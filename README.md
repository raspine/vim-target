# vim-target
=============
### Returns the executable ###

vim-target tries to parse the build-environment and return the best matching
executable target for the current buffer. It currently supports CMake build
environments.

As the current buffer may be linked by several executable targets, it's not
"water proof" and will work best if your the current buffer/file has
a CMakeList.txt defined in the same directory.

vim-target does not fill a particular purpose on its own, however I use it in
my .vimrc to launch stuff.

## Usage
vim-target currently provides a single function `FindCMakeTargetName()` that
returns the executable target for the active buffer.

Examples:
```
" run the target from Vim
nnoremap <leader>r :!FindCMakeTargetName()<cr>

" spawn a gdb session in a separate terminal using Tim Pope's vim-dispatch plugin
nnoremap <leader>g :exec "Spawn urxvt -e gdb" . FindCMakeTargetName()<cr>

```

