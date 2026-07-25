# 016-easing — motion curves and fade envelopes

Two dispatch tables of pure functions, and the single truth all
vocabulary checks derive from. EASINGS shape motion (raw
time-fraction → shaped progress): linear, stroke (the vision's
slow-then-fast brush gesture), ease-out, smoothstep. ENVELOPES shape
brightness (raw time-fraction → emission strength): hold, in, out,
in-out, flash. Adding a curve is adding a row; the validator and the
porch grammar read these tables, so a word learned here is learned
everywhere.

## Usable surface

- **EASINGS / ENVELOPES** — the tables themselves (read by the
  validator and grammar generator).
- **motion(name) → fn** / **envelope(name) → fn** — lookups whose
  refusals carry the legal words.
- **names(table) → "a, b, c"** — the legal words, sorted, one voice
  for error messages, validation, and grammar.

Contract (property-tested across whole tables): easings pin 0→0 and
1→1, stay in [0,1], never walk backward; envelopes stay in [0,1].
Knobs (STROKE_POWER, RAMP) at the file head; tuning belongs in
docs/balance-updates.md.
