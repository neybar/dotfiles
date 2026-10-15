# agent-sudo: testing status and handoff notes

Branch `feature/agent-sudo`. This file tracks what has been verified on which
platform, and gives the steps for the rest. Add your results to the
[results log](#results-log) as you go.

## Quick start on another machine

```sh
cd ~/Projects/dotfiles
git fetch origin && git switch feature/agent-sudo
make test-agent-sudo               # rule tests: no root, no prompts
sh agent-sudo/install.sh --check   # installed copy current? (no root)
sh agent-sudo/dev/probe-argv.sh    # what the helper can see of sudo here
sh agent-sudo/dev/tmux-test.sh     # tmux popups, real ttys
sh agent-sudo/dev/origin-test.sh   # "from your terminal" rule + ~/bin/sudo shim (Linux)
```

Then follow the checklist for the platform below.

## Verified so far

Machine: WSL2 on Windows, Ubuntu 24.04 (noble), sudo 1.9.15p5, gawk 5.2.1,
mawk, dash, tmux 3.4. Date: 2026-10-14.

| What | How | Result |
|---|---|---|
| Rule tests (96 cases) | `make test-agent-sudo` with dash+gawk, dash+mawk, `bash --posix`+gawk/mawk | pass |
| Tests catch regressions | broke individual fixes on purpose (mutation check) | tests fail as expected |
| The askpass parent process is sudo; `/proc` gives exact argv | stub askpass + `sudo -k -A` | yes |
| `sudo -A` calls askpass with no display | `env -u DISPLAY -u WAYLAND_DISPLAY` | yes; without `-A` sudo refuses |
| Deny through real sudo | `csrutil disable`; `chown -R nobody .` run from `/etc` | refused before any prompt |
| Fail closed: argv unreadable | simulated (forced `/proc` and `ps` unreadable) | plain sudo refused; via the wrapper, args recovered |
| Fail closed: analysis error | invalid regex, malformed rule lines, a ~140 KB command | refused / still analyzed |
| Display fidelity | newline inside `sh -c`, trailing `''`, ESC/CR in args | shown exactly; control chars become `?` |
| tmux popup, agent inside tmux | `dev/tmux-test.sh` against a real attached client | approve ~1s, deny ~0s, timeout closes popup, no leftovers |
| No popup outside the agent's own session | `dev/tmux-test.sh`: agent outside tmux, and agent in a session with no client, while another session is attached | refused immediately, no popup (2026-10-15; the old code failed both) |
| "From your terminal" rule | `dev/origin-test.sh`: as Claude Code vs. a detached (setsid) process | allowed vs. refused without prompt |
| `~/bin/sudo` shim routing | same | from terminal: agent-sudo; detached: plain sudo; no loop when the shim is first in PATH |
| Logging | `journalctl -t agent-sudo` | entries present; long commands capped at 2000 chars |
| `install.sh` install / `--check` / rerun / zenity via `--gui` | as root in an `ubuntu:24.04` Docker container | installs root-owned, adds one `sudo.conf` line, reports up to date, detects a changed file |
| Makefile `sync-agent-sudo` | dry runs: not installed, `SKIP_AGENT_SUDO=1` | detects missing pieces; skip works (real sudo run pending) |
| Terminal sudo unaffected | sudo source (`tgetpass.c`), then observed after install | normal text prompt in a terminal |
| Real install + dialog (zenity, WSLg) | `make update`, then approve/deny/display checks from Claude Code | all pass; see results log |

## Not verified yet

### macOS

Steps 1–8 passed on 2026-10-15 (macOS 26.6.2, Apple Silicon; see results
log). Left: step 9 (SSH), step 10 (Touch ID; not enabled on the
test machine), the `setsid`-free cron-like check in step 5, and an Intel Mac.

1. `make test-agent-sudo`. This exercises macOS `/bin/sh` (bash 3.2) and BWK
   awk. All cases should pass; on macOS this includes real-sudo cases for the
   exact-argv path (done 2026-10-15, see results log).
2. `sh agent-sudo/dev/probe-argv.sh`, and record the output. Key questions:
   - Does "ps args of sudo" show the full command, or only `(sudo)` / nothing?
     If it's `(sudo)`, plain `sudo` from agents is refused and only `agent-sudo`
     works (by design; see README).
   - Does "sudo cwd (lsof)" or "parent cwd (lsof)" give a real directory?
3. `brew install tmux` if needed, then `sh agent-sudo/dev/tmux-test.sh`. This
   uses BSD `script` syntax there.
4. `make install` (or `make install-agent-sudo`), and note any warnings. On Intel Macs with
   Homebrew, expect a warning if `/usr/local` or `/usr/local/libexec` is
   user-writable; decide whether to move the install prefix.
5. "From your terminal" rule: `ps -o tty= -p $$` in Terminal shows something
   like `ttys003`, and `[ -O /dev/ttys003 ] && echo mine` prints `mine` (the
   rule relies on both). `dev/origin-test.sh` needs `setsid`, which macOS
   lacks, so test the cron-like case by hand, e.g. a `launchd` job running
   `sudo true`: it should be refused with no dialog.
6. In Terminal.app/iTerm: `sudo -k; sudo true` should give the normal text
   prompt, with no dialog.
7. `agent-sudo true` from a terminal should show the macOS dialog with `true`.
   Also try `agent-sudo sh -c 'echo one
echo two'` (shown on two lines?) and a long command (cut off?).
   Click Deny and expect `denied by user`. Run it again with your password and it
   should succeed.
8. From Claude Code: `! agent-sudo true`, then ask Claude to run
   `agent-sudo true` with its Bash tool. Check that the dialog shows
   "Requested by" with a sensible process chain.
9. SSH into the Mac:
   - outside tmux, `agent-sudo true` should be refused with "no way to ask for
     approval", and no dialog should appear on the Mac's screen;
   - inside tmux, you should get the popup.
10. Unknown: interaction with Touch ID for sudo (`pam_tid` in
   `/etc/pam.d/sudo_local`). sudo may ask for Touch ID before calling askpass,
   which would bypass the command display. Test it if Touch ID sudo is enabled.

### Linux desktop / WSLg

1. `make install` (or `make install-agent-sudo`). It should install zenity and
   ask for your sudo password once. Run it again and it should print
   `agent-sudo: up to date` without asking.
2. Terminal: `sudo -k; sudo true` should give the text prompt with no dialog.
3. In Claude Code:
   - `! sudo -k; sudo true` should open the zenity dialog (via `sudo.conf`);
   - `! agent-sudo true` should open the dialog;
   - `! agent-sudo echo 'a_b\c'` checks that `_` and `\` display literally.
4. Deny button, closing the window, and waiting 120s should each give
   `denied by user`.
5. Finish the original apt fix this started from, now that sudo works here:

   ```sh
   ! agent-sudo sh -c 'wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg'
   ```

   Also replace the GitHub CLI source with the `stable` suite and
   `/etc/apt/keyrings/githubcli-archive-keyring.gpg`, then run `apt update`.

### Linux KDE desktop

Decision: kdialog on KDE, never zenity. zenity would pull in GTK4/libadwaita;
the user does not want GNOME libraries on KDE systems. kdialog ships with
Plasma.

1. `echo $XDG_CURRENT_DESKTOP` should contain `KDE`. If it doesn't (e.g. in a
   session that doesn't set it), askpass tries zenity first, then kdialog.
2. `make install` should install nothing extra (kdialog is already there).
   `sh agent-sudo/install.sh --check` should report up to date.
3. `agent-sudo true` from a terminal-less context (e.g. `!` in Claude Code)
   should show two boxes: a Continue/Cancel box with the full command, then a
   password box. Cancel in either box should give `denied by user`.
4. Display checks, all of which should show literally in the first box:
   - `agent-sudo sh -c 'echo one
     echo two'` shows two lines;
   - `agent-sudo echo '<b>bold</b>' 'a\nb'` shows the tags and `\n` as text,
     not bold or a line break;
   - `agent-sudo -u '<b>x' true` puts `<b>x` on the "Run as" line, as text.
5. Leave the first box open past 120s: it should close and be treated as a deny
   (via coreutils `timeout`).
6. Check on both Wayland and X11 sessions if you use both.

### Linux server over SSH (no GUI) — highest priority

Steps 1, 2 and the tmux parts of 3 and 4 passed on 2026-10-15 (see results
log). The prompt now only appears in the agent's own tmux session; see
[SSH without tmux](#ssh-without-tmux-findings-2026-10-15).

1. `make install` (nothing extra gets installed with no display). Without sudo
   rights, use `SKIP_AGENT_SUDO=1 make install`.
2. `sh agent-sudo/dev/tmux-test.sh`, which should be all ok.
3. Real runs, with Claude Code in your SSH session:
   - Claude inside tmux, asked to run `agent-sudo true`: the popup appears over
     its session.
   - Claude not in tmux, even with a tmux session attached elsewhere: refused
     right away, with the command to run yourself. No popup anywhere.
   When testing by hand, put the expected action in the command (for example
   `sudo sh -c ': TEST - please DENY this one'`): the popup covers the agent,
   so you can't see what it asked for.
4. Check `journalctl -t agent-sudo` for approved/cancelled entries.
5. If the machine's window manager is ever used locally, the desktop checks
   above apply to that session.

## Results log

| Date | Machine / OS | Step | Result | Notes |
|---|---|---|---|---|
| 2026-10-14 | WSL2 Ubuntu 24.04 | everything in "Verified so far" | pass | before install |
| 2026-10-14 | WSL2 Ubuntu 24.04 (WSLg, zenity) | `make update` auto-install | pass | installed root-owned files, sudo.conf line, zenity; `--check` up to date |
| 2026-10-14 | WSL2 Ubuntu 24.04 (WSLg, zenity) | Claude Bash tool: `agent-sudo true`, approve | pass | ran as root; log chain `agent-sudo <- zsh <- claude <- ...` |
| 2026-10-14 | WSL2 Ubuntu 24.04 (WSLg, zenity) | Deny button | pass | `denied by user`, exit 1 |
| 2026-10-14 | WSL2 Ubuntu 24.04 (WSLg, zenity) | Rule deny via `agent-sudo` and plain `sudo` | pass | refused, no dialog |
| 2026-10-14 | WSL2 Ubuntu 24.04 (WSLg, zenity) | Display: `echo 'a_b\c' 'x<y>&z'`, multi-line `sh -c` | pass | shown exactly (user confirmed) |
| 2026-10-14 | WSL2 Ubuntu 24.04 (WSLg, zenity) | Terminal `sudo -k; sudo true` | pass | normal text prompt, no dialog |
| 2026-10-14 | WSL2 Ubuntu 24.04 (WSLg, zenity) | Plain `sudo true` from Claude Code via `~/bin/sudo` shim | pass | dialog showed "Started from: claude on /dev/pts/0"; approved, ran |
| 2026-10-14 | WSL2 Ubuntu 24.04 (WSLg, zenity) | Detached `sudo` (setsid, display set) via shim and `/usr/bin/sudo` | pass | both refused "not started from your terminal", no dialog, logged |
| 2026-10-15 | Ubuntu 24.04 server, SSH, no tmux | `make test-agent-sudo`, `probe-argv.sh`, `tmux-test.sh`, `origin-test.sh` | pass | 96/96; `/proc` argv readable; 7/7 tmux; 7/7 origin/shim |
| 2026-10-15 | Ubuntu 24.04 server, SSH, no tmux | `make update` auto-install | pass | root-owned files, `sudo.conf` line, shim; `--check` up to date |
| 2026-10-15 | Ubuntu 24.04 server, SSH, no tmux | Claude Bash tool: plain `sudo true` via shim, no approval given | pass (timeout) | after 120s: `denied by user`, exit 1, logged `cancelled: true` |
| 2026-10-15 | Ubuntu 24.04 server, SSH, no tmux | "Another terminal" notice | **fail (design)** | notice went to a stale login (pts/0, from Sep 17) and a detached tmux pane running another Claude; nothing visible to the user. See findings below |
| 2026-10-15 | Ubuntu 24.04 server, SSH, Claude in tmux | `tmux-test.sh` | pass after test fix | `no-way-to-ask` set `TMUX_TMPDIR` to a missing dir; tmux 3.4 then falls back to `/tmp` and reached the real server (popup on the user's client). Case since replaced |
| 2026-10-15 | Ubuntu 24.04 server, SSH, Claude in tmux | Claude Bash tool: `agent-sudo true`, plain `sudo id -u` via shim | pass | popup over Claude's session; approved, ran as root; logged `approved` |
| 2026-10-15 | Ubuntu 24.04 server, SSH, Claude in tmux | Deny from the popup (labeled test command) | pass | `denied by user`, exit 1, logged `cancelled` |
| 2026-10-15 | Ubuntu 24.04 server | Removed "attached client" and `--approve` fallbacks | pass | `tmux-test.sh` 5/5 incl. new `outside-tmux` and `detached-session` refusals; both new cases fail against the previous askpass |
| 2026-10-15 | Ubuntu 24.04 server, SSH, Claude in tmux | Installed new version; real `sudo` via shim, in tmux and with `TMUX`/`TMUX_PANE` removed | pass | in tmux: popup, approved (so `TMUX` vars reach askpass through sudo); without them: refused in ~1s, no popup, logged `no prompt available` |
| 2026-10-15 | Ubuntu 24.04 server, SSH, no tmux | Claude Bash tool: `agent-sudo true`, plain `sudo id -u` via shim | pass | refused in 0.6s / 0.9s, no prompt, logged `no prompt available` |
| 2026-10-15 | Ubuntu 24.04 server, SSH, no tmux | User-typed `! sudo true` in Claude Code | refused (expected) | same refusal: `!` runs under Claude with no terminal for sudo, so the shim routes it to agent-sudo. The message said "run it yourself", which read as if `!` would work; now says to use a terminal outside the agent |
| 2026-10-15 | macOS 26.6.2 arm64 (sudo 1.9.17p2, bash 3.2, awk 20200816) | `make test-agent-sudo` | pass | 96/96 |
| 2026-10-15 | macOS 26.6.2 arm64 | `probe-argv.sh` | pass, with a finding | no `/proc`; `ps` *does* show sudo's args, but joined with spaces; sudo cwd unreadable, parent cwd via `lsof` works; no `pam_tid` in `sudo_local`; `/usr/local` root-owned, no `/usr/local/libexec` yet |
| 2026-10-15 | macOS 26.6.2 arm64 | Parsing via `ps` (scratch askpass, `AGENT_SUDO_PROMPT=none`) | **fail** | argument boundaries lost: `sh -c 'echo "a b" arg2'` shown as `sh -c echo '"a' 'b"' arg2`; a newline in `sh -c` splits words. The wrapper's own `--check` gets exact argv, so rule denies still hold; the prompt text and askpass's second analysis are wrong. See [macOS argv](#macos-argv-findings-2026-10-15) |
| 2026-10-15 | macOS 26.6.2 arm64 | "From your terminal" prerequisites | pass | Claude's tty `ttys005`, `[ -O /dev/ttys005 ]` true |
| 2026-10-15 | macOS 26.6.2 arm64 | Exact argv via JXA `sysctl` (fix) | pass | `make test-agent-sudo` 101/101, incl. 5 real-sudo cases: multi-line `sh -c`, empty arg, quote, tab, rule deny; plain `sudo -A` refused; mismatched wrapper refused. Old askpass fails 4 of the 5 |
| 2026-10-15 | macOS 26.6.2 arm64 | `make install-agent-sudo` | pass | root-owned files, `sudo.conf` line; no `/usr/local` warning (Apple Silicon, Homebrew in `/opt/homebrew`); `--check` up to date |
| 2026-10-15 | macOS 26.6.2 arm64 | Claude Bash tool: `agent-sudo`, Deny / Approve | pass | `denied by user`, exit 1; approved: `id -u` printed 0 |
| 2026-10-15 | macOS 26.6.2 arm64 | Plain `sudo` from Claude via `~/bin/sudo` shim | pass | dialog shown; rule deny (`chown -R nobody /etc`) refused in 0.06s, no dialog |
| 2026-10-15 | macOS 26.6.2 arm64 | Dialog display (screenshot) | pass | multi-line `sh -c` on separate lines; ~1.3 KB command shown in full (wraps, dialog grows, no scroll); "Requested by: sh <- zsh <- claude", "Started from: claude on /dev/ttys005". No Automation/Accessibility prompt seen |
| 2026-10-15 | macOS 26.6.2 arm64 | Approve with empty password (Return) | pass | `denied: no password entered` |
| 2026-10-15 | macOS 26.6.2 arm64 | Logging | pass, with notes | unified log, process `logger`; `-t` tag not shown, so query `/usr/bin/log show --predicate 'process == "logger"'` (`log` alone is a zsh builtin). Wrapper-side rule denies aren't logged (all platforms) |
| 2026-10-15 | macOS 26.6.2 arm64 (iTerm) | Terminal `sudo -k; sudo true` | pass | normal text prompt, no dialog |
| 2026-10-15 | macOS 26.6.2 arm64 (iTerm) | `agent-sudo true` from a terminal | pass | dialog shown |
| 2026-10-15 | macOS 26.6.2 arm64 (iTerm) | Dialog left open 120s | pass | closed itself; `denied by user` |
| 2026-10-15 | macOS 26.6.2 arm64, tmux 3.8 | `tmux-test.sh` | pass after test fix | BSD `script` exits on a FIFO stdin (`tcgetattr/ioctl: Operation not supported on socket`), so the fake client never attached and approve/deny/timeout failed (rc=3). Feeding it through `cat \| script` fixed it: 5/5 |
| 2026-10-15 | macOS 26.6.2 arm64, Claude in tmux 3.8 (local) | Claude Bash tool: `AGENT_SUDO_PROMPT=tmux agent-sudo ...`, Deny / Approve | pass | popup over Claude's pane; deny: `denied by user`, exit 1, logged `cancelled`; approve: `id -u` printed 0, logged `approved` (so `AGENT_SUDO_PROMPT` and `TMUX` reach askpass through sudo on macOS). Without the override, local runs use the dialog first |
| 2026-10-15 | macOS 26.6.2 arm64, Claude in tmux 3.8 (local) | Same with `TMUX`/`TMUX_PANE` removed | pass | refused in 0s, no popup, logged `no prompt available` |
| 2026-10-15 | Ubuntu 24.04 server, SSH | Security fixes 1, 3-7 (repo copy, not installed) | pass | `test.sh` 120/120 under gawk, mawk, `bash --posix`. Against the previous askpass 13 of the new cases fail. Through the real sudo: a script named `sudo` is refused ("not the real sudo", effective uid 1000) where the old askpass reached the prompt stage; `HOME=/tmp/x` no longer unprotects your home; prompt text checked by printing it |

## macOS argv: findings (2026-10-15)

`ps -o args=` on macOS shows a setuid sudo's arguments, so askpass takes that
path and never falls back to the wrapper, but `ps` joins arguments with spaces.
`set -- $args` then re-splits them, so what the dialog shows is not what runs.

Exact argv is available for a same-user process through `sysctl`
`KERN_PROCARGS2`; `/usr/bin/perl` (in base macOS) can call it with
`syscall(202, ...)`. Tested: works on a same-user process (spaces, newlines,
trailing `''` all exact), returns `EINVAL` for sudo itself (setuid). So on macOS
askpass should read the agent-sudo wrapper's argv (its parent) that way, and
check it joins to the same string `ps` shows for sudo.

**Fixed (2026-10-15)** with the JXA reader below; `test.sh` now covers it
through the real sudo.

Native alternative, also tested: JavaScript for Automation
(`osascript -l JavaScript`) can call `sysctl()` through `ObjC.bindFunction`.
Same results (exact argv including UTF-8, `EINVAL` on sudo), ~50 ms vs ~10 ms
for perl. `osascript` is already needed for the dialog, and Apple has listed
perl among the scripting runtimes it may drop (python went in 12.3), so JXA is
the better choice. The `sysctl` command can't read `kern.procargs2`;
`launchctl procinfo` needs root. Every tool askpass uses resolves to a stock
copy under SIP (`/bin/ps`, `/usr/bin/awk`, `/usr/sbin/lsof`), so Homebrew
packages on the test machine don't change these results.

## SSH without tmux: findings (2026-10-15)

Context: Claude Code over SSH, not in tmux, one visible terminal (the one Claude
is running in). The goal was a prompt in that same terminal.

**The "another terminal" fallback doesn't work in practice.** Targets come from
`who`, which lists every login tty, including ones the user can't see:

- a stale SSH login from weeks ago (still alive on the server);
- the pane of a detached tmux session. That pane was running another Claude
  Code, so the notice was also written into its TUI and may have garbled it.

The request then waited the full 120s with nothing visible, instead of being
refused right away. The user questioned the premise too: an approval request
should not go to a different terminal.

**Decision (2026-10-15):** a request only appears where the user is already
looking (the agent's own tmux session, on a client attached to it) or pops up
in front of them (desktop dialog). The `agent-sudo --approve` fallback and the
"most recently active tmux client anywhere" fallback were removed; everything
else is refused at once with the command to run yourself. Before the change,
an agent in a detached tmux session also sent its popup to whichever client
tmux picked, possibly showing a different session.

**Prompting on the agent's own terminal by borrowing it doesn't work.** The
agent TUI (raw mode) reads every keystroke, so askpass can't just read
`/dev/pts/N`. Tried, on a private pty with zsh and bash and a fake raw-mode TUI
that handles SIGTSTP/SIGCONT like Claude Code (scripts were in a scratch dir,
not kept):

1. SIGSTOP the shell, SIGTSTP the agent's process group (= Ctrl-Z), read the
   password on the tty with echo off, restore, SIGCONT the agent, SIGCONT the
   shell.
2. Result: password read correctly, the agent never saw it, the agent stayed
   the foreground process group. **But** both zsh and bash came back to their
   prompt after the SIGCONT and started reading the tty alongside the agent: a
   later keystroke went to the shell (`zsh: command not found: Qecho`).
3. Control: SIGSTOP + SIGCONT of the shell alone, without touching the agent,
   gives the same result. Root cause not identified.

So the shell can't simply be frozen out of the way.

**Parked options for the same-terminal case:**

- **Ctrl-Z + shell hook** (what the user already does by hand: Ctrl-Z, run sudo,
  `fg`). askpass sends SIGTSTP to the agent; zsh takes the terminal back as
  usual; a `precmd` hook sees the pending request for this tty, shows it, reads
  the password with echo off, hands it to askpass, then runs `fg`. Needs a
  request channel from root askpass to the user's shell. Untested.
- **Claude Code mod pane.** Mods (Claude Code >= the version
  [cc-askpass](https://github.com/GoneTone/cc-askpass) needs, 2.1.286) can open
  a pane with a one-line `Input`, run a long-lived helper, and pass data to a
  command's stdin. Plan would be: keep the root-owned askpass (rules, `/proc`
  argv, logging) and add a mod as another prompt surface. Caveats: `Input` has
  no hidden-text option (the mod must mask it; cc-askpass has a masking bug), the
  password passes through the Claude Code process (not the model), other mods
  can see the keystrokes, and it's Claude-only. cc-askpass as-is keeps its
  helper in the user-writable plugin dir and has no rules.
- **Wrapper that owns the terminal** (a minimal multiplexer around the agent).
  Robust but a new component; effectively what tmux popups already give.

**Decision for now:** run agents in tmux over SSH (validated 2026-10-15);
revisit the above later.

**Prior art checked** (2026-10-15): Anthropic closed requests for a sudo prompt,
stdin passthrough and host-shell mode as not planned
([#18316](https://github.com/anthropics/claude-code/issues/18316),
[#37523](https://github.com/anthropics/claude-code/issues/37523),
[#83046](https://github.com/anthropics/claude-code/issues/83046) for `!` sudo);
PTY support ([#9881](https://github.com/anthropics/claude-code/issues/9881)) is
an open request. Community tools:
[sido-askpass](https://github.com/patdx/sido-askpass) (same design as this; its
`/dev/tty` mode also gives up when a TUI owns the terminal),
[SudoGate](https://github.com/tomasWade/sudogate) (review UI on the SSH client
via `ssh -R`), [sudoplz](https://github.com/crypdick/sudoplz) and
[claude-sudo-askpass](https://github.com/dgutson/claude-sudo-askpass) (desktop
dialogs only). None solve a raw-tty prompt next to a running TUI.

## Review findings (2026-10-15)

Four reviews (code quality, principal/security, QA, docs) of the branch.
"Reproduced" means confirmed with `askpass --check` on Linux; the rest are from
reading the code. Work order: security, bugs + test strength, docs, refactors.

### Decisions

- **Install guard (done).** `make install-agent-sudo` runs
  `install.sh --review` first: it shows a diff of each installed file that
  would change, warns about uncommitted edits to `install.sh`/`Makefile`, and
  asks y/N on `/dev/tty`. With no terminal it stops with a message. It can't
  stop an agent that also rewrites the Makefile; documented in README.
- **Missing rules file: keep warning.** The file is root-owned, so an agent
  can't remove it; it only goes missing on a broken install, and the prompt
  already says "only built-in checks ran". Refusing would block all agent sudo
  for no security gain.
- **macOS argv: fixed on the Mac** (commit 4dcc462, see
  [macOS argv](#macos-argv-findings-2026-10-15)). One gap is left: security item 2.
- **The user's constraints for every fix:** no reduction in what sudo can do,
  and no silent refusals. Every refusal prints the reason and the command to
  run yourself.

### Security

Fixed 2026-10-15 except 2 (tests in `test.sh`; results log):

1. **Fixed.** Caller check was only the parent's `comm`; a fake `sudo` could
   run the real helper and collect the password. Now the parent must have
   effective uid 0 and your real uid.
2. **Open (Mac).** The wrapper's exact argv (agent-controlled) is accepted if
   its letters and digits match `ps` for sudo. A forged argv that differs only
   in punctuation or argument boundaries passes (`~/x` vs `/x`,
   `sh -c 'rm -rf /etc'` vs `sh -c rm -rf /etc`). Fix: compare the
   space-joined argv, encoded the way macOS `ps` encodes it, to the exact `ps`
   string; flag arguments containing spaces in the prompt.
3. **Fixed.** askpass PATH is now system dirs first, `/usr/local/bin` and
   `/opt/homebrew/bin` last (only tmux and timeout come from there). The tmux
   popup runs `/bin/sh`. A planted tmux in a user-writable Homebrew dir is
   still used on Macs, but that user already controls their own tmux server.
4. **Fixed.** Protected home comes from the account database (`getent` /
   `dscl`) when sudo calls askpass; the agent's `$HOME` is protected as well.
   `--check` (the wrapper's pre-flight, tests) still uses `$HOME`.
5. **Fixed.** Abbreviated long options are expanded like getopt_long
   (`--chd` -> `--chdir`). Ambiguous or unknown ones are left alone: sudo
   rejects them before calling askpass.
6. **Fixed.** `find -delete` with no path checks the current directory;
   `<` and `>` end a word. `/private/tmp` added to protected paths.
7. **Fixed.** Prompt shows run-as, directory, origin and warnings first, then
   the command with every line prefixed `| `, so text inside an argument can't
   pass for part of the prompt. Invisible and bidi characters are shown as
   `<U+XXXX>` with a warning; any non-ASCII and commands over 20 lines get a
   warning. Newlines stay real so scripts stay readable (the Mac test checked
   multi-line display).

### Bugs (to fix)

- ssh-askpass dialog has no timeout (askpass:351-356).
- `install.sh --check` accepts any `Path askpass` line (install.sh:38).
- Refusal hint drops sudo's options: `sudo -u postgres psql` suggests
  `sudo psql` (askpass:583).
- macOS case-insensitive filesystems: `RM -rf /etc`, `CSRUTIL disable` not
  caught. (`/private/tmp` fixed.)
- Unknown `AGENT_SUDO_PROMPT` values are silently ignored.
- Empty password gives `denied: no password entered`; docs say `denied by user`.

### Tests (to fix)

- test.sh only checks allow/warn/deny, not the reason; deleting five different
  rules still passed 96/96. Add an expected-reason substring.
- No automated coverage of `prompt_mode` (argv reading, caller check, cwd).
- No awk matrix (mawk/gawk/BWK); test.sh uses whatever `awk` is.
- tmux-test.sh: dead check at line ~200, fixed sleeps, never asserts the popup
  text, shares `/tmp/agent-sudo.*` with real requests.
- Add cases: the reproduced gaps above, missing/empty rules file,
  `HOME=/Users/tester`, `rm -rf /etc/`, `rm / -rf`, `sudo -s rm -rf /`.

### Docs (to fix)

- macOS still described as untested (both READMEs, this file).
- No uninstall section. SSH ordering wording imprecise. Prompt table lacks
  ssh-askpass. Top-level README doesn't mention the `~/bin/sudo` shim.
- Stale counts ("7/7 tmux"), branch-specific wording, Notes-for-Claude repeats
  README.

### Refactors (later)

`prompt_mode` ~110 lines (split argv read / cwd / prompt text); duplicated
deny reporting and `ps` lookups; `parse_sudo_opts` appends to `MODE` without
saying so; unquoted tmux target; stale comment at askpass:373.

### Still to run on a Mac

The Apple Silicon Mac covered the probe, tests, dialog, shim, tmux and logging
(results log, 2026-10-15). Left:

1. SSH into the Mac: outside tmux, `agent-sudo true` is refused with "no way to
   ask" and no dialog appears on the Mac's screen; inside tmux, the popup.
2. An Intel Mac (Homebrew in `/usr/local`): `make install-agent-sudo` should
   warn about `/usr/local`; check which `ps`/`awk`/`osascript` askpass uses.
3. Touch ID for sudo, on a machine that has it enabled.
4. Rerun `make test-agent-sudo` and `dev/tmux-test.sh` after the security fixes.

## Notes for Claude (picking this up in a new session)

This conversation's history isn't available on other machines, so this is the
context.

**Goal.** Let AI agents (Claude Code, Cursor, Codex, ...) and `!` commands run
sudo with per-command approval that shows the exact command. Terminal sudo must
behave normally. It has to be portable across macOS and Debian/Ubuntu, and work
over SSH without a GUI. The user will not accept NOPASSWD, `timestamp_type=global`,
or passwords passing through the agent.

**Design.** See `README.md` for the user-facing version.
- `agent-sudo` runs the rules check, then `sudo -k -A "$@"`.
  - `-A` routes the password request to the askpass helper even with no tty or
    display.
  - `-k` makes every call prompt, and doesn't refresh the credential cache.
  - It is deliberately *not* `exec`, so askpass can read the wrapper's argv when
    sudo's argv is unreadable (expected on macOS).
- `askpass` is a POSIX sh script with an embedded POSIX awk program.
  - It reads sudo's argv from `/proc/$PPID/cmdline` (exact). On macOS it reads
    the wrapper's argv exactly via JXA + `sysctl` `KERN_PROCARGS2`, checked
    against `ps` for sudo; anything else there is refused. On Linux with
    `/proc` hidden it falls back to `ps`, then the wrapper's `ps` args (lossy).
    If none of those work, it refuses.
  - It analyzes the command, then prompts. In order: a GUI dialog (osascript;
    kdialog on KDE (two boxes) or zenity elsewhere), a tmux popup (only on a
    client attached to the agent's own session). Nothing else: the user wants
    requests only where they're looking or popping up in front of them, so
    other terminals and other tmux sessions are never used. Over SSH the tmux
    popup comes first.
  - The user does not want GNOME libraries on KDE machines, so zenity is never
    installed there.
  - The SSH/headless case matters most to the user.
  - Fail closed everywhere: unreadable argv, awk failure, malformed rules,
    unknown cwd for relative recursive deletes.
- Everything is installed root-owned under `/usr/local`, plus `Path askpass` in
  `/etc/sudo.conf`. If the helper were user-writable, any same-user process
  could rewrite it to log the password.

**Threat model.** It protects against mistakes and runaway agents, not a
malicious same-user process. That process could set its own `SUDO_ASKPASS` and
show a fake dialog. Don't over-claim this.

**Who can ask.** The user rejected a name allowlist of agents. The rule is:
a prompt may appear only if some ancestor of sudo has a controlling terminal
owned by the user (agent TUIs, tmux, things they ran). Anything else (cron,
services, desktop apps) is refused without a prompt; the user explicitly does
not want random programs raising password requests. The `bin/sudo` shim
applies the same rule to decide between agent-sudo and plain sudo.

**Testing without root.** Copy `askpass` to a scratch dir and point the
installed-path constants at the repo with sed:
`sed "s|^RULES_FILE=.*|RULES_FILE=$PWD/agent-sudo/rules|"`. Do the same for
`SELF=` and `WRAPPER=` where needed. Then run
`AGENT_SUDO_PROMPT=none SUDO_ASKPASS=<copy> sudo -k -A <cmd>`. sudo fails
harmlessly ("no password was provided"), and the refusal message shows how the
command was parsed. A stub askpass that writes `ps`/`/proc` info and exits 1 is
the safe way to probe; `dev/probe-argv.sh` does exactly that.

**Gotcha.** Claude Code's built-in safety check blocks any Bash command whose
text contains a destructive removal like `rm -rf /`, even inside a test that
can't run it. Use `test.sh` for those cases, or use `chown -R nobody /etc` /
`csrutil disable` as harmless deny probes.

**Open items.**
- Everything under "Not verified yet", and "Review findings (2026-10-15)".
- A prompt in the agent's own terminal without tmux (parked options in the same
  section).
- A PR hasn't been opened.
- The agent instruction snippet (README, "Telling agents about it") hasn't been
  added to `~/.claude/CLAUDE.md` or `AGENTS.md` files on any machine yet.
- macOS dialog grows with the command and can't scroll: a ~1.3 KB command fills
  most of a laptop screen, so a much longer one may run off it. Untested.
- Rule denies caught by the wrapper's `--check` (before sudo) aren't logged.
- busybox awk ignores invalid regexes (fails open). Not a target platform; it's
  documented.
