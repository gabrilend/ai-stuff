# 705 — Vines Creep Along Walls

| | |
| --- | --- |
| Phase | 7 — The Delve |
| Blocked by | 303, 701, 703 |
| Blocks | 707 |
| Reads | [the monsters of the delve](../../docs/023-the-monsters-of-the-delve.md) |
| Open questions | none |

## Current behavior

The `creeping` row is `Walking.advance` with a drop limit of ninety-nine, and
that is the whole of it. A vine falls down a cliff face and keeps growing because
its creature row says a drop is not a problem.

The face-neighbour enumeration this issue describes — moving along vertical faces
rather than along surfaces — is **not** built. What is built reads as a creature
that goes wherever it likes downhill, which is most of the visible difference; a
vine climbing a wall it could not otherwise reach is not.

Entangling is built, and it is the same shape as a duel and a shared idle: a hold
with a clock. The walking row skips any body with `held` above zero, which is a
check on the body rather than a locomotion row — so it works for anything that
can be held rather than only for the kinds somebody remembered.

## Intended behavior

The `creeping` row: motion along **vertical faces** rather than along surfaces,
ignoring the drop limit entirely. A vine falls down a cliff face and keeps
growing.

Its stance is a surface like anything else's — which is what lets the buckets,
the renderer and the meet pass treat it as an ordinary body — and what differs is
which neighbours it considers. A creeper's neighbour set includes the faces of
adjacent columns, so it climbs the wall a walker routes around.

**It entangles.** A body it reaches is held: its locomotion is suspended and it
does not move until the hold breaks. The same mechanism as
[a duel](501-a-duel-is-a-record-not-two-flags.md) — a record referencing two
bodies with generations — because being held and being in a fight are the same
shape of thing, and building the third instance of that shape is when it is
finally worth generalising rather than the first.

**Its solution is fire.** It is the most flammable thing in the maze and the only
monster whose solution is not another monster's body.

**What it is for:** holding the golem.

## Suggested implementation steps

1. Write the face-neighbour enumeration: for a stance, the adjacent columns with
   stone at or above this layer, and the layers of theirs that are exposed.
2. Write the `creeping` row over that neighbour set.
3. Write the entangle as a held record and the release.
4. Set flammability high and fuel long.
5. Test: a vine placed at the bottom of a cliff reaches the top. An entangled
   body does not move and resumes when released. A vine set alight burns out and
   its holds release.

## Related documents and tools

- [The monsters of the delve](../../docs/023-the-monsters-of-the-delve.md)
- [Fire is a state that spreads](703-fire-is-a-state-that-spreads.md)
