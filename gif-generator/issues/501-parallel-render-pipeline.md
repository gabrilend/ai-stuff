# 501 — parallel render pipeline

## Current Behavior

Everything runs on one thread: the sim ticks, then the frame is
splatted, tone-mapped, indexed, and compressed, then the next tick.
The frame snapshot border exists but only one worker stands at it.

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
