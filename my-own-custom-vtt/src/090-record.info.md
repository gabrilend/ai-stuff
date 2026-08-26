# 090-record

The eight numbers a session tells about itself, and nothing else.

| Cell | What it counts | Drawn to hold |
| --- | --- | --- |
| `beats` | How long it ran, in the unit the simulation counts | 8 digits |
| `turns` | How many were declared — a different question from beats | 6 |
| `seats` | How many people were at the table | 3 |
| `commands` | How many things were asked for | 7 |
| `refused` | How many were refused | 7 |
| `rollbacks` | How many turns were taken back | 4 |
| `things` | How big the world got | 6 |
| `checksum` | The world hash at the final beat | 16 hex, always |

## The list is small because the format makes it small

A creature has only so many places to put a number, and the engraving cannot grow
a column without being redrawn. That is a good pressure. Most record formats grow
columns until nobody reads them, because adding one costs nothing at the moment
of adding — here it costs a redrawn animal.

## What is not in it

**Names.** A seat is a count. Display names are display-only everywhere in this
project and a record that outlives the evening must not be keyed on one.

**Geometry.** This carries statistics, not a map. A creature with last week's
numbers in it does not contain the tavern the players burned down. Whether the
world persists between sessions is open question 1.2 and this does not answer it.

## The widths are chosen, not derived from the type

`record_widest_value` is what the tiling is built from, so the creature has the
**same shape for every run**. A session with small numbers and a session with
large ones produce the same animal — otherwise every run would be a different
shape for reasons that have nothing to do with the run, and a deformation would
stop meaning anything.

They are also smaller than the types allow. A column sized for a value nobody
will ever reach is a chamber that is mostly empty in every engraving anybody
looks at.

## The checksum is a fixed sixteen digits

Always, including when it is zero. A number that is sometimes fifteen columns and
sometimes seventeen is a creature that changes shape for no reason.

It is the one that matters most: it says a replay of this session will reproduce
it, and if a replay ever ends on a different number this is where the two get
compared. It is also the widest value, so it is what stresses the layout.

In a `--release` build the world hash compiles out and reads as zero. That is
honest rather than broken — an engraving from a release build carries a zero
checksum and says so by being zero. The alternative, a second hash function
existing only for this, would be a number nobody had ever compared against
anything.

## The seed belongs to the run

`record_gather` folds the session seed with the final beat, so two sessions from
one seed that ran different lengths get different animals. They are different
runs, and the carving belongs to the run.

## Functions

| Function | Takes | Gives |
| --- | --- | --- |
| `record_label` | a cell | its word, or `(not a cell)` |
| `record_value_text` | a record, a cell, a buffer | the length, and the text |
| `record_widest_value` | a cell | how many characters it is drawn to hold |
| `record_gather` | a finished session, a seat count | nothing; the record is filled |

`seats` is passed in rather than read, because the session does not own the
viewer set — the server does, and a session run by a test has none.

## Related

- [094-creature](094-creature.info.md) — how eight cells become an animal
- [096-engrave](096-engrave.info.md) — the writer
- [the record log is an engraving](../docs/018-the-record-log-is-an-engraving.md)
- issue [1001](../issues/completed/1001-what-is-in-the-cells.md)
