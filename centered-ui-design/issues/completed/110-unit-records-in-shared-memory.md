# 110 — Unit records in shared memory, claimed first-come-first-served

**Phase:** 1 — The world beneath
**Blocked by:** 109
**Blocks:** 111, 406
**Related documents:** docs/architecture.md (The shape: soramech),
docs/datapath-world-tick.md
**Completed:** 2026-10-10

## Current Behavior

Built. Every unit's state is a 48-byte record of twelve 32-bit floats in one
of two blocks of shared memory (LÖVE byte data, reached through LuaJIT's
FFI). A header block says which block is the front and how many seconds the
step covers. Each step, one soramech task per unit sits in the pool; worker
threads take them first come, first served, read the unit from the front,
write it to the back, and report done. When every unit has reported, the
join station swaps the blocks and only then writes waiting orders and the
named unit into the new front. The graphics card reads the front block
unchanged as per-unit drawing data. Measured: 192 units, 6 workers, one
step per frame at 240 frames per second.

## Intended Behavior

- One fixed-size record per unit, plain 32-bit floats, so workers and the GPU
  read the same bytes.
- Two blocks, front and back; reads from the front, writes to the back, swap
  when every unit's update has arrived — no reader sees a half-written unit,
  and finishing order cannot change the result.
- Each unit's update is one soramech task, taken first come, first served.
- The next step's clock fires only when the join has every "done".
- Orders and names are written only at the swap.

## Implementation Steps (as built)

1. `src/005-unit-records.lua`: the record and header layouts (ffi structs),
   the matching LÖVE vertex format (UnitA, UnitB, UnitC), array views over
   raw memory.
2. `src/016-the-game.lua` (load): two unit blocks and a header as byte data;
   handed to every worker through the "worker-setup" channel.
3. `src/006-the-move-box.lua`: the move box.
4. `src/009-soramech-worker.lua`: the worker loop (pool → box → done).
5. `src/016-the-game.lua`: clock, one move station per unit, join; the swap
   (`at_the_swap`) applies orders and names.
6. Tests in `src/017-the-tests.test.lua`: the record is 48 bytes; units taken
   in a scrambled order give exactly the same step as in order.

## Decisions

- Records are 32-bit floats, not 64-bit, so the GPU can read them unchanged.
  The cost: positions round to about 2.4e-7 of a tier per step (see 111).
- Delivery of "done" goes through the main thread (the Lua route of 109),
  not the worker itself, because Lua states cannot share station tables.
