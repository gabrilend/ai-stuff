#!/bin/bash
# test-guide-cipher.sh - proves the guide's cipher gives messages back, keeps
# them from the wrong key, and writes trails only encrypted.
#
# In general terms: this encrypts and decrypts messages of several lengths,
# checks that the wrong key is refused, that the same message encrypted twice
# looks different each time, that the stream's 256 byte values come up about
# equally often over a quarter of a million bytes (a lopsided stream would
# leak the message), and that two keys differing in one byte give unrelated
# streams. It then writes a trail into a room in RAM and checks that no
# reader's choice appears on disk in plain text, that the trail reads back in
# order, and that the room's ledgers are in order afterwards. Exercises issue
# 065f.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

LIBS="$DIR/scripts/libs"
ROOM="/dev/shm/delta-version/guide-cipher-test/room"

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

# -- {{{ lua
function lua() {
    # Runs Lua with the cipher as C and the trail library as T; prints what
    # the snippet returns.
    luajit -e "
        local C = dofile('$LIBS/guide-cipher.lua')
        local T = dofile('$LIBS/guide-trail.lua')
        io.write(tostring((function() $1 end)()))"
}
# }}}

echo "cipher:"
check "messages of every length come back" "$(lua "
    local key = C.make_key()
    for _, n in ipairs({0, 1, 7, 64, 1000}) do
        local text = string.rep('ab\0c', n):sub(1, n)
        if C.decrypt(key, C.encrypt(key, text)) ~= text then return 'no' end
    end
    return 'yes'")"
check "the wrong key is refused" "$(lua "
    local ok, problem = pcall(C.decrypt, C.make_key(), C.encrypt(C.make_key(), 'secret'))
    return (not ok and problem:find('wrong key')) and 'yes' or 'no'")"
check "the same message twice looks different" "$(lua "
    local key = C.make_key()
    return (C.encrypt(key, 'same words') ~= C.encrypt(key, 'same words')) and 'yes' or 'no'")"
check "the message does not appear in its encrypted form" "$(lua "
    return C.encrypt(C.make_key(), 'stop 12 skip'):find('stop 12', 1, true) and 'no' or 'yes'")"
check "a key and nonce give the same stream every time" "$(lua "
    local key, nonce = string.rep('k', 32), string.rep('n', 16)
    return (C.encrypt(key, 'x', nonce) == C.encrypt(key, 'x', nonce)) and 'yes' or 'no'")"
check "byte values come up evenly (each within 15% of even over 262144 bytes)" "$(lua "
    local sample = C.stream_sample(C.make_key(), string.rep('n', 16), 262144)
    local counts = {}
    for i = 0, 255 do counts[i] = 0 end
    for _, b in ipairs(sample) do counts[b] = counts[b] + 1 end
    for i = 0, 255 do if math.abs(counts[i] - 1024) > 154 then return 'no' end end
    return 'yes'")"
check "keys one byte apart give unrelated streams (under 2% of bytes agree)" "$(lua "
    local key = string.rep('k', 32)
    local other = key:sub(1, 31) .. 'j'
    local a = C.stream_sample(key, string.rep('n', 16), 4096)
    local b = C.stream_sample(other, string.rep('n', 16), 4096)
    local same = 0
    for i = 1, 4096 do if a[i] == b[i] then same = same + 1 end end
    return (same / 4096 < 0.02) and 'yes' or 'no'")"

echo "trail:"
rm -rf "$ROOM"
mkdir -p "$ROOM"
lua "
    local trail = T.open('$ROOM')
    T.note(trail, 'walk-1', 'stop 1 next')
    T.note(trail, 'walk-1', 'stop 2 more')
    T.note(trail, 'walk-1', 'stop 2 skip')
    return ''" > /dev/null
check "no reader's choice is on disk in plain text" \
    "$(grep -rq -e 'stop 1' -e 'skip' "$ROOM"/*.trail && echo no || echo yes)"
check "the trail reads back in order" "$(lua "
    local notes = T.read(T.open('$ROOM'), 'walk-1')
    return (table.concat(notes, '|') == 'stop 1 next|stop 2 more|stop 2 skip') and 'yes' or 'no'")"
check "the key is readable by its owner only" "$(same_mode=$(stat -c %a "$ROOM/guide.key"); [ "$same_mode" = 600 ] && echo yes || echo no)"
output=$(luajit "$DIR/scripts/reading-walk-guide-room.lua" check "$ROOM" 2>&1)
check "the room's ledgers are in order afterwards" "$(case "$output" in *"in order"*) echo yes ;; *) echo no ;; esac)"
check "the trail and key are listed as kept, the notes as extensions" "$(lua "
    local R = T.room_library
    local room = R.open('$ROOM')
    return (#R.read(room, 'private') == 2 and #R.read(room, 'changes') == 2) and 'yes' or 'no'")"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
