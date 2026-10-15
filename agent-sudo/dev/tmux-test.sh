#!/bin/sh
# Exercises the terminal-based prompts with real ttys, no sudo, no password:
#   - tmux popup when the agent runs inside tmux (approve / deny / timeout)
#   - no popup anywhere else: agent outside tmux, or in a session with no
#     client attached, while another session is attached -> refused at once
# Uses a private tmux server and the repo copy of askpass with a test entry
# point.  Usage: sh agent-sudo/dev/tmux-test.sh

set -u
src=$(cd "$(dirname "$0")/.." && pwd)/askpass
T=$(mktemp -d)
H=$T/harness
# Private tmux server, so nothing reaches your real tmux clients.
unset TMUX TMUX_PANE
TMUX_TMPDIR=$T
export TMUX_TMPDIR
cleanup() { exec 7>&- 2>/dev/null; tmux kill-server 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

command -v tmux >/dev/null 2>&1 || { echo "tmux not installed"; exit 1; }
# Request dirs come from mktemp in new_request; count them rather than
# require none, so a real request running meanwhile doesn't fail the test.
dirs_before=$(ls -d /tmp/agent-sudo.* 2>/dev/null | wc -l | tr -d ' ')

# Harness: "--harness MSG" runs only the prompt step. Every popup that opens
# appends a line to $T/popups.
sed -e "s|^SELF=.*|SELF=$H|" \
    -e 's|^    --check) shift; check_mode "$@" ;;|    --harness) TIMEOUT=${TO:-120}; get_password "$2"; echo "rc=$?" ;;|' \
    -e "s|^    : >\"\$dir/started\"\$|    : >\"\$dir/started\"; echo popup >>$T/popups|" \
    "$src" >"$H"
chmod +x "$H"
grep -q -- '--harness' "$H" && grep -q "popup >>$T/popups" "$H" || { echo "harness patch failed"; exit 1; }
: >"$T/popups"
popups() { wc -l <"$T/popups" | tr -d ' '; }

# attach CMD: run CMD on a pseudo-terminal whose input is fd 7
attach() {
    rm -f "$T/in"; mkfifo "$T/in"
    if [ "$(uname -s)" = Darwin ]; then
        # BSD script fails on a FIFO stdin (EOPNOTSUPP); a pipe is fine.
        cat "$T/in" | script -q /dev/null sh -c "$1" >"$T/client.out" 2>&1 &
    else
        script -qfc "$1" /dev/null <"$T/in" >"$T/client.out" 2>&1 &
    fi
    exec 7>"$T/in"
}

# What the client terminal showed since byte $off.
screen() { tail -c +$((off + 1)) "$T/client.out" 2>/dev/null; }
# Wait for popup number $1 to open and show its password line.
wait_popup() {
    i=0
    while [ "$(popups)" -lt "$1" ] && [ $i -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
    i=0
    while ! screen | grep -q 'Enter to approve' && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
}
wait_done() {
    i=0
    while ! grep -q done "$T/result" 2>/dev/null && [ $i -lt 200 ]; do sleep 0.1; i=$((i + 1)); done
}

fail=0
report() { # NAME START EXPECT
    secs=$(($(date +%s) - $2))
    got=$(tr '\n' ' ' <"$T/result" 2>/dev/null)
    case $got in "$3"*) status=ok ;; *) status=FAIL; fail=1 ;; esac
    printf '%-4s %-16s %3ss  %s\n' "$status" "$1" "$secs" "$got"
}

tmux new-session -d -s t -x 160 -y 45 sh
attach "tmux attach -t t"
i=0
while [ -z "$(tmux list-clients -t t 2>/dev/null)" ] && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done

# --- agent inside tmux: popup over its pane ---
n=0
inside() { # NAME TIMEOUT KEYS EXPECT
    rm -f "$T/result"; off=$(wc -c <"$T/client.out"); start=$(date +%s); n=$((n + 1))
    # The message is built when it runs, so the typed command line (which the
    # pane echoes) doesn't contain the text the popup must show.
    tmux send-keys -t t "AGENT_SUDO_PROMPT=tmux TO=$2 sh $H --harness \"\$(printf 'shown-%s-%s' $1 popup)\" >$T/result 2>&1; echo done >>$T/result" Enter
    wait_popup "$n"
    shown=no
    screen | grep -q "shown-$1-popup" && shown=yes
    [ -n "$3" ] && printf "$3" >&7
    wait_done
    report "$1" "$start" "$4"
    [ "$shown" = yes ] || { echo "FAIL $1: popup did not show the message"; fail=1; }
}
inside approve 120 'hunter2\r' 'hunter2 rc=0 done'
inside deny 120 '\r' 'rc=1 done'
inside timeout 3 '' 'rc=1 done'

# --- agent outside tmux, a client attached elsewhere: refused, no popup ---
rm -f "$T/result"; start=$(date +%s)
AGENT_SUDO_PROMPT=tmux TO=5 sh "$H" --harness 'Command: test outside' >"$T/result" 2>&1
echo done >>"$T/result"
report outside-tmux "$start" 'rc=3 done'

# --- agent in a session nobody is looking at: refused, no popup ---
tmux new-session -d -s d sh
rm -f "$T/result"; start=$(date +%s)
tmux send-keys -t d "AGENT_SUDO_PROMPT=tmux TO=5 sh $H --harness 'Command: test detached' >$T/result 2>&1; echo done >>$T/result" Enter
wait_done
report detached-session "$start" 'rc=3 done'
[ "$(popups)" -eq 3 ] || { echo "FAIL: $(popups) popups opened, expected 3 (none outside the agent's session)"; fail=1; }

exec 7>&-
tmux kill-server

sleep 0.5
left=$(($(ls -d /tmp/agent-sudo.* 2>/dev/null | wc -l | tr -d ' ') - dirs_before))
echo "new leftover /tmp/agent-sudo.* dirs: $left (expect 0)"
[ "$left" -le 0 ] || fail=1
exit $fail
