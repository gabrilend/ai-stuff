# 801c — The flair's quarter colours

The third piece of 801: the function every end calls to draw a surface's
midline the same way.

## Current Behavior

Built. `src/070-the-look.lua`'s `shift(colour, amount)` is the colour
primitive (a colour `{r, g, b[, a]}` in raylib's 0-255 range, moved that
fraction of the way toward white or black, rounded, alpha kept), and
`flair_quarters(base, look)` gives the four quarters from it: one
`{lighter, lighter}`, two and three `{lighter, darker}`, four `{darker,
darker}`, each quarter a pair of halves in drawing order. How far is the
look's own new field `flair_shift` (0.15; added to docs/067's table and
recorded in docs/balance-updates.md), so a canvas may override it like
any other; with `flair` off every half is the base colour. Checked by
`tests/121-checking-flair-quarters.lua`.

Decisions: "half lighter, half darker" is read as each of quarters two
and three split into two halves along the line, the first lighter and the
second darker — light falling across the middle, brightest at the start —
rather than one colour halfway between (which would just be the base).
Lighter and darker move a fraction of the way to white and to black, so a
shift never leaves 0-255 and works the same on any colour.

## Intended Behavior

A function taking a base colour, returning its four quarter colours:
quarter one a little lighter than the base, quarter four a little darker,
quarters two and three each half lighter, half darker — reading how much
lighter and darker from 801a's look table.

## Suggested Implementation Steps

1. The colour-shift primitive (lighten/darken a colour by an amount).
2. The four-quarter function built from it. **Test:** quarter one lighter
   than the base, quarter four darker, two and three each split; the same
   base colour always gives the same four. Done (`shift`,
   `flair_quarters`).

## Blocked by

- 801a
