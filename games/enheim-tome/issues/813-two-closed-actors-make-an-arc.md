# 813 — Two Closed Actors Make an Arc

| | |
| --- | --- |
| Phase | 8 — The Scaffold |
| Blocked by | 811, 812 |
| Blocks | 814 |
| Reads | [the scaffold](../docs/009-the-scaffold.md) |
| Open questions | — |

## Current behavior

Character moves from the closed to the open. Nothing new is ever created — the
city only ever redistributes what geography seeded it with.

## Intended behavior

Two closed actors meet. Neither can receive. **What happens is not transfer.**

> when two closed things meet, sparks fly. Sometimes they just bounce off one
> another, but I'm assuming you meant when they are intent on interacting - there
> will be a new character arc that is created, sometimes it just plays on the
> room, sometimes it sticks with someone nearby

Three parts, and the scaffold must carry all three without deciding any of them.

### Intent is a precondition

Closed meeting closed **usually just bounces**. Sparks need the two of them to be
intent on interacting. The actor record carries a slot for intent; what fills it is
not settled here and must not be guessed at.

A gathering with two closed actors and no intent produces nothing, which will be
the common case.

### What is created is an arc, not a value

Not a number added to somebody's character — a new thing with a shape and a
duration. **This is where an axis nobody previously held comes from**, and it is
one of only two sources; the other is
[815](815-forcing-a-closed-thing-open.md).

### Where it lands is context

It may play on the room. It may stick with someone nearby. It may do neither.

**The scaffold provides the places an arc can land and lets the situation decide.**
It does not choose, and a table enumerating outcomes would be the opposite of what
this ticket is for.

> What we want is to build the scaffold upon which that context might develop.

### Nearby means adjacency, because there is no distance

An arc that sticks with "someone nearby" cannot use a radius.
[What this game is](../docs/001-what-this-game-is.md) explains why: the painting is
an oblique view, ordinary townhouses run 12 to 20 pixels across near the northern
wall and 40 to 70 down in the harbour, and any figure computed from those pixels is
wrong by a factor that changes with where it was measured.

So **nearby is this block, or a block sharing an edge with it** — see
[203](203-adjacency-is-a-shared-edge.md). Nothing else. A rampart genuinely stops
an arc, because blocks on opposite sides of a wall share no edge.

### The image this came from

> like two closed hands grasped around one another, lifting to see the view atop
> the roof

Two things that cannot take from each other, gripping, and the result is elevation
and a view neither of them had. **The productive case is productive without either
party having changed.**

## Suggested implementation steps

1. Add an intent slot to the actor record and leave it unfilled, with a comment
   saying so and naming this ticket.
2. Detect the condition: two or more closed actors in one gathering, intent on each
   other.
3. Create an arc record with the participants, the place, and the hour. Do not give
   it an outcome.
4. Provide the three landing sites — the room, an adjacent-or-same-block actor, and
   nowhere — as data the arc can name, not as branches.
5. Test that a gathering of closed actors without intent produces no arc at all.
6. Test that an arc never lands across a wall, by checking it only ever names
   blocks reachable through a shared edge.

## Related documents and tools

- [The scaffold](../docs/009-the-scaffold.md)
- [203 — adjacency is a shared edge](203-adjacency-is-a-shared-edge.md) — what nearby means
- [What this game is](../docs/001-what-this-game-is.md) — why there are no distances
- [The scene](../docs/010-the-scene.md) — where an arc becomes words
