#!/bin/sh
# Install agent-sudo root-owned so no user-level process can alter what the
# approval prompt shows or capture the password. Run via: make install-agent-sudo
set -eu

[ "$(id -u)" -eq 0 ] || { echo "install.sh: run as root (make install-agent-sudo)" >&2; exit 1; }

src=$(cd "$(dirname "$0")" && pwd)
libdir=/usr/local/libexec/agent-sudo
conf=/etc/sudo.conf
line="Path askpass $libdir/askpass"

# Keep the paths here in sync with AGENT_SUDO_FILES in the Makefile.
# Don't touch an existing /usr/local/bin: Homebrew on Intel Macs owns it.
[ -d /usr/local/bin ] || install -d -m 755 -o 0 -g 0 /usr/local/bin
install -d -m 755 -o 0 -g 0 "$libdir"
install -m 755 -o 0 -g 0 "$src/askpass" "$libdir/askpass"
install -m 644 -o 0 -g 0 "$src/rules" "$libdir/rules"
install -m 755 -o 0 -g 0 "$src/agent-sudo" /usr/local/bin/agent-sudo
echo "installed $libdir/{askpass,rules} and /usr/local/bin/agent-sudo"

# Root ownership only protects the helper if no directory above it is writable
# by anyone but root.
d=$libdir
while [ "$d" != / ]; do
    d=$(dirname "$d")
    perms=$(ls -ldn "$d")
    case $perms in
        ?????w* | ????????w*) writable=yes ;;
        *) writable= ;;
    esac
    if [ "$(echo "$perms" | awk '{print $3}')" != 0 ] || [ -n "$writable" ]; then
        echo "WARNING: $d is not root-only writable ($perms)." >&2
        echo "         A non-root process could replace the askpass helper." >&2
    fi
done

# Let plain sudo use the helper when it has no terminal. sudo only does this
# without -A when a GUI display is present; terminal sudo is unaffected.
if grep -Fqx "$line" "$conf" 2>/dev/null; then
    :
elif grep -Eq '^[[:space:]]*Path[[:space:]]+askpass[[:space:]]' "$conf" 2>/dev/null; then
    echo "note: $conf already sets a different askpass; left unchanged" >&2
else
    printf '\n# Added by dotfiles agent-sudo: approval prompt when sudo has no terminal\n%s\n' "$line" >>"$conf"
    echo "added '$line' to $conf"
fi

if [ "$(uname -s)" != Darwin ] && ! command -v zenity >/dev/null 2>&1 &&
    ! command -v kdialog >/dev/null 2>&1; then
    echo "note: no GUI dialog program found. On desktops/WSLg: apt install zenity." >&2
    echo "      Servers can skip this; agent-sudo prompts in a tmux popup instead." >&2
fi
