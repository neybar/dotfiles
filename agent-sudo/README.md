# agent-sudo

Lets AI agents and other tools that have no terminal (Claude Code, Cursor, Codex,
IDE task runners, `!` commands in Claude Code) run sudo commands, with your approval
for each one. The approval prompt shows the exact command before you type your
password, and rules refuse some commands outright (`rm -rf /`, `mkfs`, ...).

Terminal sudo is unchanged: in a real terminal, sudo still asks for the password
as text.

## Install

```sh
make install-agent-sudo   # runs the tests, then installs with sudo
```

This installs, owned by root:

| File | Purpose |
|---|---|
| `/usr/local/bin/agent-sudo` | wrapper agents call instead of `sudo` |
| `/usr/local/libexec/agent-sudo/askpass` | sudo askpass helper: analysis + prompt |
| `/usr/local/libexec/agent-sudo/rules` | deny/warn rules |

It also adds `Path askpass /usr/local/libexec/agent-sudo/askpass` to
`/etc/sudo.conf`, unless that file already names a different helper.

The files are root-owned on purpose. If the helper were writable by your user,
any process running as you could change it to record your password or show a
different command from the one sudo runs.

`make update` reports when the installed copy is missing or older than the repo.
Re-run `make install-agent-sudo` to update it.

Desktop Linux and WSLg need a dialog program: `sudo apt install zenity`
(`kdialog` and `ssh-askpass` also work). macOS uses its built-in dialog.

## Usage

```sh
agent-sudo apt-get update
agent-sudo -u postgres psql -c 'select 1'
```

`agent-sudo` runs `sudo -k -A`:

- `-A` sends the password request to the helper. This works without a terminal
  and without a GUI display.
- `-k` ignores cached credentials and doesn't refresh them, so every call needs
  approval and none piggybacks on an earlier one.

The rules are also checked before sudo runs, so a deny still applies to commands
your sudoers file lets run without a password.

Plain `sudo` with no terminal also reaches the helper through `sudo.conf`, but
only when a GUI display is present (a sudo rule). It also caches credentials:
after one approval, later `sudo` calls from the same parent process skip the
prompt and the rules until sudo's credential timeout expires. Agents should use `agent-sudo`.

## Where the prompt appears

| Situation | Prompt |
|---|---|
| macOS, local | native dialog (`osascript`) |
| Linux desktop / WSLg | zenity, kdialog, or ssh-askpass |
| SSH session inside tmux | tmux popup in your attached client |
| SSH with X forwarding, no tmux | dialog on your local X display |
| SSH, no tmux, no X | refused, with the command to run yourself |

Over SSH (`SSH_CONNECTION` set), tmux comes first, so a dialog never opens on a
screen you can't see. On servers, run agents inside tmux. Override the order with
`AGENT_SUDO_PROMPT="tmux gui"` or `AGENT_SUDO_PROMPT=gui`.

Every prompt shows the command, run-as user, working directory, the process
chain that asked (for example `sh <- claude <- zsh <- tmux`), and any warnings.
It times out after 120 seconds. Decisions (approved, denied, cancelled, but
never the password) are logged with `logger -t agent-sudo`. On Linux, read them
with `journalctl -t agent-sudo`; on macOS they go to the unified log.

## Rules

`rules` is a tab-separated list of `deny`/`warn` regexes; see the header of the
file. Built-in checks in `askpass` also deny recursive `rm`/`chmod`/`chown`/
`chgrp` and `find -delete` on `/`, `$HOME`, and top-level system directories, and
warn on any other recursive delete. Commands inside `sh -c '...'`, `$(...)`,
pipelines, and `;`/`&&` lists are checked too.

Add a test to `test.sh` for every rule change; `make test-agent-sudo` runs them
without root. Platform testing status and probe scripts: [TESTING.md](TESTING.md).

## What this does and doesn't protect against

- **Does:** mistakes and runaway agents. You see the real command (read from the
  sudo process itself, not from the agent's description) before it runs, and the
  worst commands are refused outright.
- **Doesn't:** a deliberately malicious process running as your user. Such a
  process could set its own `SUDO_ASKPASS` and show a fake dialog to collect your
  password. No askpass design prevents that. Only enter your password into prompts
  you expect.
- The rules are pattern matching, not a sandbox. A command can hide intent:
  running a script file, or obfuscated shell. Shells are flagged so you can read
  the script, but a script *file's* contents aren't shown.
- If the command can't be read or the analysis fails (bad rule, awk error), the
  request is refused rather than shown without checks.
- Linux reads the exact arguments from `/proc`. On macOS, `ps` may not show a
  setuid process's arguments, so the helper falls back to `agent-sudo`'s own
  arguments (which is why it runs sudo as a child instead of `exec`), and plain
  `sudo` from a tool is refused. `ps` joins arguments with spaces, so quoting
  isn't shown exactly on macOS. **The macOS path is untested so far.**
- The rules need an awk that rejects invalid regexes (gawk, mawk, macOS awk).
  busybox awk silently ignores them.

## Telling agents about it

Add something like this to each agent's global instructions (for example
`~/.claude/CLAUDE.md`, or `AGENTS.md` for tools that read it):

> To run a command as root, use `agent-sudo <command>` instead of `sudo`. It asks
> me for approval in a dialog that shows the exact command. If I deny it, don't
> retry; tell me what you wanted to run and why. Never pipe a password to `sudo -S`.
