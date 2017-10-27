vim-target
=============
### Returns the executable ###

vim-target tries to parse the build-environment and return the best matching
executable target for the current buffer. It currently supports CMake build
environments.

As the current buffer may be linked by several executable targets, it's not
"water proof" and will work best if the current buffer/file has
a CMakeList.txt defined in the same directory.

vim-target will attempt to provide a single executable target without user
intervention, however if there are several calls to "add_executable" in any
CMakeLists.txt, it will prompt the caller for the intended target. Avoid this
by using an hierarchy of CMakeLists.txt:s.

I mainly use it in my .vimrc to launch stuff together with
[vim-breakgutter](http://github.com/raspine/vim-breakgutter) and
[vim-testdog](http://github.com/raspine/vim-testdog).

## Usage
vim-target currently provides a single function `FindExeTarget()` that
returns the executable target for the active buffer.

Test with:
```
:echo FindExeTarget()
```


Examples:
```
" run the target from Vim
nnoremap <leader>r :exec "!" . FindExeTarget()<cr>

" spawn a gdb session in a separate terminal using Tim Pope's vim-dispatch plugin
nnoremap <leader>g :exec "Spawn urxvt -e gdb " . FindExeTarget()<cr>

```

## License

Distributed under the same terms as Vim itself.  See the vim license.
