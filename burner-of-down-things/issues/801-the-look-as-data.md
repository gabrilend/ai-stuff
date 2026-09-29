# 801 — The look, as data

The owner's style in one table every paintbrush reads ([067](../docs/067-datapath-the-studio.md), *the look, as data*).

## Current Behavior

Nothing is drawn.

## Intended Behavior

A module holding the look: `ground` (black, gray, white), `palette` (night: bright on dark; day: vibrant on white, only when the asset is not mostly for night), `flair` (the midline of a surface in four quarters: one lighter, two half and half, one darker), `line_weight`, `arrow` (`there-here`). A canvas may override any of these by name; an unknown name is refused. How much lighter and darker the flair goes is a number whose changes go to `docs/balance-updates.md`.

A function gives the four quarter colours of a midline from its base colour, so every end draws the flair the same way.

## Suggested Implementation Steps

1. The table and its defaults, published in the paintbrush document. **Test:** every default in the table appears in the document.
2. The flair's quarter colours. **Test:** quarter one lighter than the base, quarter four darker, two and three each split; the same colour always gives the same four.
3. `day` refused with a night-only category. **Test:** the refusal names the rule.

## Blocked by

None
