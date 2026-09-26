/*
 * 033-stations.c — the station table, the scrapyard, and removing a
 * station (issue 207).
 *
 * General description: every station of every program lives in one table
 * and is named by its position — a number, never an address. The table
 * grows by adding shelves of 64 records; a shelf, once made, never moves,
 * because every station carries its own lock inside itself and a lock is
 * identified by where it lives. The array of shelf addresses is fixed-size
 * for the same reason: nothing ever has to be reallocated, so nothing ever
 * moves.
 *
 * Old things that another core might still be reading — a replaced list
 * of wire destinations, a removed station's ports — go to a scrapyard
 * instead of being freed. Each is filed with a snapshot of every core's
 * epoch counter (odd while inside a task or an engine call, even
 * otherwise). A later sweep frees an item once every core's counter is
 * even or has changed since the snapshot: that core cannot still be inside
 * whatever it was inside when the item was retired.
 */
#include "031-engine-internal.h"

/* {{{ station_at */
struct station *station_at(int32_t index)
{
    if (index < 0 || index >= atomic_load_acquire(&engine.count)) {
        return (struct station *)0;
    }
    struct station *shelf = engine.shelves[index >> SHELF_SHIFT];
    return shelf ? &shelf[index & (STATIONS_PER_SHELF - 1)] : (struct station *)0;
}
/* }}} */

/* {{{ station_live */
struct station *station_live(int32_t index)
{
    struct station *s = station_at(index);
    if (!s || atomic_load_acquire(&s->state) != STATION_LIVE) {
        return (struct station *)0;
    }
    return s;
}
/* }}} */

/* {{{ the scrapyard */
struct scrap {
    struct scrap *next;
    void        (*release)(struct core_ctx *c, void *thing, int64_t arg);
    void         *thing;
    int64_t       arg;
    uint64_t      snapshot[OWNER_COUNT];
};

/* The scrapyard lock is a leaf: nothing else may be taken while it is
 * held. It is against double-freeing (a sweep and a teardown both
 * reaching one item), not against tearing. */
static spin_lock_t   scrap_lock = SPIN_LOCK_INIT;
static struct scrap *scrap_head;
static uint64_t      scrap_count;
static uint64_t      scrap_done;

/* {{{ scrap_retire */
void scrap_retire(struct core_ctx *c, void (*release)(struct core_ctx *c, void *thing, int64_t arg),
                  void *thing, int64_t arg)
{
    struct scrap *s = block_alloc(c->number, sizeof *s);
    if (!s) {
        /* No memory to remember it by: leaking it is the only safe
         * choice, because freeing it now might free something in use. */
        say("scrapyard: no memory to file a retired item; it is leaked rather than freed early");
        return;
    }
    s->release = release;
    s->thing   = thing;
    s->arg     = arg;
    for (int o = 0; o < OWNER_COUNT; o++) {
        s->snapshot[o] = atomic_load_acquire(&engine.ctx[o].epoch);
    }
    spin_lock(&scrap_lock);
    s->next = scrap_head;
    scrap_head = s;
    scrap_count++;
    spin_unlock(&scrap_lock);
}
/* }}} */

/* {{{ scrap_passes */
/* Can no core still be inside something it was inside when this item was
 * filed? A core passes if its counter is even now (between tasks, or
 * asleep — an idle core passes without ever having to move) or differs
 * from the snapshot (it has finished what it was doing then). */
static int scrap_passes(const struct scrap *s)
{
    for (int o = 0; o < OWNER_COUNT; o++) {
        uint64_t now = atomic_load_acquire(&engine.ctx[o].epoch);
        if ((now & 1) && now == s->snapshot[o]) {
            return 0;
        }
    }
    return 1;
}
/* }}} */

/* {{{ scrap_sweep */
void scrap_sweep(struct core_ctx *c)
{
    struct scrap *ready = (struct scrap *)0;
    spin_lock(&scrap_lock);
    struct scrap **link = &scrap_head;
    while (*link) {
        struct scrap *s = *link;
        if (scrap_passes(s)) {
            *link = s->next;
            s->next = ready;
            ready = s;
            scrap_count--;
        } else {
            link = &s->next;
        }
    }
    spin_unlock(&scrap_lock);
    /* The releases run after the lock is dropped, because some of them
     * take other locks and the scrapyard lock is a leaf. */
    while (ready) {
        struct scrap *next = ready->next;
        ready->release(c, ready->thing, ready->arg);
        block_free(c->number, ready);
        atomic_add(&scrap_done, 1);
        ready = next;
    }
}
/* }}} */

/* {{{ scrap_release_block */
void scrap_release_block(struct core_ctx *c, void *thing, int64_t arg)
{
    (void)arg;
    block_free(c->number, thing);
}
/* }}} */

/* {{{ scrap_waiting */
uint64_t scrap_waiting(void)
{
    return atomic_load_relaxed(&scrap_count);
}
/* }}} */

/* {{{ scrap_freed */
uint64_t scrap_freed(void)
{
    return atomic_load_relaxed(&scrap_done);
}
/* }}} */
/* }}} */

/* {{{ release_station */
/* The last step of removal, run by the sweep once no core can be inside a
 * task that started before the removal. A task built in the instant
 * between the readiness check and the removal flag may still be in the
 * ring, so a station with work in flight files itself again and waits for
 * the next sweep. Clearing the box is what finally frees the place. */
static void release_station(struct core_ctx *c, void *thing, int64_t index)
{
    struct station *s = thing;
    if (atomic_load_acquire(&s->in_flight) > 0) {
        scrap_retire(c, release_station, s, index);
        return;
    }
    for (int p = 0; p < s->n_ports; p++) {
        port_release(c, &s->ports[p]);
    }
    for (int e = 0; e < s->n_exits; e++) {
        if (s->exits[e].list) {
            block_free(c->number, s->exits[e].list);
        }
    }
    block_free(c->number, s->ports);
    block_free(c->number, s->exits);
    if (s->name) {
        block_free(c->number, s->name);
    }
    spin_lock(&engine.table_lock);
    s->ports = (struct port *)0;
    s->exits = (struct exit *)0;
    s->name  = (char *)0;
    s->n_ports = s->n_exits = s->n_box_ports = 0;
    atomic_store_release(&s->box, (const struct box *)0);
    atomic_store_release(&s->state, STATION_FREE);
    if (engine.n_free_places < engine.free_capacity) {
        engine.free_places[engine.n_free_places++] = (int32_t)index;
    }
    spin_unlock(&engine.table_lock);
}
/* }}} */

/* {{{ cut_wires_to */
/* Walk every station's every exit and rebuild any destination list that
 * names `target` without it. A wire exists only as an entry in such a
 * list, so this one walk finds every wire there is — which is why no
 * generation tag is needed on wires or checked on every delivery. */
static int cut_wires_to(struct core_ctx *c, int32_t target)
{
    int32_t n = atomic_load_acquire(&engine.count);
    int cut = 0;
    for (int32_t i = 0; i < n; i++) {
        struct station *s = station_at(i);
        if (!s || !atomic_load_acquire(&s->box)) {
            continue;
        }
        spin_lock(&s->lock);
        for (int e = 0; e < s->n_exits; e++) {
            struct dest_list *old = s->exits[e].list;
            if (!old) {
                continue;
            }
            int keep = 0;
            for (int d = 0; d < old->count; d++) {
                keep += old->to[d].station != target;
            }
            if (keep == old->count) {
                continue;
            }
            struct dest_list *fresh = (struct dest_list *)0;
            if (keep > 0) {
                fresh = block_alloc(c->number, sizeof *fresh + (size_t)keep * sizeof(struct destination));
                if (!fresh) {
                    spin_unlock(&s->lock);
                    return ENGINE_NO_MEMORY;
                }
                fresh->count = 0;
                for (int d = 0; d < old->count; d++) {
                    if (old->to[d].station != target) {
                        fresh->to[fresh->count++] = old->to[d];
                    }
                }
            }
            atomic_store_release(&s->exits[e].list, fresh);
            scrap_retire(c, scrap_release_block, old, 0);
            cut += old->count - keep;
        }
        spin_unlock(&s->lock);
    }
    return cut;
}
/* }}} */

/* {{{ engine_remove */
int engine_remove(int32_t index)
{
    struct core_ctx *c = engine_enter();
    struct station *s = station_at(index);
    if (!s || !atomic_load_acquire(&s->box)) {
        engine_leave(c);
        return ENGINE_NO_STATION;
    }
    /* 1. Nothing new starts from it. */
    /* Only a live station can be removed. One already being removed is
     * already on its way; a parked one has given its pages back and must
     * be restarted first, or removal would free them a second time. */
    spin_lock(&s->lock);
    uint8_t was = s->state;
    if (was == STATION_LIVE) {
        atomic_store_release(&s->state, STATION_REMOVING);
    }
    spin_unlock(&s->lock);
    if (was != STATION_LIVE) {
        engine_leave(c);
        return ENGINE_STOPPED;
    }
    /* 2. Cut every wire that names it. */
    int cut = cut_wires_to(c, index);
    if (cut < 0) {
        engine_leave(c);
        return cut;
    }
    /* 3 and 4. Its parts go to the scrapyard; the sweep frees them, and
     * the place, once nobody can be inside a task that needs them. */
    scrap_retire(c, release_station, s, index);
    scrap_sweep(c);
    engine_leave(c);
    return ENGINE_OK;
}
/* }}} */

/* {{{ engine_sweep */
/* Offer the scrapyard a chance to free what it can. The engine sweeps on
 * every rewire and removal by itself; this is for callers that want the
 * place back sooner (a test, an app closing). */
void engine_sweep(void)
{
    struct core_ctx *c = engine_enter();
    scrap_sweep(c);
    engine_leave(c);
}
/* }}} */

/* {{{ engine_station_count */
int32_t engine_station_count(void)
{
    return atomic_load_acquire(&engine.count);
}
/* }}} */

/* {{{ engine_station_box */
const struct box *engine_station_box(int32_t index)
{
    struct station *s = station_live(index);
    return s ? s->box : (const struct box *)0;
}
/* }}} */

/* {{{ engine_station_name */
const char *engine_station_name(int32_t index)
{
    struct station *s = station_live(index);
    return s && s->name ? s->name : "";
}
/* }}} */

/* {{{ engine_station_kind */
int engine_station_kind(int32_t index)
{
    struct station *s = station_live(index);
    return s ? s->kind : ENGINE_NO_STATION;
}
/* }}} */

/* {{{ engine_port_tag */
int engine_port_tag(int32_t index, int port)
{
    struct station *s = station_live(index);
    if (!s) {
        return ENGINE_NO_STATION;
    }
    if (port < 0 || port >= s->n_ports) {
        return ENGINE_NO_PORT;
    }
    return atomic_load_acquire(&s->ports[port].tag);
}
/* }}} */

/* {{{ engine_exit_count */
int engine_exit_count(int32_t index)
{
    struct station *s = station_live(index);
    return s ? s->n_exits : ENGINE_NO_STATION;
}
/* }}} */

/* {{{ engine_exit_destinations */
int engine_exit_destinations(int32_t index, int exit, struct destination *out, int max)
{
    struct core_ctx *c = engine_enter();
    struct station *s = station_live(index);
    int answer;
    if (!s) {
        answer = ENGINE_NO_STATION;
    } else if (exit < 0 || exit >= s->n_exits) {
        answer = ENGINE_NO_EXIT;
    } else {
        struct dest_list *list = atomic_load_acquire(&s->exits[exit].list);
        answer = list ? list->count : 0;
        for (int d = 0; d < answer && d < max; d++) {
            out[d] = list->to[d];
        }
    }
    engine_leave(c);
    return answer;
}
/* }}} */

/* {{{ engine_station_runs */
uint64_t engine_station_runs(int32_t index)
{
    struct station *s = station_at(index);
    return s ? atomic_load_acquire(&s->runs) : 0;
}
/* }}} */
