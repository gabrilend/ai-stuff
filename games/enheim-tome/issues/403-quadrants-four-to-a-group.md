# 403 — Quadrants, Four to a Group

| | |
| --- | --- |
| Phase | 4 — The Places |
| Blocked by | 401, 402 |
| Blocks | 404 |
| Reads | [the places of the city](../docs/003-the-places-of-the-city.md) |
| Open questions | — |

## Current behavior

Groups exist. Nothing divides them.

## Intended behavior

Four quadrants to a group. The city is quartered; each megastructure is quartered
the same way — which works only because both happen to be round.

**Land beyond the wall has no quadrant at all.** See
[401](401-the-containment-chain-is-a-list.md) for why that is a level that does
not exist rather than a value that is missing.

### A quadrant is a social horizon

This is the reason quadrants are in the design, and it is not a containment
reason.

> if your character is in the north-east, they could wander around all day and
> never see someone in the south west

A quadrant is **the scale at which the city stops being one place**. Two people in
different quadrants of the same structure do not meet, not because anything
forbids it but because a day is not long enough and there is no reason to go.

That has a consequence nothing needs built for it. Because a filter reads a place
*for a person* — see [502](502-a-reading-takes-a-person.md) — and because
knowledge accumulates where a person actually goes, **a citizen's knowledge comes
out shaped like their quadrant**: dense inside it, blank across the divide.

The hatching draws the horizon on its own. Nobody has to render a boundary called
"the limit of what this person could plausibly know"; it appears because it is
true.

### What it is made of

Membership, like everything else above the block: a quadrant names its group, and
districts name their quadrant. Its outline is derived. See
[405](405-boundaries-derived-from-members.md).

### Why four, and whether four is fixed

Four because the city is round and quartering a circle is the obvious division,
and because the megastructures are round too and can be divided the same way.

The tables should not hard-code four. Nothing in the design depends on the number,
and a structure that wanted three or six would break a program that counted on
four for no benefit.

## Suggested implementation steps

1. A quadrant table: name, and the group it belongs to.
2. Districts name a quadrant or name none.
3. Do not enforce a count of four anywhere; let membership say what it says.
4. Have the coverage report list groups with other than four quadrants as
   *worth a look*, not as an error.
5. Test that a district beyond the wall has a chain of three levels and that
   nothing in the selection or tome code branches on it.

## Related documents and tools

- [The places of the city](../docs/003-the-places-of-the-city.md)
- [Filters and the weave](../docs/006-filters-and-the-weave.md)
