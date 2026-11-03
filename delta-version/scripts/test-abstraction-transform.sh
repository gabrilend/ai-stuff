#!/bin/bash
# test-abstraction-transform.sh - proves abstraction-transform.lua rewrites a
# transcript section by section, checks the rewrites when asked, keeps what it
# cannot rewrite word for word under a marker, and never writes over a file.
#
# In general terms: a stand-in chat model (libs/stand-in-model/, no download,
# no real model) answers every rewrite with "stand-in reply: " and the first
# 60 characters of the section, so whether a rewrite passes the checks is
# fixed by how each test section begins. Exercises issue 049b.
#
# Usage: test-abstraction-transform.sh [--dir MONOREPO]   (KEEP=1 keeps the scratch)

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

TOOL="$DIR/delta-version/scripts/abstraction-transform.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/abstraction-transform-test"

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
    # Sets OUT (standard output), ERR (standard error) and CODE.
    OUT=$(timeout 60 luajit "$TOOL" --quiet "$@" 2> "$SCRATCH/err")
    CODE=$?
    ERR=$(cat "$SCRATCH/err")
}
# }}}

# -- {{{ setup
function setup() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH/project/llm-transcripts"
    SCRATCH=$(realpath "$SCRATCH")
    T="$SCRATCH/project/llm-transcripts/talk.md"
    # Exchange 1 opens with input and output, so it passes every check.
    # Exchange 2 is long, so a 60-character answer keeps under a fifth of it.
    # Exchange 3 asks the stand-in to fail. Exchange 4 opens with code.
    {
        printf '# Conversation Summary: talk\n\nGenerated on: a test day\n\n'
        printf '### User Request 1\n\nInput comes from the form and output goes to the dashboard.\n\n'
        printf '### Assistant Response 1\n\nWired the form to the dashboard.\n\n'
        printf '*[2 sections left out at detail level 2]*\n\n'
        printf '### User Request 2\n\nPlease write the parser for the config files.\n\n'
        printf '### Assistant Response 2\n\n'
        for _ in 1 2 3 4 5 6 7 8 9 10; do printf 'The parser reads one line at a time and keeps the key. '; done
        printf '\n\n### User Request 3\n\nSTAND-IN-FAIL on this one, kept as written.\n\n'
        printf '### Assistant Response 3\n\nAnswer three stays word for word.\n\n'
        printf '### User Request 4\n\n```sh\nls -la\n```\n\n### Assistant Response 4\n\nListed it.\n'
    } > "$T"
    source "$DIR/delta-version/scripts/libs/stand-in-model/stand-in-model.sh"
    stand_in_start "$SCRATCH/model" || { echo "could not start the stand-in model"; exit 1; }
}
# }}}

# -- {{{ test_document
function test_document() {
    run "$T" --level=high
    check "one level rewrites and exits 0" "$(same "$CODE" 0)"
    check "the heading names the level and the detail level read from the markers" \
        "$(has_line "$OUT" "# talk - HIGH Abstraction, Detail Level 2")"
    check "the header counts the sections (exchanges, not headings)" "$(has_line "$OUT" "Sections: 4")"
    check "the contents list names an exchange by its request" \
        "$(has_line "$OUT" "1. [Input comes from the form and output goes to the dashboard.](#section-1)")"
    check "each section has an anchor the contents list points at" "$(has_line "$OUT" '<a id="section-2"></a>')"
    check "each section is numbered and titled" \
        "$(has_line "$OUT" "## Section 2: Please write the parser for the config files.")"
    check "a section is the model's rewrite of the whole exchange" \
        "$(has_line "$OUT" "stand-in reply: ### User Request 1")"
    check "transcript-detail's left-out marker follows the section it came after" \
        "$(if awk '/^## Section 1:/{s=1} s&&/left out at detail level 2/{print "found"; exit} /^## Section 2:/{exit}' <<< "$OUT" | grep -q found; then echo yes; else echo no; fi)"
    check "a section the model failed on is kept under a marker with the reason" \
        "$(has_line "$OUT" "*[kept as written: no answer from the model: server error")"
    check "... word for word" "$(has_line "$OUT" "Answer three stays word for word.")"
    check "the summary counts rewritten and kept chunks" \
        "$(has_line "$ERR" "3 chunks rewritten, 0 from the cache, 1 kept as written")"
    check "without --validate, code and a short answer pass" "$(lacks_line "$OUT" "kept as written: a code")"
}
# }}}

# -- {{{ test_validate
function test_validate() {
    run "$T" --level=high --validate --report
    check "--report gives one line per chunk" "$(same "$(wc -l <<< "$OUT" | tr -d ' ')" 4)"
    check "high: a rewrite naming input and output passes" \
        "$(has_line "$OUT" "1.1  high   rewritten")"
    check "high: a rewrite without them is retried, then kept with the reason" \
        "$(has_line "$OUT" "(no inputs and outputs named at high abstraction)")"

    run "$T" --level=medium --validate --report
    check "medium: a rewrite under a fifth of the words is kept" \
        "$(has_line "$OUT" "2.1  medium kept")"
    check "... with that reason" "$(has_line "$OUT" "(under a fifth of the original words)")"
    check "medium: a code block is refused" "$(has_line "$OUT" "(a code block at medium abstraction)")"

    run "$T" --level=low --validate --report
    check "low at detail level 2: a code block is refused" \
        "$(has_line "$OUT" "(a code block at low abstraction, detail level 2)")"
    run "$T" --level=low --validate --report --detail=5
    check "low at detail level 5: a code block is allowed" "$(has_line "$OUT" "4.1  low    rewritten")"
    check "--detail overrides the markers" "$(has_line "$ERR" "detail level 5")"
}
# }}}

# -- {{{ test_cache
function test_cache() {
    local cache="$SCRATCH/cache.tsv" host="$INFERENCE_CHAT_HOST"
    run "$T" --level=high --cache="$cache"
    check "--cache saves each rewrite" "$(same "$(wc -l < "$cache" | tr -d ' ')" 3)"
    INFERENCE_CHAT_HOST=127.0.0.1:1 run "$T" --level=high --cache="$cache"
    check "with the model gone, cached rewrites are reused" \
        "$(has_line "$ERR" "0 chunks rewritten, 3 from the cache, 1 kept as written")"
    check "... and give the same text" "$(has_line "$OUT" "stand-in reply: ### User Request 1")"
    INFERENCE_CHAT_HOST=127.0.0.1:1 run "$T" --level=medium --cache="$cache"
    check "the cache is kept apart by level" "$(has_line "$ERR" "0 from the cache")"
    check "with no model and nothing cached, the exit status is 1" "$(same "$CODE" 1)"
    check "... everything is kept as written" "$(has_line "$ERR" "4 kept as written (4 the model could not be reached)")"
    check "... word for word" "$(has_line "$OUT" "Input comes from the form and output goes to the dashboard.")"
    export INFERENCE_CHAT_HOST="$host"
}
# }}}

# -- {{{ test_compare_and_chunks
function test_compare_and_chunks() {
    run "$T" --compare-levels
    check "--compare-levels names the comparison" \
        "$(has_line "$OUT" "# talk - Abstraction Levels Compared, Detail Level 2")"
    check "... and gives each section at all three levels" \
        "$(if [ "$(grep -c '^### High$' <<< "$OUT")" = 4 ] && [ "$(grep -c '^### Low$' <<< "$OUT")" = 4 ]; then echo yes; else echo no; fi)"

    local other="$SCRATCH/notes.md"
    {
        printf '# Notes\n\n### Short part\n\nA few words.\n\n### Long part\n\n'
        for _ in $(seq 1 9); do
            for _ in $(seq 1 100); do printf 'word '; done
            printf '\n\n'
        done
    } > "$other"
    run "$other" --level=medium --report
    check "a file without exchanges is split at its ### headings" "$(has_line "$OUT" "Short part")"
    check "a long section is cut into chunks of about 800 words" \
        "$(if grep -q '2.1  medium rewritten   703' <<< "$OUT" && grep -q '2.2  medium rewritten   200' <<< "$OUT"; then echo yes; else echo no; fi)"
    check "no markers and no --detail means detail level 5" "$(has_line "$ERR" "detail level 5")"
}
# }}}

# -- {{{ test_writing
function test_writing() {
    run "$T" --level=high --write
    local written="$SCRATCH/project/llm-transcripts/generated/high-abstraction/talk.md"
    check "--write puts it in llm-transcripts/generated/high-abstraction/" "$(if [ -s "$written" ]; then echo yes; else echo no; fi)"
    check "... and says where" "$(has_line "$ERR" "written to $written")"
    echo "hand edit" >> "$written"
    run "$T" --level=high --write
    check "--write never replaces a file" "$(same "$CODE" 2)"
    check "... and leaves it as it was" "$(same "$(tail -1 "$written")" "hand edit")"
    run "$T" --compare-levels --write
    check "--compare-levels --write uses generated/compare-levels/" \
        "$(if [ -s "$SCRATCH/project/llm-transcripts/generated/compare-levels/talk.md" ]; then echo yes; else echo no; fi)"

    cp "$T" "$SCRATCH/loose.md"
    run "$SCRATCH/loose.md" --level=high --write
    check "--write refuses a transcript outside llm-transcripts" "$(same "$CODE" 2)"
    run "$T" --level=high --out="$written"
    check "--out never replaces a file" "$(same "$CODE" 2)"
    run "$T" --level=high --out="$T"
    check "--out refuses the transcript itself" "$(has_line "$ERR" "overwrite the transcript itself")"
    run "$T" --level=high --out="$SCRATCH/out.md"
    check "--out writes a new file" "$(has_line "$(cat "$SCRATCH/out.md")" "## Section 1:")"
}
# }}}

# -- {{{ test_usage
function test_usage() {
    run "$T"
    check "no level is a usage error" "$(same "$CODE" 2)"
    run "$T" --level=sideways
    check "an unknown level is a usage error" "$(same "$CODE" 2)"
    run "$T" --level=high --compare-levels
    check "--level with --compare-levels is a usage error" "$(same "$CODE" 2)"
    printf 'return { high = "Task: abstraction-transform." }\n' > "$SCRATCH/prompts.lua"
    run "$T" --level=high --prompts="$SCRATCH/prompts.lua"
    check "a prompts file missing a level is refused" "$(has_line "$ERR" "has no medium prompt")"
}
# }}}

# -- {{{ test_key_terms
# The key-term check: names in backticks, file names, snake_case, camelCase,
# dotted names and acronyms. Low abstraction must keep half of them; high
# must name none of the code; medium is only counted.
function test_key_terms() {
    local kt="$SCRATCH/terms.md"
    {
        printf '# Terms\n\n### Keeps\n\n`parse_line` reads config.lua and JSON.\n\n'
        printf '### Loses\n\nThis paragraph runs long enough that the stand-in answer stops '
        printf 'well before naming `read_cache`, cache.tsv and HTTP.\n\n'
        printf '### High\n\nInput and output go via `route_request`.\n\n'
        printf '### Plain\n\nInput and output, nothing named here, AI or OK, said plainly.\n\n```\nhidden_name = 1\n```\n'
    } > "$kt"
    run "$kt" --level=low --validate --report
    check "low: a rewrite that keeps the key terms passes" "$(has_line "$OUT" "1.1  low    rewritten")"
    check "... and the report counts them" "$(matches "$OUT" "^  1\.1 .* terms 3/3 +Keeps")"
    check "low: a rewrite that loses them is kept, with the count" \
        "$(has_line "$OUT" "(kept 0 of 3 key terms at low abstraction)")"
    check "names in a fenced code block and two-letter capitals are not key terms" \
        "$(matches "$OUT" "^  4\.1 .* terms 0/0 +Plain")"

    run "$kt" --level=high --validate --report
    check "high: a rewrite that names the code is kept, with the names" \
        "$(has_line "$OUT" "(code names at high abstraction: route_request)")"
    check "high: a rewrite without code names passes" "$(has_line "$OUT" "4.1  high   rewritten")"

    run "$kt" --level=medium --validate --report
    check "medium: lost key terms are counted, not refused" "$(matches "$OUT" "^  2\.1  medium rewritten .* terms 0/3 ")"
    check "the summary gives the key terms the rewrites hold" \
        "$(has_line "$ERR" "the rewrites hold 4 of their 7 key terms")"
}
# }}}

# -- {{{ main
function main() {
    setup
    echo "abstraction-transform.lua with a stand-in model, scratch in $SCRATCH"
    test_document
    test_validate
    test_cache
    test_compare_and_chunks
    test_key_terms
    test_writing
    test_usage
    stand_in_stop
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
