#!/bin/sh
# Checks the "started from your terminal" rule and the ~/bin/sudo shim, as the
# current process and as a detached process with no terminal anywhere in its
# ancestry (like cron or a service). Uses scratch copies of the scripts wired
# to each other; prompts are disabled (AGENT_SUDO_PROMPT=none), so nothing pops
# up and sudo never gets a password. Linux only (needs setsid).
# Run it from a terminal or an agent started from one.
# Usage: sh agent-sudo/dev/origin-test.sh

set -u
repo=$(cd "$(dirname "$0")/../.." && pwd)
command -v setsid >/dev/null 2>&1 || { echo "needs setsid (Linux)"; exit 1; }
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

sed -e "s|^RULES_FILE=.*|RULES_FILE=$repo/agent-sudo/rules|" \
    -e "s|^WRAPPER=.*|WRAPPER=$T/agent-sudo|" \
    "$repo/agent-sudo/askpass" >"$T/askpass"
sed "s|^ASKPASS=.*|ASKPASS=$T/askpass|" "$repo/agent-sudo/agent-sudo" >"$T/agent-sudo"
sed -e "s|^AGENT_SUDO=.*|AGENT_SUDO=$T/agent-sudo|" -e "s|^ASKPASS=.*|ASKPASS=$T/askpass|" \
    "$repo/bin/sudo" >"$T/sudo"
chmod +x "$T/askpass" "$T/agent-sudo" "$T/sudo"
export AGENT_SUDO_PROMPT=none

# detached CMD: run CMD in a new session whose parent exits, so it has no
# controlling terminal and no terminal-owning ancestor; prints its output.
detached() {
    rm -f "$T/out"
    (setsid sh -c "$1 >$T/out.tmp 2>&1; mv $T/out.tmp $T/out" &)
    i=0
    while [ ! -e "$T/out" ] && [ $i -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
    cat "$T/out" 2>/dev/null
}

fail=0
expect() { # NAME PATTERN OUTPUT
    case $3 in
        *$2*) printf 'ok   %s\n' "$1" ;;
        *) printf 'FAIL %s\n     got: %s\n' "$1" "$3"; fail=1 ;;
    esac
}

expect "--from-terminal, here" "yes" \
    "$(sh "$T/askpass" --from-terminal && echo yes || echo no)"
expect "--from-terminal, detached" "no" \
    "$(detached "sh $T/askpass --from-terminal && echo yes || echo no")"

# askpass via sudo: allowed origin gets to the prompt stage ("no way to ask"
# because prompts are disabled); detached is refused before that.
expect "askpass via sudo, here" "no way to ask" \
    "$(SUDO_ASKPASS=$T/askpass sudo -k -A true 2>&1)"
expect "askpass via sudo, detached" "not started from your terminal" \
    "$(detached "SUDO_ASKPASS=$T/askpass sudo -k -A true")"

# shim: here it routes to agent-sudo (prompt stage); detached it is plain sudo.
# (No display for the detached run, so sudo.conf's askpass doesn't step in
# and plain sudo's own "terminal required" error shows the routing.)
expect "shim, here -> agent-sudo" "no way to ask" "$("$T/sudo" true 2>&1)"
expect "shim, detached -> plain sudo" "a terminal is required" \
    "$(detached "env -u DISPLAY -u WAYLAND_DISPLAY $T/sudo true")"

# agent-sudo must use the system sudo, never a shim earlier in PATH.
mkdir "$T/bin"
cp "$T/sudo" "$T/bin/sudo"
expect "no shim loop" "no way to ask" \
    "$(PATH="$T/bin:$PATH" timeout 10 "$T/agent-sudo" true 2>&1 || echo "exit $?")"

exit $fail
