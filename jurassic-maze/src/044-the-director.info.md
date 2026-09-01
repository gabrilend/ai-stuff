# 044-the-director

Decides what is worth watching and when it stops being.

**Not built yet.** The file exists and is empty, holding its index in the reading
order so that the numbering does not have to shift when it is filled in.

## What it will be

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
[issue 407](../issues/407-the-director-decides-what-is-worth-watching.md) and
[issue 408](../issues/408-the-panel-and-its-sliders.md).

## The one rule it must not break

It picks its next subject **from the `camera` stream and only from it**. That
stream is never read by the simulation, and the simulation is never read for
randomness by the director.

This is what keeps a session reproducible while somebody is mashing the swap key:
the maze does not care that you are watching. `tests/052-layering.lua` already
greps for the violation, and the test that will prove it is a run with the key
pressed a thousand times at random producing the same simulation checksum as a
run where it was never pressed.

## An open question it is waiting on

Whether *"the fencing guys should be able to swap to a different target"* means
the camera swaps to a different fencer, or the fencer swaps to a different
opponent. Both are cheap, both are worth having, and neither is built on a guess.
See [open questions](../docs/026-open-questions.md), question 1.
