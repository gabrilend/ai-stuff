# Phase 1 — The world holds still

**Goal:** a world that can be described, held, checked, and round-tripped. No
network, no sight, no rules, no clock.

**Status:** not started. All nine issues are written and none is implemented.

## The issues

| Issue | State | What it is for |
| --- | --- | --- |
| [101 the arithmetic is integers](101-the-arithmetic-is-integers.md) | not started | Fixed point, so a replay reproduces a session on any machine. |
| [102 the world is flat arrays](102-the-world-is-flat-arrays.md) | not started | Contiguous blocks and indices, so slicing across threads is arithmetic and a snapshot is a write. |
| [103 a thing is one record](103-a-thing-is-one-record.md) | not started | One record for a goblin and a coffee cup, which is what makes the control dial one mechanism. |
| [104 walls are segments](104-walls-are-segments.md) | not started | Geometry that can be asked questions, which a picture cannot. |
| [105 regions nest](105-regions-nest.md) | not started | Named areas, so an abstract scope is addressable. |
| [106 names live in one pool](106-names-live-in-one-pool.md) | not started | The one place a human-readable string enters the world. |
| [107 the validator refuses to guess](107-the-validator-refuses-to-guess.md) | not started | Establishes every invariant the rest of the program skips checking. |
| [108 a world writes itself down](108-a-world-writes-itself-down.md) | not started | Snapshot out, snapshot in, byte-identical. |
| [109 the phase one demo](109-the-phase-one-demo.md) | not started | The capstone. Shows the numbers and proves the round trip. |

## What this phase is really establishing

Three decisions, each of which every later phase depends on and none of which can
be revisited cheaply once there is code on top of them:

**Integers instead of floating point.** Because the tick has to be deterministic
for a replay to mean anything, and a compiler is allowed to reassociate and fuse
floating-point arithmetic in ways that change the last bit differently on
different machines.

**Indices instead of pointers.** Because it makes a snapshot a write rather than a
graph walk, and makes handing a range of records to a thread pool a matter of
arithmetic.

**One validator instead of ten thousand null checks.** Every later phase's right
to skip checking is bought here, once.

## What the answers since changed

**The scale is settled.** The simulation counts thousandths of a metre; the view
speaks whole feet and does the conversion on its way to the screen. No conversion
function belongs anywhere in the server, because a command carrying rounded feet
would let two clients that round differently disagree about where a body went.

**The world persists between sessions**, which is the one that reshaped an issue
rather than filling in a constant. [108](108-a-world-writes-itself-down.md) is no
longer a debugging convenience -- it is a long-lived format, and it needs its
version number and its migration chain built in from the first commit. The first
world file saved without one is the first world file that cannot be migrated.

**Turns can be rolled back**, which reaches back into phase 1 in a smaller way:
rollback takes a world snapshot at the head of every turn, constantly, during
play. So [108](108-a-world-writes-itself-down.md) grows a second path -- an
in-memory block copy that never touches the file encoder -- and a test asserting
the two paths describe the same world.

## Blocking open questions

None remain for this phase. 1.1 and 1.2 are both answered above.

What is left is downstream: the decisions in phase 3 about what a rollback does to
somebody's fog memory ([3.3](../docs/016-open-questions.md)) do not block anything
being built here, but they are the reason the snapshot path exists at all, and
somebody implementing 108 should know what it is for.
