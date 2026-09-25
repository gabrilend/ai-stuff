# analysis-gen.lua

Writes the analysis's variants so no one types them.

- `boxes`: the extra boxes (appended to `pose-boxes.c`):
  - `noop`;
  - `pose_fold`;
  - `make_blob_N` for N = 16 … 122880;
  - `pose_chunk_K` for K = 1 … 256.
- `map`: `analysis.map`, one station per variant; station i takes argument i
  and gives result i.
- `table`: the host's C table of variants (name, request kind, result kind,
  units per task, result size), in station order.
