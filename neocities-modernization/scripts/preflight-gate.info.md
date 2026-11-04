# preflight-gate.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/preflight-gate: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
preflight-gate -- every cheap check a build can fail, run before the build.

WHAT IT DOES (for a CEO): a full site build runs for hours, overnight, with
nobody watching.  Anything that can be known to break it -- a library that
will not load, a configured path that points at nothing -- is checked here
first, in seconds.  If every check the chosen stages need passes, the build
can be left alone.  If any fails, all the failures are listed together and
nothing is started.  It never changes anything.  (Issue 10-069.)

HOW: a list of checks.  Each row names what it checks, which stages need it,
and the command that checks it.  run.sh passes the stages it is about to
run; rows whose stages are not running are skipped.

Usage:
  scripts/preflight-gate [--dir PATH] [--html-threads N] [--extract]
                         [--poems-file PATH] [--effil-cpath PATTERN]

  --dir PATH      project directory (default below)
  --html-threads  stage 9 will run with N page workers
  --extract       stage 2 (extract, then strip excluded content) will run
  --poems-file    stage 9 or 10 will read this existing poem list (run.sh
                  passes it only when stage 3 is not rebuilding it this run)
  --rankings-dir  stage 9 will read the saved similarity rankings in this
                  model cache folder as they are (not rebuilt by stage 7);
                  needs --poems-file too
  --effil-cpath   look for the threading library here instead of its real
                  home -- for the gate's own test, to prove a library that
                  cannot load is reported

Exit status: 0 when every selected check passed, 1 otherwise.

--help: print the header above and exit, before any work (libs/script-help.sh)
```

## Functions

### `needs_threads()`

```
Stage 9 runs its page workers on effil.  With one worker it never loads it.
```

### `check_threads()`
(No comment above it in the source.)

### `needs_exclusions()`

```
Stage 2 strips excluded content; a mistyped exclusion stops it (10-053).
```

### `check_exclusions()`
(No comment above it in the source.)

### `needs_dates()`

```
Stages 9 and 10 place every poem on the timeline by its date; an undated
poem stops them (8-045).  Uses the page build's own date reading.
```

### `check_dates()`
(No comment above it in the source.)

### `needs_rankings()`

```
Stage 9 looks up each poem's neighbours in the saved rankings by poem number;
rankings saved before the poems were renumbered point at the wrong poems
(2-010).  Compares the rankings with the poem and image lists.
```

### `check_rankings()`
(No comment above it in the source.)
