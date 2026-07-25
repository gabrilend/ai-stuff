# 028-parallel — the many-hands pipeline

The pipeline-of-snapshots strategem performed: the simulator ticks
in order on the main thread while effil worker threads (each its own
LuaJIT state running these same modules) splat, tone-map, index, and
LZW-compress frames from packed snapshot strings; results reassemble
by sequence number — the only ordering point. Workers consume no
randomness and addition commutes, so the same scene and seed yield
byte-identical gifs with one worker, many, or none (the sequential
runner) — the honesty test that everything else here rests on.

The vehicle choice is recorded at the file head: the house C
threadpool was structurally disqualified before any stopwatch (it
dispatches C functions; these stages are Lua).

## Usable surface

- **render_to_gif(compiled, dir, workers) → bytes, facts** — one
  worker is a first-class road, not a fossil; zero is refused.
- **pack_snapshot(snapshot) → string, count** — the wire format
  (documented at the file head; fade rides at full width for the
  same identity reason the snapshot module keeps doubles).

Callers must compile fresh per render: compiled scores carry live
per-stroke emission carries, and a reused timeline would leak one
render's fractions into the next.
