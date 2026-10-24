# Keep the 1Password ssh agent usable everywhere, including inside tmux.
#
# ~/.ssh/ssh_auth_sock is a stable symlink to the best agent for this login,
# and .tmux.conf points SSH_AUTH_SOCK at it so long-lived panes keep working:
#   - over ssh: the agent forwarded from wherever 1Password is running.
#     Each login gets a new socket, so every pane follows the latest one.
#   - at the keyboard: the local 1Password agent (macOS or Linux desktop).
# Shells already using the symlink (e.g. inside tmux) leave it alone.
if [[ ! -h "$SSH_AUTH_SOCK" ]]; then
    _agent_sock=
    if [[ -n "$SSH_CONNECTION" && -S "$SSH_AUTH_SOCK" ]]; then
        _agent_sock=$SSH_AUTH_SOCK
    else
        for _s in ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock \
                  ~/.1password/agent.sock; do
            [[ -S "$_s" ]] && { _agent_sock=$_s; break; }
        done
    fi
    if [[ -n "$_agent_sock" ]]; then
        # Swap the link atomically so no other shell sees it missing.
        ln -sf "$_agent_sock" ~/.ssh/ssh_auth_sock.$$ \
            && mv -f ~/.ssh/ssh_auth_sock.$$ ~/.ssh/ssh_auth_sock \
            && export SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock
    fi
    unset _agent_sock _s
fi
