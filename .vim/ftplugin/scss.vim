"I've removed this from the global config (since it accesses a specific file)
"the new functionality is being accessed through localvimrc plugin.  Check out
"vimrc_fragments for more details
"au BufWritePost *.scss silent !/var/www/bin/webdev/sass.pl --quiet <afile>
