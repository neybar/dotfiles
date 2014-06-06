au BufNewFile,BufRead *.tt 
      \ if ( getline(1) . getline(2) . getline(3) =~ '<\chtml' 
      \           && getline(1) . getline(2) . getline(3) !~ '<[%?]' ) 
      \   || getline(1) =~ '<!DOCTYPE HTML' | 
      \   setf tt2html | 
      \ else | 
      \   setf tt2 | 
      \ endif 

:let b:tt2_syn_tags = '\[% %] <!-- -->' 
