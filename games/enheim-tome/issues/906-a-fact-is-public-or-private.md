# 906 — A Fact Is Public or Private

| | |
| --- | --- |
| Phase | 9 — The Scene |
| Blocked by | 808, 905 |
| Blocks | 908 |
| Reads | [the scene](../docs/010-the-scene.md), [filters and the weave](../docs/006-filters-and-the-weave.md) |
| Open questions | **23** — what puts a fact on either side, and how a private one is learned |

## Current behavior

Every fact about every actor is equally visible. A narrator handed a history would
be handed everything, and a filter reading a place would report everything it
holds.

## Intended behavior

Every fact an actor carries — an axis value, a history entry, a minting — is marked
**public** or **private**.

| Marking | Who may read it |
| --- | --- |
| **public** | anyone |
| **private** | only somebody who knows it |

### One marking gates both halves of the screen

This is the point of putting it in its own ticket rather than inside the narrator.
The same rule decides two different things:

- **what a narration may say** — see [908](908-the-narrator-thinks-then-narrates.md)
- **what a filter's reading returns** — the place's public axes, plus its private
  ones that person knows

A filter's reading was always `(person, place) → a number, or nothing`, and the
person half does exactly what it always did. Nothing about the signature changes.

Because one rule gates both, **the map and the tome cannot come to disagree about
what you are allowed to know.** Two separate mechanisms would drift apart, and the
drift would show up as the drawn half and the written half telling different kinds
of truth — a bug nobody would be able to name.

### What is not decided here

Where the marking lives, and how a private fact is learned. See question 23. It
could belong to the axis, to the actor, or to the moment of minting; and knowing
could follow from having been present, from being told, or from something else.

**This ticket is not implementable until that is settled.** Everything above it is
decided; that alone is not.

## Suggested implementation steps

1. Add the marking to axis values and to history entries.
2. Write the visibility test **once**, in one place, taking a reader and a fact.
   Both the narrator and the filter reading call it.
3. Do not let either caller reimplement the test. Two copies is how the two halves
   of the screen start disagreeing.
4. Default to public and make private the value that must be stated, so an
   unmarked fact fails open rather than silently hiding things.
5. Test that a filter reading and a narration, given the same reader and the same
   scene, agree exactly on which facts are available.

## Related documents and tools

- [The scene](../docs/010-the-scene.md)
- [Filters and the weave](../docs/006-filters-and-the-weave.md) — the reading this gates
- [Open questions](../docs/013-open-questions.md) — question 23
