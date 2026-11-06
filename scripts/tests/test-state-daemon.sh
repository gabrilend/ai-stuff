#!/usr/bin/env bash
# test-state-daemon.sh -- checks state-daemon.sh against a folder of its own
# (issue 052).
#
# The bug this pins: `state-daemon.sh DIR start` started the daemon in the
# default folder, /tmp/state-daemon, while every client command talked to
# DIR, so nothing could reach it. And when the daemon could not make its
# request pipe it did not stop: it looped on the missing pipe, writing an
# error line to its log many times a second, while start reported success.
#
# Also covers the commands themselves: set, get, list, dump, count, del,
# clear, save, ping, status, and state surviving a restart.
#
# Every daemon runs in a temp folder, and the test stops each one it starts.
# Usage: bash scripts/tests/test-state-daemon.sh [scripts-dir]

DIR="/home/ritz/programming/ai-stuff/scripts"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi
WORK="$(mktemp -d /tmp/test-state-daemon-XXXXXX)"
STATE="$WORK/state"
mkdir -p "$STATE"
SD() { bash "$DIR/state-daemon.sh" "$@"; }

pass=0; fail=0
# {{{ check
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}
# }}}

# {{{ stop_any <folder>
# Stops a daemon left running in a folder, by its PID file, whatever the
# script under test did, so a failing check never leaves one behind.
stop_any() {
    local pid
    pid="$(cat "$1/daemon.pid" 2>/dev/null)"
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
    return 0
}
# }}}

# {{{ leave no daemon behind
# Whatever happens, every daemon this test started is stopped on exit: the
# old script's daemons ran in the wrong folder, so a PID file could not find
# them. Daemons running before the test are left alone.
DAEMON_PATTERN='state-daemon[.]sh _daemon$'
DAEMONS_AT_START=" $(pgrep -f "$DAEMON_PATTERN" | tr '\n' ' ')"
stop_test_daemons() {
    local pid
    for pid in $(pgrep -f "$DAEMON_PATTERN"); do
        [[ "$DAEMONS_AT_START" == *" $pid "* ]] || kill "$pid" 2>/dev/null
    done
}
trap stop_test_daemons EXIT
# }}}

# {{{ a daemon in its own folder
out="$(SD "$STATE" start)"
check "start in a given folder reports success" "$(grep -c '^Daemon started' <<< "$out")" "1"
check "its request pipe is in that folder" "$([ -p "$STATE/request.fifo" ] && echo yes || echo no)" "yes"
check "its PID file is in that folder" "$([ -s "$STATE/daemon.pid" ] && echo yes || echo no)" "yes"
check "ping reaches it" "$(SD "$STATE" ping 2>&1)" "Daemon is alive"
# }}}

# {{{ the commands
SD "$STATE" set project world-edit
SD "$STATE" set phase 1
check "get returns what set stored" "$(SD "$STATE" get project 2>&1)" "world-edit"
check "count" "$(SD "$STATE" count 2>&1)" "2"
check "list names both keys" "$(SD "$STATE" list | grep -c -x -e project -e phase)" "2"
check "dump shows key=value" "$(SD "$STATE" dump | grep -c -x 'phase=1')" "1"
SD "$STATE" del phase
check "del removes the key" "$(SD "$STATE" get phase 2>&1)" "ERR:key_not_found"
check "a missing key exits non-zero" "$(SD "$STATE" get phase >/dev/null 2>&1; echo $?)" "1"
check "status names the key count" "$(SD "$STATE" status | grep -c 'Keys stored: 1')" "1"
check "save writes state.dat" "$(SD "$STATE" save >/dev/null; grep -c -x 'project=world-edit' "$STATE/state.dat")" "1"
# }}}

# {{{ state survives a restart
check "stop reports it" "$(SD "$STATE" stop)" "Daemon stopped"
check "the request pipe is gone" "$([ -e "$STATE/request.fifo" ] && echo yes || echo no)" "no"
SD "$STATE" start > /dev/null
check "after a restart the key is back" "$(SD "$STATE" get project 2>&1)" "world-edit"
SD "$STATE" clear > /dev/null
check "clear empties it" "$(SD "$STATE" count 2>&1)" "0"
SD "$STATE" stop > /dev/null
stop_any "$STATE"
# }}}

# {{{ a daemon that cannot make its pipe gives up
# A folder already holding a directory named request.fifo: rm -f cannot
# clear it and mkfifo cannot replace it.
BROKEN="$WORK/broken"
mkdir -p "$BROKEN/request.fifo"
daemons_before="$(pgrep -c -f "$DAEMON_PATTERN")"
out="$(SD "$BROKEN" start)"
check "start reports the failure" "$(grep -c '^Failed to start daemon' <<< "$out")" "1"
check "start exits non-zero" "$(SD "$BROKEN" start >/dev/null 2>&1; echo $?)" "1"
sleep 0.5
check "no daemon is left running" "$(pgrep -c -f "$DAEMON_PATTERN")" "$daemons_before"
lines_before="$(wc -l < "$BROKEN/daemon.log")"
sleep 0.5
check "its log stops growing" "$(wc -l < "$BROKEN/daemon.log")" "$lines_before"
check "the log says why" "$(grep -c 'Cannot create' "$BROKEN/daemon.log")" "2"
stop_any "$BROKEN"
# }}}

rm -rf "${WORK:?}"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
