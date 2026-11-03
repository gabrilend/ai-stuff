#!/bin/bash
# test-issues-from-history.sh - proves issues-from-history.lua groups a
# project's commits into issues, follows a roadmap when there is one, and
# never writes over anything or beside a project's own issues.
#
# In general terms: a scratch repository in a RAM folder holds a project
# with commits dated by hand into three phases; a stand-in chat model
# (libs/stand-in-model/, no download, no real model) titles the issues
# through the same client the tool uses. Exercises issue 051 (051c).
#
# Usage: test-issues-from-history.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/issues-from-history.lua"
ROADMAP="$DIR/delta-version/scripts/roadmap-from-history.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/issues-from-history-test"

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

# -- {{{ issue_has
# issue_has ID TEXT: yes when issue ID's entry in the JSON in $OUT holds TEXT.
function issue_has() {
    if tr -d '\n' <<< "$OUT" | tr -s ' ' | grep -o "\"id\":\"$1\"[^}]*" | grep -qF -- "$2"; then
        echo yes
    else
        echo no
    fi
}
# }}}

# -- {{{ run
function run() {
    OUT=$(timeout 60 luajit "$TOOL" "$@" 2>&1)
    CODE=$?
}
# }}}

# -- {{{ commit
# commit DATE SUBJECT [BODY]: commits everything with that date.
function commit() {
    git -C "$REPO" add -A
    GIT_AUTHOR_DATE="$1T12:00:00Z" GIT_COMMITTER_DATE="$1T12:00:00Z" \
        git -C "$REPO" -c user.name=t -c user.email=t@example.invalid commit -q -m "$2" -m "${3:-}"
}
# }}}

# -- {{{ setup
# widget: three parser commits; a month's quiet; three evaluator commits
# ending in a release; then a guide (two days, a week's pause, a third
# day) and a test. Phases: 1, 2, 3. Issues: 101, 201, 301, 302, 303.
function setup() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    REPO="$SCRATCH/repo"
    W="$REPO/widget"
    mkdir -p "$W/src" "$W/docs" "$W/tests" "$REPO/failing"
    git -C "$REPO" init -q

    echo 1 > "$W/src/a.lua";  commit 2026-01-01 "Start the parser" "Numbers first, strings later."
    echo 2 >> "$W/src/a.lua"; commit 2026-01-02 "Parse numbers"
    echo 3 >> "$W/src/a.lua"; commit 2026-01-03 "Fix the number parser"
    echo 1 > "$W/src/b.lua";  commit 2026-02-10 "Add the evaluator"
    echo 2 >> "$W/src/b.lua"; commit 2026-02-11 "Evaluate calls"
    echo 3 >> "$W/src/b.lua"; commit 2026-02-12 "Release v1.0"
    echo 1 > "$W/docs/guide.md";  commit 2026-02-13 "Write the guide"
    echo 2 >> "$W/docs/guide.md"; commit 2026-02-14 "Guide: examples"
    echo 3 >> "$W/docs/guide.md"; commit 2026-02-20 "Guide: index"
    echo 1 > "$W/tests/t.lua";    commit 2026-02-21 "Test the parser"

    echo 1 > "$REPO/failing/a.txt"; commit 2026-03-01 "STAND-IN-FAIL begins here"
    echo 2 >> "$REPO/failing/a.txt"; commit 2026-03-02 "More"

    source "$DIR/delta-version/scripts/libs/stand-in-model/stand-in-model.sh"
    stand_in_start "$SCRATCH/model" || { echo "could not start the stand-in model"; exit 1; }
}
# }}}

# -- {{{ test_plan
function test_plan() {
    run "$W" --no-model
    check "the plan: exit 0" "$(same "$CODE" 0)"
    check "... five issues from ten commits in three phases" "$(has_line "$OUT" "5 issues from 10 commits in 3 phases")"
    check "... and nothing written" "$(if [ -e "$W/issues" ] || [ -e "$W/docs/issue-mapping.json" ]; then echo no; else echo yes; fi)"

    run "$W" --no-model --json
    check "--json gives the mapping" "$(has_line "$OUT" '"mapping":"issues-from-history v1"')"
    check "commits in a row in one folder are one issue" \
        "$(has_line "$(tr -d ' \n' <<< "$OUT")" '"id":"101","file":"101-start-the-parser.md","phase":1')"
    check "... typed by most of its commits (feature over one fix)" "$(issue_has 101 '"type":"feature"')"
    check "a week's pause starts a new issue in the same phase" "$(has_line "$OUT" '"id":"302"')"
    check "... a new folder too, typed from its subject" "$(issue_has 303 '"type":"test"')"
    check "a guide written in .md files is docs" "$(issue_has 301 '"type":"docs"')"
    check "each issue lists its commits" "$(same "$(grep -o '"[0-9a-f]\{7\}"' <<< "$OUT" | wc -l)" 10)"
    check "without a model, titled by the largest commit" "$(same "$(grep -c '"named_by":"commits"' <<< "$OUT")" 5)"

    run "$SCRATCH" --no-model
    check "a folder outside git: refused (2)" "$(same "$CODE" 2)"
    run "$W" --roadmap="$SCRATCH/nothing.json" --no-model
    check "a --roadmap that does not exist: refused (1)" "$(same "$CODE" 1)"
    run "$W" --write --out="$SCRATCH/x"
    check "--write with --out: refused (2)" "$(same "$CODE" 2)"
}
# }}}

# -- {{{ test_roadmap
function test_roadmap() {
    timeout 60 luajit "$ROADMAP" "$W" --json --no-model --out="$SCRATCH/roadmap.json" 2>/dev/null
    run "$W" --no-model --roadmap="$SCRATCH/roadmap.json" --json
    check "a roadmap's phases are followed" "$(same "$(grep -c '"phase":3' <<< "$OUT")" 3)"

    sed 's/"Work in docs\/ and tests\/"/"Writing it down"/' "$SCRATCH/roadmap.json" > "$SCRATCH/named.json"
    run "$W" --no-model --roadmap="$SCRATCH/named.json" --out="$SCRATCH/named"
    check "... and their names" "$(has_line "$(cat "$SCRATCH"/named/301-*.md)" "**Phase**: 3 - Writing it down")"

    sed 's/"first":"[0-9a-f]*"/"first":"0000000"/' "$SCRATCH/roadmap.json" > "$SCRATCH/broken.json"
    run "$W" --no-model --roadmap="$SCRATCH/broken.json"
    check "a roadmap that does not match the history: refused (1)" "$(same "$CODE" 1)"

    echo 4 >> "$W/tests/t.lua"; commit 2026-02-22 "Test strings"
    run "$W" --no-model --roadmap="$SCRATCH/roadmap.json"
    check "commits newer than the roadmap: left out, said so" "$(has_line "$OUT" "1 commit is newer than")"
    git -C "$REPO" reset -q --hard HEAD~1
}
# }}}

# -- {{{ test_model
function test_model() {
    run "$W" --json
    check "the model titles each issue" "$(has_line "$OUT" '"title":"stand-in reply: - Start the parser"')"
    check "... and says so" "$(same "$(grep -c '"named_by":"model"' <<< "$OUT")" 5)"
    run "$W" --out="$SCRATCH/modelled"
    check "... its other lines become the issue's intent" \
        "$(has_line "$(cat "$SCRATCH"/modelled/101-*.md)" "project: widget phase 1")"

    INFERENCE_CHAT_HOST=127.0.0.1:9 run "$W"
    check "no model reachable: still a plan (0), said so" \
        "$(if [ "$CODE" = 0 ] && grep -qF "titled by its largest commit" <<< "$OUT"; then echo yes; else echo no; fi)"
    run "$REPO/failing" --json
    check "the model failing for an issue: it keeps its commit's subject" \
        "$(if [ "$CODE" = 0 ] && grep -qF '"title":"STAND-IN-FAIL begins here"' <<< "$OUT" && grep -qF "asked to fail" <<< "$OUT"; then echo yes; else echo no; fi)"
}
# }}}

# -- {{{ test_writing
function test_writing() {
    run "$W" --no-model --write
    check "--write: exit 0" "$(same "$CODE" 0)"
    check "... completed issues in issues/completed/" "$(same "$(ls "$W/issues/completed" | wc -l)" 5)"
    check "... and the mapping in docs/" "$(has_line "$(cat "$W/docs/issue-mapping.json" 2>/dev/null)" '"id":"303"')"
    local text
    text=$(cat "$W"/issues/completed/101-*.md)
    check "an issue says it is completed" "$(has_line "$text" "**Status**: Completed")"
    check "... gives its commits with their message bodies" "$(has_line "$text" "Start the parser. Numbers first, strings later.")"
    check "... its files" "$(has_line "$text" '- `src/a.lua`')"
    check "... and that it is a draft to check" "$(has_line "$text" "Check it before trusting it.")"
    check "the validator finds no clashing ids" \
        "$(lacks_line "$(luajit "$DIR/scripts/validate-issues" "$W" 2>&1)" "duplicate")"

    cp "$W/docs/issue-mapping.json" "$SCRATCH/mapping-before"
    run "$W" --no-model --write
    check "--write into a project that has issues: refused (1)" "$(same "$CODE" 1)"
    check "... nothing changed" "$(same "$(cat "$W/docs/issue-mapping.json")" "$(cat "$SCRATCH/mapping-before")")"

    rm -rf "$W/issues"
    run "$W" --no-model --write
    check "--write never replaces a file, checked before writing any (1)" \
        "$(if [ "$CODE" = 1 ] && [ ! -e "$W/issues" ]; then echo yes; else echo no; fi)"
    run "$W" --no-model --out="$SCRATCH/named"
    check "--out into a folder that is not empty: refused (1)" "$(same "$CODE" 1)"
}
# }}}

# -- {{{ main
function main() {
    setup
    echo "issues-from-history.lua with a stand-in model, scratch in $SCRATCH"
    test_plan
    test_roadmap
    test_model
    test_writing
    stand_in_stop
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
