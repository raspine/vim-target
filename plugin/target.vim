" target.vim - Returns the executable target name
" Author:       Jörgen Scott (jorgen.scott@gmail.com)
" Version:      0.4

" TODO: no idea what version is actually required for this plugin
if exists("g:loaded_target") || &cp || v:version < 700
    finish
endif
let g:loaded_target = 1

" global vars
" check that the executable is actually built (we can parse the executable
" successfully anyway)
let g:target_check_executable = 1
" add build environments here so we can ignore build environments not used (for
" speed)
let g:target_cmake_env = 1

" public interface
function! FindExeTarget()
    if g:target_cmake_env
        let l:targets = <SID>FindCMakeTarget()
        let l:sel = 0

        if len(l:targets) == 0
            return ""
        elseif len(l:targets) > 1
            echo "Multiple targets found:"
            while 1
                let index = 1
                for target in l:targets
                    echo index . ") " . target
                    let index = index + 1
                endfor
                call inputsave()
                let sel = input('Select index: ')
                call inputrestore()
                if sel == type(0) || sel > len(l:targets)
                    echoerr "Please select a number within range"
                else
                    break
                endif
            endwhile
            let sel = sel - 1
        endif

        if g:target_check_executable && l:targets[sel] != "" && !executable(l:targets[sel])
            echoerr "vim-target: Found target does not exist"
            return ""
        endif
    else
        echoerr "vim-target: Build environment not supported"
        return ""
    endif
    return l:targets[sel]
endfunction

function! FindBuildTarget()
    let l:cmake_build_dir = get(g:, 'cmake_build_dir', 'build')
    let l:build_dir = finddir(l:cmake_build_dir, '.;')

    if build_dir == ""
        return ""
    endif

    " search for CMakeLists.txt in the directory of the current file upwards
    let l:cmake_list = expand("%:h") . '/CMakeLists.txt'
    if !filereadable(cmake_list)
        let l:cmake_list = findfile("CMakeLists.txt", ".;")
    endif

    let l:targets = <SID>ParseCMakeList(build_dir, cmake_list)

	if len(l:targets) == 0
		return ""
	elseif len(l:targets) == 1
		return l:targets[0]
	elseif len(l:targets) > 1
		echo "Multiple targets found:"
		while 1
			let index = 1
			for target in l:targets
				echo index . ") " . target
				let index = index + 1
			endfor
			call inputsave()
			let sel = input('Select index: ')
			call inputrestore()
			if sel == type(0) || sel > len(l:targets)
				echoerr "Please select a number within range"
			else
				break
			endif
		endwhile
		let sel = sel - 1
		return l:targets[sel]
	endif
endfunction

" local functions

function! s:ExtractInner(str, left_delim, right_delim)
    let astr = " " . a:str . " "
    let inner = split(astr, a:left_delim)[1]
    let inner = split(inner, a:right_delim)[0]
    let inner = substitute(inner, '^\s*\(.\{-}\)\s*$', '\1', '')
    return inner
endfunction

" looks for a set function in the root CMakeLists.txt to make a substitution
" of app_name
function! s:SubstituteWithSet(build_dir, app_name, var_name)
    let main_app_name = ""
    let main_app_found = 0
    if filereadable(a:build_dir . '/../CMakeLists.txt')
        let cm_list = readfile(a:build_dir . '/../CMakeLists.txt')
        for line in cm_list
            if line =~ "set\\_s*(\\_s*" . a:var_name
                let main_app_name = <SID>ExtractInner(line, a:var_name, ")")
                let main_app_found = 1
            endif
        endfor

        if main_app_found == 0
            return ""
        endif

        " If here, we have a e.g. main_app_name="my_app", e.g. var_name="APP_NAME"
        " and e.g. app_name="${APP_NAME}_test".
        " So we make a substitution of what we got, e.g. to my_app_test.
        " echo main_app_name . " " . var_name . " " . app_name
        let final_app_name = substitute(a:app_name, "${\\_s*" . a:var_name . "\\_s*}", main_app_name, "")
        return final_app_name
    else
        return ""
    endif
endfunction

function! s:JoinLinesUntilDelim(lines, start_index, delim)
	let l:ret = a:lines[a:start_index]
	let l:index = a:start_index + 1
	while l:index < len(a:lines)
		let l:ret = l:ret . a:lines[l:index]
		let l:index = l:index + 1
		if l:ret =~ a:delim
			break
		endif
	endwhile
	return l:ret
endfunction

" Parses a CMakeLists.txt. Supports common variable substitutions such as using
" project_name and/or the set() method. The method is not 'water proof' and
" probably never will be a cmake provides very flexible ways to build up
" variables names. Hopefully it is good enough to support most common use
" cases...
function! s:ParseCMakeList(build_dir, cmake_list)
    let l:var_name = ""
    let l:app_name = ""
    let l:ret_targets = []

    if filereadable(a:cmake_list)
        let cm_list = readfile(a:cmake_list)
        let l:lineNo = 0
        while l:lineNo < len(cm_list)
            let l:line = cm_list[l:lineNo]
            " look for the target name
            if line =~ "add_executable\\_s*("
                let l:fullLine = <SID>JoinLinesUntilDelim(cm_list, l:lineNo, ")")
                let var_name = <SID>ExtractInner(l:fullLine, "(", " ")
                if var_name =~ "${\\_s*project_name\\_s*}"
                    for proj_line in cm_list
                        if proj_line =~ "project\\_s*("
                            let var_name = <SID>ExtractInner(proj_line, "(", ")")
                            if var_name =~ "${"
                                let app_name = var_name
                                let var_name = <SID>ExtractInner(var_name, "{", "}")
                                call add(ret_targets, <SID>SubstituteWithSet(a:build_dir, app_name, var_name))
                            else
                                call add(ret_targets, var_name)
                            endif
                            break
                        endif
                    endfor
                elseif var_name =~ "${"
                    let app_name = var_name
                    let var_name = <SID>ExtractInner(var_name, "{", "}")
                    call add(ret_targets, <SID>SubstituteWithSet(a:build_dir, app_name, var_name))
                else
                    call add(ret_targets, var_name)
                endif
            endif
            let l:lineNo = l:lineNo + 1
        endwhile
    endif
    return ret_targets
endfunction

" A cmake parser with the sole purpose of finding the target name for the
" active buffer.
function! s:FindCMakeTarget()
    let l:cmake_build_dir = get(g:, 'cmake_build_dir', 'build')
    let l:build_dir = finddir(l:cmake_build_dir, '.;')

    if build_dir == ""
        return ""
    endif

    " search for CMakeLists.txt in the directory of the current file upwards
    let l:cmake_list = expand("%:h") . '/CMakeLists.txt'
    if !filereadable(cmake_list)
        let l:cmake_list = findfile("CMakeLists.txt", ".;")
    endif

    let l:targets = <SID>ParseCMakeList(build_dir, cmake_list)
    let l:ret_targets = []

    if len(targets) > 0
        let uniq_targets = l:targets->uniq()
        for target in uniq_targets
            let l:build_parent_dir = fnamemodify(l:build_dir, ':h')
            if filereadable(build_dir . "/" . target)
                call add(ret_targets, build_dir . "/" . target)
            else
                " build_parent_dir may be several directories up than getcwd()
                " Append the difference to build_dir as that would typically be
                " a common place to find targets in the build directory.
                let l:str_diff = strpart(getcwd(), strlen(l:build_parent_dir))
                if filereadable(build_dir . str_diff . "/" . target)
                    call add(ret_targets, build_dir . str_diff . "/" . target)
                else
                    " brute force search
                    call add(ret_targets, findfile(target, build_dir."/**"))
                endif
            endif
        endfor
        return l:ret_targets
    endif

    " TODO: support deeper hierachies than one level?
    "
    " if here there's no local CMakeLists.txt let's look in the root
    " CMakeLists.txt, lurking above our build dir
    let l:cmake_list = build_dir . '/../CMakeLists.txt'
    let l:targets = <SID>ParseCMakeList(build_dir, cmake_list)
    let uniq_targets = l:targets->uniq()
    for target in uniq_targets
        call add(ret_targets, build_dir . "/" . target)
    endfor
    return  l:ret_targets
endfunction

" vim:set ft=vim sw=4 sts=2 et:
