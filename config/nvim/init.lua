-- Basic editor settings
vim.cmd('syntax on')
vim.opt.number = true
vim.opt.background = 'dark'
vim.opt.mouse = 'a'
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Indentation
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Better editing experience
vim.opt.wrap = false
vim.opt.clipboard = 'unnamedplus'
vim.opt.swapfile = false

-- Set leader key to space
vim.g.mapleader = " "

-- Install vim-plug if not found
local plug_path = vim.fn.stdpath('data') .. '/site/autoload/plug.vim'
if vim.fn.empty(vim.fn.glob(plug_path)) > 0 then
  vim.fn.system({
    'curl', '-fLo', plug_path, '--create-dirs',
    'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  })
end

-- Plugin setup
vim.cmd([[
call plug#begin()
Plug 'tpope/vim-sensible'
Plug 'morhetz/gruvbox'
call plug#end()
]])

-- Gruvbox theme settings
vim.g.gruvbox_transparent_bg = 1
vim.cmd('autocmd vimenter * ++nested colorscheme gruvbox')

-- Netrw file explorer settings
vim.g.netrw_liststyle = 3
vim.g.netrw_banner = 0
vim.g.netrw_browse_split = 2
vim.g.netrw_winsize = 25

-- Basic keymaps
vim.keymap.set('i', 'jk', '<ESC>', { noremap = true })
vim.keymap.set('n', '<leader>w', ':w<CR>', { noremap = true })
vim.keymap.set('n', '<leader>h', ':nohlsearch<CR>', { noremap = true })
vim.keymap.set('n', '<leader>v', ':vsplit<CR>', { noremap = true })
vim.keymap.set('n', '<leader>s', ':split<CR>', { noremap = true })

-- Enable filetype detection and plugins
vim.cmd('filetype plugin indent on')
