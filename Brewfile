# Install command-line tools using Homebrew
# Usage:
# brew update
# brew upgrade
# brew tap Homebrew/bundle
# brew bundle

# Extra Repos
tap  'caskroom/cask'
tap  'caskroom/versions'
tap  'buo/cask-upgrade'
tap  'wata727/tflint'

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
brew 'vim', args: ['override-system-vi']

# Install other useful binaries
brew 'ack'
brew 'ansible'
#brew 'caskroot/cask/java'
brew 'ctags'
brew 'cvs'
brew 'dark-mode' #toggle OSX menu bar dark/light mode with dark-mode command
brew 'diff-so-fancy' # nicer diffs
brew 'exiftool'
brew 'ffmpeg'
brew 'fzf'
brew 'git'
brew 'imagemagick', args: ['with-webp']
brew 'jhead'
brew 'jpegoptim'
brew 'lynx'
brew 'macvim'
brew 'nmap'
brew 'node' # This installs `npm` too using the recommended installation method
brew 'optipng'
brew 'p7zip'
brew 'perl-build'
brew 'pigz' # multi-processor gzip
brew 'plenv'
brew 'readline'
brew 'rename'
brew 'shellcheck'
brew 'sqlmap' # pen test tool for SQL vulnerabilies
brew 'ssh-copy-id'
brew 'tag'
brew 'tflint' #terraform linter
brew 'the_silver_searcher'
brew 'thefuck'
brew 'tmux'
brew 'tree'
brew 'webkit2png'
brew 'youtube-dl'

# Casks
cask 'adium'
cask 'bettertouchtools'
cask 'cheatsheet'
cask 'dropbox'
#cask 'firefox'
cask 'google-chrome'
cask 'imagealpha'
cask 'imageoptim'
cask 'istat-menus'
#cask 'keepassx0' #keepassx 0.4.3 eventually keepassx2.0 will be ready and I can remove the "0"
cask 'limechat'
cask 'macdown'
cask 'qlcolorcode'    # Quicklook plugin for code colorizing
cask 'qlimagesize'    # Quicklook plugin for image sizes
cask 'qlmarkdown'     # Quicklook plugin for mark down
cask 'quicklook-json' # Quicklook plugin for JSON formatting
cask 'quicksilver'
cask 'spotify'
cask 'steam'
cask 'scroll-reverser' #allows mouse and trackpad to have separate scroll directions
cask 'tagger' # MP3 ID3 Tag editor
cask 'torbrowser'
cask 'transmission'
cask 'virtualbox'
cask 'viscosity' # https://sparklabs.com/viscosity VPN client
cask 'vlc'
cask 'xquartz'
cask 'ynab'
