# Keep the 1Password ssh agent usable everywhere, including inside tmux.
#
# Each shell picks its own SSH_AUTH_SOCK; nothing shared is rewritten:
#   - over ssh: ~/.ssh/agent-proxy.sock, served by ssh-agent-proxy (next to
#     this file), which hands each request to the newest forwarded agent
#     that is still connected (sshd or Tailscale SSH). The path never
#     changes, so long-lived tmux panes keep working as logins come and go.
#     Any shell restarts the proxy if it has died.
#   - at the keyboard: the local 1Password agent (macOS or Linux desktop).
#     Under WSL, 1Password runs on Windows, so socat + npiperelay.exe bridge
#     its named pipe to ~/.1password/agent.sock (apt install socat;
#     winget install albertony.npiperelay).

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

# True if something is accepting connections on socket $1.
_sock_answers() {
    local REPLY
    zsocket $1 2>/dev/null && exec {REPLY}>&-
}

# Start the agent proxy unless one is already answering on the socket.
_ssh_agent_proxy() {
    local sock=$1 lockfd
    zmodload zsh/net/socket zsh/system || return
    _sock_answers $sock && return
    # Serialize so concurrent shells don't each start a proxy.
    : >>$sock.lock && zsystem flock -t 5 -f lockfd $sock.lock || return
    if ! _sock_answers $sock; then
        # setsid (Linux) keeps the proxy out of this login's session.
        ${commands[setsid]:+setsid} zsh $ZSH_CUSTOM/ssh-agent-proxy $sock \
            {lockfd}>&- </dev/null >/dev/null 2>&1 &!
        for _ in {1..40}; do _sock_answers $sock && break; sleep 0.05; done
    fi
    exec {lockfd}>&-
    _sock_answers $sock
}

_agent_proxy_sock=~/.ssh/agent-proxy.sock
if [[ -n "$SSH_CONNECTION" && ( -S "$SSH_AUTH_SOCK" || "$SSH_AUTH_SOCK" == "$_agent_proxy_sock" ) ]]; then
    _ssh_agent_proxy $_agent_proxy_sock && export SSH_AUTH_SOCK=$_agent_proxy_sock
else
    [[ -n "$WSL_DISTRO_NAME" ]] && _op_wsl_bridge
    for _s in ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock \
              ~/.1password/agent.sock; do
        [[ -S "$_s" ]] && { export SSH_AUTH_SOCK=$_s; break; }
    done
fi
unset _agent_proxy_sock _s
