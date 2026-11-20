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

# Larger history (allow 32³ entries; zsh's default is 30)
export HISTSIZE=32768
export SAVEHIST=$HISTSIZE
setopt hist_ignore_all_dups
setopt hist_ignore_space
# Make some commands not show up in the saved history. One pattern, matched
# against the whole line when the history file is written.
HISTORY_IGNORE="(ls|cd|cd -|pwd|exit|date|* --help)"

# Prefer US English and use UTF-8
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Highlight section titles in manual pages: bold orange (256-color 172), reset
# afterwards so the color doesn't bleed into the text that follows.
export LESS_TERMCAP_md=$'\e[1;38;5;172m'
export LESS_TERMCAP_me=$'\e[0m'

# Don’t clear the screen after quitting a manual page
export MANPAGER="less -X"

# Link Homebrew casks in `/Applications` rather than `~/Applications`
export HOMEBREW_CASK_OPTS="--appdir=/Applications"

# Turn off analytics for homebrew
export HOMEBREW_NO_ANALYTICS=1

# OMZ
export DISABLE_MAGIC_FUNCTIONS=true
