---
name: stick quantization and dead-zone tuning
phase: 4
status: pending
blockedBy: [101]
---

# 401 — stick quantization and dead-zone tuning

The two analog sticks are sampled, dead-zoned, and quantized into N
discrete wedges (default 8). This is the foundation that the radial
keyboard and any other stick-driven UI builds on.

## current behavior

The broker reads raw stick events but does no processing. Stick state
is "raw (x, y)" with values from `-1.0` to `+1.0` per axis.

## intended behavior

- For each stick, the broker maintains a derived state: `wedge` (one
  of N integers, 0..N-1, with -1 meaning "in dead zone") and
  `magnitude` (0.0..1.0).
- N defaults to 8 (8-way directional input). Configurable per stick.
- Dead zone is configurable; default 25% of the stick's range.
- Hysteresis prevents jitter at wedge boundaries: a stick must move
  ~10 degrees into a new wedge before the transition fires.
- A small calibration utility lets the user (or developer) sample
  the actual stick range, since cheap analog sticks rarely report
  exactly `-1..+1`.

## suggested implementation steps

1. Add `src/broker/stick.lua` with `update(raw_x, raw_y, prev_state)
   → new_state`. Pure function; trivially testable.
2. Implement dead-zone (radial: any (x, y) with `sqrt(x² + y²) <
   dead_zone` is wedge -1).
3. Implement wedge quantization: `angle = atan2(y, x)`, divide by
   `2π / N` to get the wedge.
4. Implement hysteresis: if `prev_state.wedge == W`, require an
   angular deviation of at least the hysteresis threshold to switch
   wedges.
5. Write a calibration script (one-off): displays current raw values
   on the bottom panel, the user moves the sticks to their extremes,
   the broker captures the actual range and saves it to
   `~/.apple-IIds/stick-calibration.lua`.
6. Test on real hardware: rotate each stick in slow circles, observe
   wedge transitions are smooth and don't double-fire at boundaries.

## related documents

- `docs/003-input-system.md` — radial keyboard grid
- `docs/002-hardware-target.md` — stick angular resolution assumption

## known design questions

- Should the wedge count be different per stick? Yes — the radial
  keyboard's design says left stick may be 4 wedges and right stick
  may be 8. Make `N` per-stick configurable, default both to 8.
- Should the dead-zone be radial or square? Radial — square dead-zones
  feel weird because the "diagonal" range is different from the
  "cardinal" range.
- Could we use the gyro to refine the stick reading? Probably yes,
  later, in a fine-cursor mode. Not for stick quantization itself.
