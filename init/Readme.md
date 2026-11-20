macOS terminal setup, installed by `make install` (each target does nothing on Linux):

- `iterm_profiles.pinfo`: iTerm2 dynamic profiles. `make sync-iterm` copies it into iTerm's DynamicProfiles folder rather than linking it, so iTerm never reads a half-written file or writes its own changes into the repo. To change a profile, edit this file and run `make sync-iterm`; changes made in iTerm's settings stay in iTerm's copy.
- `MesloLGS_NF/`, `DroidSansMonoSlashed/`: fonts. `make sync-fonts` copies each `.ttf` into `~/Library/Fonts` unless a font file of that name is already there (an installed font is never replaced, since it may be newer).
- `Presenter.terminal`, `Pro.terminal`: Terminal.app profiles. `make sync-terminal` imports each one with `open` unless Terminal already has a profile of that name; each import opens a Terminal window. `Pro` is also the name of a built-in Terminal profile, so it is skipped wherever that exists; to replace it, run `open init/Pro.terminal` yourself.
