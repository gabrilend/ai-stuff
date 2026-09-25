# ceramic-host.c

The copy-cost benchmark's host `main` for `per-unit.map` or `per-chunk.map`.
It replaces serac's emitted `main`; see `run-copy-cost.sh`.

- **Usage:** `./per-unit UNITS FRAMES` (or `./per-chunk`).
- **Each frame:** re-arm collection, deliver the frame's requests, wait for
  the count, fold the results into a checksum.
- **Output:** one line (way, units, frames, workers, mean and best
  microseconds, checksum).
- **Note:** it trusts the engine's count, which rises before results are
  copied in. `analysis-host.c` waits correctly and supersedes it for timing.
