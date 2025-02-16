" Basic editor settings
syntax on
set number
set background=dark
set mouse=a
set ignorecase
set smartcase

" Indentation
set tabstop=4
set shiftwidth=4
set expandtab
set smartindent

" Better editing experience
set nowrap
set clipboard=unnamed
set noswapfile

" Set leader key to space
let mapleader = " "

" Plug plugin manager
call plug#begin('~/.vim/plugged')
Plug 'tpope/vim-sensible'
Plug 'morhetz/gruvbox'
call plug#end()

" Gruvbox theme settings
let g:gruvbox_transparent_bg=1
autocmd vimenter * ++nested colorscheme gruvbox

" Netrw file explorer settings
let g:netrw_liststyle=3
let g:netrw_banner=0
let g:netrw_browse_split=2
let g:netrw_winsize=25

" Basic keymaps
noremap jk <ESC>
nnoremap <leader>w :w<CR>
nnoremap <leader>h :nohlsearch<CR>
nnoremap <leader>v :vsplit<CR>
nnoremap <leader>s :split<CR>

" Enable filetype detection and plugins
filetype plugin indent on
