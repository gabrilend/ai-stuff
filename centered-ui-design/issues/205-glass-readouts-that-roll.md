# 205 — Glass readouts that roll

**Phase:** 2 — Glass and metal
**Blocked by:** 203, 204

**Blocks**: 208, 302, 308
**Related documents:** docs/visual-language.md (The rule of buttons and
numbers)

## Current Behavior

There is no way to show a number in the console style.

## Intended Behavior

- A readout is digits printed on a bare metal surface, seen through a round
  or arc-shaped glass lens. It is never painted and never reacts to hover or
  press — it must not look like a button.
- Each digit is a small drum that rolls to its new value (odometer style),
  carrying into the next digit as it passes 9→0. Negative values and decimals
  have fixed formats chosen per readout.
- A readout is given a target value; the shown value moves toward it.

## Suggested Implementation Steps

1. `src/NNN-readout.lua`: digit-drum state (numbers) separate from drawing.
2. Drawing: metal surface tone, digits, glass lens on top.
3. Test: rolling from 0199 to 0200 passes through intermediate states and
   ends exactly; a readout ignores mouse input entirely.
