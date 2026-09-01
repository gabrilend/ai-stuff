# 807 — An Actor Is a Person or a Place

| | |
| --- | --- |
| Phase | 8 — The Scaffold |
| Blocked by | — |
| Blocks | 808, 810, 811 |
| Reads | [the scaffold](../docs/009-the-scaffold.md) |
| Open questions | **19** — whether a *thing* is a third kind |

## Current behavior

The city has people and it has places, and they are unrelated kinds. Nothing they
share is named.

## Intended behavior

**One record shape, worn by two things.** An actor is anything that has a
character and a status, and that is the whole of the definition.

| Field | Type | Meaning |
| --- | --- | --- |
| `kind` | one of two | person, or place |
| `character` | sparse map — see [808](808-character-is-a-sparse-map-of-axes.md) | what it is like |
| `status` | open or closed — see [810](810-open-and-closed-are-a-line-on-the-curve.md) | which way exchange runs |
| `history` | append-only list — phase 9 | how it got this way |

The reason to unify them is not tidiness. It is that
[the gathering](811-the-gathering-is-one-share-of-n-plus-one.md) treats the room
as one of the people in it — *if five people are in a room, the room is 1/6th* —
and that arithmetic is only expressible if a room and a person are the same kind
of thing to it.

### Person and place differ in exactly two ways

Everything else about them is identical, and the differences are worth naming so
nobody adds a third:

**A place has a natural character it never loses** — see
[809](809-a-place-holds-a-natural-character.md). A person does not.

**A person's status comes from their day-curve; a place's does not.** A person is
open when at rest, read off the curve. A place's status is a property of the place,
and most places are closed all the time.

### Why there are no other kinds

The vision's phrasing was *person, place, thing*, and this project has
deliberately never had objects — the containment chain in
[the places of the city](../docs/003-the-places-of-the-city.md) stops at the
house, and the old key-in-a-box went out with the event system.

Nothing here would break if things existed; an actor needs only a character and a
status, and a thing could have both. **That is exactly why it must be decided
rather than allowed to happen.** See question 19.

## Suggested implementation steps

1. Define the actor record with the four fields above and nothing else.
2. Give it a dispatch table keyed on `kind` for the two places person and place
   diverge, rather than a branch at each use site.
3. Make every later piece of the scaffold take actors, never people — the
   gathering, the flow, the spark. If a function asks whether it has a person, the
   unification has already leaked.
4. Test that a room and a person are interchangeable everywhere the gathering
   arithmetic touches them.

## Related documents and tools

- [The scaffold](../docs/009-the-scaffold.md)
- [The places of the city](../docs/003-the-places-of-the-city.md) — the containment chain, which has no room for objects
- [Open questions](../docs/013-open-questions.md) — question 19
