/*
 * 039-parking.c — asked to stop, and parking (issue 213).
 *
 * General description: a parked program is one whose stations can never
 * run (every input has no source) and whose waiting values have been
 * checksummed and their memory handed back to the allocator. Nothing polls
 * a parked program, nothing delivers to it, no core looks at it. If nobody
 * needed its pages while it was away, restarting it takes them back and
 * finds its values exactly as they were — a cache with none of the
 * machinery of a cache. If somebody was handed one of its pages, the
 * checksum fails, the program starts empty, and the developer is told
 * which program had to be rebuilt and why, every single time.
 *
 * Two checks on restart, cheap one first: are the pages still marked free?
 * If any is not, stop. Otherwise take them all back — marking them used
 * *before* reading them, so nobody can be handed one while the checksum
 * is being computed — and only then compare.
 */
#include "031-engine-internal.h"

#define MAX_PARKS 32

struct park {
    int      in_use;
    int      stage;                    /* enum park_state */
    int32_t  count;
    int32_t *stations;                 /* the caller's list, copied */
    uint64_t snapshot[OWNER_COUNT];    /* every core's epoch when the stations went quiet */
};

static spin_lock_t parks_lock = SPIN_LOCK_INIT;
static struct park parks[MAX_PARKS];

/* {{{ page_of */
/* A port page is a one-page block run; its real page starts 64 bytes
 * before the address the port keeps. */
static void *page_of(uint8_t *port_page)
{
    return (void *)((uintptr_t)port_page & ~(uintptr_t)(PAGE_BYTES - 1));
}
/* }}} */

/* {{{ port_page_checksum */
static uint64_t port_page_checksum(struct port *p)
{
    uint64_t sum = 0x5eed;
    for (int32_t i = 0; i < p->n_pages; i++) {
        sum = bytes_checksum(page_of(p->pages[i]), PAGE_BYTES, sum);
    }
    return sum;
}
/* }}} */

/* {{{ engine_park_begin */
int engine_park_begin(const int32_t *stations, int count)
{
    struct core_ctx *c = engine_enter();
    int handle = ENGINE_FULL;
    spin_lock(&parks_lock);
    for (int h = 0; h < MAX_PARKS; h++) {
        if (!parks[h].in_use) {
            parks[h].in_use = 1;
            handle = h;
            break;
        }
    }
    spin_unlock(&parks_lock);
    if (handle < 0) {
        engine_leave(c);
        return handle;
    }
    struct park *k = &parks[handle];
    k->stations = block_alloc(c->number, sizeof(int32_t) * (size_t)(count ? count : 1));
    if (!k->stations) {
        k->in_use = 0;
        engine_leave(c);
        return ENGINE_NO_MEMORY;
    }
    k->count = count;
    k->stage = PARK_DRAINING;
    for (int i = 0; i < count; i++) {
        k->stations[i] = stations[i];
        struct station *s = station_live(stations[i]);
        if (!s) {
            continue;
        }
        /* Unwire every input: nothing new can start. The source each port
         * had is remembered so a restart can give it back. */
        spin_lock(&s->lock);
        for (int p = 0; p < s->n_ports; p++) {
            s->ports[p].parked_tag = s->ports[p].tag;
            if (!s->ports[p].extra) {
                atomic_store_release(&s->ports[p].tag, (uint8_t)PORT_NONE);
            }
        }
        station_recount_open(s);
        spin_unlock(&s->lock);
    }
    engine_leave(c);
    return handle;
}
/* }}} */

/* {{{ release_station_pages */
static void release_station_pages(struct station *s)
{
    for (int p = 0; p < s->n_ports; p++) {
        struct port *port = &s->ports[p];
        port->parked_ready    = port_waiting(port);
        port->parked_checksum = port_page_checksum(port);
        for (int32_t i = 0; i < port->n_pages; i++) {
            page_release_direct(page_of(port->pages[i]));
        }
    }
}
/* }}} */

/* {{{ engine_park_step */
int engine_park_step(int handle)
{
    if (handle < 0 || handle >= MAX_PARKS || !parks[handle].in_use) {
        return ENGINE_NO_STATION;
    }
    struct park *k = &parks[handle];
    struct core_ctx *c = engine_enter();

    /* Stage one: wait for every run of these stations to finish. The
     * ordinary ending, triggered early: nothing new arrives, what is in
     * flight drains. */
    if (k->stage == PARK_DRAINING) {
        int busy = 0;
        for (int i = 0; i < k->count; i++) {
            struct station *s = station_live(k->stations[i]);
            busy += s && atomic_load_acquire(&s->in_flight) > 0;
        }
        if (!busy) {
            /* No new deliveries may land from here on; then note every
             * core's epoch, and wait for each to be seen between tasks so
             * a delivery that read "live" an instant ago has finished. */
            for (int i = 0; i < k->count; i++) {
                struct station *s = station_live(k->stations[i]);
                if (s) {
                    atomic_store_release(&s->state, STATION_PARKED);
                }
            }
            for (int o = 0; o < OWNER_COUNT; o++) {
                k->snapshot[o] = atomic_load_acquire(&engine.ctx[o].epoch);
            }
            k->stage = PARK_QUIETING;
        }
    }

    /* Stage two: once no core can be inside a delivery that began
     * before the stations went quiet, checksum and release. */
    if (k->stage == PARK_QUIETING) {
        int quiet = 1;
        for (int o = 0; o < OWNER_COUNT; o++) {
            if (o == c->number) {
                continue;                      /* ourselves: we are here, not in a delivery */
            }
            uint64_t now = atomic_load_acquire(&engine.ctx[o].epoch);
            if ((now & 1) && now == k->snapshot[o]) {
                quiet = 0;
            }
        }
        if (quiet) {
            for (int i = 0; i < k->count; i++) {
                struct station *s = station_at(k->stations[i]);
                if (s && atomic_load_acquire(&s->state) == STATION_PARKED) {
                    release_station_pages(s);
                }
            }
            k->stage = PARK_PARKED;
        }
    }
    int stage = k->stage;
    engine_leave(c);
    return stage;
}
/* }}} */

/* {{{ take_back */
/* Try to take a port's pages back intact. Answers 1 if every page was
 * still free, was reclaimed, and still checksums the same. On any
 * failure, whatever was reclaimed is released again and 0 is answered. */
static int take_back(struct port *p)
{
    for (int32_t i = 0; i < p->n_pages; i++) {
        if (!page_is_free(page_of(p->pages[i]))) {
            return 0;                          /* the cheap check: somebody was handed it */
        }
    }
    int32_t got = 0;
    for (; got < p->n_pages; got++) {
        if (!page_reclaim(page_of(p->pages[got]))) {
            break;
        }
    }
    if (got == p->n_pages && port_page_checksum(p) == p->parked_checksum) {
        return 1;
    }
    for (int32_t i = 0; i < got; i++) {
        page_release_direct(page_of(p->pages[i]));
    }
    return 0;
}
/* }}} */

/* {{{ rebuild_port */
/* Start a port empty on a fresh page. The old pages belong to whoever was
 * handed them; the pointers are simply forgotten. */
static int rebuild_port(struct core_ctx *c, struct port *p)
{
    uint8_t *fresh = block_alloc_zero(c->number, (size_t)p->page_bytes);
    if (!fresh) {
        return 0;
    }
    for (int32_t i = 0; i < p->page_slots; i++) {
        p->pages[i] = (uint8_t *)0;
    }
    p->pages[0]  = fresh;
    p->n_pages   = 1;
    p->bookmark  = 0;
    p->read_mark = 0;
    return 1;
}
/* }}} */

/* {{{ engine_restart */
int engine_restart(int handle, int *values_lost)
{
    if (handle < 0 || handle >= MAX_PARKS || !parks[handle].in_use) {
        return ENGINE_NO_STATION;
    }
    struct park *k = &parks[handle];
    if (k->stage != PARK_PARKED) {
        return ENGINE_STOPPED;
    }
    struct core_ctx *c = engine_enter();
    int rebuilt = 0;
    int lost = 0;
    for (int i = 0; i < k->count; i++) {
        struct station *s = station_at(k->stations[i]);
        if (!s || atomic_load_acquire(&s->state) != STATION_PARKED) {
            continue;
        }
        for (int p = 0; p < s->n_ports; p++) {
            struct port *port = &s->ports[p];
            if (!take_back(port)) {
                lost += port->parked_ready;
                rebuilt = 1;
                if (!rebuild_port(c, port)) {
                    engine_leave(c);
                    return ENGINE_NO_MEMORY;
                }
            }
        }
    }
    if (rebuilt) {
        say_line("engine: a parked program of %d stations had to be rebuilt empty — its memory was "
            "handed to something else while it was parked; %d waiting values were lost",
            (int)k->count, lost);
    }
    /* Give every port its source back, bring the stations live, and look:
     * values that survived may already make complete sets. */
    for (int i = 0; i < k->count; i++) {
        struct station *s = station_at(k->stations[i]);
        if (!s || atomic_load_acquire(&s->state) != STATION_PARKED) {
            continue;
        }
        spin_lock(&s->lock);
        for (int p = 0; p < s->n_ports; p++) {
            atomic_store_release(&s->ports[p].tag, s->ports[p].parked_tag);
        }
        station_recount_open(s);
        atomic_store_release(&s->state, STATION_LIVE);
        spin_unlock(&s->lock);
    }
    for (int i = 0; i < k->count; i++) {
        station_check(c, k->stations[i]);
    }
    block_free(c->number, k->stations);
    k->stations = (int32_t *)0;
    k->in_use = 0;
    engine_leave(c);
    if (values_lost) {
        *values_lost = lost;
    }
    return rebuilt ? RESTART_REBUILT : RESTART_RESUMED;
}
/* }}} */
