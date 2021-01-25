syntax on
set nu
set background=dark

call plug#begin('~/.vim/plugged')

Plug 'tpope/vim-sensible'
Plug 'morhetz/gruvbox'

call plug#end()

let g:gruvbox_transparent_bg=1

autocmd vimenter * ++nested colorscheme gruvbox
