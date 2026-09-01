# 704 — A Golem Changes The Stone

| | |
| --- | --- |
| Phase | 7 — The Delve |
| Blocked by | 101, 303, 701 |
| Blocks | 707 |
| Reads | [the monsters of the delve](../docs/023-the-monsters-of-the-delve.md) |
| Open questions | 9 (does broken stone stay broken) |

## Current behavior

The stone is generated and never changes. Everything downstream has been written
not to assume that, and this issue is where that pays off.

## Intended behavior

The stone golem is not standing in the corridor. It **is** corridor, walking.

Its locomotion is `lumbering`: a raised climb limit, and the ability to break a
wall rather than route around it. A golem that meets stone it cannot climb clears
the bits and walks through, and the affected columns' surfaces are recomputed on
the spot.

**It is the only thing in the project that changes the stone after generation**,
and it is the reason for two decisions made in phase one that cost nothing at the
time:

- The surface array is *recomputed* from the columns rather than assumed
  constant. Issue 102.
- Nothing anywhere caches the surface graph as an adjacency list. Issue 107. A
  cached graph would be a second copy of the maze to invalidate here, and there
  is no version of that which does not eventually disagree with the stone.

The component labels **do** need recomputing, and that is the one expensive
consequence. A golem breaking through a wall may join two components or split
one. Relabelling the whole maze on every broken block is too much; relabelling
lazily, when a label is next consulted and the stone has changed since, is the
approach — with a dirty flag and a version counter.

**Its solution is to be held still.** Nothing a party carries hurts stone. An
entangled golem stops, and a stopped golem is a wall — standing somewhere it was
not before, which is occasionally exactly where a party wanted one.

## Suggested implementation steps

1. Write the `lumbering` row: striding, with the climb limit from the creature
   row and a break action when blocked.
2. Write `break_stone(store, cell, layer)`: clear the bit, recompute that
   column's surfaces and its four neighbours', mark the label version dirty.
3. Write lazy relabelling behind the label accessor.
4. Write the held state as a record referencing two bodies with generations, the
   same shape as a duel.
5. Count blocks broken, relabels performed, and the component count over time
   into the report. A component count that changes is the interesting number in
   this whole phase.
6. Test: a golem walled into a box escapes. A maze after a thousand golem-ticks
   still passes every validator check except the height-shaped one, which is
   expected to fail — and the validator takes a flag saying so, rather than the
   test being deleted.

## Related documents and tools

- [The monsters of the delve](../docs/023-the-monsters-of-the-delve.md)
- [A column is one integer](101-a-column-is-one-integer.md)

## Still open

Open question 9: over a long run the maze slowly becomes a field. Does it heal?
Is there a budget? Does a maze the validator would now reject matter?
