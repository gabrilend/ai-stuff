# 002-palette — the glow palette and indexer

Spends GIF's 256 colors on purpose: black alone at index 0, a
gamma-spaced ramp per declared hue (dark half gets the most steps), a
shared gray ramp on top for white-hot cores. Indexing is arithmetic —
saturation gates gray, hue angle picks a ramp, inverted ramp gamma
picks the step — never a 256-way search.

## Usable surface

- **hues** — the vocabulary table: hue name → base color in linear
  light. Extending the vocabulary is adding a row; the compiler and
  the porch grammar both read this table, so it is the single truth.
- **hue_color(name) → r, g, b** — a hue's light color for the
  splatter. Unknown names refused with the full legal list.
- **build(declared_names) → palette** — seats declared hues into the
  256 slots; refuses to seat more hues than can each keep a readable
  ramp, and refuses an empty declaration. The palette carries the
  byte block the gif encoder embeds, plus each ramp's seat range.
- **index_of(palette, r, g, b) → 0..255** — tone-mapped floats to
  palette index.

Knobs (RAMP_GAMMA, WHITE_STEPS, MIN_RAMP, GRAY_SAT) at the file head;
tuning belongs in docs/balance-updates.md.
