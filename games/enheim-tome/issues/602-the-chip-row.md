# 602 — The Chip Row

| | |
| --- | --- |
| Phase | 6 — The Tome |
| Blocked by | 501, 601 |
| Blocks | 603 |
| Reads | [the tome](../docs/007-the-tome.md) |
| Open questions | **6** — how a chip stays legible at chip size |

## Current behavior

Any number of filters can be active. Nothing shows which, or lets you pick one to
adjust.

## Intended behavior

One small **chip per active filter**, in a wrapping row at the top of the tome.
Clicking a chip focuses that filter, whose full controls appear beneath — see
[603](603-the-focused-filters-controls.md).

### The problem it solves

The top region is welded to a fixed height, and any number of filters may be
active. Six filters, each with a colour, an angle, a mode and its own parameters,
would need twenty rows of controls — and a fixed region holding twenty rows is not
a region, it is the whole tome.

Chips bound the height. **Twelve filters is still one or two rows**, because a
chip is small and the row wraps. Only the focused filter spends vertical space.

The cost is a click to move between filters, which is small next to the top
staying a fixed size.

### A chip carries three things, not one

Per the colour rule in
[what this game is](../docs/001-what-this-game-is.md), colour may never be the
only carrier of a fact. So a chip shows:

- its **colour**
- its **hatch angle**
- its **name**

**Working ruling:** a small square showing the filter's actual hatching, at its
actual angle, in its actual colour — so the chip is a miniature of what the filter
draws — with the name beside it, truncated.

That is elegant if it works: the chip *is* a sample of the thing, so recognising
it on the map and recognising it in the row are the same act of recognition.

Whether it survives at chip size is open question 6. A few pixels of hatching may
not read as an angle at all, in which case the angle needs stating some other way
— a number, or a tick.

### What a chip does besides identify

- click to focus
- a clear way to turn the filter off, without focusing it first
- an indication of mode, since a filter woven and a filter on top behave very
  differently and the row is where you would look

## Suggested implementation steps

1. Lay chips out in a wrapping row within the top region's width.
2. Render each as a hatching sample at the filter's angle and colour, plus a
   truncated name.
3. Track which is focused; clicking focuses.
4. Provide a deactivate affordance that does not require focusing first.
5. Show mode compactly, in a way that is not only a colour.
6. Test with twelve active filters that the row wraps within the welded height and
   the button pane below has not moved.

## Related documents and tools

- [The tome](../docs/007-the-tome.md)
- [Open questions](../docs/013-open-questions.md) — question 6
