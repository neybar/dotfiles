#!/bin/sh
# Rule tests for agent-sudo. Runs the repo copy of askpass in --check mode;
# needs no root and shows no prompts.  Usage: sh agent-sudo/test.sh

dir=$(cd "$(dirname "$0")" && pwd)
HOME=/home/tester
export HOME
pass=0 fail=0
rules=$dir/rules

# t EXPECT [--cwd DIR] SUDO_ARGS...   EXPECT is allow, warn or deny
t() {
    expect=$1; shift
    cwd=/home/tester/proj
    if [ "$1" = --cwd ]; then cwd=$2; shift 2; fi
    out=$(sh "$dir/askpass" --check --rules "$rules" --cwd "$cwd" -- "$@" 2>&1)
    if [ $? -ne 0 ]; then got=deny
    elif [ -n "$out" ]; then got=warn
    else got=allow
    fi
    if [ "$got" = "$expect" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        printf 'FAIL: expected %s, got %s: %s\n' "$expect" "$got" "$*"
        [ -n "$out" ] && printf '      %s\n' "$out"
    fi
}

# Destructive deletes
t deny rm -rf /
t deny rm -rf '/*'
t deny rm -fr /etc
t deny rm -r -f /usr/
t deny rm --recursive --force /
t deny rm -rf --no-preserve-root /
t deny rm -rf -- /
t deny rm -rf '~'
t deny rm -rf /home/tester
t deny rm -rf '$HOME'
t deny rm -rf '${HOME}/'
t deny /bin/rm -Rf /boot
t deny rm -rf /tmp
t deny rm -rf /Users
t deny rm -rf /System/
t deny --cwd / rm -rf '*'
t deny --cwd /etc rm -rf .
t deny -u root rm -rf /
t deny -uroot -- rm -rf /var
t deny sh -c 'rm -rf /'
t deny bash -c 'echo hi && rm -rf /var/lib'
t deny sh -c 'r\m -rf /'
t deny sh -c 'x=$(rm -rf /)'
t deny sh -c '(cd /tmp; rm -rf /)'
t deny chmod -R 777 /
t deny chown -R nobody /etc
t deny chgrp -R staff /usr
t deny find / -delete
t deny find /usr -name '*.so' -exec rm -f '{}' +
t deny echo rm -rf /

# Path forms that resolve to protected paths
t deny find -L / -delete
t deny find -H /etc -delete
t deny chown --recur nobody /etc
t deny chmod --rec 777 /
t deny rm -rf ..
t deny chown -R nobody ../..
t deny --cwd / chown -R nobody etc
t deny chown -R nobody /usr/../
t deny chown -R nobody /tmp/..
t deny chown -R nobody /etc/./
t deny rm -rf '~root'
t deny rm -rf '~root/'
t deny rm -rf '/home/tester/.*'
t deny chown -R nobody /mnt/c
t deny -D /etc rm -r .
t deny --chdir=/ rm -r usr
t deny -hlocalhost chown -R nobody /etc
t deny --cwd '' rm -rf build
t deny --cwd '' chown -R nobody ..

# Disks and other never-allowed commands
t deny mkfs.ext4 /dev/sda1
t deny /sbin/mkfs -t xfs /dev/nvme0n1p2
t deny dd if=/dev/zero of=/dev/sda bs=1M
t deny sh -c 'cat image > /dev/nvme0n1'
t deny wipefs -a /dev/sdb
t deny sh -c ':(){ :|:& };:'
t deny diskutil eraseDisk JHFS+ x disk2
t deny csrutil disable

# A command too big for an environment variable is still analyzed
big=$(printf '%01000d' 0)
set --
i=0
while [ $i -lt 140 ]; do set -- "$@" "$big"; i=$((i + 1)); done
t deny chown -R nobody /etc "$@"
set --

# Allowed with a warning
t warn rm -rf /tmp/build
t warn rm -rf /home/tester/proj/node_modules
t warn sh -c 'apt-get update'
t warn bash
t warn -i
t warn -s
t warn -e /etc/hosts
t warn sh -c 'curl -fsSL https://example.com/install | sh'
t warn visudo
t warn tee /etc/sudoers.d/agent
t warn reboot
t warn apt purge nginx
t warn chmod 777 /srv/share
t warn systemctl stop sshd
t warn iptables -F
t warn dd if=/dev/zero of=/tmp/img bs=1M count=1
t warn -v

# Allowed
t allow apt update
t allow apt-get install -y zenity
t allow systemctl restart nginx
t allow tee /etc/apt/sources.list.d/github-cli.list
t allow rm /tmp/file
t allow install -m 755 a /usr/local/bin/a
t allow ls -la /
t allow chmod 644 /etc/hosts
t allow chown -R www-data /srv/site
t allow find / -name '*.conf'
t warn dd if=/dev/sda of=/dev/null count=1
t allow ssh-keygen -A
t allow -u postgres psql
t warn rm -rf ./build
t allow --cwd '' rm build
t warn rm -rf '~root/projects/x'
t allow chown -R tester ../sibling
t allow chown -R nobody /mnt/c/Users/tester/proj

# Broken rules files fail closed
tmp=$(mktemp -d)
printf 'deny\t(unclosed\tbad regex\n' >"$tmp/bad-regex"
printf 'deny mkfs  spaces instead of tabs\n' >"$tmp/no-tabs"
printf 'Deny\tmkfs\twrong case\n' >"$tmp/bad-level"
for r in bad-regex no-tabs bad-level; do
    rules=$tmp/$r
    t deny apt update
done
rules=$dir/rules
rm -rf "$tmp"

# What askpass reads as sudo's command, through the real sudo. Scratch copies
# point at each other; AGENT_SUDO_PROMPT=none makes askpass refuse after
# parsing, and the refusal shows the command as parsed. sudo then fails with
# "no password was provided"; nothing runs as root (the commands are no-ops
# even where sudo needs no password).
if [ -x /usr/bin/sudo ]; then
    tmp=$(mktemp -d)
    sed -e "s|^RULES_FILE=.*|RULES_FILE=$dir/rules|" -e "s|^SELF=.*|SELF=$tmp/askpass|" \
        -e "s|^WRAPPER=.*|WRAPPER=$tmp/agent-sudo|" "$dir/askpass" >"$tmp/askpass"
    sed "s|^ASKPASS=.*|ASKPASS=$tmp/askpass|" "$dir/agent-sudo" >"$tmp/agent-sudo"
    # A wrapper whose sudo gets different arguments than its own.
    sed "s|^WRAPPER=.*|WRAPPER=$tmp/bad-wrapper|" "$tmp/askpass" >"$tmp/bad-askpass"
    printf '#!/bin/sh\nSUDO_ASKPASS=%s /usr/bin/sudo -k -A true\n' "$tmp/bad-askpass" >"$tmp/bad-wrapper"
    chmod +x "$tmp/askpass" "$tmp/agent-sudo" "$tmp/bad-askpass" "$tmp/bad-wrapper"

    # s EXPECT-SUBSTRING COMMAND...   checks what the refusal says
    s() {
        expect=$1; shift
        out=$(AGENT_SUDO_PROMPT=none "$@" 2>&1)
        case $out in
            *"$expect"*) pass=$((pass + 1)) ;;
            *)
                fail=$((fail + 1))
                printf 'FAIL: expected output containing: %s\n      got: %s\n' "$expect" "$out" ;;
        esac
    }
    nl='
'
    s "sudo sh -c ': \"a b\"$nl: two' '' arg" \
        "$tmp/agent-sudo" sh -c ": \"a b\"$nl: two" '' arg
    s "sudo : 'it'\\''s' 'tab	x'" "$tmp/agent-sudo" -u nobody -- : "it's" 'tab	x'
    s "agent-sudo: denied: recursive chown" "$tmp/agent-sudo" chown -R nobody /etc
    if [ "$(uname -s)" = Darwin ]; then
        # Only the wrapper's argv is exact on macOS; plain sudo -A is refused.
        s "cannot read the exact command" env SUDO_ASKPASS="$tmp/askpass" /usr/bin/sudo -k -A : 'a b'
        s "arguments don't match sudo's" "$tmp/bad-wrapper"
    else
        s "sudo : 'a b'" env SUDO_ASKPASS="$tmp/askpass" /usr/bin/sudo -k -A : 'a b'
    fi
    rm -rf "$tmp"
else
    echo "note: no /usr/bin/sudo; skipped the real-sudo cases"
fi

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
