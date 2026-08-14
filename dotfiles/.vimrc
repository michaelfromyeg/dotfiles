" A seemingly sane? Vim configuration written by Claude
" I keep this around because my Neovim setup uses LazyVim
" which is a bit intense, and the minimal Vim setup is
" often useful for quick edits.

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
if has('unnamedplus')
  set clipboard=unnamedplus
else
  set clipboard=unnamed
endif
set noswapfile

" Set leader key to space
let mapleader = " "

" Plug plugin manager (guarded so a fresh machine without vim-plug still gets
" a working vim; `dotfiles env` installs it)
if !empty(glob('~/.vim/autoload/plug.vim'))
  call plug#begin('~/.vim/plugged')
  Plug 'tpope/vim-sensible'
  Plug 'morhetz/gruvbox'
  call plug#end()
endif

" Gruvbox theme settings (silent! so a missing plugin doesn't error every launch)
let g:gruvbox_transparent_bg=1
autocmd vimenter * ++nested silent! colorscheme gruvbox

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
