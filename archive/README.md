# archive

Retired or fallback configs. Nothing here is installed: `make copy` and
`make diff` exclude `/archive`.

## bash

The old bash setup, kept as a fallback in case zsh isn't available. The files
keep their original names, so restoring one is a copy:

```bash
cp archive/bash/.bash_profile archive/bash/.bashrc ~
cp archive/bash/{.bash_prompt,.aliases,.exports,.functions,.inputrc} ~
```

`.bash_profile` sources `~/.bash_prompt`, `~/.exports`, `~/.aliases` and
`~/.functions`. `.dircolors` is not archived: zsh uses it too. There is no
iTerm shell-integration script here: iTerm injects its own current one (the
profiles in `init/iterm_profiles.pinfo` turn that on).

On Omarchy, `~/.bashrc` belongs to Omarchy (it sources its own shell setup and
asks you to add your own changes below its marker). Don't overwrite it with
these; copy only what you want from them into it.
