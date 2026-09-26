# 204 — The parallel reader

Reading every file of the walk across all cores and writing the survey's two
tables ([004](../docs/004-datapath-the-survey.md), *parallel reading*).

## Current Behavior

The walk lists paths; nothing reads them.

## Intended Behavior

- The path list is cut into as many contiguous slices as the thread library
  reports hardware threads (never more slices than files).
- Each worker thread (effil) is given the source root, its slice as one
  newline-joined string, and the full path set as one string; it loads the
  language table and scanners itself (threads share no Lua state), reads each
  file, and returns two strings: its file rows and its link rows, already
  escaped as table lines.
- The gatherer joins every worker's strings in slice order — which is path
  order, since the slices are contiguous — and writes `survey/files.tsv`
  and `survey/links.tsv` through the text-table module, then appends
  `surveyed` to the ledger with the counts.
- A `threads` setting forces a count; 1 runs the same worker code on the
  calling thread, for comparing.
- Command `survey` is added to the dispatcher.

| Decision | What each path leads to |
|---|---|
| A worker raises an error | The survey stops, naming the file the worker was on; no tables are written |
| The thread library cannot be loaded | Refused, naming the path tried. A survey on one thread because threads were missing would be a silent fallback |

## Suggested Implementation Steps

1. The worker function. **Test:** on a slice, same rows as reading the files
   one by one.
2. The pool and gatherer. **Test:** the tables are byte-identical with 1, 2
   and every thread.
3. **Test:** timing on a large tree (kiln) with 1 thread and all threads,
   printed, for the demo.

## Blocked by

- 105
- 201
- 202
- 203
