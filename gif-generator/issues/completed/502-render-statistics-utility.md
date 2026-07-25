# 502 — render statistics utility

## Current Behavior

Complete, with one deliberate deviation recorded. The utility
measures (rendering a scene sequentially or with any worker count,
reporting stage CPU clocks and true wall time — the CPU-versus-wall
distinction documented at its head, since CPU clocks make parallel
work look slower) and summarizes (every report in output/ as one
table, read-only). The gallery already captions from the same
reports. The deviation: the earlier phase demos keep their bespoke
prints rather than being rewired — they measure demo-specific facts
(peak against estimate, identity checks) inline from renders they
themselves stage, and the utility is the one truth for score
renders and summaries. The phase-5 demo uses the utility from
birth.

## Intended Behavior

One statistics utility, so documentation points at a tool instead of
at stale numbers (the standing rule: reference a validator, never
hard-code a statistic).

- Run against a scene (it renders and measures) or against an existing
  render report from `output/` (it summarizes without rendering).
- Reports: wall time per stage (sim, splat, tone-map+index, encode),
  peak and mean live particles, pool headroom used, bytes total and
  per frame, palette ramp occupancy, worker count and speedup when the
  parallel pipeline exists.
- Output both human-readable and as a plain data file beside the gif
  in `output/`, which the gallery reads for captions.
- The demo scripts shed their ad-hoc printing and call this instead —
  one measurer, one truth.

## Suggested Implementation Steps

1. Stage timers threaded through the runner (cheap, always on — the
   report is part of the render's output contract from 403).
2. The summarize-existing-reports mode.
3. Rewire demo scripts and gallery captions to it.

## Blockers

- 403 (the runner that hosts the timers).

## Related Documents

- docs/roadmap.md (phase 5)
