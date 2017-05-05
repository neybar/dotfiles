call plug#begin()

" General Utility Plugins {{{

" Matchit: Include matchit for vim < 7
if v:version >= 800
    packadd matchit
else
    Plug 'https://github.com/tmhedberg/matchit'
endif

" Localvimrc: Provides project specific vimrc files
Plug 'https://github.com/embear/vim-localvimrc'
let localvimrc_sandbox = 0
let localvimrc_persistent = 1

" VimPager: Using for convenient installer, but don't enable plugin
Plug 'rkitover/vimpager', { 'on': 'Page' }

" Repeat: Let "." repeat more things
Plug 'tpope/vim-repeat'

" Airline: lightweight powerline plugin
Plug 'vim-airline/vim-airline'
let g:airline_powerline_fonts = 1
let g:airline_inactive_collapse = 1

" BracketedPaste: automatically turn off and on paste mode
Plug 'ConradIrwin/vim-bracketed-paste'
"}}}

" Navigation Plugins {{{ 

" Ack: Integration with ack/ag searching
Plug 'https://github.com/mileszs/ack.vim', { 'on': 'Ack' }
cnoreabbrev Ack Ack!
nnoremap <Leader>a :Ack!<Space>

" TagList: File navigation by sub routines
Plug 'taglist.vim', { 'on': 'TlistToggle' }
" Set some defaults for taglist
let Tlist_Close_On_Select = 1
let Tlist_GainFocus_On_ToggleOpen = 1
" Set a mapping for the taglist.vim plugin.  Toggles the taglist window.
nmap <leader>t :TlistToggle<cr>

" FastFold: Fixed a bug where vim tries to refold and causes severe slow down
Plug 'https://github.com/Konfekt/FastFold'

" EasyMotion: Provides easy short range navigation shortcuts
Plug 'https://github.com/easymotion/vim-easymotion'

" CtrlP: Fuzzy file finder
Plug 'https://github.com/kien/ctrlp.vim'

" NerdTree: File Browser
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
nnoremap <leader>N :NERDTreeToggle<CR>

" Gundo: Undo tree visualizer
Plug 'sjl/gundo.vim', { 'on': 'GundoToggle' }
nnoremap <leader>u :GundoToggle<CR>
" }}}

" Lazy Typing Plugins {{{

" Supertab: autocompletion with Tab
Plug 'https://github.com/ervandew/supertab'

" AutoPairs: Auto close pairs of things Eg: ""''{} etc
Plug 'https://github.com/jiangmiao/auto-pairs'
let g:AutoPairsFlyMode = 1
let g:AutoPairsShortcutBackInsert = '<Leader>b'
let g:AutoPairsShortcutJump= '<Leader>n'
let g:AutoPairsShortcutFastWrap= '<Leader>e'

" DelimitMate: Auto closer pairs.  I'm trying auto-pairs at the moment
" Plug 'Raimondi/delimitMate'
" Set some defaults for delimitMate
" let delimitMate_expand_cr = 2
" let delimitMate_expand_space = 1
" let delimitMate_expand_inside_quotes = 1
" let delimitMate_jump_expansion = 1

" CloseTag: Try to close matching <p> tags
Plug 'https://github.com/alvan/vim-closetag'

" ExpandRegion: allows easy expansion of visual selections
Plug 'https://github.com/terryma/vim-expand-region'
vmap v <Plug>(expand_region_expand)
vmap <C-v> <Plug>(expand_region_shrink)

" Templates: Provide boilerplate templates
Plug 'https://github.com/aperezdc/vim-template'

" Commentary: easily comment out code
Plug 'https://github.com/tpope/vim-commentary'

" Surround: easily manage surround areas with '")({})"' etc
Plug 'https://github.com/tpope/vim-surround'

" Exchange: easily exchange selected elements
Plug 'tommcdo/vim-exchange'

" SplitJoin: split or join code into one-liners vs verbose layouts
Plug 'AndrewRadev/splitjoin.vim'
" }}}

" Version Control Plugins {{{

" GitGutter: Shows inline git symbols for changed/added/removed lines
Plug 'https://github.com/airblade/vim-gitgutter', executable('git') ? {} : { 'on': [] }

" Fugitive: Git wrapper
Plug 'https://github.com/tpope/vim-fugitive'

" VCSCommand: VCS (cvs,svn,git,hg) managment
Plug 'vim-scripts/vcscommand.vim'
" }}}

" Language Plugins {{{

" Perl: yup
Plug 'neybar/vim-perl', { 'for': 'perl', 'do': 'make clean carp dancer highlight-all-pragmas moose test-more try-tiny'  }

" IndentGuides: Highlight indent levels
Plug 'https://github.com/nathanaelkane/vim-indent-guides', { 'for':  'python' }
" }}}

" Syntax Plugins {{{

" JSON: syntax highlighter
Plug 'elzr/vim-json'

" Ansible: Provide some coloring and syntax for ansible files
Plug 'pearofducks/ansible-vim'

" SCSS: for sassy css
Plug 'cakebaker/scss-syntax.vim'

" HashiCorp: (Syntax and other tools for Vagrant,Terraform,Packer, etc)
Plug 'hashivim/vim-hashicorp-tools'

" Groovy: syntax files
Plug 'vim-scripts/groovy.vim'

" Jenkinsfile: helper that loads up Groovy and a few other keywords
Plug 'martinda/Jenkinsfile-vim-syntax'
" }}}

" Color Plugins {{{
Plug 'altercation/vim-colors-solarized'
" color settings are after plug#end because vim can't find the colorscheme at
" this point in time.
" }}}

call plug#end()

colorscheme solarized
let g:solarized_diffmode="high"
if &diff
    " override the colorscheme for vimdiff.  This is the best colorscheme for
    " diff operations that I've found by far
    colorscheme solarized
endif

" vim:foldmethod=marker:foldlevel=0
