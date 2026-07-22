# slot.h / slot.c — public surface

The **shared-memory wire** between engine threads: a thread-safe pool of small
ring-buffer slots carrying **fixed-size struct values**. This is the C sibling of
the pure-Lua `src/soramech/000-ring-buffer-slot.lua` reference — same three
flavors, same contract — but with real per-slot locking so it is safe across the
pool's worker threads (a Lua threading library can't do this: effil/lanes copy
values, they don't share memory).

FFI-friendly by design: `extern "C"`, opaque `slot_store_t *`, plain signatures.
LuaJIT can `ffi.cdef` this header and `ffi.load` the compiled library directly.

## Flavors (the `kind` passed to `slot_alloc`)

- **`SLOT_QUEUE`** — FIFO ring. Every value matters; drain them all.
- **`SLOT_LATEST`** — one cell the producer overwrites and the consumer peeks;
  the whole struct copies under the lock, so a multi-field read never tears.
- **`SLOT_COUNTER`** — no payload; an atomic fetch-and-add index dispenser.

## Store lifecycle

- `slot_store_t *slot_store_create(void)` — empty store; NULL on OOM.
- `void slot_store_destroy(slot_store_t *s)` — frees every slot; safe on NULL.

## Slot allocation (setup-phase only)

- `slot_id_t slot_alloc(s, kind, cell_size, n_cells)` — returns a stable id or
  `SLOT_INVALID`. `LATEST` forces `n_cells = 1`; `COUNTER` ignores both sizes.
  **Do not call once worker threads are live** — it grows the slot table.

## Moving values

- `int slot_push(s, id, data)` — copy `cell_size` bytes in. `QUEUE` returns `-1`
  when full (real backlog signal, value not stored); `LATEST` always `0`
  (overwrite); `COUNTER` returns `-1`.
- `int slot_peek(s, id, buf)` — copy the current (newest) value out without
  removing it. Returns `1` if copied, `0` if empty. The latest-wins / getter read.
- `int slot_pop(s, id, buf)` — remove and copy the oldest value. `QUEUE` only.
  `1`/`0`.
- `int32_t slot_drain(s, id, buf, max_cells)` — remove all queued cells oldest-
  first into `buf` (array of `max_cells * cell_size` bytes); returns count. The
  drain-and-sum primitive. `QUEUE` only.
- `uint32_t slot_read_inc(s, id, mod)` — fetch-and-add on a `COUNTER`; distinct
  `0..mod-1` per concurrent caller. `UINT32_MAX` on wrong flavor / `mod == 0`.

## State queries

- `int32_t slot_fill(s, id)` — filled cell count (0 for `COUNTER`).
- `int slot_has_value(s, id)` — 1 if readable (`COUNTER` always readable).

## Threading & lifetime

- **Setup single-threaded, run concurrent.** Allocate every slot during graph
  load; after that the slot set is fixed and push/peek/pop/drain run in parallel.
- **Locking:** per-slot `atomic_flag` spinlock on the rings (held for one
  `memcpy`); a lockless `atomic_fetch_add` on the counter. Modelled on SoraMech's
  `009-slot-store.c`.
- **Deliberately dropped** vs. SoraMech: byte-blob payloads (we use typed fixed
  cells), the large-value heap, the cross-language dual ring, tagged pop. See
  `docs/soramech-notes.md` and issue `101` for the one-by-one skip rationale.

## Test

- `slot-test.c` — the regression prover: single-thread contract (mirrors the Lua
  reference) + a threaded-queue exactness check + a threaded-latest torn-read
  probe. Build with `-std=c11 -pthread` and run; exit 0 = pass.

## Related

- `src/soramech/000-ring-buffer-slot.lua` — the single-thread Lua reference /
  test-double for this same contract.
- `docs/soramech-notes.md` — patterns 2, 3, 4, 7 (transport, drain-and-sum,
  ownership publish, the render blackboard).
