# 102 -- The world is flat arrays

**Phase:** 1, the world holds still
**Blocked by:** [101](101-the-arithmetic-is-integers.md), for the coordinate type.
**Blocks:** every record that lives in the world.
**Documents:** [the world and its tick](../../docs/004-the-world-and-its-tick.md)

## Current behaviour

Nothing exists.

## Intended behaviour

One structure holding the whole world as contiguous arrays, and the allocator
that manages them.

Every category of thing is one block of records. A reference to a record is a
`uint32_t` index into its block. There are no pointers between world records, and
nothing in the world is ever null.

The blocks, each with a count and a capacity:

| Block | Holds | Defined in |
| --- | --- | --- |
| `things` | Bodies, props, doors -- everything that stands in the space | [103](103-a-thing-is-one-record.md) |
| `walls` | Sight- and movement-blocking segments | [104](104-walls-are-segments.md) |
| `regions` | Named areas, nesting | [105](105-regions-nest.md) |
| `vertices` | The shared pool region boundaries index into | [105](105-regions-nest.md) |
| `strings` | The shared pool names index into | [106](106-names-live-in-one-pool.md) |
| `lights` | Light sources, each attached to a thing | [104](104-walls-are-segments.md) |
| `scopes` | Who commands what | phase 6, [601](601-a-scope-is-a-record.md) |
| `viewers` | Connected participants | phase 4, [402](402-a-session-is-a-socket.md) |

Phase 1 builds the block machinery for all of them and populates only the first
six. The later ones exist with a count of zero, which is a normal state and not a
placeholder.

**Index 0 of every block is a reserved empty record**, zero-filled, never
allocated to anything. Code that reads index 0 gets the empty record and
proceeds. This is what makes "nothing in the world is ever nil" true rather than
aspirational -- there is no null to check because zero has a meaning.

Growth reallocates and moves the block. This is why references are indices: a
pointer held across a growth is a bug that appears only when a session gets busy.

## Suggested implementation steps

1. Write the block as one generic thing -- element size, count, capacity, growth
   policy -- rather than eight hand-written copies. Eight copies drift.
2. Allocate index 0 at creation and zero it. Assert, in the validator rather than
   at every use, that nothing has claimed it.
3. Make allocation return an index and never a pointer. A function that returns a
   pointer into a block is a function that will be held onto.
4. Provide accessors that take a block and an index and bounds-check in debug
   builds only. In release the bound is guaranteed by the validator.
5. Decide and write down the growth policy. Doubling is the obvious answer; the
   reason it is written down is that a session's peak thing-count is a number
   somebody will want to preallocate from later.
6. Write the companion `.info.md`.

## What this deliberately does not do

No serialisation -- that is [108](108-a-world-writes-itself-down.md). No
validation -- that is [107](107-the-validator-refuses-to-guess.md). This file is
storage and nothing else.
