" =============================================================================
" File:          autoload/ctrlp.vim
" Description:   Fuzzy file, buffer, mru, tag, etc finder.
" Author:        Kien Nguyen <github.com/kien>
" Modified By:   Akshay Hegde <github.com/ajh17>
" Version:       1.79
" =============================================================================

" ** Static variables {{{1
" Script local vars {{{2
let [s:pref, s:bpref, s:opts, s:new_opts, s:lc_opts] =
      \ ['g:ctrlp_', 'b:ctrlp_', {
      \ 'by_filename':           ['s:byfname', 0],
      \ 'dotfiles':              ['s:showhidden', 0],
      \ 'jump_to_buffer':        ['s:jmptobuf', 'Et'],
      \ 'match_window':          ['s:mw', ''],
      \ 'match_window_bottom':   ['s:mwbottom', 1],
      \ 'match_window_reversed': ['s:mwreverse', 1],
      \ 'max_depth':             ['s:maxdepth', 40],
      \ 'max_files':             ['s:maxfiles', 10000],
      \ 'max_height':            ['s:mxheight', 10],
      \ 'max_history':           ['s:maxhst', exists('+hi') ? &hi : 20],
      \ 'open_new_file':         ['s:newfop', 'v'],
      \ 'prompt_mappings':       ['s:urprtmaps', 0],
      \ 'regexp_search':         ['s:regexp', 0],
      \ 'root_markers':          ['s:rmarkers', []],
      \ 'split_window':          ['s:splitwin', 0],
      \ 'tabpage_position':      ['s:tabpage', 'ac'],
      \ 'user_command':          ['s:usrcmd', 'ag %s -l --nocolor --hidden -g ""'],
      \ 'working_path_mode':     ['s:pathmode', 'ra'],
      \ }, {
      \ 'regexp':                's:regexp',
      \ 'show_hidden':           's:showhidden',
      \ 'switch_buffer':         's:jmptobuf',
      \ }, {
      \ 'root_markers':          's:rmarkers',
      \ 'user_command':          's:usrcmd',
      \ 'working_path_mode':     's:pathmode',
      \ }]

" Global options
let s:glbs = { 'magic': 1, 'to': 1, 'tm': 0, 'sb': 1, 'hls': 0, 'im': 0,
      \ 'report': 9999, 'sc': 0, 'ss': 0, 'siso': 0, 'mfd': 200, 'ttimeout': 0,
      \ 'gcr': 'a:blinkon0', 'ic': 1, 'lmap': '', 'mousef': 0, 'imd': 1 }

" Keymaps
let [s:lcmap, s:prtmaps] = ['nn <buffer> <silent>', {
      \ 'PrtBS()':              ['<bs>', '<c-]>'],
      \ 'PrtDelete()':          ['<del>'],
      \ 'PrtDeleteWord()':      ['<c-w>'],
      \ 'PrtClear()':           ['<c-u>'],
      \ 'PrtSelectMove("j")':   ['<c-j>', '<down>'],
      \ 'PrtSelectMove("k")':   ['<c-k>', '<up>'],
      \ 'PrtHistory(-1)':       ['<c-n>'],
      \ 'PrtHistory(1)':        ['<c-p>'],
      \ 'AcceptSelection("e")': ['<cr>', '<2-LeftMouse>'],
      \ 'AcceptSelection("h")': ['<c-x>', '<c-cr>', '<c-s>'],
      \ 'AcceptSelection("t")': ['<c-t>'],
      \ 'AcceptSelection("v")': ['<c-v>', '<RightMouse>'],
      \ 'ToggleRegex()':        ['<c-r>'],
      \ 'ToggleByFname()':      ['<c-d>'],
      \ 'PrtExpandDir()':       ['<tab>'],
      \ 'PrtCurStart()':        ['<c-a>'],
      \ 'PrtCurEnd()':          ['<c-e>'],
      \ 'PrtCurLeft()':         ['<c-h>', '<left>', '<c-^>'],
      \ 'PrtCurRight()':        ['<c-l>', '<right>'],
      \ 'CreateNewFile()':      ['<c-y>'],
      \ 'PrtExit()':            ['<esc>', '<c-c>', '<c-g>'],
      \ }]

if !has('gui_running')
  cal add(s:prtmaps['PrtBS()'], remove(s:prtmaps['PrtCurLeft()'], 0))
endif

let s:compare_lim = 3000

let s:ficounts = {}

" Regexp
let s:fpats = {
      \ '^\(\\|\)\|\(\\|\)$': '\\|',
      \ '^\\\(zs\|ze\|<\|>\)': '^\\\(zs\|ze\|<\|>\)',
      \ '^\S\*$': '\*',
      \ '^\S\\?$': '\\?',
      \ }


" Get the options {{{2
function! s:opts(...)
  unl! s:usrcmd s:urprtmaps
  for [ke, va] in items(s:opts)
    let {va[0]} = exists(s:pref.ke) ? {s:pref.ke} : va[1]
  endfor
  unl va
  for [ke, va] in items(s:new_opts)
    let {va} = {exists(s:pref.ke) ? s:pref.ke : va}
  endfor
  unl va
  for [ke, va] in items(s:lc_opts)
    if exists(s:bpref.ke)
      unl {va}
      let {va} = {s:bpref.ke}
    endif
  endfor
  " Match window options
  cal s:match_window_opts()
  " One-time values
  if a:0 && a:1 != {}
    unl va
    for [ke, va] in items(a:1)
      let opke = substitute(ke, '\(\w:\)\?ctrlp_', '', '')
      if has_key(s:lc_opts, opke)
        let sva = s:lc_opts[opke]
        unl {sva}
        let {sva} = va
      endif
    endfor
  endif
  for each in ['byfname', 'regexp'] | if exists(each)
    let s:{each} = {each}
  en | endfor
let s:maxdepth = min([s:maxdepth, 100])
let s:glob = s:showhidden ? '.*\|*' : '*'
let s:lash = ctrlp#utils#lash()
" Keymaps
if type(s:urprtmaps) == 4
  cal extend(s:prtmaps, s:urprtmaps)
endif
endfunction

function! s:match_window_opts()
  let s:mw_pos =
        \ s:mw =~ 'top\|bottom' ? matchstr(s:mw, 'top\|bottom') :
        \ exists('g:ctrlp_match_window_bottom') ? ( s:mwbottom ? 'bottom' : 'top' )
        \ : 'bottom'
  let s:mw_order =
        \ s:mw =~ 'order:[^,]\+' ? matchstr(s:mw, 'order:\zs[^,]\+') :
        \ exists('g:ctrlp_match_window_reversed') ? ( s:mwreverse ? 'btt' : 'ttb' )
        \ : 'btt'
  let s:mw_max =
        \ s:mw =~ 'max:[^,]\+' ? str2nr(matchstr(s:mw, 'max:\zs\d\+')) :
        \ exists('g:ctrlp_max_height') ? s:mxheight
        \ : 10
  let s:mw_min =
        \ s:mw =~ 'min:[^,]\+' ? str2nr(matchstr(s:mw, 'min:\zs\d\+')) : 1
  let [s:mw_max, s:mw_min] = [max([s:mw_max, 1]), max([s:mw_min, 1])]
  let s:mw_min = min([s:mw_min, s:mw_max])
  let s:mw_res =
        \ s:mw =~ 'results:[^,]\+' ? str2nr(matchstr(s:mw, 'results:\zs\d\+'))
        \ : min([s:mw_max, &lines])
  let s:mw_res = max([s:mw_res, 1])
endfunction
"}}}1
" * Open & Close {{{1
function! s:Open()
  cal s:getenv()
  cal s:execextvar('enter')
  sil! exe 'keepa' ( s:mw_pos == 'top' ? 'to' : 'bo' ) '1new ControlP'
  let [s:bufnr, s:winw] = [bufnr('%'), winwidth(0)]
  let [s:focus, s:prompt] = [1, ['', '', '']]
  abc <buffer>
  if !exists('s:hstry')
    let hst = filereadable(s:gethistloc()[1]) ? s:gethistdata() : ['']
    let s:hstry = empty(hst) || !s:maxhst ? [''] : hst
  endif
  for [ke, va] in items(s:glbs) | if exists('+'.ke)
    sil! exe 'let s:glb_'.ke.' = &'.ke.' | let &'.ke.' = '.string(va)
  en | endfor
cal s:setupblank()
endfunction

function! s:Close()
  if winnr('$') == 1
    bw!
  el
    try | bun!
    cat | clo! | endt
  endif
  for key in keys(s:glbs) | if exists('+'.key)
    sil! exe 'let &'.key.' = s:glb_'.key
  en | endfor
if exists('s:glb_acd') | let &acd = s:glb_acd | endif
let g:ctrlp_lines = []
if s:winres[1] >= &lines && s:winres[2] == winnr('$')
  exe s:winres[0].s:winres[0]
endif
unl! s:focus s:hisidx s:hstgot s:statypes s:cline s:init s:savestr
      \ s:mrbs s:did_exp
cal ctrlp#recordhist()
cal s:execextvar('exit')
let v:errmsg = s:ermsg
ec
endfunction
" * Reset {{{1
function! s:Reset(args)
  let opts = has_key(a:args, 'opts') ? [a:args['opts']] : []
  cal call('s:opts', opts)
  cal ctrlp#utils#opts()
  cal s:execextvar('opts')
endfunction
" * Files {{{1
function! ctrlp#files()
  let cafile = ctrlp#utils#cachefile()
  if !filereadable(cafile)
    let [lscmd, s:initcwd, g:ctrlp_allfiles] = [s:lsCmd(), s:dyncwd, []]
    " Get the list of files
    if empty(lscmd)
      if !ctrlp#igncwd(s:dyncwd)
        cal s:GlobPath(s:fnesc(s:dyncwd, 'g', ','), 0)
      endif
    el
      sil! cal ctrlp#progress('Indexing...')
      try | cal s:UserCmd(lscmd)
      cat | return [] | endt
    endif
    " Remove base directory
    cal ctrlp#rmbasedir(g:ctrlp_allfiles)
    let catime = getftime(cafile)
  el
    let catime = getftime(cafile)
    if !( exists('s:initcwd') && s:initcwd == s:dyncwd )
          \ || get(s:ficounts, s:dyncwd, [0, catime])[1] != catime
      let s:initcwd = s:dyncwd
      let g:ctrlp_allfiles = ctrlp#utils#readfile(cafile)
    endif
  endif
  cal extend(s:ficounts, { s:dyncwd : [len(g:ctrlp_allfiles), catime] })
  return g:ctrlp_allfiles
endfunction

function! s:GlobPath(dirs, depth)
  let entries = split(globpath(a:dirs, s:glob), "\n")
  let [dnf, depth] = [ctrlp#dirnfile(entries), a:depth + 1]
  cal extend(g:ctrlp_allfiles, dnf[1])
  if !empty(dnf[0]) && !s:maxf(len(g:ctrlp_allfiles)) && depth <= s:maxdepth
    sil! cal ctrlp#progress(len(g:ctrlp_allfiles), 1)
    cal s:GlobPath(join(map(dnf[0], 's:fnesc(v:val, "g", ",")'), ','), depth)
  endif
endfunction

function! s:UserCmd(lscmd)
  let [path, lscmd] = [s:dyncwd, a:lscmd]
  let do_ign =
        \ type(s:usrcmd) == 4 && has_key(s:usrcmd, 'ignore') && s:usrcmd['ignore']
  if do_ign && ctrlp#igncwd(s:cwd) | return | endif
  if exists('+ssl') && &ssl
    let [ssl, &ssl, path] = [&ssl, 0, tr(path, '/', '\')]
  endif
  if (has('win32') || has('win64')) && match(&shellcmdflag, "/") != -1
    let lscmd = substitute(lscmd, '\v(^|\&\&\s*)\zscd (/d)@!', 'cd /d ', '')
  endif
  let path = exists('*shellescape') ? shellescape(path) : path
  let g:ctrlp_allfiles = split(system(printf(lscmd, path)), "\n")
  if exists('+ssl') && exists('ssl')
    let &ssl = ssl
    cal map(g:ctrlp_allfiles, 'tr(v:val, "\\", "/")')
  endif
  if exists('s:vcscmd') && s:vcscmd
    cal map(g:ctrlp_allfiles, 'tr(v:val, "/", "\\")')
  endif
  if do_ign
    if &wig != ''
      cal filter(g:ctrlp_allfiles, 'glob(v:val) != ""')
    endif
  endif
endfunction

function! s:lsCmd()
  let cmd = s:usrcmd
  if type(cmd) == 1
    return cmd
  elsei type(cmd) == 3 && len(cmd) >= 2 && cmd[:1] != ['', '']
    if s:findroot(s:dyncwd, cmd[0], 0, 1) == []
      return len(cmd) == 3 ? cmd[2] : ''
    endif
    let s:vcscmd = s:lash == '\'
    return cmd[1]
  elsei type(cmd) == 4 && ( has_key(cmd, 'types') || has_key(cmd, 'fallback') )
    let fndroot = []
    if has_key(cmd, 'types') && cmd['types'] != {}
      let [markrs, cmdtypes] = [[], values(cmd['types'])]
      for pair in cmdtypes
        cal add(markrs, pair[0])
      endfor
      let fndroot = s:findroot(s:dyncwd, markrs, 0, 1)
    endif
    if fndroot == []
      return has_key(cmd, 'fallback') ? cmd['fallback'] : ''
    endif
    for pair in cmdtypes
      if pair[0] == fndroot[0] | brea | endif
    endfor
    let s:vcscmd = s:lash == '\'
    return pair[1]
  endif
endfunction
" * MatchedItems() {{{1
function! s:MatchIt(items, pat, limit, exc)
  let [lines, id] = [[], 0]
  let pat =
        \ s:byfname() ? map(split(a:pat, '^[^;]\+\\\@<!\zs;', 1), 's:martcs.v:val')
        \ : s:martcs.a:pat
  for item in a:items
    let id += 1
    try | if !( s:ispath && item == a:exc ) && call(s:mfunc, [item, pat]) >= 0
      cal add(lines, item)
    en | cat | brea | endt
    if a:limit > 0 && len(lines) >= a:limit | brea | endif
  endfor
  let s:mdata = [s:dyncwd, s:itemtype, s:regexp, s:sublist(a:items, id, -1)]
  return lines
endfunction

function! s:MatchedItems(items, pat, limit)
  let exc = exists('s:crfilerel') ? s:crfilerel : ''
  let items = s:narrowable() ? s:matched + s:mdata[3] : a:items
  let lines = s:MatchIt(items, a:pat, a:limit, exc)
  let s:matches = len(lines)
  unl! s:did_exp
  return lines
endfunction

function! s:SplitPattern(str)
  let str = a:str
  let s:savestr = str
  if s:regexp
    let pat = s:regexfilter(str)
  el
    let lst = split(str, '\zs')
    if exists('+ssl') && !&ssl
      cal map(lst, 'escape(v:val, ''\'')')
    endif
    for each in ['^', '$', '.']
      cal map(lst, 'escape(v:val, each)')
    endfor
  endif
  if exists('lst')
    let pat = ''
    if !empty(lst)
      if s:byfname() && index(lst, ';') > 0
        let fbar = index(lst, ';')
        let lst_1 = s:sublist(lst, 0, fbar - 1)
        let lst_2 = len(lst) - 1 > fbar ? s:sublist(lst, fbar + 1, -1) : ['']
        let pat = s:buildpat(lst_1).';'.s:buildpat(lst_2)
      el
        let pat = s:buildpat(lst)
      endif
    endif
  endif
  return escape(pat, '~')
endfunction
" * BuildPrompt() {{{1
function! s:Render(lines, pat)
  let [&ma, lines, s:res_count] = [1, a:lines, len(a:lines)]
  let height = min([max([s:mw_min, s:res_count]), s:winmaxh])
  let pat = s:byfname() ? split(a:pat, '^[^;]\+\\\@<!\zs;', 1)[0] : a:pat
  let cur_cmd = 'keepj norm! '.( s:mw_order == 'btt' ? 'G' : 'gg' ).'1|'
  " Setup the match window
  sil! exe '%d _ | res' height
  " Print the new items
  if empty(lines)
    let [s:matched, s:lines] = [[], []]
    let lines = [' == NO ENTRIES ==']
    cal setline(1, s:offset(lines, height - 1))
    setl noma nocul
    exe cur_cmd
    return
  endif
  let s:matched = copy(lines)
  if s:mw_order == 'btt' | cal reverse(lines) | endif
  let s:lines = copy(lines)
  cal map(lines, 's:formatline(v:val)')
  cal setline(1, s:offset(lines, height))
  setl noma cul
  exe cur_cmd
  if exists('s:cline') && s:nolim != 1
    cal cursor(s:cline, 1)
  endif
endfunction

function! s:Update(str)
  " Get the previous string if existed
  let oldstr = exists('s:savestr') ? s:savestr : ''
  " Get the new string sans tail
  let str = s:sanstail(a:str)
  " Stop if the string's unchanged
  if str == oldstr && !empty(str) && !exists('s:force') | return | endif
  let s:martcs = &scs && str =~ '\u' ? '\C' : ''
  let pat = s:SplitPattern(str)
  let lines = s:nolim == 1 && empty(str) ? copy(g:ctrlp_lines)
        \ : s:MatchedItems(g:ctrlp_lines, pat, s:mw_res)
  cal s:Render(lines, pat)
endfunction

function! s:ForceUpdate()
  sil! cal s:Update(escape(s:getinput(), '\'))
endfunction

function! s:BuildPrompt(upd)
  let base = ( s:regexp ? 'r' : '>' ).( s:byfname() ? 'd' : '>' ).'> '
  let str = escape(s:getinput(), '\')
  if a:upd && ( s:matches || s:regexp || exists('s:did_exp')
        \ || str =~ '\(\\\(<\|>\)\|[*|]\)\|\(\\\:\([^:]\|\\:\)*$\)' )
    sil! cal s:Update(str)
  endif
  sil! cal ctrlp#statusline()
  " Toggling
  let [hiactive, hicursor, base] = s:focus
        \ ? ['CtrlPPrtText', 'CtrlPPrtCursor', base]
        \ : ['CtrlPPrtBase', 'CtrlPPrtBase', tr(base, '>', '-')]
  let hibase = 'CtrlPPrtBase'
  " Build it
  redr
  let prt = copy(s:prompt)
  cal map(prt, 'escape(v:val, ''"\'')')
  exe 'echoh' hibase '| echon "'.base.'"
        \ | echoh' hiactive '| echon "'.prt[0].'"
        \ | echoh' hicursor '| echon "'.prt[1].'"
        \ | echoh' hiactive '| echon "'.prt[2].'" | echoh None'
  " Append the cursor at the end
  if empty(prt[1]) && s:focus
    exe 'echoh' hibase '| echon "_" | echoh None'
  endif
endfunction
" ** Prt Actions {{{1
" Editing {{{2
function! s:PrtClear()
  if !s:focus | return | endif
  unl! s:hstgot
  let [s:prompt, s:matches] = [['', '', ''], 1]
  cal s:BuildPrompt(1)
endfunction

function! s:PrtAdd(char)
  unl! s:hstgot
  let s:act_add = 1
  let s:prompt[0] .= a:char
  cal s:BuildPrompt(1)
  unl s:act_add
endfunction

function! s:PrtBS()
  if !s:focus | return | endif
  unl! s:hstgot
  let [s:prompt[0], s:matches] = [substitute(s:prompt[0], '.$', '', ''), 1]
  cal s:BuildPrompt(1)
endfunction

function! s:PrtDelete()
  if !s:focus | return | endif
  unl! s:hstgot
  let [prt, s:matches] = [s:prompt, 1]
  let prt[1] = matchstr(prt[2], '^.')
  let prt[2] = substitute(prt[2], '^.', '', '')
  cal s:BuildPrompt(1)
endfunction

function! s:PrtDeleteWord()
  if !s:focus | return | endif
  unl! s:hstgot
  let [str, s:matches] = [s:prompt[0], 1]
  let str = str =~ '\W\w\+$' ? matchstr(str, '^.\+\W\ze\w\+$')
        \ : str =~ '\w\W\+$' ? matchstr(str, '^.\+\w\ze\W\+$')
        \ : str =~ '\s\+$' ? matchstr(str, '^.*\S\ze\s\+$')
        \ : str =~ '\v^(\S+|\s+)$' ? '' : str
  let s:prompt[0] = str
  cal s:BuildPrompt(1)
endfunction

function! s:PrtExpandDir()
  if !s:focus | return | endif
  let str = s:getinput('c')
  if str =~ '\v^\@(cd|lc[hd]?|chd)\s.+' && s:spi
    let hasat = split(str, '\v^\@(cd|lc[hd]?|chd)\s*\zs')
    let str = get(hasat, 1, '')
    if str =~# '\v^[~$]\i{-}[\/]?|^#(\<?\d+)?:(p|h|8|\~|\.|g?s+)'
      let str = expand(s:fnesc(str, 'g'))
    elsei str =~# '\v^(\%|\<c\h{4}\>):(p|h|8|\~|\.|g?s+)'
      let spc = str =~# '^%' ? s:crfile
            \ : str =~# '^<cfile>' ? s:crgfile
            \ : str =~# '^<cword>' ? s:crword
            \ : str =~# '^<cWORD>' ? s:crnbword : ''
      let pat = '(:(p|h|8|\~|\.|g?s(.)[^\3]*\3[^\3]*\3))+'
      let mdr = matchstr(str, '\v^[^:]+\zs'.pat)
      let nmd = matchstr(str, '\v^[^:]+'.pat.'\zs.{-}$')
      let str = fnamemodify(s:fnesc(spc, 'g'), mdr).nmd
    endif
  endif
  if str == '' | return | endif
  unl! s:hstgot
  let s:act_add = 1
  let [base, seed] = s:headntail(str)
  if str =~# '^[\/]'
    let base = expand('/').base
  endif
  let dirs = s:dircompl(base, seed)
  if len(dirs) == 1
    let str = dirs[0]
  elsei len(dirs) > 1
    let str .= s:findcommon(dirs, str)
  endif
  let s:prompt[0] = exists('hasat') ? hasat[0].str : str
  cal s:BuildPrompt(1)
  unl s:act_add
endfunction
" Movement {{{2
function! s:PrtCurLeft()
  if !s:focus | return | endif
  let prt = s:prompt
  if !empty(prt[0])
    let s:prompt = [substitute(prt[0], '.$', '', ''), matchstr(prt[0], '.$'),
          \ prt[1] . prt[2]]
  endif
  cal s:BuildPrompt(0)
endfunction

function! s:PrtCurRight()
  if !s:focus | return | endif
  let prt = s:prompt
  let s:prompt = [prt[0] . prt[1], matchstr(prt[2], '^.'),
        \ substitute(prt[2], '^.', '', '')]
  cal s:BuildPrompt(0)
endfunction

function! s:PrtCurStart()
  if !s:focus | return | endif
  let str = join(s:prompt, '')
  let s:prompt = ['', matchstr(str, '^.'), substitute(str, '^.', '', '')]
  cal s:BuildPrompt(0)
endfunction

function! s:PrtCurEnd()
  if !s:focus | return | endif
  let s:prompt = [join(s:prompt, ''), '', '']
  cal s:BuildPrompt(0)
endfunction

function! s:PrtSelectMove(dir)
  let wht = winheight(0)
  let dirs = {'t': 'gg','b': 'G','j': 'j','k': 'k','u': wht.'k','d': wht.'j'}
  exe 'keepj norm!' dirs[a:dir]
  if s:nolim != 1 | let s:cline = line('.') | endif
  if line('$') > winheight(0) | cal s:BuildPrompt(0) | endif
endfunction

function! s:PrtSelectJump(char)
  let lines = copy(s:lines)
  if s:byfname()
    cal map(lines, 'split(v:val, ''[\/]\ze[^\/]\+$'')[-1]')
  endif
  " Cycle through matches, use s:jmpchr to store last jump
  let chr = escape(matchstr(a:char, '^.'), '.~')
  let smartcs = &scs && chr =~ '\u' ? '\C' : ''
  if match(lines, smartcs.'^'.chr) >= 0
    " If not exists or does but not for the same char
    let pos = match(lines, smartcs.'^'.chr)
    if !exists('s:jmpchr') || ( exists('s:jmpchr') && s:jmpchr[0] != chr )
      let [jmpln, s:jmpchr] = [pos, [chr, pos]]
    elsei exists('s:jmpchr') && s:jmpchr[0] == chr
      " Start of lines
      if s:jmpchr[1] == -1 | let s:jmpchr[1] = pos | endif
      let npos = match(lines, smartcs.'^'.chr, s:jmpchr[1] + 1)
      let [jmpln, s:jmpchr] = [npos == -1 ? pos : npos, [chr, npos]]
    endif
    exe 'keepj norm!' ( jmpln + 1 ).'G'
    if s:nolim != 1 | let s:cline = line('.') | endif
    if line('$') > winheight(0) | cal s:BuildPrompt(0) | endif
  endif
endfunction
" Misc {{{2
function! s:PrtFocusMap(char)
  cal call(( s:focus ? 's:PrtAdd' : 's:PrtSelectJump' ), [a:char])
endfunction

function! s:PrtExit()
  if bufnr('%') == s:bufnr && bufname('%') == 'ControlP'
    noa cal s:Close()
    noa winc p
  endif
endfunction

function! s:PrtHistory(...)
  if !s:focus || !s:maxhst | return | endif
  let [str, hst, s:matches] = [join(s:prompt, ''), s:hstry, 1]
  " Save to history if not saved before
  let [hst[0], hslen] = [exists('s:hstgot') ? hst[0] : str, len(hst)]
  let idx = exists('s:hisidx') ? s:hisidx + a:1 : a:1
  " Limit idx within 0 and hslendif
  let idx = idx < 0 ? 0 : idx >= hslen ? hslen > 1 ? hslen - 1 : 0 : idx
  let s:prompt = [hst[idx], '', '']
  let [s:hisidx, s:hstgot, s:force] = [idx, 1, 1]
  cal s:BuildPrompt(1)
  unl s:force
endfunction
"}}}1
" * Mappings {{{1
function! s:MapNorms()
  if exists('s:nmapped') && s:nmapped == s:bufnr | return | endif
  let pcmd = "nn \<buffer> \<silent> \<k%s> :\<c-u>cal \<SID>%s(\"%s\")\<cr>"
  let cmd = substitute(pcmd, 'k%s', 'char-%d', '')
  let pfunc = 'PrtFocusMap'
  let ranges = [32, 33, 125, 126] + range(35, 91) + range(93, 123)
  for each in [34, 92, 124]
    exe printf(cmd, each, pfunc, escape(nr2char(each), '"|\'))
  endfor
  for each in ranges
    exe printf(cmd, each, pfunc, nr2char(each))
  endfor
  for each in range(0, 9)
    exe printf(pcmd, each, pfunc, each)
  endfor
  let s:nmapped = s:bufnr
endfunction

function! s:MapSpecs()
  if !( exists('s:smapped') && s:smapped == s:bufnr )
    " Correct arrow keys in terminal
    if ( has('termresponse') && v:termresponse =~ "\<ESC>" )
          \ || &term =~? '\vxterm|<k?vt|gnome|screen|linux|ansi'
      for each in ['\A <up>','\B <down>','\C <right>','\D <left>']
        exe s:lcmap.' <esc>['.each
      endfor
    endif
  endif
  for [ke, va] in items(s:prtmaps) | for kp in va
    exe s:lcmap kp ':<c-u>cal <SID>'.ke.'<cr>'
  endfo | endfor
let s:smapped = s:bufnr
endfunction
" * Toggling {{{1
function! s:ToggleRegex()
  let s:regexp = !s:regexp
  cal s:PrtSwitcher()
endfunction

function! s:ToggleByFname()
  if s:ispath
    let s:byfname = !s:byfname
    let s:mfunc = s:mfunc()
    cal s:PrtSwitcher()
  endif
endfunction

function! s:PrtSwitcher()
  let [s:force, s:matches] = [1, 1]
  cal s:BuildPrompt(1)
  unl s:force
endfunction
" - SetWD() {{{1
function! s:SetWD(args)
  if has_key(a:args, 'args') && stridx(a:args['args'], '--dir') >= 0
        \ && exists('s:dyncwd')
    cal ctrlp#setdir(s:dyncwd) | return
  endif
  if has_key(a:args, 'dir') && a:args['dir'] != ''
    cal ctrlp#setdir(a:args['dir']) | return
  endif
  let pmodes = has_key(a:args, 'mode') ? a:args['mode'] : s:pathmode
  let [s:crfilerel, s:dyncwd] = [fnamemodify(s:crfile, ':.'), getcwd()]
  if (!type(pmodes))
    let pmodes =
          \ pmodes == 0 ? '' :
          \ pmodes == 1 ? 'a' :
          \ pmodes == 2 ? 'r' :
          \ 'c'
  endif
  let spath = pmodes =~ 'd' ? s:dyncwd : pmodes =~ 'w' ? s:cwd : s:crfpath
  for pmode in split(pmodes, '\zs')
    if ctrlp#setpathmode(pmode, spath) | return | endif
  endfor
endfunction
" * AcceptSelection() {{{1
function! ctrlp#acceptfile(...)
  let useb = 0
  if a:0 == 1 && type(a:1) == 4
    let [md, line] = [a:1['action'], a:1['line']]
    let atl = has_key(a:1, 'tail') ? a:1['tail'] : ''
  el
    let [md, line] = [a:1, a:2]
    let atl = a:0 > 2 ? a:3 : ''
  endif
  if !type(line)
    let [filpath, bufnr, useb] = [line, line, 1]
  el
    let filpath = fnamemodify(line, ':p')
    if s:nonamecond(line, filpath)
      let bufnr = str2nr(matchstr(line, '[\/]\?\[\zs\d\+\ze\*No Name\]$'))
      let [filpath, useb] = [bufnr, 1]
    el
      let bufnr = bufnr('^'.filpath.'$')
    endif
  endif
  cal s:PrtExit()
  let tail = s:tail()
  let j2l = atl != '' ? atl : matchstr(tail, '^ +\zs\d\+$')
  if ( s:jmptobuf =~ md || ( !empty(s:jmptobuf) && s:jmptobuf !~# '\v^0$' && md =~ '[et]' ) ) && bufnr > 0
        \ && !( md == 'e' && bufnr == bufnr('%') )
    let [jmpb, bufwinnr] = [1, bufwinnr(bufnr)]
    let buftab = ( s:jmptobuf =~# '[tTVH]' || s:jmptobuf > 1 )
          \ ? s:buftab(bufnr, md) : [0, 0]
  endif
  " Switch to existing buffer or open new one
  if exists('jmpb') && bufwinnr > 0
        \ && !( md == 't' && ( s:jmptobuf !~# toupper(md) || buftab[0] ) )
    exe bufwinnr.'winc w'
    if j2l | cal ctrlp#j2l(j2l) | endif
  elsei exists('jmpb') && buftab[0]
        \ && !( md =~ '[evh]' && s:jmptobuf !~# toupper(md) )
    exe 'tabn' buftab[0]
    exe buftab[1].'winc w'
    if j2l | cal ctrlp#j2l(j2l) | endif
  el
    " Determine the command to use
    let useb = bufnr > 0 && buflisted(bufnr) && ( empty(tail) || useb )
    let cmd =
          \ md == 't' || s:splitwin == 1 ? ( useb ? 'tab sb' : 'tabe' ) :
          \ md == 'h' || s:splitwin == 2 ? ( useb ? 'sb' : 'new' ) :
          \ md == 'v' || s:splitwin == 3 ? ( useb ? 'vert sb' : 'vne' ) :
          \ call('ctrlp#normcmd', useb ? ['b', 'bo vert sb'] : ['e'])
    " Reset &switchbuf option
    let [swb, &swb] = [&swb, '']
    " Open new window/buffer
    let [fid, tail] = [( useb ? bufnr : filpath ), ( atl != '' ? ' +'.atl : tail )]
    let args = [cmd, fid, tail, 1, [useb, j2l]]
    cal call('s:openfile', args)
    let &swb = swb
  endif
endfunction

function! s:SpecInputs(str)
  if a:str =~ '\v^(\.\.([\/]\.\.)*[\/]?[.\/]*)$' && s:spi
    let cwd = s:dyncwd
    cal ctrlp#setdir(a:str =~ '^\.\.\.*$' ?
          \ '../'.repeat('../', strlen(a:str) - 2) : a:str)
    if cwd != s:dyncwd | cal ctrlp#setlines() | endif
    cal s:PrtClear()
    return 1
  elsei a:str == s:lash && s:spi
    cal s:SetWD({ 'mode': 'rd' })
    cal ctrlp#setlines()
    cal s:PrtClear()
    return 1
  elsei a:str =~ '^@.\+' && s:spi
    return s:at(a:str)
  elsei a:str == '?'
    cal s:PrtExit()
    let hlpwin = &columns > 159 ? '| vert res 80' : ''
    sil! exe 'bo vert h ctrlp-mappings' hlpwin '| norm! 0'
    return 1
  endif
  return 0
endfunction

function! s:AcceptSelection(action)
  let [md, icr] = [a:action[0], match(a:action, 'r') >= 0]
  let subm = icr || ( !icr && md == 'e' )
  let str = s:getinput()
  if subm | if s:SpecInputs(str) | return | en | endif
  " Get the selected line
  let line = ctrlp#getcline()
  if !subm && !s:itemtype && line == '' && line('.') > s:offset
        \ && str !~ '\v^(\.\.([\/]\.\.)*[\/]?[.\/]*|/|\\|\?|\@.+)$'
    cal s:CreateNewFile(md) | return
  endif
  if empty(line) | return | endif
  " Do something with it
  if s:itemtype < 3
    let [actfunc, type] = ['ctrlp#acceptfile', 'dict']
  el
    let [actfunc, exttype] = [s:getextvar('accept'), s:getextvar('act_farg')]
    let type = exttype == 'dict' ? exttype : 'list'
  endif
  let actargs = type == 'dict' ? [{ 'action': md, 'line': line, 'icr': icr }]
        \ : [md, line]
  cal call(actfunc, actargs)
endfunction
" - CreateNewFile() {{{1
function! s:CreateNewFile(...)
  let [md, str] = ['', s:getinput('n')]
  if empty(str) | return | endif
  if !a:0
    " Get the extra argument
    let md = s:argmaps(md, 1)
    if md == 'cancel' | return | endif
  endif
  let str = s:sanstail(str)
  let [base, fname] = s:headntail(str)
  if fname =~ '^[\/]$' | return | endif
  if base != '' | if isdirectory(ctrlp#utils#mkdir(base))
    let optyp = str | en | el | let optyp = fname
  endif
  if !exists('optyp') | return | endif
  let [filpath, tail] = [fnamemodify(optyp, ':p'), s:tail()]
  cal s:PrtExit()
  let cmd = md == 'r' ? ctrlp#normcmd('e') :
        \ s:newfop =~ '1\|t' || ( a:0 && a:1 == 't' ) || md == 't' ? 'tabe' :
        \ s:newfop =~ '2\|h' || ( a:0 && a:1 == 'h' ) || md == 'h' ? 'new' :
        \ s:newfop =~ '3\|v' || ( a:0 && a:1 == 'v' ) || md == 'v' ? 'vne' :
        \ ctrlp#normcmd('e')
  cal s:openfile(cmd, filpath, tail, 1)
endfunction

" ** Helper functions {{{1
" *** Paths {{{2
" Line formatting {{{3
function! s:formatline(str)
  let str = a:str
  if s:itemtype == 1
    let filpath = fnamemodify(str, ':p')
    let bufnr = s:nonamecond(str, filpath)
          \ ? str2nr(matchstr(str, '[\/]\?\[\zs\d\+\ze\*No Name\]$'))
          \ : bufnr('^'.filpath.'$')
    let idc = ( bufnr == bufnr('#') ? '#' : '' )
          \ . ( getbufvar(bufnr, '&ma') ? '' : '-' )
          \ . ( getbufvar(bufnr, '&ro') ? '=' : '' )
          \ . ( getbufvar(bufnr, '&mod') ? '+' : '' )
    let str .= idc != '' ? ' '.idc : ''
  endif
  let cond = s:ispath && ( s:winw - 4 ) < s:strwidth(str)
  return '> '.( cond ? s:pathshorten(str) : str )
endfunction

function! s:pathshorten(str)
  return matchstr(a:str, '^.\{9}').'...'
        \ .matchstr(a:str, '.\{'.( s:winw - 16 ).'}$')
endfunction

function! s:offset(lines, height)
  let s:offset = s:mw_order == 'btt' ? ( a:height - s:res_count ) : 0
  return s:offset > 0 ? ( repeat([''], s:offset) + a:lines ) : a:lines
endfunction
" Directory completion {{{3
function! s:dircompl(be, sd)
  if a:sd == '' | return [] | endif
  if a:be == ''
    let [be, sd] = [s:dyncwd, a:sd]
  el
    let be = a:be.s:lash(a:be)
    let sd = be.a:sd
  endif
  let dirs = split(globpath(s:fnesc(be, 'g', ','), a:sd.'*/'), "\n")
  if a:be == ''
    let dirs = ctrlp#rmbasedir(dirs)
  endif
  cal filter(dirs, '!match(v:val, escape(sd, ''~$.\''))'
        \ . ' && v:val !~ ''\v(^|[\/])\.{1,2}[\/]$''')
  return dirs
endfunction

function! s:findcommon(items, seed)
  let [items, id, cmn, ic] = [copy(a:items), strlen(a:seed), '', 0]
  cal map(items, 'strpart(v:val, id)')
  for char in split(items[0], '\zs')
    for item in items[1:]
      if item[ic] != char | let brk = 1 | brea | endif
    endfor
    if exists('brk') | brea | endif
    let cmn .= char
    let ic += 1
  endfor
  return cmn
endfunction
" Misc {{{3
function! s:headntail(str)
  let parts = split(a:str, '[\/]\ze[^\/]\+[\/:]\?$')
  return len(parts) == 1 ? ['', parts[0]] : len(parts) == 2 ? parts : []
endfunction

function! s:lash(...)
  return ( a:0 ? a:1 : s:dyncwd ) !~ '[\/]$' ? s:lash : ''
endfunction

function! s:ispathitem()
  return s:itemtype < 3 || ( s:itemtype > 2 && s:getextvar('type') == 'path' )
endfunction

function! ctrlp#dirnfile(entries)
  let [items, cwd] = [[[], []], s:dyncwd.s:lash()]
  for each in a:entries
    let etype = getftype(each)
    if etype == 'dir'
      if s:showhidden | if each !~ '[\/]\.\{1,2}$'
        cal add(items[0], each)
      en | el
        cal add(items[0], each)
      endif
    elsei etype == 'file'
      cal add(items[1], each)
    endif
  endfor
  return items
endfunction

function! s:samerootsyml(each, isfile, cwd)
  let resolve = fnamemodify(resolve(a:each), ':p:h')
  let resolve .= s:lash(resolve)
  return !( stridx(resolve, a:cwd) && ( stridx(a:cwd, resolve) || a:isfile ) )
endfunction

function! ctrlp#rmbasedir(items)
  let cwd = s:dyncwd.s:lash()
  if a:items != [] && !stridx(a:items[0], cwd)
    let idx = strlen(cwd)
    return map(a:items, 'strpart(v:val, idx)')
  endif
  return a:items
endfunction
" Working directory {{{3
function! s:getparent(item)
  let parent = substitute(a:item, '[\/][^\/]\+[\/:]\?$', '', '')
  if parent == '' || parent !~ '[\/]'
    let parent .= s:lash
  endif
  return parent
endfunction

function! s:findroot(curr, mark, depth, type)
  let [depth, fnd] = [a:depth + 1, 0]
  if type(a:mark) == 1
    let fnd = s:glbpath(s:fnesc(a:curr, 'g', ','), a:mark, 1) != ''
  elsei type(a:mark) == 3
    for markr in a:mark
      if s:glbpath(s:fnesc(a:curr, 'g', ','), markr, 1) != ''
        let fnd = 1
        brea
      endif
    endfor
  endif
  if fnd
    if !a:type | cal ctrlp#setdir(a:curr) | endif
    return [exists('markr') ? markr : a:mark, a:curr]
  elsei depth > s:maxdepth
    cal ctrlp#setdir(s:cwd)
  el
    let parent = s:getparent(a:curr)
    if parent != a:curr
      return s:findroot(parent, a:mark, depth, a:type)
    endif
  endif
  return []
endfunction

function! ctrlp#setpathmode(pmode, ...)
  if a:pmode == 'c' || ( a:pmode == 'a' && stridx(s:crfpath, s:cwd) < 0 )
    if exists('+acd') | let [s:glb_acd, &acd] = [&acd, 0] | endif
    cal ctrlp#setdir(s:crfpath)
    return 1
  elsei a:pmode == 'r'
    let spath = a:0 ? a:1 : s:crfpath
    let markers = ['.git', '.hg', '.svn', '.bzr', '_darcs']
    if type(s:rmarkers) == 3 && !empty(s:rmarkers)
      if s:findroot(spath, s:rmarkers, 0, 0) != [] | return 1 | endif
      cal filter(markers, 'index(s:rmarkers, v:val) < 0')
    endif
    if s:findroot(spath, markers, 0, 0) != [] | return 1 | endif
  endif
  return 0
endfunction

function! ctrlp#setdir(path, ...)
  let cmd = a:0 ? a:1 : 'lc!'
  sil! exe cmd s:fnesc(a:path, 'c')
  let [s:crfilerel, s:dyncwd] = [fnamemodify(s:crfile, ':.'), getcwd()]
endfunction
" Fallbacks {{{3
function! s:glbpath(...)
  return call('ctrlp#utils#globpath', a:000)
endfunction

function! s:fnesc(...)
  return call('ctrlp#utils#fnesc', a:000)
endfunction

function! ctrlp#setlcdir()
  if exists('*haslocaldir')
    cal ctrlp#setdir(getcwd(), haslocaldir() ? 'lc!' : 'cd!')
  endif
endfunction
" Prompt history {{{2
function! s:gethistloc()
  let utilcadir = ctrlp#utils#cachedir()
  let cache_dir = utilcadir.s:lash(utilcadir).'hist'
  return [cache_dir, cache_dir.s:lash(cache_dir).'cache.txt']
endfunction

function! s:gethistdata()
  return ctrlp#utils#readfile(s:gethistloc()[1])
endfunction

function! ctrlp#recordhist()
  let str = join(s:prompt, '')
  if empty(str) || !s:maxhst | return | endif
  let hst = s:hstry
  if len(hst) > 1 && hst[1] == str | return | endif
  cal extend(hst, [str], 1)
  if len(hst) > s:maxhst | cal remove(hst, s:maxhst, -1) | endif
  cal ctrlp#utils#writecache(hst, s:gethistloc()[0], s:gethistloc()[1])
endfunction
" Lists & Dictionaries {{{2
function! s:sublist(l, s, e)
  return v:version > 701 ? a:l[(a:s):(a:e)] : s:sublist7071(a:l, a:s, a:e)
endfunction

function! s:sublist7071(l, s, e)
  let [newlist, id, ae] = [[], a:s, a:e == -1 ? len(a:l) - 1 : a:e]
  wh id <= ae
    cal add(newlist, get(a:l, id))
    let id += 1
  endw
  return newlist
endfunction
" Buffers {{{2
function! s:buftab(bufnr, md)
  for tabnr in range(1, tabpagenr('$'))
    if tabpagenr() == tabnr && a:md == 't' | con | endif
    let buflist = tabpagebuflist(tabnr)
    if index(buflist, a:bufnr) >= 0
      for winnr in range(1, tabpagewinnr(tabnr, '$'))
        if buflist[winnr - 1] == a:bufnr | return [tabnr, winnr] | endif
      endfor
    endif
  endfor
  return [0, 0]
endfunction

function! s:bufwins(bufnr)
  let winns = 0
  for tabnr in range(1, tabpagenr('$'))
    let winns += count(tabpagebuflist(tabnr), a:bufnr)
  endfor
  return winns
endfunction

function! s:nonamecond(str, filpath)
  return a:str =~ '[\/]\?\[\d\+\*No Name\]$' && !filereadable(a:filpath)
        \ && bufnr('^'.a:filpath.'$') < 1
endfunction

function! ctrlp#normcmd(cmd, ...)
  if a:0 < 2 | return a:cmd | endif
  let norwins = filter(range(1, winnr('$')),
        \ 'empty(getbufvar(winbufnr(v:val), "&bt"))')
  for each in norwins
    let bufnr = winbufnr(each)
    if empty(bufname(bufnr)) && empty(getbufvar(bufnr, '&ft'))
      let fstemp = each | brea
    endif
  endfor
  let norwin = empty(norwins) ? 0 : norwins[0]
  if norwin
    if index(norwins, winnr()) < 0
      exe ( exists('fstemp') ? fstemp : norwin ).'winc w'
    endif
    return a:cmd
  endif
  return a:0 ? a:1 : 'bo vne'
endfunction

function! ctrlp#modfilecond(w)
  return &mod && !&hid && &bh != 'hide' && s:bufwins(bufnr('%')) == 1 && !&cf &&
        \ ( ( !&awa && a:w ) || filewritable(fnamemodify(bufname('%'), ':p')) != 1 )
endfunction

function! s:setupblank()
  setl noswf nonu nobl nowrap nolist nospell nocuc wfh
  setl fdc=0 fdl=99 tw=0 bt=nofile bh=unload
  if v:version > 702
    setl nornu noudf cc=0
  endif
endfunction

function! s:leavepre()
  if exists('s:bufnr') && s:bufnr == bufnr('%') | bw! | endif
endfunction

function! s:checkbuf()
  if !exists('s:init') && exists('s:bufnr') && s:bufnr > 0
    exe s:bufnr.'bw!'
  endif
endfunction

function! s:iscmdwin()
  let ermsg = v:errmsg
  sil! noa winc p
  sil! noa winc p
  let [v:errmsg, ermsg] = [ermsg, v:errmsg]
  return ermsg =~ '^E11:'
endfunction
" Arguments {{{2
function! s:at(str)
  if a:str =~ '\v^\@(cd|lc[hd]?|chd).*'
    let str = substitute(a:str, '\v^\@(cd|lc[hd]?|chd)\s*', '', '')
    if str == '' | return 1 | endif
    let str = str =~ '^%:.\+' ? fnamemodify(s:crfile, str[1:]) : str
    let path = fnamemodify(expand(str, 1), ':p')
    if isdirectory(path)
      if path != s:dyncwd
        cal ctrlp#setdir(path)
        cal ctrlp#setlines()
      endif
      cal ctrlp#recordhist()
      cal s:PrtClear()
    endif
    return 1
  endif
  return 0
endfunction

function! s:tail()
  if exists('s:optail') && !empty('s:optail')
    let tailpref = s:optail !~ '^\s*+' ? ' +' : ' '
    return tailpref.s:optail
  endif
  return ''
endfunction

function! s:sanstail(str)
  let str = s:spi ?
        \ substitute(a:str, '^\(@.*$\|\\\\\ze@\|\.\.\zs[.\/]\+$\)', '', 'g') : a:str
  let [str, pat] = [substitute(str, '\\\\', '\', 'g'), '\([^:]\|\\:\)*$']
  unl! s:optail
  if str =~ '\\\@<!:'.pat
    let s:optail = matchstr(str, '\\\@<!:\zs'.pat)
    let str = substitute(str, '\\\@<!:'.pat, '', '')
  endif
  return substitute(str, '\\\ze:', '', 'g')
endfunction

function! s:argmaps(md, i)
  let roh = [
        \ ['Open Multiple Files', '/h[i]dden/[c]lear', ['i', 'c']],
        \ ['Create a New File', '/[r]eplace', ['r']],
        \ ['Open Selected', '/[r]eplace', ['r', 'd', 'a']],
        \ ]
  if a:i == 2
    if !buflisted(bufnr('^'.fnamemodify(ctrlp#getcline(), ':p').'$'))
      let roh[2][1] .= '/h[i]dden'
      let roh[2][2] += ['i']
    endif
  endif
  let str = roh[a:i][0].': [t]ab/[v]ertical/[h]orizontal'.roh[a:i][1].'? '
  return s:choices(str, ['t', 'v', 'h'] + roh[a:i][2], 's:argmaps', [a:md, a:i])
endfunction

function! s:insertstr()
  let str = 'Insert: c[w]ord/c[f]ile/[s]earch/[v]isual/[c]lipboard/[r]egister? '
  return s:choices(str, ['w', 'f', 's', 'v', 'c', 'r'], 's:insertstr', [])
endfunction

function! s:textdialog(str)
  redr | echoh MoreMsg | echon a:str | echoh None
  return nr2char(getchar())
endfunction

function! s:choices(str, choices, func, args)
  let char = s:textdialog(a:str)
  if index(a:choices, char) >= 0
    return char
  elsei char =~# "\\v\<Esc>|\<C-c>|\<C-g>|\<C-u>|\<C-w>|\<C-[>"
    cal s:BuildPrompt(0)
    return 'cancel'
  elsei char =~# "\<CR>" && a:args != []
    return a:args[0]
  endif
  return call(a:func, a:args)
endfunction

function! s:getregs()
  let char = s:textdialog('Insert from register: ')
  if char =~# "\\v\<Esc>|\<C-c>|\<C-g>|\<C-u>|\<C-w>|\<C-[>"
    cal s:BuildPrompt(0)
    return -1
  elsei char =~# "\<CR>"
    return s:getregs()
  endif
  return s:regisfilter(char)
endfunction

function! s:regisfilter(reg)
  return substitute(getreg(a:reg), "[\t\n]", ' ', 'g')
endfunction
" Misc {{{2
function! s:modevar()
  let s:matchtype = 'path'
  let s:ispath = s:ispathitem()
  let s:mfunc = s:mfunc()
  let s:nolim = s:getextvar('nolim')
  let s:dosort = s:getextvar('sort')
  let s:spi = !s:itemtype || s:getextvar('specinput') > 0
endfunction

function! s:nosort()
  return s:nolim == 1 || ( s:itemtype == 2 )
        \ || ( s:itemtype =~ '\v^(1|2)$' && s:prompt == ['', '', ''] ) || !s:dosort
endfunction

function! s:byfname()
  return s:ispath && s:byfname
endfunction

function! s:narrowable()
  return exists('s:act_add') && exists('s:matched') && s:matched != []
        \ && exists('s:mdata') && s:mdata[:2] == [s:dyncwd, s:itemtype, s:regexp]
        \ && !exists('s:did_exp')
endfunction

function! s:getinput(...)
  let [prt, spi] = [s:prompt, ( a:0 ? a:1 : '' )]
  return spi == 'c' ? prt[0] : join(prt, '')
endfunction

function! s:strwidth(str)
  return exists('*strdisplaywidth') ? strdisplaywidth(a:str) : strlen(a:str)
endfunction

function! ctrlp#j2l(nr)
  exe 'norm!' a:nr.'G'
  sil! norm! zvzz
endfunction

function! s:maxf(len)
  return s:maxfiles && a:len > s:maxfiles
endfunction

function! s:regexfilter(str)
  let str = a:str
  for key in keys(s:fpats) | if str =~ key
    let str = substitute(str, s:fpats[key], '', 'g')
  en | endfor
return str
endfunction

function! s:walker(m, p, d)
  return a:d >= 0 ? a:p < a:m ? a:p + a:d : 0 : a:p > 0 ? a:p + a:d : a:m
endfunction

function! s:delent(rfunc)
  if a:rfunc == '' | return | endif
  let [s:force, tbrem] = [1, []]
  if tbrem == [] && ( has('dialog_gui') || has('dialog_con') ) &&
        \ confirm("Wipe all entries?", "&OK\n&Cancel") != 1
    unl s:force
    cal s:BuildPrompt(0)
    return
  endif
  let g:ctrlp_lines = call(a:rfunc, [tbrem])
  cal s:BuildPrompt(1)
  unl s:force
endfunction
" Entering & Exiting {{{2
function! s:getenv()
  let [s:cwd, s:winres] = [getcwd(), [winrestcmd(), &lines, winnr('$')]]
  let [s:crword, s:crnbword] = [expand('<cword>', 1), expand('<cWORD>', 1)]
  let [s:crgfile, s:crline] = [expand('<cfile>', 1), getline('.')]
  let [s:winmaxh, s:crcursor] = [min([s:mw_max, &lines]), getpos('.')]
  let [s:crbufnr, s:crvisual] = [bufnr('%'), s:lastvisual()]
  let s:crfile = bufname('%') == ''
        \ ? '['.s:crbufnr.'*No Name]' : expand('%:p', 1)
  let s:crfpath = expand('%:p:h', 1)
endfunction

function! s:lastvisual()
  let cview = winsaveview()
  let [ovreg, ovtype] = [getreg('v'), getregtype('v')]
  let [oureg, outype] = [getreg('"'), getregtype('"')]
  sil! norm! gv"vy
  let selected = s:regisfilter('v')
  cal setreg('v', ovreg, ovtype)
  cal setreg('"', oureg, outype)
  cal winrestview(cview)
  return selected
endfunction

function! s:openfile(cmd, fid, tail, chkmod, ...)
  let cmd = a:cmd
  if a:chkmod && cmd =~ '^[eb]$' && ctrlp#modfilecond(!( cmd == 'b' && &aw ))
    let cmd = cmd == 'b' ? 'sb' : 'sp'
  endif
  let cmd = cmd =~ '^tab' ? ctrlp#tabcount().cmd : cmd
  let j2l = a:0 && a:1[0] ? a:1[1] : 0
  exe cmd.( a:0 && a:1[0] ? '' : a:tail ) s:fnesc(a:fid, 'f')
  if j2l
    cal ctrlp#j2l(j2l)
  endif
  if !empty(a:tail)
    sil! norm! zvzz
  endif
  if cmd != 'bad'
    cal ctrlp#setlcdir()
  endif
endfunction

function! ctrlp#tabcount()
  if exists('s:tabct')
    let tabct = s:tabct
    let s:tabct += 1
  elsei !type(s:tabpage)
    let tabct = s:tabpage
  elsei type(s:tabpage) == 1
    let tabpos =
          \ s:tabpage =~ 'c' ? tabpagenr() :
          \ s:tabpage =~ 'f' ? 1 :
          \ s:tabpage =~ 'l' ? tabpagenr('$') :
          \ tabpagenr()
    let tabct =
          \ s:tabpage =~ 'a' ? tabpos :
          \ s:tabpage =~ 'b' ? tabpos - 1 :
          \ tabpos
  endif
  return tabct < 0 ? 0 : tabct
endfunction

function! s:settype(type)
  return a:type < 0 ? exists('s:itemtype') ? s:itemtype : 0 : a:type
endfunction
" Matching {{{2
function! s:matchfname(item, pat)
  let parts = split(a:item, '[\/]\ze[^\/]\+$')
  let mfn = match(parts[-1], a:pat[0])
  return len(a:pat) == 1 ? mfn : len(a:pat) == 2 ?
        \ ( mfn >= 0 && ( len(parts) == 2 ? match(parts[0], a:pat[1]) : -1 ) >= 0
        \ ? 0 : -1 ) : -1
endfunction

function! s:matchtabs(item, pat)
  return match(split(a:item, '\t\+')[0], a:pat)
endfunction

function! s:matchtabe(item, pat)
  return match(split(a:item, '\t\+[^\t]\+$')[0], a:pat)
endfunction

function! s:buildpat(lst)
  let pat = a:lst[0]
  for item in range(1, len(a:lst) - 1)
    let pat .= '[^'.a:lst[item - 1].']\{-}'.a:lst[item]
  endfor
  return pat
endfunction

function! s:mfunc()
  let mfunc = 'match'
  if s:byfname()
    let mfunc = 's:matchfname'
  elsei s:itemtype > 2
    let matchtypes = { 'tabs': 's:matchtabs', 'tabe': 's:matchtabe' }
    if has_key(matchtypes, s:matchtype)
      let mfunc = matchtypes[s:matchtype]
    endif
  endif
  return mfunc
endfunction

function! s:mmode()
  let matchmodes = {
        \ 'match': 'full-line',
        \ 's:matchfname': 'filename-only',
        \ 's:matchtabs': 'first-non-tab',
        \ 's:matchtabe': 'until-last-tab',
        \ }
  return matchmodes[s:mfunc]
endfunction
" Extensions {{{2
function! s:execextvar(key)
  if !empty(g:ctrlp_ext_vars)
    cal map(filter(copy(g:ctrlp_ext_vars),
          \ 'has_key(v:val, a:key)'), 'eval(v:val[a:key])')
  endif
endfunction

function! s:getextvar(key)
  if s:itemtype > 2
    let vars = g:ctrlp_ext_vars[s:itemtype - 3]
    return has_key(vars, a:key) ? vars[a:key] : -1
  endif
  return get(g:, 'ctrlp_' . s:matchtype . '_' . a:key, -1)
endfunction

function! ctrlp#getcline()
  let [linenr, offset] = [line('.'), ( s:offset > 0 ? s:offset : 0 )]
  return !empty(s:lines) && !( offset && linenr <= offset )
        \ ? s:lines[linenr - 1 - offset] : ''
endfunction

"}}}1
" * Initialization {{{1
function! ctrlp#setlines(...)
  if a:0 | let s:itemtype = a:1 | endif
  cal s:modevar()
  let types = ['ctrlp#files()']
  let g:ctrlp_lines = eval(types[s:itemtype])
endfunction

function! ctrlp#init(type, ...)
  if exists('s:init') || s:iscmdwin() | return | endif
  let [s:ermsg, v:errmsg] = [v:errmsg, '']
  let [s:matches, s:init] = [1, 1]
  cal s:Reset(a:0 ? a:1 : {})
  noautocmd call s:Open()
  cal s:SetWD(a:0 ? a:1 : {})
  cal s:MapNorms()
  cal s:MapSpecs()
  cal ctrlp#setlines(s:settype(a:type))
  cal s:BuildPrompt(1)
endfunction
" - Autocmds {{{1
if has('autocmd')
  aug CtrlPAug
    au!
    au BufEnter ControlP cal s:checkbuf()
    au BufLeave ControlP noa cal s:Close()
    au VimLeavePre * cal s:leavepre()
  aug END
endif
"}}}

" vim: fen
