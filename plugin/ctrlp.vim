" File:          plugin/ctrlp.vim
" Description:   Fuzzy file.
" Author:        Kien Nguyen <github.com/kien>
" Modified By:   Akshay Hegde <github.com/ajh17>

if (exists('g:loaded_ctrlp') && g:loaded_ctrlp) || v:version < 700 || &compatible
  finish
endif

let g:loaded_ctrlp = 1
let g:ctrlp_ext_vars = []
let g:ctrlp_builtins = 2

command! -nargs=? -complete=dir CtrlP call ctrlp#init(0, { 'dir': <q-args> })
command! -bar CtrlPCurWD     call ctrlp#init(0, { 'mode': '' })

nnoremap <leader>f :CtrlP<CR>
nnoremap <leader>F :CtrlPCurWD<CR>
