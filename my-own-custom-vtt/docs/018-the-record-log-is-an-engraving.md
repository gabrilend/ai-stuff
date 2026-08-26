# The record log is an engraving

What survives a session is a text file that is also a picture that is also a
spreadsheet.

It carries the statistics of the run that just ended. It is drawn as an ornate
metal carving -- a fish, a bird, a dragon, a mammoth -- and the carving is not
decoration laid over the data. **The carving is the table.** Its lines are the
cell walls. Reading the engraving and reading the database are the same act.

It is bespoke: each record log gets its own creature, and the creature belongs to
that run.

## Where it appears

In the action bar, during play. The strip along the interface that would
ordinarily hold buttons holds this instead, showing the cells of the file itself.
A table's history is visible while the table is playing, engraved, in the
furniture of the room.

This is the one thing in the project that is simultaneously an interface element,
a persistence format, and an artwork, and it is not going to be factored into
three things that are each easier to reason about. It is one thing. Splitting it
would be the obvious engineering instinct and it would destroy the whole idea.

## Two scripts, pointing opposite ways

| Direction | What it does |
| --- | --- |
| **Read** | Takes an engraving and produces variables in code. The parser walks the carving, finds the cells, and pulls the numbers out of them. |
| **Write** | Takes the variables a program is holding and produces a new engraving. Composes the creature around the values it was given. |

They are separate programs and they do not share code, which is the
[generate-then-view split](../strategems/patterns-that-keep-working) appearing
here in an unusually literal form: the writer produces the artifact, the reader
consumes it as a stranger would, and neither can hide a bug inside the other.

The round trip is the test. Write an engraving from a set of values, read it back,
compare the values. Then write it again from what was read, and compare the two
files byte for byte. Anything that fails that is a carving that cannot be trusted
to be a record.

## It is intentionally fragile

Deliberately. Not robustly parsed, not tolerant of whitespace drift, not forgiving
of a hand-edit.

That is a choice, and here is what it buys, because "fragile on purpose" deserves
an argument rather than a shrug:

**The art is a checksum you can see.** If a value comes out the wrong width, the
creature's proportions go wrong -- the wing bends, the ribs no longer meet, the
tail runs long. A person notices instantly, from across the room, without running
anything. A corrupted binary file looks exactly like a good one until something
reads it; a corrupted engraving looks corrupted.

**It cannot be casually hand-edited**, which means it must be regenerated through
the writer. That is *make the tool, not the thing*, enforced by the artifact
itself rather than by a rule somebody has to remember.

**It stays precious.** A format you can safely mangle is a format you mangle.

The failure mode is the honest cost: a record log that gets mangled is a record
log that is gone. That is accepted. Which is what the third script is for.

## Sharing

A third script hands an engraving to somebody else. This is a small thing to
build and it is the reason the format is text and the reason it is one file: the
whole record of a campaign's statistics is something you can paste to a friend,
and they can look at it before they run anything, because it is a picture of a
dragon with numbers in it.

## What is actually in the cells

Eight, decided by looking at what a session produces and taken from what
[the goodbye](../output/goodbye) already said a run should tell about itself.

| Cell | What it counts |
| --- | --- |
| beats | How long it ran, in the unit the simulation counts. |
| turns | How many were declared. A different question. |
| seats | How many people were at the table. A count, not names. |
| commands | How many things were asked for. |
| refused | How many were refused. |
| rollbacks | How many turns were taken back. |
| things | How big the world got. |
| checksum | The world hash at the final beat. |

The ratio of the fourth to the fifth is the most direct evidence there is about
where an interface confuses people. The last is the one that matters most: it says
a replay of this session will reproduce it, and if a replay ever ends on a
different number this is where the two get compared.

The constraint the format puts on that list is real: **a creature has only so many
places to put a number.** The engraving cannot grow a column without being
redrawn, so the set of statistics is small, fixed, and chosen rather than
accumulated. That is a good pressure. Most record formats grow columns until
nobody reads them.

**Names are deliberately not in it.** A seat is a count. Display names are
display-only everywhere in this project, and a record that outlives the evening
must not be keyed on something somebody can change between one evening and the
next.

## What this does not answer

The question this was raised against was whether the *world* persists between
sessions -- whether the tavern the players burned down is still burned next week.
The engraving carries **statistics**, not geometry. A creature with the numbers of
last week's session in it does not contain a map.

So that question is still open, and it is [1.2](016-open-questions.md).

## How it was built, and what that taught

Phase ten is [issues 1001 through 1009](../issues/phase-10-progress.md). The
source is [090-record](../src/090-record.info.md),
[092-canvas](../src/092-canvas.info.md),
[094-creature](../src/094-creature.info.md),
[096-engrave](../src/096-engrave.info.md) and
[097-read-engraving](../src/097-read-engraving.info.md).

### The geometry that makes the fragility work

A creature is a tiling of rectangular chambers, one per cell, and the silhouette
is the boundary of the tiling. Attachments -- fins, wings, legs, a trunk -- hang
off **the wall between two chambers**, never off a column anybody typed.

So a hand-edit that widens a value moves that wall, moves every wall to its right
on that row with it, and leaves the animal lopsided against the rows above and
below. That is the checksum you can see, and it only works because the anatomy is
defined in terms of the table.

Ornament is drawn with plain characters and never with wall characters, because a
fin that closed a rectangle would read as a chamber. Nothing may touch a wall: the
canvas counts it when something does, the tests insist on zero, and the writer
refuses to emit a carving with holes in it.

### A drawing tells you what is wrong with it, and no test does

The first render put an eye inside a chamber and it ate the last letter of a
label -- "seats" became "seato". The mammoth had six legs, because a leg was drawn
under every chamber of a band that has three.

Neither was reachable from an assertion anybody would have thought to write. Both
were obvious the instant somebody looked at the output. That is the argument for
this format restated from the inside, and it is also an argument for looking at
your own output before writing tests about it.

### Truncating quietly lies about where the fault is

The reader's text buffers were sized to the label, and a chamber's interior is as
wide as the wider of its label and its value, plus padding. So "rollbacks" came
back as "rollback" and a sixteen-digit checksum as fifteen -- and the failure
surfaced two layers away as *this carving has no chamber labelled rollbacks*,
which is a true sentence pointing at entirely the wrong thing.

It refuses rather than truncating now. Fragile is not the same as unhelpful.

### Two alphabets forced a better reader

The plain alphabet cannot tell a corner from a crossing -- a plus sign is every
junction there is -- so the chamber scan could not depend on recognising corner
characters and had to be written as geometry: four unbroken walls, exactly four
rows, and no stroke anywhere inside.

That version is simpler than the one it replaced, and it reads a creature nobody
has written a rule for.

## Read next

- [Content is generated](013-content-is-generated.md) -- the other place in this
  project where a description becomes an artifact through a writer nobody
  bypasses.
- [The sprite studio](017-the-sprite-studio.md) -- the same shape again, with a
  pool and a person's judgment attached.
