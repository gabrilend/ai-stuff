#!/usr/bin/env bash
# stage-timing.sh  (Issue 10-051) -- a sourced library, not run directly.
#
# WHAT (for a CEO): the pipeline used to print hand-typed guesses for how long
# each stage takes ("~42 hours"). Those guesses rot -- a faster GPU or a new
# embedding backend changes the real time, but the printed number never does.
# This records how long each stage ACTUALLY took on THIS machine, keeps the last
# few, and lets the menu show the real average instead of a stale guess.
#
# WHERE: timings live in ${DIR}/.stage-timings -- a hidden plain-text file modelled
# on .file-index-counter. One [section] per stage, holding up to RING_SIZE bare
# integers (seconds), the oldest rolling off when a newer one is recorded. The
# numbers are a function of the operator's hardware and run count, so the file is
# gitignored -- useless to share.
#
# HOW it stays honest: a stage is only recorded when it COMPLETES successfully.
# A run that errors or is Ctrl-C'd logs nothing -- a partial "time-until-failure"
# would drag the average down and make the next estimate lie optimistically.
#
# FUNCTIONS (source this file, then call):
#   timed_stage <stage> <cmd...>            run cmd; record its wall-clock iff it succeeds
#   stage_timing_record <stage> <seconds>   append a timing (oldest rolls off past the ring)
#   stage_timing_mean   <stage>             print the integer mean, or "" if no history
#   stage_timing_count  <stage>             print how many timings are stored for the stage
#   stage_timing_format_seconds <int>       "45s" / "12m 30s" / "2h 14m" / "1d 18h"
#   stage_timing_label  <stage> <fallback>  the pre-flight estimate string (measured or fallback)
#
# Usage:  DIR=/path/to/project; source "${DIR}/scripts/stage-timing.sh"

# {{{ configuration
# ${DIR} is the project root. run.sh sets it before sourcing; the hardcoded value
# is the fallback so the library is usable standalone. STAGE_TIMINGS_FILE is
# overridable (the tests point it at a temp file).
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/neocities-modernization}"
STAGE_TIMINGS_FILE="${STAGE_TIMINGS_FILE:-${DIR}/.stage-timings}"
# Ring size: how many recent timings to keep per stage. 5 balances a smooth mean
# against reacting to a real change (e.g. a backend that halved the embed time):
# larger is smoother but slower to track reality; smaller is noisier but quicker.
STAGE_TIMING_RING_SIZE="${STAGE_TIMING_RING_SIZE:-5}"
# }}}

# {{{ stage_timing_record <stage> <seconds>
# Append <seconds> to the [stage] section, keep only the last RING_SIZE entries
# (oldest off the top), and write the whole file back atomically (temp + mv) so a
# reader never sees a torn file. Creates the section -- and the file -- if absent.
# Missing/unwritable file is a no-op: timing is a nice-to-have, never a contract.
stage_timing_record() {
    local stage="$1" secs="$2"
    [ -n "$stage" ] || return 0
    [ -n "$secs" ] || return 0
    case "$secs" in (*[!0-9]*|'') return 0;; esac   # only non-negative integers
    local tmp
    tmp="$(mktemp "${STAGE_TIMINGS_FILE}.XXXXXX" 2>/dev/null)" || return 0
    # On the very first record the file does not exist yet; read /dev/null so awk
    # has a valid (empty) input and the END block still creates the section.
    local src="$STAGE_TIMINGS_FILE"
    [ -f "$src" ] || src=/dev/null
    awk -v stage="$stage" -v secs="$secs" -v ring="$STAGE_TIMING_RING_SIZE" '
        # Collect existing sections (in original order) and their integer entries.
        /^\[.*\]$/ { name = $0; sub(/^\[/, "", name); sub(/\]$/, "", name);
                     if (!(name in cnt)) { ord[++norder] = name; cnt[name] = 0 }
                     cur = name; next }
        /^[0-9]+$/ { if (cur != "") { cnt[cur]++; val[cur, cnt[cur]] = $0 } next }
        # comments and blank lines are dropped; we re-emit a fresh header below.
        END {
            if (!(stage in cnt)) { ord[++norder] = stage; cnt[stage] = 0 }
            cnt[stage]++; val[stage, cnt[stage]] = secs       # append the new timing
            print "# Stage timing ring buffer (Issue 10-051). Each section holds the last"
            print "# " ring " wall-clock durations (in seconds) for that stage; the oldest rolls"
            print "# off when a newer one is recorded. Hardware-specific -- do not commit."
            print ""
            for (i = 1; i <= norder; i++) {
                s = ord[i]
                print "[" s "]"
                start = (cnt[s] > ring) ? cnt[s] - ring + 1 : 1   # keep only the last `ring`
                for (j = start; j <= cnt[s]; j++) print val[s, j]
                print ""
            }
        }
    ' "$src" 2>/dev/null > "$tmp" || { rm -f "$tmp"; return 0; }
    mv -f "$tmp" "$STAGE_TIMINGS_FILE" 2>/dev/null || rm -f "$tmp"
}
# }}}

# {{{ stage_timing_mean <stage>  -- integer mean of the section, or "" if none
stage_timing_mean() {
    local stage="$1"
    [ -f "$STAGE_TIMINGS_FILE" ] || return 0
    awk -v stage="$stage" '
        /^\[.*\]$/ { name = $0; sub(/^\[/, "", name); sub(/\]$/, "", name); cur = name; next }
        /^[0-9]+$/ { if (cur == stage) { sum += $0; n++ } next }
        END { if (n > 0) printf "%d\n", int(sum / n + 0.5) }
    ' "$STAGE_TIMINGS_FILE" 2>/dev/null
}
# }}}

# {{{ stage_timing_count <stage>  -- number of timings stored for the stage
stage_timing_count() {
    local stage="$1"
    [ -f "$STAGE_TIMINGS_FILE" ] || { echo 0; return 0; }
    awk -v stage="$stage" '
        /^\[.*\]$/ { name = $0; sub(/^\[/, "", name); sub(/\]$/, "", name); cur = name; next }
        /^[0-9]+$/ { if (cur == stage) n++ ; next }
        END { print n + 0 }
    ' "$STAGE_TIMINGS_FILE" 2>/dev/null
}
# }}}

# {{{ stage_timing_format_seconds <int>  -- human-readable duration
# 45 -> "45s", 750 -> "12m 30s", 8040 -> "2h 14m", 151200 -> "1d 18h".
# Two units of resolution is enough for a pre-flight hint; we drop the finer unit
# once hours/days lead, where seconds of precision are noise.
stage_timing_format_seconds() {
    local s="$1"
    case "$s" in (*[!0-9]*|'') return 0;; esac
    if   [ "$s" -lt 60 ];    then echo "${s}s"
    elif [ "$s" -lt 3600 ];  then echo "$((s / 60))m $((s % 60))s"
    elif [ "$s" -lt 86400 ]; then echo "$((s / 3600))h $(((s % 3600) / 60))m"
    else                          echo "$((s / 86400))d $(((s % 86400) / 3600))h"
    fi
}
# }}}

# {{{ stage_timing_label <stage> <magnitude>  -- the pre-flight estimate string
# Measured history wins and prints a real average: "(avg 2h 14m, last 3 runs)".
# Before any run, the caller passes a coarse MAGNITUDE word (short/medium/long)
# instead of a specific number -- a word can't rot the way "~42 hours" did when
# the GPU path made it minutes, and the avg+count format makes it obvious which
# lines are measured and which are still a guess. Empty magnitude -> print
# nothing (the stage line stays bare until it has run once).
stage_timing_label() {
    local stage="$1" magnitude="$2"
    local mean count
    mean="$(stage_timing_mean "$stage")"
    if [ -n "$mean" ]; then
        count="$(stage_timing_count "$stage")"
        local plural="s"; [ "$count" = "1" ] && plural=""
        echo "(avg $(stage_timing_format_seconds "$mean"), last ${count} run${plural})"
    elif [ -n "$magnitude" ]; then
        echo "(${magnitude})"
    fi
}
# }}}

# {{{ timed_stage <stage> <cmd...>  -- run a stage, record its time iff it succeeds
# The generic wrapper used at run.sh's dispatch call sites, so each stage need not
# be edited individually. Records ONLY on a zero exit -- a failed or interrupted
# stage logs nothing (see "stays honest" above).
timed_stage() {
    local stage="$1"; shift
    local start_ts; start_ts="$(date +%s)"
    "$@"
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        local end_ts; end_ts="$(date +%s)"
        stage_timing_record "$stage" "$((end_ts - start_ts))"
    fi
    return "$rc"
}
# }}}
