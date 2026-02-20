# zsh_custom

This directory is used as the `ZSH_CUSTOM` folder for oh-my-zsh.
Any `*.zsh` file placed here is automatically sourced by oh-my-zsh at startup.

## Local overrides

Files matching `*.local.zsh` are **git-ignored** and will not be committed
to the dotfiles repo. Use this pattern for machine-specific configuration
that doesn't belong in the shared dotfiles.

For example, if you install nvm on a particular machine:

```
# zsh_custom/nvm.local.zsh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
```

### When to use `*.local.zsh` vs `~/.zshrc.local`

| File | Loaded by | Best for |
|------|-----------|----------|
| `~/.zshrc.local` | `.zshrc` (before oh-my-zsh) | `$PATH` changes, `plugins+=()` additions |
| `zsh_custom/*.local.zsh` | oh-my-zsh (during startup) | Tool setup, env vars, aliases, functions |
