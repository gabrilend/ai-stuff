# Strategem: Spread thin, fold in whole

A strategem is a data flow pattern that recurs across areas of the project
and has proven useful enough to name. This one was learned fanning out
four of the studio, switchboard and story's lettered pieces (801b, 807b,
901b, 1002b) to separate agents in one afternoon, then reading every one
of them back in by hand.

## What it means

One mind — the spreader — holds the whole map: every file, every
convention, every neighboring interface. It uses that to write each
piece's brief down to almost nothing: which one or two documents to read,
which one file to copy style from, and the exact shape of the interface
where one can be stated plainly. Each fanned-out piece works from that
brief alone, never the whole map. When every piece reports back, the same
mind — now the fold-in — reads what actually came back, checks it against
the project's real state, and only then treats anything as finished. The
less specified a brief, the more the piece has to invent, and the more
that invention costs — in tokens spent deliberating, and in what the
fold-in then has to reconcile.

## The shape

1. Hold the whole map yourself before spreading anything. The spreader is
   the only one allowed to know all of it; that is the whole point of
   being the spreader.
2. Distill each piece's brief to the smallest set of files it needs — one
   or two `.info.md`s, never a whole subsystem's docs — and name them by
   path, not by describing their contents in prose.
3. State the interface as plainly as you can. An exact function name and
   signature removes deliberation; an open "pick something reasonable"
   invites it, and the piece spends its budget deciding what you could
   have just told it.
4. Hand the piece one already-built exemplar — a file plus its test — to
   copy conventions from, instead of restating house style in words.
5. Forbid the piece from touching git, the issue tree, or any shared
   counter. Those are single-writer resources; the fold-in is the one
   writer, and only after every piece is in.
6. Verify before accepting: read every diff, rerun every test yourself. A
   piece's own claim that it passed is not the fold-in's evidence — the
   fold-in's own rerun is.
7. Treat a mismatch as an observation, not a bug, unless it is actually
   wrong. A reasonable judgment call made in a corner the brief left open
   gets written into the record (the issue's own Current Behavior), not
   reverted — the ambiguity was the brief's to close, so the fix belongs
   in how the next brief is written, not in undoing this piece's work.

## Examples in this project

- Four pieces, one afternoon (801b, 807b, 901b, 1002b), each handed only
  its own issue file, one or two `.info.md` files, and one file-plus-test
  pair to copy style from. Token cost tracked with how much was left
  open, not with how hard the task looked: tag parsing (901b), whose
  grammar was given exactly, came back clean near its lower bound;
  append-only lessons (1002b), whose on-disk format was never specified,
  cost the most of the four on a same-sized task, because it had to
  invent a shape nothing told it to use and then justify the invention.
- 807b's piece hit a spurious content-policy refusal reading an unrelated
  personal anecdote elsewhere in the environment's own configuration —
  present regardless of how narrow its brief was, since that
  configuration loads for every piece, not something the brief could have
  excluded. Resuming it past the misfire, rather than relaunching fresh,
  kept its already-correct design intact instead of paying its full token
  cost twice for no new information.

## When not to use it

- When the interface itself is the open question. Nothing is settled
  enough to write a plain signature down, and a piece asked to invent one
  will spend its whole budget deliberating what the spreader could have
  just decided in a sentence.
- When a piece needs to reach into several places to make one coherent
  decision — a change that only makes sense if three modules agree with
  each other. That coherence is the spreader's own job; four blind pieces
  cannot average their way into it.
