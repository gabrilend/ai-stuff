# 104 — The world is flat arrays

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 101 |
| Blocks | 105, 112, 201, 304 |
| Reads | [the tick and the timers](../docs/003-the-tick-and-the-timers.md) |
| Open questions | F2 |

## Current behavior

Nothing. The record shapes are described across the design documents — the
unit in one, the cell in another, the roster in a third — and no memory holds
them. The phase 1 test program looks for a source file whose stem is
`the-world` and reports its absence by name.

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

## Related documents and tools

- [The tick and the timers](../docs/003-the-tick-and-the-timers.md)
- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- [The shape of the code](../docs/013-the-shape-of-the-code.md)
- The test program: [the dunes and the clock](../tests/019-the-dunes-and-the-clock.lua)

## Still open

- F2: whether double-precision arithmetic agrees between a desktop processor
  and the handheld's cores. Awaiting evidence from running one match on both;
  the layout table is where the answer lands.
