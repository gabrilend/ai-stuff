#!/usr/bin/env bash
# stage-timing.test.sh (Issue 10-051) -- exercises scripts/stage-timing.sh against
# a throwaway temp file. Run: bash scripts/stage-timing.test.sh
#
# Pins the behaviours that matter: human-readable durations, the ring buffer
# evicting the oldest past the cap, the mean/count, and -- the load-bearing rule
# -- that a FAILED stage records nothing while a successful one does.

set -u
DIR_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export STAGE_TIMINGS_FILE="$(mktemp)"
# shellcheck source=/dev/null
source "${DIR_HERE}/scripts/stage-timing.sh"

pass=0; fail=0
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}

# {{{ format_seconds across the unit boundaries
check "45s"      "$(stage_timing_format_seconds 45)"     "45s"
check "12m 30s"  "$(stage_timing_format_seconds 750)"    "12m 30s"
check "2h 14m"   "$(stage_timing_format_seconds 8040)"   "2h 14m"
check "1d 18h"   "$(stage_timing_format_seconds 151200)" "1d 18h"
check "boundary 3600 -> 1h 0m" "$(stage_timing_format_seconds 3600)" "1h 0m"
# }}}

# {{{ ring buffer keeps only the last RING_SIZE, oldest off the top
rm -f "$STAGE_TIMINGS_FILE"
for v in 100 200 300 400 500 600 700; do stage_timing_record embed "$v"; done
check "ring count capped at 5"  "$(stage_timing_count embed)" "5"
check "mean of last 5 (300..700)" "$(stage_timing_mean embed)" "500"
check "oldest (100,200) evicted" "$(grep -c '^100$\|^200$' "$STAGE_TIMINGS_FILE")" "0"
# }}}

# {{{ no history -> fallback label with explicit qualifier
check "magnitude fallback label" "$(stage_timing_label ghost long)" "(long)"
check "measured beats magnitude"  "$(stage_timing_label embed long)" "(avg 8m 20s, last 5 runs)"
check "no magnitude + no history -> empty" "$(stage_timing_label ghost '')" ""
# }}}

# {{{ record only on success (the honesty rule)
timed_stage ok_stage   true
timed_stage fail_stage false
check "success recorded"     "$(stage_timing_count ok_stage)"   "1"
check "failure NOT recorded" "$(stage_timing_count fail_stage)" "0"
# }}}

# {{{ bad inputs are no-ops, never crash
stage_timing_record "" 5
stage_timing_record nostage "abc"
check "empty stage no-op"     "$(stage_timing_count '')"        "0"
check "non-integer secs no-op" "$(stage_timing_count nostage)"  "0"
# }}}

rm -f "$STAGE_TIMINGS_FILE"*
echo "---"
if [ "$fail" -eq 0 ]; then echo "ALL ${pass} PASS"; exit 0
else echo "${fail} FAILURE(S)"; exit 1; fi
