execute pathogen#infect()

syntax on
filetype plugin indent on

set tabstop=4
set softtabstop=2
set shiftwidth=2
set expandtab
set smarttab

set path+=**
set wildmenu
set wildignore+=**/*.pyc
set hidden

set number
set relativenumber

let NERDTreeShowHidden=1

let g:ycm_autoclose_preview_window_after_insertion=1

" ctrl+y and enter to stop completion
let g:ycm_key_list_stop_completion=['<C-y>', '<CR>']

" have vim jump to the last position when reopening a file
autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" commits set spell and width
autocmd Filetype gitcommit setlocal spell textwidth=72

" Start NERDTree when Vim is started without file arguments.
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists('s:std_in') | NERDTree | endif

" Exit Vim if NERDTree is the only window remaining in the only tab.
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

" keybinds
map <F2> :NERDTreeToggle<cr>
map <C-Left> :$wincmd h<cr>
map <C-Right> :$wincmd l<cr>
map <C-Up> :$wincmd k<cr>
map <C-Down> :$wincmd j<cr>

" Theme
set background=dark
colorscheme gruvbox
