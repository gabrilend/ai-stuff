/*
 * 090-replace.c — replacing a box in a running program (issue 411).
 *
 * General description: see 090-replace.h. The one piece of work here
 * that the engine does not already name is finding the arrows that point
 * into a station: a wire exists only as an entry in some station's exit
 * list, so one walk over every station's exits finds them all, the same
 * walk removal does (033's cut_wires_to). Everything else is a sequence of
 * public engine calls, made holding the outside's turn so nothing else
 * builds while the arrows are between two stations.
 */
#include "031-engine-internal.h"
#include "070-catalogue.h"
#include "086-shelves.h"
#include "090-replace.h"

enum { PENDING = 1, FINISHED = 2 };

struct replacement {
    int     program;
    int     state;
    char    name[MAP_NAME];
    int32_t live;                   /* the station the arrows are on */
    int32_t spare;                  /* the one they are not */
    char    live_address[MAP_ADDRESS];
    char    spare_address[MAP_ADDRESS];
};

static struct shelves replacements = SHELVES_INIT(struct replacement, 64);

/* {{{ same_shape */
/* Does the new box take and give exactly the widths the old one does?
 * Each difference is a line naming both types and both widths. */
static int same_shape(const char *name, const struct box *old, const struct box *box, struct map_report *report)
{
    int problems = 0;
    size_t used = text_length(report->text);
    if (old->n_params != box->n_params) {
        used += (size_t)text_format(report->text + used, sizeof report->text - used,
                                    "%s: %s takes %d values, %s takes %d\n", name, old->name, old->n_params,
                                    box->name, box->n_params);
        return 1;
    }
    for (int p = 0; p < box->n_params && used < sizeof report->text; p++) {
        if (old->params[p].size != box->params[p].size) {
            used += (size_t)text_format(report->text + used, sizeof report->text - used,
                                        "%s.%d: %s takes %s (%u bytes), %s takes %s (%u bytes)\n", name, p, old->name,
                                        old->params[p].type, (unsigned)old->params[p].size, box->name,
                                        box->params[p].type, (unsigned)box->params[p].size);
            problems++;
        }
    }
    if (old->return_size != box->return_size && used < sizeof report->text) {
        text_format(report->text + used, sizeof report->text - used,
                    "%s: %s returns %s (%u bytes), %s returns %s (%u bytes)\n", name, old->name, old->return_type,
                    (unsigned)old->return_size, box->name, box->return_type, (unsigned)box->return_size);
        problems++;
    }
    return problems;
}
/* }}} */

/* {{{ give_ports */
/* The new station gets the old one's sources: the same tag on every port,
 * the same fixed value on every static one, the same doors. */
static int give_ports(struct core_ctx *c, int32_t from, int32_t to, const struct box *box, int kind)
{
    int n_ports = box->n_params + engine_kind_extra_ports(kind);
    uint8_t *value = (uint8_t *)0;
    int r = ENGINE_OK;
    for (int p = 0; p < n_ports && r >= 0; p++) {
        int tag = engine_port_tag(from, p);
        if (tag == PORT_STATIC) {
            if (!value && !(value = block_alloc(c->number, MAX_VALUE_BYTES))) {
                return ENGINE_NO_MEMORY;
            }
            int size = engine_static_value(from, p, value, MAX_VALUE_BYTES);
            r = size < 0 ? size : engine_configure(to, p, PORT_STATIC, value, (size_t)size);
        } else if (tag == PORT_RING) {
            r = engine_configure(to, p, PORT_RING, (const void *)0, 0);
        }
    }
    if (value) {
        block_free(c->number, value);
    }
    return r < 0 ? r : ENGINE_OK;
}
/* }}} */

/* {{{ move_arrows */
/* Everything wired to `from` goes to `to`: arrows out first (one exit's
 * whole list at a time, a station's arrow to itself becoming `to`'s to
 * itself), then the doors, then every arrow in, then `from`'s own arrows
 * cut so a value still waiting in it can never leave. */
static int move_arrows(struct core_ctx *c, int32_t from, int32_t to, int n_ports)
{
    int n_exits = engine_exit_count(from);
    for (int e = 0; e < n_exits; e++) {
        int n = engine_exit_destinations(from, e, (struct destination *)0, 0);
        if (n < 0) return n;
        struct destination *list = n ? block_alloc(c->number, sizeof *list * (size_t)n) : (struct destination *)0;
        if (n && !list) return ENGINE_NO_MEMORY;
        engine_exit_destinations(from, e, list, n);
        for (int d = 0; d < n; d++) {
            if (list[d].station == from) list[d].station = to;
        }
        int r = engine_wire(to, e, list, n);
        if (list) block_free(c->number, list);
        if (r < 0) return r;
        int door = engine_exit_door(from, e);
        if (door >= 0) {
            engine_mark_result(from, e, -1);
            engine_mark_result(to, e, door);
        }
    }
    for (int p = 0; p < n_ports; p++) {
        int door = engine_port_door(from, p);
        if (door >= 0) {
            engine_mark_argument(from, p, -1);
            engine_mark_argument(to, p, door);
        }
    }
    int32_t stations = engine_station_count();
    for (int32_t s = 0; s < stations; s++) {
        if (s == from || s == to || !engine_station_box(s)) continue;
        int exits = engine_exit_count(s);
        for (int e = 0; e < exits; e++) {
            int n = engine_exit_destinations(s, e, (struct destination *)0, 0);
            if (n <= 0) continue;
            struct destination *list = block_alloc(c->number, sizeof *list * (size_t)n);
            if (!list) return ENGINE_NO_MEMORY;
            n = engine_exit_destinations(s, e, list, n);
            int hits = 0;
            for (int d = 0; d < n; d++) {
                if (list[d].station == from) {
                    list[d].station = to;
                    hits++;
                }
            }
            int r = hits ? engine_wire(s, e, list, n) : ENGINE_OK;
            block_free(c->number, list);
            if (r < 0) return r;
        }
    }
    for (int e = 0; e < n_exits; e++) {
        int r = engine_wire(from, e, (const struct destination *)0, 0);
        if (r < 0) return r;
    }
    return ENGINE_OK;
}
/* }}} */

/* {{{ repoint_program */
/* The program's name, address and doors follow the arrows. */
static void repoint_program(int program, int32_t from, int32_t to, const char *address)
{
    struct program_record *r = program_record(program);
    if (!r) return;
    for (int i = 0; i < r->n_stations; i++) {
        if (r->stations[i] == from) {
            r->stations[i] = to;
            text_format(r->addresses[i], MAP_ADDRESS, "%s", address);
        }
    }
    for (int k = 0; k < PROGRAM_DOORS; k++) {
        if (r->args[k].station == from) r->args[k].station = to;
        if (r->results[k].station == from) r->results[k].station = to;
    }
    struct station *s = station_at(to);
    if (s) atomic_store_release(&s->program, (uint32_t)(program + 1));
}
/* }}} */

/* {{{ replace_station */
int replace_station(int program, const char *name, const char *address, struct map_report *report)
{
    report->text[0] = 0;
    report->problems = 0;
    struct core_ctx *c = engine_enter();
    int answer;
    int32_t old = program_station(program, name);
    const struct box *old_box = old >= 0 ? engine_station_box(old) : (const struct box *)0;
    const struct box *box = catalogue_box(address);
    if (!old_box) {
        text_format(report->text, sizeof report->text, "no station %s in program %d\n", name, program);
        answer = ENGINE_NO_STATION;
        goto done;
    }
    if (!box) {
        text_format(report->text, sizeof report->text, "no box at %s\n", address);
        answer = ENGINE_NO_BOX;
        goto done;
    }
    if (same_shape(name, old_box, box, report)) {
        answer = REPLACE_DIFFERENT_SHAPE;
        goto done;
    }
    if (shelves_count(&replacements) >= shelves_capacity(&replacements)) {
        text_format(report->text, sizeof report->text, "no room to record another replacement\n");
        answer = ENGINE_FULL;
        goto done;
    }
    int kind = engine_station_kind(old);
    int32_t fresh = engine_place(box, engine_station_name(old), kind, engine_exit_count(old));
    if (fresh < 0) {
        answer = fresh;
        goto done;
    }
    int r = give_ports(c, old, fresh, box, kind);
    if (r >= 0) r = move_arrows(c, old, fresh, box->n_params + engine_kind_extra_ports(kind));
    if (r < 0) {
        /* Nothing points at the new station unless move_arrows got part
         * way, which only running out of memory can do; say so plainly
         * rather than pretend the program is as it was. */
        text_format(report->text, sizeof report->text, "replacing %s failed part way: %s\n", name, engine_error_text(r));
        answer = r;
        goto done;
    }
    struct program_record *rec = program_record(program);
    const char *old_address = "";
    for (int i = 0; rec && i < rec->n_stations; i++) {
        if (rec->stations[i] == old) old_address = rec->addresses[i];
    }
    spin_lock(&replacements.lock);
    int32_t number = replacements.count;
    struct replacement *rp = shelves_place(&replacements, c->number, number);
    if (rp) {
        rp->program = program;
        rp->state   = PENDING;
        text_format(rp->name, sizeof rp->name, "%s", name);
        rp->live  = fresh;
        rp->spare = old;
        text_format(rp->live_address, sizeof rp->live_address, "%s", address);
        text_format(rp->spare_address, sizeof rp->spare_address, "%s", old_address);
        shelves_publish(&replacements, number + 1);
    }
    spin_unlock(&replacements.lock);
    repoint_program(program, old, fresh, address);
    /* The new station is looked at once, as bring-up looks at every
     * station: one whose every input is fixed runs now. */
    struct station *s = station_live(fresh);
    if (s && atomic_load_acquire(&s->open_ports) == 0) {
        station_check(c, fresh);
    }
    transcript_record(TRANSCRIPT_REPLACED, fresh, old, 0, program, name);
    say_line("replaced: %s in %s now places %s (station %d; station %d kept, unwired)", name, program_path(program),
             address, (int)fresh, (int)old);
    answer = rp ? number : ENGINE_NO_MEMORY;
done:
    engine_leave(c);
    return answer;
}
/* }}} */

/* {{{ pending */
static struct replacement *pending(int replacement)
{
    if (replacement < 0 || replacement >= shelves_count(&replacements)) {
        return (struct replacement *)0;
    }
    struct replacement *rp = shelves_at(&replacements, replacement);
    return rp->state == PENDING ? rp : (struct replacement *)0;
}
/* }}} */

/* {{{ replacement_swap */
int replacement_swap(int replacement)
{
    struct core_ctx *c = engine_enter();
    struct replacement *rp = pending(replacement);
    if (!rp) {
        engine_leave(c);
        return REPLACE_NO_REPLACEMENT;
    }
    const struct box *box = engine_station_box(rp->spare);
    int r = box ? move_arrows(c, rp->live, rp->spare, box->n_params + engine_kind_extra_ports(engine_station_kind(rp->spare)))
                : ENGINE_NO_STATION;
    if (r >= 0) {
        int32_t was = rp->live;
        char address[MAP_ADDRESS];
        text_format(address, sizeof address, "%s", rp->live_address);
        rp->live = rp->spare;
        rp->spare = was;
        text_format(rp->live_address, sizeof rp->live_address, "%s", rp->spare_address);
        text_format(rp->spare_address, sizeof rp->spare_address, "%s", address);
        repoint_program(rp->program, was, rp->live, rp->live_address);
        transcript_record(TRANSCRIPT_REPLACED, rp->live, was, 1, rp->program, rp->name);
        say_line("replaced: %s in %s back on %s (station %d; station %d kept, unwired)", rp->name,
                 program_path(rp->program), rp->live_address, (int)rp->live, (int)was);
    }
    engine_leave(c);
    return r;
}
/* }}} */

/* {{{ replacement_finish */
int replacement_finish(int replacement)
{
    struct core_ctx *c = engine_enter();
    struct replacement *rp = pending(replacement);
    int r = rp ? engine_remove(rp->spare) : REPLACE_NO_REPLACEMENT;
    if (rp && r >= 0) {
        rp->state = FINISHED;
    }
    engine_leave(c);
    return r;
}
/* }}} */

/* {{{ replacement_live */
int32_t replacement_live(int replacement)
{
    struct replacement *rp = pending(replacement);
    return rp ? rp->live : REPLACE_NO_REPLACEMENT;
}
/* }}} */

/* {{{ replacement_spare */
int32_t replacement_spare(int replacement)
{
    struct replacement *rp = pending(replacement);
    return rp ? rp->spare : REPLACE_NO_REPLACEMENT;
}
/* }}} */

/* {{{ replacements_end_program */
void replacements_end_program(int program)
{
    int32_t n = shelves_count(&replacements);
    for (int32_t i = 0; i < n; i++) {
        struct replacement *rp = shelves_at(&replacements, i);
        if (rp->state == PENDING && rp->program == program) {
            engine_remove(rp->spare);
            rp->state = FINISHED;
        }
    }
}
/* }}} */
