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

" Dispatch: kick off jobs based on actions (Installed for Omnisharp)
Plug 'tpope/vim-dispatch'
"}}}

" Navigation Plugins {{{ 

" Ack: Integration with ack/ag searching
Plug 'https://github.com/mileszs/ack.vim', { 'on': 'Ack' }
cnoreabbrev Ack Ack!
nnoremap <Leader>a :Ack!<Space>

" Tagbar: ctag file navigation
Plug 'majutsushi/tagbar'
" Set some defaults for tagbar
let g:tagbar_autoclose = 1
let g:tagbar_left = 1
" Set a mapping for the tagbar.vim plugin.  Toggles the tagbar window.
nmap <leader>t :TagbarToggle<cr>

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
let g:templates_directory = [$HOME."/.vim/templates"]

" Commentary: easily comment out code
Plug 'https://github.com/tpope/vim-commentary'

" EasyAlign: Align all sorts of things
Plug 'junegunn/vim-easy-align'
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)
" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)
" Quick map for aligning code in a {} block
nmap <silent> - gavi}
vmap <silent> - ga
" Same thing, but assume alignment on equal sign
nmap <silent> -- gavi}=<CR>
vmap <silent> -- ga=<CR>

" Surround: easily manage surround areas with '")({})"' etc
Plug 'https://github.com/tpope/vim-surround'

" Exchange: easily exchange selected elements
Plug 'tommcdo/vim-exchange'

" SplitJoin: split or join code into one-liners vs verbose layouts
Plug 'AndrewRadev/splitjoin.vim'

" Ultisnips: Snippets
Plug 'sirver/ultisnips'

" VimSnippets: Various snippets for lots of languages
Plug 'honza/vim-snippets'

" YouCompleteMe: Autocompletion
if v:version >= 704
    Plug 'Valloric/YouCompleteMe', { 'do': './install.py' }
end
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

" Syntastic: Inline Syntax Checking
Plug 'vim-syntastic/syntastic'

" Perl: yup
Plug 'neybar/vim-perl', { 'for': 'perl', 'do': 'make clean carp dancer highlight-all-pragmas moose test-more try-tiny'  }

" IndentGuides: Highlight indent levels
Plug 'https://github.com/nathanaelkane/vim-indent-guides', { 'for':  'python' }
" }}}

" Csharp: syntax, indent, etc
Plug 'OrangeT/vim-csharp'
Plug 'OmniSharp/omnisharp-vim'
let g:OmniSharp_server_type = 'roslyn'
let g:OmniSharp_timeout = 10

" Syntax Plugins {{{

" JSON: syntax highlighter
Plug 'elzr/vim-json'
" Turn off the auto conceal feature (It hides the quote characters until you
" move your cursor over the line)
let g:vim_json_syntax_conceal = 0

" Ansible: Provide some coloring and syntax for ansible files
Plug 'pearofducks/ansible-vim'

" SCSS: for sassy css
Plug 'cakebaker/scss-syntax.vim'

" HashiCorp: (Syntax and other tools for Vagrant,Terraform,Packer, etc)
Plug 'hashivim/vim-hashicorp-tools'

" Groovy: syntax files
Plug 'modille/groovy.vim'

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

" In order to make Supertab, UltiSnips, and YouCompleteMe all work together a
" few things need to happen.
" First make YCM compatible with UltiSnips (using supertab) by using C-n
let g:ycm_key_list_select_completion = ['<C-n>', '<Down>']
let g:ycm_key_list_previous_completion = ['<C-p>', '<Up>']
" Then make Supertab's default completion type be C-n (which will fire YCM)
let g:SuperTabDefaultCompletionType = '<C-n>'

" Finally let UltiSnips use <tab> to complete snippets.
let g:UltiSnipsExpandTrigger = "<tab>"
" Use Ctrl-j and Ctrl-b to navigate between snippet tabstops
let g:UltiSnipsJumpForwardTrigger = "<c-j>"
let g:UltiSnipsJumpBackwardTrigger = "<c-b>"

" vim:foldmethod=marker:foldlevel=0
