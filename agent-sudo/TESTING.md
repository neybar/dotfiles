# agent-sudo: testing status and handoff notes

This file tracks what has been verified on which platform, and gives the
steps for the rest. Add your results to the
[results log](#results-log) as you go.

## Quick start on another machine

```sh
cd ~/Projects/dotfiles
git fetch origin && git switch feature/agent-sudo   # until it's merged
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
| Rule tests (96 cases then; 132 since 2026-10-15) | `make test-agent-sudo` with dash+gawk, dash+mawk, `bash --posix`+gawk/mawk | pass |
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

Steps 1-4 passed on 2026-10-15 (see results log). The prompt now only appears in the agent's own tmux session; see
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
| 2026-10-15 | Ubuntu 24.04 server, SSH, tmux 3.4 | Bug fixes, reason-checked tests, tmux-test.sh hardening (repo copy) | pass | `test.sh` 132/132 under gawk, mawk, `bash --posix`; every one-rule-deleted mutant fails; `tmux-test.sh` 5/5, and fails both mutants (silent popup, wrong-session client) |
| 2026-10-15 | Ubuntu 24.04 server, SSH, tmux 3.4 | Refactor (repo copy), after pulling the Mac's 677ed5d and 5350477 | pass | `test.sh` 132/132 under gawk, mawk, `bash --posix`; `tmux-test.sh` 5/5; `origin-test.sh` all ok; prompt chain unchanged (`agent-sudo <- zsh <- claude`); `make sync-agent-sudo` prints the check once and stops without a terminal |
| 2026-10-15 | Ubuntu 24.04 server, SSH, no tmux | Installed c88a5e9 (`make install-agent-sudo`: diff shown, y/N answered); Claude Bash tool | pass | `--check` up to date; `agent-sudo -u nobody true` and shimmed `sudo id -u` refused at once with `cd /tmp && sudo -u nobody true` / `cd /tmp && sudo id -u`; `chown -R nobody /etc` and `--chd /etc chown -R nobody .` denied by the wrapper; `HOME=/tmp/x ... chown -R nobody /home/<you>` passed the wrapper's pre-flight and was denied by askpass (logged); `AGENT_SUDO_PROMPT=gui,tmux` named as unknown; a script named `sudo` running the installed askpass refused (effective uid 1000). Note: `test.sh`'s real-sudo cases write `cancelled`/`no prompt available` lines to the system log |
| 2026-10-15 | macOS 26.6.2 arm64 (bash 3.2 `sh`, BWK awk 20200816) | `test.sh` at 856ec39 (repo copy) | 131/133 | Two macOS-only failures. (1) Fake `sudo` refused as "parent process is 'sh'": macOS `ps -o comm=` shows argv[0], and for a script that is the interpreter, so the uid check was never reached. (2) U+200B case refused as "arguments don't match": with `LANG=en_US.UTF-8`, `ps` shows U+200B as `\040^K` and U+202E as `\040-.`, so the letters-and-digits check saw `K` on one side only |
| 2026-10-15 | macOS 26.6.2 arm64 | `LC_ALL=C ps -ww -o args=` encoding, all 255 bytes plus 30 random byte strings | mapped | tab `\011`, newline `\012`, other control bytes `^X`, DEL `^?`, printable ASCII as is (`\` and `^` not escaped), 128-159 `M^X`, 160 `\240`, 161-254 `M-x`, 255 `M^?`, arguments joined by one space (a trailing `''` leaves a trailing space). No byte's form depends on its neighbours. The new `mac_ps_args` matches `ps` exactly on all cases |
| 2026-10-15 | macOS 26.6.2 arm64 | `test.sh` after security fix 2 (repo copy) | pass | 140/140 with case folding always on (`RM -rf /etc`, `CSRUTIL disable`, `rm -rf /ETC` denied; BWK `tolower()` and the for-in copy fine); `mark_invisible` cases (U+202E, U+200B) pass. New Darwin cases: punctuation-only forgery (`: ~/x` vs `: /x`) and trailing-`''` forgery refused; spaces and `\011`/`^A` warnings shown. Mutants: the old letters-and-digits check fails the `~/x` case; no space warning fails its case. Fake `sudo` on Darwin now uses `exec -a sudo`, so it reaches the uid check |
| 2026-10-15 | macOS 26.6.2 arm64, tmux 3.8 | `dev/tmux-test.sh` at 856ec39, BSD `/usr/bin/script` | pass | 5/5 (approve, deny, timeout, outside-tmux, detached-session), each popup counted through the harness log; 0 leftover request dirs |
| 2026-10-15 | macOS 26.6.2 arm64 | `test.sh` after the escape recheck (repo copy) | pass | 143/143. A wrapper claiming `sh -c 'exit 0; rm -rf\011/etc'` while sudo gets a real tab, and the same with `\012` for a newline, are denied (`recursive rm on a protected path: /etc`); before, both got only warnings. Real commands exit before the `rm`. `mac_ps_decode` gives a valid reading of `ps` (re-encodes to the same text) for all 255 bytes and 300 random strings. Mutants: no recheck fails 5 cases; no `\011`-first decoding fails the tab case |
| 2026-10-15 | macOS 26.6.2 arm64 (bash 3.2 `sh`, BWK awk 20200816), tmux 3.8 | Refactor c88a5e9 (repo copy) | pass | `test.sh` 143/143 (`check_recursive` / `check_find` under BWK awk); `tmux-test.sh` 5/5 with BSD `script`. macOS `ps -o ppid= -o tty= -o comm=` gives that order; comm is argv[0], possibly a full path, and the chain shows base names (`sh <- zsh <- claude`). Prompt printed through the real sudo: details, then warnings (spaces, `<U+202E>`, non-ASCII), then `\| : 'a<U+202E>b' 'two words'` |

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

Historical: the "another terminal" fallback described here was removed in
949a0f0. Context: Claude Code over SSH, not in tmux, one visible terminal (the
one Claude is running in). The goal was a prompt in that same terminal.

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

Fixed 2026-10-15 (tests in `test.sh`; results log):

1. **Fixed.** Caller check was only the parent's `comm`; a fake `sudo` could
   run the real helper and collect the password. Now the parent must have
   effective uid 0 and your real uid.
2. **Fixed (Mac).** The wrapper's exact argv (agent-controlled)
   was accepted if its letters and digits matched `ps` for sudo, so `~/x` vs
   `/x` passed. Now `mac_ps_args` encodes `sudo -k -A ARGS` the way
   `LC_ALL=C ps -o args=` does (table in the results log) and it must equal
   sudo's `ps` string exactly. `ps` stays ambiguous in two ways, flagged in
   the prompt: an argument containing a space ("where one argument ends and
   the next begins can't be cross-checked"), and literal text like `\011`,
   `^A` or `M-a`, which looks the same as the tab, control or non-ASCII byte
   it stands for. Boundaries don't change the rules' verdict: `analyze` reads
   the space-joined `"$*"`, which the exact match makes identical (a claimed
   `sh -c rm -rf /etc` and a real `sh -c 'rm -rf /etc'` both deny). The escape
   ambiguity did: a claimed literal `\011` hid the tab in sudo's
   `rm -rf<TAB>/etc`. So `mac_recheck` also analyzes the command with every
   escape-like sequence decoded (`mac_ps_decode`, `\011` `\012` `\240` first)
   and keeps the union of denies and warnings. It reads too much where the
   text really was literal, which can only add findings.
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

### Bugs

Fixed 2026-10-15 except where noted:

- **Fixed.** ssh-askpass dialog had no timeout; now runs under `timeout`.
- **Fixed.** `install.sh --check` accepted any `Path askpass` line. It now
  wants the exact line, and prints a note (without failing, so `make update`
  doesn't ask for the password every time) when another helper is named.
- **Fixed.** The refusal hint dropped sudo's options. It now keeps them
  (minus the `-k -A` agent-sudo adds) and starts with `cd DIR &&` when the
  directory is known: `cd /srv && sudo -u postgres psql`.
- **Fixed.** macOS case-insensitive filesystems: on macOS, command names,
  protected paths and rules are compared ignoring case (`RM -rf /etc`,
  `CSRUTIL disable` denied). `--check --fold` does the same on Linux for
  tests. Folding only adds matches.
- **Fixed.** Unknown `AGENT_SUDO_PROMPT` values are reported in the refusal
  (`none` is accepted and disables prompts).
- **Docs step.** Empty password gives `denied: no password entered`; docs say
  `denied by user`.

### Tests

- **Fixed.** `t` takes `deny:REASON` / `warn:REASON` and checks the output
  contains REASON; rule-based cases carry their reason. Deleting any single
  rule from `rules` now fails at least one test (QA's run: five survived).
- **Fixed.** tmux-test.sh: popups are counted through a log the harness
  writes (the old "popup opened" check could never fire); each popup must show
  a message built at run time (the typed command line can't satisfy it);
  waits poll for the client and the popup instead of fixed sleeps; leftover
  request dirs are counted against the start, so a real request running at
  the same time doesn't fail it. Checked by mutation: a popup that doesn't
  print the message, and one that picks a client of any session, both fail.
- **Partly.** `prompt_mode` coverage: real-sudo cases now cover the caller
  check, account home, prompt layout and refusal hint. Not covered: hidden
  `/proc` fallback, cwd lookup via `lsof`.
- **Open.** No awk matrix in `make test-agent-sudo` (done by hand on Linux:
  gawk, mawk).
- **Open.** Cases still to add: missing/empty rules file,
  `HOME=/Users/tester`, `sudo -s rm -rf /`.

### Docs

**Fixed 2026-10-15.** macOS no longer described as untested (the Mac session
updated README and the macOS section). README: uninstall section, prompt order
over SSH, ssh-askpass row, prompt layout, deny messages (`denied by user` vs
`denied: no password entered`), tmux popup keys, `~/bin/sudo` ownership,
install diff, home directory and case-insensitive matching. Top-level README:
shim and install confirmation. askpass header: environment variables. Here:
counts, branch wording, historical lead-in, Notes for Claude trimmed.

### Refactors

**Done 2026-10-15** (no behaviour change; all suites pass): `prompt_mode`
split into `check_caller`, `find_cwd` and `build_prompt_text`; shared
`report_denies`; one `ps` per ancestor in `from_your_terminal`; `uname` once
(`OS`); `optval` takes one spelling per option; awk `check_segment` split into
`check_recursive` and `check_find`; kdialog comment no longer duplicated;
Makefile runs `install.sh --check` once; `install.sh` reports each installed
file; `test.sh` cleans up on interrupt and its warn cases are all under
"Allowed with a warning"; `bin/sudo` uses `set -u`. Left as is: the
hard-coded install paths (each file must stand alone; `dev/*` and `test.sh`
rewrite the `NAME=` lines).

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

**Design.** `README.md` describes it for users; what it doesn't say:
- `agent-sudo` is deliberately *not* `exec`: on macOS askpass reads the
  wrapper's argv (JXA + `sysctl` `KERN_PROCARGS2`) and checks it against `ps`
  for sudo. On Linux with `/proc` hidden it falls back to `ps`, then the
  wrapper's `ps` args (lossy).
- askpass only answers the setuid sudo (parent effective uid 0, your real uid).
- Prompts only where the user is looking: the desktop dialog, or a tmux popup
  on a client attached to the agent's own session. Other terminals and other
  tmux sessions are never used (the user's decision, 2026-10-15).
- Fail closed: unreadable argv, awk failure, malformed rules, unknown cwd for
  relative recursive deletes. A missing rules file only warns (root-owned, so
  only a broken install loses it).
- The SSH/headless case matters most to the user. No GNOME libraries on KDE
  machines, so zenity is never installed there.

**Constraints for any change.** No reduction in what sudo can do, and no
silent refusals: every refusal says why and gives the command to run yourself.

**Threat model.** Mistakes and runaway agents, plus the deceptions the review
fixed (fake sudo parent, forged display, agent `$HOME`, repo edits before an
install). Not a malicious same-user process in general: it could set its own
`SUDO_ASKPASS` and show a fake dialog. Don't over-claim this.

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
