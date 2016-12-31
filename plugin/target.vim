" target.vim - Returns the executable target name
" Author:       Jörgen Scott (jorgen.scott@gmail.com)
" Version:      0.1

if exists("g:loaded_target") || &cp || v:version < 700
    finish
endif
let g:loaded_target = 1

" global vars
let g:target_check_executable = 1
let g:target_cmake_env = 1

" public interface
function! FindExeTarget()
    " TODO: support more build environments
    if g:target_cmake_env
        let l:target = <SID>FindCMakeTarget()
        if g:target_check_executable && l:target != "" && !executable(l:target)
            echoerr "vim-target: Found target does not exist"
            return ""
        endif
    else
        echoerr "vim-target: Build environment not supported"
        return ""
    endif

    return l:target

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

function! s:SubstituteWithSet(cmake_list, app_name, var_name)
    " a variable is used for the target name let's look for a set function
    " containing the var_name in cmake_list
    let main_app_name = ""
    let main_app_found = 0
    if filereadable(a:cmake_list)
        let cm_list = readfile(a:cmake_list)
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
        return build_dir . "/" . final_app_name
    else
        return ""
    endif
endfunction

" A cmake parser with the single purpose of finding the target name for the
" active buffer.
" TODO: No support for target names built with multiple concatenated cmake
" variables.
function! s:FindCMakeTarget()
    let l:found_var = 0
    let l:var_name = ""
    let l:app_name = ""
    let l:cmake_build_dir = get(g:, 'cmake_build_dir', 'build')
    let l:build_dir = finddir(l:cmake_build_dir, '.;')
    if build_dir == ""
        return ""
    endif

    " look for CMakeLists.txt in current dir
    let l:curr_cmake = expand("%:h") . '/CMakeLists.txt'
    if filereadable(curr_cmake)
        let cm_list = readfile(curr_cmake)
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
                                let found_var = 1
                            else
                                return build_dir . "/" . var_name
                            endif
                            break
                        endif
                    endfor
                elseif var_name =~ "${"
                    let app_name = var_name
                    let var_name = <SID>ExtractInner(var_name, "{", "}")
                    let found_var = 1
                else
                    return build_dir . "/" . var_name
                endif
            endif
        endfor
        if found_var == 0
            return ""
        endif

        " a variable is used for the target name let's look for a set function
        " containing the var_name in the root CMakeLists.txt
        return <SID>SubstituteWithSet(build_dir . '/../CMakeLists.txt', app_name, var_name)
    endif

    " if here there's no local CMakeLists.txt let's look in the root
    " CMakeLists.txt, lurking above our build dir
    if filereadable(build_dir . '/../CMakeLists.txt')
        let cm_list = readfile(build_dir . '/../CMakeLists.txt')
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
                                let found_var = 1
                            else
                                return build_dir . "/" . var_name
                            endif
                            break
                        endif
                    endfor
                elseif var_name =~ "${"
                    let app_name = var_name
                    let var_name = <SID>ExtractInner(var_name, "{", "}")
                    let found_var = 1
                else
                    return build_dir . "/" . var_name
                endif
            endif
        endfor
        if found_var == 0
            return ""
        endif

        " a variable is used for the target name let's look for a set function
        " containing the var_name in the root CMakeLists.txt
        return <SID>SubstituteWithSet(build_dir . '/../CMakeLists.txt', app_name, var_name)
    endif
endfunction

" vim:set ft=vim sw=4 sts=2 et:
