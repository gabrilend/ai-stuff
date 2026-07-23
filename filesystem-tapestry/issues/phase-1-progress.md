# Phase 1 — The Thread — Progress

Goal of the phase: a runnable spine that catalogs the creation and modification
date of every file on the user's data drives, walks that catalog in
chronological order, and opens the file under the cursor in the correct program.

For live numbers rather than prose that goes stale, run:

    ./scripts/validate.sh --stats

## Status of the phase goals

- **Catalog of both dates (1-001):** done. The scanner records birth time
  (created) and mtime (modified) for every file, one process per root, in
  parallel. Verified on `/mnt/cmdo/ritz/my-recorded-videos` (46k+ files).
- **Exclude unimportant directories from the shared list (1-002):** done, with
  one important discovery — the shared `.gitignore` filters by *file type*
  (`*.mkv`, `*.o`), which would have hidden the very media the user wants to
  browse. Resolved by honoring directory/name/path patterns and dropping pure
  `*.ext` type-globs, plus adding `.git` (which git omits by convention). See
  `strategems/place-not-kind.md`.
- **Merge + load (1-003):** done. One `catalog.jsonl` is the only artifact the
  generation and viewing halves share.
- **Chronological ordering (1-004):** done, deterministic (path tie-break),
  by created or modified, ascending or descending. The `similar`/`different`
  seams exist and fall back to chronological with a spoken warning.
- **Media dispatch (1-005):** done. Table maps kind → mpv / feh / zathura /
  nvim; unknown kinds take the announced xdg-open fallback.
- **Navigator (1-006):** done. `next`/`previous`/`open`, mode and date switches,
  `list`, `where`; reads `input/` first, writes `output/goodbye` last.

## Lessons carried forward

- "Excluded" must mean "skipped by the walk", never "dropped from the record" —
  the excluded count in the stats stays inside the chronological catalog.
- Capturing both dates paid off immediately: many files show a creation date
  (arrival on this drive) years after their content's modified date. A single
  date would have hidden one truth or the other. `scripts/find-divergence.lua`
  surfaces this.
- Fallbacks are audible everywhere: missing birth time, unknown media kind, and
  absent Phase-2 similarity all announce themselves.

## What Phase 1 does NOT yet do

`similar` and `different` need policy descriptions and their embeddings — that is
Phase 2 (`issues/2-001-...`). Until then they walk the chronological order and
say so.

## Demo

`issues/completed/demos/phase-1-demo.sh` (run via `./phase-demo.sh` → choose 1):
shows the statistics, the birth-vs-content divergence, and a scripted walk
including the Phase-2 fallback.
