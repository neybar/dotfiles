# agent-sudo

Lets AI agents and other tools that have no terminal (Claude Code, Cursor, Codex,
IDE task runners, `!` commands in Claude Code) run sudo commands, with your approval
for each one. The approval prompt shows the exact command before you type your
password, and rules refuse some commands outright (`rm -rf /`, `mkfs`, ...).

Terminal sudo is unchanged: in a real terminal, sudo still asks for the password
as text.

## Who can ask

A prompt only appears for requests that trace back to **your own terminal**:
some ancestor of the sudo process has a controlling terminal owned by you.
That covers agent TUIs you started (Claude Code, Cursor CLI, Codex, ...),
`!` commands inside them, tmux panes, and scripts you ran. Cron jobs, services,
and programs launched from the desktop have no such terminal; their requests
are refused without showing anything, and logged.

## Agents just type `sudo`

The dotfiles install a shim at `~/bin/sudo` (from `bin/sudo`; `~/bin` is first
in PATH). It hands off to the real `/usr/bin/sudo` in every case except one:
no terminal here, but the request traces back to your terminal. Then it runs
`agent-sudo` instead. So agents need no instructions, and everything else
(cron, services, your own terminal) gets plain sudo exactly as before.

`agent-sudo` itself always calls the system sudo by full path, so it never
loops back into the shim.

## Install

`make install` and `make update` handle it. When the installed copy is missing
or differs from the repo, they run the tests and install it, asking for your
sudo password once. When it's current, they print `agent-sudo: up to date` and
don't ask for anything. If the install fails or you cancel it, the rest of
`make install` still runs.

```sh
make install-agent-sudo                # install/reinstall now (runs tests first)
sh agent-sudo/install.sh --check       # is the installed copy current?
SKIP_AGENT_SUDO=1 make update          # skip it (e.g. no sudo on this machine)
```

This installs, owned by root:

| File | Purpose |
|---|---|
| `/usr/local/bin/agent-sudo` | wrapper agents call instead of `sudo` |
| `/usr/local/libexec/agent-sudo/askpass` | sudo askpass helper: analysis + prompt |
| `/usr/local/libexec/agent-sudo/rules` | deny/warn rules |

It also adds `Path askpass /usr/local/libexec/agent-sudo/askpass` to
`/etc/sudo.conf`, unless that file already names a different helper. On a Linux
desktop or WSLg (a display is present) with apt, it installs `zenity` for the
dialog, or `kdialog` if the desktop is KDE, unless one of them is already
there. Nothing GNOME is ever installed on KDE: Plasma ships kdialog. macOS uses
its built-in dialog, and servers use a tmux popup, so
neither needs one.

The files are root-owned on purpose. If the helper were writable by your user,
any process running as you could change it to record your password or show a
different command from the one sudo runs.

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

Plain `/usr/bin/sudo` with no terminal (bypassing the shim) also reaches the
helper through `sudo.conf`, but only when a GUI display is present (a sudo
rule), and it caches credentials: after one approval, later calls from the same
parent process skip the prompt and the rules until sudo's credential timeout
expires. The shim and `agent-sudo` don't have either limitation.

## Where the prompt appears

| Situation | Prompt |
|---|---|
| macOS, local | native dialog (`osascript`) |
| Linux, KDE | kdialog: one box shows the command, a second takes the password |
| Linux, other desktops / WSLg | zenity (one box) |
| SSH, agent inside tmux, its session attached | tmux popup over the agent's session |
| anything else | refused right away, with the command to run yourself |

A request only ever appears where you are already looking (the agent's own
tmux session) or pops up in front of you (a desktop dialog). It is never sent
to another terminal or another tmux session: an agent outside tmux, or in a
session no client is attached to, is refused even if you have tmux open
elsewhere. If several clients show the agent's session, the most recently
active one gets the popup.

Over SSH, run agents inside tmux. A prompt in the agent's own terminal without
tmux isn't supported (the agent's TUI owns the keyboard). See
[TESTING.md](TESTING.md#ssh-without-tmux-findings-2026-10-15).

Over SSH (`SSH_CONNECTION` set), the tmux popup comes first, so a dialog never
opens on a screen you can't see. Override the order with
`AGENT_SUDO_PROMPT`, e.g. `tmux` or `gui`.

kdialog uses two boxes because its password box turns newlines into spaces.
The message box shows the command exactly. Qt only renders it as HTML if a
tag appears before the first line break, and the first line is fixed text.
zenity, on non-KDE desktops, shows the text exactly in a single box.

Every prompt shows the command, run-as user, working directory, the process
chain that asked (for example `agent-sudo <- zsh <- claude`), the terminal it
traces back to (`claude on /dev/pts/0`), and any warnings.
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

Not required: with the shim, agents can use plain `sudo`. Two things are still
worth telling them (for example in `~/.claude/CLAUDE.md` or `AGENTS.md`):

> `sudo` here asks me for approval in a prompt that shows the exact command,
> and can wait up to 2 minutes for me, so give sudo commands a shell timeout of
> at least 3 minutes. If I deny one, don't retry; tell me what you wanted to
> run and why. Never pipe a password to `sudo -S`.
