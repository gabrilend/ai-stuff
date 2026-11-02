#!/bin/bash
# test-claudemd-revise.sh - proves claudemd-revise.lua turns repeated events
# into proposals and changes a CLAUDE.md only on approval, with a backup,
# an audit trail and a safe rollback.
#
# In general terms: a stand-in chat model (libs/stand-in-model/, no download,
# no real model) answers in place of the local llama.cpp server, through the
# same client the tool uses. Events, proposals and a scratch CLAUDE.md all
# live in a RAM folder. Exercises issue 040.
#
# Usage: test-claudemd-revise.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/claudemd-revise.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/claudemd-revise-test"

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
    OUT=$(timeout 60 luajit "$TOOL" --state="$STATE" "$@" 2>&1)
    CODE=$?
}
# }}}

# -- {{{ setup
function setup() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    STATE="$SCRATCH/state"
    TARGET="$SCRATCH/CLAUDE.md"
    printf '# House rules\n\n- Use LuaJIT.\n\n## Testing\n\n- Tests are cheap.\n' > "$TARGET"
    source "$DIR/delta-version/scripts/libs/stand-in-model/stand-in-model.sh"
    stand_in_start "$SCRATCH/model" || { echo "could not start the stand-in model"; exit 1; }
}
# }}}

# -- {{{ test_events
function test_events() {
    run event mood "x"
    check "an unknown event kind is refused" "$(same "$CODE" 2)"
    run event correction
    check "an event with no text is refused" "$(same "$CODE" 2)"
    run event correction "Use vimfolds in every function."
    run event correction "use vimfolds in every function"
    run event correction "Use  vimfolds in every function!"
    run event instruction "Run the tests before committing."
    run events
    check "the same event in different spelling is counted once, three times" \
        "$(has_line "$OUT" "   3  correction  Use vimfolds in every function.")"
    check "a different event is counted apart" "$(has_line "$OUT" "   1  instruction Run the tests")"
}
# }}}

# -- {{{ test_suggest
function test_suggest() {
    run suggest
    check "suggest words the event seen 3 times" "$(has_line "$OUT" "P001  - Use vimfolds in every function.")"
    check "... and leaves the event seen once" "$(lacks_line "$OUT" "Run the tests")"
    check "... exit 0" "$(same "$CODE" 0)"
    run suggest
    check "an event already proposed is not proposed again" "$(has_line "$OUT" "0 proposal(s) filed")"
    run suggest --min=1
    check "--min=1 proposes the rarer event too" "$(has_line "$OUT" "P002  - Run the tests before committing.")"
    check "suggest changes no CLAUDE.md" "$(lacks_line "$(cat "$TARGET")" "vimfolds")"

    run event convention "STAND-IN-FAIL when worded"
    run suggest --min=1
    check "a model error is reported, nothing filed" "$(has_line "$OUT" "the stand-in was asked to fail")"
    check "... exit 1" "$(same "$CODE" 1)"

    INFERENCE_CHAT_HOST=127.0.0.1:9 run suggest --min=1
    check "no model reachable: said plainly" "$(has_line "$OUT" "unreachable")"
}
# }}}

# -- {{{ test_approve
function test_approve() {
    local before
    before=$(cat "$TARGET")
    run list
    check "list shows the pending proposals with their reason" "$(has_line "$OUT" "why: seen 3 times as a correction")"
    run approve P001
    check "approve without --target is refused" "$(same "$CODE" 2)"
    run approve P001 --target="$SCRATCH/missing.md"
    check "approve into a missing file is refused" "$(same "$CODE" 1)"

    run approve P001 --target="$TARGET"
    check "approve adds the guideline" "$(has_line "$(cat "$TARGET")" "- Use vimfolds in every function.")"
    check "... under a Learned conventions section at the end" \
        "$(same "$(tail -3 "$TARGET")" "$(printf '## Learned conventions\n\n- Use vimfolds in every function.')")"
    check "... leaving the rest of the file as it was" "$(has_line "$(cat "$TARGET")" "- Tests are cheap.")"
    check "... after backing the file up" \
        "$(same "$(cat "$STATE"/backups/P001-*.md)" "$before")"
    run approve P001 --target="$TARGET"
    check "approving twice is refused" "$(same "$CODE" 1)"

    run approve P002 --target="$TARGET"
    check "a second approval joins the same section" \
        "$(same "$(grep -c '^## Learned conventions$' "$TARGET")" 1)"
    check "... in order" "$(same "$(tail -1 "$TARGET")" "- Run the tests before committing.")"

    run propose "Use vimfolds in every function"
    run approve P003 --target="$TARGET"
    check "a guideline the file already holds is refused" "$(has_line "$OUT" "already says this")"
    run reject P003 --reason="duplicate"
    check "reject marks it" "$(has_line "$OUT" "P003 rejected")"
    run list
    check "rejected and approved proposals leave the pending list" "$(has_line "$OUT" "No pending proposals.")"
}
# }}}

# -- {{{ test_rollback
function test_rollback() {
    local before_p002
    before_p002=$(cat "$STATE"/backups/P002-*.md)
    run rollback P002 --target="$TARGET"
    check "rollback restores the file as it was before the approval" \
        "$(same "$(cat "$TARGET")" "$before_p002")"
    run rollback P002 --target="$TARGET"
    check "a rolled-back proposal cannot be rolled back again" "$(same "$CODE" 1)"

    echo "- Hand edit." >> "$TARGET"
    run rollback P001 --target="$TARGET"
    check "rollback refuses when the file was edited since" "$(has_line "$OUT" "has changed since P001")"
    check "... and leaves the edit" "$(has_line "$(cat "$TARGET")" "- Hand edit.")"

    run history
    check "the audit trail shows proposals, approvals, rejections and rollbacks" \
        "$(if grep -q proposed <<< "$OUT" && grep -q approved <<< "$OUT" && grep -q rejected <<< "$OUT" && grep -q rolled-back <<< "$OUT"; then echo yes; else echo no; fi)"
}
# }}}

# -- {{{ main
function main() {
    setup
    echo "claudemd-revise.lua with a stand-in model, scratch in $SCRATCH"
    test_events
    test_suggest
    test_approve
    test_rollback
    stand_in_stop
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
