/*
 * 069-map-write.c — writing a running program back out as a map (the
 * round trip of issue 312, and what an editor on the device will use
 * constantly).
 *
 * General description: for each station of the program, one station line
 * with its kind, name and box address (written relative to the program's
 * own file, so the text reads back from the same place), then one line for
 * everything feeding each of its ports and one for everything each exit
 * feeds — both ends of every wire, the way the format asks. Fixed values
 * are written through the catalogue's type rows, so they read back to the
 * same bytes. Programs placed inside this one are written as a station
 * line naming their map file, with the wires into their argument doors and
 * out of their result doors.
 *
 * What does not survive the trip, said plainly: a port that queues values
 * but has nothing feeding it and no door mark is written as having no
 * source, because the format has no way to say "queued, fed from outside
 * the file". It reads back as a port with no source.
 */
#include "031-engine-internal.h"
#include "070-catalogue.h"
#include "067-values.h"
#include "068-programs.h"

struct writer {
    char  *out;
    size_t size;
    size_t n;
};

/* {{{ w */
static void w(struct writer *wr, const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);
    size_t left = wr->n < wr->size ? wr->size - wr->n : 0;
    int k = text_format_va(wr->out + (wr->n < wr->size ? wr->n : wr->size), left, fmt, args);
    va_end(args);
    wr->n += (size_t)k;
}
/* }}} */

/* {{{ relative_to */
/* "src/boxes/063-text.c:say" seen from "src/maps" is "../boxes/063-text.c:say". */
static void relative_to(const char *home, const char *address, char *out, size_t size)
{
    size_t common = 0, i = 0;
    /* the longest shared run of whole directories */
    while (home[i] && address[i] && home[i] == address[i]) {
        i++;
        if (address[i] == '/' && (home[i] == '/' || !home[i])) common = i + 1;
    }
    if (!home[i] && address[i] == '/') common = i + 1;
    int ups = 0;
    const char *h = home + (common > 0 ? common : 0);
    if (common == 0) h = home;
    if (*h) {
        ups = 1;
        for (const char *p = h; *p; p++) if (*p == '/') ups++;
    }
    size_t n = 0;
    for (int u = 0; u < ups && n + 3 < size; u++) {
        out[n++] = '.'; out[n++] = '.'; out[n++] = '/';
    }
    text_format(out + n, size - n, "%s", address + common);
}
/* }}} */

/* {{{ name_of */
/* This program's name for an engine station — its own station's name, or
 * a placed program's name and door number when the station is behind one
 * of its doors. Answers 0 if the station belongs to neither. */
static int name_of(struct program_record *r, int32_t station, int number, int is_port,
                   const char **name, int *door)
{
    for (int i = 0; i < r->n_stations; i++) {
        if (r->stations[i] == station) {
            *name = r->names[i];
            *door = number;
            return 1;
        }
    }
    for (int c = 0; c < r->n_children; c++) {
        struct program_record *child = program_record(r->children[c]);
        const struct program_door *doors = is_port ? child->args : child->results;
        for (int k = 0; k < PROGRAM_DOORS; k++) {
            if (doors[k].station == station && doors[k].number == number) {
                *name = child->name;
                *door = k;
                return 1;
            }
        }
    }
    return 0;
}
/* }}} */

/* {{{ write_feeders */
/* Every wire into (station, port) from this program's stations or its
 * children's result doors, as "in N - name.exit" lines. Answers how many. */
static int write_feeders(struct writer *wr, struct program_record *r, int32_t station, int port, int written_port)
{
    int found = 0;
    int32_t n = engine_station_count();
    for (int32_t s = 0; s < n; s++) {
        int exits = engine_exit_count(s);
        for (int e = 0; e < exits; e++) {
            struct destination d[256];
            int k = engine_exit_destinations(s, e, d, 256);
            for (int i = 0; i < k && i < 256; i++) {
                if (d[i].station != station || d[i].port != port) continue;
                const char *name;
                int number;
                if (name_of(r, s, e, 0, &name, &number)) {
                    w(wr, "  in %d - %s.%d\n", written_port, name, number);
                    found++;
                }
            }
        }
    }
    return found;
}
/* }}} */

/* {{{ write_station */
static void write_station(struct writer *wr, struct program_record *r, int i)
{
    int32_t s = r->stations[i];
    struct station *st = station_live(s);
    if (!st) return;
    char address[MAP_ADDRESS];
    relative_to(r->home, r->addresses[i], address, sizeof address);
    w(wr, "\n%s %s (%s)\n", map_kind_word(st->kind), r->names[i], address);
    for (int p = 0; p < st->n_ports; p++) {
        int tag = engine_port_tag(s, p);
        int door = engine_port_door(s, p);
        int feeders = write_feeders(wr, r, s, p, p);
        if (door >= 0) {
            w(wr, "  in %d - %d$\n", p, door);
        }
        /* Three more possibilities for a port: a fixed value (written in
         * the text form of its type), no source, or a queue nothing feeds
         * (written as no source — see the top of this file). */
        if (tag == PORT_STATIC) {
            char text[1024];
            uint8_t bytes[4096];
            int size = engine_static_value(s, p, bytes, sizeof bytes);
            int k = -1;
            if (p >= st->n_box_ports && st->kind == KIND_WEIGHTED) {
                k = value_print_weights((const unsigned int *)bytes, st->n_exits, text, sizeof text);
            } else {
                const char *type = p < st->n_box_ports ? st->box->params[p].type : st->box->return_type;
                if (size > 0) k = value_print(type, bytes, (size_t)size, text, sizeof text);
            }
            if (k >= 0) w(wr, "  in %d = %s\n", p, text);
            else w(wr, "  # in %d holds a value this writer cannot put into words\n", p);
        } else if (!feeders && door < 0) {
            w(wr, "  in %d -\n", p);
        }
    }
    for (int e = 0; e < st->n_exits; e++) {
        struct destination d[256];
        int k = engine_exit_destinations(s, e, d, 256);
        for (int j = 0; j < k && j < 256; j++) {
            const char *name;
            int number;
            if (name_of(r, d[j].station, d[j].port, 1, &name, &number)) {
                w(wr, "  out %d - %s.%d\n", e, name, number);
            } else {
                w(wr, "  # out %d also feeds a station of another program\n", e);
            }
        }
        int door = engine_exit_door(s, e);
        if (door >= 0) {
            w(wr, "  out %d - %d$\n", e, door);
        }
    }
}
/* }}} */

/* {{{ write_child */
static void write_child(struct writer *wr, struct program_record *r, struct program_record *child)
{
    char address[MAP_ADDRESS];
    relative_to(r->home, child->path, address, sizeof address);
    w(wr, "\nstation %s (%s)\n", child->name, address);
    for (int k = 0; k < PROGRAM_DOORS; k++) {
        if (child->args[k].station >= 0) {
            write_feeders(wr, r, child->args[k].station, child->args[k].number, k);
        }
    }
    for (int k = 0; k < PROGRAM_DOORS; k++) {
        if (child->results[k].station < 0) continue;
        struct destination d[256];
        int n = engine_exit_destinations(child->results[k].station, child->results[k].number, d, 256);
        for (int j = 0; j < n && j < 256; j++) {
            const char *name;
            int number;
            /* Only wires leaving the child for this program are the
             * child's out lines; wires inside the child are its own. */
            int own = 0;
            for (int i = 0; i < child->n_stations; i++) if (child->stations[i] == d[j].station) own = 1;
            if (!own && name_of(r, d[j].station, d[j].port, 1, &name, &number)) {
                w(wr, "  out %d - %s.%d\n", k, name, number);
            }
        }
    }
}
/* }}} */

/* {{{ program_write */
int program_write(int program, char *out, size_t size)
{
    struct program_record *r = program_record(program);
    if (!r) return -1;
    struct writer wr = { out, size, 0 };
    struct core_ctx *c = engine_enter();
    w(&wr, "# %s, written back out by the map writer\n", r->path);
    for (int i = 0; i < r->n_stations; i++) {
        write_station(&wr, r, i);
    }
    for (int k = 0; k < r->n_children; k++) {
        write_child(&wr, r, program_record(r->children[k]));
    }
    engine_leave(c);
    return wr.n < size ? (int)wr.n : -1;
}
/* }}} */
