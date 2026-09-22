#!/usr/bin/env bash
# test-transcript-repair-apply.sh - Exercise the half of the repair tool that
# actually moves files, over a fixture tree.
#
# The planner had tests from the start; this half did not, and a fault in it
# reached a real run - an array expansion that aborted the tool after it had
# parked a folder's files under temporary names and before it had moved them
# to their real ones. Nothing was lost, because the two-pass rename keeps the
# contents intact under a predictable name, but the archive was left
# mid-step. These cases cover that whole sequence: the renames landing, the
# timestamps being written, the temporary names not surviving, and the
# recovery path that undoes an interrupted run.
#
# Run: `bash test-transcript-repair-apply.sh`

set -uo pipefail

# -- {{{ Paths and settings
# Hard-coded default root, overridable by argument, so the test runs from any
# directory (house convention).
DIR="${1:-/home/ritz/programming/ai-stuff/scripts}"
TOOL="${DIR}/repair-transcript-timezone"

# Fixtures live in the RAM tier, per house convention, ensured not assumed.
ROOT="/dev/shm/transcript-repair-apply-test"
PROJECT="$ROOT/tree/project"
FIXTURE="$PROJECT/llm-transcripts"

export TZ="America/Los_Angeles"

PASSED=0
FAILED=0
# }}}

# -- {{{ check()
check() {
   local condition="$1" description="$2"
   if [ "$condition" = true ]; then
      echo "  ok   - $description"
      PASSED=$((PASSED + 1))
   else
      echo "  FAIL - $description"
      FAILED=$((FAILED + 1))
   fi
}
# }}}

# -- {{{ stored_stamp_for()
# The timestamp the faulty exporter would have left for a conversation that
# really ended at the given UTC instant: the UTC reading, taken as local.
stored_stamp_for() {
   local utc_instant="$1" utc_reading
   utc_reading=$(date -u -d "$utc_instant" '+%Y-%m-%d %H:%M:%S')
   date -d "$utc_reading" '+%s'
}
# }}}

# -- {{{ make_transcript()
make_transcript() {
   local name="$1" conversation_id="$2" stored="$3"
   printf '# Conversation Summary: %s\n\nbody of %s\n' \
      "$conversation_id" "$conversation_id" > "$FIXTURE/$name"
   touch -d "@$stored" "$FIXTURE/$name"
}
# }}}

# -- {{{ build_fixture()
# Two evening conversations on consecutive days. Both slide back one day, so
# the first wants the name the second is giving up - the chain that a single
# rename cannot see, and that the two-pass move has to survive.
build_fixture() {
   rm -rf "$ROOT"
   mkdir -p "$FIXTURE" "$ROOT/sessions"

   make_transcript "sep-17-26.md" "conv-later"   "$(stored_stamp_for '2026-09-17T02:49:33Z')"
   make_transcript "sep-16-26.md" "conv-earlier" "$(stored_stamp_for '2026-09-16T03:10:00Z')"

   : > "$ROOT/empty-history.jsonl"
}
# }}}

# -- {{{ run_tool()
run_tool() {
   TRANSCRIPT_SEARCH_ROOTS="$ROOT/tree" \
   CLAUDE_SESSIONS_ROOT="$ROOT/sessions" \
   PROMPT_HISTORY="$ROOT/empty-history.jsonl" \
   WORK="$ROOT/work" \
      "$TOOL" --dir "$DIR" "$@" > "$ROOT/output.txt" 2> "$ROOT/errors.txt"
   printf '%s' "$?"
}
# }}}

# -- {{{ mtime_of()
mtime_of() { stat -c %Y "$1" 2>/dev/null || printf 'missing'; }
# }}}

build_fixture

echo "The tool reports before it writes:"
status=$(run_tool)
check "$([ "$status" = "0" ] && echo true || echo false)" \
   "a dry run exits cleanly (status $status)"
check "$([ -f "$FIXTURE/sep-17-26.md" ] && echo true || echo false)" \
   "and changes nothing on disk"

echo "Writing moves both files back a day:"
status=$(run_tool --write)
check "$([ "$status" = "0" ] && echo true || echo false)" \
   "the write run exits cleanly (status $status)"
check "$([ -f "$FIXTURE/sep-16-26.md" ] && echo true || echo false)" \
   "the later conversation takes the 16th"
check "$([ -f "$FIXTURE/sep-15-26.md" ] && echo true || echo false)" \
   "the earlier one takes the 15th"
check "$([ ! -f "$FIXTURE/sep-17-26.md" ] && echo true || echo false)" \
   "and nothing is left on the 17th"

echo "The name a neighbour gave up is reused, not suffixed:"
check "$([ ! -e "$FIXTURE/sep-16-26_agent-1.md" ] && echo true || echo false)" \
   "no file is pushed to _agent-1 by a file that was itself leaving"

echo "Contents follow their names:"
check "$(grep -q 'conv-later' "$FIXTURE/sep-16-26.md" 2>/dev/null && echo true || echo false)" \
   "the 16th holds the later conversation"
check "$(grep -q 'conv-earlier' "$FIXTURE/sep-15-26.md" 2>/dev/null && echo true || echo false)" \
   "the 15th holds the earlier one"

echo "Timestamps are corrected to the true instant:"
check "$([ "$(mtime_of "$FIXTURE/sep-16-26.md")" = "$(date -u -d '2026-09-17T02:49:33Z' +%s)" ] && echo true || echo false)" \
   "the later file carries the real instant of its last message"
check "$([ "$(mtime_of "$FIXTURE/sep-15-26.md")" = "$(date -u -d '2026-09-16T03:10:00Z' +%s)" ] && echo true || echo false)" \
   "so does the earlier one"

echo "No working files are left behind:"
check "$([ -z "$(find "$FIXTURE" -name '.repair-tmp-*')" ] && echo true || echo false)" \
   "nothing remains parked under a temporary name"

echo "Running again changes nothing:"
before=$(find "$FIXTURE" -type f -printf '%f %T@\n' | sort)
run_tool --write > /dev/null
after=$(find "$FIXTURE" -type f -printf '%f %T@\n' | sort)
check "$([ "$before" = "$after" ] && echo true || echo false)" \
   "a second write run is a no-op"

echo "An interrupted run can be undone:"
# Reproduce the exact state the fault left behind: files parked, not moved.
mv "$FIXTURE/sep-16-26.md" "$FIXTURE/.repair-tmp-sep-16-26.md"
mv "$FIXTURE/sep-15-26.md" "$FIXTURE/.repair-tmp-sep-15-26.md"
run_tool --recover > /dev/null
check "$([ -f "$FIXTURE/sep-16-26.md" ] && [ -f "$FIXTURE/sep-15-26.md" ] && echo true || echo false)" \
   "recovery puts parked files back under their own names"
check "$([ -z "$(find "$FIXTURE" -name '.repair-tmp-*')" ] && echo true || echo false)" \
   "and leaves no parked files behind"
check "$([ "$(mtime_of "$FIXTURE/sep-16-26.md")" = "$(date -u -d '2026-09-17T02:49:33Z' +%s)" ] && echo true || echo false)" \
   "recovery preserves the timestamp, because a move never touched it"

echo ""
echo "passed: $PASSED  failed: $FAILED"
[ "$FAILED" -eq 0 ] || exit 1
