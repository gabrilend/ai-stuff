# 109 — Soramech: stations, slots, and the pool

**Phase:** 1 — The world beneath
**Blocked by:** 101

**Blocks**: 105, 106, 107
**Related documents:** docs/architecture.md (The shape: soramech),
/mnt/mtwo/programs/sora/minimal-soramech/docs/ (001–006)

## Current Behavior

There is no engine. Phase 1's other issues were first written assuming a
plain thread pool; they now assume this one.

## Intended Behavior

The program's runtime is the soramech pattern (consensual coroutines):

- A **box** is a function of its inputs, returning one value, remembering
  nothing.
- A **station** places a box in the map: input slots (small queues), output
  ports with destinations, and a kind — plain, comparator (less / equal /
  greater ports) or iterator (next port each run).
- A station runs when, and only when, every input slot holds a value. The
  delivery of the last missing value creates the task and hands it to the
  pool; any free worker runs it. Nothing polls.
- State lives on wires: a station whose output feeds its own input carries a
  running value around a loop (the world tick is such a loop).
- No box blocks. Unknown boxes, unconnected slots and mistyped wires stop the
  program at load with a message naming the station.
- Joins that combine many inputs (all directions, all seats) combine them in
  a fixed order, never arrival order, so results are deterministic.
- The map (which stations, which wires) is a data file read at start.

## Suggested Implementation Steps

1. Decide the route (open question 7 in docs/open-questions.md): Lua
   stations over LÖVE threads and channels, or minimal-soramech's C engine
   through LuaJIT's FFI. Record the decision and its reason here.
2. `src/NNN-soramech-stations.lua` (+ `.info.md`): station table, slots,
   readiness check at delivery, task creation.
3. `src/NNN-soramech-pool.lua`: worker threads taking tasks.
4. `src/NNN-soramech-map-loader.lua`: read and validate the map file.
5. Tests: a counter loop counts to N; a two-input station never runs with
   one input; a fan-out of 8 stations runs on several workers at once;
   a missing wire stops the load with the station named.

## Open questions

- Lua reimplementation or the C engine through FFI? (Open question 7.)
