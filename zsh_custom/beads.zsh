# Beads (bd) client settings for the shared Dolt server (orcrist, dolt.thelances.net).
# Sourced by oh-my-zsh from ZSH_CUSTOM, so interactive shells only. No secrets in this file:
# bd reads the password itself from ~/.config/beads/credentials (chmod 600, INI section
# [dolt.thelances.net:3307], key "password"), so hooks and scripts work without this file.

command -v bd >/dev/null 2>&1 || [[ -x /opt/homebrew/bin/bd ]] || return 0

export BEADS_DOLT_SERVER_MODE=1
export BEADS_DOLT_SERVER_HOST=dolt.thelances.net
export BEADS_DOLT_SERVER_PORT=3307
export BEADS_DOLT_SERVER_USER=beads
export BEADS_DOLT_SERVER_TLS=1
export BEADS_DOLT_AUTO_START=0
# <person>@<short host>; tools set their own (claude@host, cursor@host) via --actor or BEADS_ACTOR.
export BEADS_ACTOR="${BEADS_ACTOR:-james@${HOST%%.*}}"
