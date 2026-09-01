# 508 — The Glow Flips to Aiming

| | |
| --- | --- |
| Phase | 5 — Filters and the Weave |
| Blocked by | 507 |
| Blocks | — |
| Reads | [the map surface](../docs/002-the-map-surface.md) |
| Open questions | **3** — the tunable that decides the flip |

## Current behavior

The glow always marks what is selected.

## Intended behavior

At close zoom, when the selected place is **the only one fully on screen**,
marking it is pointless — it is obviously the one, because it is all you can see.
So the glow flips to **following the pointer**, becoming an aiming aid instead.

The person can switch the behaviour off entirely and keep the glow on selection
always.

### Why it is worth having at all

The glow answers *which one*. When there is only one, the question has no content
and the light is wasted — worse, it is a large moving brightness over the thing
you are trying to look at closely.

At that zoom the useful question has changed from *which is selected* to *which
would I get if I clicked*, and the same light answers it.

### The tunable, and why it is not settled

**Working ruling:** count places entirely within the view; flip when that count
reaches one.

It is cheap and exactly expresses the sentence. It is also **jumpy** — the count
changes on a single pixel of pan, so at the boundary the glow can switch back and
forth while you nudge the view, which is worse than either behaviour alone.

A zoom threshold would be smoother and less correct, since the right zoom differs
between a harbour block and a northern one — the same perspective problem that
makes [408](408-the-zoom-picks-the-level.md) measure places rather than trust the
zoom directly.

A third option is hysteresis: flip at one, flip back at three, so the boundary is
not a single line to sit on.

This needs feeling rather than reasoning, so it waits for something runnable. See
open question 3.

## Suggested implementation steps

1. Count places wholly inside the view each frame, at the currently selected
   level — cheap, since the cull already visits them.
2. Implement the working ruling with hysteresis, and mark it in the source as a
   ruling rather than a decision, naming the open question.
3. Put the switch in the map controls at the top of the tome — see
   [603](603-the-focused-filters-controls.md).
4. Cross-fade rather than cutting when the meaning changes, so the flip is not a
   flash.
5. Once runnable, try all three approaches against the real painting in the
   harbour and by the north wall, since those are where they differ most.

## Related documents and tools

- [The map surface](../docs/002-the-map-surface.md)
- [Open questions](../docs/013-open-questions.md) — question 3
