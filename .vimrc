set nocompatible              " be iMproved, required
filetype off                  " required
set shell=/bin/bash

" using vim-plug for managing plugins
call plug#begin('~/.vim/plugged')

Plug 'junegunn/vim-plug' " self-management

Plug 'rhysd/vim-clang-format'
Plug 'vim-autoformat/vim-autoformat'

" markdown: tabular is a hard dependency of vim-markdown's :TableFormat
Plug 'godlygeek/tabular'
Plug 'preservim/vim-markdown'

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

set updatetime=50 "instant tooltips

set colorcolumn=100
"highlight ColorColumn ctermbg=0 guibg=lightgrey
hi ColorColumn ctermbg=236 guibg=blue

"disable config load confirmation prompt
let g:ycm_confirm_extra_conf = 0

" ESP32 / PlatformIO: use the system clangd (honors --query-driver; the clangd
" YCM bundles is older and silently ignores it), and let it query the Xtensa/
" RISC-V cross-GCC for its system headers -- else ESP32 #includes all go red.
let g:ycm_clangd_binary_path = '/usr/bin/clangd'
let g:ycm_clangd_args = ['--query-driver=' . expand('$HOME') . '/.platformio/packages/toolchain-*/bin/*']

if has("syntax")
  syntax on
endif

syntax enable

" --- Markdown ---------------------------------------------------------------

" Highlight fenced code blocks with the real syntax of the language. Left of
" the '=' is the fence tag written in the document, right of it is the vim
" filetype -- entries without '=' use the tag as the filetype directly.
let g:vim_markdown_fenced_languages = [
      \ 'c=c', 'cpp=cpp', 'c++=cpp', 'h=c',
      \ 'bash=sh', 'sh=sh', 'shell=sh', 'zsh=zsh',
      \ 'py=python', 'python=python',
      \ 'js=javascript', 'javascript=javascript',
      \ 'ts=typescript', 'typescript=typescript',
      \ 'json=json', 'yaml=yaml', 'yml=yaml', 'toml=toml',
      \ 'html=html', 'css=css', 'sql=sql',
      \ 'rust=rust', 'rs=rust', 'go=go', 'lua=lua', 'vim=vim',
      \ 'ini=dosini', 'diff=diff', 'make=make', 'cmake=cmake', 'dockerfile=dockerfile',
      \ ]

" Conceal emphasis markers and link targets; ``` fences stay literal. The
" concealed text reappears on whichever line the cursor sits on, so it stays
" editable. Set this to 0 to see every marker verbatim.
let g:vim_markdown_conceal = 1
let g:vim_markdown_conceal_code_blocks = 0
let g:vim_markdown_no_extensions_in_markdown = 1
let g:vim_markdown_strikethrough = 1
let g:vim_markdown_new_list_item_indent = 2
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_math = 1
let g:vim_markdown_frontmatter = 1      " YAML front matter
let g:vim_markdown_toml_frontmatter = 1
let g:vim_markdown_json_frontmatter = 1

augroup markdown_prose
  au!
  " conceal only inside markdown; leaves every other filetype untouched.
  " empty concealcursor => the cursor line always shows its raw markers.
  autocmd FileType markdown setlocal conceallevel=2 concealcursor=
augroup END

" Distinct colours per heading level plus readable code/link/quote styling.
function! s:MarkdownColors() abort
  hi htmlH1        cterm=bold      ctermfg=204
  hi htmlH2        cterm=bold      ctermfg=209
  hi htmlH3        cterm=bold      ctermfg=180
  hi htmlH4        cterm=bold      ctermfg=114
  hi htmlH5        cterm=bold      ctermfg=110
  hi htmlH6        cterm=bold      ctermfg=140
  hi mkdHeading                    ctermfg=59
  hi mkdCode                       ctermfg=180 ctermbg=236
  hi mkdCodeStart                  ctermfg=59
  hi mkdCodeEnd                    ctermfg=59
  hi mkdCodeDelimiter              ctermfg=180 ctermbg=236
  hi mkdListItem   cterm=bold      ctermfg=209
  hi mkdBlockquote cterm=italic    ctermfg=59
  hi mkdLink       cterm=underline ctermfg=110
  hi mkdURL                        ctermfg=59
  hi mkdInlineURL  cterm=underline ctermfg=110
  hi mkdLinkDef                    ctermfg=110
  hi mkdDelimiter                  ctermfg=59
  hi mkdRule                       ctermfg=59
  hi htmlBold      cterm=bold      ctermfg=222
  hi htmlItalic    cterm=italic    ctermfg=140
  hi htmlBoldItalic cterm=bold,italic ctermfg=222
  hi mkdStrike     cterm=strikethrough ctermfg=59
  hi htmlStrike    cterm=strikethrough ctermfg=59
endfunction

augroup markdown_colors
  au!
  autocmd ColorScheme * call s:MarkdownColors()
augroup END
call s:MarkdownColors()

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
