# Make vim the default editor
export EDITOR="vim"

# Use vim as the default pager
export PAGER=~/.vim/plugged/vimpager/vimpager

# I normally would put this in the alias file, but I didn't want to lose track that I'm using 
# vimpager here
alias less=$PAGER
alias zless=$PAGER

# Larger bash history (allow 32³ entries; default is 500)
export HISTSIZE=32768
export SAVEHIST=$HISTSIZE
export HISTFILESIZE=$HISTSIZE
export HISTCONTROL=ignoreboth
setopt hist_ignore_all_dups
setopt hist_ignore_space
# Make some commands not show up in history
export HISTIGNORE="ls:cd:cd -:pwd:exit:date:* --help"

# Prefer US English and use UTF-8
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Highlight section titles in manual pages
export LESS_TERMCAP_md="$ORANGE"

# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X"

# Link Homebrew casks in `/Applications` rather than `~/Applications`
export HOMEBREW_CASK_OPTS="--appdir=/Applications"

# Turn off analytics for homebrew
export HOMEBREW_NO_ANALYTICS=1
