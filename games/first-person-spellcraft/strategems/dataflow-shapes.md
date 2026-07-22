# dataflow shapes — patterns proven building the engine

Shapes that kept working no matter where I pointed them while laying the
SoraMech-style substrate (issues 102a/102b) and the world (103). Written here so
the next area reuses them instead of rediscovering them. Re-read at random.

## The self-checking round-trip

Generate the inputs *deterministically*, push them through the *real* pipeline,
and check the result against an INDEPENDENT recomputation of those same inputs.
The two can only agree if the pipeline lost, duplicated, or torn nothing — so
one test covers the whole path at once, however the threads interleaved.

Proved on the mouse differentials: random deltas summed by the drain-and-sum
boxes matched an authoritative sum computed straight from the seeds. The same
shape will check a spell's rolled damage, the economy's ledger, a puzzle's
solution — anywhere you can compute "the answer" two independent ways, do, and
diff them.

## Build off to the side, publish with one write

Never let a reader see a half-made thing. Assemble the whole record elsewhere,
then hand over the single pointer (or flip the single flag) that makes it
visible. The reader sees old-whole or new-whole, never a seam.

Proved twice already: the latest-wins slot copies a whole struct under its lock,
so the render thread never reads a half-written position; and the sorted index
rebuilds a fresh compact buffer off to the side and swaps it in with one write.
Same move at two scales — one cell, and a whole collection.

## Trigger on ready; wake the neighbours

No central loop. Each unit fires when all its inputs are present, does its work,
then pokes the units it feeds to see if *they* are now ready. The graph turns
itself; a source that re-arms after firing keeps it turning forever.

Proved as the engine's dispatch (with a single-spawn gate and a clear-then-
recheck so no wakeup is missed). It is how the frame clock, the two mice, the
LLM boxes, and the economy ticks will all run — the same firing rule at every
scale of the game.

## Two disciplines of handoff

Ask of every wire: does the reader need *every* value, or only the *latest*?

- Between computers that each matter, QUEUE every value and consume it on use
  (the mouse deltas the pose box drains and sums).
- Into a constant watcher that only wants "now," keep ONE cell and overwrite it,
  read by reference (the player position the renderer peeks each frame).

Conflating them costs you either lost motion or pointless buffering. Proved as
the queue-vs-latest slots between the pose solver and the render thread.
