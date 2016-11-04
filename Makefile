#
# Makefile to copy dotfiles into place
#
.PHONY: fetch copy install update clean unlink

fetch:
	git pull

copy:
	rsync --exclude ".git/" \
		  --exclude ".DS_STORE" \
		  --exclude "Makefile" \
		  --exclude "README.md" \
		  --exclude "LICENSE-MIT.txt" \
		  --exclude "init" \
		  -avh --no-perms . ~

install: copy
	source ~/.bash_profile
	vim +PlugUpdate +qall

update: fetch install

# remove any directories since rsync isn't quite smart enough.
unlink:
	rm -rf ~/.vim
	rm -rf ~/.vagrant.d

clean: unlink update

# vim:ft=make
