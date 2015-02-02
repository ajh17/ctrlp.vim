" =============================================================================
" File:          plugin/ctrlp.vim
" Description:   Fuzzy file, buffer, mru, tag, etc finder.
" Author:        Kien Nguyen <github.com/kien>
" =============================================================================
" GetLatestVimScripts: 3736 1 :AutoInstall: ctrlp.zip

if ( exists('g:loaded_ctrlp') && g:loaded_ctrlp ) || v:version < 700 || &cp
  finish
endif

let g:loaded_ctrlp = 1

let g:ctrlp_ext_vars = []
let g:ctrlp_builtins = 2

command! -nargs=? -complete=dir CtrlP call ctrlp#init(0, { 'dir': <q-args> })
command! -bar CtrlPCurWD     call ctrlp#init(0, { 'mode': '' })

nnoremap <leader>f :CtrlP<CR>
nnoremap <leader>F :CtrlPCurWD<CR>
" vim:ts=2:sw=2:sts=2
