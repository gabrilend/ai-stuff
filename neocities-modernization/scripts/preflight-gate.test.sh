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

# {{{ rankings one poem short stop the gate; the real ones pass
SCRATCH="$DIR/tmp/shared-memory/preflight-gate-test"
mkdir -p "$SCRATCH/cache"
printf '{"poems":[{"id":1,"poem_index":1,"creation_date":"2024-01-01T00:00:00Z"},{"id":2,"poem_index":2,"creation_date":"2024-01-02T00:00:00Z"},{"id":3,"poem_index":3,"creation_date":"2024-01-03T00:00:00Z"}]}' \
    > "$SCRATCH/three-poems.json"
printf '{"metadata":{},"images":{}}' > "$SCRATCH/cache/image-manifest.json"
# Built when there were two poems: poem 3 has no ranking, and poem 1's list
# still names a poem 4 that no longer exists.
printf '{"metadata":{},"rankings":{"1":[2,4],"2":[1]}}' > "$SCRATCH/cache/similarity_rankings_cache.json"
out=$("$GATE" "$DIR" --poems-file "$SCRATCH/three-poems.json" --rankings-dir "$SCRATCH/cache" 2>&1)
check "stale rankings: gate fails" "$?" "1"
check "stale rankings: names the check" \
    "$(printf '%s' "$out" | grep -c 'saved rankings match the poem list')" "1"
check "stale rankings: names the poem with no ranking" \
    "$(printf '%s' "$out" | grep -c 'have no saved ranking (e.g. 3)')" "1"
check "stale rankings: names the neighbour that no longer exists" \
    "$(printf '%s' "$out" | grep -c 'point at numbers the poem list does not have (e.g. 4)')" "1"
"$GATE" "$DIR" --poems-file "$DIR/assets/poems.json" \
    --rankings-dir "$(luajit "$DIR/scripts/cache-dir" "$DIR" --model embeddinggemma-300m)" >/dev/null 2>&1
check "real rankings: gate passes" "$?" "0"
rm -rf "$SCRATCH"
# }}}

# {{{ a malformed thread count is refused, not guessed at
"$GATE" "$DIR" --html-threads many >/dev/null 2>&1
check "non-numeric thread count refused" "$?" "1"
# }}}

echo "passed ${pass}, failed ${fail}"
[ "${fail}" -eq 0 ]
