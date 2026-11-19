# dotfiles

Personal dotfiles for both macOS and Linux (both are first-class targets; changes must work on each), forked long ago from mathiasbynens/dotfiles. Shell is zsh + oh-my-zsh + powerlevel10k. See `README.md` for user-facing setup docs.

This file is the **root agent instructions** for every tool (Claude Code, Codex, Cursor): `CLAUDE.md` imports it and adds only Claude Code-specific rules. Neither is copied into `~`, nor are the agent-tool dirs `.agents/`, `.codex/`, `.cursor/`, `.beads/` (all excluded in the `Makefile`).

## Never leak secrets

This repo is **public**. No tokens, passwords, API keys, private keys, private IP addresses, or identifying live machine config in any file, commit message, PR title or body, issue, or comment. Machine-specific values go in files that are not tracked: `~/.gitconfig`, `~/.zshrc.local`, `zsh_custom/*.local.zsh`, `~/.config/beads/credentials`.

- **Before every commit**: run `gitleaks git --staged --no-banner` (exit 1 means a finding: stop, remove it) and read `git diff --cached` for hostnames, IPs, emails and paths that identify the machine or its owner.
- **Never print secrets**: don't `cat` credentials files, `env | grep` tokens, or paste command output that holds one into a commit, PR, or issue.
- **If a secret reaches a commit**: don't push. If it was already pushed, tell James so it can be rotated; deleting it or rewriting history does not un-leak it.


- Dotfiles are **copied**, not symlinked: `make copy` rsyncs the repo root into `~`. Editing `~/.aliases` does not change the repo, and editing the repo does not change `~` until `make copy` runs. Use `make diff` / `make diff-long` to preview.
- Exceptions:
  - `.zshrc` is symlinked to `~/.zshrc`.
  - `.gitconfig` is not copied; `make install` adds it to the global git config via `include.path`. Machine-specific git settings (name, email) live in `~/.gitconfig`.
  - `init/iterm_profiles.pinfo` (iTerm2 dynamic profiles) is copied, not linked, into `~/Library/Application Support/iTerm2/DynamicProfiles/` by `make sync-iterm` (part of `make install`, macOS only), via a temp file and rename so iTerm never reads it half-written. iTerm watches that folder live and can rewrite profiles there, so never link it to the repo.
  - The rest of `init/` is also installed by `make install` on macOS only: `make sync-fonts` (fonts into `~/Library/Fonts`, never replacing one already there) and `make sync-terminal` (Terminal.app profiles imported with `open`, only when missing). See `init/Readme.md`.
  - `.zshrc.local` is a template, copied only if `~/.zshrc.local` doesn't exist. Machine-specific PATH/plugins go there.
  - `ZSH_CUSTOM` is set in `.zshrc` to `$HOME/Projects/dotfiles/zsh_custom`, so changes there are live in new shells (only for a checkout at that path). `zsh_custom/*.local.zsh` is git-ignored for machine-specific config.
- Anything at the repo root not in the rsync exclude list lands in `~`. When adding a repo-only file (docs, tooling), add it to the exclude lists in the `diff`, `diff-long`, and `copy` targets of the `Makefile`.
- `archive/` holds retired configs kept as a fallback (the old bash setup, `archive/bash/`). It is not installed: excluded in the `Makefile`. `.dircolors` stays at the root because zsh uses it too. See `archive/README.md`.
- Config for tools that read `~/.config` lives under `.config/` (tmux, curl, wget, IdeaVim, yamllint) and is installed by the same `make copy` rsync.
- `zsh_custom/themes/powerlevel10k` and `zsh_custom/plugins/zsh-syntax-highlighting` are git-ignored clones managed by `make bootstrap-omz` / `make update-omz`, not submodules.

## agent-sudo

`agent-sudo/` (installed as root by `make install`) routes sudo from AI agents through a per-command approval prompt; `bin/sudo` is the shim that sits ahead of `/usr/bin/sudo` in PATH. It is security-sensitive: run `make test-agent-sudo` after any change, and read `agent-sudo/README.md` and `agent-sudo/TESTING.md` first.

## Claude Code config

`claude/` holds the shared `~/.claude` config; `make sync-claude` (part of `make install`) installs it. `settings.json` is jq-merged into `~/.claude/settings.json` (repo keys win, other keys are kept; the previous file is saved as `settings.json.prev`), so it is not copied by `make copy`. `settings.darwin.json` (iTerm `cc-status` hooks) is merged only on macOS when `~/.config/iterm2/cc-status` exists. Needs `jq`; skipped with a message when missing. The ccstatusline layout is `claude/ccstatusline.json`, which overwrites `~/.config/ccstatusline/settings.json` (previous saved as `settings.json.prev`); if you change the layout with `npx ccstatusline`, copy it back into the repo. Don't put machine- or project-specific settings (permissions, `autoMode`) there.

## SSH and commit signing

No private keys on disk; everything comes from the 1Password SSH agent (`zsh_custom/ssh-agent.zsh` makes it available, including inside tmux; over ssh it points at `zsh_custom/ssh-agent-proxy`, which relays to the newest live forwarded agent). Commits are SSH-signed with the 1Password "GitHub (personal)" key, so committing needs 1Password unlocked.

## Brewfile

`Brewfile` is a bootstrap list for setting up a fresh Mac, not a manifest of what's installed on the current machine. Keep it reasonably current (renamed casks, replacements for deprecated/disabled ones) so a new build is low effort.

- `brew bundle check` failures are expected and are not a problem to fix. Some apps (e.g. Firefox) are installed manually before Homebrew exists, and some entries are installed only on machines that need them.
- Don't add or remove entries just to match the current machine's `brew list`.
- Do remove entries Homebrew no longer has, since they break `brew bundle install`.
- Day-to-day maintenance is the `brewski` alias (update, upgrade, `brew cu`, cleanup).

## Other

- `.osx` is kept for reference and isn't run as a whole; apply individual settings as needed.
- Vim plugins are managed with vim-plug (`.vim/plugins.vim`); `make install` runs `:PlugUpdate`.
- Changes go through feature branches and PRs on `neybar/dotfiles`. Agents may commit, push feature branches and open PRs without asking (after the secrets check below); never commit to, push or merge `master`.

## Non-interactive shell

Agent shells have no TTY: a command that prompts hangs. `cp`/`mv`/`rm` may be aliased to `-i` on some machines. Use `cp -f`, `mv -f`, `rm -f`; use `rm -rf` only on a path the user named in this turn. Other prompters: `ssh`/`scp -o BatchMode=yes`, `apt-get -y`, `HOMEBREW_NO_AUTO_UPDATE=1 brew ...`.

## Beads in this repo

This section beats the generated Codex block below, the Cursor rule `.cursor/rules/beads.mdc`, and the `bd prime` text injected at session start. In particular, ignore their "local Dolt DB" / `refs/dolt/data` / `bd dolt push` text: the issue database is on a shared server, not synced through git.

- **Shared server** `dolt.thelances.net:3307`, database `dotfiles`, user `beads`, TLS. `.beads/metadata.json` records all of it (server mode, host, port, TLS, user, database), so `bd` reaches the server from a hook or GUI-launched tool with no shell env. `zsh_custom/beads.zsh` exports the same values for interactive shells plus a default `BEADS_ACTOR`. `bd` warns that `dolt_server_port` in `metadata.json` is deprecated; it still works.
- **Password** comes from `~/.config/beads/credentials` (per user, mode 600), never the repo: not in a file here, an env var in a committed file, or a logged command line.
- **Identity**: `BEADS_ACTOR=<tool>@<host>` (e.g. `claude@orcrist`) or `--actor <tool>@<host>`. `beads.zsh` defaults it to `james@<host>`; set your own when you are not James.
- **Server unreachable**: never `bd init`, start, or create a local or embedded database (it splits the history). Do the work and note in your report what to file, claim or close.
- **Never commit `.beads/issues.jsonl`** or any JSONL export, and never run `bd dolt push`/`pull` (there are no Dolt remotes).
- **Git follows "Other" above** (agents may commit, push feature branches and open PRs; never `master`), whatever a Beads profile or session-close checklist says about needing authorization. This is about git only: still never `bd dolt push`/`pull`.
- Claude Code loads Beads context from the SessionStart hook in `.claude/settings.json`, Codex from `.codex/hooks.json`, Cursor from `.cursor/hooks.json`; rerun `bd prime` only if the context is stale.
- `bd setup <tool>` rewrites these files: never rerun `bd setup claude` (it re-adds a Beads block to `CLAUDE.md`); `--check` is safe (its "no beads section" warning is expected); `--stealth` adds a second hook; `--remove` deletes the hook. Never edit between the `BEGIN/END` markers of a generated block. `bd setup cursor` also deletes anything after its `END` marker, so the Cursor-side override lives in its own file, `.cursor/rules/repo-beads-override.mdc`; keep it there.
- Persistent project knowledge goes in `bd remember`, not ad hoc memory files. `/endsession` and `/refine-bd` (`claude/skills/`) follow these rules; where `/endsession` mentions `bd dolt push`, this section wins.

<!-- BEGIN BEADS CODEX SETUP: generated by bd setup codex -->
## Beads Issue Tracker

Use Beads (`bd`) for durable task tracking in repositories that include it. Use the `beads` skill at `.agents/skills/beads/SKILL.md` (project install) or `~/.agents/skills/beads/SKILL.md` (global install) for Beads workflow guidance, then use the `bd` CLI for issue operations.

### Quick Reference

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
bd prime                # Refresh Beads context
```

### Rules

- Use `bd` for all task tracking; do not create markdown TODO lists.
- Run `bd prime` when Beads context is missing or stale. Codex 0.129.0+ can load Beads context automatically through native hooks; use `/hooks` to inspect or toggle them.
- Keep persistent project memory in Beads via `bd remember`; do not create ad hoc memory files.

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.
<!-- END BEADS CODEX SETUP -->

The generated block above is wrong for this repo (it describes a local, git-synced DB). The "Beads in this repo" section above wins: shared server, no `bd dolt push`/`pull`, no `bd init`; git follows "Other".
