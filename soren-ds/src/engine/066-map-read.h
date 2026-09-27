/*
 * 066-map-read.h — reading a map file into a description (issue 305).
 *
 * General description: a map is one line-oriented text file. The first
 * word of every line says what the line is — a shortcut (`boxes =
 * ../boxes/`), an include, a station of some kind (`station`,
 * `comparator`, `iterator`, `random`, `weighted`, `spread`), or one of its
 * ports (`in`, `out`). Indentation means nothing; an `in` or `out` line
 * belongs to the station line above it. A braced value may run across
 * lines. `#` starts a comment unless it sits inside a quoted string.
 *
 * Reading builds a description and constructs nothing — building from the
 * description is the loader's job (068). Every malformed line is recorded
 * as a problem, naming its line, and reading carries on, so a person
 * fixing a new map sees every mistake in one go (issue 307).
 *
 * The one address resolver lives here too, because every caller that
 * turns an address into a file must agree with every other.
 */
#ifndef SOREN_MAP_READ_H
#define SOREN_MAP_READ_H

#include <stdint.h>
#include <stddef.h>

#define MAP_NAME    48
#define MAP_ADDRESS 192
#define MAP_LINE    1024

/* {{{ memory for one reading */
/* All of a description's memory comes from one arena, dropped whole when
 * the description is no longer needed. */
struct map_arena {
    int    owner;                   /* whose blocks (a core, or the outside owner) */
    void  *chunks;                  /* linked list of blocks, for dropping */
    char  *next;
    size_t left;
};
void  map_arena_begin(struct map_arena *a, int owner);
void *map_arena_take(struct map_arena *a, size_t bytes);
void  map_arena_end(struct map_arena *a);
/* }}} */

/* {{{ problems (issue 307) */
/* Every problem found, one per line, in file order, as text. */
struct map_problems {
    struct map_arena *arena;
    char             *text;
    size_t            length;
    size_t            capacity;
    int               count;
};
void map_problem(struct map_problems *p, const char *path, int line, const char *fmt, ...);
/* }}} */

/* {{{ the description */
enum map_port_kind {
    MAP_IN_WIRE,     /* in N - station.exit */
    MAP_IN_NONE,     /* in N -              (no source yet) */
    MAP_IN_VALUE,    /* in N = value        (a fixed value) */
    MAP_IN_DEPTH,    /* in N x64            (a queue that starts deeper) */
    MAP_IN_DOOR,     /* in N - K$           (the program's argument K) */
    MAP_OUT_WIRE,    /* out N - station.port */
    MAP_OUT_DOOR,    /* out N - K$          (the program's result K) */
};

struct map_port_line {
    int   kind;                     /* enum map_port_kind */
    int   number;                   /* the port (in) or exit (out) this line is about */
    char  other[MAP_NAME];          /* the station at the other end of a wire */
    int   other_number;             /* its exit (for in) or port (for out) */
    int   door;                     /* K for a $ line */
    int   depth;                    /* for x lines */
    char *value;                    /* the value's text, for = lines */
    int   line;
};

struct map_station {
    char                  name[MAP_NAME];
    int                   kind;     /* enum station_kind (031-engine.h) */
    char                  written[MAP_ADDRESS];   /* the address as the file wrote it */
    char                  address[MAP_ADDRESS];   /* resolved: "src/boxes/063-text.c:say" or "src/maps/x.map" */
    int                   is_program;             /* the address names a map file: a program placed inside */
    struct map_port_line *ports;
    int                   n_ports;
    int                   capacity;
    int                   line;
};

struct map_shortcut {
    char name[MAP_NAME];
    char path[MAP_ADDRESS];
    int  line;
};

struct map_include {
    char path[MAP_ADDRESS];         /* resolved */
    int  line;
};

struct map_description {
    char                 path[MAP_ADDRESS];   /* the file it was read from */
    char                 home[MAP_ADDRESS];   /* the directory every address in it is relative to */
    struct map_station  *stations;
    int                  n_stations;
    struct map_shortcut *shortcuts;
    int                  n_shortcuts;
    struct map_include  *includes;
    int                  n_includes;
};
/* }}} */

/* Read `text` (the contents of the map at `path`) into `out`. Problems are
 * appended to `problems`; answers how many this read added. */
int map_read(const char *path, const char *text, size_t length, struct map_arena *arena,
             struct map_description *out, struct map_problems *problems);

/* The one address resolver: apply the shortcuts to the first segment,
 * join what is left to the description's home unless it is already
 * absolute, and collapse "//", "./" and "../". Writes into `out`. */
void map_resolve(const struct map_description *d, const char *written, char *out, size_t size);

/* A station of the description by name, or NULL. */
struct map_station *map_station_named(const struct map_description *d, const char *name);

/* The keyword for a kind, and back. */
const char *map_kind_word(int kind);

#endif
