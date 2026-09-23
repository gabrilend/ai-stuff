#!/usr/bin/env bash
# preflight-gate.test.sh (Issue 10-069) -- proves the pre-flight gate stops a
# build whose threading library cannot load, lets a good one through, and
# stays out of the way when no selected stage needs a check.
# Run: bash scripts/preflight-gate.test.sh [project-dir]

set -u
DIR="/mnt/mtwo/programming/ai-stuff/neocities-modernization"
if [ -n "${1:-}" ]; then
    DIR="$1"
fi
GATE="$DIR/scripts/preflight-gate"

pass=0; fail=0
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}

# {{{ a threading library that cannot be found stops the gate, and says so
out=$("$GATE" "$DIR" --html-threads 4 --effil-cpath "/nonexistent/?.so" 2>&1)
check "missing library: gate fails" "$?" "1"
check "missing library: names the threading check" \
    "$(printf '%s' "$out" | grep -c 'threading library loads')" "1"
check "missing library: says no stage was started" \
    "$(printf '%s' "$out" | grep -c 'No stage was started')" "1"
# }}}

# {{{ the real library passes
"$GATE" "$DIR" --html-threads 4 >/dev/null 2>&1
check "real library: gate passes" "$?" "0"
# }}}

# {{{ one worker never needs the library, so a broken one is not checked
out=$("$GATE" "$DIR" --html-threads 1 --effil-cpath "/nonexistent/?.so" 2>&1)
check "one worker: gate passes with a broken library path" "$?" "0"
check "one worker: the threading check did not run" \
    "$(printf '%s' "$out" | grep -c 'threading')" "0"
# }}}

# {{{ nothing selected, nothing run
out=$("$GATE" "$DIR" 2>&1)
check "no stages: gate passes" "$?" "0"
check "no stages: prints nothing" "$out" ""
# }}}

# {{{ an undated poem stops the gate; the real poem list passes
SCRATCH="$DIR/tmp/shared-memory/preflight-gate-test"
mkdir -p "$SCRATCH"
printf '{"poems":[{"id":1,"poem_index":1,"category":"notes","content":"no date"}]}' \
    > "$SCRATCH/undated.json"
out=$("$GATE" "$DIR" --poems-file "$SCRATCH/undated.json" 2>&1)
check "undated poem: gate fails" "$?" "1"
check "undated poem: names the date check" \
    "$(printf '%s' "$out" | grep -c 'every poem has a date')" "1"
check "undated poem: names the poem" \
    "$(printf '%s' "$out" | grep -c 'poem 1 (notes')" "1"
"$GATE" "$DIR" --poems-file "$DIR/assets/poems.json" >/dev/null 2>&1
check "real poem list: gate passes" "$?" "0"
rm -rf "$SCRATCH"
# }}}

# {{{ a malformed thread count is refused, not guessed at
"$GATE" "$DIR" --html-threads many >/dev/null 2>&1
check "non-numeric thread count refused" "$?" "1"
# }}}

echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
