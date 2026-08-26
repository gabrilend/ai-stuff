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

## The scale, now settled

**The simulation counts metres.** A position is an `int32_t` in units of 1/1024 of
a metre: range about ±2,100 kilometres, precision about a millimetre. Nothing in
the server has ever heard of a foot.

**The picture speaks feet**, rounded to the nearest foot, converted by the
renderer on its way to the screen.

The consequence phase 1 has to build in from the start:
[101](101-the-arithmetic-is-integers.md) writes the metre constant with its
reasoning beside it, and **no conversion function belongs anywhere in the
server**. The foot exists in the view and only in the view, because a command
carrying rounded feet would let two clients that round differently disagree about
where a body went.

## Blocking open questions

One remains, in [open questions](../docs/016-open-questions.md):

- **1.2** — does the *world* persist between sessions? Statistics now do, as
  [the engraving](../docs/018-the-record-log-is-an-engraving.md), but an engraving
  carries numbers and not geometry. If the world persists too, the snapshot format
  in [108](108-a-world-writes-itself-down.md) stops being a debugging convenience
  and becomes a long-lived format needing a version story and a migration path.

It does not block starting. It blocks finishing 108, because it changes what that
format is obliged to promise.

**Settled since these issues were written:** 1.1, the scale, answered above.
