#!/usr/bin/env bash
# test-state-daemon-interactive.sh -- drives `state-daemon.sh -I` in a pretend
# terminal and checks what it did to the daemon, and checks `watch` (issue
# 014, phase 3).
#
# How: `script` gives the menu a real terminal (sized with stty), keys are
# typed one second apart, and afterwards the daemon is asked what it holds.
# The menu's "Do" list comes first (Refresh, Set a key, Delete the checked
# keys, Clear all keys, Watch, Stop the daemon), then the keys, then Go; G
# jumps to Go.
#
# Needs `script` (util-linux) and luajit. Takes about a minute.
# Usage: bash scripts/tests/test-state-daemon-interactive.sh [scripts-dir]

DIR="/home/ritz/programming/ai-stuff/scripts"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi
WORK="$(mktemp -d /tmp/test-state-daemon-interactive-XXXXXX)"
STATE="$WORK/state"
mkdir -p "$STATE"
SD() { bash "$DIR/state-daemon.sh" "$STATE" "$@"; }

pass=0; fail=0
# {{{ check
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}
# }}}

# {{{ leave no daemon behind
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

# {{{ drive <name> <keys...>
# Opens the menu, types each key one second apart, then q to leave. A key
# may be a whole line for a prompt, ending in a carriage return.
drive() {
    local name="$1"; shift
    {
        sleep 2
        for key in "$@"; do printf '%s' "$key"; sleep 1; done
        printf 'q'; sleep 1
    } | timeout 60 script -qfc "stty rows 30 cols 100; bash $DIR/state-daemon.sh $STATE -I" "$WORK/$name.log" >/dev/null 2>&1
}
# }}}

# {{{ screen <name>
# The last screen the menu drew in that run, as plain text (the recording
# replayed by libs/test-menu-screen-replay.lua).
screen() {
    luajit "$DIR/libs/test-menu-screen-replay.lua" "$WORK/$1.log" 30 100
}
# }}}

SD start > /dev/null
SD set alpha 1
SD set bravo 2
SD set charlie 3

# {{{ delete the checked key
# Refresh -> Set -> Delete: space picks Delete. Then down past Clear, Watch
# and Stop to the keys (alpha, bravo, charlie): space checks bravo. G, Enter.
drive delete j j ' ' j j j j j ' ' G $'\r'
check "delete removes the checked key" "$(SD get bravo 2>&1)" "ERR:key_not_found"
check "and leaves the others" "$(SD count)" "2"
check "the menu listed keys with their values" "$(grep -c 'alpha = 1' "$WORK/delete.log")" "1"
# }}}

# {{{ set a key at the prompt
drive set j ' ' G $'\r' $'delta\r' $'hello world\r'
check "set stores the typed key and value" "$(SD get delta 2>&1)" "hello world"
check "the menu came back afterwards and said so" "$(screen set | grep -c 'Set delta')" "1"
# }}}

# {{{ a key with a space is refused
drive badset j ' ' G $'\r' $'two words\r'
check "a key with a space is not set" "$(SD count)" "3"
# }}}

# {{{ clear asks first
drive clear-no j j j ' ' G $'\r' $'n\r'
check "answering no keeps the keys" "$(SD count)" "3"
drive clear-yes j j j ' ' G $'\r' $'y\r'
check "answering yes clears them" "$(SD count)" "0"
# }}}

# {{{ stop, then start again from the menu
SD set echo 5
drive stop j j j j j ' ' G $'\r'
check "stop from the menu stops the daemon" "$(SD ping 2>&1)" "No response"
check "the reopened menu offers to start it" "$(screen stop | grep -c 'Start the daemon')" "1"
drive start G $'\r'
check "start from the menu starts it" "$(SD ping 2>&1)" "Daemon is alive"
check "state saved at stop is back" "$(SD get echo 2>&1)" "5"
# }}}

# {{{ watch, from the menu and on its own
drive watch j j j j ' ' G $'\r' x
check "watch from the menu shows the keys" "$(grep -c 'echo=5' "$WORK/watch.log")" "1"
check "a key leaves watch and the menu comes back" \
    "$(grep -c 'any key stops watching' "$WORK/watch.log")" "1"
out="$(timeout 3 bash "$DIR/state-daemon.sh" "$STATE" watch 1 < /dev/null)"
check "watch on its own shows the keys" "$( [ "$(grep -c 'echo=5' <<< "$out")" -ge 2 ] && echo yes || echo no)" "yes"
check "without a terminal it redraws on the interval, not in a spin" \
    "$( [ "$(grep -c 'any key stops watching' <<< "$out")" -le 4 ] && echo yes || echo no)" "yes"
# }}}

SD stop > /dev/null
[ -n "${KEEP:-}" ] && echo "kept $WORK" || rm -rf "${WORK:?}"
echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
