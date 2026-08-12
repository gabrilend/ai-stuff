# 207 — Release/acquire memory ordering on ARM

## Current behavior

The queue (204) and the slot store (205) both have atomic
operations that publish "this cell now holds a value." On ARM,
which has a weak memory model, those atomic operations are not
enough by themselves to guarantee that another core sees the
value bytes before it sees the atomic flag flip. Without the
right ordering on those atomics, a consumer can legally observe
the flag-true state and load the cell's bytes, getting whatever
was there *before* the publishing thread did its store. The
firing rule would silently see stale values.

## Intended behavior

Every atomic operation in the threading core that publishes a
visible state change uses **release** ordering, and every atomic
operation that observes such a state change uses **acquire**
ordering. This is the C11 `stdatomic.h` convention; the compiler
emits the right barrier instructions for ARM under the covers, so
the kernel never writes a bare DMB or DSB.

The specific cases:

- `slot_push` stores the value bytes into the cell, then
  performs a `memory_order_release` store on the cell's occupancy
  flag. A consumer doing `memory_order_acquire` load of the flag
  is guaranteed to see the value bytes too.
- `slot_pop` does an acquire load of the flag before reading the
  bytes. After reading, it does a release store to clear the
  flag.
- The queue's producer counter advances with release ordering;
  the consumer counter advances with acquire ordering on read
  and release ordering on write.
- The gathering atomic uses `compare_exchange_strong` with
  acquire on success (we just observed the unlocked state and
  are about to read slot contents) and release on the post-pop
  unlock (we just wrote the new slot state and want consumers to
  see it).
- The unique return slot's "value landed" flag is a release
  store; the downstream consumer's gathering function does an
  acquire load.

The release-acquire pair is the unit of correctness. Get every
pair right and the runtime above this layer never sees torn or
stale values. Get one pair wrong and the bug manifests rarely,
under load, in non-reproducible ways. This issue is largely
about reviewing every atomic in the threading core and tagging
each one with the right ordering.

## Suggested implementation steps

1. Audit every atomic call site in 203, 204, 205, 206.
2. Tag each with release or acquire as appropriate; write a
   one-line comment per call site explaining the choice.
3. A small per-platform test using ARM's DMB-omitted assembly
   to deliberately race release/acquire pairs; the test should
   detect ordering bugs (it should fail before the fix and pass
   after).

## Related documents

- `docs/003-threading-model.md` — the visibility-on-ARM section.

## Blocked by

204, 205, 206 (this issue tags atomics in those issues).

## Blocks

211 (the torture test exercises the orderings).
