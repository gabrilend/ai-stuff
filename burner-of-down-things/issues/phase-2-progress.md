# Phase 2 Progress — The survey

## Goals
The machine reads a source without a model — files, languages, sizes, who includes whom — across every core, and writes it as two tables and a summary view that can be rebuilt from the tables alone. Ends with the owner's own projects surveyed side by side (docs/004).

Counts: run `/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/burner-of-down-things -m`.

## Completed Issues
- 201 the walk — every file under a folder, one `find`, NUL-separated, skipped folders pruned.
- 202 the language table — language, role and scanner from a name and 8 KiB; C++ added from real sources.
- 203 include lines and links — scanners per include style, resolution inside the source; the anchored-pattern trap fixed and held by a check.
- 204 the parallel reader — dealt round-robin across every core, identical output at any thread count; 11.4 s → 0.63 s on the AzerothCore tree.
- 205 the summary view — built from the tables alone; C compile units kept apart from entry points.
- 206 phase 2 demo — the owner's projects side by side, and the speed curve on the largest source.

The phase's goal is met: a source is read without a model, across every
core, into two tables and a summary that can be rebuilt without the source.
Run `tests/run-tests survey` for the checks and `./run-phase-demo 2` for the
numbers.
