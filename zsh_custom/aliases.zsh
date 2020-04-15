# Read in my dircolors file
(( $+commands[gdircolors] )) && eval "$(gdircolors -b ~/.dircolors)"

# Enhanced WHOIS lookups
alias whois="whois -h whois-servers.net"

# make brew update easier
alias brewski='brew update && brew upgrade && brew cu && brew cleanup; brew doctor'

# cleanup unused docker images, layers, etc
alias docker-cleanup='docker run --rm -v /var/run/docker.sock:/var/run/docker.sock:rw -v /var/lib/docker:/var/lib/docker:rw -e LOOP=false -e DELAY_TIME=10 meltwater/docker-cleanup:latest'
