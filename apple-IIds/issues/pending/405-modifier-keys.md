---
name: modifier keys
phase: 4
status: pending
blockedBy: [404]
---

# 405 — modifier keys

Shift, Command (the Apple key), Option, and Control work with the
radial keyboard. L3 and R3 (left/right stick clicks) provide
additional layers for numeric / symbol / shifted characters.

## current behavior

The radial keyboard emits only the unmodified characters from the
default layout (issue 404). No way to type capitals, punctuation
beyond the 6 slots in the default layout, or modifier combos.

## intended behavior

- L1 → Shift (held)
- R1 → Command (held)
- L2 → Option (held)
- R2 → Control (held)
- L3 (left stick click) → numeric / symbol layer (held)
- R3 (right stick click) → punctuation / shifted layer (held)
- The broker tracks modifier state. On each commit, the active
  modifiers are passed to the lookup table; they may select a
  different character (e.g. shifted "a" → "A"), and they are also
  attached to the emitted ADB event as modifier flags.
- The L3 and R3 modifier layers select a *different lookup table*,
  not just a different character per cell. This is how the 64-cell
  effective space expands.
- For modifier discoverability, the overlay (issue 402) **redraws**
  when modifiers change: the cells show the modified characters
  (e.g., uppercase letters when Shift is held).
- Sticky-vs-held: the default is **held** (release the modifier to
  return to the base layer). A settings option enables "sticky"
  (press-and-release the modifier to apply to the next character
  only, then auto-release).

## suggested implementation steps

1. Add modifier state to the broker: `modifiers = {shift, cmd, opt,
   ctrl, layer_l3, layer_r3}`.
2. Wire the shoulder and L3/R3 button events to update the modifier
   state.
3. Extend `src/broker/radial-layout.lua` to accept a `modifiers`
   parameter and return the modified character or the layer-shifted
   lookup result.
4. Extend the overlay renderer (issue 402) to redraw on modifier
   state change, showing the active layer's characters.
5. Extend the commit handler (issue 404) to pass modifiers to the
   lookup and to attach modifier flags to the ADB event.
6. Add the settings option for sticky modifiers.
7. Test: type an "A" using Shift + radial-a; type a number from the
   L3 layer; type Cmd+S (Save) and confirm GS/OS receives the
   command-key shortcut.

## related documents

- `docs/003-input-system.md` — modifiers table and L3/R3 layers
- `issues/404-character-emission-adb.md` — the layer this builds on
- `issues/407-wedge-layout-calibration.md` — finalizes the per-layer
  character assignments

## known design questions

- Layer assignments: which characters live on L3, which on R3? See
  the layout in `docs/003-input-system.md` — those are starting
  positions; final assignments come out of issue 407.
- Can two layers be active simultaneously (e.g., L3 + R3 held)?
  Default: no, the second layer press cancels the first. Combo
  layers are out of scope.
- Caps Lock: the IIds keyboard has a caps lock key. We don't have a
  natural button for it on the RG DS. Default: L1 + Start cycles
  caps lock; surfaced in the overlay's status area as a small
  indicator.
