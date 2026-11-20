#
# Makefile to copy dotfiles into place
#
.PHONY: fetch copy diff diff-long install update clean unlink bootstrap-omz update-omz \
	sync-agent-sudo install-agent-sudo test-agent-sudo sync-claude sync-iterm sync-fonts sync-terminal

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
	@if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then \
	    git pull; \
	else \
	    echo "fetch: $$(git rev-parse --abbrev-ref HEAD) has no upstream (not pushed yet), skipping git pull"; \
	fi

diff:
	@echo "Files that would be changed:"
	@rsync --exclude ".git/" \
		  --exclude ".claude" \
		  --exclude "/claude" \
		  --exclude ".DS_Store" \
		  --exclude ".gitignore" \
		  --exclude ".gitconfig" \
		  --exclude ".zshrc.local" \
		  --exclude "Brewfile" \
		  --exclude ".osx" \
		  --exclude "Makefile" \
		  --exclude "README.md" \
		  --exclude "CLAUDE.md" \
		  --exclude "AGENTS.md" \
		  --exclude ".agents" \
		  --exclude ".codex" \
		  --exclude ".cursor" \
		  --exclude ".beads" \
		  --exclude ".beads.gate.lock" \
		  --exclude "LICENSE-MIT.txt" \
		  --exclude "oh-my-zsh" \
		  --exclude "zsh_custom" \
		  --exclude "init" \
		  --exclude "agent-sudo" \
		  --exclude "/archive" \
		  --exclude ".zshrc" \
		  -avh --dry-run --no-perms . ~ | grep -E "^[<>cf\.]" || echo "No changes needed"

diff-long:
	@echo "Detailed diffs for changed dotfiles:"
	@bash -c 'for file in {,.}*; do \
	  case "$$file" in \
	    .|..|.git|.claude|claude|.DS_Store|.gitignore|.gitconfig|.zshrc.local|Brewfile|.osx|Makefile|README.md|CLAUDE.md|AGENTS.md|.agents|.codex|.cursor|.beads|.beads.gate.lock|LICENSE*|oh-my-zsh|zsh_custom|init|agent-sudo|archive|.zshrc) continue ;; \
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
		  --exclude "Brewfile" \
		  --exclude ".osx" \
		  --exclude "Makefile" \
		  --exclude "README.md" \
		  --exclude "CLAUDE.md" \
		  --exclude "AGENTS.md" \
		  --exclude ".agents" \
		  --exclude ".codex" \
		  --exclude ".cursor" \
		  --exclude ".beads" \
		  --exclude ".beads.gate.lock" \
		  --exclude "LICENSE-MIT.txt" \
		  --exclude "oh-my-zsh" \
		  --exclude "zsh_custom" \
		  --exclude "init" \
		  --exclude "agent-sudo" \
		  --exclude "/archive" \
		  --exclude ".zshrc" \
		  -avh --no-perms . ~
	@[ -f ~/.zshrc.local ] || cp $(CURDIR)/.zshrc.local ~/.zshrc.local
	@ln -sfn $(CURDIR)/.zshrc ~/.zshrc

install: copy bootstrap-omz sync-agent-sudo sync-claude sync-iterm sync-fonts sync-terminal
	# @/bin/zsh ~/.zshrc
	@if command -v vim >/dev/null 2>&1; then \
		vim +PlugUpdate +qall; \
	else \
		printf '\033[0;31mvim: not installed, so :PlugUpdate was skipped (vim and the vimpager pager are expected). Install it (macOS: brew install vim; Arch: pacman -S vim; Debian/Ubuntu: apt install vim) and run make install again.\033[0m\n'; \
	fi
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

# iTerm2 dynamic profiles (macOS only): copy init/iterm_profiles.pinfo into
# iTerm's DynamicProfiles folder. A copy, not a symlink: iTerm watches that
# folder live, so git writing the repo file could be read half-written, and
# iTerm rewriting a profile would land in the repo. The copy is written to a
# temp file beside the folder and renamed into place, so iTerm only ever sees
# a whole file; a differing previous copy is saved as iterm_profiles.pinfo.prev
# next to the folder (not in it, where iTerm would load it).
ITERM_SUPPORT_DIR ?= $(HOME)/Library/Application Support/iTerm2
sync-iterm:
	@if [ "$$(uname -s)" != Darwin ]; then exit 0; fi; \
	src=init/iterm_profiles.pinfo; \
	dir="$(ITERM_SUPPORT_DIR)/DynamicProfiles"; dst="$$dir/iterm_profiles.pinfo"; \
	if [ ! -L "$$dst" ] && cmp -s "$$src" "$$dst"; then echo "iterm: profiles up to date"; exit 0; fi; \
	mkdir -p "$$dir"; \
	if [ -f "$$dst" ] && [ ! -L "$$dst" ]; then cp -f "$$dst" "$(ITERM_SUPPORT_DIR)/iterm_profiles.pinfo.prev"; fi; \
	tmp="$(ITERM_SUPPORT_DIR)/.iterm_profiles.pinfo.tmp"; \
	cp -f "$$src" "$$tmp" && mv -f "$$tmp" "$$dst" && echo "iterm: profiles installed"

# Fonts (macOS only): copy init/*/*.ttf into ~/Library/Fonts when no font file
# of that name is there yet. Never replaces an installed font (it may be newer).
FONTS_DIR ?= $(HOME)/Library/Fonts
sync-fonts:
	@if [ "$$(uname -s)" != Darwin ]; then exit 0; fi; \
	mkdir -p "$(FONTS_DIR)"; added=0; \
	for f in init/*/*.ttf; do \
		[ -e "$(FONTS_DIR)/$${f##*/}" ] && continue; \
		cp -f "$$f" "$(FONTS_DIR)/" && added=$$((added + 1)); \
	done; \
	echo "fonts: $$added added"

# Terminal.app profiles (macOS only): import init/*.terminal when Terminal has
# no profile of that name yet. `open` is Terminal's own import (safe while it is
# running, e.g. during make install on a fresh Mac); it opens one window each.
sync-terminal:
	@if [ "$$(uname -s)" != Darwin ]; then exit 0; fi; \
	prefs=$$(defaults export com.apple.Terminal - 2>/dev/null); added=; \
	for f in init/*.terminal; do \
		name=$$(plutil -extract name raw -o - "$$f") || continue; \
		printf '%s' "$$prefs" | plutil -extract "Window Settings.$$name" xml1 -o /dev/null - 2>/dev/null && continue; \
		open "$$f" && added="$$added $$name"; \
	done; \
	echo "terminal: profiles imported:$${added:- none}"

# Claude Code config (claude/ -> ~/.claude). Needs jq; skipped with a message
# when it's missing. settings.json is merged, not replaced: keys in
# claude/settings.json win, anything else Claude or you put there is kept. The
# previous file is saved as settings.json.prev first, to see or undo the merge.
# claude/settings.darwin.json (iTerm cc-status hooks) is merged on macOS only,
# and only when ~/.config/iterm2/cc-status exists.
# The ccstatusline layout comes from claude/ccstatusline.json and overwrites
# ~/.config/ccstatusline/settings.json (previous saved as settings.json.prev).
# If you change the layout with `npx ccstatusline`, copy it back into the repo.
CLAUDE_DIR ?= $(HOME)/.claude
CCSTATUSLINE_DIR ?= $(HOME)/.config/ccstatusline
sync-claude:
	@if ! command -v jq >/dev/null 2>&1; then \
		echo "\033[0;31mclaude: skipped, jq not installed (brew install jq / apt install jq), then make sync-claude\033[0m"; \
		exit 0; \
	fi; \
	mkdir -p "$(CLAUDE_DIR)/skills"; \
	rsync -a claude/skills/ "$(CLAUDE_DIR)/skills/"; \
	cp claude/statusline.sh "$(CLAUDE_DIR)/statusline.sh"; \
	mkdir -p "$(CCSTATUSLINE_DIR)"; \
	[ ! -f "$(CCSTATUSLINE_DIR)/settings.json" ] || cp "$(CCSTATUSLINE_DIR)/settings.json" "$(CCSTATUSLINE_DIR)/settings.json.prev"; \
	cp claude/ccstatusline.json "$(CCSTATUSLINE_DIR)/settings.json"; \
	files="claude/settings.json"; \
	if [ "$$(uname -s)" = Darwin ] && [ -x "$(HOME)/.config/iterm2/cc-status" ]; then \
		files="$$files claude/settings.darwin.json"; \
	fi; \
	[ -f "$(CLAUDE_DIR)/settings.json" ] || echo '{}' > "$(CLAUDE_DIR)/settings.json"; \
	cp "$(CLAUDE_DIR)/settings.json" "$(CLAUDE_DIR)/settings.json.prev"; \
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
