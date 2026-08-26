# Phase 1 — The world holds still

**Goal:** a world that can be described, held, checked, and round-tripped. No
network, no sight, no rules, no clock.

**Status: complete.** All nine issues are done and in `completed/`. The build
runs, 3,412 checks pass, and `./run-phase-demo 1` shows the phase working.

## The issues

| Issue | What it established |
| --- | --- |
| [101 the arithmetic is integers](completed/101-the-arithmetic-is-integers.md) | Fixed point, so a replay reproduces on any machine. |
| [102 the world is flat arrays](completed/102-the-world-is-flat-arrays.md) | Contiguous blocks and indices, so a snapshot is a copy and threading is arithmetic. |
| [103 a thing is one record](completed/103-a-thing-is-one-record.md) | One record for a goblin and a coffee cup. |
| [104 walls are segments](completed/104-walls-are-segments.md) | Geometry that can be asked questions, which a picture cannot. |
| [105 regions nest](completed/105-regions-nest.md) | Named areas, so an abstract scope is addressable. |
| [106 names live in one pool](completed/106-names-live-in-one-pool.md) | The one place a human-readable string enters the world. |
| [107 the validator refuses to guess](completed/107-the-validator-refuses-to-guess.md) | Every invariant the rest of the program skips checking. |
| [108 a world writes itself down](completed/108-a-world-writes-itself-down.md) | A versioned, long-lived format that round-trips byte for byte. |
| [109 the phase one demo](completed/109-the-phase-one-demo.md) | The capstone, which shows the numbers and the refusals. |

## What is built

`./build` generates the trigonometry tables, compiles nine modules, checks the
compiled objects for floating-point instructions, builds the demo, and runs the
tests.

| Source | What it is |
| --- | --- |
| `020-test-harness.h` | Three macros and a counter. Does not stop at the first failure. |
| `021-fixed-point` | Every arithmetic operation the world may use. Tables generated at build time. |
| `023-blocks` | One contiguous run of records, with the index-0 sentinel and a free list threaded through the freed records. |
| `025-strings` | The append-only name pool that never grows, so a read's pointer stays valid. |
| `027-world` | The records and the blocks that hold them. |
| `029-geometry` | The questions a segment can answer that a picture cannot. |
| `031-region` | Which region, and the walk up the parent chain. |
| `033-validate` | The pass that makes every later assumption true. |
| `035-worldfile` | The versioned format, and the world hash. |
| `037-fixture` | Two rooms, a corridor, a cellar, a pillar, a door. |
| `039-demo-phase-1` | The capstone. |

## What building it taught

**The floating-point ban is checked, not trusted.** The build disassembles every
compiled object and fails if it finds a floating-point instruction. A comment
saying "no floats here" is a wish; this is the check, and it costs nothing.

**Two documents disagreed about a flag bit.** Sight and movement were numbered
one way for bodies and the other way for walls. Nothing would have looked wrong
in either file, and the symptom would have been a curtain you cannot walk through
and a wall you can see past. They are one shared pair of constants now, a test
asserts it, and both documents were corrected — the mistake was in the prose, so
that is where it got fixed.

**The records pack with no padding**: 36, 24, 16, 8, and 20 bytes, asserted by a
test. This matters because the world file writes fields one at a time precisely
so a compiler's padding never reaches the disk.

**The broad-phase index moved to phase 2**, where its only callers live. An index
built with no caller to shape it is an index built against the wrong query.

**`truncate` and `M_PI` are not C99.** Both were reached for out of habit and
both were replaced with something the standard actually guarantees, which is
cheaper than discovering it on a machine that does not have them.

## What the numbers came out as

Reported by the demo rather than fixed here, because a document with a hard-coded
measurement in it becomes wrong without anybody noticing. As of the phase's
close, on the two-room fixture: validation about 7 microseconds a pass; 864 bytes
in memory against 972 on disk; the round trip byte-identical.

## Open questions settled during the phase

- **1.1** — the simulation counts metres; the view speaks whole feet and converts
  on its way to the screen, never back.
- **1.2** — the world persists between sessions, which is why the file format is
  versioned from its first commit.

## What phase 2 inherits

A world that holds still, a fixture with a pillar to cast shadows around, a
corridor to be out of sight in, and a validator that will catch the moment the
motion pass starts letting a body's region field drift.
