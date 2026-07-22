# 006-attention-trace-descriptor — info

> Black-box summary of the BCI **attention descriptor** (data at rest). Part of the
> experimental BCI branch (issue 207, Phase 2 stretch). DOCUMENTED, NOT SCHEDULED —
> nothing depends on it.

## What this module is

The data definition of the software core for the imagined brain-interface aim
source: the vocabulary of coarse "attention" directions, the tuning knobs for the
decoder (007) and the ceiling-headset tension model (008), and a sample scripted
trace. It holds numbers and rules; it decodes and pulls nothing.

## External functions

- `M.default_descriptor() -> desc`
  The shipped config: `directions` (name → raw lean vector, a dispatch table),
  `drift_rate` / `max_yaw` / `max_pitch` (decoder), and `rig` (`base_tension`,
  `gain`, `min_tension`, `max_tension`, and four named `cables`). No side effects.

- `M.example_trace() -> {{direction, seconds}, ...}`
  A scripted daydream (center → up-left → right → down → center) the demo plays to
  prove the pipe with no brain in the loop.

- `M.validate(desc) -> desc`
  Proves a descriptor well-formed, erroring LOUDLY on the first problem (min < base
  < max tensions, positive gains/limits, the four opposing cables present, a
  `center` direction). Returns the same `desc` for chaining.

- `M.lean_vector(desc, direction_name) -> x, y`
  Resolves a named direction into a UNIT lean vector (`x` = right+, `y` = up+), or
  `0, 0` for center. Errors on an unknown name (no guessed direction).

## Notes for a future reader

- Diagonals are stored raw and normalised here, so "up-left" drifts the aim at the
  same speed as a cardinal direction. `x` is rightward, `y` is upward — the same
  convention the decoder and tension model read.
