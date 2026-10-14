#!/bin/sh
# Drives the askpass tmux popup through a real attached tmux client (on a
# private tmux server) and checks approve / deny / timeout. Runs the repo copy
# of askpass with a test entry point; no sudo, no password.
# Usage: sh agent-sudo/dev/tmux-test.sh

set -u
src=$(cd "$(dirname "$0")/.." && pwd)/askpass
T=$(mktemp -d)
H=$T/harness
sock=agent-sudo-test-$$
tm() { tmux -L "$sock" "$@"; }
cleanup() { exec 7>&- 2>/dev/null; tm kill-server 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

command -v tmux >/dev/null 2>&1 || { echo "tmux not installed"; exit 1; }
if ls -d /tmp/agent-sudo.* >/dev/null 2>&1; then
    echo "remove leftover /tmp/agent-sudo.* dirs first"; exit 1
fi

# Harness: same script, but "--harness MSG" runs only the prompt step.
sed -e "s|^SELF=.*|SELF=$H|" \
    -e 's|^    --check) shift; check_mode "$@" ;;|    --harness) TIMEOUT=${TO:-120}; get_password "$2"; echo "rc=$?" ;;|' \
    "$src" >"$H"
chmod +x "$H"

tm new-session -d -s t -x 160 -y 45 sh
mkfifo "$T/in"
if [ "$(uname -s)" = Darwin ]; then
    script -q /dev/null tmux -L "$sock" attach -t t <"$T/in" >"$T/client.out" 2>&1 &
else
    script -qfc "tmux -L $sock attach -t t" /dev/null <"$T/in" >"$T/client.out" 2>&1 &
fi
exec 7>"$T/in" # keeps the client's input open; keystrokes go here
sleep 1

fail=0
# run NAME TIMEOUT KEYS EXPECT
run() {
    rm -f "$T/result"
    start=$(date +%s)
    tm send-keys -t t "AGENT_SUDO_PROMPT=tmux TO=$2 sh $H --harness 'Command: test $1' >$T/result 2>&1; echo done >>$T/result" Enter
    i=0
    while ! ls /tmp/agent-sudo.*/started >/dev/null 2>&1 && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
    sleep 0.3
    [ -n "$3" ] && printf "$3" >&7
    i=0
    while ! grep -q done "$T/result" 2>/dev/null && [ $i -lt 200 ]; do sleep 0.1; i=$((i + 1)); done
    secs=$(($(date +%s) - start))
    got=$(tr '\n' ' ' <"$T/result" 2>/dev/null)
    case $got in
        "$4"*) status=ok ;;
        *) status=FAIL; fail=1 ;;
    esac
    printf '%-4s %-8s %3ss  %s\n' "$status" "$1" "$secs" "$got"
}

run approve 120 'hunter2\r' 'hunter2 rc=0 done'
run deny 120 '\r' 'rc=1 done'
run timeout 3 '' 'rc=1 done'
sleep 0.5

left=$(ls -d /tmp/agent-sudo.* 2>/dev/null | wc -l | tr -d ' ')
echo "leftover /tmp/agent-sudo.* dirs: $left (expect 0)"
[ "$left" -eq 0 ] || fail=1
echo "approve should take ~0-1s (not the timeout); timeout case ~3s"
exit $fail
