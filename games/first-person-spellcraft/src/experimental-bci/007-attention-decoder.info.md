# 007-attention-decoder — info

> Black-box summary of the BCI **attention decoder** (data generation). Part of the
> experimental BCI branch (issue 207, Phase 2 stretch). DOCUMENTED, NOT SCHEDULED.

## What this module is

Turns a coarse "attention" direction, held over time, into an aim orientation
(`yaw`, `pitch`). Attention is modelled as a *velocity* of gaze: held attention
drifts the aim that way at `drift_rate`; returning to `center` lets the aim rest
where it is (no spring-back). The aim is clamped to the neck's `max_yaw`/`max_pitch`.
Pure — same trace + same `dt` gives the same path. Separate from the tension model
(008), which holds the head where this says to look.

## External functions

- `M.neutral_aim() -> {yaw=0, pitch=0}` — the straight-ahead rest pose.

- `M.advance(desc, aim, direction_name, dt) -> new_aim`
  Integrates one `dt` step of held attention into a NEW aim table (input not
  mutated). `yaw+` is rightward, `pitch+` is upward; both clamped to the limits.

- `M.run_trace(desc, trace, dt) -> path`
  Plays a scripted `{ {direction, seconds}, ... }` trace from neutral, sampling each
  segment in `dt` steps (a short segment still gets ≥1 step, so nothing is skipped).
  Returns the aim PATH: an array of `{t, direction, yaw, pitch}`; the last entry is
  the final aim. Errors on non-positive `dt` and validates the descriptor first.

## Notes for a future reader

- No spring-back is deliberate: a physical neck holds its turn. If a future design
  wants attention to mean a *target* (ease toward it) rather than a *velocity*, that
  is a different decoder — add it as a mode, do not silently change this one.
