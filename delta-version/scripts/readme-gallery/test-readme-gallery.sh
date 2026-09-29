#!/bin/bash
# test-readme-gallery.sh - proves the shape gallery makes honest, repeatable films.
#
# In general terms: this films a tiny test scene and has an independent
# reader walk the result the way a browser would, checking it is a real,
# looping GIF with the right number of frames. It films the scene twice and
# checks the two files are identical to the byte, since the gallery promises
# the same scene always gives the same film. Then it feeds the tool three
# broken scenes -- half a turn of spin, a shape that does not exist, a colour
# that does not exist -- and checks each is refused rather than filmed. A
# second test scene carries every word added for the second round of films
# (arches, tails, rocking petals, bursting fruit, horns, clouds) and gets the
# same treatment. Last, it asks the stage manager directly whether every
# scene's first moment and the moment one loop later agree -- the seamless
# loop promise, camera included -- and whether each word does what it says.
# It refuses two broken camera scenes, and films the approved scenes again
# to check each still matches its recorded fingerprint byte for byte.
# A third test scene carries the fourth round's words (ground, rolling,
# becoming, trails, parts, wind) through the same film-and-refuse checks, and
# every scene that promises to keep its subjects in the picture is checked
# frame by frame. It also checks that a film split across worker processes
# is byte-identical to one filmed alone, and that the liquid films to the
# same bytes every time.
# Everything is written to RAM. Exercises the success criteria of issue 060.

DIR="/mnt/mtwo/programming/ai-stuff/delta-version/scripts/readme-gallery"
[ -n "${1:-}" ] && [ -d "$1" ] && DIR="$1"

TOOL="$DIR/readme-gallery.lua"
FACTS="$DIR/tests/gif-facts.lua"
SCRATCH="/dev/shm/delta-version/readme-gallery-test"

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

# -- {{{ test_valid_gif
function test_valid_gif() {
    mkdir -p "$SCRATCH/first" "$SCRATCH/second"
    luajit "$TOOL" "$DIR" "$DIR/tests/tiny.lua" --out="$SCRATCH/first" --still > /dev/null
    check "the tiny scene films without error" "$([ $? -eq 0 ] && echo yes || echo no)"

    local facts
    facts=$(luajit "$FACTS" "$SCRATCH/first/tiny.gif")
    check "signature is GIF89a" "$(echo "$facts" | grep -q 'signature=GIF89a' && echo yes || echo no)"
    check "size is 48x48" "$(echo "$facts" | grep -q 'width=48 height=48' && echo yes || echo no)"
    check "it loops forever" "$(echo "$facts" | grep -q 'loop=yes' && echo yes || echo no)"
    check "it holds all 6 frames" "$(echo "$facts" | grep -q 'frames=6' && echo yes || echo no)"
    check "it ends with the trailer, nothing after" "$(echo "$facts" | grep -q 'trailer=yes' && echo yes || echo no)"

    local png_head
    png_head=$(head -c 8 "$SCRATCH/first/tiny.png" | od -An -tx1 | tr -d ' \n')
    check "the still is a PNG" "$([ "$png_head" = "89504e470d0a1a0a" ] && echo yes || echo no)"

    local frames_override
    luajit "$TOOL" "$DIR" "$DIR/tests/tiny.lua" --out="$SCRATCH/second" --frames=3 > /dev/null
    frames_override=$(luajit "$FACTS" "$SCRATCH/second/tiny.gif")
    check "--frames= overrides the scene's length" "$(echo "$frames_override" | grep -q 'frames=3' && echo yes || echo no)"
}
# }}}

# -- {{{ test_deterministic
function test_deterministic() {
    luajit "$TOOL" "$DIR" "$DIR/tests/tiny.lua" --out="$SCRATCH/second" > /dev/null
    local a b
    a=$(sha256sum < "$SCRATCH/first/tiny.gif")
    b=$(sha256sum < "$SCRATCH/second/tiny.gif")
    check "the same scene films to the same bytes" "$([ "$a" = "$b" ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_refusals
function test_refusals() {
    # Each broken scene is the tiny one with a single word changed.
    local label pattern replacement
    local cases=(
        "half a turn of spin|turns = 1 }|turns = 1.5 }"
        "an unknown shape|mesh = \"torus\"|mesh = \"dodecahedron\""
        "an unknown colour|hue = \"teal\"|hue = \"chartreuse\""
    )
    local entry
    for entry in "${cases[@]}"; do
        IFS='|' read -r label pattern replacement <<< "$entry"
        local broken="$SCRATCH/broken.lua"
        sed "s/$pattern/$replacement/" "$DIR/tests/tiny.lua" > "$broken"
        rm -f "$SCRATCH/broken-out/tiny.gif"
        mkdir -p "$SCRATCH/broken-out"
        luajit "$TOOL" "$DIR" "$broken" --out="$SCRATCH/broken-out" > /dev/null 2>&1
        local code=$?
        check "$label is refused" "$([ $code -ne 0 ] && echo yes || echo no)"
        check "$label films nothing" "$([ ! -e "$SCRATCH/broken-out/tiny.gif" ] && echo yes || echo no)"
    done
}
# }}}

# -- {{{ test_second_round_words
function test_second_round_words() {
    # The second scene carries every word added for the second round of
    # films; it must film into a valid GIF, and breaking any of the new
    # whole-number or closed-list rules must be refused.
    mkdir -p "$SCRATCH/new"
    luajit "$TOOL" "$DIR" "$DIR/tests/tiny-new.lua" --out="$SCRATCH/new" > /dev/null
    check "the second-round scene films without error" "$([ $? -eq 0 ] && echo yes || echo no)"
    check "its GIF holds all 6 frames and loops" \
        "$(luajit "$FACTS" "$SCRATCH/new/tiny-new.gif" | grep -q 'loop=yes frames=6 trailer=yes' && echo yes || echo no)"

    local label pattern replacement entry
    local cases=(
        "half a rock|amount = 0.4, cycles = 1 }|amount = 0.4, cycles = 1.5 }"
        "half an arch|radius = 1.5, cycles = 1, center = { 0, -0.5, 0 } } }|radius = 1.5, cycles = 0.5, center = { 0, -0.5, 0 } } }"
        "an unknown shard colour|shards = \"own\"|shards = \"plaid\""
    )
    for entry in "${cases[@]}"; do
        IFS='|' read -r label pattern replacement <<< "$entry"
        local broken="$SCRATCH/broken-new.lua"
        # the patterns contain braces and quotes, so the swap is done in Lua,
        # which matches them as plain text
        luajit -e "
            local f = io.open([[$DIR/tests/tiny-new.lua]]); local s = f:read('*a'); f:close()
            local a, b = s:find([[$pattern]], 1, true)
            assert(a, 'pattern not found in tiny-new.lua: ' .. [[$pattern]])
            s = s:sub(1, a - 1) .. [[$replacement]] .. s:sub(b + 1)
            f = io.open([[$broken]], 'w'); f:write(s); f:close()"
        rm -f "$SCRATCH/broken-out/tiny-new.gif"
        luajit "$TOOL" "$DIR" "$broken" --out="$SCRATCH/broken-out" > /dev/null 2>&1
        local code=$?
        check "$label is refused" "$([ $code -ne 0 ] && echo yes || echo no)"
        check "$label films nothing" "$([ ! -e "$SCRATCH/broken-out/tiny-new.gif" ] && echo yes || echo no)"
    done
}
# }}}

# -- {{{ test_approved_unchanged
function test_approved_unchanged() {
    # The approved films were made by this tool. Whatever the tool has
    # learned since, filming those scenes again must reproduce every one of
    # them to the byte -- otherwise approval would silently drift away from
    # what the owner saw. Their fingerprints are kept in tests/approved-films.lua
    # (the films themselves live in the owner's library, not the repository).
    mkdir -p "$SCRATCH/approved"
    local listing name expected actual
    listing=$(luajit -e "for name, hash in pairs(dofile([[$DIR/tests/approved-films.lua]])) do print(name .. ' ' .. hash) end" | sort)
    while read -r name expected; do
        luajit "$TOOL" "$DIR" "$name" --out="$SCRATCH/approved" > /dev/null
        actual=$(sha256sum "$SCRATCH/approved/$name.gif" | cut -d' ' -f1)
        check "approved $name films again byte-identical" "$([ "$actual" = "$expected" ] && echo yes || echo no)"
    done <<< "$listing"
}
# }}}

# -- {{{ test_broken_camera
function test_broken_camera() {
    # A camera scene broken two ways: half a turn of orbit, and a camera
    # motion that does not exist. Both refused, nothing filmed.
    local label replacement entry
    local cases=(
        "a camera orbit of half a turn|motion = { kind = \"orbit\", radius = 4, cycles = 0.5 }"
        "an unknown camera motion|motion = { kind = \"teleport\", radius = 4, cycles = 1 }"
    )
    for entry in "${cases[@]}"; do
        IFS='|' read -r label replacement <<< "$entry"
        local broken="$SCRATCH/broken-camera.lua"
        printf 'return { name = "tiny-camera", size = 32, frames = 4, camera = { %s },\n  instances = { { mesh = "cube", hue = "gold" } } }\n' "$replacement" > "$broken"
        rm -f "$SCRATCH/broken-out/tiny-camera.gif"
        mkdir -p "$SCRATCH/broken-out"
        luajit "$TOOL" "$DIR" "$broken" --out="$SCRATCH/broken-out" > /dev/null 2>&1
        local code=$?
        check "$label is refused" "$([ $code -ne 0 ] && echo yes || echo no)"
        check "$label films nothing" "$([ ! -e "$SCRATCH/broken-out/tiny-camera.gif" ] && echo yes || echo no)"
    done
}
# }}}

# -- {{{ test_fourth_round_words
function test_fourth_round_words() {
    # The third test scene carries every fourth-round word (ground, rolling,
    # becoming, trails, parts, waves, curves, wind, a leading flying camera);
    # it must film into a valid GIF, and a scene resting on a ground it does
    # not have must be refused by the tool itself.
    mkdir -p "$SCRATCH/third"
    luajit "$TOOL" "$DIR" "$DIR/tests/tiny-third.lua" --out="$SCRATCH/third" > /dev/null
    check "the fourth-round scene films without error" "$([ $? -eq 0 ] && echo yes || echo no)"
    check "its GIF holds all 6 frames and loops" \
        "$(luajit "$FACTS" "$SCRATCH/third/tiny-third.gif" | grep -q 'loop=yes frames=6 trailer=yes' && echo yes || echo no)"

    local broken="$SCRATCH/broken-third.lua"
    grep -v '^    ground = GROUND,$' "$DIR/tests/tiny-third.lua" > "$broken"
    rm -f "$SCRATCH/broken-out/tiny-third.gif"
    luajit "$TOOL" "$DIR" "$broken" --out="$SCRATCH/broken-out" > /dev/null 2>&1
    local code=$?
    check "a scene standing on a ground it lacks is refused" "$([ $code -ne 0 ] && echo yes || echo no)"
    check "that refused scene films nothing" "$([ ! -e "$SCRATCH/broken-out/tiny-third.gif" ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_teamwork_and_liquid
function test_teamwork_and_liquid() {
    # Splitting a film's frames across workers must give exactly the film
    # one process gives; and the liquid, worked out from the same recipe and
    # seed, must film to the same bytes every time.
    mkdir -p "$SCRATCH/alone" "$SCRATCH/team" "$SCRATCH/liquid-a" "$SCRATCH/liquid-b"
    luajit "$TOOL" "$DIR" "$DIR/tests/tiny.lua" --out="$SCRATCH/alone" > /dev/null
    luajit "$TOOL" "$DIR" "$DIR/tests/tiny.lua" --out="$SCRATCH/team" --jobs=3 > /dev/null
    check "a film split across three workers is byte-identical to one filmed alone" \
        "$(cmp -s "$SCRATCH/alone/tiny.gif" "$SCRATCH/team/tiny.gif" && echo yes || echo no)"
    luajit "$TOOL" "$DIR" "$DIR/tests/tiny-fluid.lua" --out="$SCRATCH/liquid-a" > /dev/null
    luajit "$TOOL" "$DIR" "$DIR/tests/tiny-fluid.lua" --out="$SCRATCH/liquid-b" --jobs=2 > /dev/null
    check "the liquid films to the same bytes twice (once split across workers)" \
        "$(cmp -s "$SCRATCH/liquid-a/tiny-fluid.gif" "$SCRATCH/liquid-b/tiny-fluid.gif" && echo yes || echo no)"
    check "the liquid's GIF holds all 6 frames and loops" \
        "$(luajit "$FACTS" "$SCRATCH/liquid-a/tiny-fluid.gif" | grep -q 'loop=yes frames=6 trailer=yes' && echo yes || echo no)"
}
# }}}

# -- {{{ test_stills_folder
function test_stills_folder() {
    # --stills= sends the stills to their own folder (the library keeps them
    # in stills/ beside the films), and none is left beside the GIF.
    mkdir -p "$SCRATCH/library"
    luajit "$TOOL" "$DIR" "$DIR/tests/tiny.lua" --out="$SCRATCH/library" --stills="$SCRATCH/library/stills" > /dev/null
    check "--stills= puts the still in its own folder" \
        "$([ -e "$SCRATCH/library/stills/tiny.png" ] && [ -e "$SCRATCH/library/tiny.gif" ] && echo yes || echo no)"
    check "--stills= leaves no still beside the film" "$([ ! -e "$SCRATCH/library/tiny.png" ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_framing
function test_framing() {
    # Scenes that promise to keep their subjects in the picture (`framing`)
    # are walked frame by frame through the painter's own projection.
    local report
    report=$(luajit "$DIR/tests/framing-test.lua" "$DIR")
    echo "$report" | grep -E '^  (ok|FAIL)' | sed 's/^  ok   - /  ok   - framing: /; s/^  FAIL - /  FAIL - framing: /'
    PASS=$((PASS + $(echo "$report" | grep -c '^  ok')))
    FAIL=$((FAIL + $(echo "$report" | grep -c '^  FAIL')))
}
# }}}

# -- {{{ test_choreography
function test_choreography() {
    # Every scene loops without a seam, and each word of the vocabulary does
    # what it says -- asked of the stage manager directly, no pixels.
    local report
    report=$(luajit "$DIR/tests/choreography-test.lua" "$DIR")
    local code=$?
    echo "$report" | grep -E '^  (ok|FAIL)' | sed 's/^  ok   - /  ok   - stage: /; s/^  FAIL - /  FAIL - stage: /'
    PASS=$((PASS + $(echo "$report" | grep -c '^  ok')))
    FAIL=$((FAIL + $(echo "$report" | grep -c '^  FAIL')))
    [ $code -eq 0 ] || [ "$(echo "$report" | grep -c '^  FAIL')" -gt 0 ] || { echo "  FAIL - stage test crashed"; FAIL=$((FAIL + 1)); }
}
# }}}

rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"
echo "readme-gallery"
test_valid_gif
test_deterministic
test_refusals
test_second_round_words
test_broken_camera
test_fourth_round_words
test_teamwork_and_liquid
test_stills_folder
test_framing
test_approved_unchanged
test_choreography
echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
