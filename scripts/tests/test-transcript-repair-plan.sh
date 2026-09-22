#!/usr/bin/env bash
# test-transcript-repair-plan.sh - Exercise the archive repair planner over a
# fixture folder, so its judgements can be checked without renaming anything
# real.
#
# The planner's whole job is deciding which piece of evidence to believe about
# each transcript, so each case here supplies a different combination of
# evidence and asserts on the tier it picks and the name it lands on. The
# timezone is pinned so the expectations mean the same thing on any machine.
#
# Run: `bash test-transcript-repair-plan.sh`

set -uo pipefail

# -- {{{ Paths and settings
# Hard-coded default root, overridable by argument, so the test runs from any
# directory (house convention).
DIR="${1:-/home/ritz/programming/ai-stuff/scripts}"
PLANNER="${DIR}/libs/transcript-repair-plan.lua"

# Fixtures live in the RAM tier, per house convention, and the directory is
# ensured rather than assumed because a reboot empties it.
WORK="/dev/shm/transcript-repair-plan-test"
FIXTURE="$WORK/project/llm-transcripts"

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
# The stamp the faulty exporter would have written for a conversation that
# really ended at the given UTC instant. It built the stamp by reading the
# UTC clock fields as though they were local, so the stored value is simply
# that same reading interpreted in local time.
stored_stamp_for() {
   local utc_instant="$1"
   local utc_reading
   utc_reading=$(date -u -d "$utc_instant" '+%Y-%m-%d %H:%M:%S')
   date -d "$utc_reading" '+%s'
}
# }}}

# -- {{{ make_transcript()
make_transcript() {
   local name="$1" conversation_id="$2" stored="$3"
   printf '# Conversation Summary: %s\n\nbody\n' "$conversation_id" > "$FIXTURE/$name"
   touch -d "@$stored" "$FIXTURE/$name"
}
# }}}

# -- {{{ plan_stamp()
# The timestamp the planner wants written onto one file.
plan_stamp() {
   awk -F'\t' -v f="$1" '$2==f {print $5}' "$WORK/plan.tsv"
}
# }}}

# -- {{{ plan_line()
# The planner's decision for one file, as "tier<TAB>dest<TAB>action".
plan_line() {
   awk -F'\t' -v f="$1" '$2==f {print $3"\t"$4"\t"$6}' "$WORK/plan.tsv"
}
# }}}

# -- {{{ build_fixture()
# Five situations, one per kind of evidence the planner has to weigh.
build_fixture() {
   rm -rf "$WORK"
   mkdir -p "$FIXTURE"

   # 1. Its session log still exists, so the planner must not touch it.
   make_transcript "sep-17-26.md" "live-0001" "$(stored_stamp_for '2026-09-17T02:49:33Z')"

   # 2. An evening conversation: held on the 16th locally, misfiled on the
   #    17th because that was the UTC date. History and stamp agree.
   make_transcript "sep-17-26_agent-1.md" "even-0002" "$(stored_stamp_for '2026-09-17T02:49:33Z')"

   # 3. and 4. Two files carrying one identical stamp weeks after their
   #    sessions ended - the signature of a bulk copy. One is in the prompt
   #    history and can be rescued; the other has nothing and must be left.
   local flattened
   flattened=$(stored_stamp_for '2026-01-07T18:13:39Z')
   make_transcript "jan-7-26.md"         "bulk-0003" "$flattened"
   make_transcript "jan-7-26_agent-1.md" "bulk-0004" "$flattened"
   make_transcript "jan-7-26_agent-2.md" "bulk-0005" "$flattened"

   # 5. No history, sound stamp: dated by inverting the stamp alone.
   make_transcript "jun-16-26.md" "solo-0006" "$(stored_stamp_for '2026-06-16T03:20:00Z')"

   printf 'live-0001\n' > "$WORK/logs.tsv"

   # The prompt history. Times are epoch seconds of the first and last prompt.
   {
      printf 'even-0002\t%s\t%s\n' \
         "$(date -u -d '2026-09-16T01:00:00Z' +%s)" "$(date -u -d '2026-09-17T02:45:00Z' +%s)"
      printf 'bulk-0003\t%s\t%s\n' \
         "$(date -u -d '2025-12-21T20:00:00Z' +%s)" "$(date -u -d '2025-12-22T04:00:00Z' +%s)"
      printf 'bulk-0004\t%s\t%s\n' \
         "$(date -u -d '2025-12-26T20:00:00Z' +%s)" "$(date -u -d '2025-12-27T04:00:00Z' +%s)"
   } > "$WORK/history.tsv"
}
# }}}

# -- {{{ run_planner()
run_planner() {
   find "$FIXTURE" -maxdepth 1 -name '*.md' -type f -printf '%T@\t%p\n' \
      | sed 's/\.[0-9]*\t/\t/' \
      | REPAIR_DIR="$DIR" lua "$PLANNER" \
           --logs "$WORK/logs.tsv" --history "$WORK/history.tsv" \
      > "$WORK/plan.tsv"
}
# }}}

build_fixture
run_planner

echo "A transcript whose session log survives is left to the exporter:"
line=$(plan_line "sep-17-26.md")
check "$([ "$(echo "$line" | cut -f1)" = "rebuild" ] && echo true || echo false)" \
   "it is marked as the exporter's to rebuild"
check "$([ "$(echo "$line" | cut -f3)" = "skip" ] && echo true || echo false)" \
   "and no action is planned against it"

echo "An evening conversation moves back to the day it happened:"
line=$(plan_line "sep-17-26_agent-1.md")
check "$([ "$(echo "$line" | cut -f1)" = "history" ] && echo true || echo false)" \
   "dated from the prompt history"
check "$([ "$(echo "$line" | cut -f2)" = "sep-15-26-through-sep-16-26.md" ] && echo true || echo false)" \
   "named for the local 15th-to-16th, not the UTC 16th-to-17th (got: $(echo "$line" | cut -f2))"

echo "A bulk-copy stamp is ignored in favour of the history:"
line=$(plan_line "jan-7-26.md")
check "$([ "$(echo "$line" | cut -f1)" = "history" ] && echo true || echo false)" \
   "a file with prompt history never consults its stamp at all"
check "$([ "$(echo "$line" | cut -f2)" = "dec-21-25.md" ] && echo true || echo false)" \
   "recovers the real December date (got: $(echo "$line" | cut -f2))"

line=$(plan_line "jan-7-26_agent-1.md")
check "$([ "$(echo "$line" | cut -f2)" = "dec-26-25.md" ] && echo true || echo false)" \
   "a second file sharing that stamp gets its own real date (got: $(echo "$line" | cut -f2))"

echo "A file with no evidence at all is reported, not guessed at:"
line=$(plan_line "jan-7-26_agent-2.md")
check "$([ "$(echo "$line" | cut -f1)" = "no-evidence" ] && echo true || echo false)" \
   "sharing a disproved stamp and absent from the history leaves nothing to date it"
check "$([ "$(echo "$line" | cut -f3)" = "skip" ] && echo true || echo false)" \
   "so it is left exactly where it is"

echo "A sound stamp with no history still dates its file:"
line=$(plan_line "jun-16-26.md")
check "$([ "$(echo "$line" | cut -f1)" = "stamp" ] && echo true || echo false)" \
   "dated by inverting the stamp"
check "$([ "$(echo "$line" | cut -f2)" = "jun-15-26.md" ] && echo true || echo false)" \
   "which moves it back to the local evening (got: $(echo "$line" | cut -f2))"

echo "A history-dated file decides the same way every time:"
# Both its endpoints come from epoch counts, so nothing about the answer
# depends on the file's current state. Re-planning after the first answer has
# been written onto the file must produce that same answer again - which is
# what makes these files safe to reconsider without any note to guard them.
first_pass=$(plan_line "sep-17-26_agent-1.md")
touch -d "@$(date -u -d '2026-09-17T02:45:00Z' +%s)" "$FIXTURE/sep-17-26_agent-1.md"
run_planner
second_pass=$(plan_line "sep-17-26_agent-1.md")
check "$([ "$first_pass" = "$second_pass" ] && echo true || echo false)" \
   "the verdict survives its own result being applied to the file"

echo "A stamp-dated file does NOT, which is why the note exists:"
stamp_first=$(plan_stamp "jun-16-26.md")
touch -d "@$stamp_first" "$FIXTURE/jun-16-26.md"
run_planner
stamp_second=$(plan_stamp "jun-16-26.md")
check "$([ "$stamp_first" != "$stamp_second" ] && echo true || echo false)" \
   "re-planning it after applying its own answer gives a different one (${stamp_first} then ${stamp_second})"

echo "No planned name runs backwards:"
backwards=0
while IFS= read -r base; do
   [ -n "$base" ] || continue
   start_token="${base%%-through-*}"
   end_token="${base##*-through-}"
   start_epoch=$(date -d "$(echo "$start_token" | awk -F- '{print $1" "$2" 20"$3}')" +%s)
   end_epoch=$(date -d "$(echo "$end_token" | awk -F- '{print $1" "$2" 20"$3}')" +%s)
   [ "$start_epoch" -gt "$end_epoch" ] && backwards=$((backwards + 1))
done < <(awk -F'\t' '$4 ~ /-through-/ {print $4}' "$WORK/plan.tsv" | sed 's/_agent-[0-9]*//; s/\.md$//')
check "$([ "$backwards" -eq 0 ] && echo true || echo false)" \
   "every span reads start-before-end ($backwards backwards)"

echo ""
echo "passed: $PASSED  failed: $FAILED"
[ "$FAILED" -eq 0 ] || exit 1
