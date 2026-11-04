#!/usr/bin/env bash
# find-in-transcripts.test.sh -- the phrase finder finds a phrase split across
# a line break, ignores case and extra spaces, names the right line, and says
# when a phrase is not there.
#
# Usage:  scripts/find-in-transcripts.test.sh [--dir PATH]

# The project folder: --dir PATH, or the path below; a stray word on the
# command line stops the script (libs/project-dir.sh, Issue 10-076).
source "$(dirname "$(readlink -f "$0")")/../libs/project-dir.sh"
project_dir_read "/mnt/mtwo/programming/ai-stuff/neocities-modernization" "" "$@"
SCRATCH="$DIR/tmp/shared-memory/find-in-transcripts-test"
rm -rf "$SCRATCH"
mkdir -p "$SCRATCH/llm-transcripts"
printf 'first line\nwe want to prune it down, lower the cognitive\nload required to understand\n\nlast   line\n' > "$SCRATCH/llm-transcripts/a.md"
passed=0
failed=0
check() { if [ "$2" = 1 ]; then passed=$((passed + 1)); else failed=$((failed + 1)); echo "  FAIL - $1: $3"; fi; }

out="$("$DIR/scripts/find-in-transcripts" --dir "$SCRATCH" --phrase "lower the cognitive load" --context 0)"
check "a phrase split across a line break is found" "$([ $? -eq 0 ] && echo 1 || echo 0)" "$out"
check "the find names the line it starts on" "$(printf '%s' "$out" | grep -q 'a.md:2' && echo 1 || echo 0)" "$out"
out="$("$DIR/scripts/find-in-transcripts" --dir "$SCRATCH" --phrase "LAST LINE" --context 0)"
check "case and runs of spaces are ignored" "$(printf '%s' "$out" | grep -q 'a.md:5' && echo 1 || echo 0)" "$out"
"$DIR/scripts/find-in-transcripts" --dir "$SCRATCH" --phrase "not in there" > /dev/null 2>&1
check "a phrase not there exits 1" "$([ $? -eq 1 ] && echo 1 || echo 0)" ""

rm -rf "$SCRATCH"
echo "passed $passed, failed $failed"
[ "$failed" -eq 0 ]
