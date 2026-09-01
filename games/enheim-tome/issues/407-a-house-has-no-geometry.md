# 407 — A House Has No Geometry

| | |
| --- | --- |
| Phase | 4 — The Places |
| Blocked by | 406 |
| Blocks | 607 |
| Reads | [the places of the city](../docs/003-the-places-of-the-city.md) |
| Open questions | — |

## Current behavior

Buildings exist. Nothing lives inside them.

## Intended behavior

A house is a dwelling **inside** a building — not a freestanding thing. Several
share a roof. Three to five rooms, holding one family or one person.

**It has no geometry whatsoever.** No footprint, no zone, no point. It is a row in
a list inside its building, reached through the tome.

### Why nothing is drawn for it

The painting's roofs were never drawn with individual dwellings in mind. Giving
each one a position would mean deciding, invisibly and arbitrarily, that this
corner of this roof is the tanner's — which is inventing rather than observing,
twenty to forty thousand times.

The list is enough. You reach a house by descending: block, building, house,
person. See [607](607-descending-to-a-person.md). That is how a Paradox game does
it too — a list, not a pixel — and it costs no tracing at all.

### The record

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | what it is called, if anything |
| `building` | integer | which building it is in |
| `rooms` | integer | usually three to five |
| `access` | one of a few values | **almost always restricted** |
| `occupants` | list | one family, or one person |

### Access is the opposite of a building's

Buildings are rarely closed; houses are almost always restricted. Someone lives
there. See [406](406-a-building-and-its-facts.md) for why that asymmetry matters.

### What a house is like inside

Recorded here because it constrains anything that ever draws one, and because it
will otherwise be forgotten by the time such a thing is built:

Built haphazardly, looking nothing like an apartment now. Railings and bannisters
and banners everywhere. **Vaulted ceilings, commonly twenty feet.** Wooden beams
hung from them on chains, and from those beams things arranged at whatever height
you please.

That last detail is not decoration. It says the interior is **used vertically** —
a room here is not a floor plan with furniture on it, it is a tall volume with
things hanging in it at chosen heights. Anything generating an interior must start
from that or it will produce rooms from the wrong century.

### The lives inside

Family, trades, martial, learned — as many lives as there are districts, and you
pick. Whether that choice can be revisited is open question 13, and it is close to
the whole point in a city whose problem is that it tells you which to choose.

## Suggested implementation steps

1. A house table: building, rooms, access, occupants, name.
2. No coordinates on it, ever. If something wants a position for a house, that is
   a design error to raise rather than a field to add.
3. Default access to restricted; open is the exception.
4. Let a building hold zero houses — most will, for years.
5. Test that a house is reachable from its block by descending, and that searching
   for a house resolves to its block. See [609](609-space-to-search.md).

## Related documents and tools

- [The places of the city](../docs/003-the-places-of-the-city.md)
- [Open questions](../docs/013-open-questions.md) — question 13
