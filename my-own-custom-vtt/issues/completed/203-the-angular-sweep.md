# 203 -- The angular sweep

**Phase:** 2, the world can be seen
**Blocked by:** [201](201-the-thread-pool.md),
[202](202-an-eye-and-its-wedge.md)
**Blocks:** [204](204-the-visibility-polygon.md), and through it the entire
security model.
**Documents:** [sight and what it remembers](../docs/007-sight-and-what-it-remembers.md)

## Current behaviour

Nothing exists.

## Intended behaviour

Given a wedge and a set of segments, compute what is visible. This is the most
important algorithm in the project and the most expensive one.

### The method

1. For each segment, compute the angle from the apex to each endpoint. Clip to the
   wedge.
2. Sort all endpoints by angle. **This is the `n log n` and it is essentially the
   whole cost.**
3. Sweep through the sorted endpoints, maintaining the set of segments currently
   crossing the sweep ray. At each step, the nearest member of that set is what is
   visible at that angle.
4. Where the nearest changes, emit a visibility boundary.

The active set is small -- it is the number of walls overlapping one angle, which
in a room is a handful. A sorted array with linear insertion beats a balanced tree
here and is far easier to make deterministic. **Choose the array and write down
why**, because a tree looks more sophisticated and is worse at both jobs.

### The cases that will break it

These are not edge cases to handle later. They are the file.

| Case | What goes wrong if ignored |
| --- | --- |
| Two endpoints at exactly the same angle | Sort order becomes arbitrary, and arbitrary means non-deterministic, and non-deterministic means replays diverge. Break the tie on something stable -- segment index -- never on address or arrival. |
| The wedge straddles angle zero | The sort wraps. Either rotate everything so the wedge starts at zero, or sort in two pieces. Rotating is simpler and costs one addition per endpoint. |
| A segment passing exactly through the apex | The angle to it is undefined. Refuse this in [107](107-the-validator-refuses-to-guess.md) if it is a static wall; handle it if a body can walk onto a wall, which it should not be able to. |
| A collinear pair of segments | Which is nearer is ill-defined. Tie-break on index, consistently. |
| Zero-length segment | Both endpoints at one angle. Refused by the validator, but the sweep should not crash if one arrives. |

Every one of these is a determinism hazard rather than a crash. That is worse,
because it fails an hour later in a replay with nothing to point at. **Every
tie-break in this file gets a comment naming what is being broken and why that
rule is stable.**

### It must be deterministic and it must not use floating point

Angles are 16-bit integers. Distances are compared squared, in fixed point,
through [101](101-the-arithmetic-is-integers.md). No `atan2`, no doubles, no
`libm`. The angle from a vector comes from the lookup table.

## Suggested implementation steps

1. Write the endpoint gathering and the wedge clip.
2. Write the sort. Use one whose behaviour on equal keys is defined, and give it
   an explicit tie-break so it does not matter.
3. Write the sweep and the active set.
4. Handle each case in the table above, with its comment, as you go rather than
   afterwards.
5. Keep the inner loop free of branches on data and free of pointer chasing, so
   that hand-written assembly stays possible later without restructuring anything.
   See [the shape of the code](../docs/014-the-shape-of-the-code.md).
6. Write the companion `.info.md`.
7. Test against hand-computed visibility in small worlds: one wall, two walls
   meeting, a doorway, a pillar, a body inside a closed room, a body in the open.
8. Test determinism directly: run the same sweep with the endpoints fed in a
   different order and assert the output is identical.

---

## What was actually built, and why it is not a sweep

**Ray casting at corners**, not an angular sweep. `042-sight.c` casts three rays
at each wall endpoint -- one at it and one just to either side -- and takes the
nearest wall each meets. That is O(corners x walls) where the sweep is
O(n log n).

The reason is the active set. Everything difficult about the sweep lives there:
deciding which of two overlapping segments is nearer, at an angle where they
overlap, in integer arithmetic, with ties broken identically on every machine.
The table of hazards above is entirely a table of ways that decision goes wrong.

And the consequence of getting it slightly wrong is not a drawing glitch. This
polygon decides which records go on a socket, so a wall that goes missing at one
angle is somebody seeing through stone -- a security failure that looks like a
rendering artefact.

Ray casting has no active set. Each ray is independent and obviously correct.

**The measurement, which is what actually settled it:** about 90 microseconds per
body against 17 walls. A table of six is roughly 550 microseconds of sight per
tick, which at twenty ticks a second is about 1% of one core. The phase 2 demo
reports the current figure rather than this file quoting a stale one.

At that price the sweep buys nothing a tabletop can feel, and costs the one thing
this project cannot afford to get subtly wrong.

## What survives for whoever writes the sweep later

Everything above the line. The hazards are still the hazards -- two endpoints at
one angle, a wedge straddling zero, collinear segments -- and every one of them is
a determinism failure rather than a crash, so they fail an hour into a replay
with nothing to point at.

The tests in `043-test-sight.c` are the guard rail. In particular the one that
samples thousands of points and asserts that the fan and the point query agree:
a sweep that passes that has not gone quietly wrong.
