# dotfiles

Personal dotfiles for both macOS and Linux (both are first-class targets; changes must work on each), forked long ago from mathiasbynens/dotfiles. Shell is zsh + oh-my-zsh + powerlevel10k. See `README.md` for user-facing setup docs.

## How files get into `~`

- Dotfiles are **copied**, not symlinked: `make copy` rsyncs the repo root into `~`. Editing `~/.aliases` does not change the repo, and editing the repo does not change `~` until `make copy` runs. Use `make diff` / `make diff-long` to preview.
- Exceptions:
  - `.zshrc` is symlinked to `~/.zshrc`.
  - `.gitconfig` is not copied; `make install` adds it to the global git config via `include.path`. Machine-specific git settings (name, email) live in `~/.gitconfig`.
  - `.zshrc.local` is a template, copied only if `~/.zshrc.local` doesn't exist. Machine-specific PATH/plugins go there.
  - `ZSH_CUSTOM` points straight at `zsh_custom/` in the repo, so changes there are live in new shells. `zsh_custom/*.local.zsh` is git-ignored for machine-specific config.
- Anything at the repo root not in the rsync exclude list lands in `~`. When adding a repo-only file (docs, tooling), add it to the exclude lists in the `diff`, `diff-long`, and `copy` targets of the `Makefile`.
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
- Changes go through feature branches and PRs on `neybar/dotfiles`.


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:1105d646 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->
