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

# -- {{{ test_stand_in
# The stand-in must answer in the real server's shapes, or the shared client
# reads it as a broken server.
function test_stand_in() {
    local client="$DIR/delta-version/scripts/libs/llama-chat-client.lua" out
    out=$(timeout 30 luajit "$client" --ping 2>&1)
    check "the shared client finds the stand-in reachable" "$(same "$?" 0)"
    out=$(timeout 30 luajit "$client" --tokens "one two three" 2>&1)
    check "the shared client reads a token count from the stand-in" \
        "$(if [[ "$out" =~ ^[0-9]+$ ]] && [ "$out" -ge 3 ]; then echo yes; else echo no; fi)"
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

# -- {{{ test_audit
# Issue 040d: querying the trail, a guideline's provenance, what an
# approval changed, a summary, and the integrity checks.
function test_audit() {
    run history --id=P002
    check "history --id: one proposal's rows" "$(same "$(wc -l <<< "$OUT")" 3)"
    run history --action=rejected
    check "history --action: one action's rows" \
        "$(if [ "$(wc -l <<< "$OUT")" = 1 ] && grep -qF "P003" <<< "$OUT"; then echo yes; else echo no; fi)"
    run history --since=2099-01-01
    check "history --since a later date: none, said so" "$(has_line "$OUT" "No history matches.")"
    run history --since=yesterday
    check "--since that is not a date: refused (2)" "$(same "$CODE" 2)"

    run show P001
    check "show: the guideline and its status" "$(has_line "$OUT" "P001  approved")"
    check "... the three events behind it" "$(has_line "$OUT" "events behind it (3):")"
    check "... and its timeline" \
        "$(if grep -qE '^  .*proposed' <<< "$OUT" && grep -qE '^  .*approved' <<< "$OUT"; then echo yes; else echo no; fi)"
    run show P003
    check "show: a direct proposal says so" "$(has_line "$OUT" "filed directly")"
    run show P009
    check "show: an unknown id is refused (1)" "$(same "$CODE" 1)"

    run diff P001
    check "diff: what the approval added" "$(has_line "$OUT" "+- Use vimfolds in every function.")"
    check "... checked against the checksum taken then (0)" "$(same "$CODE" 0)"
    check "... and nothing left behind" "$(same "$(ls -A "$STATE/backups" | grep -c '^\.diff')" 0)"
    run diff P003
    check "diff: a proposal never approved is refused (1)" "$(same "$CODE" 1)"

    run report
    check "report: events by kind" "$(has_line "$OUT" "events     5 (convention 1, correction 3, instruction 1)")"
    check "... proposals by status" "$(has_line "$OUT" "proposals  3 (approved 1, rejected 1, rolled-back 1)")"
    check "... and actions" "$(has_line "$OUT" "actions    7")"
    run report --since=2099-01-01
    check "report --since a later date: nothing counted" "$(has_line "$OUT" "events     0")"

    run verify
    check "verify: a sound trail passes (0)" "$(same "$CODE" 0)"
    check "... and notes a target edited since its approval" "$(has_line "$OUT" "has been edited since it was approved")"

    local good="$STATE"
    STATE="$SCRATCH/broken-state"
    cp -r "$good" "$STATE"
    sed -i "s|$good/|$STATE/|g" "$STATE/audit.tsv"
    rm -f "$STATE"/backups/P001-*.md
    printf '2000-01-01 00:00:00\tapproved\tP009\t-\tbackup x after 00\n' >> "$STATE/audit.tsv"
    sed -i 's/^P003\t\([^\t]*\)\trejected/P003\t\1\tpending/' "$STATE/proposals.tsv"
    run verify
    check "verify: problems found (1)" "$(same "$CODE" 1)"
    check "... a missing backup" "$(has_line "$OUT" "is missing")"
    check "... a row naming no proposal" "$(has_line "$OUT" "names P009, which is not a proposal")"
    check "... a row out of date order" "$(has_line "$OUT" "dated before the line above it")"
    check "... a status that disagrees with the trail" "$(has_line "$OUT" "P003: its status is pending, but its last action was rejected")"
    STATE="$good"
}
# }}}

# -- {{{ test_prune
# Issue 040d, backup rotation: the newest N backups stay, and so does any a
# rollback still needs; nothing goes without --yes, and what goes is on the
# audit trail.
function test_prune() {
    local p001 p002
    p001=$(ls "$STATE"/backups/P001-*.md)
    p002=$(ls "$STATE"/backups/P002-*.md)
    run prune
    check "prune: under the default 100, nothing to prune" "$(has_line "$OUT" "Nothing to prune: 2 backups")"
    run prune --keep=0
    check "prune without --yes only shows what would go" \
        "$(if grep -qF "would remove  $(basename "$p002")" <<< "$OUT" && [ -f "$p002" ]; then echo yes; else echo no; fi)"
    check "... and keeps the backup a rollback needs (P001 is approved)" \
        "$(has_line "$OUT" "1 older kept for rollback")"
    touch "$STATE/backups/P003-20000101-000000.md" "$STATE/backups/notes.md"
    run prune --keep=1 --yes
    check "prune --yes removes the backups beyond the newest N, oldest first by the date in the name" \
        "$(if [ ! -f "$STATE/backups/P003-20000101-000000.md" ] && [ -f "$p002" ] && [ -f "$p001" ]; then echo yes; else echo no; fi)"
    check "... and says what it kept" "$(has_line "$OUT" "1 backup removed (newest 1 kept, 1 older kept for rollback).")"
    check "... and leaves files not named as backups alone" "$(if [ -f "$STATE/backups/notes.md" ]; then echo yes; else echo no; fi)"
    run prune --keep=0 --yes
    check "prune --keep=0 removes every backup a rollback does not need" \
        "$(if [ ! -f "$p002" ] && [ -f "$p001" ]; then echo yes; else echo no; fi)"
    run history --action=pruned
    check "each removal is on the audit trail" \
        "$(if [ "$(wc -l <<< "$OUT")" = 2 ] && grep -qF "P002" <<< "$OUT"; then echo yes; else echo no; fi)"
    run diff P002
    check "diff of a pruned backup says it was pruned (1)" \
        "$(if [ "$CODE" = 1 ] && grep -qF "was pruned on" <<< "$OUT"; then echo yes; else echo no; fi)"
    run verify
    check "verify: a pruned backup is not a problem" "$(same "$CODE" 0)"
    run prune --keep=0 --yes
    check "prune never removes the backup a rollback needs" \
        "$(if [ -f "$p001" ] && grep -qF "Nothing to prune" <<< "$OUT"; then echo yes; else echo no; fi)"
    run prune --keep=some
    check "prune --keep takes a whole number (2)" "$(same "$CODE" 2)"
}
# }}}

# -- {{{ main
function main() {
    setup
    echo "claudemd-revise.lua with a stand-in model, scratch in $SCRATCH"
    test_stand_in
    test_events
    test_suggest
    test_approve
    test_rollback
    test_audit
    test_prune
    stand_in_stop
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
