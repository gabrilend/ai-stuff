# 108 — The Headless Runner

| | |
| --- | --- |
| Phase | 1 — The Ground and the Clock |
| Blocked by | 104, 107 |
| Blocks | 109, 803, 804 |
| Reads | [the viewing layer](../docs/017-the-viewing-layer.md), [the shape of the code](../docs/018-the-shape-of-the-code.md) |
| Open questions | none |

## Current behavior

`./run-prototype headless` plays a whole match with no window and prints a report
made of the numbers a balance question is asked in — push depth and waves lost per
lane, upgrades drawn and where they went, towers standing, library health.

`./run-many-matches` does the same a great many times, one worker per core, and writes
a row per match plus a summary table.

## Intended behavior

A script that builds a world, optionally loads a replay, advances it to a stop
condition, and writes a report. It opens no window, reads no keyboard, and knows
nothing about drawing.

This is the program the balance work runs, the program the tests run, and the
program the bot plays against. It is the **generator** half of the project's
central split, standing alone with the viewer removed — which is exactly the
proof that the split is real.

The report it writes:

- Match length in ticks. Which team won, in which lane the library fell, and to
  what.
- Per lane, per team: the frontline's milestone over time, sampled.
- Per team: upgrades drawn, upgrades placed, waves lost, towers lost.
- Per player: resource earned and spent, heroes bought, heroes lost.
- The world hash at the final tick, so two runs can be compared with one
  comparison.

It writes to `tmp/shared-memory/`, which is RAM, and it makes sure that directory
exists before writing. **Nothing ephemeral goes into the repository.**

Like every script in the project it has a hard-coded `${DIR}` at the top pointing
at the project root, accepts an override as its first argument, and builds every
path relative to it — so it runs correctly from any directory. It opens with a
comment explaining what it is and how it works, pitched at a reader who has never
seen the code.

**Startup reads `input/` first.** Shutdown writes goodbye to `output/`, last.

## Suggested implementation steps

1. Write the runner script with its `${DIR}` header and its input-directory read.
2. Add a stop condition table: run for N ticks, run until a library falls, run
   until a given tick, run until the world hash changes from a baseline.
3. Write the report generator as a **separate module from the runner**. The
   runner produces data; the report views it. The same separation as the whole
   project, at a smaller scale.
4. Make the report emit two formats from the same data: a human-readable text
   table and a machine-readable line-per-match record for issue 804 to aggregate.
5. Ensure `tmp/shared-memory/` exists before the first write, and fail loudly if
   it cannot be created rather than falling back to the working directory.
6. Write goodbye to `output/` on exit, including the abnormal exit.

## Related documents and tools

- [The viewing layer](../docs/017-the-viewing-layer.md) — the split this proves
- [The shape of the code](../docs/018-the-shape-of-the-code.md) — script rules
- The report generator (this issue creates it)
