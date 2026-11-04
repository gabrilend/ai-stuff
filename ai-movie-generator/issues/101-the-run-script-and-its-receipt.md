# 101 — the run script and its receipt

phase 1, the image call and the run

**Depends on:** None

## Current behavior

No program exists. The project folder has its skeleton and RAM tiers (tmp/ → /tmp/ai-movie-generator, tmp/shared-memory/ → /dev/shm/ai-movie-generator).

## Intended behavior

A `run` script at the project root that every later stage is started through:
- a hard-coded ${DIR} at the top, overridable by the first argument, with a `.DIR` file at the project root taking precedence when present;
- `--help`; `-I` for anything interactive;
- rebuilds the RAM tiers before writing anything (sources /mnt/mtwo/programming/ai-stuff/scripts/libs/ensure-ram-tiers);
- reads `input/` first: the brief, the sound, an optional hand-written shot list;
- makes a run folder `tmp/shared-memory/runs/<date-time>/`;
- writes `output/goodbye` last — the receipt: end time, seed, and the run's counters (pictures painted, clips made, seconds of film, seconds spent). A crash never says goodbye.
A shared Lua module (the goodbye writer) gathers counters from any stage, so no stage writes the receipt by hand.

## Suggested implementation steps

1. `src/` numbering from `.file-index-counter`; the first source file is the run's entry.
2. The goodbye writer: a counter table any stage increments; written on clean exit only.
3. The `run` script dispatches subcommands (paint, clip, assemble, listen, write, all) through a table.
4. Tests: a run with no work writes a goodbye with zero counts; a run that errors writes none.

## Related documents

- docs/architecture.md
