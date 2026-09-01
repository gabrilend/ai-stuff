# 307 — The Aquarium Tops Itself Up

| | |
| --- | --- |
| Phase | 3 — The Rolling |
| Blocked by | 103, 301, 302, 206 |
| Blocks | nothing |
| Reads | [what this is](../docs/001-what-this-is.md) |
| Open questions | 5 (do the phases share one aquarium) |

## Current behavior

Bodies can be spawned by hand and there is no reason for there to be any.

## Intended behavior

There is no run that finishes. Balls enter at the top, roll down, come to rest,
are taken away, and are dropped in again. The population is a number that is
maintained rather than an event that happens at the start.

The `spawn` pass, each tick:

- Any body at rest for longer than `rest_seconds` is removed.
- Any body that somehow left the world is removed, **loudly**, and counted.
- While the live count of a kind is below its target, spawn one.

A spawn point is a surface drawn from the `spawn` stream, weighted toward high
layers for balls so they have somewhere to roll from, and spread across the maze
for walkers so they do not all arrive in one corner.

The **spawn must not land on top of another body.** A cell that already holds one
is rejected and another drawn, up to a small number of tries, after which the
spawn is skipped this tick and counted. Skipping is correct — the population
recovers next tick — and counting is what makes a maze whose spawn points are all
blocked visible as a number instead of as a slowly emptying aquarium.

Which kinds are present, and how many of each, is a parameter of the run rather
than a property of the phase. Balls and little guys can share one maze.

## Suggested implementation steps

1. Write the target population table: one row per creature kind, with a count.
2. Write the rest detector — speed below a threshold for `rest_seconds`
   continuously, with the timer reset by any motion above it.
3. Write the weighted spawn surface picker, drawing from the `spawn` stream.
4. Write the occupancy rejection using the buckets from issue 308.
5. Count everything: spawned, removed at rest, removed for leaving, spawns
   skipped for want of room. All into the report.
6. Test: over a long headless run the live count stays within one of the target;
   the leaving count is zero; the skipped count is zero on a maze with normal
   parameters and non-zero on a deliberately tiny one.

## Related documents and tools

- [What this is](../docs/001-what-this-is.md) — why there is no end
- [Headless and the report](206-headless-and-the-report.md)

## Still open

Open question 5: whether the phases share one aquarium. Assumed yes, because it
costs nothing to allow and it is the more interesting default. If the answer is
no, the target population table becomes per-scene and nothing else changes.
