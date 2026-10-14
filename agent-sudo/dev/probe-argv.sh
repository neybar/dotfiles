#!/bin/sh
# Shows what an askpass helper can see of the sudo process on this machine:
# whether sudo's arguments and cwd are readable, and what its parent shows.
# Supplies no password, so sudo just fails ("no password was provided").
# Needs no root and changes nothing.  Usage: sh agent-sudo/dev/probe-argv.sh

set -u
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/stub" <<EOF
#!/bin/sh
gp=\$(ps -o ppid= -p \$PPID | tr -d ' ')
{
    echo "os:                       \$(uname -sr)"
    echo "parent comm:              \$(ps -o comm= -p \$PPID)"
    echo "/proc cmdline readable:   \$([ -r /proc/\$PPID/cmdline ] && echo yes || echo no)"
    echo "ps args of sudo:          [\$(ps -ww -o args= -p \$PPID 2>&1)]"
    echo "ps args of sudo's parent: [\$(ps -ww -o args= -p \$gp 2>&1)]"
    echo "sudo cwd (readlink):      [\$(readlink /proc/\$PPID/cwd 2>/dev/null)]"
    echo "sudo cwd (lsof):          [\$(lsof -a -p \$PPID -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')]"
    echo "parent cwd (lsof):        [\$(lsof -a -p \$gp -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')]"
    echo "DISPLAY=[\${DISPLAY:-}] WAYLAND_DISPLAY=[\${WAYLAND_DISPLAY:-}]"
    echo "TMUX=[\${TMUX:-}] SSH_CONNECTION=[\${SSH_CONNECTION:-}]"
} >"$tmp/out"
exit 1
EOF
chmod +x "$tmp/stub"

SUDO_ASKPASS="$tmp/stub" sudo -k -A -- sh -c 'echo "a b"' arg2 2>/dev/null
cat "$tmp/out" 2>/dev/null || echo "askpass stub never ran (sudo didn't call it)"
echo "sudo:                     $(sudo -V 2>/dev/null | head -1)"
echo "awk:                      $(awk --version 2>&1 | head -1)"
echo "tmux:                     $(tmux -V 2>/dev/null || echo none)"
for p in zenity kdialog ssh-askpass osascript; do
    command -v "$p" >/dev/null 2>&1 && echo "dialog program:           $p"
done
echo
echo "Expected 'ps args of sudo' (or /proc readable): sudo -k -A -- sh -c echo \"a b\" arg2"
echo "If it shows only (sudo) or is empty, askpass relies on the agent-sudo wrapper's args."
