# memory-budgeter.lua

Estimate-and-fit memory budgeter for threaded / GPU stages (Issue 10-057). Given a
stage's memory shape and a worker-count request, it answers "how many workers fit in
free memory without swapping?" — and when even the shared data won't fit, it **warns
and continues** (relying on swap) rather than aborting. One budgeter serves both
system RAM and GPU VRAM; only the "how much is free" measurement differs.

The memory shape every stage shares: a **fixed** part loaded once (caches, a model)
plus a **per-worker** part that scales with the worker count. The safe count is
`floor((free * headroom - fixed) / per_worker)`.

## External functions

### `M.fit_threads(spec) -> integer`
The live entry point. Probes the chosen memory pool, computes the safe worker count,
logs the estimate and decision, and returns the count (always >= 1). `spec` fields:
- `pool` — `"ram"` or `"vram"` (which memory to measure; ignored if `probe` given)
- `fixed` — bytes loaded once, shared across workers
- `per_thread` — bytes each worker adds (0 / nil if workers cost no extra memory)
- `want` — requested worker count
- `headroom` — optional fraction of free memory to use (default `0.7`)
- `probe` — optional `function() -> free_bytes` overriding the pool default (use for
  GPUs the built-in VRAM probe can't read)
- `label` — optional short tag for the log lines (e.g. `"HTML"`)

Logs one info line with the estimate always; adds an info line when it reduces the
count, or a **warning** (not an error) when the fixed data alone overflows the budget.

### `M.compute_fit(available, fixed, per_thread, want, headroom) -> table`
The pure decision — numbers in, plan out, no I/O (unit-testable without real memory).
Returns `{ threads, reduced, swapping, budget }`:
- `threads` — safe worker count (>= 1)
- `reduced` — true if cut below `want` to fit
- `swapping` — true if even one worker overflows the budget (caller should warn; the
  fix is to shrink `fixed`, not change the worker count)
- `budget` — `available * headroom`, the usable ceiling

### `M.default_probe(pool) -> function`
Maps `"ram"` / `"vram"` to its built-in free-memory probe. RAM reads
`/proc/meminfo` MemAvailable; VRAM queries `nvidia-smi` (errors with guidance on
non-NVIDIA GPUs — supply a custom `probe` instead). Errors on an unknown pool.

### `M.file_size_bytes(path) -> integer | nil`
On-disk size of a file (via seek, no shell), or `nil` if absent. Convenience for the
common `fixed = cache_file_size * parse_factor` descriptor.

## Notes
- Exact worker-count boundaries round **down** under the default 0.7 headroom (a
  floating-point artifact) — conservative by one worker, which is the safe direction.
- Tests: `libs/memory-budgeter.test.lua` (19 checks; pure cases + a live-probe smoke
  test). Run `luajit libs/memory-budgeter.test.lua`.
