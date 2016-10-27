call plug#begin()

" EasyMotion: Provides easy short range navigation shortcuts
Plug 'https://github.com/easymotion/vim-easymotion'

" CtrlP: Fuzzy file finder
Plug 'https://github.com/kien/ctrlp.vim'

" Ack: Integration with ack/ag searching
Plug 'https://github.com/mileszs/ack.vim'

" FastFold: Fixed a bug where vim tries to refold and causes severe slow down
Plug 'https://github.com/Konfekt/FastFold'

" Ansible: Provide some coloring and syntax for ansible files
Plug 'https://github.com/pearofducks/ansible-vim'

" Auto-Pairs: Auto close pairs of things Eg: ""''{} etc
Plug 'https://github.com/jiangmiao/auto-pairs'

" CloseTag: Try to close matching <p> tags
Plug 'https://github.com/alvan/vim-closetag'

" Matchit: Include matchit for vim < 7
if v:version >= 800
    packadd matchit
else
    Plug 'https://github.com/tmhedberg/matchit'
endif

" Supertab: autocompletion with Tab
Plug 'https://github.com/ervandew/supertab'

call plug#end()
