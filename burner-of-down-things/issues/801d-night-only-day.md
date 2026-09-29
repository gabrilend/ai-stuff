# 801d — `day` refused on a night-only category

The fourth piece of 801: the palette rule docs/067 states but nothing yet
enforces.

## Current Behavior

No palette rule is enforced; `palette = "day"` is accepted for anything.

## Intended Behavior

`palette = "day"` is refused for a category marked night-only (docs/067:
vibrant-on-white "only when the asset is not mostly for night"); the
refusal names the rule it broke.

## Suggested Implementation Steps

1. A per-category night-only flag.
2. The refusal check reading it before a canvas compiles. **Test:** `day`
   on a night-only category is refused, naming the rule; `day` on any other
   category succeeds.

## Blocked by

- 801a
