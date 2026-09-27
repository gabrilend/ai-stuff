/*
 * 068-programs.c — the loader and the program record (issues 306, 307,
 * 309).
 *
 * General description: loading happens in two halves. Planning reads the
 * map (and every map placed inside it), looks every box up, and checks
 * everything, collecting problems in file order. Building happens only if
 * planning found none, and it happens in four sweeps over the whole tree
 * of programs at once: place every station, draw every wire, set every
 * port's source, then write every fixed value — so no value starts a
 * station whose wires are not all drawn yet. Every sweep is calls to the
 * engine's own operations; the loader has no construction path of its
 * own, so nothing a file can build is out of reach of a person building
 * by hand, and the other way round.
 *
 * Why there is no cycle detector: a box cannot remember, so the only way
 * to carry a value from one run to the next is an arrow pointing back
 * round. A loop is not a hazard; it is the counter (issue 307).
 */
#include "031-engine-internal.h"
#include "070-catalogue.h"
#include "067-values.h"
#include "068-programs.h"

#define MAX_DEPTH 8

static struct program_record programs[PROGRAM_MAX];
static spin_lock_t           programs_lock = SPIN_LOCK_INIT;
static map_reader_fn         reader;
static void                 *reader_ctx;

/* {{{ embedded_reader */
static const char *embedded_reader(const char *path, size_t *length, void *ctx)
{
    (void)ctx;
    const char *text = catalogue_embedded_map(path);
    if (text) *length = text_length(text);
    return text;
}
/* }}} */

/* {{{ program_set_reader */
void program_set_reader(map_reader_fn fn, void *ctx)
{
    reader = fn;
    reader_ctx = ctx;
}
/* }}} */

/* {{{ read_map_text */
static const char *read_map_text(const char *path, size_t *length)
{
    map_reader_fn fn = reader ? reader : embedded_reader;
    const char *text = fn(path, length, reader_ctx);
    /* A map compiled into the image is always available as a second
     * source, so a reader for the disk still finds the built-in maps. */
    if (!text && fn != embedded_reader) {
        text = embedded_reader(path, length, (void *)0);
    }
    return text;
}
/* }}} */

/* {{{ program_record */
struct program_record *program_record(int program)
{
    if (program < 0 || program >= PROGRAM_MAX || !programs[program].in_use) {
        return (struct program_record *)0;
    }
    return &programs[program];
}
/* }}} */

/* {{{ planning */
struct plan;

struct plan_station {
    struct map_station *m;
    const struct box   *box;         /* NULL for a program placed inside */
    struct plan        *child;       /* the placed program's plan, or NULL */
    int                 n_ports;     /* box parameters (+ a routing port), or the child's argument count */
    int                 n_exits;     /* the box's exits, or the child's result count */
    int32_t             placed;      /* engine index once built (boxes) */
    int                 program;     /* program number once built (children) */
};

struct plan {
    struct map_description d;
    struct plan_station   *st;
    int                    arg_station[PROGRAM_DOORS];   /* index into st, or -1 */
    int                    arg_port[PROGRAM_DOORS];
    int                    res_station[PROGRAM_DOORS];
    int                    res_exit[PROGRAM_DOORS];
    int                    n_args;
    int                    n_results;
    int                    program;                      /* once built */
};

struct planning {
    struct map_arena    *arena;
    struct map_problems *problems;
    const char          *ancestors[MAX_DEPTH + 1];
    int                  depth;
};

/* {{{ port_type */
/* The type and width a station's input port expects. Three sources: a
 * box's parameter, a routing port (a comparator's threshold is the box's
 * return type; a weighted station's weights are one 32-bit number per
 * exit), or a placed program's argument door (whatever its inner port
 * expects). Answers 0 if the port does not exist. */
static int port_type(const struct plan_station *ps, int port, const char **type, uint32_t *size)
{
    if (ps->child) {
        if (port < 0 || port >= PROGRAM_DOORS || ps->child->arg_station[port] < 0) return 0;
        const struct plan_station *inner = &ps->child->st[ps->child->arg_station[port]];
        return port_type(inner, ps->child->arg_port[port], type, size);
    }
    if (!ps->box || port < 0 || port >= ps->n_ports) return 0;
    if (port < ps->box->n_params) {
        *type = ps->box->params[port].type;
        *size = ps->box->params[port].size;
        return 1;
    }
    if (ps->m->kind == KIND_COMPARATOR) {
        *type = ps->box->return_type;
        *size = ps->box->return_size;
        return 1;
    }
    *type = "weights";
    *size = (uint32_t)(4 * ps->n_exits);
    return 1;
}
/* }}} */

/* {{{ exit_type */
static int exit_type(const struct plan_station *ps, int exit, const char **type, uint32_t *size)
{
    if (ps->child) {
        if (exit < 0 || exit >= PROGRAM_DOORS || ps->child->res_station[exit] < 0) return 0;
        const struct plan_station *inner = &ps->child->st[ps->child->res_station[exit]];
        return exit_type(inner, ps->child->res_exit[exit], type, size);
    }
    if (!ps->box || exit < 0 || exit >= ps->n_exits) return 0;
    *type = ps->box->return_type;
    *size = ps->box->return_size;
    return 1;
}
/* }}} */

/* {{{ plan_station_named */
static struct plan_station *plan_station_named(struct plan *p, const char *name)
{
    for (int i = 0; i < p->d.n_stations; i++) {
        if (text_equal(p->st[i].m->name, name)) return &p->st[i];
    }
    return (struct plan_station *)0;
}
/* }}} */

/* {{{ report_unknown_box */
/* The most common mistake a map will have, so the best message: the
 * address as written, where it was looked for, and what that file does
 * hold — or, if no such file exists, where box sources live. */
static void report_unknown_box(struct planning *g, struct plan *p, struct map_station *m)
{
    char file[MAP_ADDRESS];
    size_t n = text_length(m->address);
    size_t colon = n;
    for (size_t i = 0; i < n; i++) if (m->address[i] == ':') colon = i;
    bytes_copy(file, m->address, colon);
    file[colon] = 0;
    char holds[400] = "";
    size_t used = 0;
    int in_file = 0;
    for (int i = 0; i < catalogue_count(); i++) {
        const char *a = catalogue_address(i);
        if (text_length(a) > colon && bytes_equal(a, file, colon) && a[colon] == ':') {
            in_file++;
            int w = text_format(holds + used, sizeof holds - used, "%s%s", used ? ", " : "", a + colon + 1);
            if (used + (size_t)w < sizeof holds) used += (size_t)w;
        }
    }
    if (in_file) {
        map_problem(g->problems, p->d.path, m->line, "no box named \"%s\" in %s — that file holds: %s",
                    m->address + (colon < n ? colon + 1 : n), file, holds);
    } else {
        map_problem(g->problems, p->d.path, m->line, "no box source %s (\"%s\" as written) — box sources live in src/boxes/",
                    file, m->written);
    }
}
/* }}} */

static struct plan *plan_map(struct planning *g, const char *path, const char *text, size_t length);

/* {{{ plan_station_shape */
/* Look the station's box (or program) up and work out its ports and exits. */
static void plan_station_shape(struct planning *g, struct plan *p, struct plan_station *ps)
{
    struct map_station *m = ps->m;
    if (m->is_program) {
        for (int a = 0; a < g->depth; a++) {
            if (text_equal(g->ancestors[a], m->address)) {
                map_problem(g->problems, p->d.path, m->line, "%s places %s, which is already being placed above it — a program that places itself never ends",
                            m->name, m->address);
                return;
            }
        }
        if (g->depth >= MAX_DEPTH) {
            map_problem(g->problems, p->d.path, m->line, "programs placed inside programs more than %d deep", MAX_DEPTH);
            return;
        }
        size_t length = 0;
        const char *text = read_map_text(m->address, &length);
        if (!text) {
            map_problem(g->problems, p->d.path, m->line, "no map file %s (\"%s\" as written)", m->address, m->written);
            return;
        }
        ps->child = plan_map(g, m->address, text, length);
        if (ps->child) {
            ps->n_ports = ps->child->n_args;
            ps->n_exits = ps->child->n_results;
        }
        return;
    }
    ps->box = catalogue_box(m->address);
    if (!ps->box) {
        report_unknown_box(g, p, m);
        return;
    }
    ps->n_ports = ps->box->n_params + engine_kind_extra_ports(m->kind);
    int highest_out = -1;
    for (int i = 0; i < m->n_ports; i++) {
        if ((m->ports[i].kind == MAP_OUT_WIRE || m->ports[i].kind == MAP_OUT_DOOR) && m->ports[i].number > highest_out) {
            highest_out = m->ports[i].number;
        }
    }
    /* How many exits: a sink has none, a plain station one, a comparator
     * three, and the kinds that choose among many have as many as the
     * file uses. */
    if (ps->box->return_size == 0) {
        ps->n_exits = 0;
        if (highest_out >= 0) {
            map_problem(g->problems, p->d.path, m->line, "%s runs %s, which returns nothing, so it has no exits to write out lines for",
                        m->name, ps->box->name);
        }
    } else if (m->kind == KIND_PLAIN) {
        ps->n_exits = 1;
    } else if (m->kind == KIND_COMPARATOR) {
        ps->n_exits = 3;
    } else {
        ps->n_exits = highest_out >= 0 ? highest_out + 1 : 1;
    }
    if (m->kind == KIND_COMPARATOR && ps->box->return_size && !ps->box->return_order) {
        const struct catalogue_type *t = catalogue_type_named(ps->box->return_type);
        if (!t || t->kind == CATALOGUE_STRUCT) {
            map_problem(g->problems, p->d.path, m->line, "%s is a comparator, but %s returns %s, which has no ordering — "
                        "write a %s__compare beside the type", m->name, ps->box->name, ps->box->return_type, ps->box->return_type);
        }
    }
}
/* }}} */

/* {{{ plan_port_lines */
/* Every in and out line: its number is real, its value reads, a port is
 * not given two contradictory sources, and the doors are collected. */
static void plan_port_lines(struct planning *g, struct plan *p, struct plan_station *ps)
{
    struct map_station *m = ps->m;
    if (!ps->box && !ps->child) return;          /* already reported */
    for (int i = 0; i < m->n_ports; i++) {
        struct map_port_line *pl = &m->ports[i];
        int is_in = pl->kind <= MAP_IN_DOOR;
        const char *type;
        uint32_t size;
        if (is_in) {
            if (!port_type(ps, pl->number, &type, &size)) {
                if (ps->child) {
                    map_problem(g->problems, p->d.path, pl->line, "%s has no argument %d — %s marks %d argument%s",
                                m->name, pl->number, m->address, ps->n_ports, ps->n_ports == 1 ? "" : "s");
                } else {
                    map_problem(g->problems, p->d.path, pl->line, "%s has no port %d — %s takes %d input%s",
                                m->name, pl->number, ps->box->name, ps->n_ports, ps->n_ports == 1 ? "" : "s");
                }
                continue;
            }
            int routing = ps->box && pl->number >= ps->box->n_params;
            if (routing && pl->kind != MAP_IN_VALUE) {
                map_problem(g->problems, p->d.path, pl->line, "port %d of %s is its %s — it can only hold a fixed value (in %d = ...)",
                            pl->number, m->name, m->kind == KIND_COMPARATOR ? "threshold" : "weights", pl->number);
                continue;
            }
            if (ps->child && (pl->kind == MAP_IN_VALUE || pl->kind == MAP_IN_DEPTH || pl->kind == MAP_IN_NONE)) {
                map_problem(g->problems, p->d.path, pl->line, "%s is a program placed inside this one; its argument %d can be wired or marked, not given a value here",
                            m->name, pl->number);
                continue;
            }
            /* A port gets one kind of source: wired (any number of wires,
             * and a door mark besides), a fixed value, or none. */
            for (int j = 0; j < i; j++) {
                struct map_port_line *other = &m->ports[j];
                if (other->kind > MAP_IN_DOOR || other->number != pl->number) continue;
                int a_fixed = pl->kind == MAP_IN_VALUE, b_fixed = other->kind == MAP_IN_VALUE;
                int a_none = pl->kind == MAP_IN_NONE, b_none = other->kind == MAP_IN_NONE;
                if (a_fixed != b_fixed || a_none != b_none || (a_fixed && b_fixed)) {
                    map_problem(g->problems, p->d.path, pl->line, "port %d of %s already has a different source on line %d",
                                pl->number, m->name, other->line);
                    break;
                }
            }
            if (pl->kind == MAP_IN_VALUE) {
                uint8_t bytes[MAX_VALUE_BYTES > 4096 ? 4096 : MAX_VALUE_BYTES];
                char why[200];
                int bad;
                if (routing && m->kind == KIND_WEIGHTED) {
                    unsigned int w[64];
                    bad = value_parse_weights(pl->value, w, ps->n_exits > 64 ? 64 : ps->n_exits, why, sizeof why);
                } else if (size > sizeof bytes) {
                    bad = 1;
                    text_format(why, sizeof why, "a %u-byte value is too large to write in a map", (unsigned)size);
                } else {
                    bad = value_parse(type, pl->value, bytes, size, why, sizeof why);
                }
                if (bad) {
                    map_problem(g->problems, p->d.path, pl->line, "in %d = %s: %s (the port takes %s)", pl->number, pl->value, why, type);
                }
            }
            if (pl->kind == MAP_IN_DOOR) {
                if (pl->door < 0 || pl->door >= PROGRAM_DOORS) {
                    map_problem(g->problems, p->d.path, pl->line, "argument numbers run from 0 to %d", PROGRAM_DOORS - 1);
                } else if (p->arg_station[pl->door] < 0) {
                    p->arg_station[pl->door] = (int)(ps - p->st);
                    p->arg_port[pl->door] = pl->number;
                    if (pl->door + 1 > p->n_args) p->n_args = pl->door + 1;
                }
            }
        } else {
            if (!exit_type(ps, pl->number, &type, &size)) {
                map_problem(g->problems, p->d.path, pl->line, "%s has no exit %d — it has %d", m->name, pl->number, ps->n_exits);
                continue;
            }
            if (pl->kind == MAP_OUT_DOOR) {
                if (pl->door < 0 || pl->door >= PROGRAM_DOORS) {
                    map_problem(g->problems, p->d.path, pl->line, "result numbers run from 0 to %d", PROGRAM_DOORS - 1);
                } else if (p->res_station[pl->door] < 0) {
                    p->res_station[pl->door] = (int)(ps - p->st);
                    p->res_exit[pl->door] = pl->number;
                    if (pl->door + 1 > p->n_results) p->n_results = pl->door + 1;
                }
            }
        }
    }
}
/* }}} */

/* {{{ plan_both_ends */
/* Every wire is written at both ends, and the two must agree. Four
 * different mistakes, told apart: an arrow with no receiving end, a
 * receiving end with no arrow, two ends naming different numbers, and a
 * wire naming a station the file does not have. Then each agreed wire's
 * two sides must be the same width (issue 303). */
static void plan_both_ends(struct planning *g, struct plan *p)
{
    for (int s = 0; s < p->d.n_stations; s++) {
        struct plan_station *a = &p->st[s];
        for (int i = 0; i < a->m->n_ports; i++) {
            struct map_port_line *pl = &a->m->ports[i];
            if (pl->kind != MAP_OUT_WIRE && pl->kind != MAP_IN_WIRE) continue;
            int is_out = pl->kind == MAP_OUT_WIRE;
            struct plan_station *b = plan_station_named(p, pl->other);
            if (!b) {
                map_problem(g->problems, p->d.path, pl->line, "%s names a station %s the file does not have", a->m->name, pl->other);
                continue;
            }
            /* Look for the matching line at the other end. */
            int matched = 0, names_us = 0;
            for (int j = 0; j < b->m->n_ports; j++) {
                struct map_port_line *ql = &b->m->ports[j];
                if (ql->kind != (is_out ? MAP_IN_WIRE : MAP_OUT_WIRE) || !text_equal(ql->other, a->m->name)) continue;
                names_us = 1;
                if (ql->number == pl->other_number && ql->other_number == pl->number) matched = 1;
            }
            if (matched) {
                if (is_out) {
                    const char *ta, *tb;
                    uint32_t wa, wb;
                    if (exit_type(a, pl->number, &ta, &wa) && port_type(b, pl->other_number, &tb, &wb) && wa != wb) {
                        map_problem(g->problems, p->d.path, pl->line, "%s -> %s.%d: %s returns %s (%u bytes), the port takes %s (%u bytes)",
                                    a->m->name, b->m->name, pl->other_number,
                                    a->box ? a->box->name : a->m->name, ta, (unsigned)wa, tb, (unsigned)wb);
                    }
                }
                continue;
            }
            /* Unmatched. Report each disagreement once, from the out side
             * when both sides name each other with different numbers. */
            if (names_us) {
                if (is_out) {
                    map_problem(g->problems, p->d.path, pl->line, "%s and %s name different ports for their wire — "
                                "this end says out %d - %s.%d; the other end disagrees",
                                a->m->name, b->m->name, pl->number, b->m->name, pl->other_number);
                }
            } else if (is_out) {
                map_problem(g->problems, p->d.path, pl->line, "an arrow with no receiving end: %s says it feeds %s.%d — add \"in %d - %s.%d\" to %s",
                            a->m->name, b->m->name, pl->other_number, pl->other_number, a->m->name, pl->number, b->m->name);
            } else {
                map_problem(g->problems, p->d.path, pl->line, "a receiving end with no arrow: %s says it is fed by %s.%d — add \"out %d - %s.%d\" to %s",
                            a->m->name, b->m->name, pl->other_number, pl->other_number, a->m->name, pl->number, b->m->name);
            }
        }
    }
}
/* }}} */

/* {{{ plan_map */
static struct plan *plan_map(struct planning *g, const char *path, const char *text, size_t length)
{
    struct plan *p = map_arena_take(g->arena, sizeof *p);
    if (!p) return (struct plan *)0;
    for (int k = 0; k < PROGRAM_DOORS; k++) {
        p->arg_station[k] = p->res_station[k] = -1;
    }
    map_read(path, text, length, g->arena, &p->d, g->problems);
    p->st = map_arena_take(g->arena, sizeof(struct plan_station) * (size_t)(p->d.n_stations ? p->d.n_stations : 1));
    g->ancestors[g->depth++] = path;
    for (int i = 0; i < p->d.n_stations; i++) {
        p->st[i].m = &p->d.stations[i];
        p->st[i].placed = -1;
        p->st[i].program = -1;
        plan_station_shape(g, p, &p->st[i]);
    }
    g->depth--;
    for (int i = 0; i < p->d.n_stations; i++) {
        plan_port_lines(g, p, &p->st[i]);
    }
    plan_both_ends(g, p);
    /* An include says "this box source (or every one in this directory)
     * belongs to the program, placed or not". On this device every box
     * source is compiled into the image already (issue 304), so an include
     * cannot add anything; what it can still do is be wrong, so it is
     * checked: it must name a file or directory the catalogue holds boxes
     * from. */
    for (int i = 0; i < p->d.n_includes; i++) {
        const char *want = p->d.includes[i].path;
        size_t n = text_length(want);
        int found = 0;
        for (int k = 0; k < catalogue_count() && !found; k++) {
            const char *a = catalogue_address(k);
            found = text_length(a) > n && bytes_equal(a, want, n) && (a[n] == ':' || a[n] == '/');
        }
        if (!found) {
            map_problem(g->problems, p->d.path, p->d.includes[i].line, "include names %s, which holds no box the device has", want);
        }
    }
    return p;
}
/* }}} */
/* }}} */

/* {{{ building */
/* {{{ new_program */
static int new_program(struct core_ctx *c, const struct plan *p, int parent, const char *name)
{
    spin_lock(&programs_lock);
    int id = -1;
    for (int i = 0; i < PROGRAM_MAX; i++) {
        if (!programs[i].in_use) {
            programs[i].in_use = 1;
            id = i;
            break;
        }
    }
    spin_unlock(&programs_lock);
    if (id < 0) return -1;
    struct program_record *r = &programs[id];
    int in_use = r->in_use;
    bytes_zero(r, sizeof *r);
    r->in_use = in_use;
    r->parent = parent;
    r->owner = c->number;
    text_format(r->name, sizeof r->name, "%s", name);
    text_format(r->path, sizeof r->path, "%s", p->d.path);
    text_format(r->home, sizeof r->home, "%s", p->d.home);
    int n = p->d.n_stations ? p->d.n_stations : 1;
    r->capacity = n;
    r->stations = block_alloc_zero(c->number, sizeof(int32_t) * (size_t)n);
    r->names = block_alloc_zero(c->number, sizeof(*r->names) * (size_t)n);
    r->addresses = block_alloc_zero(c->number, sizeof(*r->addresses) * (size_t)n);
    r->looked_at = block_alloc_zero(c->number, (size_t)n);
    for (int k = 0; k < PROGRAM_DOORS; k++) {
        r->args[k].station = r->results[k].station = -1;
    }
    if (parent >= 0) {
        struct program_record *up = &programs[parent];
        up->children[up->n_children++] = id;
    }
    return id;
}
/* }}} */

/* {{{ build_place */
/* Sweep one: every station of every program in the tree. */
static int build_place(struct core_ctx *c, struct plan *p, int parent, const char *prefix, const char *name)
{
    int id = new_program(c, p, parent, name);
    if (id < 0) return ENGINE_FULL;
    p->program = id;
    struct program_record *r = &programs[id];
    for (int i = 0; i < p->d.n_stations; i++) {
        struct plan_station *ps = &p->st[i];
        char full[MAP_NAME * 2];
        text_format(full, sizeof full, "%s%s", prefix, ps->m->name);
        if (ps->child) {
            char child_prefix[MAP_NAME * 2];
            text_format(child_prefix, sizeof child_prefix, "%s.", full);
            int r2 = build_place(c, ps->child, id, child_prefix, ps->m->name);
            if (r2 < 0) return r2;
            ps->program = ps->child->program;
            continue;
        }
        int32_t idx = engine_place(ps->box, full, ps->m->kind, ps->n_exits);
        if (idx < 0) return idx;
        ps->placed = idx;
        r->stations[r->n_stations] = idx;
        text_format(r->names[r->n_stations], MAP_NAME, "%s", ps->m->name);
        text_format(r->addresses[r->n_stations], MAP_ADDRESS, "%s", ps->m->address);
        r->n_stations++;
        atomic_store_release(&station_at(idx)->program, (uint32_t)(id + 1));
    }
    /* The program's doors, as engine places. A door on a placed program's
     * station line hands this program's door straight to the inner one. */
    for (int k = 0; k < PROGRAM_DOORS; k++) {
        if (p->arg_station[k] >= 0) {
            struct plan_station *ps = &p->st[p->arg_station[k]];
            r->args[k].station = ps->placed;
            r->args[k].number = p->arg_port[k];
        }
        if (p->res_station[k] >= 0) {
            struct plan_station *ps = &p->st[p->res_station[k]];
            r->results[k].station = ps->placed;
            r->results[k].number = p->res_exit[k];
        }
    }
    return id;
}
/* }}} */

/* {{{ destination_of */
/* Where a wire into station `b`'s port `port` actually lands: the station
 * itself, or — for a placed program — the inner port its argument door
 * names, followed down however deep the nesting goes. */
static struct destination destination_of(struct plan_station *b, int port)
{
    struct destination d = { b->placed, port };
    while (b->child) {
        struct plan *cp = b->child;
        struct plan_station *inner = &cp->st[cp->arg_station[port]];
        port = cp->arg_port[port];
        b = inner;
        d.station = b->placed;
        d.port = port;
    }
    return d;
}
/* }}} */

/* {{{ source_of */
/* The station and exit a wire out of `a`'s exit `exit` actually leaves
 * from: the station itself, or the inner exit a placed program's result
 * door names. */
static struct destination source_of(struct plan_station *a, int exit)
{
    struct destination s = { a->placed, exit };
    while (a->child) {
        struct plan *cp = a->child;
        struct plan_station *inner = &cp->st[cp->res_station[exit]];
        exit = cp->res_exit[exit];
        a = inner;
        s.station = a->placed;
        s.port = exit;
    }
    return s;
}
/* }}} */

/* {{{ build_wire */
/* Sweep two: every wire, one whole exit at a time, so every destination
 * of an exit starts from the same instant (issue 207). Wires out of a
 * placed program's result are added to whatever the inner program already
 * wired from that exit. */
static int build_wire(struct core_ctx *c, struct plan *p)
{
    (void)c;
    for (int i = 0; i < p->d.n_stations; i++) {
        if (p->st[i].child) {
            int r = build_wire(c, p->st[i].child);
            if (r < 0) return r;
        }
    }
    for (int i = 0; i < p->d.n_stations; i++) {
        struct plan_station *a = &p->st[i];
        for (int e = 0; e < a->n_exits; e++) {
            struct destination list[256];
            int n = 0;
            struct destination from = source_of(a, e);
            if (a->child) {
                n = engine_exit_destinations(from.station, from.port, list, 256);
                if (n < 0) n = 0;
            }
            int added = 0;
            for (int k = 0; k < a->m->n_ports && n < 256; k++) {
                struct map_port_line *pl = &a->m->ports[k];
                if (pl->kind != MAP_OUT_WIRE || pl->number != e) continue;
                struct plan_station *b = plan_station_named(p, pl->other);
                list[n++] = destination_of(b, pl->other_number);
                added++;
            }
            if (added) {
                int r = engine_wire(from.station, from.port, list, n);
                if (r < 0) return r;
            }
        }
    }
    return ENGINE_OK;
}
/* }}} */

/* {{{ build_sources */
/* Sweep three: each port's source (queued, none, or a starting depth),
 * and the door marks. Fixed values wait for sweep four. */
static int build_sources(struct core_ctx *c, struct plan *p)
{
    for (int i = 0; i < p->d.n_stations; i++) {
        struct plan_station *ps = &p->st[i];
        if (ps->child) {
            int r = build_sources(c, ps->child);
            if (r < 0) return r;
            continue;
        }
        for (int k = 0; k < ps->m->n_ports; k++) {
            struct map_port_line *pl = &ps->m->ports[k];
            int r = ENGINE_OK;
            switch (pl->kind) {
            case MAP_IN_WIRE:
                r = engine_configure(ps->placed, pl->number, PORT_RING, (void *)0, 0);
                break;
            case MAP_IN_DOOR:
                r = engine_mark_argument(ps->placed, pl->number, pl->door);
                if (r == ENGINE_OK) r = engine_configure(ps->placed, pl->number, PORT_RING, (void *)0, 0);
                break;
            case MAP_IN_DEPTH:
                r = engine_port_reserve(ps->placed, pl->number, pl->depth);
                if (r == ENGINE_OK) r = engine_configure(ps->placed, pl->number, PORT_RING, (void *)0, 0);
                break;
            case MAP_IN_NONE:
                r = engine_configure(ps->placed, pl->number, PORT_NONE, (void *)0, 0);
                break;
            case MAP_OUT_DOOR:
                r = engine_mark_result(ps->placed, pl->number, pl->door);
                break;
            default:
                break;
            }
            if (r < 0) return r;
        }
    }
    return ENGINE_OK;
}
/* }}} */

/* {{{ build_values */
/* Sweep four: the fixed values. Writing one runs its station's readiness
 * check, so these writes are what set the program going. */
static int build_values(struct core_ctx *c, struct plan *p)
{
    for (int i = 0; i < p->d.n_stations; i++) {
        struct plan_station *ps = &p->st[i];
        if (ps->child) {
            int r = build_values(c, ps->child);
            if (r < 0) return r;
            continue;
        }
        for (int k = 0; k < ps->m->n_ports; k++) {
            struct map_port_line *pl = &ps->m->ports[k];
            if (pl->kind != MAP_IN_VALUE) continue;
            const char *type;
            uint32_t size;
            port_type(ps, pl->number, &type, &size);
            uint8_t bytes[4096];
            char why[200];
            if (text_equal(type, "weights")) {
                value_parse_weights(pl->value, (unsigned int *)bytes, ps->n_exits, why, sizeof why);
            } else {
                value_parse(type, pl->value, bytes, size, why, sizeof why);
            }
            int r = engine_configure(ps->placed, pl->number, PORT_STATIC, bytes, size);
            if (r < 0) return r;
        }
    }
    return ENGINE_OK;
}
/* }}} */
/* }}} */

/* {{{ sort_report */
/* Copy the collected problems into the report, ordered by file and line,
 * under a one-line heading. */
static void sort_report(const struct map_problems *pr, const char *path, struct map_report *report)
{
    const char *lines[512];
    int n = 0;
    const char *s = pr->text;
    while (s && *s && n < 512) {
        lines[n++] = s;
        while (*s && *s != '\n') s++;
        if (*s) s++;
    }
    /* Insertion sort by (path, line number); entries are "  path line N  ..." */
    for (int i = 1; i < n; i++) {
        const char *x = lines[i];
        int j = i - 1;
        while (j >= 0) {
            const char *y = lines[j];
            /* compare path then numeric line */
            const char *px = x + 2, *py = y + 2;
            int cmp = 0;
            while (*px && *px == *py && *px != ' ') { px++; py++; }
            if (*px != *py) cmp = (unsigned char)*px < (unsigned char)*py ? -1 : 1;
            if (cmp == 0) {
                int lx = 0, ly = 0;
                const char *qx = px, *qy = py;
                while (*qx && (*qx < '0' || *qx > '9')) qx++;
                while (*qy && (*qy < '0' || *qy > '9')) qy++;
                while (*qx >= '0' && *qx <= '9') lx = lx * 10 + (*qx++ - '0');
                while (*qy >= '0' && *qy <= '9') ly = ly * 10 + (*qy++ - '0');
                cmp = lx < ly ? -1 : lx > ly;
            }
            if (cmp >= 0) break;
            lines[j + 1] = lines[j];
            j--;
        }
        lines[j + 1] = x;
    }
    size_t used = (size_t)text_format(report->text, sizeof report->text, "%d problem%s in %s:\n",
                                      pr->count, pr->count == 1 ? "" : "s", path);
    for (int i = 0; i < n && used < sizeof report->text; i++) {
        const char *e = lines[i];
        while (*e && *e != '\n' && used + 1 < sizeof report->text) report->text[used++] = *e++;
        if (used + 1 < sizeof report->text) report->text[used++] = '\n';
    }
    report->text[used < sizeof report->text ? used : sizeof report->text - 1] = 0;
    report->problems = pr->count;
}
/* }}} */

/* {{{ program_load_text */
int program_load_text(const char *path, const char *text, size_t length, struct map_report *report)
{
    struct core_ctx *c = engine_enter();
    struct map_arena arena;
    map_arena_begin(&arena, c->number);
    struct map_problems problems;
    bytes_zero(&problems, sizeof problems);
    problems.arena = &arena;
    struct planning g;
    bytes_zero(&g, sizeof g);
    g.arena = &arena;
    g.problems = &problems;

    report->text[0] = 0;
    report->problems = 0;
    struct plan *p = plan_map(&g, path, text, length);
    int id = -1;
    /* Two outcomes: problems (report them all, place nothing), or none
     * (build the whole tree in four sweeps). */
    if (!p || problems.count) {
        sort_report(&problems, path, report);
    } else {
        id = build_place(c, p, -1, "", "");
        int r = id < 0 ? id : build_wire(c, p);
        if (r >= 0) r = build_sources(c, p);
        if (r >= 0) r = build_values(c, p);
        if (r < 0) {
            text_format(report->text, sizeof report->text, "building %s failed after it was checked: %s\n",
                        path, engine_error_text(r));
            report->problems = 1;
            if (id >= 0) {
                engine_leave(c);
                program_remove(id);
                c = engine_enter();
            }
            id = -1;
        }
    }
    map_arena_end(&arena);
    engine_leave(c);
    return id;
}
/* }}} */

/* {{{ program_load */
int program_load(const char *path, struct map_report *report)
{
    size_t length = 0;
    const char *text = read_map_text(path, &length);
    if (!text) {
        text_format(report->text, sizeof report->text, "1 problem in %s:\n  %s line   0  no such map file\n", path, path);
        report->problems = 1;
        return -1;
    }
    return program_load_text(path, text, length, report);
}
/* }}} */

/* {{{ fed_by_a_wire */
/* Does any wire, anywhere, feed this station's port? (An argument slot is
 * a marked port that nothing feeds — derived, never stored.) */
int engine_port_fed(int32_t station, int port)
{
    int32_t n = engine_station_count();
    for (int32_t s = 0; s < n; s++) {
        int exits = engine_exit_count(s);
        for (int e = 0; e < exits; e++) {
            struct destination d[256];
            int k = engine_exit_destinations(s, e, d, 256);
            for (int i = 0; i < k && i < 256; i++) {
                if (d[i].station == station && d[i].port == port) return 1;
            }
        }
    }
    return 0;
}
/* }}} */

/* {{{ report_line */
static void report_line(struct map_report *report, const char *fmt, ...)
{
    size_t used = text_length(report->text);
    va_list args;
    va_start(args, fmt);
    text_format_va(report->text + used, sizeof report->text - used, fmt, args);
    va_end(args);
}
/* }}} */

/* {{{ check_numbering */
/* Doors are numbered 0, 1, 2 ... with no gap and no repeat, on the
 * argument side and the result side separately. Only visible once every
 * line is in, which is why it is checked here and not while loading. */
static int check_numbering(struct program_record *r, int is_args, struct map_report *report)
{
    int seen[PROGRAM_DOORS] = { 0 };
    int problems = 0;
    for (int i = 0; i < r->n_stations; i++) {
        int32_t s = r->stations[i];
        int count = is_args ? engine_station_box(s)->n_params : engine_exit_count(s);
        for (int k = 0; k < count; k++) {
            int door = is_args ? engine_port_door(s, k) : engine_exit_door(s, k);
            if (door < 0 || door >= PROGRAM_DOORS) continue;
            if (is_args && engine_port_fed(s, k)) continue;   /* marked and wired: not an argument */
            if (seen[door]++) {
                report_line(report, "  %s: %s %d$ is marked twice (again on %s)\n", r->path,
                            is_args ? "argument" : "result", door, r->names[i]);
                problems++;
            }
        }
    }
    int highest = -1;
    for (int k = 0; k < PROGRAM_DOORS; k++) if (seen[k]) highest = k;
    for (int k = 0; k < highest; k++) {
        if (!seen[k]) {
            report_line(report, "  %s: %s %d$ is missing, but %d$ exists\n", r->path, is_args ? "argument" : "result", k, highest);
            problems++;
        }
    }
    return problems;
}
/* }}} */

/* {{{ program_bring_up */
int program_bring_up(int program, struct map_report *report)
{
    struct program_record *r = program_record(program);
    report->text[0] = 0;
    report->problems = 0;
    if (!r) {
        report_line(report, "no program %d\n", program);
        report->problems = 1;
        return 1;
    }
    int problems = check_numbering(r, 1, report) + check_numbering(r, 0, report);
    for (int i = 0; i < r->n_children; i++) {
        struct map_report inner;
        problems += program_bring_up(r->children[i], &inner);
        report_line(report, "%s", inner.text);
    }
    report->problems = problems;
    if (problems) {
        return problems;
    }
    /* Look once at every station not yet looked at: one added by hand
     * since the last bring-up may already hold a complete set. Stations
     * whose every input is fixed are never re-looked-at — each look would
     * be one more run. */
    struct core_ctx *c = engine_enter();
    for (int i = 0; i < r->n_stations; i++) {
        if (r->looked_at[i]) continue;
        r->looked_at[i] = 1;
        struct station *s = station_live(r->stations[i]);
        if (s && atomic_load_acquire(&s->open_ports) > 0) {
            station_check(c, r->stations[i]);
        }
    }
    engine_leave(c);
    return 0;
}
/* }}} */

/* {{{ program_unfinished */
int program_unfinished(int program, struct map_report *report)
{
    struct program_record *r = program_record(program);
    report->text[0] = 0;
    report->problems = 0;
    if (!r) return 0;
    int findings = 0;
    for (int i = 0; i < r->n_stations; i++) {
        int32_t s = r->stations[i];
        const struct box *b = engine_station_box(s);
        for (int k = 0; b && k < b->n_params; k++) {
            int tag = engine_port_tag(s, k);
            int door = engine_port_door(s, k);
            /* The explicit mark buys the exemption, never the mere
             * absence of a wire — so a forgotten wire stays
             * distinguishable from a deliberate door. */
            if (tag == PORT_NONE) {
                report_line(report, "  %s: %s port %d has no source, so %s can never run\n", r->path, r->names[i], k, r->names[i]);
                findings++;
            } else if (tag == PORT_RING && door < 0 && !engine_port_fed(s, k)) {
                report_line(report, "  %s: %s port %d queues values but nothing feeds it and it is not marked as an argument\n",
                            r->path, r->names[i], k);
                findings++;
            }
        }
    }
    report->problems = findings;
    return findings;
}
/* }}} */

/* {{{ program_argument */
int program_argument(int program, int door, const void *value, size_t size)
{
    struct program_record *r = program_record(program);
    if (!r || door < 0 || door >= PROGRAM_DOORS || r->args[door].station < 0) {
        return ENGINE_NO_PORT;
    }
    return engine_deliver(r->args[door].station, r->args[door].number, value, size);
}
/* }}} */

/* {{{ program_result */
int program_result(int program, int door, void *out, size_t size)
{
    struct program_record *r = program_record(program);
    if (!r || door < 0 || door >= PROGRAM_DOORS || r->results[door].station < 0) {
        return ENGINE_NO_EXIT;
    }
    return engine_take_result(r->results[door].station, r->results[door].number, out, size);
}
/* }}} */

/* {{{ program_argument_count */
int program_argument_count(int program)
{
    struct program_record *r = program_record(program);
    int n = 0;
    for (int k = 0; r && k < PROGRAM_DOORS; k++) if (r->args[k].station >= 0) n = k + 1;
    return n;
}
/* }}} */

/* {{{ program_result_count */
int program_result_count(int program)
{
    struct program_record *r = program_record(program);
    int n = 0;
    for (int k = 0; r && k < PROGRAM_DOORS; k++) if (r->results[k].station >= 0) n = k + 1;
    return n;
}
/* }}} */

/* {{{ program_station */
int32_t program_station(int program, const char *name)
{
    struct program_record *r = program_record(program);
    for (int i = 0; r && i < r->n_stations; i++) {
        if (text_equal(r->names[i], name)) return r->stations[i];
    }
    return ENGINE_NO_STATION;
}
/* }}} */

/* {{{ program accessors */
int program_station_count(int program) { struct program_record *r = program_record(program); return r ? r->n_stations : 0; }
int32_t program_station_at(int program, int i) { struct program_record *r = program_record(program); return r && i >= 0 && i < r->n_stations ? r->stations[i] : ENGINE_NO_STATION; }
const char *program_path(int program) { struct program_record *r = program_record(program); return r ? r->path : ""; }
const char *program_name(int program) { struct program_record *r = program_record(program); return r ? r->name : ""; }
int program_child_count(int program) { struct program_record *r = program_record(program); return r ? r->n_children : 0; }
int program_child(int program, int i) { struct program_record *r = program_record(program); return r && i >= 0 && i < r->n_children ? r->children[i] : -1; }
/* }}} */

/* {{{ program_remove */
int program_remove(int program)
{
    struct program_record *r = program_record(program);
    if (!r) return ENGINE_NO_STATION;
    for (int i = 0; i < r->n_children; i++) {
        program_remove(r->children[i]);
    }
    for (int i = 0; i < r->n_stations; i++) {
        engine_remove(r->stations[i]);
    }
    struct core_ctx *c = engine_enter();
    block_free(c->number, r->stations);
    block_free(c->number, r->names);
    block_free(c->number, r->addresses);
    block_free(c->number, r->looked_at);
    if (r->parent >= 0) {
        struct program_record *up = &programs[r->parent];
        for (int i = 0; i < up->n_children; i++) {
            if (up->children[i] == program) {
                up->children[i] = up->children[--up->n_children];
                break;
            }
        }
    }
    spin_lock(&programs_lock);
    bytes_zero(r, sizeof *r);
    spin_unlock(&programs_lock);
    engine_leave(c);
    return ENGINE_OK;
}
/* }}} */
