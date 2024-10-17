set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

" The following are examples of different formats supported.
" Keep Plugin commands between vundle#begin/end.
" plugin on GitHub repo
Plugin 'tpope/vim-fugitive'
" plugin from http://vim-scripts.org/vim/scripts.html
" Plugin 'L9'
" Git plugin not hosted on GitHub
Plugin 'git://git.wincent.com/command-t.git'
" git repos on your local machine (i.e. when working on your own plugin)
"Plugin 'file:///home/gmarik/path/to/plugin'
" The sparkup vim script is in a subdirectory of this repo called vim.
" Pass the path to set the runtimepath properly.
Plugin 'rstacruz/sparkup', {'rtp': 'vim/'}
" Install L9 and avoid a Naming conflict if you've already installed a
" different version somewhere else.
" Plugin 'ascenator/L9', {'name': 'newL9'}

"PLUG IN HERE YOUR PLUGINS!

packadd YouCompleteMe

"ycm format on paste
:autocmd BufWritePost * :YcmCompleter Format <afile>

"Binds

:function! OIOIOI_RUN()
:wa
:!rm %:r.out %:r.e && ./ocen %:r
:endfunction

:function! ANY_RUN()
:wa
:!g++ %:r.cpp && ./a.out
:endfunction

"basic html opensite
map <f4> <esc>:!firefox *.html<CR>
"basic compile with c++
"map <f5> <esc>:!make<CR>
map <f5> <esc>:execute ANY_RUN()<CR>
"build and test oioioi files
map <f6> <esc>:execute OIOIOI_RUN()<CR>
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

"Holy, these popups are annoying
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
set noeb "no error bells
set hlg=en "english help (default is pl)
set udf "enable undo file
set udir=~/.vim/undodir "undodir
set nosm "no jumping to {
set ts=2 "tab
set sw=2 "autotab
set nosta "disable some tab gimmick
set noet "tabs shall reamain tabs, not spaces
set ai "auto indent
set si "smart autoindent
set cin "special C lang indenting
set wildmenu "unfolding selection menu
set noarab "no arabic support
set noemo "no emoticons support

set colorcolumn=100
"highlight ColorColumn ctermbg=0 guibg=lightgrey
hi ColorColumn ctermbg=236 guibg=blue

if has("syntax")
  syntax on
endif

"Install when new vim is available
"Plugin 'Valloric/YouCompleteMe'
"    let g:ycm_global_ycm_extra_conf = "~/.vim/.ycm_extra_conf.py"


Plugin 'rust-lang/rust.vim'

Plugin 'racer-rust/vim-racer'
	let g:syntastic_rust_checkers = ['cargo']
	let g:racer_experimental_completer = 1
	let g:racer_insert_paren = 1
	let g:racer_cmd = "/home/user/.cargo/bin/racer"

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
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
