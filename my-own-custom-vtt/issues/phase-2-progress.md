# Phase 2 — The world can be seen

**Goal:** compute what a body can see, remember what it has seen, and do it fast
enough to run per viewer per tick. Still no network and no clock -- sight is
computed on demand, from a world that is not moving.

**Status:** not started. All seven issues are written and none is implemented.

## The issues

| Issue | State | What it is for |
| --- | --- | --- |
| [201 the thread pool](201-the-thread-pool.md) | not started | A range and a function. No locks, because no pass writes where another reads. |
| [202 an eye and its wedge](202-an-eye-and-its-wedge.md) | not started | Turning a body into the question the sweep answers, and handing it as few walls as possible. |
| [203 the angular sweep](203-the-angular-sweep.md) | not started | The most important algorithm in the project, and the most expensive. |
| [204 the visibility polygon](204-the-visibility-polygon.md) | not started | The sweep's output, in the one shape that serves the fog, the filter, and the renderer at once. |
| [205 the fog is a bitmap](205-the-fog-is-a-bitmap.md) | not started | Memory, which is a different thing from sight and is stored differently. |
| [206 sight for a viewer is a union](206-sight-for-a-viewer-is-a-union.md) | not started | Several bodies, one screen, and the two flags that stop a GM being unaffordable. |
| [207 the phase two demo](207-the-phase-two-demo.md) | not started | The capstone. A picture, the timings, and the security claim shown before there is a network to enforce it. |

## What this phase is really establishing

**That sight is exact, deterministic, and parallel** -- three properties that are
each needed by something different, and all three of which come from the same
algorithm.

Exact, because the visibility polygon has to be usable as a security boundary and
a drawing at the same time. Deterministic, because a replay that computes
visibility differently on a different machine diverges. Parallel, because it is
the expensive pass and it is about to run per viewer per tick.

The determinism is the one most likely to be lost quietly. Every tie-break in
[203](203-the-angular-sweep.md) -- two endpoints at the same angle, two collinear
segments -- is a place where an arbitrary choice becomes a divergence an hour into
a replay. Those are not edge cases to handle later; they are the file.

## What this phase decides for later phases

**The tick rate.** [207](207-the-phase-two-demo.md) measures the sweep, and sweep
cost times viewer count is the budget the heartbeat has to fit inside. That number
is measured here, not chosen in a document.

**Whether `SEES_REGION` is an optimisation or a necessity**, which depends on how
large a table gets ([4.3](../docs/016-open-questions.md)) and on how expensive a
sweep turns out to be.

## Blocking open questions

- **2.1** — is a metre too coarse for the fog grid? Now that the memory cost has
  collapsed, the question has inverted: not "can we afford finer" but "does a
  cell set by a glancing corner overclaim what somebody remembers".
- **2.2** — does a viewer with many bodies see the union of all of them, or switch
  between them? The union is what [206](206-sight-for-a-viewer-is-a-union.md)
  builds and what the security argument assumes. It may still play badly.

Neither blocks starting. Both change what [207](207-the-phase-two-demo.md) should
be showing.
