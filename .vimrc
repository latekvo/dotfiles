set nocompatible              " be iMproved, required
filetype off                  " required
set shell=/bin/bash

" using vim-plug for managing plugins
call plug#begin('~/.vim/plugged')

Plug 'junegunn/vim-plug' " self-management

Plug 'rhysd/vim-clang-format'
Plug 'vim-autoformat/vim-autoformat'

call plug#end()

packadd YouCompleteMe

autocmd BufWritePre *.c,*.cpp,*.h,*.hpp,*.cc,*.cxx ClangFormat

"Binds

:function! CXX_RUN()
:wa
:!g++ %:r.c* && ./a.out
:endfunction

"basic html opensite
map <f4> <esc>:!firefox *.html<CR>
"map <f5> <esc>:!make<CR>
map <f5> <esc>:execute CXX_RUN()<CR>

" Don't save backups of *.gpg files
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
set nocp "disable VI compatibility
set sol  "jump to first character
set is "incremental search
set ic "ignore case search
set noswapfile "working directly on file
set nowrap "no wrapping 
set nolbr "more of nowrap
set nobri "more of nowrap "no indent
set wd=0 "no delay to writing
set hid "keep buffer that are out of reach
set mouse=a "enables all mouse functions
set rnu "relative numbers
set nu "works with rnu for better rnu
set nospell "no english dictionary
set ruler "cursor position as a coordinate number
set smd "show mode
set noeb "disable error bells
set hlg=en "set english as help default
set udf "enable undo file
set udir=~/.vim/undodir "undo dir
set nosm "disable confusing bracket highlighting
set ai "auto indent
set si "smart auto indent
set cin "C lang indenting
set wildmenu "unfolding selection menu
set ts=2 "tab
set sw=2 "autotab
set nosta "disable smart tab
set et "convert tabs to spaces
set tabstop=2
set softtabstop=2
set shiftwidth=2

set noarab "disable arabic
set noemo "disable emoticons

set colorcolumn=100
"highlight ColorColumn ctermbg=0 guibg=lightgrey
hi ColorColumn ctermbg=236 guibg=blue

"disable config load confirmation prompt
let g:ycm_confirm_extra_conf = 0

if has("syntax")
  syntax on
endif

syntax enable

" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line
