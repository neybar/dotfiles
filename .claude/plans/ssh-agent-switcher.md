# Handoff: replace the shared ~/.ssh/ssh_auth_sock symlink (dotfiles)

Written 2026-10-26 from a docker-services session. Work continues in `~/Projects/dotfiles`.

## Problem

Git commit signing (1Password ssh key, `gpg.format ssh`) failed with
`error: Couldn't get agent socket?`. `~/.ssh/ssh_auth_sock` pointed at a socket that
no longer existed.

How the setup works today (`zsh_custom/ssh-agent.zsh`, commit 3647e52; `.tmux.conf`;
`.bash_profile` has older relink-only logic):
- Every shell and tmux pane sets `SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock`, **one symlink
  shared by the whole user**. Last writer wins.
- A shell relinks when its `SSH_AUTH_SOCK` isn't already a symlink and either
  (a) `SSH_CONNECTION` is set and the socket exists, or (b) local 1Password's socket exists.
- Nothing ever repairs a dead link.

## Root cause (verified from the journal and file timestamps)

- The current login (sshd, Oct 24 02:08, from a LAN client) forwarded a live agent at
  `/tmp/ssh-0uHS64BpZt/agent.603639`.
- At 04:19:49 and 04:20:02 on Oct 24, two **Tailscale SSH** sessions came in from
  `narsil` (over the tailnet) with agent forwarding (`journalctl -u tailscaled`). They were
  non-interactive test commands, and the second one explicitly sourced `ssh-agent.zsh`.
  Tailscale's forwarded socket is `/tmp/auth-agent<N>/listener.sock`, in a root-owned dir.
  The script relinked to it, the session ended a second later, and the link was left dead.
  (logind lists these as `c1`/`c2` sessions, i.e. not started by sshd.)
- The general bug doesn't need a test to happen: whenever the most recently linked login
  disconnects, the link dies for every shell, even if an older login is still connected.

Temporary fix applied: `ln -sfn /tmp/ssh-0uHS64BpZt/agent.603639 ~/.ssh/ssh_auth_sock`.
This only lasts as long as that login.

## Rejected: repair the link at every prompt (precmd hook)

The user called it heavy-handed. A shared mutable link that many shells write to invites
them fighting each other; the user often has several shells open at once.

## Recommended: ssh-agent-switcher (decision pending)

https://github.com/jmmv/ssh-agent-switcher, v1.0.2 (2026-04-29), Rust, BSD-3.

- A daemon listens on a fixed socket, `/tmp/ssh-agent.$USER`. Each time something
  connects to it, it finds a live forwarded socket and passes the request through.
  Nothing is written or repointed, so shells can't fight over it, and it can't go stale
  while any forwarded login is still connected.
- Discovery (`src/find.rs`): only dirs named `/tmp/ssh-*` owned by the current uid,
  sockets named `agent.*`, plus the OpenSSH 10.1+ naming `~/.ssh/agent/*.sshd.*`.
  A socket is used only if connecting to it succeeds. `--agents-dirs` overrides the
  search dirs.
- Tailscale sockets (`/tmp/auth-agent*/listener.sock`) are **ignored**. That would have
  prevented the Oct 24 break, but an agent forwarded over Tailscale SSH isn't used.
- When several sockets are live it takes the **first alphabetically**, not the newest.
  With two client machines connected at once, the 1Password prompt may appear on the
  other machine.
- Starts from a login script: `ssh-agent-switcher --daemon 2>/dev/null || true`
  (a PID-file lock prevents duplicates). Flags: `--socket-path`, `--log-file`,
  `--pid-file`, `--agents-dirs`.
- Install: this host (orcrist, Ubuntu, OpenSSH 9.6p1) has **no Rust toolchain**.
  Options: `rustup` + `cargo install ssh-agent-switcher` (binary only), or
  `make install MODE=release PREFIX=~/.local` from the repo (adds a man page), or build
  elsewhere and copy the binary over.

Dotfiles changes if adopted:
- `zsh_custom/ssh-agent.zsh`: over SSH, start the daemon and export
  `SSH_AUTH_SOCK=/tmp/ssh-agent.$USER`. At the keyboard (macOS / Linux desktop), keep
  pointing straight at the local 1Password socket.
- `.tmux.conf`: `setenv -g SSH_AUTH_SOCK` set to the same path, keeping the
  `update-environment` list without SSH_AUTH_SOCK.
- `.bash_profile`: same treatment, or leave it alone (login shell is zsh).
- Remove the `~/.ssh/ssh_auth_sock` symlink logic.
- Applies to every machine using these dotfiles, so check that macOS isn't affected.

Alternatives considered:
- `~/.ssh/rc` that relinks only when the current link is dead (werat.dev). Only sshd
  logins write the link, never shells. It still goes dead when the linked login
  disconnects while others remain. It also takes over X11 xauth handling from sshd.
  Tailscale SSH probably doesn't run `~/.ssh/rc` (unverified).
- tmux `update-environment SSH_AUTH_SOCK`: no shared state, but existing panes break on
  every reconnect.

## Open questions for the user

1. Go with ssh-agent-switcher?
2. Install Rust via rustup here, or build the binary elsewhere?
3. Is Tailscale SSH with agent forwarding a real workflow, or only used for those tests?
   **Answered: yes, it's used.** The proxy must include Tailscale sockets.

## Loose ends

- Empty dotfiles branch `fix/ssh-agent-self-heal` (created, no commits). Delete it or
  reuse it.
- `gpg.ssh.allowedSignersFile` isn't configured, so `git log --show-signature` prints
  "No signature" even for signed commits. Optional dotfiles fix.
- docker-services: PR #30 (remove `mode: host`) is merged. The Pi-hole
  DNS change is still uncommitted on master there.

Sources: jmmv.dev/2023/11/ssh-agent-forwarding-and-tmux-done.html,
jmmv.dev/2025/12/ssh-agent-switcher-release.html, werat.dev/blog/happy-ssh-agent-forwarding/,
chrisdown.name/2013/08/02/fixing-stale-ssh-sockets-in-tmux.html

## Decision so far (2026-10-26)

- No Rust, no new dependencies: must be self-contained in dotfiles, zsh only.
- ssh-agent-switcher's design is being redone in zsh (option A). Option B (relink only
  when dead) is the fallback.
- oh-my-zsh's bundled `ssh-agent` plugin was looked at and rejected: it uses the same
  shared symlink (last writer wins, no liveness check), and otherwise starts its own
  ssh-agent that would replace 1Password's. It isn't enabled in `.zshrc` anyway.

## Prototype: pure-zsh proxy

Script: `.claude/plans/ssh-agent-proxy` (next to this file; committed on this branch).
Usage: `ssh-agent-proxy <listen-socket>`. Uses zsh/net/socket, zsh/zselect, zsh/system.
- Listens with `zsocket -l`; forks a child per connection.
- Per connection, picks the newest live socket (by mtime, across all locations) from
  `/tmp/ssh-*/agent.*` and `~/.ssh/agent/*.sshd.*` (dir owned by the user) and
  `/tmp/auth-agent*/listener.sock` (Tailscale SSH; dir owned by root). Sockets must be
  owned by the user. "live" = `zsocket` connect succeeds.
- Relays with `zselect` + `sysread`/`syswrite` (multibyte off, partial writes handled).
- Exits if the listen socket already answers; removes it if dead.

### Results on orcrist (Ubuntu, zsh 5.9, OpenSSH 9.6p1)
- `ssh-add -l` through the proxy: same 4 keys as direct (binary blobs with NULs OK).
- 20 parallel `ssh-add -l`: all rc=0; no leftover children.
- `ssh-keygen -Y sign -n git` with GitHub (personal) via proxy, approved in 1Password;
  `ssh-keygen -Y verify` reports a good signature (same path git signing uses).
- `zsocket -l` mangled a 107-byte socket path (created `proxy.sockY`). Linux sun_path is
  108, macOS 104. `/tmp/ssh-agent.$USER` is well under; keep any override short.

### Results on narsil (macOS, /bin/zsh 5.9, OpenSSH 10.3p1)
Tested with a throwaway `ssh-agent` in `/tmp/ssh-mactest/`, not 1Password.
- The three modules load. `ssh-add -l` through the proxy matches direct;
  `ssh-keygen -Y sign` via the proxy verifies.
- **Bug, fixed:** the `~/.ssh/agent/*` glob matched macOS's own launchd ssh-agent
  (OpenSSH 10.x puts it at `~/.ssh/agent/s.*.agent.*`). Here that agent accepts a
  connection and never answers (a direct `ssh-add -l` hangs too), so every request
  through the proxy hung. The glob is now `~/.ssh/agent/*.sshd.*` (sshd-forwarded
  sockets only, same as ssh-agent-switcher). Linux will hit this too once its
  OpenSSH is 10.x and a local ssh-agent runs. Any upstream that accepts and then
  never answers still hangs the client (ssh-agent-switcher behaves the same).
- No live upstream (after the fix): `ssh-add` fails in ~13 ms ("communication with
  agent failed", rc=1). Upstream killed mid-session: next request fails fast; a new
  agent appearing is picked up on the next connection.
- **Limitation, unfixed:** 20 parallel `ssh-add -l` → 12 got "Connection refused".
  `zsocket -l` uses a listen backlog of 1 (confirmed: with no accept, only 1 of 10
  connects queues). Linux blocks the extra clients, macOS refuses them, and zsh can't
  change the backlog. Only matters if a Mac is the ssh *target*, where the proxy
  would run.
- `zsocket -l` with a path of 104+ bytes silently truncates to 103, no error. When
  wiring in, refuse long listen paths instead of relying on this.

### Results on orcrist over Tailscale SSH (tailscaled 1.104.2)
Tested from narsil with a non-interactive `ssh orcrist.tailcb20d4.ts.net '...'`
(never sources `ssh-agent.zsh`), proxy on a mktemp socket, not `/tmp/ssh-agent.$USER`.
- Tailscale's socket is `/tmp/auth-agent<N>/listener.sock`, owned by the user, mode
  600, in a root-owned 755 dir. Discovery now takes it only if the dir's owner is
  root, so another user can't plant one.
- With the older sshd login (`/tmp/ssh-0uHS64BpZt`) still live, the proxy picked the
  Tailscale socket as newest. `ssh-add -l` via proxy = direct (4 keys); 20 parallel
  all rc=0. `~/.ssh/ssh_auth_sock` was unchanged.
- tailscaled never removes the `/tmp/auth-agent*` dirs, only the socket (Go
  unlinks it on `Close()`). `gliderssh.NewAgentListener` makes the dir with
  `os.MkdirTemp` and nothing removes it; tailssh.go even has
  `TODO(maisem/bradfitz): add a way to close all session resources`. Harmless
  (empty, tmpfiles clears /tmp), and the proxy skips dirs without a socket.
- Tailscale SSH check mode: a login can print an approval URL; when the approval has
  expired, a non-interactive login waits on it.

### Not yet tested
- WSL.
- Real forwarded login on Linux with the `*.sshd.*` glob (OpenSSH 10.1+ naming).

## Still to decide before wiring into dotfiles
- Script location: `zsh_custom/` vs `bin/`.
- How `ssh-agent.zsh` starts it (over SSH only; restart if socket dead).
- `.tmux.conf`: conditional SSH_AUTH_SOCK (not a blanket `setenv -g`), since it's shared
  with macOS / desktop sessions.
- `.bash_profile`: probably just drop the symlink logic.
- WSL (added on master in e55d115): at the keyboard, `ssh-agent.zsh` starts a socat +
  npiperelay.exe bridge to `~/.1password/agent.sock`. That's the local case, so the
  proxy shouldn't touch it, but the rewrite of `ssh-agent.zsh` must keep the bridge.
  Three targets to check, not two: macOS, Linux (desktop and ssh), WSL.
