/*
 * 036-delivery.c — from "a box just returned" to "another box is queued
 * to run because of it" (issues 211 and 308).
 *
 * General description: the core that ran a box carries its return value
 * on itself. It asks the station's kind which exit the value leaves by,
 * reads that exit's destination list once (nobody ever edits a list; a
 * rewire swaps in a new one), and for each destination takes an empty
 * cell, copies the value in, marks it ready, and runs the destination's
 * readiness check — which may build and queue a task. No lock is taken
 * anywhere on this path except the task ring's, at the very end.
 *
 *   choose exit → read list → for each {station, port}:
 *                               take a cell → copy → mark ready → check
 *
 * Fan-out is not a kind of box: it is one exit with several destinations.
 * A box that returns nothing is a sink and delivery is skipped. An exit
 * wired to nothing discards, which is what lets a program be assembled a
 * piece at a time.
 */
#include "031-engine-internal.h"

/* {{{ core_random */
/* xorshift64*: a core's own stream, seeded once. Per-core state, never
 * box state, so it breaks no rule about boxes remembering. */
uint64_t core_random(struct core_ctx *c)
{
    uint64_t x = c->random ? c->random : 0x9e3779b97f4a7c15ull;
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    c->random = x;
    return x * 0x2545f4914f6cdd1dull;
}
/* }}} */

/* {{{ engine_random */
uint64_t engine_random(void)
{
    struct core_ctx *c = engine_here();
    if (c->number == OWNER_OUTSIDE) {
        platform_halt("engine_random: only a core has a random stream");
    }
    return core_random(c);
}
/* }}} */

/* {{{ read_integer */
/* Widen a value of `size` bytes to 64 bits, as signed or unsigned. */
static uint64_t read_integer(const uint8_t *bytes, uint32_t size, int is_signed)
{
    uint64_t v = 0;
    bytes_copy(&v, bytes, size > 8 ? 8 : size);
    if (is_signed && size < 8) {
        uint64_t sign = 1ull << (size * 8 - 1);
        v = (v ^ sign) - sign;
    }
    return v;
}
/* }}} */

/* {{{ compare_by_order */
/* Answers 0 below, 1 equal, 2 above. */
static int compare_by_order(int order, const uint8_t *value, const uint8_t *threshold, uint32_t size)
{
    int is_signed = order == ORDER_SIGNED;
    uint64_t a = read_integer(value, size, is_signed);
    uint64_t b = read_integer(threshold, size, is_signed);
    if (is_signed) {
        int64_t x = (int64_t)a, y = (int64_t)b;
        return x < y ? 0 : (x == y ? 1 : 2);
    }
    return a < b ? 0 : (a == b ? 1 : 2);
}
/* }}} */

/* {{{ the exit table */
/* One row per kind, all reached the same way. A kind is consulted here
 * and nowhere else; a new kind is a new row. Every row answers an exit
 * number, or -1 to discard (only when the station has no exits). */

/* {{{ exit_plain */
static int32_t exit_plain(struct core_ctx *c, struct station *s, struct task *t)
{
    (void)c; (void)t;
    return s->n_exits > 0 ? 0 : -1;
}
/* }}} */

/* {{{ exit_comparator */
static int32_t exit_comparator(struct core_ctx *c, struct station *s, struct task *t)
{
    (void)c;
    uint8_t threshold[MAX_VALUE_BYTES > 64 ? 64 : MAX_VALUE_BYTES];
    struct port *p = &s->ports[s->n_box_ports];
    if ((size_t)p->elem_size > sizeof threshold) {
        return -1;
    }
    port_read_static(p, threshold);
    /* Two kinds of ordering: the box's value type brings its own, or the
     * return value is an integer and is compared as one. */
    if (s->box->return_order) {
        int r = s->box->return_order(t->out, threshold);
        return r < 0 ? 0 : (r == 0 ? 1 : 2);
    }
    return compare_by_order(s->order, t->out, threshold, t->out_bytes);
}
/* }}} */

/* {{{ exit_iterator */
/* Decided at claim time (choose_exit_at_claim) and carried in the task;
 * this row is only reached if a task somehow lacks one. */
static int32_t exit_iterator(struct core_ctx *c, struct station *s, struct task *t)
{
    (void)c;
    return t->exit >= 0 ? t->exit : (int32_t)(atomic_fetch_add_rel(&s->cursor, 1) % s->n_exits);
}
/* }}} */

/* {{{ exit_random */
static int32_t exit_random(struct core_ctx *c, struct station *s, struct task *t)
{
    (void)t;
    return (int32_t)(core_random(c) % s->n_exits);
}
/* }}} */

/* {{{ exit_weighted */
/* The weights are a static port of one 32-bit weight per exit, so they
 * are a dial somebody can turn while the program runs, for free. */
static int32_t exit_weighted(struct core_ctx *c, struct station *s, struct task *t)
{
    (void)t;
    uint32_t weights[64];
    struct port *p = &s->ports[s->n_box_ports];
    int n = s->n_exits < 64 ? s->n_exits : 64;
    if (p->elem_size != (int32_t)(s->n_exits * sizeof(uint32_t))) {
        return -1;                      /* impossible: placement sizes this port from the exit count */
    }
    port_read_static(p, weights);
    uint64_t total = 0;
    for (int e = 0; e < n; e++) {
        total += weights[e];
    }
    if (total == 0) {
        return -1;                      /* every weight zero: no exit may be taken, so the value is discarded */
    }
    uint64_t pick = core_random(c) % total;
    for (int e = 0; e < n; e++) {
        if (pick < weights[e]) {
            return e;
        }
        pick -= weights[e];
    }
    return n - 1;
}
/* }}} */

/* {{{ exit_spread */
/* Whichever exit's first destination has fewest values waiting. The look
 * is best-effort — a value can land between the look and the send — and
 * every such race is harmless: the worst outcome is a slightly uneven
 * split, never a lost or doubled value. Ties go to the cursor. */
static int32_t exit_spread(struct core_ctx *c, struct station *s, struct task *t)
{
    (void)c; (void)t;
    uint32_t turn = atomic_fetch_add_rel(&s->cursor, 1);
    int32_t best = -1;
    int best_waiting = 0x7fffffff;
    for (int k = 0; k < s->n_exits; k++) {
        int e = (int)((turn + (uint32_t)k) % s->n_exits);
        struct dest_list *list = atomic_load_acquire(&s->exits[e].list);
        if (!list || list->count == 0) {
            continue;
        }
        struct station *d = station_live(list->to[0].station);
        if (!d) {
            continue;
        }
        /* How far behind the destination is: values waiting in its port,
         * plus runs of it already queued or running. The port alone is not
         * enough — measured in issue 308's test: the readiness check turns
         * a waiting value into a queued run almost at once, so a slow
         * destination's backlog sits in the task ring, where a look at the
         * port never sees it, and spread split evenly. */
        int waiting = port_waiting(&d->ports[list->to[0].port]) + atomic_load_relaxed(&d->in_flight);
        if (waiting < best_waiting) {
            best_waiting = waiting;
            best = e;
        }
    }
    return best >= 0 ? best : (int32_t)(turn % s->n_exits);
}
/* }}} */

static int32_t (*const exit_by_kind[KIND_COUNT])(struct core_ctx *, struct station *, struct task *) = {
    [KIND_PLAIN]      = exit_plain,
    [KIND_COMPARATOR] = exit_comparator,
    [KIND_ITERATOR]   = exit_iterator,
    [KIND_RANDOM]     = exit_random,
    [KIND_WEIGHTED]   = exit_weighted,
    [KIND_SPREAD]     = exit_spread,
};
/* }}} */

/* {{{ engine_kind_extra_ports */
int engine_kind_extra_ports(int kind)
{
    return kind == KIND_COMPARATOR || kind == KIND_WEIGHTED;
}
/* }}} */

/* {{{ choose_exit_at_claim */
/* The iterator's exit is decided while its values are claimed, so two
 * tasks assembled a moment apart carry different exits however they
 * finish. Every other kind decides on the way out (-1 here). */
int32_t choose_exit_at_claim(struct station *s)
{
    if (s->kind == KIND_ITERATOR && s->n_exits > 0) {
        return (int32_t)(atomic_fetch_add_rel(&s->cursor, 1) % s->n_exits);
    }
    return -1;
}
/* }}} */

/* {{{ choose_exit */
int32_t choose_exit(struct core_ctx *c, struct station *s, struct task *t)
{
    if (s->n_exits == 0) {
        return -1;
    }
    if (t->exit >= 0) {
        return t->exit;
    }
    return exit_by_kind[s->kind](c, s, t);
}
/* }}} */

/* {{{ the write table */
/* How a value lands in a port, one row per tag. A ring port queues it in
 * a cell and then asks whether the station is now ready. A static port has
 * its dial replaced — under the station's lock, one of the four rare
 * things that lock is for — and the check runs, because a static write is
 * an event. A port with no source still keeps the value in a cell, where
 * it waits in case the port is given a source again (issue 208: values
 * survive a change of source); no check runs, since the station cannot be
 * ready. */

/* {{{ write_ring */
static int write_ring(struct core_ctx *c, struct station *s, int32_t index, struct port *p, const void *value)
{
    int r = port_write_cell(c, s, p, value);
    if (r == ENGINE_OK) {
        station_check(c, index);
    }
    return r;
}
/* }}} */

/* {{{ write_static */
static int write_static(struct core_ctx *c, struct station *s, int32_t index, struct port *p, const void *value)
{
    spin_lock(&s->lock);
    port_write_static(s, p, value);
    spin_unlock(&s->lock);
    station_check(c, index);
    return ENGINE_OK;
}
/* }}} */

/* {{{ write_none */
static int write_none(struct core_ctx *c, struct station *s, int32_t index, struct port *p, const void *value)
{
    (void)index;
    return port_write_cell(c, s, p, value);
}
/* }}} */

static int (*const write_by_tag[PORT_TAG_COUNT])(struct core_ctx *, struct station *, int32_t,
                                                  struct port *, const void *) = {
    [PORT_RING]   = write_ring,
    [PORT_STATIC] = write_static,
    [PORT_NONE]   = write_none,
};
/* }}} */

/* {{{ deliver_value */
int deliver_value(struct core_ctx *c, int32_t index, int32_t port, const void *value, size_t size)
{
    struct station *s = station_at(index);
    if (!s || !atomic_load_acquire(&s->box)) {
        c->stats.discarded++;
        return ENGINE_NO_STATION;
    }
    /* A value already in flight toward a station that is being removed
     * or is parked is discarded — and counted on that station, so the
     * loss is a number somebody can read rather than a silence. */
    if (atomic_load_acquire(&s->state) != STATION_LIVE) {
        atomic_add(&s->discarded, 1);
        c->stats.discarded++;
        return ENGINE_STOPPED;
    }
    if (port < 0 || port >= s->n_ports) {
        error_record(s, index, ERROR_BAD_WIRING, (uint64_t)port);
        c->stats.discarded++;
        return ENGINE_NO_PORT;
    }
    struct port *p = &s->ports[port];
    if ((size_t)p->elem_size != size) {
        error_record(s, index, ERROR_WRONG_SIZE, size);
        c->stats.discarded++;
        return ENGINE_WRONG_SIZE;
    }
    uint8_t tag = atomic_load_acquire(&p->tag);
    int r = write_by_tag[tag](c, s, index, p, value);
    if (r == ENGINE_OK) {
        c->stats.deliveries++;
        transcript_record(TRANSCRIPT_DELIVERED, index, c->inside, port, 0, s->name);
    } else {
        error_record(s, index, ERROR_NO_MEMORY, (uint64_t)port);
        c->stats.discarded++;
    }
    return r;
}
/* }}} */

/* {{{ deliver_task */
void deliver_task(struct core_ctx *c, struct task *t)
{
    if (t->out_bytes == 0) {
        return;                                   /* a sink: nothing to carry */
    }
    struct station *s = station_at(t->station);
    int32_t exit = choose_exit(c, s, t);
    if (exit < 0 || exit >= s->n_exits) {
        c->stats.discarded++;
        return;
    }
    /* One read of the list's address. Whatever list that is, nobody will
     * ever change it, so it is walked with no lock and no copy. */
    struct dest_list *list = atomic_load_acquire(&s->exits[exit].list);
    if (!list || list->count == 0) {
        /* Wired to nothing. Two cases: an ordinary exit discards (an
         * unwired comparator branch is the everyday example); an exit
         * marked as one of the program's results holds the value for
         * whoever asks for it (issue 309), because discarding a program's
         * results would mean the program did nothing. */
        struct port *held = atomic_load_acquire(&s->exits[exit].held);
        if (held && port_write_cell(c, s, held, t->out) == ENGINE_OK) {
            c->stats.deliveries++;
            return;
        }
        c->stats.discarded++;
        return;
    }
    for (int32_t d = 0; d < list->count; d++) {
        deliver_value(c, list->to[d].station, list->to[d].port, t->out, t->out_bytes);
    }
}
/* }}} */

/* {{{ engine_deliver */
int engine_deliver(int32_t station, int port, const void *value, size_t size)
{
    struct core_ctx *c = engine_enter();
    int r = deliver_value(c, station, port, value, size);
    engine_leave(c);
    return r;
}
/* }}} */
