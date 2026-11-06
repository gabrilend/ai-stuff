/*
 * 087-compile.h — compiling a box on the running device (issue 409).
 *
 * General description: a box's C source, handed over while the device
 * runs, becomes boxes a station can place. The source goes through the
 * same generator the build runs (060), whose C is handed to a compiler
 * (the platform's, 025-platform.h), and the compiled unit's rows are added
 * to the catalogue (070) all at once. A box compiled here is addressed by
 * the file its source was saved to — "/programs/greet/boxes/greet.c:greet"
 * — so a program placing it can be written back out as a map plus the C
 * of every box it places, and built again.
 *
 * Nothing is half-done: problems the generator finds and words the
 * compiler says come back whole, as the report, and nothing is added;
 * the rows appear only once the code they point at is loaded.
 *
 * The source is kept, as text, from the moment its boxes exist: in the
 * engine's own memory, which is RAM and empties at a reboot — the lifetime
 * of the device's tmp/ tier (docs/011). It is found again from the file's
 * path or from any of its boxes' addresses.
 */
#ifndef SOREN_COMPILE_H
#define SOREN_COMPILE_H

#include <stddef.h>
#include <stdint.h>

#define COMPILE_PATH_BYTES 128      /* a file a box address names; the address adds ":function" */
#define COMPILE_WORDS 4096          /* the report: the generator's or the compiler's own words */

enum compile_error {
    COMPILE_BAD_PATH   = -30,       /* empty, too long, not ending ".c", or holding ':' '"' '\' */
    COMPILE_UNREADABLE = -31,       /* the generator found problems; the report lists every one */
    COMPILE_NO_BOXES   = -32,       /* the source defines no box */
    COMPILE_FAILED     = -33,       /* the compiler refused or the code would not load; its words */
    COMPILE_TAKEN      = -34,       /* a box address the image's own rows already hold */
    COMPILE_FULL       = -35,       /* no room left for another unit or its rows */
};

struct compile_report {
    char text[COMPILE_WORDS];
};

/* Compile `text` (`length` bytes), the source saved at `path`, and add
 * every box it defines to the catalogue as "path:function". Answers the
 * new unit's number (0 or more), or a negative compile_error, engine_error
 * (ENGINE_NO_MEMORY) — with what went wrong in `report`. Compiling a path
 * again makes a newer unit: its rows answer the addresses from then on,
 * and the older unit's boxes stay where they are placed. Called from
 * outside the cores, or from a box: it never holds the engine while the
 * compiler runs. */
int compile_box_source(const char *path, const char *text, size_t length, struct compile_report *report);

/* The source of the newest unit compiled from a file, by the file's path
 * or by any box address in it ("/boxes/greet.c:greet"): its text (not
 * ended by a zero) and length, or NULL if no unit came from that file. */
const char *compile_source(const char *path_or_address, size_t *length);

/* {{{ the units, for 410 and for listings */
enum compile_unit_state {
    UNIT_LOADED = 1,                /* its code is loaded and its rows are in the catalogue */
};

struct compile_unit_facts {
    const char *path;
    int         state;              /* enum compile_unit_state */
    int         boxes;              /* rows it added */
    uint64_t    when_ns;            /* on the platform clock, when its rows appeared */
    const char *source;
    size_t      length;
};

int compile_unit_count(void);
int compile_unit_facts(int unit, struct compile_unit_facts *out);
/* }}} */

const char *compile_error_text(int error);

#endif
