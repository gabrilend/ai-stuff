# 104 — The world is flat arrays

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 101 |
| Blocks | 105, 112, 201, 304 |
| Reads | [the tick and the timers](../../docs/003-the-tick-and-the-timers.md) |
| Open questions | F2 |

## Current behavior

Built. `src/030-the-world.lua` allocates the world once from `LAYOUT` -- the unit,
cell, team and stream groups, each field a zero-filled foreign array one longer
than its capacity -- validates it against the same table, and claims and
releases a pool's rows. It also holds the loader every module uses to find
another by stem. The phase 1 program's world suites hold, including a new one
for claiming, releasing, the capacity refusal and a slot that is not a number.

## Intended behavior

The world is allocated **once**, before the first tick, as a set of flat
arrays, and nothing is allocated during a match. Every kind of thing the
simulation holds — units, cells, teams, factories, patterns and their points,
shots in flight, bones, queued commands, counters, streams — is a group of
parallel arrays, one array per field, sized to a capacity from the parameters.

**The layout is data.** One table lists every group, every field in it, and the
field's type — integer or double. The allocator reads that table to build the
arrays; the validator reads it to check them; the snapshot's hash walks it; the
handheld port reads it to declare its boxes. There is no second description of
the world anywhere.

Three rules, none negotiable:

- **Zero is nothing.** A unit with no target holds zero; a cell with no owner
  holds zero; a factory with no line holds zero. Slot zero of every array is
  never used, so that an id of zero can mean "no such thing" without a check.
  Every array is allocated one longer for it.
- **Nothing is nil.** Every array is filled with zeros at allocation, and
  `validate(world)` walks every field of every group and refuses if any slot
  holds anything but a number, or any array is not its declared length.
- **Capacity is a refusal, not a resize.** A spawn past capacity is an error
  that names the group; the arrays never grow during a match, because a resize
  on one worker while another reads is the class of bug the thread pool exists
  to make impossible.

The arrays are foreign-function arrays of the declared type, because the whole
simulation is arithmetic over them and that is what LuaJIT is fast at. Which
fields are doubles is exactly the list F2 will visit if the two targets
disagree: switching positions to fixed-point integers is changing type names in
one table.

The world also carries a handful of scalars: the current tick, the live count
of each group, and the seed.

## Suggested implementation steps

1. Claim the file with `./new-source-file --summary "Allocates the world once, as flat arrays." the-world`.
2. Write the layout table: for each group, a name, a capacity key in the
   parameters, and an ordered list of `{field, type}` pairs. Take the unit's
   fields from the unit document, the cell's from the economy document, the
   rest from the tick document's system list.
3. Write `allocate(parameters)`: for each group, for each field, one
   zero-filled array of the declared type and capacity plus one.
4. Write `validate(world)`: lengths, types, and the rule that the live count of
   every group is within its capacity.
5. Write the one function that claims a free slot in a group and the one that
   releases it, so that no other module ever touches a live count directly.
6. Fill the companion with the layout table reproduced as a table, because the
   companion is where a reader looks for a record's fields.

## What happened

- **The world raises its own field.** The tests allocate a world and then read
  `world.field` and stand units on its land, so `allocate` raises the field
  through the dunes from `parameters.field` and `parameters.seed` and validates
  it. Issue 105's `assemble` therefore only adds what a match needs beyond that.
- **An absent seed is the seed zero.** The phase 1 world suite allocates with no
  seed. Rather than refuse it, an absent seed takes the world's own rule for
  every empty thing: zero is nothing, and nil is never stored.
- **Two kinds of group.** A *pool* (units) has stable ids for a row's life, and
  a released row is zeroed and its id reused last-released-first from a stack in
  the world, so the order is the same on every machine; a *fixed* group (cells,
  teams, streams) has every row for the whole match. Walkers go from one to the
  pool's `top`, checking `alive`.
- **The layout holds what this phase and the unit document name**: the unit's
  fields from the unit document and the tests' contract, the cell's ownership
  fields, the team's treasury, and the stream rows. Patterns, shots, bones,
  factories, the command queue and the rest are added by the issues that build
  them, under the names the tests document gives; the tests document now says
  so.
- **`claim_by`, not `claiming`.** Issue 112's table calls the claimant
  `claiming`; the cloud test reads `world.cell.claim_by`, and the tests are the
  contract, so the layout uses `claim_by`.
- **The loader lives here.** Every module that needs another must find it by
  stem, and a file cannot use the loader to find the loader; the world is the
  module everything already reaches, so `load` and `load_asset` are its exports
  and the few modules that need a sibling find the world first by the same
  rule. Loaded modules are kept under their paths, so a stem is one table.
- **The world carries a reference to its own layout**, so the snapshot and
  anything else holding a world can walk it without loading this file.
- **Counters are small tables, not flat arrays.** The tests read
  `world.claim.period`; `COUNTERS` is the one table saying where each counter
  lives and where its period comes from, and the tick and the hash walk it.

## Related documents and tools

- [The tick and the timers](../../docs/003-the-tick-and-the-timers.md)
- [A unit and what it carries](../../docs/004-a-unit-and-what-it-carries.md)
- [The shape of the code](../../docs/013-the-shape-of-the-code.md)
- The test program: [the dunes and the clock](../../tests/019-the-dunes-and-the-clock.lua)

## Still open

- F2: whether double-precision arithmetic agrees between a desktop processor
  and the handheld's cores. Awaiting evidence from running one match on both;
  the layout table is where the answer lands.
