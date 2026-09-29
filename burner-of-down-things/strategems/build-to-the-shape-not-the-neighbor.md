# Strategem: Build to the shape, not the neighbor

A strategem is a data flow pattern that recurs across areas of the project
and has proven useful enough to name. This one was learned splitting the
studio, the switchboard and the story into lettered pieces (801a-d,
901a-d, 902a-d, 905a-d, 1002a-d, 1003a-d, and the rest): a late piece in
one issue often needs what an early piece of a *different* issue will
produce, and that issue may not be built yet.

## What it means

When a piece's blocker is not built, look at what the blocker will
eventually *look like* — its output's fields, arranged the same way it
will really be arranged — rather than waiting on the blocker itself. Write
the piece against that shape, as a plain argument its function takes, and
test it with a small hand-built fixture of the same shape. The piece never
`require`s the blocker module or reaches into a table that does not exist
yet; it only agrees on the shape.

This is the switchboard's own idea (docs/068 — a plan is stations joined
by shape, not by which one happens to exist) turned inward, onto the
project's own construction order.

## The shape

1. **Name what is missing.** A piece's blocker is itself several pieces
   away from existing — not "not built yet" in general, but specifically:
   which of *its* pieces would have to land first.
2. **Write the shape down**, in the piece's own issue file or module
   comment: the blocker's eventual output's field names and their
   arrangement, not how it will compute them.
3. **Take that shape as a plain argument.** The function never reaches for
   the blocker by name; it takes a table (or array, or record) shaped like
   the blocker's output and works only from that.
4. **Test against a fixture of the shape**, built by hand in the test
   file. The fixture *is* the interface's contract, written where anyone
   reading the test can see exactly what is promised.
5. **When the blocker is later built**, feed its real output straight
   through — nothing in the earlier piece changes. Prove this in the
   blocker's own test: call the earlier piece's function on the blocker's
   real output and check it still holds.

## Examples in this project

- **The shape graph and the station table (issues 905a, 902d).** 905a's
  `shape_graph.build(rows)` was built and tested against a three-row
  fixture shaped like a station table, before 902d — the real station
  table — existed. When 902d was built, its real `TABLE` fed straight into
  `shape_graph.build` unchanged; 902d's own test proves it, rather than
  asserting it in prose.
- **The recurrence trigger and mechanism counting (issues 1003a, 1002d).**
  1003a's `strategem_trigger.due(counts, drafted)` was built and tested
  against a fixture counts table, before 1002d — the real mechanism
  counter — existed, and before 1002b (the lesson writer it would
  otherwise have needed) existed either. When 1002d was built, its real
  counts fed straight into `strategem_trigger.due` unchanged; 1002d's own
  test proves it the same way.

## When not to use it

- When the blocker is one piece away and nearly free to build first:
  building the real thing costs less than writing down and testing a
  stand-in for it.
- When the shape itself is the open question — the blocker's own design
  is not settled yet. There is nothing stable to agree on; build the
  blocker first, or leave the piece honestly blocked.
