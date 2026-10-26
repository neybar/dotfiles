# Keep the 1Password ssh agent usable everywhere, including inside tmux.
#
# ~/.ssh/ssh_auth_sock is a stable symlink to the best agent for this login,
# and .tmux.conf points SSH_AUTH_SOCK at it so long-lived panes keep working:
#   - over ssh: the agent forwarded from wherever 1Password is running.
#     Each login gets a new socket, so every pane follows the latest one.
#   - at the keyboard: the local 1Password agent (macOS or Linux desktop).
#     Under WSL, 1Password runs on Windows, so socat + npiperelay.exe bridge
#     its named pipe to ~/.1password/agent.sock (apt install socat;
#     winget install albertony.npiperelay).
# Shells already using the symlink (e.g. inside tmux) leave it alone.

# Start the WSL bridge unless one is already answering on the socket.
_op_wsl_bridge() {
    local sock=~/.1password/agent.sock relay
    relay=${commands[npiperelay.exe]:-$(print -l /mnt/c/Users/*/AppData/Local/Microsoft/WinGet/Packages/albertony.npiperelay_*/npiperelay.exe(N[1]))}
    [[ -n "$relay" ]] && (( $+commands[socat] )) || return
    mkdir -p -m 700 ~/.1password
    # ssh-add exits 2 only when it can't reach an agent.
    SSH_AUTH_SOCK=$sock ssh-add -l >/dev/null 2>&1; (( $? != 2 )) && return
    # Serialize so concurrent shells don't each start a bridge.
    (
        flock 9
        SSH_AUTH_SOCK=$sock ssh-add -l >/dev/null 2>&1; (( $? != 2 )) && exit
        rm -f $sock
        setsid socat UNIX-LISTEN:$sock,fork,umask=077 \
            EXEC:"'$relay' -ei -s //./pipe/openssh-ssh-agent",nofork \
            </dev/null >/dev/null 2>&1 &
        for _ in {1..20}; do [[ -S $sock ]] && break; sleep 0.05; done
    ) 9>~/.1password/bridge.lock
}

if [[ ! -h "$SSH_AUTH_SOCK" ]]; then
    _agent_sock=
    if [[ -n "$SSH_CONNECTION" && -S "$SSH_AUTH_SOCK" ]]; then
        _agent_sock=$SSH_AUTH_SOCK
    else
        [[ -n "$WSL_DISTRO_NAME" ]] && _op_wsl_bridge
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
