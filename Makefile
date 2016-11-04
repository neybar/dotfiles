#
# Makefile to copy dotfiles into place
#
.PHONY: fetch copy install update clean unlink

update: fetch install

fetch:
	@git pull

copy:
	@rsync --exclude ".git/" \
		  --exclude ".DS_STORE" \
		  --exclude "Makefile" \
		  --exclude "README.md" \
		  --exclude "LICENSE-MIT.txt" \
		  --exclude "init" \
		  -avh --no-perms . ~

install: copy
	@/bin/bash ~/.bash_profile
	@vim +PlugUpdate +qall
	@echo "\033[0;31mCall 'source ~/.bash_profile' to get new changes\033[0m"

# remove any directories since rsync isn't quite smart enough.
unlink:
	@rm -rf ~/.vim
	@rm -rf ~/.vagrant.d

clean: unlink update

# vim:ft=make
