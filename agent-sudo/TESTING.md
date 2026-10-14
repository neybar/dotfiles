# agent-sudo: testing status and handoff notes

Branch `feature/agent-sudo`. This file tracks what has been verified on which
platform, and gives the steps for the rest. Add your results to the
[results log](#results-log) as you go.

## Quick start on another machine

```sh
cd ~/Projects/dotfiles
git fetch origin && git switch feature/agent-sudo
make test-agent-sudo               # rule tests: no root, no prompts
sh agent-sudo/dev/probe-argv.sh    # what the helper can see of sudo here
sh agent-sudo/dev/tmux-test.sh     # tmux popup: approve / deny / timeout
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
| tmux popup | `dev/tmux-test.sh` against a real attached client | approve ~0s, deny ~1s, timeout closes popup, no leftovers |
| Logging | `journalctl -t agent-sudo` | entries present; long commands capped at 2000 chars |
| Terminal sudo unaffected | sudo source (`tgetpass.c`) + man page | askpass only without a tty or with `-A` (not yet observed after install) |

## Not verified yet

### macOS (biggest open questions)

1. `make test-agent-sudo`. This exercises macOS `/bin/sh` (bash 3.2) and BWK
   awk, which haven't been tested. All cases should pass.
2. `sh agent-sudo/dev/probe-argv.sh`, and record the output. Key questions:
   - Does "ps args of sudo" show the full command, or only `(sudo)` / nothing?
     If it's `(sudo)`, plain `sudo` from agents is refused and only `agent-sudo`
     works (by design; see README).
   - Does "sudo cwd (lsof)" or "parent cwd (lsof)" give a real directory?
3. `brew install tmux` if needed, then `sh agent-sudo/dev/tmux-test.sh`. This
   uses BSD `script` syntax there.
4. `make install-agent-sudo`, and note any warnings. On Intel Macs with
   Homebrew, expect a warning if `/usr/local` or `/usr/local/libexec` is
   user-writable; decide whether to move the install prefix.
5. In Terminal.app/iTerm: `sudo -k; sudo true` should give the normal text
   prompt, with no dialog.
6. `agent-sudo true` from a terminal should show the macOS dialog with `true`.
   Click Deny and expect `denied by user`. Run it again with your password and it
   should succeed.
7. From Claude Code: `! agent-sudo true`, then ask Claude to run
   `agent-sudo true` with its Bash tool. Check that the dialog shows
   "Requested by" with a sensible process chain.
8. SSH into the Mac:
   - outside tmux, `agent-sudo true` should be refused with "no way to ask for
     approval", and no dialog should appear on the Mac's screen;
   - inside tmux, you should get the popup.
9. Unknown: interaction with Touch ID for sudo (`pam_tid` in
   `/etc/pam.d/sudo_local`). sudo may ask for Touch ID before calling askpass,
   which would bypass the command display. Test it if Touch ID sudo is enabled.

### Linux desktop / WSLg

1. `sudo apt install zenity`, then `make install-agent-sudo`.
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

### Linux server over SSH (no GUI)

1. `make install-agent-sudo` (zenity isn't needed).
2. Inside tmux, `agent-sudo true` should show the popup in your terminal.
   Outside tmux it should be refused with "no way to ask for approval".
3. `sh agent-sudo/dev/tmux-test.sh`.

## Results log

| Date | Machine / OS | Step | Result | Notes |
|---|---|---|---|---|
| 2026-10-14 | WSL2 Ubuntu 24.04 | everything in "Verified so far" | pass | before install |

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
  - It analyzes the command, then prompts: a GUI dialog
    (osascript/zenity/kdialog/ssh-askpass) or a tmux popup. Over SSH the popup
    comes first.
  - Fail closed everywhere: unreadable argv, awk failure, malformed rules,
    unknown cwd for relative recursive deletes.
- Everything is installed root-owned under `/usr/local`, plus `Path askpass` in
  `/etc/sudo.conf`. If the helper were user-writable, any same-user process
  could rewrite it to log the password.

**Threat model.** It protects against mistakes and runaway agents, not a
malicious same-user process. That process could set its own `SUDO_ASKPASS` and
show a fake dialog. Don't over-claim this.

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
- `make check-agent-sudo` doesn't check that the `sudo.conf` line exists.
- busybox awk ignores invalid regexes (fails open). Not a target platform; it's
  documented.
