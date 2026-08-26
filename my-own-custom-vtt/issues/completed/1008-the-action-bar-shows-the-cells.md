# 1008 -- The action bar shows the cells

**Phase:** 10, the engraving
**Blocked by:** [1005](1005-the-reader-reads-the-picture.md)
**Blocks:** [1009](1009-the-phase-ten-demo.md)
**Documents:** [the record log is an engraving](../../docs/018-the-record-log-is-an-engraving.md),
[the three programs](../../docs/002-the-three-programs.md)

## Current behaviour

**Done.** The bridge reads the engraving once at startup and serves it at
`/engraving`; the view fetches it and hangs it in a strip at the bottom right.

One more row in a fixed table, which is not the same as adding a directory — the
table is still matched by exact path, so `..` remains a question the bridge cannot
be asked. Verified: `/engraving` answers 200 and `/../etc/passwd` answers 404.

A missing engraving is not an error. The bridge serves a sentence saying the table
has no history yet, which is true of a first session — and a bar that showed
nothing would be indistinguishable from a bar that failed to load.

The view shows the carving and does **not** parse it into a table and re-render
it. This is simultaneously an interface element, a persistence format and an
artwork, and it is one thing.

The server writes the carving as the last thing it does, so the next bridge to
start hangs the last session's evening on the wall.

## Intended behaviour

**In the action bar, during play.** The strip along the interface that would
ordinarily hold buttons holds the engraving instead, showing the cells of the
file itself.

A table's history is visible while the table is playing, engraved, in the
furniture of the room.

### It is the previous run's engraving

The current session has not ended and has no statistics yet. What hangs on the
wall is what the last session left, which is exactly what a carving on a wall is.

### How it gets there

The bridge serves it. It is a text file, the bridge already serves a fixed table
of files on loopback, and adding one more entry to a fixed table is not the same
as adding a directory — which is a question this project would rather never be
asked.

The bridge reads it once at startup. A missing engraving is a bar that says the
table has no history yet, which is true of a first session and is not an error.

### It is one thing, and stays one thing

This is simultaneously an interface element, a persistence format, and an
artwork. It is not going to be factored into three things that are each easier to
reason about. Splitting it would be the obvious engineering instinct and it would
destroy the whole idea.

So the browser does not parse it into a table and re-render it. It shows the
carving.

## Suggested implementation steps

1. A route on the bridge serving the engraving as plain text.
2. An action bar in the view, monospaced, holding the carving.
3. Say plainly when there is none rather than showing an empty bar.
4. Test that the route refuses anything outside the fixed table, as before.
