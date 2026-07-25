# 501 — parallel render pipeline

## Current Behavior

Complete. The measurement the blueprint demanded turned out to be
structural, and is recorded in the module head: the house C
threadpool dispatches C functions, and the stages being parallelized
are Lua — driving them from C threads would mean one embedded Lua
state per thread plus glue, which is the effil design wearing a
heavier coat. So: effil threads (the prebuilt shelf .so loads under
LuaJIT), snapshots packed as flat strings (wire format documented,
fade at full width for identity), jobs and results through channels,
reassembly by sequence number as the only ordering point. The
honesty test passes: sequential runner, one worker, and three
workers yield byte-identical gifs. One lesson recorded in the test:
compiled scores carry live per-stroke emission carries, so every
render must compile fresh or one render's fractions leak into the
next. The encoder split into compress-frame and assemble halves so
workers own the expensive half; the completed encoder issue carries
the cross-note.

## Intended Behavior

The pipeline-of-snapshots strategem made real: the simulator keeps
ticking while worker threads rasterize and LZW-compress finished
snapshots; the encoder reassembles frames by sequence number and
writes the file.

- Two candidate vehicles, decided by measurement, not taste — and the
  measurement recorded in this issue when taken: effil Lua threads
  (`libs/lua/effil-jit` in the shared library area) with snapshots
  through channels, versus the house C threadpool
  (`my-libs/threadpool`) driven over FFI with snapshots in shared FFI
  memory.
- Additive splatting and per-frame LZW are order-independent by
  construction (decisions recorded in the rendering and encoding
  datapaths); reassembly is the only ordering point.
- Determinism must survive: same scene, same seed, same bytes,
  regardless of worker count — this is the pipeline's honesty test,
  run with one, two, and many workers.
- Single-thread mode remains a first-class path (worker count one,
  same code road), not a preserved fossil.

## Suggested Implementation Steps

1. The measurement: render a heavy reference scene both ways, small;
   pick; record numbers and choice here and in the datapath docs.
2. Snapshot hand-off and sequence-numbered reassembly on the chosen
   vehicle.
3. The determinism test across worker counts.

## Blockers

- 403 (a whole pipeline to parallelize); the snapshot border from 204.

## Related Documents

- strategems/pipeline-of-snapshots (the pattern)
- docs/datapath-particle-sim.md, docs/datapath-rendering.md (the
  border and the order-independence it rests on)
