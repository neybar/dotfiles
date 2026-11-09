#
# Makefile to copy dotfiles into place
#
.PHONY: fetch copy diff diff-long install update clean unlink bootstrap-omz update-omz \
	sync-agent-sudo install-agent-sudo test-agent-sudo sync-claude

update: fetch install update-omz

# Clone oh-my-zsh custom plugins/themes if missing, and re-clone any leftover
# submodule checkouts (identified by .git being a file rather than a directory).
bootstrap-omz:
	@for dir in zsh_custom/themes/powerlevel10k zsh_custom/plugins/zsh-syntax-highlighting; do \
		[ -f "$$dir/.git" ] && echo "$$dir: leftover submodule checkout, re-cloning..." && rm -rf "$$dir" || true; \
	done
	@[ -d zsh_custom/themes/powerlevel10k ] || \
		git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
			zsh_custom/themes/powerlevel10k
	@[ -d zsh_custom/plugins/zsh-syntax-highlighting ] || \
		git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
			zsh_custom/plugins/zsh-syntax-highlighting

# Pull latest commits in the oh-my-zsh-managed clones.
update-omz:
	@git -C zsh_custom/themes/powerlevel10k pull --ff-only
	@git -C zsh_custom/plugins/zsh-syntax-highlighting pull --ff-only

fetch:
	@git pull

diff:
	@echo "Files that would be changed:"
	@rsync --exclude ".git/" \
		  --exclude ".claude" \
		  --exclude "/claude" \
		  --exclude ".DS_Store" \
		  --exclude ".gitignore" \
		  --exclude ".gitconfig" \
		  --exclude ".zshrc.local" \
		  --exclude "Makefile" \
		  --exclude "README.md" \
		  --exclude "CLAUDE.md" \
		  --exclude "LICENSE-MIT.txt" \
		  --exclude "oh-my-zsh" \
		  --exclude "zsh_custom" \
		  --exclude "init" \
		  --exclude "agent-sudo" \
		  --exclude ".zshrc" \
		  -avh --dry-run --no-perms . ~ | grep -E "^[<>cf\.]" || echo "No changes needed"

diff-long:
	@echo "Detailed diffs for changed dotfiles:"
	@bash -c 'for file in {,.}*; do \
	  case "$$file" in \
	    .|..|.git|.claude|claude|.DS_Store|.gitignore|.gitconfig|.zshrc.local|Makefile|README.md|CLAUDE.md|LICENSE*|oh-my-zsh|zsh_custom|init|agent-sudo|.zshrc) continue ;; \
	  esac; \
	  [ -f "$$file" ] || continue; \
	  [ -f "$$HOME/$$file" ] || continue; \
	  cmp -s "$$file" "$$HOME/$$file" && continue; \
	  echo; \
	  echo "=== $$file ==="; \
	  diff -u "$$HOME/$$file" "$$file" || true; \
	done'

copy:
	@rsync --exclude ".git/" \
		  --exclude ".claude" \
		  --exclude "/claude" \
		  --exclude ".DS_Store" \
		  --exclude ".gitignore" \
		  --exclude ".gitconfig" \
		  --exclude ".zshrc.local" \
		  --exclude "Makefile" \
		  --exclude "README.md" \
		  --exclude "CLAUDE.md" \
		  --exclude "LICENSE-MIT.txt" \
		  --exclude "oh-my-zsh" \
		  --exclude "zsh_custom" \
		  --exclude "init" \
		  --exclude "agent-sudo" \
		  --exclude ".zshrc" \
		  -avh --no-perms . ~
	@[ -f ~/.zshrc.local ] || cp $(CURDIR)/.zshrc.local ~/.zshrc.local
	@ln -sfn $(CURDIR)/.zshrc ~/.zshrc

install: copy bootstrap-omz sync-agent-sudo sync-claude
	# @/bin/zsh ~/.zshrc
	@vim +PlugUpdate +qall
	@# Prompt only for git user info that isn't set yet.
	@if ! git config --global user.name >/dev/null; then \
		read -p "Git user name: " GIT_NAME && git config --global user.name "$$GIT_NAME"; \
	fi
	@if ! git config --global user.email >/dev/null; then \
		read -p "Git user email: " GIT_EMAIL && git config --global user.email "$$GIT_EMAIL"; \
	fi
	@git config --global --get-all include.path | grep -qxF "$(CURDIR)/.gitconfig" || \
		git config --global --add include.path "$(CURDIR)/.gitconfig"
	@echo "\033[0;32mGit user: $$(git config --global user.name) <$$(git config --global user.email)>\033[0m"
	@echo "\033[0;31mCall 'source ~/.zshrc' to get new changes\033[0m"


# Claude Code config (claude/ -> ~/.claude). Needs jq; skipped with a message
# when it's missing. settings.json is merged, not replaced: keys in
# claude/settings.json win, anything else Claude or you put there is kept.
# claude/settings.darwin.json (iTerm cc-status hooks) is merged on macOS only,
# and only when ~/.config/iterm2/cc-status exists.
CLAUDE_DIR ?= $(HOME)/.claude
sync-claude:
	@if ! command -v jq >/dev/null 2>&1; then \
		echo "\033[0;31mclaude: skipped, jq not installed (brew install jq / apt install jq), then make sync-claude\033[0m"; \
		exit 0; \
	fi; \
	mkdir -p "$(CLAUDE_DIR)/skills"; \
	rsync -a claude/skills/ "$(CLAUDE_DIR)/skills/"; \
	cp claude/statusline.sh "$(CLAUDE_DIR)/statusline.sh"; \
	files="claude/settings.json"; \
	if [ "$$(uname -s)" = Darwin ] && [ -x "$(HOME)/.config/iterm2/cc-status" ]; then \
		files="$$files claude/settings.darwin.json"; \
	fi; \
	[ -f "$(CLAUDE_DIR)/settings.json" ] || echo '{}' > "$(CLAUDE_DIR)/settings.json"; \
	if jq -s 'reduce .[] as $$f ({}; . * $$f)' "$(CLAUDE_DIR)/settings.json" $$files > "$(CLAUDE_DIR)/settings.json.new"; then \
		mv "$(CLAUDE_DIR)/settings.json.new" "$(CLAUDE_DIR)/settings.json"; \
		echo "claude: settings and skills synced"; \
	else \
		rm -f "$(CLAUDE_DIR)/settings.json.new"; \
		echo "\033[0;31mclaude: merge failed (is $(CLAUDE_DIR)/settings.json valid JSON?); left unchanged\033[0m"; \
	fi

# agent-sudo: sudo approval prompt for agents/IDEs (see agent-sudo/README.md).
# make install / make update install it when missing or changed, asking for
# your sudo password only then. A failure doesn't stop the rest of the install.
# Skip with SKIP_AGENT_SUDO=1 (e.g. machines where you have no sudo).
sync-agent-sudo:
	@if [ -n "$(SKIP_AGENT_SUDO)" ]; then \
		echo "agent-sudo: skipped (SKIP_AGENT_SUDO set)"; \
	elif ! command -v sudo >/dev/null 2>&1; then \
		echo "agent-sudo: skipped (sudo not installed)"; \
	elif out=$$(sh agent-sudo/install.sh --check); then \
		echo "agent-sudo: up to date"; \
	else \
		printf '%s\n' "$$out"; \
		$(MAKE) --no-print-directory install-agent-sudo || \
			echo "\033[0;31magent-sudo: install failed; retry with make install-agent-sudo\033[0m"; \
	fi

# Install or reinstall (runs the tests first). Shows the changes and asks
# before running anything as root.
install-agent-sudo: test-agent-sudo
	@if sh agent-sudo/install.sh --check >/dev/null; then \
		echo "agent-sudo: up to date; nothing to install"; \
	elif ! sh agent-sudo/install.sh --review; then \
		exit 1; \
	elif [ "$$(uname -s)" = Linux ] && [ -n "$$DISPLAY$$WAYLAND_DISPLAY" ]; then \
		sudo sh agent-sudo/install.sh --gui "$$XDG_CURRENT_DESKTOP"; \
	else \
		sudo sh agent-sudo/install.sh; \
	fi

test-agent-sudo:
	@sh agent-sudo/test.sh

# remove any directories since rsync isn't quite smart enough.
unlink:
	@rm -rf ~/.vim
	@rm -rf ~/.vagrant.d

clean: unlink update

# vim:ft=make
