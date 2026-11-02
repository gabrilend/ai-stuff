#!/bin/bash
# test-history-kernel.sh - proves history-kernel.lua reads a project's first
# commits correctly and never replaces an existing vision document.
#
# In general terms: a scratch repository in a RAM folder holds two project
# folders with a short history each; a stand-in chat model
# (libs/stand-in-model/, no download, no real model) writes the draft from
# the facts, through the same client the tool uses. Exercises issue 051
# (051a).
#
# Usage: test-history-kernel.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/history-kernel.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/history-kernel-test"

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
function commit() {
    git -C "$REPO" add -A
    git -C "$REPO" -c user.name=t -c user.email=t@example.invalid commit -q -m "$1" -m "${2:-}"
}
# }}}

# -- {{{ setup
function setup() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    REPO="$SCRATCH/repo"
    mkdir -p "$REPO/widget/src" "$REPO/other" "$REPO/failing"
    git -C "$REPO" init -q

    printf '# Widget\n\nCounts the words in files.\n' > "$REPO/widget/README.md"
    echo "print(0)" > "$REPO/widget/src/main.lua"
    commit "Start a widget that counts words" "The idea: wc, but friendlier."
    echo "x" > "$REPO/other/thing.txt"
    commit "Unrelated work in another folder"
    echo "all:" > "$REPO/widget/Makefile"
    commit "Add a command line"
    echo "print(1)" >> "$REPO/widget/src/main.lua"
    printf '# Widget\n\nNow a word-count server.\n' > "$REPO/widget/README.md"
    commit "Add JSON output"

    echo "y" > "$REPO/failing/a.txt"
    commit "STAND-IN-FAIL in this project"

    source "$DIR/delta-version/scripts/libs/stand-in-model/stand-in-model.sh"
    stand_in_start "$SCRATCH/model" || { echo "could not start the stand-in model"; exit 1; }
}
# }}}

# -- {{{ test_facts
function test_facts() {
    run "$REPO/widget" --json
    check "--json gives the project's name" "$(has_line "$OUT" '"name":"widget"')"
    check "... its commit count, other folders' commits left out" "$(has_line "$OUT" '"commit_count":3')"
    check "... the first commit's subject" "$(has_line "$OUT" '"subject":"Start a widget that counts words"')"
    check "... the first lines of its message" "$(has_line "$OUT" '"body":"The idea: wc, but friendlier."')"
    check "... the README as first committed, not as it is now" \
        "$(if grep -qF 'Counts the words in files.' <<< "$OUT" && ! grep -qF 'word-count server' <<< "$OUT"; then echo yes; else echo no; fi)"
    check "... the build files it has now" "$(has_line "$OUT" '"Makefile"')"
    check "... and the latest commit" "$(has_line "$OUT" '"subject":"Add JSON output"')"
    check "--json does not ask the model" \
        "$(INFERENCE_CHAT_HOST=127.0.0.1:9 timeout 60 luajit "$TOOL" "$REPO/widget" --json > /dev/null 2>&1 && echo yes || echo no)"

    run "$REPO/widget" --json --commits=2
    check "--commits=2 reads two first commits" "$(same "$(grep -c '"subject"' <<< "$OUT")" 3)"

    run "$SCRATCH" --json
    check "a folder outside git: refused (2)" "$(same "$CODE" 2)"
    mkdir -p "$REPO/empty"
    run "$REPO/empty" --json
    check "a folder no commit touches: refused (1)" "$(same "$CODE" 1)"
    run "$REPO/widget" --commits=0
    check "--commits=0: refused" "$(same "$CODE" 2)"
}
# }}}

# -- {{{ test_draft
function test_draft() {
    run "$REPO/widget"
    check "the draft starts with # Vision" "$(same "$(head -1 <<< "$OUT")" "# Vision")"
    check "... gives the original idea from the first commit" "$(has_line "$OUT" "Start a widget that counts words")"
    check "... and what it grew into from the later ones" "$(has_line "$OUT" "- Add JSON output")"
    check "... and says it is a draft to check" "$(has_line "$OUT" "check it before trusting it")"

    run "$REPO/widget" --write
    check "--write saves notes/vision.md" "$(has_line "$(cat "$REPO/widget/notes/vision.md")" "# Vision")"
    echo "My own vision." > "$REPO/widget/notes/vision.md"
    run "$REPO/widget" --write
    check "--write never replaces an existing vision (1)" "$(same "$CODE" 1)"
    check "... which is left as it was" "$(same "$(cat "$REPO/widget/notes/vision.md")" "My own vision.")"
    run "$REPO/widget" --out="$SCRATCH/draft.md"
    check "--out saves the draft elsewhere" "$(has_line "$(cat "$SCRATCH/draft.md")" "# Vision")"
    run "$REPO/widget" --out="$SCRATCH/draft.md"
    check "--out never replaces a file either" "$(same "$CODE" 1)"
    run "$REPO/widget" --write --out="$SCRATCH/x.md"
    check "--write with --out: refused" "$(same "$CODE" 2)"

    run "$REPO/failing"
    check "a model error: exit 1, said plainly" "$(if [ "$CODE" = 1 ] && grep -qF "asked to fail" <<< "$OUT"; then echo yes; else echo no; fi)"
    INFERENCE_CHAT_HOST=127.0.0.1:9 run "$REPO/widget"
    check "no model reachable: exit 1" "$(same "$CODE" 1)"
}
# }}}

# -- {{{ main
function main() {
    setup
    echo "history-kernel.lua with a stand-in model, scratch in $SCRATCH"
    test_facts
    test_draft
    stand_in_stop
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
