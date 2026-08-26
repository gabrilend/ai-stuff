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

Undecided, and it should be decided by looking at what a session produces rather
than by guessing here. The shape of the answer: whatever
[the goodbye](../output/goodbye) writes at the end of a run is the candidate list
-- how long it ran, who was at the table, what they held, where they went, the
world hash at the last tick.

The constraint the format puts on that list is real and worth stating early: **a
creature has only so many places to put a number.** The engraving cannot grow a
column without being redrawn, so the set of statistics is small, fixed, and chosen
rather than accumulated. That is a good pressure. Most record formats grow columns
until nobody reads them.

## What this does not answer

The question this was raised against was whether the *world* persists between
sessions -- whether the tavern the players burned down is still burned next week.
The engraving carries **statistics**, not geometry. A creature with the numbers of
last week's session in it does not contain a map.

So that question is still open, and it is [1.2](016-open-questions.md).

## Read next

- [Content is generated](013-content-is-generated.md) -- the other place in this
  project where a description becomes an artifact through a writer nobody
  bypasses.
- [The sprite studio](017-the-sprite-studio.md) -- the same shape again, with a
  pool and a person's judgment attached.
