# 1001 -- What is in the cells

**Phase:** 10, the engraving
**Blocked by:** phase 9 complete.
**Blocks:** everything else in phase 10.
**Documents:** [the record log is an engraving](../docs/018-the-record-log-is-an-engraving.md)

## Current behaviour

**Done.** Eight cells, in `090-record`, gathered from a finished session.

The widths each can reach are written down beside them, because the tiling is
built from those rather than from the values in hand — so a session with small
numbers and a session with large ones produce **the same shaped creature**.
Otherwise every run would be a different animal for reasons that have nothing to
do with the run, and a deformation would stop meaning anything.

They are also smaller than the types allow. Eight digits of beats is nineteen days
of continuous play; a column sized for a value nobody will ever reach is a chamber
that is mostly empty in every engraving anybody looks at.

`rollbacks` needed a counter on the session, because the command log records what
was DECLARED and a rollback is not a declaration — there is nothing in the log to
count afterwards. It is incremented after the restore succeeds, so a rollback that
could not restore is not counted as one that did.

The checksum is a fixed sixteen digits including when it is zero. In a release
build the world hash compiles out and reads as zero, which is honest rather than
broken — the alternative, a second hash function existing only for this, would be
a number nobody had ever compared against anything.

A session that did nothing produces a record saying so, and there is a test for
it: every count is zero and the world's size is not, which is what tells a record
of an empty evening from a record that was never gathered.

**And an off-by-one the first real session caught.** Seats came from the viewer
set's count, which includes the reserved sentinel at index 0 — so a table with
nobody at it reported one seat. Nothing found that; the first carving a running
server produced did.

## Intended behaviour

**A fixed, small, chosen set of statistics.** Not accumulated — chosen.

### The constraint is the format, and it is a good one

A creature has only so many places to put a number. The engraving cannot grow a
column without being redrawn, so the list is small and stays small.

That pressure is worth naming as a feature. Most record formats grow columns
until nobody reads them, because adding one costs nothing at the moment of
adding. Here it costs a redrawn animal.

### The candidates

[The goodbye](../output/goodbye) already lists them, and it was written before any
of this existed, which makes it the honest source rather than a guess made now:

| Cell | Why it earns a place |
| --- | --- |
| beats | How long it ran, in the unit the simulation actually counts. |
| turns | How many were declared. A different question from beats. |
| seats | Who was at the table. The number, not the names — a name is display-only and does not belong in a durable record. |
| commands | How many things were asked for. |
| refused | How many were refused. The ratio of these two is the most direct evidence there is about where the interface confuses people. |
| rollbacks | How many turns were taken back. |
| things | How big the world got. |
| checksum | The world hash at the final beat. |

### The checksum is the one that matters most

It is the number that says a replay of this session will reproduce it. If a
replay ever ends on a different number, the engraving is where the two get
compared — which means it has to survive the round trip exactly, and it is the
widest value in the table, and therefore the one that stresses the layout.

### What is NOT in the cells

**Names.** A seat is a count. Display names are display-only everywhere in this
project and a record that outlives the evening must not be keyed on one.

**Geometry.** The engraving carries statistics, not a map. A creature with last
week's numbers in it does not contain the tavern the players burned down. Whether
the world itself persists is open question 1.2 and this does not answer it.

## Suggested implementation steps

1. A record structure holding exactly these values, with the widths each can
   reach written down beside them — the layout depends on knowing the widest.
2. Gather it from a finished session: the world, the command log, the viewer set.
3. Write the companion `.info.md`, listing the cells — that listing is the
   contract the carving is drawn around.
4. Test that a session that did nothing produces a record saying so, rather than
   an empty one.
