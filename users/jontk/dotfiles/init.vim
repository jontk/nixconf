" Neovim configuration
" This file is managed by Home Manager

" Basic settings
set number relativenumber
set expandtab
set tabstop=2
set shiftwidth=2
set softtabstop=2
set autoindent
set smartindent
set wrap
set linebreak
set scrolloff=8
set sidescrolloff=8
set signcolumn=yes
set colorcolumn=80,120
set cursorline
set termguicolors
set hidden
set nobackup
set nowritebackup
set updatetime=300
set timeoutlen=300
set encoding=utf-8
set fileencoding=utf-8
set mouse=a
set splitbelow
set splitright
set clipboard=unnamedplus
set completeopt=menuone,noselect
set ignorecase
set smartcase
set incsearch
set hlsearch

" Set leader key
let mapleader = " "
let maplocalleader = " "

" Disable netrw for nvim-tree
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1

" Basic keymaps
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>Q :qa!<CR>
nnoremap <ESC><ESC> :noh<CR>

" Window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Window resizing
nnoremap <C-Up> :resize +2<CR>
nnoremap <C-Down> :resize -2<CR>
nnoremap <C-Left> :vertical resize -2<CR>
nnoremap <C-Right> :vertical resize +2<CR>

" Buffer navigation
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprevious<CR>
nnoremap <leader>bd :bdelete<CR>

" Visual mode improvements
vnoremap < <gv
vnoremap > >gv
vnoremap <leader>y "+y
vnoremap <leader>p "+p

" Move text up and down
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" Better terminal navigation
tnoremap <Esc> <C-\><C-n>
tnoremap <C-h> <C-\><C-n><C-w>h
tnoremap <C-j> <C-\><C-n><C-w>j
tnoremap <C-k> <C-\><C-n><C-w>k
tnoremap <C-l> <C-\><C-n><C-w>l

" Quick splits
nnoremap <leader>v :vsplit<CR>
nnoremap <leader>h :split<CR>

" Plugin configuration would go here
" Since we're using home-manager, plugins should be managed via Nix

" Color scheme
try
  colorscheme dracula
catch
  colorscheme desert
endtry

" Highlight on yank
augroup YankHighlight
  autocmd!
  autocmd TextYankPost * silent! lua vim.highlight.on_yank()
augroup end

" Remove trailing whitespace on save
augroup TrimWhitespace
  autocmd!
  autocmd BufWritePre * %s/\s\+$//e
augroup end

" Return to last edit position when opening files
augroup RememberPosition
  autocmd!
  autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
augroup end

" File type specific settings
augroup FileTypeSettings
  autocmd!
  autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
  autocmd FileType json setlocal ts=2 sts=2 sw=2 expandtab
  autocmd FileType nix setlocal ts=2 sts=2 sw=2 expandtab
  autocmd FileType python setlocal ts=4 sts=4 sw=4 expandtab
  autocmd FileType go setlocal ts=4 sts=4 sw=4 noexpandtab
  autocmd FileType rust setlocal ts=4 sts=4 sw=4 expandtab
  autocmd FileType markdown setlocal wrap linebreak spell
augroup end