set nocompatible              " be iMproved, required
filetype off                  " required

set backupskip+=*.gpg
" To avoid that parts of the file is saved to .viminfo when yanking or
" deleting, empty the 'viminfo' option.
set viminfo=

augroup encrypted
  au!
  " Disable swap files, and set binary file format before reading the file
  autocmd BufReadPre,FileReadPre *.gpg
    \ setlocal noswapfile bin
  " Decrypt the contents after reading the file, reset binary file format
  " and run any BufReadPost autocmds matching the file name without the .gpg
  " extension
  autocmd BufReadPost,FileReadPost *.gpg
    \ execute "'[,']!gpg --decrypt --default-recipient-self" |
    \ setlocal nobin |
    \ execute "doautocmd BufReadPost " . expand("%:r")
  " Set binary file format and encrypt the contents before writing the file
  autocmd BufWritePre,FileWritePre *.gpg
    \ setlocal bin |
    \ '[,']!gpg --encrypt --default-recipient-self
  " After writing the file, do an :undo to revert the encryption in the
  " buffer, and reset binary file format
  autocmd BufWritePost,FileWritePost *.gpg
    \ silent u |
    \ setlocal nobin
augroup END

set completeopt-=preview
set encoding=utf-8
set nocp "not that VI compatible, has pros and cons
set sol  "jump to first character
set is "incremental search
set ic "ignore case search
set noswapfile "working directly on file
set nowrap "no wrapping 
set nolbr "more of nowrap
set nobri "more of nowrap "no indent
set wd=0 "no delay to writing
set hid "not deleting buffer when outta reach
set mouse=a "enables all mouse functions
set rnu "relative numbers
set nu "works with rnu for better rnu
set nospell "no english dictionary
set ruler "cursor position as a coordinate number
set smd "show mode
set noeb "Who the living fuck invented error bells
set hlg=en "english help (default is pl)
set udf "enable undo file
set udir=~/.vim/undodir "undodir
set nosm "no annoying jumping to {
set ts=4 "tab
set sw=4 "autotab
set nosta "this function is usually great, but i want my tabs to be consistent
set noet "tabs shall reamain tabs, not spaces
set ai "auto indent, its sometimes annoying but i like it
set si "eeh sceptical about 'smart' autoindent
set cin "special C lang indenting
set wildmenu "unfolding selection menu

set colorcolumn=100
hi ColorColumn ctermbg=236 guibg=blue

if has("syntax")
  syntax on
endif

filetype plugin indent on    " required
syntax enable
