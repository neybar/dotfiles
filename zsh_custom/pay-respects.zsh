# Command correction: type `bah` to fix the previous command. Silent when
# pay-respects isn't installed: a stray message at shell startup trips the
# powerlevel10k instant prompt. Install: Arch `yay -S pay-respects-bin` (AUR),
# macOS `brew install timescam/tap/pay-respects` (in the Brewfile), Debian/Ubuntu
# the .deb from https://github.com/iffse/pay-respects/releases.
if (( $+commands[pay-respects] )); then
    # Its optional AI fallback sends the failed command to a third-party proxy.
    # It is opt-in (it asks first); keep it off.
    export _PR_AI_DISABLE=1
    # --nocnf: no command-not-found handler (thefuck never had one).
    eval "$(pay-respects zsh --alias bah --nocnf)"
fi
