# 506 — Radial menu chord box

## Current behavior

The chord detector (505) provides the generic two-button
mechanism but does not yet have the specific instance that the
text editor and the apps' drawers use for text entry. The
radial menu's "D-pad direction (or stick direction, eight ways)
plus face button (four ways)" combinatoric is the central input
the editor depends on.

## Intended behavior

A `radial-menu-chord` box emits a single event encoding the
specific chord struck:

- The direction component (one of 8): pulled from the
  `stick-direction-changed` or `button-down` (D-pad) streams via
  a configurable input port.
- The face button (one of 4): A, B, X, Y.
- The mode (one of N): determined by which combination of L1,
  L2, R1, R2 was held at the moment of the chord.

The output value is a single character (or character-equivalent
small struct) — the cell at row=direction × column=button × mode
in the editor's lookup table. The default lookup table covers
the alphabet, digits, and common punctuation across two or three
modes; the table itself lives in a configuration file the editor
loads from `/settings/` so the user can remap it.

The box is internally a small composition: chord-of (from 505)
applied to (any of eight directions) and (any of four face
buttons), gated by which mode triggers are held, looking up the
result in the table. The composition is itself a map fragment
that lives at `/system-maps/radial-menu-chord.json` on the SD
card; phase 8's editor wires it into its input pipeline.

The handedness setting (507) does not affect the radial menu
chord — the chord keeps its physical button identity. What
changes per-handedness is which side the user thinks of as their
direction hand and their action hand, but the radial menu's
mechanism is "one button from each hand" regardless.

## Suggested implementation steps

1. `radial_menu_chord_box()` — composite of chord-of plus mode
   gating plus table lookup.
2. The default lookup table at
   `/system-maps/radial-menu-table-default.json`.
3. Hooks for the editor (phase 8) to override the table per user
   setting.

## Related documents

- `docs/004-input-model.md` — the radial menu chord section.
- `notes/vision/000-vision.md` — the radial menu's role.

## Blocked by

502, 503 (direction source), 505.

## Blocks

508, phase 8 (the editor consumes this).
