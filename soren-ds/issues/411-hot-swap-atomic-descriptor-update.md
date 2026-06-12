# 411 — Hot-swap atomic descriptor update

## Current behavior

The compile pipeline (409) produces a function pointer, the
artifact tree (410) holds it under a generation directory, and
208's descriptor table is where the runtime looks up box
functions by name. But the descriptor's `fn` field still points
at the old generation. The new code exists; no one is calling
it.

## Intended behavior

`hot_swap(box_name, new_function_ptr, new_generation)` performs
the atomic store that makes the new code live:

1. Look up the descriptor in 208's table.
2. Acquire-load the current `fn` and `generation` for context
   (used to log the swap).
3. With release ordering, store `new_function_ptr` into the
   descriptor's `fn` field. Store `new_generation` into the
   descriptor's `generation` field. The release ordering
   guarantees any worker that picks up the new pointer also
   sees every byte of the new code (which the compile pipeline
   placed before calling hot_swap).
4. Emit a `hot_swap` event into the RAM transcript ring (310)
   carrying both generations.

After the store, every new fire of the box dispatches to the new
function pointer. In-flight fires that already entered the old
function pointer hold an acquire on the *old* generation's
refcount (410), so the old code stays mapped until they
complete. Because every box is multi-spawn (the runtime doc),
multiple in-flight fires may be using the old generation when
the swap happens; they finish on old code, the swap is correct
for each of them, and the old generation only becomes
reclaimable once the last task drains.

The hot-swap is invoked by:

- The compile pipeline at the end of a successful build, when
  the new function pointer is ready.
- A theoretical "rollback" path that swaps back to a known-good
  generation if a newly-built one is misbehaving. Phase 4 ships
  rollback as a manual call (no automatic detection yet);
  phase 9's protection-mode MMU adds the automatic version when
  a swapped-in box crashes.

## Suggested implementation steps

1. `hot_swap()` — the atomic store path.
2. Integration in 409's compile pipeline post-build.
3. Manual rollback hook `hot_swap_to_generation()` that lets a
   caller pick any live generation, not just the newest.

## Related documents

- `docs/012-soramech-runtime.md` — hot-swap section.

## Blocked by

207, 208, 409, 410.

## Blocks

412.
