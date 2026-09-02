# 502 — A Reading Takes a Person

| | |
| --- | --- |
| Phase | 5 — Filters and the Weave |
| Blocked by | 501 |
| Blocks | 503, 510, 707 |
| Reads | [filters and the weave](../docs/006-filters-and-the-weave.md) |
| Open questions | — |

## Current behavior

A filter reads a place.

## Intended behavior

A filter reads a place **for somebody**.

```
   reading(person, place) → a number from 0 to 1, or nothing
```

One extra parameter. It is the most valuable thing in the design and it costs an
argument.

### Why it was always true

The governing idea is that **the map is not the city — it is one person's model of
the city**. Every rule follows from that: ignorance draws as bare painting, a
stranger's day is unreadable, sweeping the hour consults a belief rather than
travelling.

If the map is somebody's model, then the readings on it were never *block → a
number*. They were always *(person, block) → a number*, with the person left
implicit because there had only ever been one. Making it explicit is not adding a
feature; it is writing down something that was already the case.

### What it buys

**Character switching, entire.** Select any house, take up whoever lives there,
and the map repaints — hatching rearranged, blank ground moved, different days
readable, different buttons lit. See [510](510-switching-person-repaints.md).

And with it, the ability to **look at another person's ignorance**. A servant in
the eastern mansions has a blank harbour. A bargeman has a bright river and a dark
walled quarter. For a game whose subject is a city that constrains what people may
know and do, being able to see the shape of somebody's blindness is closer to the
point than any mechanic.

### It also draws the social horizon for free

Because knowledge accumulates where a person actually goes, and because a quadrant
is the scale at which two people never meet — see
[403](403-quadrants-four-to-a-group.md) — a citizen's knowledge comes out **shaped
like their quadrant**.

Nothing renders that boundary. It appears because it is true.

### The discipline this demands

**No global "current knowledge".** The moment a reading can be obtained without
naming whose it is, the design has quietly lost character switching, and it will
be a long way back. Every call site names a person, including the ones where there
is obviously only one.

## Suggested implementation steps

1. Change the reading signature to take a person first.
2. Make the person a required argument everywhere — no default, no ambient
   current-person that a call can omit.
3. Have the shading pass carry the person whose model is being drawn, from one
   place near the top of the frame.
4. Keep a filter free to *ignore* the person — a purely physical reading like
   shade may not care — while still receiving it, so the signature stays uniform.
5. Test that two people over the same fixture city produce different hatching,
   and that swapping which one is drawn changes nothing else.

## Related documents and tools

- [Filters and the weave](../docs/006-filters-and-the-weave.md)
- [What this game is](../docs/001-what-this-game-is.md)
