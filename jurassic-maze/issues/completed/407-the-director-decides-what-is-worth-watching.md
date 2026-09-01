# 407 — The Director Decides What Is Worth Watching

| | |
| --- | --- |
| Phase | 4 — The Wandering |
| Blocked by | 103, 204, 301 |
| Blocks | 408, 504 |
| Reads | [the camera and what it watches](../../docs/008-the-camera-and-what-it-watches.md) |
| Open questions | 1 (camera or fencer) |

## Current behavior

`044-the-director.lua`. Free, follow, or stakeout; a verdict that is an ordered
list of named predicates so the panel can say *which* one fired; and a subject
held with its generation.

The next subject is chosen by **reservoir sampling in one pass**, weighted toward
bodies doing something — on an errand, in company, falling. No candidate list is
built, so a swap costs one pass and no allocation rather than a few hundred
entries for a result that is one integer.

`tests/059-the-camera-cannot-move-the-world.lua` is the proof the whole
arrangement rests on: fifteen hundred ticks with the swap key pressed five
hundred times, every control driven through its range, and the camera panned and
zoomed throughout, produce a simulation checksum identical to a run where nobody
looked. It also asserts the quiet run never touched the camera stream at all —
because if it had, the simulation is reading it, which is the thing the
arrangement exists to prevent.

The duel verdict is not written. It arrives with fencing in phase five, above the
rest of the list.

## Intended behavior

A thing separate from the camera that holds a **subject** and a **verdict** about
that subject, and asks one question every tick: is this still worth watching?

Separate from the camera because "where is the camera" and "who is interesting"
change at completely different rates.

Three ways of watching: **free** (the person is driving), **follow** (the pan
tracks the subject, eased not snapped), and **stakeout** (go to where the subject
is, then *stop*, and watch whatever wanders through for `dwell_seconds`).

Stakeout exists because following is not always the better shot. A camera welded
to a body in a corridor shows a wall going past; a camera parked at a junction
shows the maze working.

The verdict, in order: the subject no longer exists; its duel ended; it arrived
where it had decided to go — the aquarium's version of solving the maze; it has
been idle past `boredom_seconds`; the stakeout elapsed.

Only with `auto swap` on does a verdict cause a swap. With it off the verdict is
still computed and **shown in the panel**, so pressing the swap key is an
informed choice rather than a dice roll.

The next subject comes **from the `camera` stream and only from it**. That stream
is never read by the simulation and the simulation is never read for randomness
by the director. This is the single rule that keeps a session reproducible while
somebody is mashing the swap key.

## Suggested implementation steps

1. Write the director record: subject, generation, mode, verdict, clocks.
2. Write the verdict function as an ordered list of named predicates, so the
   panel can display which one fired.
3. Write the follow easing and the stakeout hold as two rows of a small mode
   table.
4. Write the weighted picker: filter by `same team only`, weight bodies that are
   doing something above bodies standing still, draw one number. Do not sort —
   sorting the whole population for a choice that only needs to be plausible is
   work proportional to the population every swap.
5. Draw the follow marker: a thin ring on the surface beneath the subject, after
   the column and before the body, so it sits on the stone. Without it, a camera
   locked to one of forty identical little guys looks like a camera locked to
   nothing.
6. Test: a run with the swap key pressed a thousand times at random produces the
   same simulation checksum as a run with it never pressed. This is the test that
   proves the camera cannot move the world.

## Related documents and tools

- [The camera and what it watches](../../docs/008-the-camera-and-what-it-watches.md)
- [Open questions](../../docs/026-open-questions.md) — question 1

## Still open

Open question 1. The camera reading is assumed. The fencer's re-engagement delay
is a knob rather than a constant so that setting it to zero produces the other
reading without a rewrite.
