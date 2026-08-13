# 902 — Per-app memory region

## Current behavior

The MMU is on (901) and enforces per-page permissions, but the
kernel does not yet assign apps to regions. Every app's
allocations still come from the kernel's shared heap.

## Intended behavior

Each loaded app gets its own region of physical memory carved
out of the kernel's heap. The page allocator from 108 grows a
new entry point: `page_alloc_for_app(app_handle, size)` returns
pages from the named app's region. The kernel-internal
allocation path stays unchanged.

A region's shape:

- A starting physical address.
- A size in bytes (typically a few megabytes per app at launch
  — enough for the app's stations and the cells its ports hold,
  its surfaces, and reasonable working memory).
- A page-permission tag the MMU uses to determine access from
  this app's worker contexts.

Region assignment:

1. At app load time (303), the runtime asks for a region of the
   declared size. The region allocator (a small subsystem
   inside the page allocator) picks contiguous free space and
   sets its permissions in the page table from 901.
2. Subsequent allocations the app makes for itself — surfaces,
   the pages a port adds as it grows, the blocks its tasks come
   from — go through `page_alloc_for_app`. The pages come from
   inside the app's region, which means the striping from 203
   becomes per-region as well as per-core.
3. At app unload time (909), every page in the app's region is
   freed, the region itself is returned to the pool, and the
   page table entries are reset to kernel-only.

A worker thread's `worker_context` (202) gains a `current_app`
field. When the worker starts a task, it sets this field. When
the task ends, it clears the field. The MMU fault handler (903)
reads the field to decide whether a fault is "this app touched
its own memory" (legal) or "this app touched someone else's"
(faulting).

## Suggested implementation steps

1. `struct app_memory_region` — start, size, permission tag.
2. Region allocator inside 108.
3. `page_alloc_for_app()`.
4. `worker_context.current_app` field and its updates in the
   scheduling loop (209).

## Related documents

- `docs/007-memory-model.md`.

## Blocked by

108, 202, 209, 303, 901.

## Blocks

903, 905, 909.
