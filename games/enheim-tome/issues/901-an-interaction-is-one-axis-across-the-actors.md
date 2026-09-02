# 901 — An Interaction Is One Axis Across the Actors

| | |
| --- | --- |
| Phase | 9 — The Scene |
| Blocked by | 808, 811 |
| Blocks | 902 |
| Reads | [the scene](../docs/010-the-scene.md) |
| Open questions | — |

## Current behavior

A gathering can be computed, blended, and applied. What happened in it exists only
as a set of numbers that moved.

## Intended behavior

A scene is not "two people met." It is **the set of axes in play, and what each one
is doing across the actors present.**

For one axis name, look at every actor in the gathering — the place included — and
ask who carries it, at what value, and who is open. That yields five recognisable
situations, and they are a dispatch table rather than a staircase of tests:

| Interaction | When | What it is |
| --- | --- | --- |
| **shared** | several carry it at close values | common ground; the thing nobody has to explain |
| **strained** | several carry it at distant values | the unlike that makes sparks |
| **offered** | a closed actor carries it, an open one does not | it will be taken up, because the closed give and the open receive |
| **withheld** | an open actor carries it and every other carrier is absent | nobody takes it, because the one who has it can only receive |
| **asserted** | only the place carries it | the room insisting on something nobody present holds |

### An axis nobody carries is not in the scene

Not listed, not typed, not mentioned. This is the same structural *nothing* that
draws as bare painting in [503](503-nothing-is-a-value.md) — an absent axis is a
way of looking that does not apply here, rather than a value of zero.

That also bounds the size of a scene without a cap: a gathering only ever produces
as many interactions as there are axes anybody present actually carries.

### Withheld is the one to be careful not to lose

Nobody designed it and it is the most human entry in the table. An open person is
receptive, and receptive people do not give. So somebody can carry a thing, be
surrounded by people, and have it go nowhere — not because they were refused, but
because **being the sort of person who takes things in is the same as being the
sort who cannot hand them out.**

It falls out of *the closed gives, the open receives* and nothing else, which is
exactly why an implementer simplifying the table would delete it first.

### Close and distant need a threshold

*Shared* and *strained* differ only by how far apart the values are, and the line
between them decides where sparks happen. It is a tunable and belongs in
`input/what-to-start-with`, not in the source.

## Suggested implementation steps

1. Group the gathering's characters by axis name — a union over sparse maps, per
   [808](808-character-is-a-sparse-map-of-axes.md).
2. For each axis, collect who carries it, at what value, and each carrier's status.
3. Classify with a dispatch table keyed on the shape of that collection. Five
   entries, no branching staircase.
4. Read the shared-versus-strained threshold from the input directory.
5. Emit nothing at all for an axis nobody carries.
6. Test each of the five types against a hand-built gathering, and test that
   withheld survives a refactor by asserting it directly.

## Related documents and tools

- [The scene](../docs/010-the-scene.md)
- [811 — the gathering is one share of N plus one](811-the-gathering-is-one-share-of-n-plus-one.md)
- [503 — nothing is a value](503-nothing-is-a-value.md)
