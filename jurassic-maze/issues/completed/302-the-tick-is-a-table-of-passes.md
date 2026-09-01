# 302 — The Tick Is A Table Of Passes

| | |
| --- | --- |
| Phase | 3 — The Rolling |
| Blocked by | 301 |
| Blocks | 303, 307, 308, 405, 502, 703 |
| Reads | [the tick](../docs/010-the-tick.md) |
| Open questions | none |

## Current behavior

Three passes so far — `move`, `spawn`, `index` — as an array of rows walked in
order, with optional per-pass timing. `meet` and `resolve` are simply absent
rather than present and skipped, which is the whole argument for the table.

`new_world` also lives here: the maze, the streams, the bodies, the rows and the
report assembled in one place, so the window, the terminal and the headless
runner all get the same thing.

Each world loads its **own copy** of every module, including the creature table.
That is worth knowing before writing anything that tunes a number: mutating the
table an outer script loaded changes nothing, because the world is reading a
different one. A parameter sweep that reported identical results for twelve
different settings is how this was found.

The thread pool is not wired up. The passes declare `parallel` and nothing reads
it yet. At a few hundred bodies the move pass costs half a millisecond a tick, so
there is nothing to gain until the population is an order of magnitude larger --
and the flag being stated now is what makes it safe to add later.

## Intended behavior

One tick is **one sixtieth of a second of simulated time, always.** The engine's
real elapsed time never reaches the simulation; the viewer accumulates it and
spends it in whole ticks, with a ceiling on the accumulator so that a dragged
window does not produce a hundred and twenty ticks in one frame — trying to catch
up takes longer than real time, which produces more to catch up on.

A variable timestep would make a ball that clears a gap at sixty frames a second
fall into it at thirty, and every seed in every bug report would mean something
different on every machine.

The tick is **an array of `{name, function, parallel}` rows walked in order**,
not a function with seven calls in it. The passes and their order are in
[the document](../docs/010-the-tick.md). Two things about that order are
load-bearing:

- **Deciding is separated from moving**, so no body's decision can see another
  body half-moved. Otherwise the simulation depends on the order bodies happen to
  be stored in, which changes whenever one dies.
- **Damage is buffered and applied in one place**, so two fencers who kill each
  other in the same tick both die instead of the outcome being decided by an
  array index.

Being a table gives three things: a pass is added as a row, timing every pass is
a loop rather than seven pieces of timing code, and a pass can be removed without
editing the tick — the ball phase does not need `meet` or `resolve`.

Each row declares whether it is **parallel-safe**, stated rather than inferred.
Inferring it means being silently wrong once, at which point determinism is gone
and nobody knows when it went.

## Suggested implementation steps

1. Write the pass table with the seven rows, the flags, and nothing else in the
   file that decides anything.
2. Write the walk, with optional per-pass timing accumulating into the report.
3. Write the accumulator and its ceiling in the viewer, not in the tick — the
   tick takes whole steps and knows nothing about real time.
4. Wire the thread pool to safe passes only, as a range split into one chunk per
   core. Unsafe passes run on the calling thread; they are the three cheapest,
   which is by design and not by luck.
5. Test: a run with the pool disabled and a run with it enabled produce identical
   checksums. This is the only test that can catch a pass mislabelled safe.

## Related documents and tools

- [The tick](../docs/010-the-tick.md)
- [A body and what it carries](../docs/011-a-body-and-what-it-carries.md)
