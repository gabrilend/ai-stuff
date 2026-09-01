# 044-the-director

Decides what is worth watching and when it stops being.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `new()` | | the director, with every setting the panel can move |
| `update(world, director, camera, Projection, Camera, Walking, dt, w, h)` | | one frame of directing. Moves the camera; touches nothing in the world. |
| `verdict(world, director)` | | which predicate fired, by name, or nil |
| `pick(world, director)` | | a new subject, from the camera stream |
| `free(director)` | | give the camera back |
| `draw_marker(...)` | | a thin ring on the stone beneath the subject |
| `describe(world, director)` | | what the panel says, as lines |
| `CONTROLS` | | the settings, as rows, so the panel is a loop |

## What it is

Separate from the camera, because "where is the camera" and "who is interesting"
are two questions that change at completely different rates. It holds a subject
and a verdict about that subject, and asks one question every tick: is this still
worth watching?

Three ways of watching — **free**, **follow**, and **stakeout**, which goes to
where the subject is and then *stops*, holding that spot for `dwell_seconds`.
Stakeout exists because a camera welded to a body in a corridor shows a wall
going past, and a camera parked at a junction shows the maze working.

The full design is in
[the camera and what it watches](../docs/008-the-camera-and-what-it-watches.md),
and the work is
[issue 407](../issues/completed/407-the-director-decides-what-is-worth-watching.md) and
[issue 408](../issues/completed/408-the-panel-and-its-sliders.md).

## The one rule it must not break

It picks its next subject **from the `camera` stream and only from it**. That
stream is never read by the simulation, and the simulation is never read for
randomness by the director.

This is what keeps a session reproducible while somebody is mashing the swap key:
the maze does not care that you are watching.

`tests/059-the-camera-cannot-move-the-world.lua` proves it. Fifteen hundred
ticks, the swap key pressed five hundred times, every panel control driven
through its whole range, the camera panned and zoomed throughout — and a
simulation checksum identical to a run where nobody looked. It also asserts the
quiet run never touched the camera stream **at all**, because if it had, the
simulation is reading it, and that second assertion is what keeps the first from
being vacuous.

## An open question it is waiting on

Whether *"the fencing guys should be able to swap to a different target"* means
the camera swaps to a different fencer, or the fencer swaps to a different
opponent. Both are cheap, both are worth having, and neither is built on a guess.
See [open questions](../docs/026-open-questions.md), question 1.
