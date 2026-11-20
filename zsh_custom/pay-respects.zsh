# pay-respects: fix the previous command by typing `fuck` (replaces thefuck).
# Silent when it isn't installed (a stray message at shell startup trips the
# powerlevel10k instant prompt). Install: Arch `yay -S pay-respects-bin` (AUR),
# macOS `brew install timescam/tap/pay-respects` (in the Brewfile).
if (( $+commands[pay-respects] )); then
    # Its optional AI fallback sends the failed command to a third-party proxy.
    # It is opt-in (it asks first); keep it off.
    export _PR_AI_DISABLE=1
    # --nocnf: no command-not-found handler, to match what thefuck did.
    eval "$(pay-respects zsh --alias fuck --nocnf)"
fi
