# 310 — Undo Over a Shared Network

| | |
| --- | --- |
| Phase | 3 — The Tracing Tool |
| Blocked by | 208, 302, 305 |
| Blocks | — |
| Reads | [the tracing mode](../docs/005-the-tracing-mode.md) |
| Open questions | — *(was question 10; answered)* |

## Current behavior

Every action is permanent. A mis-click during a tracing session is repaired by
retracing.

## Intended behavior

**Unlimited undo within a session, built from inverses** — each action records
how to reverse itself rather than a copy of what it changed.

### Two of the four hard cases stopped existing

Undo over a shared-vertex network was going to be awkward because several actions
changed structure in ways no rule could reconstruct.

Cutting and severing are now **exact inverses of each other** — see
[302](302-cutting-and-severing.md) — so the two commonest actions come with their
reversals already written, as gestures a person already has. Undoing a cut is a
sever; undoing a sever is a cut.

Dragging a vertex was always easy: it moves one entry, and every fence into that
corner follows because none of them held a copy.

### The one that is still hard

**Merging two vertices.** It rewrites an unknown number of edge paths to point at
the survivor, and no rule reconstructs which paths were rewritten or what they
said. Its inverse has to record the affected paths explicitly rather than derive
them.

The same applies to the name resolution that a sever forces: undoing must restore
**both** names and the fact that the question was asked, not just the geometry.

### The discipline that makes inverses safe

Recording inverses is smaller and faster than keeping copies, and it has one
failure mode that keeping copies does not: **a missing or wrong inverse is a
corruption that appears only after somebody presses undo**, which is the worst
possible moment to discover one.

So the rule this issue exists to enforce:

> **Every action has a test that performs it, undoes it, and asserts the network
> is byte-identical to before** — using the round-trip writer from
> [201](201-vertices-edges-and-places.md).

That turns *hope every inverse is right* into *the build fails if one is not*. An
action added without such a test is an action that will corrupt somebody's work,
and the test is three lines.

## Suggested implementation steps

1. Define one funnel through which every mutating action passes — nothing edits
   the tables directly.
2. Each action returns its inverse alongside its effect; the funnel pushes that
   onto the undo stack with a name for display.
3. Undo applies the inverse and pushes the action onto a redo stack.
4. For merge, capture the rewritten paths explicitly. For sever, capture both
   names and the resolution.
5. Clear the stack on load, not on save — saving does not make earlier states
   uninteresting.
6. Show the name of what would be undone, so it is never a guess.
7. **Write the round-trip test for every action, without exception.**

## Related documents and tools

- [The tracing mode](../docs/005-the-tracing-mode.md)
- [302 — cutting and severing](302-cutting-and-severing.md)
