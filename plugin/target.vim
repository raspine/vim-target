" target.vim - Returns the executable target name
" Author:       Jörgen Scott (jorgen.scott@gmail.com)
" Version:      0.2

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
    " TODO: support more build environments than cmake?
    if g:target_cmake_env
        let l:targets = <SID>FindCMakeTarget()
        let l:sel = 0

        if len(l:targets) == 0
            echoerr "No target found"
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

" local functions

" TODO: Is there a Vim function for this?
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
        return a:build_dir . "/" . final_app_name
    else
        return ""
    endif
endfunction

" Parses a CMakeLists.txt. Supports common variable substitutions such as using
" project_name and/or the set() method. The method is not 'water proof' and
" probably never will be a cmake provides very flexible ways to build up
" variables names. Hopefully it is good enough to support most common use
" cases...
" TODO: No support for target names built with _multiple_ concatenated cmake
" variables.
function! s:ParseCMakeList(build_dir, cmake_list)
    let l:var_name = ""
    let l:app_name = ""
    let l:ret_targets = []

    if filereadable(a:cmake_list)
        let cm_list = readfile(a:cmake_list)
        for line in cm_list
            " look for the target name
            if line =~ "add_executable\\_s*("
                let var_name = <SID>ExtractInner(line, "(", " ")
                if var_name =~ "${\\_s*project_name\\_s*}"
                    for proj_line in cm_list
                        if proj_line =~ "project\\_s*("
                            let var_name = <SID>ExtractInner(proj_line, "(", ")")
                            if var_name =~ "${"
                                let app_name = var_name
                                let var_name = <SID>ExtractInner(var_name, "{", "}")
                                call add(ret_targets, <SID>SubstituteWithSet(a:build_dir, app_name, var_name))
                            else
                                call add(ret_targets, a:build_dir . "/" . var_name)
                            endif
                            break
                        endif
                    endfor
                elseif var_name =~ "${"
                    let app_name = var_name
                    let var_name = <SID>ExtractInner(var_name, "{", "}")
                    call add(ret_targets, <SID>SubstituteWithSet(a:build_dir, app_name, var_name))
                else
                    call add(ret_targets, a:build_dir . "/" . var_name)
                endif
            endif
        endfor
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

    " look for CMakeLists.txt in current dir
    let l:cmake_list = expand("%:h") . '/CMakeLists.txt'
    let l:ret_targets = <SID>ParseCMakeList(build_dir, cmake_list)

    if len(ret_targets) > 0
        return l:ret_targets->uniq()
    endif

    " TODO: support deeper hierachies than one level?
    "
    " if here there's no local CMakeLists.txt let's look in the root
    " CMakeLists.txt, lurking above our build dir
    let l:cmake_list = build_dir . '/../CMakeLists.txt'
    let l:ret_targets = <SID>ParseCMakeList(build_dir, cmake_list)
    return  l:ret_targets->uniq()
endfunction

" vim:set ft=vim sw=4 sts=2 et:
