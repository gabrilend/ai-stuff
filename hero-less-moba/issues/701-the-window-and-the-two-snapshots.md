# 701 — The Window and the Two Snapshots

| | |
| --- | --- |
| Phase | 7 — Watching It Happen |
| Blocked by | 107, 109 |
| Blocks | 702, 703, 704, 705 |
| Reads | [the viewing layer](../docs/017-the-viewing-layer.md) |
| Open questions | none |

## Current behavior

A window, a fixed tick under a free frame rate, and two snapshots with the blend
clamped so the viewer can be behind and never ahead. A long frame is truncated rather
than simulated through, and pausing drops the accumulator.

Above walking pace the blend is dropped entirely: a frame that spans many ticks would
otherwise show positions between two states that were never adjacent.

## Intended behavior

A window, in **LÖVE**, and the interpolation loop behind it.

LÖVE because it is already LuaJIT — **no FFI boundary between the viewer and the
simulation**, the snapshot read directly in the same language with no
marshalling — and because its sprite batcher is the viewer's only real
performance question, given hundreds to thousands of near-identical bodies every
frame.

### The interpolation loop

Keep the **two most recent snapshots** and draw positions interpolated between
them by the fraction of a tick elapsed. The viewer runs at whatever rate the
display wants, decoupled from the fixed tick.

**Allowed to be behind. Never allowed to be ahead.** A viewer that extrapolates
shows things that did not happen, and in a game where a player judges a lane by
looking at where the frontline is, that is a lie that changes decisions.

### The camera

**Whole map by default, always. Zoom to inspect.** The default is the part that
matters — the entire design rests on judging three lanes by looking at them.

One rule, and it belongs in a comment above the camera code:

> **Zoom reveals detail. It never reveals events.**

Anything a player must react to must be legible at the default view, with no zoom
and no camera move. And **returning to the whole map is one instant, unmissable
action** — if getting back is ever a small navigation task, players stop zooming
in at all and the detail the camera exists for goes unread.

Why that rule, and what breaks without it, is in
[the viewing layer](../docs/017-the-viewing-layer.md).

### The rules this program obeys

Reads snapshots. Writes commands. Holds no state the simulation needs, decides
nothing the simulation could decide, never writes into the world. Those were easy
to keep when the viewer was fifty lines of text; this is where they start costing
something, and they are still not negotiable.

## Suggested implementation steps

1. Write the window, the main loop, and the snapshot double-buffer.
2. Write the interpolation, and make the **never extrapolate** clamp explicit and
   commented rather than implicit in the arithmetic.
3. Write the camera as a zoom scalar and a centre, with the whole-map framing as
   its rest state and a single binding that returns to it.
4. Write an assertion helper the event code calls: anything raising a
   player-facing event checks its subject is inside the default framing. Cheap,
   and it catches the "zoom reveals events" failure the moment somebody
   introduces it rather than in playtesting.
5. Write the input-to-command path: every click becomes a command record and
   nothing else.
6. **Keep the terminal viewer from issue 109 working.** Not a stepping stone to
   discard — it is faster to debug in, works over a connection where nothing
   graphical does, pipes to a file and diffs, and it keeps this layer honest by
   being a second consumer of the same snapshots. **Two viewers means neither can
   quietly become part of the simulation.**

## Related documents and tools

- [The viewing layer](../docs/017-the-viewing-layer.md)
- The terminal viewer from issue 109

## Still open

Nothing blocking. What the setting looks like is not decided —
[nobody remembers why](../docs/021-nobody-remembers-why.md) establishes an
automated war nobody started and two archives nobody has read, and nothing has
been drawn yet.
