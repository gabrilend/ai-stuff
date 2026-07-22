/* slot.h — the lean fixed-cell slot store: the shared-memory wire between
 * threads. Public C API (extern "C", plain signatures) so LuaJIT's FFI can
 * cdef and call it directly.
 *
 * What it is, in a sentence: a thread-safe pool of small ring-buffer slots,
 * each carrying fixed-size struct values, that boxes running on different
 * threads push into and take out of.
 *
 * This is the C sibling of the pure-Lua `src/soramech/000-ring-buffer-slot.lua`
 * reference: same three flavors, same contract — but with real per-slot locking
 * so it is safe across the pool's worker threads, which the single-state Lua
 * version can never be. (A Lua threading library like effil/lanes can't help:
 * they copy values across a managed boundary; they do not share memory. Only C
 * gives us a slot that two OS threads truly share.)
 *
 * Modelled on SoraMech's `009-slot-store.c` — we reuse its hard-won
 * synchronization (a per-slot atomic-flag spinlock on the rings, an atomic
 * fetch-add on the counter) and deliberately DROP what a game one-language
 * engine doesn't need: byte-blob payloads (we store typed fixed-size cells
 * instead), the large-value heap, the cross-language dual ring, tagged pop.
 *
 * Three flavors, chosen at slot_alloc:
 *   SLOT_QUEUE   — FIFO ring. Every value matters; drain them all. (mouse
 *                  deltas: pop all each frame and sum.)
 *   SLOT_LATEST  — one cell the producer overwrites and the consumer peeks;
 *                  the whole struct copies under the lock, so a multi-field
 *                  read can never tear. (the render blackboard.)
 *   SLOT_COUNTER — no payload; an atomic fetch-and-add index dispenser so N
 *                  fan-out consumers never grab the same work item.
 *
 * Lifetime & threading: slots are allocated once during single-threaded setup
 * (graph load), then the slot set is fixed and push/peek/pop/drain run
 * concurrently. Do NOT slot_alloc once worker threads are live — the store
 * grows its slot table then, and that is a setup-phase-only operation.
 */
#ifndef FPS_SLOT_H
#define FPS_SLOT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct slot_store slot_store_t;
typedef int32_t           slot_id_t;

#define SLOT_INVALID ((slot_id_t)-1)

/* Slot flavors. Passed as the `kind` argument to slot_alloc. */
enum {
    SLOT_QUEUE   = 0,
    SLOT_LATEST  = 1,
    SLOT_COUNTER = 2,
};

/* {{{ Store lifecycle */
/* Make an empty store. NULL on allocation failure. */
slot_store_t *slot_store_create(void);
/* Free every slot and the store. Safe on NULL. */
void          slot_store_destroy(slot_store_t *s);
/* }}} */

/* {{{ Slot allocation (setup-phase only) */
/* Allocate a slot.
 *   kind      — SLOT_QUEUE | SLOT_LATEST | SLOT_COUNTER.
 *   cell_size — bytes per cell (the fixed struct size). Ignored for COUNTER;
 *               forced meaningful for QUEUE/LATEST.
 *   n_cells   — ring length. Forced to 1 for LATEST; ignored for COUNTER.
 * Returns the slot id (stable for the store's life) or SLOT_INVALID. */
slot_id_t slot_alloc(slot_store_t *s, int32_t kind,
                     int32_t cell_size, int32_t n_cells);
/* }}} */

/* {{{ Moving values */
/* Push cell_size bytes from `data` into the slot.
 * QUEUE: appends to the ring tail; returns -1 if the ring is full (a real
 *        backlog signal — the value was NOT stored). 0 on success.
 * LATEST: overwrites the single cell; always returns 0.
 * COUNTER: invalid, returns -1. */
int     slot_push(slot_store_t *s, slot_id_t id, const void *data);

/* Copy the current value (newest) into `buf` (cell_size bytes) WITHOUT
 * removing it — the latest-wins read. The whole struct copies under the slot
 * lock, so the read never tears. Returns 1 if a value was copied, 0 if empty. */
int     slot_peek(slot_store_t *s, slot_id_t id, void *buf);

/* Remove and copy the oldest value (FIFO) into `buf`. QUEUE only.
 * Returns 1 if a value was copied, 0 if empty. */
int     slot_pop(slot_store_t *s, slot_id_t id, void *buf);

/* Drain the whole ring, oldest-first, into `buf` (an array of up to
 * max_cells * cell_size bytes), and empty it. Returns the number of cells
 * copied (0..max_cells). This is the drain-and-sum primitive. QUEUE only. */
int32_t slot_drain(slot_store_t *s, slot_id_t id, void *buf, int32_t max_cells);

/* Fetch-and-add on a COUNTER slot: return the current index mod `mod`, then
 * advance atomically, so concurrent callers each get a distinct 0..mod-1. */
uint32_t slot_read_inc(slot_store_t *s, slot_id_t id, uint32_t mod);
/* }}} */

/* {{{ State queries */
int32_t slot_fill(slot_store_t *s, slot_id_t id);      /* filled cell count */
int     slot_has_value(slot_store_t *s, slot_id_t id); /* 1 if readable */
/* }}} */

#ifdef __cplusplus
}
#endif

#endif /* FPS_SLOT_H */
