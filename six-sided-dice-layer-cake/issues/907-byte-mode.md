# 907 — Byte mode

Produces `src/068-spout-byte-mode.md`.

## Current behavior

Nothing. The vision document's own retreat, and probably the grade that ships.

## Intended behavior

**One conductor per byte instead of per bit, eight pulses per transfer.**

### Where it comes from

> alternatively, each byte, so you can pulse 8 bits in a cycle.

That line is in the original page, two sentences after the one-wire-per-bit claim,
and it is the most quietly competent thing on it. **Whoever wrote it had already
found the wall**, and the blueprint should say so, because the retreat is better
engineering than the claim it retreats from.

### What it changes

Dividing the conductor count by eight moves the required pitch from ten microns to
about thirty-two. That is the difference between **a permanent copper-to-copper
bond and an ordinary microbump**, and therefore between a part that can only be
made by wafer-level bonding at the end of assembly and a part that can be attached
with a process the industry runs every day.

| | bonded (`905`) | byte mode |
|---|---|---|
| conductors | 16,777,216 | 2,097,152 |
| pitch | 10 µm | 32 µm |
| attach | permanent bond | microbump |
| edges per pane | 1 | 8 |
| whole-core copy | 33 µs | 262 µs |
| rework | none | possible |

Eight times the time, and in exchange the part becomes manufacturable, reworkable,
and testable before it is committed. **Two hundred and sixty-two microseconds to
move sixty-four gibibytes is still five thousand times a network link.**

### What has to be designed rather than scaled

**The multiplexer.** Eight bits share a conductor, so something selects between
them at eight times the pane rate. That circuit is per conductor, two million
times, and it has more area available than `903`'s driver did — a thirty-two
micron pitch gives a thousand square microns — so it can be a real circuit rather
than an inverter.

**The eight-phase timing.** `904`'s tiling still applies, but now each tile must
also produce eight correctly spaced phases. The skew budget within a pulse is
eight times tighter than the bonded grade's for the same nominal rate, which is
the hidden cost and the blueprint must surface it.

**Which eight bits.** Byte-aligned, so conductor *n* carries the eight bits of
byte *n*, is the obvious mapping and probably right — but `902`'s bit-to-pad rule
was chosen to keep a tile inside one memory interleave unit, and the byte-serial
order interacts with it. The blueprint must check rather than assume.

### Why this is the one that ships

Recommended, with the argument stated plainly: the bonded grade is unrepairable
and stakes two objects on sixteen million simultaneous bonds; the cabled grade
gives up two orders of magnitude and needs a different circuit entirely. Byte mode
keeps most of the width, uses a process that exists, can be tested before it is
committed, and costs eight edges — which against a translation unit that is
already a thousand times slower is invisible.

## Symbols this must publish

Conductor count, pitch, multiplexer area and energy. Phases per transfer and their
spacing. Intra-pulse skew budget. Pane transfer time and whole-core time. Bit-to-
conductor mapping and its consistency with `902`. Attach process and rework
possibility. Comparison table against the other two grades.

## Constraints this must assert

- Conductor count times eight equals `901`'s pane size in bits.
- Pitch is achievable by the named microbump process, with margin.
- Multiplexer area fits the pitch.
- Intra-pulse skew budget is met by `904`'s tiling at eight phases — the tighter
  test, asserted at the tighter number.
- The bit-to-conductor mapping keeps a tile within one `505` interleave unit,
  same as `902`.

## Suggested implementation steps

1. Quote the line from the vision and credit it.
2. Build the comparison table by deriving each row.
3. Design the multiplexer to the available area.
4. Redo `904`'s budget at eight phases and surface the tightening.
5. Check the mapping against `902` and `505`.
6. Write the recommendation with its argument.

## Blocks

`909`, `1202`, `1302`.

## Blocked by

`505`, `901`, `902`, `903`, `904`.

## Related documents

`007`. `008` entry 2, where this is credited as the page finding its own wall.
