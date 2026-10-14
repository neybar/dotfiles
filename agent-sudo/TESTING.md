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
sh agent-sudo/dev/tmux-test.sh     # tmux popups + agent-sudo --approve, real ttys
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
| tmux popup, agent outside tmux | same, agent not in tmux; popup goes to the attached client | approved |
| `agent-sudo --approve` from another terminal | same, no tmux; approver on a separate pty | approved; notice written to the "other terminal" |
| No way to ask | no tmux client, no other terminal | refused immediately (no wait) |
| "From your terminal" rule | `dev/origin-test.sh`: as Claude Code vs. a detached (setsid) process | allowed vs. refused without prompt |
| `~/bin/sudo` shim routing | same | from terminal: agent-sudo; detached: plain sudo; no loop when the shim is first in PATH |
| Notice never hits the agent's terminal | `other_ttys` with Claude Code on pts/0 | listed only pts/1, a different terminal |
| Logging | `journalctl -t agent-sudo` | entries present; long commands capped at 2000 chars |
| `install.sh` install / `--check` / rerun / zenity via `--gui` | as root in an `ubuntu:24.04` Docker container | installs root-owned, adds one `sudo.conf` line, reports up to date, detects a changed file |
| Makefile `sync-agent-sudo` | dry runs: not installed, `SKIP_AGENT_SUDO=1` | detects missing pieces; skip works (real sudo run pending) |
| Terminal sudo unaffected | sudo source (`tgetpass.c`), then observed after install | normal text prompt in a terminal |
| Real install + dialog (zenity, WSLg) | `make update`, then approve/deny/display checks from Claude Code | all pass; see results log |

## Not verified yet

### macOS (biggest open questions)

The dialog is AppleScript's `display dialog` via `osascript`, which is built in,
so nothing gets installed. None of it has run on a Mac yet. Specific unknowns:
whether multi-line commands and very long commands display fully, whether the
dialog comes to the front when triggered from a background process, and whether
macOS asks for Automation/Accessibility permission the first time.

1. `make test-agent-sudo`. This exercises macOS `/bin/sh` (bash 3.2) and BWK
   awk, which haven't been tested. All cases should pass.
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

1. `make install` (nothing extra gets installed with no display). Without sudo
   rights, use `SKIP_AGENT_SUDO=1 make install`.
2. `sh agent-sudo/dev/tmux-test.sh`, which should be all ok.
3. Real runs, with Claude Code in your SSH session:
   - Claude inside tmux, asked to run `agent-sudo true`: the popup appears over
     its pane.
   - Claude not in tmux, while you also have a tmux session attached from
     another SSH login: the popup appears in that session.
   - No tmux, with a second plain SSH login open: that terminal shows
     `[agent-sudo] ... Run: agent-sudo --approve`. Running it shows the command
     and takes your password.
   - Only one SSH login and no tmux: refused right away, with the command to
     run yourself.
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
  - It reads sudo's argv from `/proc/$PPID/cmdline` (exact), otherwise from `ps`,
    otherwise from the wrapper's argv. If none of those work, it refuses.
  - It analyzes the command, then prompts. In order: a GUI dialog (osascript;
    kdialog on KDE (two boxes) or zenity elsewhere), a tmux popup (agent's pane
    or your attached client), or a request answered by `agent-sudo --approve`
    in another of your terminals. Over SSH the terminal prompts come first.
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
- Everything under "Not verified yet".
- A PR hasn't been opened.
- The agent instruction snippet (README, "Telling agents about it") hasn't been
  added to `~/.claude/CLAUDE.md` or `AGENTS.md` files on any machine yet.
- busybox awk ignores invalid regexes (fails open). Not a target platform; it's
  documented.
