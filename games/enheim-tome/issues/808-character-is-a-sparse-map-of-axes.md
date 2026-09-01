# 808 — Character Is a Sparse Map of Axes

| | |
| --- | --- |
| Phase | 8 — The Scaffold |
| Blocked by | 807 |
| Blocks | 809, 811, 815, 816 |
| Reads | [the scaffold](../docs/009-the-scaffold.md), [filters and the weave](../docs/006-filters-and-the-weave.md) |
| Open questions | — |

## Current behavior

An actor exists but is featureless. Nothing says what it is like.

## Intended behavior

A character is a **map from axis name to a value between zero and one**. Not a
fixed-width vector. There is no declared list of dimensions anywhere in the
program, and there never will be.

> we will generate an arbitrary amount of axes for places that have character.
> They will be created on-demand for the developing nature of the place.

Most actors carry very few. One with a long history carries many. **How many axes
this city has is not knowable in advance and is not supposed to be.**

### An axis and a filter are the same record

[Filters and the weave](../docs/006-filters-and-the-weave.md) defines a filter as a
name, a colour, an angle, a mode, and a reading of
`(person, place) → a number, or nothing`. A minted axis is exactly that.

So **the filter list is not authored.** It grows as the city grows axes, which is
why [501](501-what-a-filter-is.md) must not assume a fixed catalogue, and why
[816](816-a-minted-axis-needs-a-colour-and-an-angle.md) exists at all.

### Absence is structural, not a special case

An actor that does not carry an axis is not carrying zero. Zero is a reading;
absence is **the axis not applying here**.

This is the same distinction [503](503-nothing-is-a-value.md) already draws, and it
stops being a filter-rendering convenience and becomes the shape of the data. Bare
painting under a filter is a place that never grew that axis.

### What sparse buys, in numbers

A fixed vector over an unbounded vocabulary is impossible — the vocabulary grows
forever. A sparse map costs only what is actually carried, and the count of axes
an actor holds is itself the useful measure of *how much character it has*.

## Suggested implementation steps

1. Represent a character as a table keyed by axis name. Lua tables are already
   sparse maps; do not build an index.
2. Blending two characters is a **union over names**, not a walk over a fixed
   list. An axis present in one and absent in the other is the interesting case,
   not an error.
3. Never test for a nil value at a use site. If an axis could be absent, the
   caller wanted the union, and the union is where absence is handled once.
4. Report the axis count per actor and across the city, so "how much character
   exists" is a measured number rather than a guess.
5. Test that blending is order-independent and that an absent axis and a
   zero-valued axis never compare equal.

## Related documents and tools

- [The scaffold](../docs/009-the-scaffold.md)
- [Filters and the weave](../docs/006-filters-and-the-weave.md) — the record an axis shares
- [503 — nothing is a value](503-nothing-is-a-value.md)
- [816 — a minted axis needs a colour and an angle](816-a-minted-axis-needs-a-colour-and-an-angle.md)
