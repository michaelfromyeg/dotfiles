syntax on
set nu
set background=dark

call plug#begin('~/.vim/plugged')

Plug 'tpope/vim-sensible'
Plug 'morhetz/gruvbox'

call plug#end()

let g:gruvbox_transparent_bg=1

" netrw
let g:netrw_liststyle=3
let g:netrw_banner=0
let g:netrw_browse_split=2
let g:netrw_winsize=25

autocmd vimenter * ++nested colorscheme gruvbox
