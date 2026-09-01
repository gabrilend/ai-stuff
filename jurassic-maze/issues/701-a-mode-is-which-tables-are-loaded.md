# 701 — A Mode Is Which Tables Are Loaded

| | |
| --- | --- |
| Phase | 7 — The Delve |
| Blocked by | 301, 405 |
| Blocks | 702, 703, 707 |
| Reads | [the delve](../docs/021-the-delve.md) |
| Open questions | 2 (what does "only" attach to), 3 (does "solve" mean solve) |

## Current behavior

There is one world and everything that exists is in it.

## Intended behavior

A **mode** is a named set of table contents: which creature kinds spawn, which
meet-table entries are active, which tick passes run, and which games can start.
It is not a branch anywhere in the simulation.

Two modes: **habitat**, which is phases three through six, and **delve**, which
adds humans, monsters, riding, weapons and fire.

Building it as table contents rather than as a flag is what stops "if delve"
appearing in the movement code, the renderer, and the meet pass — three places
that would then all have to agree about it. A mode selects rows; the code that
walks the rows never learns there are modes.

Riding and dinosaur-borne weapons belong to the delve and not to the habitat.
That is the reading taken of *"but only when they're navigating the dungeon"*,
and it is a reading — see [open question 2](../docs/026-open-questions.md). The
mode being table contents is exactly what makes the other reading a one-line
change: move the weapon row from the mode's table to the creature's.

## Suggested implementation steps

1. Write the mode table: name, creature kinds and their targets, extra meet
   entries, extra tick passes, allowed games.
2. Write the loader that composes the active tables from a mode at world
   creation, once, so nothing consults the mode during a tick.
3. Make the mode a run parameter, and print it in the report and in the terminal
   viewer's header.
4. Test: a habitat run and a delve run on the same seed produce different reports
   and both validate; no file under `src/` other than the loader mentions a mode
   by name.

## Related documents and tools

- [The delve](../docs/021-the-delve.md)
- [Open questions](../docs/026-open-questions.md) — questions 2 and 3
