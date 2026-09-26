# 204 — The parallel reader

Reading every file of the walk across all cores and writing the survey's two
tables ([004](../docs/004-datapath-the-survey.md), *parallel reading*).

## Current Behavior

Built as `src/029-the-survey.lua` with the `survey` command in `src/031-the-survey-commands.lua`. Entries are dealt round-robin to worker threads rather than cut into contiguous slices (large files cluster in folders), each row tagged with its walk number so the gatherer restores path order; output is byte-identical at 1, 2 and 7 threads (tests/032). Lines are counted with a plain search loop: counting by substitution copied every file and was nearly all of the time. On the AzerothCore tree (about 8 500 files, 6 million lines) the survey went from 11.4 s to 1.7 s on one thread and 0.63 s on twelve.

## Intended Behavior

- The path list is dealt round-robin into as many slices as the thread
  library reports hardware threads (never more slices than files), so large
  files that sit together in one folder spread across threads.
- Each worker thread (effil) is given the source root, its slice as one
  newline-joined string, and the full path set as one string; it loads the
  language table and scanners itself (threads share no Lua state), reads each
  file, and returns two strings: its file rows and its link rows, already
  escaped as table lines.
- Each row comes back tagged with its entry's number in the walk; the
  gatherer puts every row back in walk order — path order — and writes
  `survey/files.tsv`
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
