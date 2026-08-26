# 1009 -- The phase ten demo

**Phase:** 10, the engraving
**Blocked by:** every other issue in phase 10.
**Blocks:** nothing. The capstone.
**Documents:** [the roadmap](../docs/015-roadmap.md)

## Current behaviour

**Done.** `./run-phase-demo 10`.

A session run for real — forty beats, eight turns, commands that work and commands
that cannot, and one turn taken back — so the eight numbers are numbers rather than
invention.

The carving, printed in full, as an animal nobody chose in advance.

Read back into variables by the independent reader, with a table of what went in
beside what came out. Then engraved **again** from what was read, and compared byte
for byte — 1057 against 1057, identical. That second comparison is the one worth
having.

All four creatures on the same eight numbers, so a reader can see that the carving
is the table rather than a picture beside it.

Then one digit typed into the first number, the deformed animal printed, and the
row before and the row after shown so the walls that stopped meeting are on the
page. Then the reader refusing it.

Then where the files are, and the sharing script listing them — each named by its
animal, each validated by actually running the reader.

The wrapper then runs the pair as the two separate **programs** they are, because
the demo calls them as libraries and a person is going to call them as commands.

## Intended behaviour

### What it shows

**A session finishing.** Run one, with commands, refusals, a rollback, and a
final beat, so the statistics are real rather than invented.

**The engraving.** Printed in full, in the terminal, as a creature nobody chose in
advance — the seed picked it.

**Read back into variables**, with the values shown beside the ones that went in.

**Re-engraved from those variables**, and the two files compared **byte for
byte**. Both halves of the round trip, and the second is the one that catches a
reader recovering a value by accident.

**All four creatures**, on the same statistics, so the reader can see that the
carving is the table rather than a picture beside it.

**And then it is broken.** Change one cell by one character and print it again.
The animal visibly deforms — that is the whole argument for the fragility, and a
demo that only asserted it would be asking to be believed.

Then the reader is pointed at the damaged file and refuses, naming the row and
the column.

### The artifact itself

Write the engravings where somebody can open them, and say where. Then hand one
to a friend with the sharing script, and show what that produced.

## Suggested implementation steps

1. Run a real session and gather its statistics.
2. Engrave, print, read back, compare, re-engrave, compare bytes.
3. Print all four creatures on the same numbers.
4. Mangle one cell, print the deformation, and show the refusal.
5. Run the sharing script and print where it put things.
6. Confirm `./run-phase-demo 10`.
