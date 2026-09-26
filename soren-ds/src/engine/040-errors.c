/*
 * 040-errors.c — when a box removes itself (issue 214).
 *
 * General description: this device cannot exit — there is nothing to exit
 * to, and the person who made the mistake is usually holding it, halfway
 * through writing the box that just failed. So a box that cannot continue
 * takes itself out of service, says so once, and everything else keeps
 * running. Taking itself out of service is setting its inputs to "no
 * source": it can never become ready, so it never runs, and costs nothing
 * while it waits. Give it its source back and it runs again.
 *
 * The record of what went wrong is one slot per station, written in place
 * and counted. The first occurrence goes out on the developer's line; the
 * count is for the ones after it, so a repeating error cannot drown the
 * stream or grow a buffer until the buffer is the problem.
 */
#include "031-engine-internal.h"

/* {{{ engine_error_kind_text */
const char *engine_error_kind_text(int kind)
{
    static const char *const text[ERROR_KIND_COUNT] = {
        [ERROR_NONE]       = "none",
        [ERROR_REFUSED]    = "refused",
        [ERROR_BAD_WIRING] = "bad wiring",
        [ERROR_WRONG_SIZE] = "wrong size",
        [ERROR_NO_MEMORY]  = "no memory",
        [ERROR_TRAPPED]    = "trapped",
    };
    if (kind < 0 || kind >= ERROR_KIND_COUNT) {
        return "unknown";
    }
    return text[kind];
}
/* }}} */

/* {{{ error_record */
void error_record(struct station *s, int32_t index, int kind, uint64_t detail)
{
    int first = 0;
    spin_lock(&s->lock);
    /* Two paths: the slot already holds this kind (count it — nothing
     * else changes, nothing is printed), or it holds nothing or a
     * different kind (the slot now describes this one, and the developer
     * hears about it once). */
    if (s->error.kind == (uint32_t)kind) {
        s->error.count++;
    } else {
        s->error.kind     = (uint32_t)kind;
        s->error.count    = 1;
        s->error.detail   = detail;
        s->error.first_ns = platform_now_ns();
        first = 1;
    }
    spin_unlock(&s->lock);
    if (first) {
        say("station %d \"%s\" (%s): %s, detail %llu",
            (int)index, s->name ? s->name : "", s->box ? s->box->name : "",
            engine_error_kind_text(kind), (unsigned long long)detail);
    }
}
/* }}} */

/* {{{ error_take_out_of_service */
/* Set every one of the box's inputs to no source. One field write per
 * port, and the station can never become ready again until somebody gives
 * one back. Values already waiting stay in their cells. Nothing
 * downstream needs telling: a station starved of input is already the
 * ordinary state of a station nobody has wired yet. */
void error_take_out_of_service(struct core_ctx *c, struct station *s, int32_t index)
{
    (void)c; (void)index;
    spin_lock(&s->lock);
    for (int p = 0; p < s->n_box_ports; p++) {
        atomic_store_release(&s->ports[p].tag, (uint8_t)PORT_NONE);
    }
    station_recount_open(s);
    spin_unlock(&s->lock);
}
/* }}} */

/* {{{ engine_read_error */
int engine_read_error(int32_t index, struct engine_error_report *out, int clear)
{
    struct station *s = station_at(index);
    if (!s || !atomic_load_acquire(&s->box)) {
        return ENGINE_NO_STATION;
    }
    spin_lock(&s->lock);
    out->kind     = (int)s->error.kind;
    out->count    = s->error.count;
    out->detail   = s->error.detail;
    out->first_ns = s->error.first_ns;
    if (clear) {
        s->error.count = 0;
    }
    spin_unlock(&s->lock);
    return ENGINE_OK;
}
/* }}} */

/* {{{ engine_station_discarded */
uint64_t engine_station_discarded(int32_t index)
{
    struct station *s = station_at(index);
    return s ? atomic_load_acquire(&s->discarded) : 0;
}
/* }}} */
