# Phase 1 — The world holds still

**Goal:** a world that can be described, held, checked, and round-tripped. No
network, no sight, no rules, no clock.

**Status:** in progress. Five of nine issues are complete and the code for them
builds and passes its tests.

## The issues

| Issue | State | What it is for |
| --- | --- | --- |
| [101 the arithmetic is integers](completed/101-the-arithmetic-is-integers.md) | **done** | Fixed point, so a replay reproduces a session on any machine. |
| [102 the world is flat arrays](completed/102-the-world-is-flat-arrays.md) | **done** | Contiguous blocks and indices, so slicing across threads is arithmetic and a snapshot is a write. |
| [103 a thing is one record](completed/103-a-thing-is-one-record.md) | **done** | One record for a goblin and a coffee cup, which is what makes the control dial one mechanism. |
| [104 walls are segments](completed/104-walls-are-segments.md) | **done** | Geometry that can be asked questions, which a picture cannot. |
| [105 regions nest](105-regions-nest.md) | not started | Named areas, so an abstract scope is addressable. |
| [106 names live in one pool](completed/106-names-live-in-one-pool.md) | **done** | The one place a human-readable string enters the world. |
| [107 the validator refuses to guess](107-the-validator-refuses-to-guess.md) | not started | Establishes every invariant the rest of the program skips checking. |
| [108 a world writes itself down](108-a-world-writes-itself-down.md) | not started | Snapshot out, snapshot in, byte-identical, versioned from the first commit. |
| [109 the phase one demo](109-the-phase-one-demo.md) | not started | The capstone. Shows the numbers and proves the round trip. |

## What is built and running

`./build` generates the trigonometry tables, compiles five modules, checks the
compiled objects for floating-point instructions, and runs the tests.

| Source | What it is |
| --- | --- |
| `020-test-harness.h` | Three macros and a counter. Does not stop at the first failure. |
| `021-fixed-point` | Every arithmetic operation the world may use. Tables generated at build time by `021-sine-table-generator.c`. |
| `023-blocks` | One contiguous run of fixed-size records, with the index-0 sentinel and a free list threaded through the freed records. |
| `025-strings` | The append-only name pool that never grows, so a read's pointer stays valid. |
| `027-world` | The records and the blocks that hold them. |
| `029-geometry` | The questions a segment can answer that a picture cannot. |

## What building it taught

**The floating-point ban is checked, not trusted.** `./build` disassembles every
compiled object and fails if it finds a floating-point instruction. A comment
saying "no floats here" is a wish; this is the check, and it costs nothing.

**Two documents disagreed about a flag bit.** The sight and movement flags were
numbered one way for bodies and the other way for walls. Nothing would have
looked wrong in either file, and the symptom would have been a curtain you cannot
walk through and a wall you can see past. They are now one shared pair of
constants, a test asserts it, and both documents were corrected.

**The records pack with no padding**, which was hoped for and is now asserted —
36, 24, 16, 8, and 20 bytes. This matters because the world file writes fields
one at a time precisely so a compiler's padding never reaches the disk, and a
record that silently grows a hole should fail a build rather than a load.

**The broad-phase index moved to phase 2.** It was listed in
[104](completed/104-walls-are-segments.md) and its only two consumers — the sight
sweep and collision — are both later. An index built with no caller to shape it
is an index built against the wrong query.
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
