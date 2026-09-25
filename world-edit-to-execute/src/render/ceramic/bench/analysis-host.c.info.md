# analysis-host.c

The performance analysis's host `main`, for any one variant in
`analysis.map`.

- **Usage:** `./analysis VARIANT UNITS FRAMES WORKERS`, where VARIANT is a
  box name from `analysis-gen.lua`.
- **Each frame:**
  - re-arm collection and deliver `units / per` requests (timed as
    "delivering");
  - wait for the count, then wait out every worker mid-task, whose epoch is
    odd, so every counted result has really been copied in (timed as the
    "landing wait");
  - fold the results into a checksum.
- **Output:** variant, units, units per task, workers, frames, mean / p50 /
  p95 / p99 / worst microseconds, mean delivering, mean landing wait, and the
  checksum (00000000 for variants without poses).
- **Variant table:** spliced in at the marker by `run-analysis.sh`, from
  `analysis-gen.lua table`.
