#!/bin/sh
# Exercises the terminal-based prompts with real ttys, no sudo, no password:
#   - tmux popup when the agent runs inside tmux (approve / deny / timeout)
#   - tmux popup on your attached client when the agent is NOT inside tmux
#   - "agent-sudo --approve" from another terminal when there's no tmux
# Uses a private tmux server and the repo copy of askpass with a test entry
# point.  Usage: sh agent-sudo/dev/tmux-test.sh

set -u
src=$(cd "$(dirname "$0")/.." && pwd)/askpass
T=$(mktemp -d)
H=$T/harness
# Private tmux server on the default socket name, so askpass's plain `tmux`
# commands find it when the agent isn't inside tmux.
unset TMUX TMUX_PANE
TMUX_TMPDIR=$T
export TMUX_TMPDIR
tm() { tmux "$@"; }
cleanup() { exec 7>&- 2>/dev/null; tm kill-server 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

command -v tmux >/dev/null 2>&1 || { echo "tmux not installed"; exit 1; }
if ls -d /tmp/agent-sudo.* >/dev/null 2>&1; then
    echo "remove leftover /tmp/agent-sudo.* dirs first"; exit 1
fi

# Harness: "--harness MSG" runs only the prompt step; TEST_TTYS stands in for
# your other terminals in the --approve case.
sed -e "s|^SELF=.*|SELF=$H|" \
    -e 's|^    --check) shift; check_mode "$@" ;;|    --harness) TIMEOUT=${TO:-120}; get_password "$2"; echo "rc=$?" ;;|' \
    -e 's|^    ttys=$(other_ttys)$|    ttys=${TEST_TTYS-$(other_ttys)}|' \
    "$src" >"$H"
chmod +x "$H"
grep -q 'TEST_TTYS' "$H" || { echo "harness patch failed"; exit 1; }

# attach CMD: run CMD on a pseudo-terminal whose input is fd 7
attach() {
    rm -f "$T/in"; mkfifo "$T/in"
    if [ "$(uname -s)" = Darwin ]; then
        script -q /dev/null sh -c "$1" <"$T/in" >"$T/client.out" 2>&1 &
    else
        script -qfc "$1" /dev/null <"$T/in" >"$T/client.out" 2>&1 &
    fi
    exec 7>"$T/in"
}

wait_started() {
    i=0
    while ! ls /tmp/agent-sudo.*/"$1" >/dev/null 2>&1 && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
    sleep 0.3
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

tm new-session -d -s t -x 160 -y 45 sh
attach "tmux attach -t t"
sleep 1

# --- agent inside tmux: popup over its pane ---
inside() { # NAME TIMEOUT KEYS EXPECT
    rm -f "$T/result"; start=$(date +%s)
    tm send-keys -t t "AGENT_SUDO_PROMPT=tmux TO=$2 sh $H --harness 'Command: test $1' >$T/result 2>&1; echo done >>$T/result" Enter
    wait_started started
    [ -n "$3" ] && printf "$3" >&7
    wait_done
    report "$1" "$start" "$4"
}
inside approve 120 'hunter2\r' 'hunter2 rc=0 done'
inside deny 120 '\r' 'rc=1 done'
inside timeout 3 '' 'rc=1 done'

# --- agent outside tmux: popup on the attached client ---
rm -f "$T/result"; start=$(date +%s)
(AGENT_SUDO_PROMPT=tmux sh "$H" --harness 'Command: test outside' >"$T/result" 2>&1; echo done >>"$T/result") &
wait_started started
printf 'hunter3\r' >&7
wait_done
report outside-tmux "$start" 'hunter3 rc=0 done'

exec 7>&-
tm kill-server
sleep 0.3

# --- no tmux: agent-sudo --approve from another terminal ---
: >"$T/fake-tty"
rm -f "$T/result"; start=$(date +%s)
(AGENT_SUDO_PROMPT=terminal TEST_TTYS=$T/fake-tty sh "$H" --harness 'Command: test approve' \
    >"$T/result" 2>&1; echo done >>"$T/result") &
wait_started pending
attach "sh $H --approve"
sleep 0.5
printf 'hunter4\r' >&7
wait_done
report terminal-approve "$start" 'hunter4 rc=0 done'
grep -q 'agent-sudo --approve' "$T/fake-tty" && echo "ok   notice written to other terminal" ||
    { echo "FAIL notice not written"; fail=1; }
exec 7>&-

# --- no tmux, no other terminal: refuse right away ---
rm -f "$T/result"; start=$(date +%s)
TMUX_TMPDIR=$T/none AGENT_SUDO_PROMPT="tmux terminal" TEST_TTYS= sh "$H" --harness x >"$T/result" 2>&1
echo done >>"$T/result"
report no-way-to-ask "$start" 'rc=3 done'

sleep 0.5
left=$(ls -d /tmp/agent-sudo.* 2>/dev/null | wc -l | tr -d ' ')
echo "leftover /tmp/agent-sudo.* dirs: $left (expect 0)"
[ "$left" -eq 0 ] || fail=1
exit $fail
