# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:$HOME/go/bin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Would you like to use another custom folder than $ZSH/custom?
ZSH_CUSTOM="$HOME/Projects/dotfiles/zsh_custom"

plugins=(
    sudo
    git
    colored-man-pages
    macos
    vi-mode
    fzf
    thefuck
    z
    zsh-syntax-highlighting
)

# Machine-specific overrides (not tracked in dotfiles)
# Changes to $PATH and plugins should go in ~/.zshrc.local
# This file is sourced before oh-my-zsh, so plugins+=() works here.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

source $ZSH/oh-my-zsh.sh
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
