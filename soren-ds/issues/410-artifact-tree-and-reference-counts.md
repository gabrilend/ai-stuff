# 410 — Artifact tree and reference-counted artifacts

## Current behavior

The compile pipeline (409) produces a function pointer per build.
A user editing a box and saving repeatedly produces many
function pointers, each living in some allocated page. Without a
lifecycle for those pages — knowing which versions are live, which
have running tasks, which can be reclaimed — the system slowly
fills its heap with abandoned box code.

## Intended behavior

The artifact tree lives under `tmp/compiled/<map>/<box>/<generation>/`
on the RAM-backed `tmp` symlink. Each generation directory
holds:

- `function.bin` — the compiled machine code, copied from the
  page the linker wrote.
- `manifest.json` — what the box's `fn` symbol resolves to,
  what symbols were resolved against the kernel, the source's
  hash, the build's wall-clock timestamp.
- `refs/` — small files recording live references.

The reference-counted descriptor from 208 holds a `refcount`
field per generation. When a task starts running a box, the
worker increments the refcount on the generation the task
dispatched to. When the task ends, the worker decrements.

A generation whose refcount has dropped to zero AND is not the
current (highest) generation is eligible for reclamation. A
background sweep task in the runtime walks the artifact tree
periodically, releases the pages of reclaimable generations back
to 108's allocator, and removes their directories from `tmp/`.

The highest generation always survives. Even if no task is
currently running it, it is the one the next gathering function
will dispatch to. A generation only becomes reclaimable when a
*newer* generation has taken over the descriptor's primary
pointer.

This is the on-device equivalent of soramech proper's `.refs` log
with PID-and-start-time liveness tracking. The on-device version
is simpler because everything runs in the kernel — no
out-of-process holders, no PID recycling, no liveness ambiguity.

## Suggested implementation steps

1. `struct artifact_generation` — pointer, refcount, source
   hash, parent descriptor pointer.
2. `artifact_register(box_name, function_ptr)` — create a new
   generation, write its manifest, link it under the
   descriptor.
3. `artifact_acquire(descriptor *)` — atomic increment.
4. `artifact_release(descriptor *)` — atomic decrement; if it
   reaches zero and another generation exists, schedule
   reclamation.
5. `artifact_sweep_task` — background task body.

## Related documents

- `docs/012-soramech-runtime.md` — reference-counted artifacts
  section.

## Blocked by

108, 208, 409.

## Blocks

411, 412.
