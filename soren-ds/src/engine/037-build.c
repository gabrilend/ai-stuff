/*
 * 037-build.c — place, configure, wire: the three operations every
 * program is built with (issue 212).
 *
 * General description: there is one way a station comes into existence,
 * one way a port gets a source, and one way an exit gets destinations.
 * Phase 3's loader calls these while reading a file; the editor calls them
 * when somebody drags a wire; a debugger over the serial line calls them.
 * Because there is only one path, there is no second path that could
 * reach a state the first would have refused. Each refusal names what was
 * wrong and where.
 *
 * Building is the same act as running: the last thing construction does
 * is write the statics, and writing a static runs the readiness check,
 * which builds the first tasks, which the cores were already waiting for.
 */
#include "031-engine-internal.h"

/* {{{ engine_error_text */
const char *engine_error_text(int error)
{
    static const char *const text[] = {
        "ok",
        "no such box, or a box with no function",
        "no such station",
        "no such port on that station",
        "no such exit on that station",
        "the value's size differs from the port's",
        "out of memory",
        "that place was removed but is not reclaimed yet",
        "the box's task would be larger than the engine allows",
        "the station is parked or being removed",
        "a fixed table has no room left",
        "a comparator over a type with no ordering",
        "an unknown kind, or an exit count the kind cannot have",
        "an unknown port tag, or a routing port given a non-static source",
    };
    int i = -error;
    if (i < 0 || i >= (int)(sizeof text / sizeof text[0])) {
        return "an error the engine does not know the name of";
    }
    return text[i];
}
/* }}} */

/* {{{ ordering_of */
/* How a type orders, from its name as the box states it. Only integers
 * order today (the kernel has no floating point, issue 103f). A type with
 * no ordering makes a comparator over it a refusal at placement, not a
 * surprise at run time. Issue 303 replaces this with the catalogue's own
 * width table. */
static int ordering_of(const char *type)
{
    static const struct { const char *name; int order; } known[] = {
        { "int", ORDER_SIGNED }, { "long", ORDER_SIGNED }, { "short", ORDER_SIGNED },
        { "char", ORDER_SIGNED }, { "signed char", ORDER_SIGNED }, { "long long", ORDER_SIGNED },
        { "int8_t", ORDER_SIGNED }, { "int16_t", ORDER_SIGNED }, { "int32_t", ORDER_SIGNED },
        { "int64_t", ORDER_SIGNED }, { "intptr_t", ORDER_SIGNED },
        { "unsigned", ORDER_UNSIGNED }, { "unsigned int", ORDER_UNSIGNED },
        { "unsigned long", ORDER_UNSIGNED }, { "unsigned short", ORDER_UNSIGNED },
        { "unsigned char", ORDER_UNSIGNED }, { "unsigned long long", ORDER_UNSIGNED },
        { "uint8_t", ORDER_UNSIGNED }, { "uint16_t", ORDER_UNSIGNED }, { "uint32_t", ORDER_UNSIGNED },
        { "uint64_t", ORDER_UNSIGNED }, { "uintptr_t", ORDER_UNSIGNED }, { "size_t", ORDER_UNSIGNED },
        { "bool", ORDER_UNSIGNED }, { "_Bool", ORDER_UNSIGNED },
    };
    if (!type) {
        return ORDER_NONE;
    }
    for (size_t i = 0; i < sizeof known / sizeof known[0]; i++) {
        if (text_equal(type, known[i].name)) {
            return known[i].order;
        }
    }
    return ORDER_NONE;
}
/* }}} */

/* {{{ check_shape */
/* Everything about a placement that can be refused before any memory is
 * touched. */
static int check_shape(const struct box *box, int kind, int n_exits)
{
    if (!box || !box->call) {
        return ENGINE_NO_BOX;
    }
    if (kind < 0 || kind >= KIND_COUNT || n_exits < 0 || n_exits > 64) {
        return ENGINE_BAD_KIND;
    }
    /* The kinds with a fixed number of exits must have exactly that
     * many; the others may have any number from one up. A sink has no
     * value to send, so it may have none. */
    if (box->return_size == 0 && n_exits != 0) {
        return ENGINE_BAD_KIND;
    }
    if (box->return_size != 0) {
        if (kind == KIND_PLAIN && n_exits != 1) {
            return ENGINE_BAD_KIND;
        }
        if (kind == KIND_COMPARATOR && n_exits != 3) {
            return ENGINE_BAD_KIND;
        }
        if (n_exits < 1) {
            return ENGINE_BAD_KIND;
        }
    }
    if (kind == KIND_COMPARATOR && ordering_of(box->return_type) == ORDER_NONE) {
        return ENGINE_UNORDERED;
    }
    if (box->n_params + engine_kind_extra_ports(kind) > 64) {
        return ENGINE_TOO_BIG;
    }
    for (int p = 0; p < box->n_params; p++) {
        if (box->params[p].size > MAX_VALUE_BYTES || (box->params[p].offset & 7)) {
            return ENGINE_TOO_BIG;
        }
    }
    if (box->return_size > MAX_VALUE_BYTES || task_bytes(box) > MAX_TASK_BYTES) {
        return ENGINE_TOO_BIG;
    }
    return ENGINE_OK;
}
/* }}} */

/* {{{ fill_station */
/* Build a station's parts. The record is not yet visible to anybody:
 * build first, publish last. */
static int fill_station(struct core_ctx *c, struct station *s, const struct box *box,
                        const char *name, int kind, int n_exits)
{
    int extra = engine_kind_extra_ports(kind);
    int n_ports = box->n_params + extra;
    struct port *ports = block_alloc_zero(c->number, sizeof(struct port) * (size_t)(n_ports ? n_ports : 1));
    struct exit *exits = block_alloc_zero(c->number, sizeof(struct exit) * (size_t)(n_exits ? n_exits : 1));
    size_t name_len = name ? text_length(name) : 0;
    char *copy = block_alloc(c->number, name_len + 1);
    if (!ports || !exits || !copy) {
        return ENGINE_NO_MEMORY;
    }
    for (int p = 0; p < box->n_params; p++) {
        if (port_init(c, &ports[p], (int32_t)box->params[p].size) != ENGINE_OK) {
            return ENGINE_NO_MEMORY;
        }
    }
    if (extra) {
        /* The routing port: the threshold is the width of the return
         * value; the weights are one 32-bit number per exit. */
        int32_t size = kind == KIND_COMPARATOR ? (int32_t)box->return_size
                                               : (int32_t)(n_exits * (int)sizeof(uint32_t));
        if (port_init(c, &ports[box->n_params], size) != ENGINE_OK) {
            return ENGINE_NO_MEMORY;
        }
        ports[box->n_params].extra = 1;
    }
    if (name_len) {
        bytes_copy(copy, name, name_len);
    }
    copy[name_len] = '\0';

    spin_lock_t fresh_lock = SPIN_LOCK_INIT;
    s->lock        = fresh_lock;
    s->kind        = (uint8_t)kind;
    s->n_ports     = (uint16_t)n_ports;
    s->n_box_ports = box->n_params;
    s->n_exits     = (uint16_t)n_exits;
    s->ports       = ports;
    s->exits       = exits;
    s->cursor      = 0;
    s->pending     = 0;
    s->in_flight   = 0;
    s->open_ports  = n_ports;          /* every port starts with no source */
    s->name        = copy;
    bytes_zero(&s->error, sizeof s->error);
    s->runs        = 0;
    s->discarded   = 0;
    s->program     = 0;
    s->order       = kind == KIND_COMPARATOR ? ordering_of(box->return_type) : ORDER_NONE;
    return ENGINE_OK;
}
/* }}} */

/* {{{ ensure_shelf */
/* Called holding the table lock. */
static int ensure_shelf(struct core_ctx *c, int32_t index)
{
    int32_t shelf = index >> SHELF_SHIFT;
    if (shelf >= MAX_SHELVES) {
        return ENGINE_FULL;
    }
    if (!engine.shelves[shelf]) {
        struct station *fresh = block_alloc_zero(c->number, sizeof(struct station) * STATIONS_PER_SHELF);
        if (!fresh) {
            return ENGINE_NO_MEMORY;
        }
        atomic_store_release(&engine.shelves[shelf], fresh);
    }
    return ENGINE_OK;
}
/* }}} */

/* {{{ publish_station */
static void publish_station(struct station *s, const struct box *box)
{
    atomic_store_release(&s->box, box);
    atomic_store_release(&s->state, STATION_LIVE);
}
/* }}} */

/* {{{ place_into */
/* Take a place (a particular one, or any) and fill it. */
static int32_t place_into(struct core_ctx *c, int32_t wanted, const struct box *box,
                          const char *name, int kind, int n_exits)
{
    int r = check_shape(box, kind, n_exits);
    if (r != ENGINE_OK) {
        return r;
    }
    spin_lock(&engine.table_lock);
    int32_t index = -1;
    int32_t count = engine.count;

    /* Three ways to find a place: a particular one was asked for (it
     * must be free and reclaimed); any will do and a reclaimed one is
     * waiting (reuse it); or none is waiting (the table grows by one). */
    if (wanted >= 0) {
        if (wanted < count) {
            struct station *s = station_at(wanted);
            if (s->state != STATION_FREE) {
                spin_unlock(&engine.table_lock);
                say("engine: refused to place \"%s\" at %d: that place is %s", name ? name : "",
                    (int)wanted, s->state == STATION_REMOVING ? "removed but not yet reclaimed" : "in use");
                return ENGINE_PLACE_BUSY;
            }
            for (int32_t k = 0; k < engine.n_free_places; k++) {
                if (engine.free_places[k] == wanted) {
                    engine.free_places[k] = engine.free_places[--engine.n_free_places];
                    break;
                }
            }
            index = wanted;
        } else {
            r = ensure_shelf(c, wanted);
            if (r != ENGINE_OK) {
                spin_unlock(&engine.table_lock);
                return r;
            }
            for (int32_t k = count; k < wanted; k++) {
                if (ensure_shelf(c, k) == ENGINE_OK && engine.n_free_places < engine.free_capacity) {
                    engine.free_places[engine.n_free_places++] = k;
                }
            }
            index = wanted;
        }
    } else if (engine.n_free_places > 0) {
        index = engine.free_places[--engine.n_free_places];
    } else {
        index = count;
        r = ensure_shelf(c, index);
        if (r != ENGINE_OK) {
            spin_unlock(&engine.table_lock);
            return r;
        }
    }

    struct station *s = &engine.shelves[index >> SHELF_SHIFT][index & (STATIONS_PER_SHELF - 1)];
    r = fill_station(c, s, box, name, kind, n_exits);
    if (r != ENGINE_OK) {
        if (index < count && engine.n_free_places < engine.free_capacity) {
            engine.free_places[engine.n_free_places++] = index;
        }
        spin_unlock(&engine.table_lock);
        return r;
    }
    publish_station(s, box);
    /* Build the station completely, then publish the count that reveals
     * it. A reader holding a stale, smaller count simply does not see the
     * newest station yet — harmless, because nothing can be wired to a
     * station before it exists. */
    if (index >= count) {
        atomic_store_release(&engine.count, index + 1);
    }
    spin_unlock(&engine.table_lock);
    return index;
}
/* }}} */

/* {{{ engine_place */
int32_t engine_place(const struct box *box, const char *name, int kind, int n_exits)
{
    struct core_ctx *c = engine_enter();
    int32_t r = place_into(c, -1, box, name, kind, n_exits);
    engine_leave(c);
    return r;
}
/* }}} */

/* {{{ engine_place_at */
int32_t engine_place_at(int32_t index, const struct box *box, const char *name, int kind, int n_exits)
{
    if (index < 0) {
        return ENGINE_NO_STATION;
    }
    struct core_ctx *c = engine_enter();
    int32_t r = place_into(c, index, box, name, kind, n_exits);
    engine_leave(c);
    return r;
}
/* }}} */

/* {{{ engine_configure */
int engine_configure(int32_t index, int port, int tag, const void *value, size_t size)
{
    struct core_ctx *c = engine_enter();
    struct station *s = station_live(index);
    int r = ENGINE_OK;
    if (!s) {
        r = ENGINE_NO_STATION;
    } else if (port < 0 || port >= s->n_ports) {
        r = ENGINE_NO_PORT;
    } else if (tag < 0 || tag >= PORT_TAG_COUNT || (s->ports[port].extra && tag != PORT_STATIC)) {
        r = ENGINE_BAD_TAG;
    } else if (tag == PORT_STATIC && size != (size_t)s->ports[port].elem_size) {
        error_record(s, index, ERROR_WRONG_SIZE, size);
        r = ENGINE_WRONG_SIZE;
    }
    if (r != ENGINE_OK) {
        engine_leave(c);
        return r;
    }

    struct port *p = &s->ports[port];
    spin_lock(&s->lock);
    uint8_t before = p->tag;
    if (tag == PORT_STATIC) {
        port_write_static(s, p, value);
    }
    atomic_store_release(&p->tag, (uint8_t)tag);
    station_recount_open(s);
    /* Giving a port back its source after the station took itself out of
     * service is the act that says "fixed"; it resets the error slot, so
     * a stale count on a box that now works does not linger (issue 214's
     * open question, answered here — see the issue). */
    if (before == PORT_NONE && tag != PORT_NONE && s->error.kind != ERROR_NONE) {
        bytes_zero(&s->error, sizeof s->error);
    }
    spin_unlock(&s->lock);

    /* A static write is an event; a port newly given a ring source may
     * already hold values that were waiting. Either way, look. */
    if (tag != PORT_NONE) {
        station_check(c, index);
    }
    engine_leave(c);
    return ENGINE_OK;
}
/* }}} */

/* {{{ engine_wire */
int engine_wire(int32_t index, int exit, const struct destination *to, int count)
{
    struct core_ctx *c = engine_enter();
    struct station *s = station_live(index);
    int r = ENGINE_OK;
    if (!s) {
        r = ENGINE_NO_STATION;
    } else if (exit < 0 || exit >= s->n_exits) {
        r = ENGINE_NO_EXIT;
    } else if (count < 0) {
        r = ENGINE_NO_STATION;
    }
    /* Every destination must exist, and every port must be exactly as
     * wide as the value this station returns. A mismatch here would
     * otherwise be a torn or overrun copy on every single delivery. */
    for (int d = 0; r == ENGINE_OK && d < count; d++) {
        struct station *dst = station_live(to[d].station);
        if (!dst) {
            error_record(s, index, ERROR_BAD_WIRING, (uint64_t)(uint32_t)to[d].station);
            r = ENGINE_NO_STATION;
        } else if (to[d].port < 0 || to[d].port >= dst->n_ports) {
            error_record(s, index, ERROR_BAD_WIRING, (uint64_t)(uint32_t)to[d].port);
            r = ENGINE_NO_PORT;
        } else if ((uint32_t)dst->ports[to[d].port].elem_size != s->box->return_size) {
            error_record(s, index, ERROR_WRONG_SIZE, s->box->return_size);
            r = ENGINE_WRONG_SIZE;
        }
    }
    if (r != ENGINE_OK) {
        engine_leave(c);
        return r;
    }

    struct dest_list *fresh = (struct dest_list *)0;
    if (count > 0) {
        fresh = block_alloc(c->number, sizeof *fresh + (size_t)count * sizeof(struct destination));
        if (!fresh) {
            engine_leave(c);
            return ENGINE_NO_MEMORY;
        }
        fresh->count = count;
        for (int d = 0; d < count; d++) {
            fresh->to[d] = to[d];
        }
    }
    spin_lock(&s->lock);
    struct dest_list *old = s->exits[exit].list;
    /* One atomic store swaps the whole list. A walker already inside the
     * old one finishes reading a coherent set; the old one goes to the
     * scrapyard until no core can still be inside it. */
    atomic_store_release(&s->exits[exit].list, fresh);
    spin_unlock(&s->lock);
    if (old) {
        scrap_retire(c, scrap_release_block, old, 0);
    }
    scrap_sweep(c);
    engine_leave(c);
    return ENGINE_OK;
}
/* }}} */
