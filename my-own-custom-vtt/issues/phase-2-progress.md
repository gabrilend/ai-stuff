# Phase 2 — The world can be seen

**Goal:** compute what a body can see, remember what it has seen, and do it fast
enough to run per viewer per tick.

**Status: complete but for one issue that cannot be finished yet.** Six of seven
done; `./run-phase-demo 2` draws the phase working.

## The issues

| Issue | State | What it established |
| --- | --- | --- |
| [201 the thread pool](completed/201-the-thread-pool.md) | **done** | A range and a function, and no locks inside a pass. |
| [202 an eye and its wedge](completed/202-an-eye-and-its-wedge.md) | **done** | Turning a body into the question sight answers. |
| [203 the angular sweep](completed/203-the-angular-sweep.md) | **done** | Built as ray casting rather than a sweep — see below. |
| [204 the visibility polygon](completed/204-the-visibility-polygon.md) | **done** | A fan of angles and distances, sorted from the wedge's edge. |
| [205 the fog is a bitmap](completed/205-the-fog-is-a-bitmap.md) | **done** | Memory, which is a different thing from sight and is stored differently. |
| [206 sight for a viewer is a union](206-sight-for-a-viewer-is-a-union.md) | **open** | The per-body half is built. The union needs scopes, which are phase 6. |
| [207 the phase two demo](completed/207-the-phase-two-demo.md) | **done** | The capstone: a picture, the timings, and the security claim. |

## What is built

| Source | What it is |
| --- | --- |
| `040-threadpool` | Persistent workers, one barrier, no locks in a pass. |
| `042-sight` | The ray caster, the visibility fan, and the point query. |
| `044-fog` | The bitmap that only ever grows, and the copy rollback uses. |
| `046-demo-phase-2` | A body walking between rooms, drawn. |

## The decision the phase turned on

**Ray casting, not an angular sweep.**

The sweep is O(n log n) and is the classic answer. Everything difficult about it
lives in the active set — deciding which of two overlapping segments is nearer,
in integer arithmetic, with ties broken identically on every machine. The hazard
table in [203](completed/203-the-angular-sweep.md) is entirely a table of ways
that decision goes wrong.

**And the consequence of getting it slightly wrong is not a drawing glitch.**
This polygon decides which records go on a socket. A wall that goes missing at
one angle is somebody seeing through stone — a security failure wearing a
rendering artefact's clothes.

Ray casting has no active set. Each ray is independent and obviously correct, and
the measurement says it is fast enough by a wide margin. When correctness and
affordability point the same way, that is usually a sign the decision is right
for a reason not yet written down.

## What the measurement settled

**Open question 3.2, the tick rate.** About 90 microseconds of sight per body
against 17 walls. A table of six is roughly 550 microseconds a tick, which at
twenty ticks a second is about 1% of one core.

Sight was expected to be the pass that constrained the heartbeat. It does not, at
tabletop scale, and phase 3 can pick a tick rate for reasons other than this one.

**And the broad-phase index still has no case.** It was moved out of phase 1 for
lack of a caller. Now there is a caller and the caller does not need it. It stays
unbuilt until a measurement asks for it.

## What building it taught

**Three tests were wrong before the code was.** All three assumed a line crossed a
wall where the arithmetic says it does not — a point "round the end" of a wall
that the wall still covers, and a corridor mouth wide enough to see through. The
code was right each time. Working the geometry out by hand before changing
anything is what kept a correct ray caster from being "fixed".

**Two clocks, not one.** The first version of the demo measured processor time and
reported threading as a slowdown, because processor time is the sum across
threads and climbs when work is shared. Wall time falls while processor time
climbs, and that gap is the coordination being paid for. A table showing only one
of them lies about the other.

## Blocking open questions

- **2.1** — is a metre too coarse for the fog grid? The fold currently tests each
  cell's centre, which under-claims rather than over-claims, so the risk the
  question was about is reduced but not answered.
- **2.2** — does a viewer with many bodies see the union or switch between them?
  Now blocking [206](206-sight-for-a-viewer-is-a-union.md) directly.

## What phase 3 inherits

A thread pool proven to give identical results at any thread count, a sight pass
that is cheap enough not to constrain the heartbeat, and a fog that can be
snapshotted and restored — which is half of what taking a turn back needs.
