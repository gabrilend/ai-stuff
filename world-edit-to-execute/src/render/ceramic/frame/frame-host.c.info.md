# frame-host.c

The ceramic way's `main`, for `frame.map` on the kept engine copy.

- **Usage:** `./frame-ceramic FRAMES WORKERS BACKGROUND`. With
  `CERAMIC_SPIN` set, it reports as `ceramic-graph-spin`.
- **Each frame:**
  - re-arm collection;
  - open one batch; hand in the tick, the eight lane requests, the
    pathfinding requests and (with background) two decodes; close it;
  - wait until 4 fog, 8 cull and every path answer have landed (the count
    is trusted);
  - check every answer's frame number, and fold a checksum.
- **Output:** way, background, frames, workers, mean / p50 / p95 / p99 /
  worst microseconds, checksum, decodes finished.

The regions marked THREADING are what `run-frame.sh` counts.
