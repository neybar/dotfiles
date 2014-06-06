" Vim syntax file
" Language: CVS commit file
" Maintainer:   Matt Dunford (zoot@zotikos.com)
" URL:      http://www.zotikos.com/downloads/cvs.vim
" Last Change:  Sat Nov 24 23:25:11 CET 2001
" Modified: Rob Van Dam (see corresponding output in CVSROOT/cvs_editinfo.pl)
" Put this in your ~/.vim/syntax/ dir to override your local default

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
    syntax clear
elseif exists("b:current_syntax")
    finish
endif

syn region cvsLine start="^CVS: " end="$" contains=cvsFile,cvsCom,cvsFiles,cvsTag,cvsHead,cvsHeadFile,pcSev5,pcSev4,pcSev3,pcSev2,pcSev1,pcPolicy
syn match cvsFile  contained " \t\(\(\S\+\) \)\+"
syn match cvsTag   contained " Tag:"
syn match cvsFiles contained "\(Added\|Modified\|Removed\) Files:"
syn region cvsCom start="Committing in" end="$" contains=cvsDir contained extend keepend
syn match cvsDir   contained "\S\+$"
" Added by rvandam
syn region cvsHead start="\(Potential projects\|Top \d\+ Perl::Critic\)" end="$" contains=cvsHeadFile
syn match cvsHeadFile contained "\s\+\[\w\.\]\+\(\/\[\w\.\]\+\)*:"
syn region pcSev5 start="Severity 5" end="$" contained contains=pcPolicy
syn region pcSev4 start="Severity 4" end="$" contained contains=pcPolicy
syn region pcSev3 start="Severity 3" end="$" contained contains=pcPolicy
syn region pcSev2 start="Severity 2" end="$" contained
syn region pcSev1 start="Severity 1" end="$" contained
syn match pcPolicy contained "\w\+\(::\w\+\)\+"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_cvs_syn_inits")
    if version < 508
        let did_cvs_syn_inits = 1
        command -nargs=+ HiLink hi link <args>
    else
        command -nargs=+ HiLink hi def link <args>
    endif

    HiLink cvsLine      Comment
    HiLink cvsDir       cvsFile
    HiLink cvsFile      Constant
    HiLink cvsFiles     cvsCom
    HiLink cvsTag       cvsCom
    HiLink cvsCom       Statement
    " Added by rvandam
    HiLink cvsHead      Statement
    HiLink cvsHeadFile  Special
    HiLink pcSev5       Special
    HiLink pcSev4       Constant
    HiLink pcSev3       Include
    HiLink pcPolicy     Special

    delcommand HiLink
endif

let b:current_syntax = "cvs"
