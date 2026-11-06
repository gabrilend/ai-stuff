# 801d — `day` refused on a night-only category

The fourth piece of 801: the palette rule docs/067 states but nothing yet
enforces.

## Current Behavior

Built. `src/070-the-look.lua`'s `NIGHT_ONLY` is the per-category flag,
and `check_palette(category, look)` refuses `palette = "day"` on a marked
category, naming docs/067's rule ("day (vibrant on white) only when the
asset is not mostly for night"); `for_canvas(category, overrides)` lays a
canvas's overrides on the defaults and runs the check, for the wall (802)
to call before a canvas compiles. Checked by
`tests/122-checking-night-only-day.lua`, against its own marks: `day` on
a marked category is refused naming the rule, `day` elsewhere succeeds.

Decisions: which categories are mostly for night is the owner's own
taste, so — like the router's model (docs/010, question 12) — the slot and
the refusal are built and no category is marked: docs/010 gains question
15, and marking one is a single line. Fixed on the way, since this check
depends on it: 801b's `with_overrides` kept the default ground's palette
when a canvas named only `ground = "white"`; palette now follows an
overridden ground unless the canvas names a palette outright, so a white
ground's `day` cannot slip past the night-only check.

## Intended Behavior

`palette = "day"` is refused for a category marked night-only (docs/067:
vibrant-on-white "only when the asset is not mostly for night"); the
refusal names the rule it broke.

## Suggested Implementation Steps

1. A per-category night-only flag.
2. The refusal check reading it before a canvas compiles. **Test:** `day`
   on a night-only category is refused, naming the rule; `day` on any other
   category succeeds. Done (`NIGHT_ONLY`, `check_palette`,
   `for_canvas`).

## Blocked by

- 801a
