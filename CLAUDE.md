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

## SSH and commit signing

No private keys on disk; everything comes from the 1Password SSH agent (`zsh_custom/ssh-agent.zsh` makes it available, including inside tmux). Commits are SSH-signed with the 1Password "GitHub (personal)" key, so committing needs 1Password unlocked.

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
