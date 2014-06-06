set makeprg=$HOME/.vim/makeprg/vimparse.pl\ %\ $*
"set makeprg=$HOME/.vim/makeprg/vimparse.pl\ -c\ %\ $*
"set tags+=$HOME/.vim/tags/perl.ctags
set tags=./tags;/,tags;/
set errorformat=%f:%l:%m
let g:perl_fold=1
let perl_fold=1
"set define=^\\s*sub This was set by vim-perl

