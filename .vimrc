" =============================================================================
" Plugin manager: vim-plug
" Install: curl -fLo ~/.vim/autoload/plug.vim --create-dirs
"   https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
" Then run :PlugInstall
" =============================================================================
call plug#begin('~/.vim/plugged')

Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'airblade/vim-gitgutter'
Plug 'dense-analysis/ale'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-fugitive'
Plug 'itchyny/lightline.vim'
Plug 'plasticboy/vim-markdown'
Plug 'bogado/file-line'
Plug 'vim-ruby/vim-ruby'
Plug 'leafgarland/typescript-vim'
Plug 'prettier/vim-prettier', { 'do': 'yarn install' }

call plug#end()

" =============================================================================
" General
" =============================================================================
set nocompatible
set encoding=utf-8
syntax on
filetype plugin indent on

set number
set ruler
set laststatus=2
set noshowmode              " lightline handles this
set title
set backspace=2

set nobackup
set noswapfile
set nowritebackup

set visualbell
set noerrorbells

set hidden                  " allow switching buffers without saving
set wildmenu                " better command-line completion
set wildmode=longest:full,full
set scrolloff=3             " keep 3 lines above/below cursor
set signcolumn=yes          " always show sign column (gitgutter/ale)

" =============================================================================
" Indentation
" =============================================================================
set shiftwidth=2
set softtabstop=2
set expandtab
set autoindent

" =============================================================================
" Search
" =============================================================================
set hlsearch
set incsearch
set ignorecase
set smartcase

" Copy selection to system clipboard (Wayland)
vnoremap <F8> :w !wl-copy<CR><CR>

" Clear highlighted search with ,/
nmap <silent> ,/ :nohlsearch<CR>

" Search for visually selected text with //
vnoremap // y/\V<C-R>=escape(@",'/\')<CR><CR>

" =============================================================================
" Leader
" =============================================================================
let mapleader = ","

" =============================================================================
" Folding
" =============================================================================
set foldmethod=indent
set foldlevel=20

" =============================================================================
" Colors
" =============================================================================
set background=dark
set t_ut=

if has('termguicolors')
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif

colorscheme mustang

" =============================================================================
" Plugin: fzf (replaces CtrlP)
" =============================================================================
nnoremap <C-p> :Files<CR>
nnoremap <Leader>b :Buffers<CR>
nnoremap <Leader>f :Rg<CR>
nnoremap <Leader>/ :BLines<CR>
nnoremap <Leader>h :History<CR>

" =============================================================================
" Plugin: ALE (replaces Syntastic)
" =============================================================================
let g:ale_fix_on_save = 0
let g:ale_sign_error = 'E'
let g:ale_sign_warning = 'W'
let g:ale_lint_on_text_changed = 'normal'
let g:ale_lint_on_insert_leave = 1
let g:ale_fixers = {
      \ 'ruby': ['rubocop'],
      \ 'sh': ['shfmt'],
      \ }

" =============================================================================
" Plugin: lightline
" =============================================================================
let g:lightline = {
      \ 'colorscheme': 'wombat',
      \ 'active': {
      \   'left': [ ['mode', 'paste'], ['gitbranch', 'readonly', 'filename', 'modified'] ],
      \ },
      \ 'component_function': {
      \   'gitbranch': 'FugitiveHead'
      \ },
      \ }

" =============================================================================
" Plugin: vim-gitgutter
" =============================================================================
nmap <Leader>hv <Plug>(GitGutterPreviewHunk)
nmap <Leader>hs <Plug>(GitGutterStageHunk)
nmap <Leader>hu <Plug>(GitGutterUndoHunk)

" =============================================================================
" Plugin: vim-markdown
" =============================================================================
let g:vim_markdown_folding_disabled = 1

" =============================================================================
" Key mappings
" =============================================================================
" Run rubocop for the current file (open in new tab)
map <F2> :Tab rubocop %<CR>

" Run rg for current word (open in new tab)
map <F4> :Tab rg <cword><CR>

" Remove trailing whitespace
map <F7> :%s/\s\+$//ge<CR>

" Format with ALEFix (Ruby: rubocop, Bash: shfmt)
map <F9> :ALEFix<CR>

" Prettier
map <F10> :Prettier<CR>

" =============================================================================
" Shell command helpers
" =============================================================================
" :Split ls -la  — run shell command, show output in horizontal split
command! -complete=file -nargs=+ Split call s:RunShellCommandInSplit(<q-args>)
function! s:RunShellCommandInSplit(cmdline)
  botright new
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
  call setline(1, a:cmdline)
  call setline(2, substitute(a:cmdline, '.', '=', 'g'))
  execute 'silent $read !' . escape(a:cmdline, '%#')
  setlocal nomodifiable
  1
endfunction

" :Tab ls -la  — same but in a new tab
command! -complete=file -nargs=+ Tab call s:RunShellCommandInTab(<q-args>)
function! s:RunShellCommandInTab(cmdline)
  tabnew
  setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
  call setline(1, a:cmdline)
  call setline(2, substitute(a:cmdline, '.', '=', 'g'))
  execute 'silent $read !' . escape(a:cmdline, '%#')
  setlocal nomodifiable
  1
endfunction

" :S pattern  — search with rg (replaces ag)
command! -nargs=+ S call s:RunShellCommandInTab('rg "' . <q-args> . '"')

" =============================================================================
" Navigate by indentation level: [l ]l [L ]L
" =============================================================================
function! NextIndent(exclusive, fwd, lowerlevel, skipblanks)
  let line = line('.')
  let column = col('.')
  let lastline = line('$')
  let indent = indent(line)
  let stepvalue = a:fwd ? 1 : -1
  while (line > 0 && line <= lastline)
    let line = line + stepvalue
    if ( ! a:lowerlevel && indent(line) == indent ||
          \ a:lowerlevel && indent(line) < indent)
      if (! a:skipblanks || strlen(getline(line)) > 0)
        if (a:exclusive)
          let line = line - stepvalue
        endif
        exe line
        exe "normal " column . "|"
        return
      endif
    endif
  endwhile
endfunction

nnoremap <silent> [l :call NextIndent(0, 0, 0, 1)<CR>
nnoremap <silent> ]l :call NextIndent(0, 1, 0, 1)<CR>
nnoremap <silent> [L :call NextIndent(0, 0, 1, 1)<CR>
nnoremap <silent> ]L :call NextIndent(0, 1, 1, 1)<CR>
vnoremap <silent> [l <Esc>:call NextIndent(0, 0, 0, 1)<CR>m'gv''
vnoremap <silent> ]l <Esc>:call NextIndent(0, 1, 0, 1)<CR>m'gv''
vnoremap <silent> [L <Esc>:call NextIndent(0, 0, 1, 1)<CR>m'gv''
vnoremap <silent> ]L <Esc>:call NextIndent(0, 1, 1, 1)<CR>m'gv''
onoremap <silent> [l :call NextIndent(0, 0, 0, 1)<CR>
onoremap <silent> ]l :call NextIndent(0, 1, 0, 1)<CR>
onoremap <silent> [L :call NextIndent(1, 0, 1, 1)<CR>
onoremap <silent> ]L :call NextIndent(1, 1, 1, 1)<CR>
