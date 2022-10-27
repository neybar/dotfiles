# Read in my dircolors file
(( $+commands[gdircolors] )) && eval "$(gdircolors -b ~/.dircolors)"

# Enhanced WHOIS lookups
alias whois="whois -h whois-servers.net"

# make brew update easier
alias brewski='brew update && brew upgrade && brew cu && brew cleanup; brew doctor'

# cleanup unused docker images, layers, etc
alias docker-cleanup='docker run --rm -v /var/run/docker.sock:/var/run/docker.sock:rw -v /var/lib/docker:/var/lib/docker:rw -e LOOP=false -e DELAY_TIME=10 meltwater/docker-cleanup:latest'

# allow wildcard in scp command: https://superuser.com/questions/420525/scp-with-zsh-no-matches-found
alias scp='noglob scp'

# remind me what the Mac Os command for dig is again?
function dig() { if [[ `uname` == "Darwin" ]]; then echo "try dscacheutil -q host -a name $1"; fi; command dig $@ }
