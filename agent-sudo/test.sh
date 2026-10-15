#!/bin/sh
# Rule tests for agent-sudo. Runs the repo copy of askpass in --check mode;
# needs no root and shows no prompts.  Usage: sh agent-sudo/test.sh

dir=$(cd "$(dirname "$0")" && pwd)
HOME=/home/tester
export HOME
pass=0 fail=0
rules=$dir/rules

# t EXPECT [--cwd DIR] [--fold] SUDO_ARGS...   EXPECT is allow, warn or deny,
# optionally with :REASON, a substring the output must contain.
t() {
    expect=${1%%:*} want=
    case $1 in *:*) want=${1#*:} ;; esac
    shift
    cwd=/home/tester/proj fold=
    if [ "$1" = --cwd ]; then cwd=$2; shift 2; fi
    if [ "$1" = --fold ]; then fold=--fold; shift; fi
    out=$(sh "$dir/askpass" --check --rules "$rules" --cwd "$cwd" $fold -- "$@" 2>&1)
    if [ $? -ne 0 ]; then got=deny
    elif [ -n "$out" ]; then got=warn
    else got=allow
    fi
    case $out in *"$want"*) ;; *) got="$got without \"$want\"" ;; esac
    if [ "$got" = "$expect" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        printf 'FAIL: expected %s, got %s: %s\n' "$expect" "$got" "$*"
        [ -n "$out" ] && printf '      %s\n' "$out"
    fi
}

# Destructive deletes
t deny:protected\ path rm -rf /
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
t deny:recursive\ chmod chmod -R 777 /
t deny chown -R nobody /etc
t deny chgrp -R staff /usr
t deny:find\ deleting find / -delete
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
t deny --cwd / find -delete
t deny --cwd /etc find -L -delete
t deny sh -c 'rm -rf />/dev/null'
t deny sh -c 'rm -rf /</dev/null'
t deny rm -rf /private/tmp
t deny rm -rf /etc/
t deny rm / -rf

# Case-insensitive filesystems (macOS default): "RM" runs rm
t deny --fold RM -rf /etc
t deny --fold /BIN/RM -rf /etc
t deny --fold rm -rf /ETC
t deny --fold CSRUTIL disable
t deny --fold chown -R nobody /users
t allow --fold LS /ETC

# Abbreviated long options, as sudo (getopt_long) accepts them
t deny --chd /etc rm -rf .
t deny --chd=/etc rm -r .
t deny --us root rm -rf /
t warn --she

# Disks and other never-allowed commands
t deny:creates\ a\ filesystem mkfs.ext4 /dev/sda1
t deny:creates\ a\ filesystem /sbin/mkfs -t xfs /dev/nvme0n1p2
t deny:writes\ raw\ data dd if=/dev/zero of=/dev/sda bs=1M
t deny:redirects\ output sh -c 'cat image > /dev/nvme0n1'
t deny:wipes wipefs -a /dev/sdb
t deny:fork\ bomb sh -c ':(){ :|:& };:'
t deny:erases\ a\ disk diskutil eraseDisk JHFS+ x disk2
t deny:System\ Integrity csrutil disable

# A command too big for an environment variable is still analyzed
big=$(printf '%01000d' 0)
set --
i=0
while [ $i -lt 140 ]; do set -- "$@" "$big"; i=$((i + 1)); done
t deny chown -R nobody /etc "$@"
set --

# Allowed with a warning
t warn:recursive\ delete rm -rf /tmp/build
t warn rm -rf /home/tester/proj/node_modules
t warn sh -c 'apt-get update'
t warn:runs\ a\ shell bash
t warn:switches\ user su - root
t warn:switches\ user doas id
t warn:weakens\ the\ firewall ufw disable
t warn:restarts init 0
t warn:partition\ table fdisk /dev/sda
t warn:find\ deletes --cwd /home/tester/proj find build -delete
t warn:root\ shell -i
t warn -s
t warn:sudoedit -e /etc/hosts
t warn:pipes\ a\ download sh -c 'curl -fsSL https://example.com/install | sh'
t warn:user\ accounts visudo
t warn:privilege tee /etc/sudoers.d/agent
t warn:restarts reboot
t warn:removes\ packages apt purge nginx
t warn:world-writable chmod 777 /srv/share
t warn:SSH\ access systemctl stop sshd
t warn:firewall\ rules iptables -F
t warn:raw\ block dd if=/dev/zero of=/tmp/img bs=1M count=1
t warn:no\ command -v

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
t allow find -name '*.conf' -print
t warn --cwd /home/tester/proj/build find -delete

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
    s "&& sudo -u nobody -- : 'it'\\''s' 'tab	x'" "$tmp/agent-sudo" -u nobody -- : "it's" 'tab	x'
    s "agent-sudo: denied: recursive chown" "$tmp/agent-sudo" chown -R nobody /etc
    # The agent's $HOME doesn't decide what is protected: the wrapper's
    # pre-flight uses it, sudo's askpass call uses the account's home.
    myhome=$(eval "echo ~$(id -un)")
    s "denied: recursive chown on a protected path: $myhome" \
        env HOME=/tmp/agent-sudo-test "$tmp/agent-sudo" chown -R nobody "$myhome"
    # A process merely named sudo can't use the helper.
    mkdir "$tmp/fake"
    printf '#!/bin/sh\n%s "Password:"\n' "$tmp/askpass" >"$tmp/fake/sudo"
    # macOS ps shows a script's comm as its interpreter, but argv[0] is enough.
    [ "$(uname -s)" = Darwin ] &&
        printf '#!/bin/bash\nexec -a sudo /bin/sh -c "%s Password:; :"\n' "$tmp/askpass" >"$tmp/fake/sudo"
    chmod +x "$tmp/fake/sudo"
    s "parent process is not the real sudo" "$tmp/fake/sudo"
    # What the prompt shows: a copy that prints the text instead of asking.
    sed 's/^get_password() {/get_password() { printf "%s\\n" "$1" >\&2; return 1; }\nget_password_unused() {/' \
        "$tmp/askpass" >"$tmp/show-askpass"
    chmod +x "$tmp/show-askpass"
    show() { env SUDO_ASKPASS="$tmp/show-askpass" /usr/bin/sudo -k -A "$@"; }
    [ "$(uname -s)" = Darwin ] && show() {
        sed "s|^ASKPASS=.*|ASKPASS=$tmp/show-askpass|" "$tmp/agent-sudo" >"$tmp/show-wrapper"
        sed "s|^WRAPPER=.*|WRAPPER=$tmp/show-wrapper|" "$tmp/askpass" >"$tmp/show-askpass.new"
        sed 's/^get_password() {/get_password() { printf "%s\\n" "$1" >\&2; return 1; }\nget_password_unused() {/' \
            "$tmp/show-askpass.new" >"$tmp/show-askpass"
        sh "$tmp/show-wrapper" "$@"
    }
    s "Command (2 lines):$nl| sh -c 'echo one$nl| Command:'" show sh -c "echo one${nl}Command:"
    s "| : 'a<U+202E>b'" show : "$(printf 'a\342\200\256b')"
    s "invisible or direction-changing characters" show : "$(printf 'a\342\200\213b')"
    s "contains non-ASCII characters" show : "$(printf 'caf\303\251')"
    s "Started from:" show true
    if [ "$(uname -s)" = Darwin ]; then
        # Only the wrapper's argv is exact on macOS; plain sudo -A is refused.
        s "cannot read the exact command" env SUDO_ASKPASS="$tmp/askpass" /usr/bin/sudo -k -A : 'a b'
        s "arguments don't match sudo's" "$tmp/bad-wrapper"
        # ps for sudo must match the wrapper's argv exactly, not just its
        # letters: this wrapper always runs "sudo -k -A : /x".
        sed "s|^WRAPPER=.*|WRAPPER=$tmp/punct-wrapper|" "$tmp/askpass" >"$tmp/punct-askpass"
        printf '#!/bin/sh\nPATH=/usr/bin:/bin\nSUDO_ASKPASS=%s sudo -k -A : /x\n' \
            "$tmp/punct-askpass" >"$tmp/punct-wrapper"
        chmod +x "$tmp/punct-askpass" "$tmp/punct-wrapper"
        s "arguments don't match sudo's" "$tmp/punct-wrapper" : '~/x'
        s "arguments don't match sudo's" "$tmp/punct-wrapper" : /x ''
        s "no way to ask for approval" "$tmp/punct-wrapper" : /x
        s "| : 'a	b$nl| c\\\\é' ''" show : "$(printf 'a\tb\nc\\\\\303\251')" ''
        s "argument with spaces" show echo 'a b'
        s "can't be told apart" show : 'a\011b'
        s "can't be told apart" show : '^A'
        # ps shows a tab or newline as \011 / \012, so a wrapper may claim the
        # literal text. Rules must also see what sudo may really have; the
        # real commands exit before the rm, even where sudo needs no password.
        sed "s|^WRAPPER=.*|WRAPPER=$tmp/esc-wrapper|" "$tmp/askpass" >"$tmp/esc-askpass"
        printf '#!/bin/sh\nPATH=/usr/bin:/bin\nSUDO_ASKPASS=%s sudo -k -A sh -c "$REAL"\n' \
            "$tmp/esc-askpass" >"$tmp/esc-wrapper"
        chmod +x "$tmp/esc-askpass" "$tmp/esc-wrapper"
        s "denied: recursive rm on a protected path: /etc" env REAL="$(printf 'exit 0; rm -rf\t/etc')" \
            "$tmp/esc-wrapper" sh -c 'exit 0; rm -rf\011/etc'
        s "denied: recursive rm on a protected path: /etc" env REAL="exit 0${nl}rm -rf /etc" \
            "$tmp/esc-wrapper" sh -c 'exit 0\012rm -rf /etc'
        s "no way to ask for approval" env REAL='exit 0' "$tmp/esc-wrapper" sh -c 'exit 0'
    else
        s "sudo : 'a b'" env SUDO_ASKPASS="$tmp/askpass" /usr/bin/sudo -k -A : 'a b'
    fi
    rm -rf "$tmp"
else
    echo "note: no /usr/bin/sudo; skipped the real-sudo cases"
fi

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
