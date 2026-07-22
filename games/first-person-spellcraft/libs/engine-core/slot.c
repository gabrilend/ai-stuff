/* slot.c — the lean fixed-cell slot store.
 *
 * How it works, for a general reader: the store is a bag of slots. Each slot is
 * a tiny fixed-length ring of same-sized pigeonholes plus a one-byte "busy"
 * flag. To touch a slot you first spin on that flag until it's yours, do your
 * read or write of whole pigeonholes, then clear it. Because a value is always
 * a whole fixed-size struct copied under that flag, two threads never see a
 * half-written value. The COUNTER slot skips the flag entirely: it's a single
 * number bumped with one atomic instruction, which is faster and needs no lock.
 *
 * The slots are held as an array of POINTERS, not an array of slots, on purpose:
 * growing the table moves the pointers but never the slots themselves, so a
 * slot's atomic flag keeps its address and stays valid across a table grow.
 */
#include "slot.h"

#include <stdlib.h>
#include <string.h>
#include <stdatomic.h>

/* {{{ struct slot / struct slot_store */
struct slot {
    int32_t kind;
    int32_t cell_size;   /* bytes per cell (QUEUE/LATEST) */
    int32_t n_cells;     /* ring length */
    int32_t first;       /* index of the oldest filled cell */
    int32_t n;           /* number of filled cells */
    uint8_t *cells;      /* n_cells * cell_size bytes, or NULL for COUNTER */
    _Atomic uint32_t counter;   /* COUNTER slots only */
    atomic_flag lock;    /* per-slot spinlock (QUEUE/LATEST) */
};

struct slot_store {
    struct slot **slots; /* array of pointers; pointers move on grow, slots don't */
    int32_t count;
    int32_t cap;
};
/* }}} */

/* {{{ local lock_slot() / unlock_slot() */
/* Acquire/release the per-slot spinlock. Acquire spins with an acquire barrier
 * so the reads that follow can't float above it; release uses a release barrier
 * so the writes that preceded it are visible before the flag clears. This pair
 * is what makes a whole-struct push/peek atomic against a concurrent one. */
static inline void lock_slot(struct slot *sl)
{
    while (atomic_flag_test_and_set_explicit(&sl->lock, memory_order_acquire)) {
        /* spin: another thread holds it. Slots are held briefly (one memcpy),
         * so a spin is cheaper than parking a worker. */
    }
}
static inline void unlock_slot(struct slot *sl)
{
    atomic_flag_clear_explicit(&sl->lock, memory_order_release);
}
/* }}} */

/* {{{ local get_slot() */
/* Resolve a slot id to its pointer, or NULL if the id is out of range. We fail
 * to NULL rather than crash so a mis-wired id is a caught no-op at the boundary,
 * not a segfault deep in a worker. */
static struct slot *get_slot(slot_store_t *s, slot_id_t id)
{
    if (!s || id < 0 || id >= s->count) return NULL;
    return s->slots[id];
}
/* }}} */

/* {{{ slot_store_create() / slot_store_destroy() */
slot_store_t *slot_store_create(void)
{
    slot_store_t *s = calloc(1, sizeof *s);
    return s; /* NULL on OOM propagates to caller */
}

void slot_store_destroy(slot_store_t *s)
{
    if (!s) return;
    for (int32_t i = 0; i < s->count; i++) {
        if (s->slots[i]) {
            free(s->slots[i]->cells);
            free(s->slots[i]);
        }
    }
    free(s->slots);
    free(s);
}
/* }}} */

/* {{{ slot_alloc() */
slot_id_t slot_alloc(slot_store_t *s, int32_t kind,
                     int32_t cell_size, int32_t n_cells)
{
    if (!s) return SLOT_INVALID;

    /* Normalize per flavor. LATEST is one overwritable cell by definition;
     * COUNTER stores no cells at all. Anything else must carry real cells. */
    if (kind == SLOT_LATEST)  n_cells = 1;
    if (kind == SLOT_COUNTER) { cell_size = 0; n_cells = 0; }
    else if (cell_size < 1 || n_cells < 1) return SLOT_INVALID;

    struct slot *sl = calloc(1, sizeof *sl);
    if (!sl) return SLOT_INVALID;
    sl->kind = kind;
    sl->cell_size = cell_size;
    sl->n_cells = n_cells;
    sl->first = 0;
    sl->n = 0;
    atomic_init(&sl->counter, 0);
    /* atomic_flag has no atomic_init; clearing it once here is the documented
     * way to put it in a known-unset state before any concurrent use. */
    atomic_flag_clear(&sl->lock);

    if (n_cells > 0) {
        sl->cells = calloc((size_t)n_cells, (size_t)cell_size);
        if (!sl->cells) { free(sl); return SLOT_INVALID; }
    }

    /* Grow the pointer table if needed (setup-phase only — never while workers
     * run). Doubling keeps allocations amortized O(1). */
    if (s->count == s->cap) {
        int32_t newcap = s->cap ? s->cap * 2 : 8;
        struct slot **grown = realloc(s->slots, (size_t)newcap * sizeof *grown);
        if (!grown) { free(sl->cells); free(sl); return SLOT_INVALID; }
        s->slots = grown;
        s->cap = newcap;
    }
    s->slots[s->count] = sl;
    return s->count++;
}
/* }}} */

/* {{{ slot_push() */
int slot_push(slot_store_t *s, slot_id_t id, const void *data)
{
    struct slot *sl = get_slot(s, id);
    if (!sl || sl->kind == SLOT_COUNTER || !data) return -1;

    lock_slot(sl);
    int rc;
    if (sl->kind == SLOT_LATEST) {
        /* Overwrite the single cell — the newest value simply IS the value. */
        memcpy(sl->cells, data, (size_t)sl->cell_size);
        sl->n = 1;
        rc = 0;
    } else if (sl->n >= sl->n_cells) {
        /* QUEUE full: refuse, so a backlog surfaces instead of silently
         * dropping the oldest. The caller decides what a full ring means. */
        rc = -1;
    } else {
        int32_t at = (sl->first + sl->n) % sl->n_cells;
        memcpy(sl->cells + (size_t)at * sl->cell_size, data, (size_t)sl->cell_size);
        sl->n++;
        rc = 0;
    }
    unlock_slot(sl);
    return rc;
}
/* }}} */

/* {{{ slot_peek() */
int slot_peek(slot_store_t *s, slot_id_t id, void *buf)
{
    struct slot *sl = get_slot(s, id);
    if (!sl || sl->kind == SLOT_COUNTER || !buf) return 0;

    lock_slot(sl);
    int got = 0;
    if (sl->n > 0) {
        /* newest = last-written cell. For LATEST that's cell 0; for QUEUE it's
         * the cell just before the write cursor. */
        int32_t newest = (sl->first + sl->n - 1) % sl->n_cells;
        memcpy(buf, sl->cells + (size_t)newest * sl->cell_size, (size_t)sl->cell_size);
        got = 1;
    }
    unlock_slot(sl);
    return got;
}
/* }}} */

/* {{{ slot_pop() */
int slot_pop(slot_store_t *s, slot_id_t id, void *buf)
{
    struct slot *sl = get_slot(s, id);
    if (!sl || sl->kind != SLOT_QUEUE || !buf) return 0;

    lock_slot(sl);
    int got = 0;
    if (sl->n > 0) {
        memcpy(buf, sl->cells + (size_t)sl->first * sl->cell_size, (size_t)sl->cell_size);
        sl->first = (sl->first + 1) % sl->n_cells;
        sl->n--;
        got = 1;
    }
    unlock_slot(sl);
    return got;
}
/* }}} */

/* {{{ slot_drain() */
int32_t slot_drain(slot_store_t *s, slot_id_t id, void *buf, int32_t max_cells)
{
    struct slot *sl = get_slot(s, id);
    if (!sl || sl->kind != SLOT_QUEUE || !buf || max_cells < 1) return 0;

    lock_slot(sl);
    int32_t took = 0;
    while (sl->n > 0 && took < max_cells) {
        memcpy((uint8_t *)buf + (size_t)took * sl->cell_size,
               sl->cells + (size_t)sl->first * sl->cell_size,
               (size_t)sl->cell_size);
        sl->first = (sl->first + 1) % sl->n_cells;
        sl->n--;
        took++;
    }
    unlock_slot(sl);
    return took;
}
/* }}} */

/* {{{ slot_read_inc() */
uint32_t slot_read_inc(slot_store_t *s, slot_id_t id, uint32_t mod)
{
    struct slot *sl = get_slot(s, id);
    if (!sl || sl->kind != SLOT_COUNTER || mod == 0) return UINT32_MAX;
    /* One atomic fetch-add, no lock: each concurrent caller gets a distinct
     * pre-increment value, which mod `mod` deals distinct 0..mod-1 slots. */
    uint32_t v = atomic_fetch_add_explicit(&sl->counter, 1, memory_order_relaxed);
    return v % mod;
}
/* }}} */

/* {{{ slot_fill() / slot_has_value() */
int32_t slot_fill(slot_store_t *s, slot_id_t id)
{
    struct slot *sl = get_slot(s, id);
    if (!sl) return 0;
    if (sl->kind == SLOT_COUNTER) return 0;
    /* A brief lock so the count read is consistent with concurrent push/pop. */
    lock_slot(sl);
    int32_t n = sl->n;
    unlock_slot(sl);
    return n;
}

int slot_has_value(slot_store_t *s, slot_id_t id)
{
    struct slot *sl = get_slot(s, id);
    if (!sl) return 0;
    if (sl->kind == SLOT_COUNTER) return 1; /* always readable */
    return slot_fill(s, id) > 0;
}
/* }}} */
