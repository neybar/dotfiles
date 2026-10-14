#!/bin/sh
# Install agent-sudo root-owned so no user-level process can alter what the
# approval prompt shows or capture the password.
#
#   install.sh --check   (any user) exit 0 if installed and current, else
#                        print what's missing and exit 1
#   install.sh [--gui DESKTOP]
#                        (root) install or update. --gui (Linux with a display)
#                        also installs a dialog program if none is present:
#                        kdialog on KDE, zenity elsewhere. DESKTOP is
#                        $XDG_CURRENT_DESKTOP, passed in because sudo drops it.
#
# Normally run via make install / make update / make install-agent-sudo.
set -eu

src=$(cd "$(dirname "$0")" && pwd)
libdir=/usr/local/libexec/agent-sudo
conf=/etc/sudo.conf
line="Path askpass $libdir/askpass"
# source-file:installed-path
FILES="askpass:$libdir/askpass rules:$libdir/rules agent-sudo:/usr/local/bin/agent-sudo"

# zenity shows text exactly; on KDE, kdialog (shipped with Plasma) is used
# instead so nothing GNOME gets installed. Either one counts as a dialog.
has_dialog() {
    command -v zenity >/dev/null 2>&1 || command -v kdialog >/dev/null 2>&1
}
is_kde() { case ${1:-} in *KDE* | *kde*) return 0 ;; esac; return 1; }

if [ "${1-}" = --check ]; then
    status=0
    for pair in $FILES; do
        if ! cmp -s "$src/${pair%%:*}" "${pair#*:}"; then
            echo "agent-sudo: ${pair#*:} is missing or out of date"
            status=1
        fi
    done
    if ! grep -Eq '^[[:space:]]*Path[[:space:]]+askpass[[:space:]]' "$conf" 2>/dev/null; then
        echo "agent-sudo: $conf has no askpass line"
        status=1
    fi
    # Only flag a missing dialog where install can fix it (apt).
    if [ "$(uname -s)" = Linux ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] &&
        ! has_dialog && command -v apt-get >/dev/null 2>&1; then
        echo "agent-sudo: no dialog program installed (kdialog on KDE, zenity elsewhere)"
        status=1
    fi
    exit $status
fi

[ "$(id -u)" -eq 0 ] || { echo "install.sh: run as root (make install-agent-sudo)" >&2; exit 1; }

# Don't touch an existing /usr/local/bin: Homebrew on Intel Macs owns it.
[ -d /usr/local/bin ] || install -d -m 755 -o 0 -g 0 /usr/local/bin
install -d -m 755 -o 0 -g 0 "$libdir"
for pair in $FILES; do
    case ${pair%%:*} in rules) mode=644 ;; *) mode=755 ;; esac
    install -m "$mode" -o 0 -g 0 "$src/${pair%%:*}" "${pair#*:}"
done
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

if [ "${1-}" = --gui ] && [ "$(uname -s)" = Linux ] && ! has_dialog; then
    if is_kde "${2-}"; then pkg=kdialog; else pkg=zenity; fi
    if command -v apt-get >/dev/null 2>&1; then
        echo "installing $pkg for the approval dialog"
        DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends "$pkg"
    else
        echo "note: install $pkg for the approval dialog" >&2
    fi
fi
