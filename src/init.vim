syntax on
set nu
set ai
set tabstop=4
set ls=2
set autoindent 

call plug#begin()

Plug 'tpope/vim-sensible'
Plug 'preservim/nerdtree'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'stsewd/fzf-checkout.vim'
Plug 'Valloric/YouCompleteMe', { 'do': './install.py' }

" Color schemes
Plug 'sainnhe/gruvbox-material'

call plug#end()

" Note this will call errors before :PlugInstall is ran
colorscheme gruvbox-material