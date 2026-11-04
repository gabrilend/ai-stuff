# stage-timing.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/stage-timing.sh: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
stage-timing.sh  (Issue 10-051) -- a sourced library, not run directly.

WHAT (for a CEO): the pipeline used to print hand-typed guesses for how long
each stage takes ("~42 hours"). Those guesses rot -- a faster GPU or a new
embedding backend changes the real time, but the printed number never does.
This records how long each stage ACTUALLY took on THIS machine, keeps the last
few, and lets the menu show the real average instead of a stale guess.

WHERE: timings live in ${DIR}/.stage-timings -- a hidden plain-text file modelled
on .file-index-counter. One [section] per stage, holding up to RING_SIZE bare
integers (seconds), the oldest rolling off when a newer one is recorded. The
numbers are a function of the operator's hardware and run count, so the file is
gitignored -- useless to share.

HOW it stays honest: a stage is only recorded when it COMPLETES successfully.
A run that errors or is Ctrl-C'd logs nothing -- a partial "time-until-failure"
would drag the average down and make the next estimate lie optimistically.

FUNCTIONS (source this file, then call):
  timed_stage <stage> <cmd...>            run cmd; record its wall-clock iff it succeeds
  stage_timing_record <stage> <seconds>   append a timing (oldest rolls off past the ring)
  stage_timing_mean   <stage>             print the integer mean, or "" if no history
  stage_timing_count  <stage>             print how many timings are stored for the stage
  stage_timing_format_seconds <int>       "45s" / "12m 30s" / "2h 14m" / "1d 18h"
  stage_timing_label  <stage> <fallback>  the pre-flight estimate string (measured or fallback)

Usage:  DIR=/path/to/project; source "${DIR}/scripts/stage-timing.sh"

${DIR} is the project root, set by the script that sources this (run.sh, the
test). project-dir: none -- a sourced library takes no command line; its
caller reads --dir. It used to fall back to a written-in path when DIR was
unset; now an unset DIR stops the caller, naming it (Issue 10-076).
STAGE_TIMINGS_FILE is overridable (the tests point it at a temp file).
```

## Functions

### `stage_timing_record()`

```
Append <seconds> to the [stage] section, keep only the last RING_SIZE entries
(oldest off the top), and write the whole file back atomically (temp + mv) so a
reader never sees a torn file. Creates the section -- and the file -- if absent.
Missing/unwritable file is a no-op: timing is a nice-to-have, never a contract.
```

### `stage_timing_mean()`
(No comment above it in the source.)

### `stage_timing_count()`
(No comment above it in the source.)

### `stage_timing_format_seconds()`

```
45 -> "45s", 750 -> "12m 30s", 8040 -> "2h 14m 0s", 151200 -> "1d 18h 0m".
Three units of resolution once an hour or more is involved (h m s, or d h m),
two below that (m s). Showing the seconds slot at the hour scale keeps every
row the same shape, which the pre-flight table relies on to line the times up.
```

### `stage_timing_label()`

```
Measured history wins and prints a real average: "(avg 2h 14m, last 3 runs)".
Before any run, the caller passes a coarse MAGNITUDE word (short/medium/long)
instead of a specific number -- a word can't rot the way "~42 hours" did when
the GPU path made it minutes, and the avg+count format makes it obvious which
lines are measured and which are still a guess. Empty magnitude -> print
nothing (the stage line stays bare until it has run once).
```

### `timed_stage()`

```
The generic wrapper used at run.sh's dispatch call sites, so each stage need not
be edited individually. Records ONLY on a zero exit -- a failed or interrupted
stage logs nothing (see "stays honest" above).
```
