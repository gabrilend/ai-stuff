# 901 — The map of stops

**Phase:** 9 — Reading the machine
**Blocked by:** none (reads whatever src/ holds; grows as phases 1–8 land)
**Blocks:** 902, 904, 905
**Related documents:** delta-version issue 065 (the same system, built in
parallel as a tool for every project), docs/roadmap.md (Phase 9)

## Current Behavior

Nothing describes this project as a walk. Source files are numbered in
reading order from `.file-index-counter`, and each has a `.info.md` beside
it, but no tool gathers them into stops.

## Intended Behavior

A builder reads this project and writes a **map**: one stop per function or
datastructure, in index order. Each stop holds:

| Field | Type | What it is |
|---|---|---|
| index | integer | position on the default path |
| name | string | English name, not the code name |
| file, line | string, integer | where it lives |
| black-box description | string | from the file's `.info.md` |
| uses | list of (file string, line integer) | everywhere it is called or built |
| summary | string | the shortest true statement of it — the floor a reader may skip down to |

The map is data only. It is written to `tmp/shared-memory/reading-walk/map`
and knows nothing about who will read it.

## Suggested Implementation Steps

1. Read `src/` in index order; for each file, read its `.info.md` entries.
2. Find each entry's definition line and its uses, one file per job across the
   worker threads from issue 105.
3. Write the map; print the count of stops and the count of stops with no
   `.info.md` entry (each of those is an error, not a warning).
4. Tests: a small fixture project of three files whose map is known by hand.

## Lessons from the parallel build

delta-version issues 065a–d (completed) built the same map first. Two things
it learned: a fold marker can open a prose heading rather than a name, which
is a stop with no uses; and a private function's name reused in another file
is a different function, so its uses count only in its own file.
A third, found when the pages were drawn: a shared function's name ending
another module's call ("graph.new" vs the canvas's "new") is not a use; count
a use in another file only when it goes through the name that file gave this
one when loading it.
