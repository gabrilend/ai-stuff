#!/bin/bash
# test-roadmap-from-history.sh - proves roadmap-from-history.lua finds a
# project's phases where its history breaks, names them through the model
# or plainly without one, and never replaces an existing roadmap.
#
# In general terms: a scratch repository in a RAM folder holds a project
# whose commits are dated by hand into three stretches (a quiet month, then
# a release, between them); a stand-in chat model (libs/stand-in-model/, no
# download, no real model) names the phases through the same client the
# tool uses. Exercises issue 051 (051b).
#
# Usage: test-roadmap-from-history.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/roadmap-from-history.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/roadmap-from-history-test"

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
    OUT=$(timeout 60 luajit "$TOOL" "$@" 2>&1)
    CODE=$?
}
# }}}

# -- {{{ commit
# commit DATE SUBJECT: commits everything with that author and commit date.
function commit() {
    git -C "$REPO" add -A
    GIT_AUTHOR_DATE="$1T12:00:00Z" GIT_COMMITTER_DATE="$1T12:00:00Z" \
        git -C "$REPO" -c user.name=t -c user.email=t@example.invalid commit -q -m "$2"
}
# }}}

# -- {{{ setup
# widget: three commits in src/, a month's quiet, three in src/ ending in a
# release, then three in a new docs/ folder. Two breaks, so three phases.
function setup() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    REPO="$SCRATCH/repo"
    mkdir -p "$REPO/widget/src" "$REPO/widget/docs" "$REPO/other" "$REPO/failing"
    git -C "$REPO" init -q

    echo 1 > "$REPO/widget/src/a.lua";  commit 2026-01-01 "Start the parser"
    echo 1 > "$REPO/other/x.txt";       commit 2026-01-02 "Unrelated work elsewhere"
    echo 2 >> "$REPO/widget/src/a.lua"; commit 2026-01-02 "Parse numbers"
    echo 3 >> "$REPO/widget/src/a.lua"; commit 2026-01-03 "Parse strings"
    echo 1 > "$REPO/widget/src/b.lua";  commit 2026-02-10 "Add the evaluator"
    echo 2 >> "$REPO/widget/src/b.lua"; commit 2026-02-11 "Evaluate calls"
    echo 3 >> "$REPO/widget/src/b.lua"; commit 2026-02-12 "Release v1.0"
    echo 1 > "$REPO/widget/docs/guide.md"; commit 2026-02-13 "Write the guide"
    echo 2 >> "$REPO/widget/docs/guide.md"; commit 2026-02-14 "Guide: examples"
    echo 3 >> "$REPO/widget/docs/guide.md"; commit 2026-02-15 "Guide: index"

    echo 1 > "$REPO/failing/a.txt"; commit 2026-03-01 "STAND-IN-FAIL begins here"
    echo 2 >> "$REPO/failing/a.txt"; commit 2026-03-02 "More"

    source "$DIR/delta-version/scripts/libs/stand-in-model/stand-in-model.sh"
    stand_in_start "$SCRATCH/model" || { echo "could not start the stand-in model"; exit 1; }
}
# }}}

# -- {{{ test_phases
function test_phases() {
    run "$REPO/widget" --json --no-model
    check "--json --no-model: exit 0" "$(same "$CODE" 0)"
    check "reads only the commits touching the folder" "$(has_line "$OUT" '"commit_count":9')"
    check "finds three phases" "$(same "$(grep -c '"number":' <<< "$OUT")" 3)"
    check "phase 2 starts after the quiet month" "$(has_line "$OUT" '"from":"2026-02-10"')"
    check "... and says why" "$(has_line "$OUT" '38 days after the commit before')"
    check "phase 3 starts after the release" "$(has_line "$OUT" '"from":"2026-02-13"')"
    check "... and says why, with the new folder too" \
        "$(if grep -qF 'follows a version or release' <<< "$OUT" && grep -qF 'first work in docs/' <<< "$OUT"; then echo yes; else echo no; fi)"
    check "plain names come from the folders changed" "$(has_line "$OUT" '"name":"Work in docs/"')"
    check "plain descriptions give the dates, folders and first and last subjects" \
        "$(has_line "$OUT" '"description":"3 commits from 2026-02-10 to 2026-02-12, most changes in src/, from \"Add the evaluator\" to \"Release v1.0\"."')"
    check "every phase says it was named by heuristics" "$(same "$(grep -c '"named_by":"heuristics"' <<< "$OUT")" 4)"
    check "--no-model does not ask the model" \
        "$(INFERENCE_CHAT_HOST=127.0.0.1:9 timeout 60 luajit "$TOOL" "$REPO/widget" --no-model > /dev/null 2>&1 && echo yes || echo no)"

    run "$REPO/widget" --json --no-model --phases=2
    check "--phases=2 keeps the strongest break only" "$(same "$(grep -c '"number":' <<< "$OUT")" 2)"
    check "... the release into a new folder (it outscores the quiet month)" \
        "$(if grep -qF '"from":"2026-02-13"' <<< "$OUT" && ! grep -qF '"from":"2026-02-10"' <<< "$OUT"; then echo yes; else echo no; fi)"
    run "$REPO/widget" --json --no-model --gap-days=60
    check "--gap-days=60: the month no longer counts" "$(lacks_line "$OUT" '"from":"2026-02-10"')"
    check "... the release still does" "$(has_line "$OUT" '"from":"2026-02-13"')"

    run "$SCRATCH" --no-model
    check "a folder outside git: refused (2)" "$(same "$CODE" 2)"
    mkdir -p "$REPO/empty"
    run "$REPO/empty" --no-model
    check "a folder no commit touches: refused (1)" "$(same "$CODE" 1)"
    run "$REPO/widget" --phases=0
    check "--phases=0: refused (2)" "$(same "$CODE" 2)"
    run "$REPO/widget" --write --json
    check "--write with --json: refused (2)" "$(same "$CODE" 2)"
}
# }}}

# -- {{{ test_naming
function test_naming() {
    run "$REPO/widget"
    check "Markdown starts with the project's title" "$(same "$(head -1 <<< "$OUT")" "# Roadmap: widget")"
    check "the model names each phase from its own commits" \
        "$(has_line "$OUT" "## Phase 2: stand-in reply: phase 2 of 3: 2026-02-10 to 2026-02-12")"
    check "... and describes it from the rest of its answer" "$(lacks_line "$OUT" 'from "Add the evaluator" to "Release v1.0"')"
    check "... lists the largest changes" "$(has_line "$OUT" "- Evaluate calls")"
    check "... and says it is a draft named by the model" "$(has_line "$OUT" "phases named by model; check it before trusting it")"

    INFERENCE_CHAT_HOST=127.0.0.1:9 run "$REPO/widget"
    check "no model reachable: still a roadmap (0)" "$(same "$CODE" 0)"
    check "... with plain names" "$(has_line "$OUT" "## Phase 3: Work in docs/")"
    check "... and says so" "$(has_line "$OUT" "the phases keep plain names")"

    run "$REPO/failing" --json
    check "the model failing for a phase: still a roadmap (0)" "$(same "$CODE" 0)"
    check "... that phase keeps its plain name, said plainly" "$(has_line "$OUT" "asked to fail")"
}
# }}}

# -- {{{ test_saving
function test_saving() {
    run "$REPO/widget" --write --no-model
    check "--write saves docs/roadmap.md" "$(has_line "$(cat "$REPO/widget/docs/roadmap.md" 2>/dev/null)" "# Roadmap: widget")"
    check "... and docs/roadmap.json" "$(has_line "$(cat "$REPO/widget/docs/roadmap.json" 2>/dev/null)" '"roadmap":"roadmap-from-history v1"')"
    rm -f "$REPO/widget/docs/roadmap.json"
    echo "My own roadmap." > "$REPO/widget/docs/roadmap.md"
    run "$REPO/widget" --write --no-model
    check "--write never replaces an existing roadmap (1)" "$(same "$CODE" 1)"
    check "... which is left as it was" "$(same "$(cat "$REPO/widget/docs/roadmap.md")" "My own roadmap.")"
    check "... and the missing half is not written either" "$(if [ -e "$REPO/widget/docs/roadmap.json" ]; then echo no; else echo yes; fi)"
    run "$REPO/widget" --json --no-model --out="$SCRATCH/roadmap.json"
    check "--out with --json saves JSON elsewhere" "$(has_line "$(cat "$SCRATCH/roadmap.json")" '"phases":')"
    run "$REPO/widget" --no-model --out="$SCRATCH/roadmap.json"
    check "--out never replaces a file either (1)" "$(same "$CODE" 1)"
    run "$REPO/widget" --write --out="$SCRATCH/x.md"
    check "--write with --out: refused (2)" "$(same "$CODE" 2)"
}
# }}}

# -- {{{ main
function main() {
    setup
    echo "roadmap-from-history.lua with a stand-in model, scratch in $SCRATCH"
    test_phases
    test_naming
    test_saving
    stand_in_stop
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
