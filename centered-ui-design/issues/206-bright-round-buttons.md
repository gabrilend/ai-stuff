# 206 — Bright round buttons

**Phase:** 2 — Glass and metal
**Blocked by:** 202, 201
**Blocks**: 208, 302
**Related documents:** docs/visual-language.md (The rule of buttons and
dials)

## Current Behavior

Nothing is pressable.

## Intended Behavior

- Buttons are the only clickable parts of the dashboard. They are painted:
  flat, bright, saturated, round or half-round, or an arc segment of a ring,
  with a bezel of metal.
- Every button is an order verb (plus the calendar's pace switch).
- States: resting, hovered (rim brightens), pressed (inset, darker),
  de-selected (no stand is named yet, so pressing would do nothing; dimmer
  but still painted).
- A button fires once on release inside it; dragging off cancels.
- Labels are short words or simple glyphs in the paint's contrasting tone.

## Suggested Implementation Steps

1. `src/NNN-button.lua`: state and input handling separate from drawing.
2. A dispatch table from state to drawing style (not an if-chain).
3. Tests: press-drag-off-release does not fire; a de-selected button reports
   the press so the view can flash "name someone first".
