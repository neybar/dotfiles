# Install command-line tools using Homebrew
# Usage:
# brew update
# brew upgrade
# brew tap Homebrew/bundle
# brew bundle

# Install GNU core utilities (those that come with OS X are outdated)
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew 'coreutils'
# Install some other useful utilities like `sponge`
brew 'moreutils'
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed
brew 'findutils'
# Install GNU `sed`, overwriting the built-in `sed`
brew 'gnu-sed', args: ['default-names']
# Install Bash 4
# Note: don’t forget to add `/usr/local/bin/bash` to `/etc/shells` before running `chsh`.
brew 'bash'
brew 'bash-completion'

# Install wget with IRI support
brew 'wget', args: ['enable-iri']

# Install more recent versions of some OS X tools
brew 'homebrew/dupes/grep'
brew 'vim', args: ['override-system-vi']

# This formula didn’t work well last time I tried it:
#install homebrew/dupes/screen

# Install other useful binaries
brew 'ack'
brew 'ansible'
brew 'caskroot/cask/java'
brew 'ctags'
brew 'cvs'
brew 'exiftool'
brew 'dark-mode' #toggle OSX menu bar dark/light mode with dark-mode command
brew 'ffmpeg'
brew 'thefuck'
brew 'git'
brew 'imagemagick', args: ['with-webp']
brew 'jhead'
brew 'jpegoptim'
brew 'lynx'
brew 'nmap'
brew 'node' # This installs `npm` too using the recommended installation method
brew 'optipng'
brew 'p7zip'
brew 'perl-build'
brew 'pigz'
brew 'plenv'
brew 'readline'
brew 'rename'
brew 'sqlmap'
brew 'ssh-copy-id'
brew 'tag'
brew 'the_silver_searcher'
brew 'tmux'
brew 'tree'
brew 'webkit2png'
brew 'youtube-dl'

# Casks
brew 'caskroom/cask/brew-cask'
tap  'caskroom/cask'
tap  'caskroom/versions'

cask 'adium'
cask 'bettertouchtools'
cask 'cheatsheet'
cask 'dropbox'
cask 'firefox'
cask 'google-chrome'
cask 'imagealpha'
cask 'imageoptim'
cask 'istat-menus'
cask 'keepassx0' #keepassx 0.4.3 eventually keepassx2.0 will be ready and I can remove the "0"
cask 'limechat'
cask 'macdown'
cask 'macvim'
cask 'parallels9'
cask 'quicksilver'
cask 'spotify'
cask 'steam'
#cask 'synergy'
cask 'tagger' # MP3 ID3 Tag editor
cask 'torbrowser'
cask 'transmission'
cask 'tunnelblick'
cask 'virtualbox'
cask 'vlc'
cask 'xquartz'
cask 'ynab'
