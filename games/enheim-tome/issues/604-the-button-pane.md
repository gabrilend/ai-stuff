# 604 — The Button Pane

| | |
| --- | --- |
| Phase | 6 — The Tome |
| Blocked by | 601 |
| Blocks | 605 |
| Reads | [the tome](../docs/007-the-tome.md) |
| Open questions | — *(was question 7; answered by the two-hand scheme)* |

## Current behavior

The middle region is empty.

## Intended behavior

A pane of icon buttons in **stable positions**, learned by hand rather than by
reading.

### Selecting a place produces actions, not a document

This is the part that differs from what a map interface usually does. Clicking a
block does not produce something to *read* — it produces **the set of things you
can do here**, in positions that never move.

Fixed positions are the whole point. A button that moves depending on context is a
button you must find every time; a button that is always in the same place becomes
something your hand knows.

### Dimming is information

A button the current place does not afford is **dimmed rather than removed**.

Which means **the pattern of what is lit is itself a description of the place**.
You can read what kind of place this is from the shape of the lit buttons before
reading a word — a block with the trade actions lit and the domestic ones dark is
a different sort of place from the reverse.

Removing unavailable buttons would destroy that and would also break the fixed
positions, since the remaining ones would close up.

### A dimmed button must say why, and the hands provide the place

Per the colour rule, dimming may not be the only carrier of the fact. A dimmed
button must be dimmed **and** able to say why — "nobody here will speak to you",
"you are not inside" — because a person facing a wall of grey icons with no
explanation is being told nothing.

The two-hand scheme from [104](104-pan-and-zoom-by-hand.md) answers it without
needing a mechanism of its own:

| | |
| --- | --- |
| **left click** on a button | tells you what it does, and if dimmed, why it cannot be used here |
| **right click** on a button | presses it |

**The enquiry hand works on controls the action hand refuses**, so a greyed
button is never a dead end.

From which follows a rule the whole pane is held to: **nothing may be pressable
by the hand that asks about it.** Anything acting on left click has broken the
scheme, and the scheme is what makes every dimmed thing legible.

The explanation goes into the text pane below rather than into a floating
tooltip, since the pane is where words live and a tooltip over the buttons would
cover the neighbouring ones.

### What the buttons actually are is not decided

They are actions, and actions are mechanics, and mechanics are deliberately not
guessed at. This issue builds **the pane**, its layout, its dimming and its
hover behaviour, against a small placeholder set.

## Suggested implementation steps

1. A fixed grid whose cells are positions, filled from a declared action table so
   that positions come from the table rather than from iteration order.
2. Render each with its icon; dim those the selected place does not afford.
3. On hover, write the name and any reason for dimming into the text pane.
4. Keep the grid the same size regardless of how many actions are available.
5. Test that the same action is in the same cell across three different kinds of
   place, and that dimming never reflows the grid.

## Related documents and tools

- [The tome](../docs/007-the-tome.md)
- [Open questions](../docs/013-open-questions.md) — question 7
