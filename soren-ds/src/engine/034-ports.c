/*
 * 034-ports.c — input ports, their cells, and the readiness check that
 * takes no lock (issues 208 and 209).
 *
 * General description: a port is one input of one station. A ring port
 * holds values in cells, each cell carrying its own four-state lock
 * (empty → reserved → ready → claimed → empty), so a writer filling one
 * cell and a reader emptying another never touch the same lock. A static
 * port holds one value every run reads. A port with no source holds
 * nothing, and a station with such a port can never run — which is how a
 * program is assembled a piece at a time, how it parks, and how a broken
 * box takes itself out of service.
 *
 * The readiness check runs at the tail of every write, on exactly the
 * station written to. It claims one ready cell from every ring port, in
 * ascending port order, or gives back what it took and stops. The fixed
 * order is what keeps two cores from each holding one half of a complete
 * set forever.
 *
 * One thing the issue did not foresee, found while building this: two
 * cores can each deliver the last missing value of one set at the same
 * instant, each run the check, and each fail — because each finds the
 * other's port claimed-and-about-to-be-released by the other's failed
 * attempt. Both give up and a complete set sits there with nobody left to
 * look at it. The fix keeps the check lock-free: a station has a count of
 * checks asked for. The first core to raise it from zero does the
 * checking, and keeps claiming until the count it saw is still the count
 * when it finishes; any core that finds the count already raised adds one
 * and leaves, knowing the checker will look again on its behalf. Nobody
 * waits, and every delivery is looked at by somebody after it landed.
 * A welcome side-effect: the checker drains every complete set there is,
 * which answers issue 209's "how long should a core retry" — as long as
 * there are complete sets, and not once more.
 */
#include "031-engine-internal.h"

#define MAX_PORTS_PER_STATION 64

/* {{{ cell_at */
static inline uint8_t *cell_at(const struct port *p, int32_t index)
{
    int32_t page = index / p->cells_per_page;
    int32_t slot = index - page * p->cells_per_page;
    uint8_t **list = atomic_load_acquire(&p->pages);
    return list[page] + (size_t)slot * (size_t)p->stride;
}
/* }}} */

/* {{{ cell_state */
static inline uint32_t *cell_state(uint8_t *cell)
{
    return (uint32_t *)cell;
}
/* }}} */

/* {{{ cell_value */
static inline uint8_t *cell_value(uint8_t *cell)
{
    return cell + CELL_HEADER;
}
/* }}} */

/* {{{ port_init */
int port_init(struct core_ctx *c, struct port *p, int32_t elem_size)
{
    bytes_zero(p, sizeof *p);
    p->tag       = PORT_NONE;
    p->door      = -1;
    p->elem_size = elem_size;
    p->stride    = (int32_t)(CELL_HEADER + round_up_pow2((size_t)(elem_size ? elem_size : 1), 8));
    /* Start as deep as one page holds (issue 208's open question: "as
     * many as fit in one page" rather than a fixed ten). A four-byte value
     * gets 252 cells; a large struct gets at least four. */
    p->cells_per_page = PORT_PAGE_BYTES / p->stride;
    if (p->cells_per_page < MIN_CELLS_PER_PAGE) {
        p->cells_per_page = MIN_CELLS_PER_PAGE;
    }
    p->page_bytes = p->cells_per_page * p->stride;
    p->pages = block_alloc_zero(c->number, sizeof(uint8_t *) * PORT_FIRST_SLOTS);
    p->page_slots = PORT_FIRST_SLOTS;
    p->static_value = block_alloc_zero(c->number, (size_t)(elem_size ? elem_size : 1));
    if (!p->pages || !p->static_value) {
        return ENGINE_NO_MEMORY;
    }
    p->pages[0] = block_alloc_zero(c->number, (size_t)p->page_bytes);
    if (!p->pages[0]) {
        return ENGINE_NO_MEMORY;
    }
    p->n_pages = 1;
    return ENGINE_OK;
}
/* }}} */

/* {{{ port_release */
void port_release(struct core_ctx *c, struct port *p)
{
    if (p->pages) {
        for (int32_t i = 0; i < p->n_pages; i++) {
            if (p->pages[i]) {
                block_free(c->number, p->pages[i]);
            }
        }
        block_free(c->number, p->pages);
        p->pages = (uint8_t **)0;
    }
    p->n_pages = 0;
    if (p->static_value) {
        block_free(c->number, p->static_value);
        p->static_value = (uint8_t *)0;
    }
}
/* }}} */

/* {{{ port_grow */
/* Append one page of empty cells. Nothing is copied and no existing cell
 * moves, so there is no window in which a value could be seen twice or
 * not at all. Answers 1 if the port now has more room than the caller
 * saw (whether or not this call added it). */
static int port_grow(struct core_ctx *c, struct station *s, struct port *p, int32_t seen)
{
    spin_lock(&s->lock);
    int ok = 1;
    if (p->n_pages == seen) {
        if (seen >= PORT_MAX_PAGES) {
            ok = 0;
        } else {
            /* The list of page addresses is full: build one twice as long,
             * publish it, and retire the old one — a reader may still be
             * holding it, and every address in it is still right. The new
             * list is published before the page count that needs it. */
            if (seen == p->page_slots) {
                uint8_t **longer = block_alloc_zero(c->number, sizeof(uint8_t *) * (size_t)seen * 2);
                if (!longer) {
                    spin_unlock(&s->lock);
                    return 0;
                }
                for (int32_t i = 0; i < seen; i++) {
                    longer[i] = p->pages[i];
                }
                uint8_t **old = p->pages;
                atomic_store_release(&p->pages, longer);
                p->page_slots = seen * 2;
                scrap_retire(c, scrap_release_block, old, 0);
            }
            uint8_t *page = block_alloc_zero(c->number, (size_t)p->page_bytes);
            if (!page) {
                ok = 0;
            } else {
                p->pages[seen] = page;
                /* Build, then publish: the page pointer is written before
                 * the count that reveals it. */
                atomic_store_release(&p->n_pages, seen + 1);
                p->growths++;
                atomic_add(&engine.port_growths, 1);
            }
        }
    }
    spin_unlock(&s->lock);
    return ok;
}
/* }}} */

/* {{{ port_write_cell */
int port_write_cell(struct core_ctx *c, struct station *s, struct port *p, const void *value)
{
    for (;;) {
        /* Read the page count once per scan: that is what bounds the
         * scan. A count that grows meanwhile is seen on the next pass. */
        int32_t pages = atomic_load_acquire(&p->n_pages);
        int32_t total = pages * p->cells_per_page;
        int32_t start = atomic_load_relaxed(&p->bookmark);
        if (start >= total || start < 0) {
            start = 0;
        }
        for (int32_t k = 0; k < total; k++) {
            int32_t index = start + k;
            if (index >= total) {
                index -= total;
            }
            uint8_t *cell = cell_at(p, index);
            uint32_t expected = CELL_EMPTY;
            if (atomic_load_relaxed(cell_state(cell)) == CELL_EMPTY &&
                atomic_cas(cell_state(cell), &expected, CELL_RESERVED)) {
                /* Every write copies the full element size, so a stale
                 * value is always completely covered. The copy happens
                 * with no lock held: the cell's own state is the lock. */
                bytes_copy(cell_value(cell), value, (size_t)p->elem_size);
                atomic_store_release(cell_state(cell), CELL_READY);
                atomic_store_relaxed(&p->bookmark, index + 1);
                return ENGINE_OK;
            }
        }
        /* Every cell is occupied: this input is being fed faster than its
         * siblings. Add a page and look again. */
        if (!port_grow(c, s, p, pages)) {
            return ENGINE_NO_MEMORY;
        }
    }
}
/* }}} */

/* {{{ port_write_static */
/* Called holding the station's lock. The value is published with a
 * sequence number that is odd while the bytes are changing, so a reader
 * that raced the write copies again rather than keeping a torn value. */
void port_write_static(struct station *s, struct port *p, const void *value)
{
    (void)s;
    uint32_t seq = atomic_load_relaxed(&p->static_seq);
    atomic_store_relaxed(&p->static_seq, seq + 1);
    __atomic_thread_fence(__ATOMIC_RELEASE);
    bytes_copy(p->static_value, value, (size_t)p->elem_size);
    atomic_store_release(&p->static_seq, seq + 2);
}
/* }}} */

/* {{{ port_read_static */
void port_read_static(const struct port *p, void *out)
{
    for (;;) {
        uint32_t before = atomic_load_acquire(&p->static_seq);
        if (before & 1) {
            continue;
        }
        bytes_copy(out, p->static_value, (size_t)p->elem_size);
        __atomic_thread_fence(__ATOMIC_ACQUIRE);
        if (atomic_load_relaxed(&p->static_seq) == before) {
            return;
        }
    }
}
/* }}} */

/* {{{ port_waiting */
int port_waiting(const struct port *p)
{
    int32_t pages = atomic_load_acquire(&p->n_pages);
    int32_t total = pages * p->cells_per_page;
    int n = 0;
    for (int32_t i = 0; i < total; i++) {
        n += atomic_load_relaxed(cell_state(cell_at(p, i))) == CELL_READY;
    }
    return n;
}
/* }}} */

/* {{{ the claim table */
/* "Take one value from this port" — one row per tag, no row an absence
 * (issue 209). A ring port hands over a ready cell or answers that it has
 * none; a static port has nothing to take and is always satisfied; a port
 * with no source is never satisfied. Adding a fourth tag is adding a row. */

/* {{{ take_ring */
static int take_ring(struct port *p, uint8_t **cell_out)
{
    int32_t pages = atomic_load_acquire(&p->n_pages);
    int32_t total = pages * p->cells_per_page;
    int32_t start = atomic_load_relaxed(&p->read_mark);
    if (start >= total || start < 0) {
        start = 0;
    }
    /* Readers follow their own hint forward, wrapping once. Writers fill
     * forward from theirs, so this is roughly oldest-first — never
     * guaranteed: values may leave a port in a different order than they
     * arrived, which issue 208 states as a deliberate non-guarantee. */
    for (int32_t k = 0; k < total; k++) {
        int32_t index = start + k;
        if (index >= total) {
            index -= total;
        }
        uint8_t *cell = cell_at(p, index);
        uint32_t expected = CELL_READY;
        if (atomic_load_relaxed(cell_state(cell)) == CELL_READY &&
            atomic_cas(cell_state(cell), &expected, CELL_CLAIMED)) {
            atomic_store_relaxed(&p->read_mark, index + 1);
            *cell_out = cell;
            return 1;
        }
    }
    return 0;
}
/* }}} */

/* {{{ take_static */
static int take_static(struct port *p, uint8_t **cell_out)
{
    (void)p;
    *cell_out = (uint8_t *)0;
    return 1;
}
/* }}} */

/* {{{ take_none */
static int take_none(struct port *p, uint8_t **cell_out)
{
    (void)p;
    *cell_out = (uint8_t *)0;
    return 0;
}
/* }}} */

static int (*const take_by_tag[PORT_TAG_COUNT])(struct port *p, uint8_t **cell_out) = {
    [PORT_RING]   = take_ring,
    [PORT_STATIC] = take_static,
    [PORT_NONE]   = take_none,
};
/* }}} */

/* {{{ claim */
/* Walk the ports in ascending order taking one value from each; on the
 * first port that has nothing, give back everything taken and answer 0. */
static int claim(struct station *s, uint8_t **cells)
{
    for (int p = 0; p < s->n_ports; p++) {
        struct port *port = &s->ports[p];
        uint8_t tag = atomic_load_acquire(&port->tag);
        if (!take_by_tag[tag](port, &cells[p])) {
            for (int q = 0; q < p; q++) {
                if (cells[q]) {
                    atomic_store_release(cell_state(cells[q]), CELL_READY);
                }
            }
            return 0;
        }
    }
    return 1;
}
/* }}} */

/* {{{ release_claimed */
/* Mark every claimed cell empty: its value now lives in a task. Or, if
 * building the task failed, mark them ready again so nothing is lost. */
static void release_claimed(struct station *s, uint8_t **cells, uint32_t state)
{
    for (int p = 0; p < s->n_ports; p++) {
        if (cells[p]) {
            atomic_store_release(cell_state(cells[p]), state);
        }
    }
}
/* }}} */

/* {{{ build_and_push */
static int build_and_push(struct core_ctx *c, struct station *s, int32_t index, uint8_t **cells)
{
    struct task *t = task_build(c, s, index, (void **)cells);
    if (!t) {
        release_claimed(s, cells, CELL_READY);
        error_record(s, index, ERROR_NO_MEMORY, task_bytes(s->box));
        return 0;
    }
    release_claimed(s, cells, CELL_EMPTY);
    if (!ring_push(&engine.ring, c->number, t)) {
        error_record(s, index, ERROR_NO_MEMORY, 0);
        atomic_sub(&s->in_flight, 1);
        task_free(c, t);
        return 0;
    }
    engine_wake_sleepers();
    c->stats.tasks_built++;
    transcript_record(TRANSCRIPT_QUEUED, index, (int32_t)t->in_bytes, 0, 0, s->name);
    return 1;
}
/* }}} */

/* {{{ station_recount_open */
/* Called holding the station's lock after a port's tag changes. */
void station_recount_open(struct station *s)
{
    int32_t open = 0;
    for (int p = 0; p < s->n_ports; p++) {
        open += s->ports[p].tag != PORT_STATIC;
    }
    atomic_store_release(&s->open_ports, open);
}
/* }}} */

/* {{{ station_check */
void station_check(struct core_ctx *c, int32_t index)
{
    struct station *s = station_at(index);
    if (!s || atomic_load_acquire(&s->state) != STATION_LIVE) {
        return;
    }
    c->stats.checks++;
    uint8_t *cells[MAX_PORTS_PER_STATION];

    /* Two shapes of station. One whose every port is static is always
     * ready: each check is one run, exactly — a static write is an event,
     * and a chain wired through statics recalculates once per write. The
     * other shape has at least one ring or unconfigured port and runs once
     * per complete set, found by the checker described at the top. */
    if (atomic_load_acquire(&s->open_ports) == 0) {
        for (int p = 0; p < s->n_ports; p++) {
            cells[p] = (uint8_t *)0;
        }
        build_and_push(c, s, index, cells);
        return;
    }

    if (atomic_fetch_add_rel(&s->pending, 1) != 0) {
        c->stats.checks_merged++;
        return;
    }
    for (;;) {
        int32_t seen = atomic_load_acquire(&s->pending);
        while (atomic_load_acquire(&s->state) == STATION_LIVE && claim(s, cells)) {
            if (!build_and_push(c, s, index, cells)) {
                break;
            }
        }
        if (atomic_cas(&s->pending, &seen, 0)) {
            return;
        }
    }
}
/* }}} */

/* {{{ port_take_value */
/* Take one ready value out of a port, as a reader outside any station
 * would: claim a cell, copy it out, empty it. Answers 1 if a value was
 * taken. Used for a program's held results (issue 309). */
int port_take_value(struct port *p, void *out)
{
    uint8_t *cell;
    if (!take_ring(p, &cell)) {
        return 0;
    }
    bytes_copy(out, cell_value(cell), (size_t)p->elem_size);
    atomic_store_release(cell_state(cell), CELL_EMPTY);
    return 1;
}
/* }}} */

/* {{{ engine_port_reserve */
/* Grow a port now so it holds at least `cells` values without growing
 * later: a map's "in N x64". Ports grow on their own, so this is only for
 * somebody who knows better (issue 305). */
int engine_port_reserve(int32_t index, int port, int cells)
{
    struct core_ctx *c = engine_enter();
    struct station *s = station_live(index);
    int r = ENGINE_OK;
    if (!s) {
        r = ENGINE_NO_STATION;
    } else if (port < 0 || port >= s->n_ports) {
        r = ENGINE_NO_PORT;
    } else {
        struct port *p = &s->ports[port];
        while (r == ENGINE_OK && atomic_load_acquire(&p->n_pages) * p->cells_per_page < cells) {
            if (!port_grow(c, s, p, atomic_load_acquire(&p->n_pages))) {
                r = ENGINE_NO_MEMORY;
            }
        }
    }
    engine_leave(c);
    return r;
}
/* }}} */

/* {{{ engine_port_waiting */
int engine_port_waiting(int32_t index, int port)
{
    struct station *s = station_live(index);
    if (!s) {
        return ENGINE_NO_STATION;
    }
    if (port < 0 || port >= s->n_ports) {
        return ENGINE_NO_PORT;
    }
    return port_waiting(&s->ports[port]);
}
/* }}} */

/* {{{ engine_static_value */
int engine_static_value(int32_t index, int port, void *out, size_t max)
{
    struct station *s = station_live(index);
    if (!s) {
        return ENGINE_NO_STATION;
    }
    if (port < 0 || port >= s->n_ports) {
        return ENGINE_NO_PORT;
    }
    struct port *p = &s->ports[port];
    if ((size_t)p->elem_size > max) {
        return ENGINE_WRONG_SIZE;
    }
    port_read_static(p, out);
    return p->elem_size;
}
/* }}} */
