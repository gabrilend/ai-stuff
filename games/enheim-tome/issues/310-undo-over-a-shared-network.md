# 310 — Undo Over a Shared Network

| | |
| --- | --- |
| Phase | 3 — The Tracing Tool |
| Blocked by | 302, 305 |
| Blocks | — |
| Reads | [the tracing tool](../docs/005-the-tracing-tool.md) |
| Open questions | **10** — whether it is needed, and how deep |

## Current behavior

Every action is permanent. A mis-click during a tracing session is repaired by
retracing.

## Intended behavior

**Working ruling:** unlimited undo within a session. The alternative, during hours
of tracing, is retracing — and the cost of that is what makes the whole campaign
feel like a wall.

### Why this is harder than it looks

Undo over a shared-vertex network is **not a stack of independent edits**.

Dragging one junction touched every edge running into that corner. Undoing it must
restore all of them — and it does, for free, because they never held their own
copies; restoring the vertex restores them all. That case is easy for exactly the
reason [305](305-dragging-a-junction-moves-the-corner.md) was easy.

The hard cases are the ones that change **structure** rather than position:

| Action | What undoing it must restore |
| --- | --- |
| adopting an edge | the block's loop, and the fact that the two blocks were not adjacent before |
| merging two vertices | both vertices, and every edge's path that was rewritten to point at the survivor |
| closing a loop | the block record, and any edges created during the trace |
| deleting a block | the block, and any edges that became stranded and were cleaned up with it |

A merge is the dangerous one: it rewrites paths across an unknown number of edges,
so undoing it needs those paths back rather than a rule for reconstructing them.

### What that decides about memory

Two shapes are possible and they differ in more than performance:

- **record the inverse of each action** — small, fast, and every new action needs
  its inverse written and kept correct forever. A missing inverse is a corruption
  that appears only after an undo.
- **snapshot the affected tables** before each action — larger, dull, and cannot
  be wrong. The network is flat arrays of numbers and a city's worth is a few
  megabytes, so a snapshot per action is affordable for a session.

**Working ruling: snapshot.** This is hand-authoring of irreplaceable work, and
correctness beats economy. If memory ever becomes a real constraint, snapshot only
the tables an action touches rather than switching to inverses.

## Suggested implementation steps

1. Define one funnel through which every mutating action passes — nothing edits
   the tables directly.
2. Before each action, copy the tables it will touch onto an undo stack, with the
   name of the action for display.
3. Undo restores; redo re-applies by keeping the popped states.
4. Clear the stack on load, not on save — saving does not make earlier states
   uninteresting.
5. Show the name of what would be undone, so it is never a guess.
6. Test each structural case in the table above: adopt, merge, close, delete —
   undo each and assert the network is byte-identical to before, using the
   round-trip writer from [201](201-vertices-edges-and-loops.md).

## Related documents and tools

- [The tracing tool](../docs/005-the-tracing-tool.md)
- [Open questions](../docs/012-open-questions.md) — question 10
