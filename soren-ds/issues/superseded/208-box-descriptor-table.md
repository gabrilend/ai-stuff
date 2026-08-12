# 208 — Box descriptor table

## Current behavior

The gathering function (206) needs to look up boxes by name to
know their input port shape, their routing kind, and the
function pointer to call. The slot store (205) needs the
descriptor to size its per-port slot allocations. There is no
table yet.

## Intended behavior

A flat C array of `box_descriptor` structs, compiled into the
kernel image, lists every statically-linked box the kernel knows
about. Each entry carries:

```c
typedef struct {
    const char     *name;
    const port_t   *inputs;
    int             n_inputs;
    routing_kind_t  routing;
    int           (*fn)(box_args_t *args);
    int             generation;
    int             refcount;
} box_descriptor_t;
```

The `name` field is what map JSON files reference. The `fn`
pointer is the function the worker calls when the box fires.
`generation` and `refcount` exist for the hot-swap mechanism
described in `012-soramech-runtime.md`; phase 2 ships them but
the swap mechanism itself lands in phase 4.

Phase 2 ships with a small **test library** of about a dozen
boxes — enough to write the torture test in 211 without needing
the real runtime library that phase 3 builds:

- `noop` — one input, one output, returns the input unchanged.
- `inc` — one numeric input, output is input + 1.
- `add` — two numeric inputs, output is sum.
- `constant-zero`, `constant-one`, `constant-thousand` — no
  inputs, output is the named constant.
- `count-down` — one numeric input, emits N-1 if input > 0, else
  emits nothing (used to terminate test chains).
- `discard` — one input, no output. The sink that drains test
  chains.

Phase 3's runtime replaces this table with the real launch
library (routing kinds, debug-write, the start of the filesystem
boxes, etc.).

A lookup function `descriptor_by_name(const char *)` returns the
descriptor or null if the name is unknown. The gathering function
uses it once per box at map load time, then caches the pointer.

## Suggested implementation steps

1. `box_descriptor_t` and `port_t` struct definitions.
2. The static array `descriptors[]` with the test library.
3. `descriptor_by_name()` — linear scan is fine for this size.
4. The test box implementations (one C function each).

## Related documents

- `docs/003-threading-model.md`.
- `docs/012-soramech-runtime.md` — the box descriptor section.

## Blocked by

108 (descriptors are small but allocated alongside other heap
structures).

## Blocks

206 (gathering looks up descriptors), 209 (workers call
descriptor function pointers), 211 (the demo uses these boxes).
