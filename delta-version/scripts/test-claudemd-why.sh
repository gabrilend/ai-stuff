#!/bin/bash
# test-claudemd-why.sh - proves claudemd-why.lua finds the conversations
# behind a guideline, skips the context pack copied into each transcript,
# never changes a transcript, and never replaces a saved record.
#
# In general terms: a scratch monorepo in a RAM folder holds three
# projects' llm-transcripts/ folders written by hand; a stand-in chat model
# (libs/stand-in-model/, no download, no real model) drafts the record
# through the same client the tool uses. Exercises issue 040 (040g).
#
# Usage: test-claudemd-why.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/claudemd-why.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/claudemd-why-test"

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
    OUT=$(timeout 60 luajit "$TOOL" --dir="$M" --state="$STATE" "$@" 2>&1)
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
    M="$SCRATCH/monorepo"
    STATE="$SCRATCH/state"
    mkdir -p "$M/alpha/llm-transcripts" "$M/beta/llm-transcripts" "$M/failing/llm-transcripts" "$STATE"

    # Line 4 is the context pack (a copy of CLAUDE.md): it must not count.
    cat > "$M/alpha/llm-transcripts/oct-01-26.md" <<'EOF'
# Conversation Backup - Full Context Pack

### Global CLAUDE.md
- Use vimfolds in every function.

## Conversation 1: abc

### User Request 1

Please add a parser.

### Assistant Response 1

Added it.

### User Request 2

Wrap every function in vimfolds, please. I fold code in vim, and
without the markers a long file is unreadable.

### Assistant Response 2

Done: every function now has vimfolds.
EOF
    cat > "$M/beta/llm-transcripts/oct-02-26.md" <<'EOF'
## Conversation 1: def

### User Request 1

The vimfolds plugin is slow today.
EOF
    cat > "$M/failing/llm-transcripts/oct-03-26.md" <<'EOF'
## Conversation 1: ghi

### User Request 1

STAND-IN-FAIL: vimfolds around each function.
EOF
    printf 'P001\t2026-10-01\tapproved\tUse vimfolds in every function.\tseen 3 times\tcorrection:x\n' \
        > "$STATE/proposals.tsv"
    sha256sum "$M"/*/llm-transcripts/*.md > "$SCRATCH/sums"

    source "$DIR/delta-version/scripts/libs/stand-in-model/stand-in-model.sh"
    stand_in_start "$SCRATCH/model" || { echo "could not start the stand-in model"; exit 1; }
}
# }}}

# -- {{{ test_evidence
function test_evidence() {
    run "Use vimfolds in every function." --no-model --transcripts="$M/alpha/llm-transcripts" \
        --transcripts="$M/beta/llm-transcripts"
    check "--no-model: exit 0" "$(same "$CODE" 0)"
    check "searches the guideline's key words" "$(has_line "$OUT" "searched for: vimfolds, function.")"
    check "finds the one exchange holding both" "$(has_line "$OUT" "1 of 1 matching exchanges, from 2 transcripts")"
    check "... cited by file and the line that talks about it" \
        "$(has_line "$OUT" "### [1] $M/alpha/llm-transcripts/oct-01-26.md, line 18")"
    check "... quoting the reason given" "$(has_line "$OUT" "> without the markers a long file is unreadable.")"
    check "the context pack's copy is not evidence" "$(lacks_line "$OUT" "> - Use vimfolds in every function.")"
    check "a one-word mention is not evidence" "$(lacks_line "$OUT" "plugin is slow")"
    check "says it is evidence only" "$(has_line "$OUT" "evidence only; check it against the excerpts")"

    run "Use vimfolds in every function." --no-model
    check "by default every */llm-transcripts/ folder is read" "$(has_line "$OUT" "from 3 transcripts")"

    run P001 --no-model --transcripts="$M/alpha/llm-transcripts"
    check "a proposal id is looked up in the state" \
        "$(if grep -qF "# Why: Use vimfolds in every function." <<< "$OUT" && grep -qF "Proposal P001" <<< "$OUT"; then echo yes; else echo no; fi)"
    run P009 --no-model
    check "an unknown proposal id: refused (1)" "$(same "$CODE" 1)"
    run "Prefer tabs over spaces" --no-model
    check "nothing found: said plainly (1)" \
        "$(if [ "$CODE" = 1 ] && grep -qF "No exchange in 3 transcripts" <<< "$OUT"; then echo yes; else echo no; fi)"
    run "x" --transcripts="$SCRATCH/nowhere"
    check "a --transcripts folder that does not exist: refused (1)" "$(same "$CODE" 1)"
    run --no-model
    check "no guideline named: refused (2)" "$(same "$CODE" 2)"
}
# }}}

# -- {{{ test_record
function test_record() {
    run "Use vimfolds in every function." --transcripts="$M/alpha/llm-transcripts"
    check "the model drafts the record from the guideline and excerpts" \
        "$(has_line "$OUT" "stand-in reply: Guideline: Use vimfolds in every function.")"
    check "... followed by the evidence it was given" "$(has_line "$OUT" "## Evidence")"

    run "Use vimfolds in every function." --transcripts="$M/failing/llm-transcripts"
    check "a model error: exit 1, said plainly" \
        "$(if [ "$CODE" = 1 ] && grep -qF "asked to fail" <<< "$OUT"; then echo yes; else echo no; fi)"
    INFERENCE_CHAT_HOST=127.0.0.1:9 run "Use vimfolds in every function." --transcripts="$M/alpha/llm-transcripts"
    check "no model reachable: exit 1" "$(same "$CODE" 1)"

    run P001 --transcripts="$M/alpha/llm-transcripts" --write
    local saved
    saved=$(ls "$STATE"/analysis/P001-*.md 2>/dev/null)
    check "--write saves the record under the state's analysis/" "$(has_line "$(cat "$saved" 2>/dev/null)" "# Why: Use vimfolds")"
    echo "My notes." > "$saved"
    run P001 --transcripts="$M/alpha/llm-transcripts" --write
    check "--write never replaces a record (1)" "$(same "$CODE" 1)"
    check "... which is left as it was" "$(same "$(cat "$saved")" "My notes.")"

    check "no transcript was changed" "$(sha256sum -c --quiet "$SCRATCH/sums" > /dev/null 2>&1 && echo yes || echo no)"
}
# }}}

# -- {{{ main
function main() {
    setup
    echo "claudemd-why.lua with a stand-in model, scratch in $SCRATCH"
    test_evidence
    test_record
    stand_in_stop
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
