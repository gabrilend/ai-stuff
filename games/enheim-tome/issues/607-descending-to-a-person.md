# 607 — Descending to a Person

| | |
| --- | --- |
| Phase | 6 — The Tome |
| Blocked by | 406, 407, 510, 606 |
| Blocks | 610 |
| Reads | [the tome](../docs/007-the-tome.md) |
| Open questions | — |

## Current behavior

The map stops at buildings. Nothing reaches inside one.

## Intended behavior

Everything finer than a building happens in the tome, as lists.

```
   block selected  ──▶  its buildings        (and its intersections)
        │                    │
        │                    ▼
        │               a building     ──▶  its houses
        │                    │                   │
        │                    ▼                   ▼
        │              who owns the roof,   who lives there
        │              what the ground           │
        │              floor trades in           ▼
        ▼                                   take them up
   what is known here, and what can be done
```

This is how you **select any house in the city and play as whoever lives in it**.
No building footprints are needed, the map keeps to its four marks, and it is how
a Paradox game does it too — a list, not a pixel.

### Why a list is not a compromise

Twenty to forty thousand houses have no geometry at all — see
[407](407-a-house-has-no-geometry.md) — because the painting's roofs were never
drawn with individual dwellings in mind. Inventing positions for them would be
inventing rather than observing, tens of thousands of times.

The list loses only the ability to point at the particular roof, which the
painting could not honestly support anyway.

### Taking somebody up

Choosing a person switches whose model the map is. That **repaints everything and
moves nothing** — see [510](510-switching-person-repaints.md). The view stays
exactly where it was, so the change reads as a change: the same streets,
differently known.

The tome must say **whose model is on screen at all times**, since the map carries
no text and there is otherwise nothing to remind you.

### Descending is cheap; ascending must be too

Having gone block → building → house → person, getting back out must be one act,
not four. A visible trail of where you are, each step of it clickable, both shows
the containment and provides the way back.

That trail is the containment chain from
[401](401-the-containment-chain-is-a-list.md) extended downward, so it is the
same idea in both directions.

### Access is shown, not enforced here

Buildings are rarely closed; houses are almost always restricted. The tome shows
what a place is, including that you may not enter it. What that *means* is
mechanics.

## Suggested implementation steps

1. Render the selected place's contents as a list in the text pane.
2. Clicking an entry descends; the trail grows.
3. Clicking a step in the trail ascends to it.
4. A person entry offers taking them up, which calls the switch and leaves the
   view alone.
5. Show whose model is current, permanently, somewhere that does not scroll.
6. Test descending to a person and back out, asserting pan, zoom and the selected
   block are unchanged throughout.

## Related documents and tools

- [The tome](../docs/007-the-tome.md)
- [The places of the city](../docs/003-the-places-of-the-city.md)
