#!/bin/bash
# test-summarize-transcript.sh - proves summarize-transcript.lua slices a
# transcript only between turns, reduces the slice summaries to one, and
# turns that into a one-sentence title, a slug and a paragraph.
#
# In general terms: a stand-in chat model (libs/stand-in-model/, no download,
# no real model) answers in place of the local llama.cpp server, through the
# same client the tool uses. Its /tokenize counts one token per word, so a
# small --context forces many slices and several levels of merging on a short
# transcript. Every file lives in a RAM folder. Exercises issue 056 (056b).
#
# Usage: test-summarize-transcript.sh [--dir MONOREPO]   (KEEP=1 keeps the folder)

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/summarize-transcript.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/summarize-transcript-test"
SEPARATOR="--------------------------------------------------------------------------------"

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
    OUT=$(timeout 120 luajit "$TOOL" "$@" 2>&1)
    CODE=$?
}
# }}}

# -- {{{ field
function field() {
    # One "name: value" line of the plain record in $OUT.
    sed -n "s/^$1: //p" <<< "$OUT" | head -1
}
# }}}

# -- {{{ write_transcript
function write_transcript() {
    # FILE, number of exchanges, the request text, the answer's word count.
    local file="$1" exchanges="$2" request="$3" words="$4" i j answer
    answer=$(for ((j = 1; j <= words; j++)); do printf 'word%d ' "$j"; done)
    {
        echo "# Conversation Summary: conv-$exchanges"
        echo ""
        echo "Generated on: 2026-11-02 12:00:00"
        echo ""
        echo "$SEPARATOR"
        for ((i = 1; i <= exchanges; i++)); do
            printf '\n### User Request %d\n\n%s %d\n\n%s\n\n### Assistant Response %d\n\n%s\n\n%s\n' \
                "$i" "$request" "$i" "$SEPARATOR" "$i" "$answer" "$SEPARATOR"
        done
    } > "$file"
}
# }}}

# -- {{{ setup
function setup() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    write_transcript "$SCRATCH/short.md" 2 "Build the parser with care" 10
    write_transcript "$SCRATCH/long.md" 12 "Build the parser part" 30
    source "$DIR/delta-version/scripts/libs/stand-in-model/stand-in-model.sh"
    stand_in_start "$SCRATCH/model" || { echo "could not start the stand-in model"; exit 1; }
}
# }}}

# -- {{{ test_one_slice
function test_one_slice() {
    local before
    before=$(md5sum < "$SCRATCH/short.md")
    run "$SCRATCH/short.md" --quiet
    check "a short transcript is summarised (exit 0)" "$(same "$CODE" 0)"
    check "the record opens with its version line" "$(same "$(head -1 <<< "$OUT")" "transcript-summary v1")"
    check "the conversation id comes from the header" "$(same "$(field conversation)" "conv-2")"
    check "one slice is enough, so there is no reduce level" \
        "$(same "$(field slices) $(field levels)" "1 0")"
    check "the summary is the slice's summary" \
        "$(has_line "$OUT" "Slice of 2 request(s), opening with: Build the parser with care 1.")"
    check "the title is one sentence (the model's second sentence is dropped)" \
        "$(same "$(field title)" "Worked on Build the parser with care 1.")"
    check "the slug is the title in lowercase words" \
        "$(same "$(field slug)" "worked-on-build-the-parser-with-care-1")"
    check "the blurb is one paragraph under its heading" \
        "$(same "$(sed -n '/^## Blurb$/{n;p}' <<< "$OUT" | cut -c1-14)" "This session: ")"
    check "the transcript itself is not changed" "$(same "$(md5sum < "$SCRATCH/short.md")" "$before")"
}
# }}}

# -- {{{ test_slices_and_levels
function test_slices_and_levels() {
    # 12 exchanges of about 45 tokens each; 160 tokens a slice holds 3
    # exchanges, so 4 slices, merged in one level.
    run "$SCRATCH/long.md" --context=200 --reserve=20 --overhead=20 --plan
    check "the plan shows 4 slices of 3 exchanges" "$(same "$(grep -c '^slice .*: 3 piece(s)' <<< "$OUT")" 4)"
    check "every slice starts on a user request" "$(same "$(grep -c 'from "### User Request' <<< "$OUT")" 4)"
    check "and its last piece is a whole exchange too, so no request is read apart from its answer" \
        "$(same "$(grep -c 'to "### User Request' <<< "$OUT")" 4)"
    run "$SCRATCH/long.md" --context=200 --reserve=20 --overhead=20
    check "four slices merge in one level" "$(same "$(field slices) $(field levels)" "4 1")"
    check "the merge level is logged with its fan-in" "$(has_line "$OUT" "reduce level 1: 4 -> 1")"
    check "the final summary is the merge of the four" "$(has_line "$OUT" "Merged 4 parts, first: ")"
    # 50 tokens a slice: one exchange each, so 12 slices, then merges of
    # four summaries at a time (about 12 tokens each) until one is left.
    run "$SCRATCH/long.md" --context=90 --reserve=20 --overhead=20
    check "a tighter budget gives one slice an exchange" "$(same "$(field slices)" 12)"
    check "... and needs more than one reduce level" "$([ "$(field levels)" -ge 2 ] && echo yes || echo no)"
    check "the first level merges groups that fit (four summaries each)" "$(has_line "$OUT" "reduce level 1: 12 -> 3")"
    check "and the last level ends at one" "$(grep -q "reduce level $(field levels): [0-9]* -> 1\$" <<< "$OUT" && echo yes || echo no)"
}
# }}}

# -- {{{ test_oversized_turn
function test_oversized_turn() {
    write_transcript "$SCRATCH/big.md" 1 "Read this long answer" 300
    run "$SCRATCH/big.md" --context=200 --reserve=20 --overhead=20
    check "an exchange bigger than a slice is cut between lines and still summarised" \
        "$(same "$CODE" 0)"
    check "... and the cut is reported" "$(has_line "$OUT" "1 exchange(s) bigger than a slice were cut between lines")"
}
# }}}

# -- {{{ test_no_progress
function test_no_progress() {
    # 20 tokens a slice: each summary is about 12 tokens, so no two fit
    # together and merging could never shrink the pile.
    run "$SCRATCH/long.md" --context=60 --reserve=20 --overhead=20
    check "summaries that cannot shrink stop the run (exit 1)" "$(same "$CODE" 1)"
    check "... with the reason and what to change" "$(has_line "$OUT" "raise --context or lower --reserve")"
}
# }}}

# -- {{{ test_model_answers
function test_model_answers() {
    write_transcript "$SCRATCH/think.md" 1 "STAND-IN-THINK Tidy the config loader" 5
    run "$SCRATCH/think.md" --quiet
    check "a <think> block is dropped from every answer" "$(lacks_line "$OUT" "working it out")"
    check "... and the answer after it is kept" "$(has_line "$(field title)" "Worked on STAND-IN-THINK Tidy")"
    write_transcript "$SCRATCH/fail.md" 1 "STAND-IN-FAIL please" 5
    run "$SCRATCH/fail.md" --quiet
    check "a model error stops the run (exit 1)" "$(same "$CODE" 1)"
    check "... and names the step" "$(has_line "$OUT" "slice 1 of 1:")"
    write_transcript "$SCRATCH/slug.md" 1 "Supercalifragilistic extraordinarily-long-hyphenated-component-names everywhere-across-the-whole-tree today" 5
    run "$SCRATCH/slug.md" --quiet
    local slug
    slug=$(field slug)
    check "a long slug is cut to 60 characters at most" "$([ "${#slug}" -le 60 ] && echo yes || echo no)"
    check "... at a word boundary" "$([[ "$slug" != *- && "$slug" == worked-on-supercalifragilistic-* ]] && echo yes || echo no)"
}
# }}}

# -- {{{ test_outputs
function test_outputs() {
    run "$SCRATCH/short.md" --quiet --out="$SCRATCH/short.summary"
    check "--out writes the record to the file" \
        "$(same "$(head -1 "$SCRATCH/short.summary")" "transcript-summary v1")"
    check "... and nothing to standard output" "$(same "$OUT" "")"
    run "$SCRATCH/short.md" --quiet --json
    check "--json gives the same fields as JSON" "$(has_line "$OUT" '"slug":"worked-on-build-the-parser-with-care-1"')"
    printf 'First paragraph about the build.\n\nSecond paragraph about the tests.\n' > "$SCRATCH/plain.md"
    run "$SCRATCH/plain.md" --quiet
    check "a file with no exchange headings is summarised by paragraphs" "$(same "$CODE" 0)"
}
# }}}

# -- {{{ test_usage_and_reachability
function test_usage_and_reachability() {
    run
    check "no transcript is a usage error (exit 2)" "$(same "$CODE" 2)"
    run "$SCRATCH/missing.md"
    check "an unreadable transcript is exit 2" "$(same "$CODE" 2)"
    : > "$SCRATCH/empty.md"
    run "$SCRATCH/empty.md"
    check "an empty transcript is exit 2" "$(same "$CODE" 2)"
    run "$SCRATCH/short.md" --context=30 --reserve=10 --overhead=10
    check "a budget too small for a slice is exit 2" "$(same "$CODE" 2)"
    run "$SCRATCH/short.md" --context=lots
    check "a non-numeric budget is exit 2" "$(same "$CODE" 2)"
    OUT=$(INFERENCE_CHAT_HOST=127.0.0.1:1 timeout 60 luajit "$TOOL" "$SCRATCH/short.md" 2>&1)
    CODE=$?
    check "an unreachable model is exit 1" "$(same "$CODE" 1)"
    check "... with how to start it" "$(has_line "$OUT" "start-llamacpp-server.sh")"
}
# }}}

setup
echo "summarize-transcript"
test_one_slice
test_slices_and_levels
test_oversized_turn
test_no_progress
test_model_answers
test_outputs
test_usage_and_reachability
stand_in_stop
[ "${KEEP:-}" ] || rm -rf "${SCRATCH:?}"
echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
