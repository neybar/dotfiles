"Restart apache and Tasks on write
:function! <SID>restart_apache()
" not the most robust check, but should keep from firing on any non-alpha box
" might need to add in some additional checks for CAS since it doesn't have
" apache or taskd, but would match the alpha check.
if hostname() =~ 'alpha' 
    silent !sudo /var/www/bin/taskd_init.sh reload &>/dev/null
    silent !sudo /usr/sbin/apachectl -k restart 2>/dev/null
endif 
:endfunction

au BufWritePost *.pm call s:restart_apache()
au BufWritePost /var/www/cgi/* call s:restart_apache()
