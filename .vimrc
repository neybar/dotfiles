" General Settings 
set nocompatible
set history=300		" keep 50 lines of command line history
" With a map leader it's possible to do extra key combinations
" like <leader>w saves the current file
let mapleader = ","
let g:mapleader = ","

" Fast saving
nmap <leader>w :w!<cr>

" user interface
" backspace config
set backspace=indent,eol,start
set whichwrap+=<,>,h,l
set wildmenu        " Turn on wild menu
set ruler	    	" show the cursor position all the time
set autoindent		" always set autoindenting on
if has("vms")
  set nobackup		" do not keep a backup file, use versions instead
else
  set backup		" keep a backup file
endif
set backupdir=~/.vim/backups
set directory=~/.vim/swaps
if exists("&undodir")
    set undodir=~/.vim/undo
endif
set showcmd	    	" display incomplete commands
set ignorecase      " ignore case when searching
set smartcase       " don't ignore case when looking for Caps
set hlsearch        " highlight search terms
set incsearch       " show partial search matches
set magic           " set magic on for regex
set showmatch       " show matching brackets when text indicator is over them
set mat=2           " how long to blink the brackets
set cursorline      " underline the current line

"No sound on errors
set noerrorbells
set novisualbell
set t_vb=

map  <F12> :nohlsearch<CR>
nmap <F5> :make <cr>
set pastetoggle=<F11>
set autowrite
set wildmode=list:longest
set shiftround
set updatecount=10 "save file every 10 keystrokes?
set modeline
set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [ASCII=\%03.3b]\ [HEX=\%02.2B]\ [POS=%04l,%04v][%p%%]\ [LEN=%L]
set laststatus=2
set virtualedit=block
set scrolloff=3    "Start scrolling three lines before bottom of window

"colors and fonts
syntax enable
colors desert
set background=dark
set ffs=unix,dos,mac "Default file types
          
if has("gui_running")
    set guioptions-=T
    set t_Co=256
    set nu
endif

"Text, tab and indent related
set expandtab "turn tabs into spaces
set shiftwidth=4
set tabstop=4
set smarttab "might need to remove this
set foldlevelstart=1


set ai "Auto indent
set si "Smart indent
"disable clearing to the begining of the line when entering #
"inoremap # X# 
set wrap "Wrap lines

"Allow searching in visual block
:vnoremap <M-/> <Esc>/\%V

map <leader>t2 :setlocal shiftwidth=2<cr>
map <leader>t4 :setlocal shiftwidth=4<cr>
map <leader>t8 :setlocal shiftwidth=8<cr>

"Save a file as root (,W)
noremap <leader>W :w !sudo tee % > /dev/null<CR>

"Cope
" Do :help cope if you are unsure what cope is. It's super useful!
map <leader>bc :botright cope<cr>
map <leader>n :cn<cr>
map <leader>p :cp<cr>


"Spell checking
"Pressing ,ss will toggle and untoggle spell checking
map <leader>ss :setlocal spell!<cr>

"Shortcuts using <leader>
map <leader>sn ]s
map <leader>sp [s
map <leader>sa zg
map <leader>s? z=

"Set some vars to allow localvimrc plugin to work
let localvimrc_sandbox = 0
let localvimrc_persistent = 1

if &t_Co > 2 || has("gui_running")

  " InsertTabWrapper
  " " http://vim.sourceforge.net/tips/tip.php?tip_id=102
  function! InsertTabWrapper(direction)
     let col = col('.') - 1
     if !col || getline('.')[col - 1] !~ '\k'
        return "\<tab>"
     elseif "backward" == a:direction
        return "\<c-p>"
     else
        return "\<c-n>"
     endif
  endfunction

  inoremap <tab> <c-r>=InsertTabWrapper ("forward")<cr>
  inoremap <s-tab> <c-r>=InsertTabWrappe ("backward")<cr>
endif

" Enable file type detection.
" Use the default filetype settings, so that mail gets 'tw' set to 72,
" 'cindent' is on in C files, etc.
" Also load indent files, to automatically do language-dependent indenting.
filetype plugin indent on

" Only do this part when compiled with support for autocommands.
if has("autocmd")

  augroup vimrc_autocmd
    autocmd!
    " For all text files set 'textwidth' to 78 characters.
    autocmd FileType text setlocal textwidth=78

    " When editing a file, always jump to the last known cursor position.
    " Don't do it when the position is invalid or when inside an event handler
    " (happens when dropping a file on gvim).
    autocmd BufReadPost *
      \ if line("'\"") > 0 && line("'\"") <= line("$") |
      \   exe "normal g`\"" |
      \ endif

    " Don't screw up folds when inserting text that might affect them, until
    " leaving insert mode. Foldmethod is local to the window. Protect against
    " screwing up folding when switching between windows.
    " NOTE: this is disabled because re-enabling the syntax folding was
    " causing significant delays
    " autocmd InsertEnter * if !exists('w:last_fdm') | let w:last_fdm=&foldmethod | setlocal foldmethod=manual | endif
    " autocmd InsertLeave,WinLeave * if exists('w:last_fdm') | let &l:foldmethod=w:last_fdm | unlet w:last_fdm | endif
  augroup END
  
  if exists("+omnifunc")
      augroup vimrc_autocmd_omnifunc
        autocmd!
        autocmd Filetype *
                    \	if &omnifunc == "" |
                    \		setlocal omnifunc=syntaxcomplete#Complete |
                    \	endif
      augroup END
  endif

endif " has("autocmd")


fu! DoPrettyXML()
    " save the filetype so we can restore it later
    let l:origft = &ft
    set ft=

    " delete the xml header if it exists.  This will
    " permit us to surround the document with fake tags
    " without creating invalid xml.
    1,1s/<?xml .*?>//

    " insert fake tags around the entire document.
    " This will permit us to pretty-format excerpts of
    " XML that may contain multiple top-level elements.
    1
    exe "norm! O<PrettyXML>"
    exe "norm! Go</PrettyXML>"


    silent %!xmllint --format -

    " xmllint will insert an <?xml?> header.  it's easy enough to delete
    " if you don't want it.

    " delete the fake tags
    2
    exe "norm ddGdd"

    " restore the 'normal' indentation, which is one extra level
    " too deep due to the extra tags we wrapped around the document.
    silent %<

    " back to home
    1

    " restore the filetype
    exe "set ft=" . l:origft
endfu

command! PrettyXML call DoPrettyXML()

nmap <leader>t :TlistToggle<cr>
       
" Remove the Windows ^M - when the encodings gets messed up
noremap <Leader>m mmHmt:%s/<C-V><cr>//ge<cr>'tzt'm
"
"                                             
