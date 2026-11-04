#!/bin/bash
# test-transcript-detail.sh - proves transcript-detail.lua keeps the right
# sections at each detail level, word for word, and never hides a section
# the model could not class.
#
# In general terms: a stand-in chat model (libs/stand-in-model/, no download,
# no real model) classes each section by a fixed rule, through the same
# client the tool uses. A small transcript with one section of each class is
# filtered at every level. Exercises issue 049 (049a).
#
# Usage: test-transcript-detail.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/transcript-detail.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/transcript-detail-test"

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

# -- {{{ same / has_line / lacks_line
function same() { if [ "$1" = "$2" ]; then echo yes; else echo no; fi; }
function has_line() { if grep -qF -- "$2" <<< "$1"; then echo yes; else echo no; fi; }
function lacks_line() { if grep -qF -- "$2" <<< "$1"; then echo no; else echo yes; fi; }
# }}}

# -- {{{ run
function run() {
    # Sets OUT (standard output), ERR (the summary line) and CODE.
    OUT=$(timeout 60 luajit "$TOOL" "$@" 2> "$SCRATCH/err")
    CODE=$?
    ERR=$(cat "$SCRATCH/err")
}
# }}}

# -- {{{ setup
function setup() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    T="$SCRATCH/transcript.md"
    cat > "$T" <<'EOF'
# Conversation Summary: test

Generated on: a test day

### User Request 1

hi there

### Assistant Response 1

We decided to use a dispatch table for the commands.

### Why a table

A heading inside a response stays part of it.

### User Request 2

Let me try running it again, it still fails.

### Assistant Response 2

The parser is implemented and handles nested brackets.

### User Request 3

Why tables? Because Lua tables are hashed.
EOF
    source "$DIR/delta-version/scripts/libs/stand-in-model/stand-in-model.sh"
    stand_in_start "$SCRATCH/model" || { echo "could not start the stand-in model"; exit 1; }
}
# }}}

# -- {{{ test_usage
function test_usage() {
    run "$T"
    check "no --detail: refused" "$(same "$CODE" 2)"
    run "$T" --detail=6
    check "--detail=6: refused" "$(same "$CODE" 2)"
    run "$T" --detail=1 --out="$T"
    check "--out naming the transcript itself: refused" "$(same "$CODE" 2)"
    run "$SCRATCH/none.md" --detail=1
    check "a missing transcript: refused" "$(same "$CODE" 2)"
}
# }}}

# -- {{{ test_levels
function test_levels() {
    run "$T" --detail=5
    check "level 5 is the transcript unchanged" "$(same "$OUT" "$(cat "$T")")"
    check "... without asking the model" "$(has_line "$ERR" "0 asked of the model")"

    run "$T" --detail=1 --report
    check "--report gives each section's class" \
        "$(has_line "$OUT" "  2  ESSENTIAL")"
    check "... NOISE for a greeting" "$(has_line "$OUT" "  1  NOISE")"

    run "$T" --detail=1
    check "level 1 keeps the decision, word for word" \
        "$(has_line "$OUT" "We decided to use a dispatch table for the commands.")"
    check "... and drops the milestone" "$(lacks_line "$OUT" "parser is implemented")"
    check "... keeps the title" "$(has_line "$OUT" "# Conversation Summary: test")"
    check "... and marks where sections were left out" \
        "$(has_line "$OUT" "*[3 sections left out at detail level 1]*")"
    check "level 1 keeps 1 of 5 sections" "$(has_line "$ERR" "level 1 keeps 1 of 5 sections")"
    check "a ### heading inside a response stays with it" "$(has_line "$OUT" "A heading inside a response stays part of it.")"

    run "$T" --detail=2
    check "level 2 adds the milestone" "$(has_line "$OUT" "parser is implemented")"
    run "$T" --detail=3
    check "level 3 adds the explanation" "$(has_line "$OUT" "Because Lua tables are hashed.")"
    check "... but not the retry" "$(lacks_line "$OUT" "Let me try")"
    run "$T" --detail=4
    check "level 4 adds the retry" "$(has_line "$OUT" "Let me try running it again")"
    check "... but never the greeting" "$(lacks_line "$OUT" "hi there")"

    run "$T" --detail=2 --out="$SCRATCH/out.md"
    check "--out writes the result to the file" "$(has_line "$(cat "$SCRATCH/out.md")" "parser is implemented")"
}
# }}}

# -- {{{ test_classes
function test_classes() {
    local classes="$SCRATCH/classes.tsv"
    run "$T" --detail=1 --classes="$classes"
    check "--classes: the first run asks the model for every section" "$(has_line "$ERR" "5 asked of the model")"
    run "$T" --detail=3 --classes="$classes"
    check "... a second level reuses them all" "$(has_line "$ERR" "0 asked of the model")"
    sed -i 's/hi there/hi there, we decided nothing yet/' "$T"
    run "$T" --detail=1 --classes="$classes"
    check "... and asks again only for the section that changed" "$(has_line "$ERR" "1 asked of the model")"
    check "... which is classed afresh" "$(has_line "$OUT" "we decided nothing yet")"
}
# }}}

# -- {{{ test_failures
function test_failures() {
    printf '\n### Assistant Response 9\n\nSTAND-IN-FAIL here\n' >> "$T"
    run "$T" --detail=1
    check "a section the model cannot class is kept" "$(has_line "$OUT" "STAND-IN-FAIL here")"
    check "... and counted as unclassed" "$(has_line "$ERR" "1 unclassed")"
    check "... and the run still succeeds" "$(same "$CODE" 0)"

    INFERENCE_CHAT_HOST=127.0.0.1:9 run "$T" --detail=1
    check "no model reachable: exit 1" "$(same "$CODE" 1)"
    check "... with everything kept rather than hidden" "$(has_line "$OUT" "Let me try running it again")"
    check "... and the reason given" "$(has_line "$ERR" "unreachable")"
}
# }}}

# -- {{{ main
function main() {
    setup
    echo "transcript-detail.lua with a stand-in model, scratch in $SCRATCH"
    test_usage
    test_levels
    test_classes
    test_failures
    stand_in_stop
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
