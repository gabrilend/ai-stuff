# 811 — The Gathering Is One Share of N Plus One

| | |
| --- | --- |
| Phase | 8 — The Scaffold |
| Blocked by | 703, 807, 808, 809, 810 |
| Blocks | 812, 813 |
| Reads | [the scaffold](../docs/009-the-scaffold.md) |
| Open questions | — |

## Current behavior

Actors have characters and statuses. Nothing brings them together.

## Intended behavior

At an hour, in a block, there is a set of actors. **The place is one of them.**

Who is present comes from the whereabouts equation
[703](703-whereabouts-is-a-function.md) already provides: feed it a person and an
hour, get a block. A gathering is everyone whose answer is this block, plus the
block itself.

**Nothing is stored.** A gathering is computed by evaluating whereabouts for
everyone at one hour. There is no attendance list to keep in sync.

### Every actor present is one share of 1 / (N + 1)

> if five people are in a room, the room is 1/6th

That sentence deletes a tunable constant and replaces it with a rule that behaves
correctly at every scale without being tuned:

| Who is present | The room's share | What that means |
| --- | --- | --- |
| nobody | 1/1 | an empty place is entirely itself |
| one person | 1/2 | alone at home, you are half the building |
| five people | 1/6 | the room is one voice among six |
| fifty in a square | 1/51 | a crowd is its crowd, not its stones |

**A place's resistance to change is inversely proportional to how busy it is.**
Crowds change places; solitude preserves them. Nothing was tuned to get that, and
nothing should be added that would let it be tuned — a weight parameter here would
be a knob that can only make the behaviour worse.

### You count yourself

An actor's own share is `1 / (N + 1)` like everyone else's. That is why a person
alone in a closed building drifts halfway toward the stone, and why somebody in a
crowded square barely moves at all.

### This is where the room becoming its visitors comes from

> make sure that a place's character is derived from the character of the people
> who visit it, plus a little bit of it's own natural character.

Those are not two rules. When an open room adopts the blend, its own prior
character is its **one share** of what it becomes. The little bit is `1 / (N + 1)`.

## Suggested implementation steps

1. Build the gathering by evaluating whereabouts for every person at the hour and
   grouping by block. Do not maintain a per-block occupant list.
2. Append the place to its own gathering, as an actor, before anything counts N.
3. Compute the blend as the share-weighted union of every present character —
   union, because [808](808-character-is-a-sparse-map-of-axes.md) is sparse and an
   axis one actor lacks is the interesting case.
4. Never give the room a weight of its own. If a constant appears here, the rule
   has been broken.
5. Test the four rows of the table above directly: empty, alone, five, fifty.
6. Test that the shares sum to exactly one, including the room, at every N.

## Related documents and tools

- [The scaffold](../docs/009-the-scaffold.md)
- [703 — whereabouts is a function](703-whereabouts-is-a-function.md) — who is present
- [809 — a place holds a natural character](809-a-place-holds-a-natural-character.md) — what the room contributes
