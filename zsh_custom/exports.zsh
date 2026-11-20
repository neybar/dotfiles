# vim is the default editor and vimpager (a vim-plug plugin that make install
# fetches) is the pager. Until they are installed, leave the system defaults
# alone instead of breaking less and $EDITOR. make install warns about a
# missing vim; nothing is printed here, because output during shell startup
# trips the powerlevel10k instant prompt.
if (( $+commands[vim] )); then
    export EDITOR="vim"

    if [[ -x ~/.vim/plugged/vimpager/vimpager ]]; then
        export PAGER=~/.vim/plugged/vimpager/vimpager

        # I normally would put this in the alias file, but I didn't want to lose
        # track that I'm using vimpager here
        alias less=$PAGER
        alias zless=$PAGER
    fi
fi

export BAT_THEME="Solarized (dark)"

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

# OMZ
export DISABLE_MAGIC_FUNCTIONS=true
