" booky.vim - Bookmark plugin for Neovim
" Maintainer: atiladefreitas

if exists('g:loaded_booky') || !has('nvim-0.5')
  finish
endif
let g:loaded_booky = 1

" Define the plugin commands
command! -nargs=0 BookyAdd lua require('booky').add_current_file()
command! -nargs=0 BookyRemove lua require('booky').remove_current_file()
command! -nargs=0 BookyToggle lua require('booky').toggle_current_file()
command! -nargs=0 BookyList lua require('booky').open_telescope()