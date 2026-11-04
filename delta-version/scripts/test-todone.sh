#!/bin/bash
# test-todone.sh - proves todone.lua finds the components several projects
# each plan to build, matching names that differ only in spelling or by a
# listed synonym, and reading only planned (open) work.
#
# In general terms: a scratch monorepo in a RAM folder holds a few projects
# with issue files and a roadmap; a stand-in chat model
# (libs/stand-in-model/, no download, no real model) names the components it
# finds, through the same client the tool uses. Exercises issue 053
# (053a and 053b's first two tiers).
#
# Usage: test-todone.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/todone.lua"
SYNONYMS="$DIR/delta-version/config/component-synonyms.conf"
SCRATCH="$DIR/delta-version/tmp/shared-memory/todone-test"

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

# -- {{{ same / has_line / lacks_line / matches
function same() { if [ "$1" = "$2" ]; then echo yes; else echo no; fi; }
function has_line() { if grep -qF -- "$2" <<< "$1"; then echo yes; else echo no; fi; }
function lacks_line() { if grep -qF -- "$2" <<< "$1"; then echo no; else echo yes; fi; }
function matches() { if grep -qE -- "$2" <<< "$1"; then echo yes; else echo no; fi; }
# }}}

# -- {{{ run
function run() {
    OUT=$(timeout 60 luajit "$TOOL" --dir="$M" "$@" 2> "$SCRATCH/err")
    CODE=$?
    ERR=$(cat "$SCRATCH/err")
}
# }}}

# -- {{{ issue
function issue() {
    # issue PATH "Title": an issue file with that first line.
    mkdir -p "$(dirname "$1")"
    printf '# %s\n\nDetails.\n' "$2" > "$1"
}
# }}}

# -- {{{ setup
function setup() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    M="$SCRATCH/monorepo"

    issue "$M/alpha/issues/101-pool.md" "Issue 101: Build a Thread-Pool"
    issue "$M/alpha/issues/102-menus.md" "Issue 102: A TUI framework for the menus"
    issue "$M/alpha/issues/completed/103-json.md" "Issue 103: JSON parser"
    issue "$M/beta/issues/phase-2/201-workers.md" "Issue 201: A worker pool for the jobs"
    mkdir -p "$M/beta/docs"
    printf '# Roadmap\n\n## Phase 2: an LLM client\n\nText that is not a heading: threadpool.\n' > "$M/beta/docs/roadmap.md"
    issue "$M/gamma/issues/301-tuning.md" "Issue 301: threadpool tuning"
    issue "$M/gamma/issues/302-json.md" "Issue 302: json parser"
    issue "$M/gamma/issues/moved-303-chat.md" "Issue 303 has moved: chat client"
    issue "$M/delta/issues/401-odd.md" "Issue 401: STAND-IN-FAIL"
    mkdir -p "$M/empty/issues" "$M/noissues/src"

    source "$DIR/delta-version/scripts/libs/stand-in-model/stand-in-model.sh"
    stand_in_start "$SCRATCH/model" || { echo "could not start the stand-in model"; exit 1; }
}
# }}}

# -- {{{ test_usage
function test_usage() {
    run "$M/alpha"
    check "one project: refused (2)" "$(same "$CODE" 2)"
    run "$M/alpha" "$M/beta" --min=0
    check "--min=0: refused (2)" "$(same "$CODE" 2)"
    run --bogus
    check "an unknown option: refused (2)" "$(same "$CODE" 2)"
}
# }}}

# -- {{{ test_matching
function test_matching() {
    run "$M/alpha" "$M/beta" "$M/gamma"
    check "a component three projects plan is reported" \
        "$(matches "$OUT" '^  threadpool +3  alpha, beta, gamma$')"
    check "... spelling ignored (Thread-Pool) and a synonym joined (worker pool)" \
        "$(lacks_line "$OUT" "worker pool")"
    check "a component only one project plans is not reported at --min=2" "$(lacks_line "$OUT" "tui framework")"
    check "completed issues are not planned work (alpha's JSON parser)" "$(lacks_line "$OUT" "json parser")"
    check "exit 0" "$(same "$CODE" 0)"

    run "$M/alpha" "$M/beta" "$M/gamma" --min=1 --each
    check "--min=1 reports single-project components too" "$(matches "$OUT" '^  tui framework +1  alpha$')"
    check "a roadmap heading counts as planned work (beta's LLM client)" "$(matches "$OUT" '^  llm client +1  beta$')"
    check "roadmap text that is not a heading does not" \
        "$(matches "$OUT" '^  threadpool +3  alpha, beta, gamma$')"
    check "moved- pointer files are not planned work (gamma's chat client)" \
        "$(lacks_line "$(grep '^  gamma' <<< "$OUT")" "chat client")"
    check "--each lists what was found per project" \
        "$(matches "$OUT" '^  alpha +thread-pool, tui framework$')"

    run "$M/alpha" "$M/beta" "$M/gamma" --synonyms="$SCRATCH/none.conf"
    check "without the synonym list, worker pool stays apart" "$(matches "$OUT" '^  thread-?pool +2  alpha, gamma$')"

    run "$M/alpha" "$M/beta" "$M/gamma" --json
    check "--json gives the shared components" "$(has_line "$OUT" '"name":"threadpool"')"
    check "... with their projects" "$(has_line "$OUT" '"projects":["alpha","beta","gamma"]')"
}
# }}}

# -- {{{ test_all
function test_all() {
    run --all --each
    check "--all takes every top-level folder with issues/" \
        "$(if grep -q '^  delta' <<< "$OUT" || grep -q 'delta' <<< "$ERR"; then echo yes; else echo no; fi)"
    check "... and not a folder without one" "$(lacks_line "$OUT$ERR" "noissues")"
    check "a project with no planned work is said so" "$(matches "$OUT" '^  empty +no open issues or roadmap$')"
    check "a model failure names the project" "$(has_line "$ERR" "the model failed for delta")"
    check "... the others are still reported" "$(matches "$OUT" '^  threadpool +3')"
    check "... and the exit status is 1" "$(same "$CODE" 1)"

    INFERENCE_CHAT_HOST=127.0.0.1:9 run "$M/alpha" "$M/beta"
    check "no model reachable: exit 1, said plainly" \
        "$(if [ "$CODE" = 1 ] && grep -q unreachable <<< "$ERR"; then echo yes; else echo no; fi)"
}
# }}}

# -- {{{ main
function main() {
    setup
    echo "todone.lua with a stand-in model, scratch in $SCRATCH"
    test_usage
    test_matching
    test_all
    stand_in_stop
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
