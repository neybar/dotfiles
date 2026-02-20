# Neybar's dotfiles

## Installation

### ZSH

The dotfiles use ZSH with [oh-my-zsh](https://ohmyzsh.sh/). To get started, install oh-my-zsh:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

#### Machine-specific ZSH Configuration

To keep local changes separate from the tracked dotfiles, use `~/.zshrc.local`. This file is sourced by `.zshrc` before oh-my-zsh loads, so you can:

- **Add machine-specific PATH entries**:
  ```bash
  export PATH="$HOME/.local/bin:$PATH"
  ```

- **Add local plugins without modifying the repo**:
  ```bash
  plugins+=(nvm docker kubectl)
  ```

- **Add custom ZSH functions and aliases** in `~/Projects/dotfiles/zsh_custom/` with a `.local.zsh` suffix (e.g., `functions.local.zsh`) — these are ignored by git and only loaded on your machine.

### Using Git and the bootstrap script

You can clone the repository wherever you want. (I like to keep it in `~/Projects/dotfiles`, with `~/dotfiles` as a symlink.) The Makefile will pull in the latest version and copy the files to your home folder.

```sh
git clone https://github.com/neybar/dotfiles.git && cd dotfiles && git submodule update --init --recursive && make install
```

To update, `cd` into your local `dotfiles` repository and then:

```sh
make update
```
if you are making local change and just want to copy files into place then:
```sh
make install # will copy files and run vim
make copy    # will only copy
```

### Git-free install

To install these dotfiles without Git:

```sh
cd; curl -#L https://github.com/neybar/dotfiles/tarball/master | tar -xzv --strip-components 1 --exclude={README.md,Makefile,LICENSE-MIT.txt}
```

To update later on, just run that command again. (`make` won't work for the git-free install very well)

### Specify the `$PATH`

Edit `~/.zshrc.local` to add machine-specific PATH entries. Since `.zshrc.local` is sourced before oh-my-zsh loads, you can set PATH variables that affect your shell:

```bash
export PATH="$HOME/utils:$PATH"
```

### Add custom commands without creating a new fork

Use `~/.zshrc.local` to add custom commands, aliases, and environment variables without forking the repository. See the examples above in the ZSH section.

For machine-specific custom ZSH scripts, place files in `~/Projects/dotfiles/zsh_custom/` with a `.local.zsh` suffix — these are git-ignored and won't be committed.

Git user configuration is set up during `make install` and stored in `~/.gitconfig`.

If you want to maintain your own customizations long-term, consider [forking this repository](https://github.com/neybar/dotfiles/fork).

### Sensible OS X defaults

When setting up a new Mac, you may want to set some sensible OS X defaults:

```bash
./.osx
```

*Note*: I haven't run the `.osx` script for a while.  I mostly keep it for reference so I can apply settings when needed.  Not all of the settings in this file are needed.

### Install Homebrew formulae

When setting up a new Mac, you may want to install some common [Homebrew](http://brew.sh/) formulae (after installing Homebrew, of course):

```bash
brew update
brew upgrade
brew bundle ~/Brewfile
```

After getting homebrew setup, you can maintain your brews with

```bash
brewski
```

This will run homebrews' `update`, `upgrade`, `cu`, and then `cleanup` commands

## Feedback

Suggestions/improvements
[welcome](https://github.com/neybar/dotfiles/issues)!

## Thanks to…

* Forked from (https://github.com/mathiasbynens/dotfiles)
* @ptb and [his _OS X Lion Setup_ repository](https://github.com/ptb/Mac-OS-X-Lion-Setup)
* [Ben Alman](http://benalman.com/) and his [dotfiles repository](https://github.com/cowboy/dotfiles)
* [Chris Gerke](http://www.randomsquared.com/) and his [tutorial on creating an OS X SOE master image](http://chris-gerke.blogspot.com/2012/04/mac-osx-soe-master-image-day-7.html) + [_Insta_ repository](https://github.com/cgerke/Insta)
* [Cãtãlin Mariş](https://github.com/alrra) and his [dotfiles repository](https://github.com/alrra/dotfiles)
* [Gianni Chiappetta](http://gf3.ca/) for sharing his [amazing collection of dotfiles](https://github.com/gf3/dotfiles)
* [Jan Moesen](http://jan.moesen.nu/) and his [ancient `.bash_profile`](https://gist.github.com/1156154) + [shiny _tilde_ repository](https://github.com/janmoesen/tilde)
* [Lauri ‘Lri’ Ranta](http://lri.me/) for sharing [loads of hidden preferences](http://osxnotes.net/defaults.html)
* [Matijs Brinkhuis](http://hotfusion.nl/) and his [dotfiles repository](https://github.com/matijs/dotfiles)
* [Nicolas Gallagher](http://nicolasgallagher.com/) and his [dotfiles repository](https://github.com/necolas/dotfiles)
* [Sindre Sorhus](http://sindresorhus.com/)
* [Tom Ryder](http://blog.sanctum.geek.nz/) and his [dotfiles repository](https://github.com/tejr/dotfiles)
* [Kevin Suttle](http://kevinsuttle.com/) and his [dotfiles repository](https://github.com/kevinSuttle/dotfiles) and [OSXDefaults project](https://github.com/kevinSuttle/OSXDefaults), which aims to provide better documentation for [`~/.osx`](http://mths.be/osx)
* [Haralan Dobrev](http://hkdobrev.com/)

* anyone who [contributed a patch](https://github.com/mathiasbynens/dotfiles/contributors) or [made a helpful suggestion](https://github.com/mathiasbynens/dotfiles/issues)
