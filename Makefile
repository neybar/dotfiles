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
		  --exclude "oh-my-zsh" \
		  --exclude "zsh-custom" \
		  --exclude "init" \
		  --exclude ".zshrc" \
		  -avh --no-perms . ~
	@ln -sfn $(CURDIR)/.zshrc ~/.zshrc

install: copy
	# @/bin/zsh ~/.zshrc
	@vim +PlugUpdate +qall
	@echo "\033[0;33mConfiguring git user info...\033[0m"
	@read -p "Git user name: " GIT_NAME && \
	read -p "Git user email: " GIT_EMAIL && \
	git config --global user.name "$$GIT_NAME" && \
	git config --global user.email "$$GIT_EMAIL" && \
	echo "\033[0;32mGit configured: $$GIT_NAME <$$GIT_EMAIL>\033[0m"
	@echo "\033[0;31mCall 'source ~/.zshrc' to get new changes\033[0m"


# remove any directories since rsync isn't quite smart enough.
unlink:
	@rm -rf ~/.vim
	@rm -rf ~/.vagrant.d

clean: unlink update

# vim:ft=make
