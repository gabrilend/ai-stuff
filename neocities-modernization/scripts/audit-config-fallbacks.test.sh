#!/usr/bin/env bash
# audit-config-fallbacks.test.sh -- the fallback checker finds what it should,
# and this project has none left.
#
# Builds a small git repository in RAM with one Lua file holding a fallback
# value, an empty-section fallback, a declared optional one and a plain
# comment, and checks the checker reports each as what it is. Then runs it on
# this project: a new `setting or literal` anywhere fails the test run, so the
# owner's rule (defaults live only in config.lua, Issue 10-071) is kept by
# the tests instead of by memory.
#
# Usage:  scripts/audit-config-fallbacks.test.sh [DIR]
DIR="${1:-/mnt/mtwo/programming/ai-stuff/neocities-modernization}"
TOOL="$DIR/scripts/audit-config-fallbacks"
SCRATCH="$DIR/tmp/shared-memory/audit-config-fallbacks-test"
passed=0
failed=0
# {{{ check
check() {
    if [ "$2" = 1 ]; then
        passed=$((passed + 1)); echo "  ok   $1"
    else
        failed=$((failed + 1)); echo "  FAIL $1 -- $3"
    fi
}
# }}}

rm -rf "$SCRATCH"
mkdir -p "$SCRATCH/src"
cat > "$SCRATCH/src/sample.lua" <<'LUA'
local size = config.pagination.size or 5
local layout = config.layout or {}
-- optional: absent means no stop words
local stop = config.word_cloud.stop_words or {}
-- a comment that mentions config.x or 3 is not code
local plain = some_table.value or 7
LUA
git -C "$SCRATCH" init -q
git -C "$SCRATCH" add src/sample.lua

report=$("$TOOL" "$SCRATCH" --declared)
status=$?
check "a fallback value is reported as a value" \
    "$(echo "$report" | grep -c 'value     config.pagination.size or 5')" "$report"
check "an empty-section fallback is reported as a section" \
    "$(echo "$report" | grep -c 'section   config.layout or {}')" "$report"
check "a fallback with an optional: comment is listed as declared" \
    "$(echo "$report" | grep -c 'declared  config.word_cloud.stop_words or {}')" "$report"
check "a comment is not code" \
    "$([ "$(echo "$report" | grep -c 'config.x or 3')" = 0 ] && echo 1)" "$report"
check "a table that is not settings is left alone" \
    "$([ "$(echo "$report" | grep -c 'some_table')" = 0 ] && echo 1)" "$report"
check "the totals count each kind" \
    "$(echo "$report" | grep -c '^1 fallback values, 1 absent sections treated as empty; 1 declared optional')" "$report"
check "undeclared fallbacks fail the check" "$([ "$status" = 1 ] && echo 1)" "exit $status"

project=$("$TOOL" "$DIR")
pstatus=$?
check "this project has no undeclared fallback" "$([ "$pstatus" = 0 ] && echo 1)" "$project"

rm -rf "$SCRATCH"
echo
echo "passed $passed, failed $failed"
[ "$failed" = 0 ]
