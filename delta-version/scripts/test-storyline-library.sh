#!/bin/bash
# test-storyline-library.sh - proves the storyline library keeps its promises.
#
# In general terms: this runs the builder for real, then independently
# re-counts what SHOULD be on the shelf and checks the two agree; verifies
# every link resolves; verifies alphabetical order is chronological order;
# verifies a re-run converges to the identical shelf; and verifies the
# builder refuses to destroy a non-symlink file placed in its directory.
# Exercises the success criteria of issue 057.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

BUILDER="$DIR/delta-version/scripts/build-storyline-library.sh"
LIBRARY="$DIR/delta-version/library/storyline"

PASS=0
FAIL=0

# -- {{{ check
function check() {
    # One line per assertion; failures keep going so a run reports everything.
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

# -- {{{ test_builder_runs
function test_builder_runs() {
    # Exit 0 (clean) and 2 (built-with-exclusions) are both legitimate
    # outcomes on a living corpus; 1 means nothing was built at all.
    DIR="$DIR" "$BUILDER" > /dev/null 2> /dev/null
    local code=$?
    [ "$code" = 0 ] || [ "$code" = 2 ]
    check "builder completes (exit $code)" "$([ "$code" = 0 ] || [ "$code" = 2 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_all_links_resolve
function test_all_links_resolve() {
    local broken=0 link
    for link in "$LIBRARY"/*.md; do
        [ -L "$link" ] || continue
        [ -e "$link" ] || broken=$((broken + 1))
    done
    check "every symlink resolves (broken: $broken)" "$([ "$broken" = 0 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_count_matches_independent_recount
function test_count_matches_independent_recount() {
    # Recount from first principles, deliberately NOT via the builder's code
    # path: header test by hand, date test via the shared rulebook alone.
    source "$DIR/scripts/libs/transcript-discovery.sh"
    local expected=0 f first
    for f in "$DIR"/*/llm-transcripts/*.md; do
        [ -f "$f" ] || continue
        IFS= read -r first < "$f" || continue
        case "$first" in "# Conversation Summary: "*) ;; *) continue ;; esac
        transcript_basename_start_ymd "$(basename "$f")" > /dev/null || continue
        expected=$((expected + 1))
    done
    local actual
    actual=$(find "$LIBRARY" -maxdepth 1 -type l | wc -l)
    check "shelf count ($actual) equals independent recount ($expected)" \
        "$([ "$actual" = "$expected" ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_alphabetical_is_chronological
function test_alphabetical_is_chronological() {
    # Every name must begin with YYYY-MM-DD_; since ISO dates compare as
    # strings, valid prefixes alone guarantee the listing is a timeline.
    local bad=0 link name
    for link in "$LIBRARY"/*.md; do
        [ -L "$link" ] || continue
        name="$(basename "$link")"
        [[ "$name" =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}_ ]] || bad=$((bad + 1))
    done
    check "every name carries an ISO date prefix (violations: $bad)" \
        "$([ "$bad" = 0 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_span_uses_start_date
function test_span_uses_start_date() {
    # A "-through-" span must shelve under its START date. Find one real span
    # link and confirm; a corpus with no spans skips (vacuously true).
    source "$DIR/scripts/libs/transcript-discovery.sh"
    local link name prefix derived found=no ok=yes
    for link in "$LIBRARY"/*-through-*.md; do
        [ -L "$link" ] || continue
        found=yes
        name="$(basename "$link")"
        prefix="${name%%_*}"
        derived="$(transcript_basename_start_ymd "${name#*_*_}")"
        [ "$prefix" = "$derived" ] || ok=no
    done
    check "span links shelve under their start date (any spans: $found)" "$ok"
}
# }}}

# -- {{{ test_rerun_converges
function test_rerun_converges() {
    local before after
    before="$(find "$LIBRARY" -maxdepth 1 -type l -printf '%f -> %l\n' | sort)"
    DIR="$DIR" "$BUILDER" > /dev/null 2> /dev/null
    after="$(find "$LIBRARY" -maxdepth 1 -type l -printf '%f -> %l\n' | sort)"
    check "second run produces the identical shelf" \
        "$([ "$before" = "$after" ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_refuses_to_delete_regular_files
function test_refuses_to_delete_regular_files() {
    # Plant a decoy regular file; the builder must hard-fail (exit 1) and the
    # decoy must survive. Then clean up and rebuild the shelf for real.
    local decoy="$LIBRARY/decoy-not-a-symlink.md"
    echo "do not delete me" > "$decoy"
    DIR="$DIR" "$BUILDER" > /dev/null 2> /dev/null
    local code=$?
    local survived=no
    [ -f "$decoy" ] && survived=yes
    rm -f "$decoy"
    DIR="$DIR" "$BUILDER" > /dev/null 2> /dev/null
    check "builder refuses a non-symlink intruder (exit $code, decoy survived: $survived)" \
        "$([ "$code" = 1 ] && [ "$survived" = yes ] && echo yes || echo no)"
}
# }}}

echo "storyline library test suite"
test_builder_runs
test_all_links_resolve
test_count_matches_independent_recount
test_alphabetical_is_chronological
test_span_uses_start_date
test_rerun_converges
test_refuses_to_delete_regular_files
echo ""
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" = 0 ] || exit 1
exit 0
