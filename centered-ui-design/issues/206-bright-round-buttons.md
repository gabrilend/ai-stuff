# 206 — Bright round buttons

**Phase:** 2 — Glass and metal
**Blocked by:** 202, 201

**Blocks**: 208, 302
**Related documents:** docs/visual-language.md (The rule of buttons and
numbers)

## Current Behavior

Nothing is pressable.

## Intended Behavior

- Buttons are painted: flat, bright, saturated, round or half-round, or an
  arc segment of a ring. They have a bezel of metal.
- States: resting, hovered (rim brightens), pressed (inset, darker), armed
  (an order button waiting for its map click glows and pulses), de-selected.
- A button fires once on release inside it; dragging off cancels.
- Button labels are short words or simple glyphs drawn in the paint's
  contrasting tone.

## Suggested Implementation Steps

1. `src/NNN-button.lua`: state and input handling separate from drawing.
2. A dispatch table from state to drawing style (not an if-chain).
3. Tests: press-drag-off-release does not fire; armed state persists until
   cleared.
