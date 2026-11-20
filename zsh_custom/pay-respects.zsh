# Command correction: type `bah` to fix the previous command. pay-respects is
# preferred; thefuck is the fallback for machines that don't have it yet (drop
# the elif once pay-respects is installed everywhere). Silent when neither is
# installed: a stray message at shell startup trips the powerlevel10k instant
# prompt. Install pay-respects: Arch `yay -S pay-respects-bin` (AUR), macOS
# `brew install timescam/tap/pay-respects` (in the Brewfile).
if (( $+commands[pay-respects] )); then
    # Its optional AI fallback sends the failed command to a third-party proxy.
    # It is opt-in (it asks first); keep it off.
    export _PR_AI_DISABLE=1
    # --nocnf: no command-not-found handler, to match what thefuck did.
    eval "$(pay-respects zsh --alias bah --nocnf)"
elif (( $+commands[thefuck] )); then
    eval "$(thefuck --alias bah)"
fi
