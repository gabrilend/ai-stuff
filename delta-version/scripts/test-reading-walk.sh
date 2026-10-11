#!/bin/bash
# test-reading-walk.sh - proves the reading walk's map and walk do what issue
# 065 says.
#
# In general terms: this builds a tiny made-up project in RAM -- two source
# files, one with a documentation page, one issue file, a git history holding
# only the first file -- maps it, and checks each rule: stops come in reading
# order; a description comes from the page when there is one and is marked as
# coming from the source comment when there is not; a prose heading is a stop
# with no uses; a private helper's uses are counted only in its own file while
# a shared one's are counted wherever it is called; a reason is recorded only
# where it was written down, from a comment or from an issue paragraph; a file
# never committed says so; one worker and three workers give the same map. It
# then walks the map without a person and checks that walking to the end is a
# complete reading, that skipping shows the summary, and that "yeah yeah" is
# taken as a skip. Last, it walks with a stand-in guide and checks that the
# guide steps back to a stop the current one is built from, returns
# afterwards, notes everything only encrypted in its room, and that an answer
# it cannot use hands the choice back to the reader.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

BUILDER="$DIR/scripts/reading-walk-map.lua"
WALKER="$DIR/scripts/reading-walk.lua"
FIXTURE="/dev/shm/delta-version/reading-walk-test"
PROJECT="$FIXTURE/tiny-project"

PASS=0
FAIL=0

# -- {{{ check
function check() {
    # One line per assertion; failures keep going so a run reports everything.
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

# -- {{{ same
function same() {
    [ "$1" = "$2" ] && echo yes || echo no
}
# }}}

# -- {{{ contains
function contains() {
    # "yes" when the first text holds the second, for check's second argument.
    case "$1" in *"$2"*) echo yes ;; *) echo no ;; esac
}
# }}}

# -- {{{ ask
function ask() {
    # Evaluates a Lua expression against the map (bound as m) and prints it.
    local map="$1" expression="$2"
    luajit -e "local m = dofile('$map'); io.write(tostring($expression))"
}
# }}}

# -- {{{ build_fixture
function build_fixture() {
    rm -rf "$FIXTURE"
    mkdir -p "$PROJECT/src" "$PROJECT/issues"

    cat > "$PROJECT/src/001-alpha.lua" <<'EOF'
local M = {}

-- {{{ WHY THIS FILE EXISTS
-- It greets people. Every walk begins with a greeting.
-- }}}

-- {{{ local function helper()
-- Puts a name in a sentence.
local function helper(name)
    return "hello, " .. name
end
-- }}}

-- {{{ M.greet(name)
-- Greets one person by name.
--
-- The greeting is built here rather than by the caller, so every greeting in
-- the project reads the same.
function M.greet(name)
    return helper(name)
end
-- }}}

return M
EOF

    cat > "$PROJECT/src/002-beta.lua" <<'EOF'
local alpha = dofile("src/001-alpha.lua")
local M = {}

-- {{{ TABLE -- the words that get shouted
local TABLE = { "hey", "oi" }
-- }}}

-- {{{ M.shout(text)
-- This comment is not the description; the page is.
function M.shout(text)
    local helper = "not the other file's helper"
    return alpha.greet(text):upper() .. TABLE[1]
end
-- }}}

return M
EOF

    cat > "$PROJECT/src/002-beta.info.md" <<'EOF'
# 002-beta - info

| | |
|---|---|
| `M.shout(text)` | A greeting, loudly. |

### `M.shout(text)`

A greeting, loudly. Upper case all the way through.
EOF

    cat > "$PROJECT/issues/101-loud.md" <<'EOF'
# 101 - loud

Some unrelated paragraph that mentions nothing at all.

We shout the greeting instead of whispering it, because a whisper
is lost across the room.
EOF

    git -C "$PROJECT" init -q
    git -C "$PROJECT" -c user.name=test -c user.email=test@test add src/001-alpha.lua
    git -C "$PROJECT" -c user.name=test -c user.email=test@test commit -q -m "alpha arrives"
}
# }}}

# -- {{{ run_map_checks
function run_map_checks() {
    local map="$FIXTURE/one.map.lua"
    luajit "$BUILDER" "$PROJECT" --out="$map" --workers=1 > /dev/null
    luajit "$BUILDER" "$PROJECT" --out="$FIXTURE/three.map.lua" --workers=3 > /dev/null

    echo "map:"
    check "five stops" "$(same "$(ask "$map" '#m.stops')" 5)"
    check "reading order: alpha's heading first, beta's shout last" \
        "$(same "$(ask "$map" 'm.stops[1].file .. " " .. m.stops[5].name')" "src/001-alpha.lua M.shout")"
    check "a prose heading is a passage" "$(same "$(ask "$map" 'm.stops[1].kind')" passage)"
    check "a passage has no uses" "$(same "$(ask "$map" '#m.stops[1].uses')" 0)"
    check "a page entry is the description" "$(same "$(ask "$map" 'm.stops[5].description_source')" info.md)"
    check "no page: description from the comment, marked" \
        "$(same "$(ask "$map" 'm.stops[3].description_source')" "source comment")"
    check "the summary is the first sentence" "$(same "$(ask "$map" 'm.stops[5].summary')" "A greeting, loudly.")"
    check "a private helper is used once, in its own file only" \
        "$(same "$(ask "$map" '#m.stops[2].uses .. " " .. m.stops[2].uses[1].file')" "1 src/001-alpha.lua")"
    check "a shared function is used from another file" \
        "$(same "$(ask "$map" 'm.stops[3].uses[1].file')" "src/002-beta.lua")"
    check "a reason written in a comment is recorded" \
        "$(contains "$(ask "$map" 'm.stops[3].alternatives[1].text')" "rather than by the caller")"
    check "a reason written in an issue paragraph is recorded" \
        "$(contains "$(ask "$map" 'm.stops[5].alternatives[1].text')" "instead of whispering")"
    check "an issue paragraph without a reason is not" \
        "$(same "$(ask "$map" '#m.stops[5].alternatives')" 1)"
    check "nothing written down: no reason invented" "$(same "$(ask "$map" '#m.stops[4].alternatives')" 0)"
    check "a committed file names its first commit" "$(same "$(ask "$map" 'm.stops[2].chapter.subject')" "alpha arrives")"
    check "a file never committed says so" \
        "$(same "$(ask "$map" 'm.stops[5].chapter.subject')" "not yet in history")"
    check "one worker and three workers give the same map" \
        "$(same "$(grep -v '"built"' "$map" | md5sum)" "$(grep -v '"built"' "$FIXTURE/three.map.lua" | md5sum)")"
}
# }}}

# -- {{{ run_walk_checks
function run_walk_checks() {
    local map="$FIXTURE/one.map.lua" output
    echo "walk:"
    output=$(luajit "$WALKER" --map="$map" --choices=nnnnn)
    check "walking every stop is a complete reading" "$(contains "$output" "walk complete")"
    output=$(luajit "$WALKER" --map="$map" --start=5 --choices=s)
    check "skip shows the summary" "$(contains "$output" "in short: A greeting, loudly.")"
    check "starting partway is not called complete" "$(contains "$output" "having started at stop 5")"
    output=$(luajit "$WALKER" --map="$map" --choices=f)
    check "skipping a file shows each of its summaries" \
        "$(contains "$output" "M.greet: Greets one person by name.")"
    output=$(printf 'yeah yeah I get it\nq\n' | luajit "$WALKER" --map="$map" --start=5)
    check "\"yeah yeah\" is a skip" "$(contains "$output" "in short: A greeting, loudly.")"
    output=$(luajit "$WALKER" --map="$map" --start=4 --choices=wq)
    check "no reason: the walk says it was not written down" "$(contains "$output" "no alternative was recorded here")"
}
# }}}

# -- {{{ run_guide_checks
function run_guide_checks() {
    local map="$FIXTURE/one.map.lua" room="$FIXTURE/room" output
    echo "guide:"
    rm -rf "$room"
    mkdir -p "$room"
    # A stand-in AI: steps back to the first foundation offered when the
    # reader has asked for two or more things at the current stop since the
    # guide last moved, else on.
    cat > "$FIXTURE/stand-in-guide.lua" <<'EOF'
return function(system, user)
    local current = user:match("Current stop (%d+)")
    local since = user:match(".*\n  guide [^\n]*(.*)$") or user
    local asked = 0
    for _ in since:gmatch("stop " .. current .. " %a+") do asked = asked + 1 end
    local foundation = user:match("\n  (%d+): ")
    if asked >= 2 and foundation then return "BACK " .. foundation end
    return "NEXT"
end
EOF
    echo 'return function() return "I would like to ask the reader a question." end' > "$FIXTURE/unreadable-guide.lua"
    echo 'return function() return "BACK 1" end' > "$FIXTURE/wrong-back-guide.lua"

    output=$(luajit "$WALKER" --map="$map" --start=3 --choices=mwnnnq --guide="$room" --guide-model="$FIXTURE/stand-in-guide.lua")
    check "a struggling reader is stepped back to a foundation" \
        "$(contains "$output" "the guide steps back to stop 2, which this one is built from")"
    check "after the step back, next returns to where the reader was" \
        "$(contains "$output" "back to stop 3, where you were")"
    check "the receipt counts the guide's step back" "$(contains "$output" "stepped back 1")"
    check "nothing the reader did is on disk in plain text" \
        "$(grep -rq -e 'more' -e 'guide back' "$room"/trail-*.trail && echo no || echo yes)"
    local notes
    notes=$(luajit -e "
        local T = dofile('$DIR/scripts/libs/guide-trail.lua')
        local trail = T.open('$room')
        local name = io.popen('ls $room | grep trail-'):read('*l'):match('^trail%-(.*)%.trail$')
        io.write(table.concat(T.read(trail, name), '|'))")
    check "the trail reads back: the reader's requests, then the guide's move" \
        "$(contains "$notes" "stop 3 more|stop 3 why|stop 3 next|guide back 2")"
    output=$(luajit "$WALKER" --map="$map" --start=3 --choices=nq --guide="$room" --guide-model="$FIXTURE/unreadable-guide.lua")
    check "an answer with no move hands the choice to the reader" "$(contains "$output" "choose for yourself")"
    output=$(luajit "$WALKER" --map="$map" --start=3 --choices=nq --guide="$room" --guide-model="$FIXTURE/wrong-back-guide.lua")
    check "a step back to a stop not offered is refused" "$(contains "$output" "not offered")"
    output=$(INFERENCE_CHAT_HOST=127.0.0.1:1 luajit "$WALKER" --map="$map" --choices=q --guide="$room" 2>&1)
    check "a guide with no AI answering is an error, not a quiet walk without one" \
        "$(contains "$output" "is not answering")"
    output=$(luajit "$DIR/scripts/reading-walk-guide-room.lua" check "$room" 2>&1)
    check "the guide's room is in order after the walks" "$(contains "$output" "in order")"
}
# }}}

build_fixture
run_map_checks
run_walk_checks
run_guide_checks
echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
