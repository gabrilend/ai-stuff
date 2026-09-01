# 302 — Cutting and Severing

| | |
| --- | --- |
| Phase | 3 — The Tracing Mode |
| Blocked by | 209, 301, 304 |
| Blocks | 303, 310 |
| Reads | [the tracing mode](../docs/005-the-tracing-mode.md) |
| Open questions | — |

## Current behavior

The mode can be entered and shows the network. Nothing can be changed.

## Intended behavior

**The map starts whole and gets cut up.** Placing nodes and linking them divides a
region in two; severing a link merges two back into one.

```
   start            one cut           two cuts
   ┌────────┐      ┌────────┐      ┌────────┐
   │        │      │   │    │      │   │    │
   │  one   │  ─▶  │ A │  B │  ─▶  │ A │ B  │
   │        │      │   │    │      │───┼────│
   │        │      │   │    │      │ C │ D  │
   └────────┘      └────────┘      └────────┘
```

Every state in between is a **complete partition**. You are never looking at a
half-finished city, only at a coarsely divided one.

### The gestures

Hung off the same two-hand scheme as everywhere else — **left asks, right acts**:

| Input | What it does |
| --- | --- |
| **middle drag**, **wheel** | pan and zoom, exactly as in play |
| **left click** | selects |
| **left click, shift** | drags what is under it |
| **left click, ctrl** | **severs** the nearest link to the selected node |
| **right click on empty ground** | places a node |
| **right click on a thing** | opens its menu, **without changing the selection** |
| **tab** | opens the menu for whatever is selected |

Two details there are worth not losing.

**Right-clicking a thing opens its menu without selecting it.** So you can act on
one thing while another stays selected — adjusting the lane while the block stays
in the tome. Acting and attending are separated, which is the same idea as
left-asks-right-acts one level up.

**Ctrl-click severs the nearest link to the *selected node*,** not to the pointer.
The selection says where, the modifier says what, and the pointer only
disambiguates between several links meeting at that corner.

### Cutting and severing are exact inverses

Which is worth noticing twice. It is what makes the model easy to hold in the
head — there is one operation and its opposite, not a vocabulary — and it is what
makes undo natural, since the hard part of undo is usually inventing an inverse
that does not exist. Here both directions are gestures a person already has.

### What it must refuse

**Crossing edges.** Faces are found by walking a planar graph — see
[209](209-blocks-are-faces-of-the-graph.md) — so two edges may not cross except
at a shared vertex.

This is the refusal that matters most, because letting it through fails
**silently and remotely**: the walk still terminates and still produces closed
rings, just wrong ones, and what you notice weeks later is two places behaving as
neighbours when they are not. Either refuse the link, or place a vertex at the
intersection and split both edges — but never quietly allow it.

**Imprecise work.** Below the zoom floor in
[304](304-snapping-is-measured-on-the-screen.md), placing and dragging are
refused outright rather than warned about.

**Losing a name.** Severing merges two named places, and one name must lose. **The
person is asked.** Hand-written names are the expensive part of this work and none
may vanish without somebody saying so — see
[201](201-vertices-edges-and-places.md).

## Suggested implementation steps

1. Extend hit-testing to report what kind of thing is under the pointer — node,
   link, or bare region — using the grab radius from
   [304](304-snapping-is-measured-on-the-screen.md).
2. Build the gesture table: one entry per button-and-modifier combination, keyed
   on that kind. A table, not a staircase of conditions.
3. On placing a node in bare region, create the vertex. On linking two nodes,
   create the edge — after checking it crosses nothing.
4. On sever, remove the edge, recompute faces, and resolve the two seeds now
   sharing one face by asking.
5. Recompute faces after every change and run the affected part of
   [208](208-the-network-validator.md) before accepting it.
6. Test the round trip: cut a fixture region in two, sever the same link, and
   assert the network is byte-identical to before.

## Related documents and tools

- [The tracing mode](../docs/005-the-tracing-mode.md)
- [209 — blocks are faces of the graph](209-blocks-are-faces-of-the-graph.md)
