# plain.c

The benchmark's two ways without the engine: one thread, or a hand-written
parallel loop (persistent threads, one fixed slice each, meeting at
barriers).

- **Usage:** `./plain plain|parallel UNITS FRAMES [THREADS]`.
- **Output:** the same 13 tab-separated columns as `analysis-host.c` (way,
  units, 0, threads, frames, mean / p50 / p95 / p99 / worst microseconds, 0,
  0, checksum). The checksum is the XOR of every pose word, plus the frame
  number.
