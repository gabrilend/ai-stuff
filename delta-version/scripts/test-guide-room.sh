#!/bin/bash
# test-guide-room.sh - proves a reading-walk guide's room keeps its ledgers
# honestly, and that making a room asks first.
#
# In general terms: this makes a room folder in RAM (no system account -- the
# ledger rules do not depend on who owns the folder), has a stand-in guide
# write files and list them as public, kept, edited and extended, and checks
# that a well-kept room passes and that each kind of broken ledger is caught:
# a file listed that is not there, an entry earlier than the one before it, a
# path climbing out of the room, a change to a file never listed, a change
# that is neither an edit nor an extension. It then checks that the room maker
# shows its plan without acting in a dry run, and does nothing without a
# typed "yes". Exercises issue 065e.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/scripts/reading-walk-guide-room.lua"
LIBRARY="$DIR/scripts/libs/guide-room.lua"
ROOM="/dev/shm/delta-version/guide-room-test/room"

PASS=0
FAIL=0

# -- {{{ check
function check() {
    local label="$1" ok="$2"
    if [ "$ok" = "yes" ]; then
        echo "  ok   - $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL - $label"
        FAIL=$((FAIL + 1))
    fi
}
# }}}

# -- {{{ contains
function contains() {
    case "$1" in *"$2"*) echo yes ;; *) echo no ;; esac
}
# }}}

# -- {{{ guide
function guide() {
    # Runs Lua as the stand-in guide, with the room library as R and the room
    # open as room; a fixed clock that steps one second per entry.
    luajit -e "
        local R = dofile('$LIBRARY')
        local tick = 0
        R.now = function() tick = tick + 1; return string.format('2026-10-10T12:00:%02d', tick) end
        local room = R.open('$ROOM')
        $1"
}
# }}}

# -- {{{ fresh_room
function fresh_room() {
    rm -rf "$ROOM"
    mkdir -p "$ROOM"
    echo "a note the guide shares" > "$ROOM/shared.txt"
    echo "ciphertext stands in here" > "$ROOM/kept.bin"
}
# }}}

echo "ledgers:"
fresh_room
guide "R.make_public(room, 'shared.txt', 'how I explained the blur'); R.keep(room, 'kept.bin');
       R.record_change(room, 'shared.txt', 'extension')"
output=$(luajit "$TOOL" check "$ROOM" 2>&1)
check "a well-kept room is in order" "$(contains "$output" "in order")"
output=$(luajit "$TOOL" list "$ROOM" 2>&1)
check "list shows what was made public, with its note" "$(contains "$output" "shared.txt  -- how I explained the blur")"
check "list counts what was kept, without naming it" "$(contains "$output" "kept to itself: 1 file(s)")"

output=$(guide "R.make_public(room, '../escape.txt', 'x')" 2>&1)
check "a path climbing out of the room is refused" "$(contains "$output" "may not climb out")"
output=$(guide "R.keep(room, 'missing.bin')" 2>&1)
check "listing a file that is not there is refused" "$(contains "$output" "no such file")"
output=$(guide "R.record_change(room, 'shared.txt', 'rewrite')" 2>&1)
check "a change must be an edit or an extension" "$(contains "$output" "edit or an extension")"

rm "$ROOM/kept.bin"
output=$(luajit "$TOOL" check "$ROOM" 2>&1)
check "a listed file that vanished is caught" "$(contains "$output" "not in the room: kept.bin")"
fresh_room
printf '2026-10-10T12:00:05\tshared.txt\tlater\n2026-10-10T12:00:01\tkept.bin\tearlier\n' > "$ROOM/made-public.ledger"
output=$(luajit "$TOOL" check "$ROOM" 2>&1)
check "an entry earlier than the one before is caught" "$(contains "$output" "out of time order")"
fresh_room
printf '2026-10-10T12:00:01\tshared.txt\tedit\n' > "$ROOM/changes.ledger"
output=$(luajit "$TOOL" check "$ROOM" 2>&1)
check "a change to a file never listed is caught" "$(contains "$output" "never listed")"

echo "making a room:"
output=$(luajit "$TOOL" create test-guide --dry-run --rooms=/dev/shm/delta-version/guide-room-test/rooms 2>&1)
check "the plan names the account" "$(contains "$output" "useradd --system")"
check "a dry run does nothing" "$(contains "$output" "dry run: nothing was done")"
output=$(echo "no" | luajit "$TOOL" create test-guide --rooms=/dev/shm/delta-version/guide-room-test/rooms 2>&1)
check "without a typed yes, nothing is done" "$(contains "$output" "No consent given")"
output=$(luajit "$TOOL" create "Bad Name" --dry-run 2>&1)
check "a bad guide name is refused" "$(contains "$output" "lower-case letters")"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
