# 201 — Palette tokens, from dark to bright

**Phase:** 2 — Glass and metal
**Blocked by:** 101

**Blocks**: 202, 206, 208, 210, 211, 213
**Related documents:** docs/visual-language.md (Materials, Team colors),
docs/datapath-glass-and-metal.md

## Current Behavior

No colors are defined.

## Intended Behavior

- One file defines every color as a named token: five metal tones
  (gunmetal, graphite, steel, silver, chrome), five glass tones (smoked to
  frosted-bright, each with a tint and an opacity), paint colors per seat
  (bright, saturated, distinct hues), foe colors (darker, desaturated
  versions, never sharing a hue with a seat), and map tones (muted).
- Nothing else in the code writes a color number; everything asks for a token
  by name. An unknown token name is an error.
- A check (test) that every seat paint color differs from every foe color by
  a minimum hue distance, and that readout text on every metal tone passes a
  contrast minimum.

## Suggested Implementation Steps

1. `src/NNN-the-palette.lua` (NNN from `.file-index-counter`).
2. Hue-distance and contrast checks as a test file.
