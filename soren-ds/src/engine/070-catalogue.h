/*
 * 070-catalogue.h — every box the device holds, found by its address
 * (issues 302, 303, and the catalogue question in phase-3-progress.md).
 *
 * General description: the generator (060) writes, for every box source,
 * a record per box and a table of rows mapping each box's address —
 * "src/boxes/062-arithmetic.c:add" — to its record. The loader looks boxes
 * up here by the address a map file names. Value types have rows too:
 * their size, their fields (so text like { 5, "hey" } can be turned into
 * bytes and back), and their ordering if they have one.
 *
 * The built-in rows are fixed at build time. Boxes compiled later on the
 * device (phase 4) are added at run time into shelves that never move, the
 * same way stations are — a reader holding a row never sees it relocate.
 *
 * Why this device keeps a catalogue at all, when the parent project
 * deleted its own: the parent leaned on the operating system's symbol
 * table to find a box that arrived late. This device is the operating
 * system; a table it writes is the catalogue. What it takes from the
 * parent is that every width is a compile-time constant in the box's
 * record; what remains stored is one address per box. (Proposed answer to
 * the open question, UNVERIFIED — see phase-3-progress.md.)
 */
#ifndef SOREN_CATALOGUE_H
#define SOREN_CATALOGUE_H

#include <stdint.h>
#include "031-engine.h"

/* Kinds, numbered as the generator numbers them (enum gen_field_kind). */
enum catalogue_kind {
    CATALOGUE_SIGNED   = 0,
    CATALOGUE_UNSIGNED = 1,
    CATALOGUE_TEXT     = 2,     /* a char array, written as a quoted string */
    CATALOGUE_STRUCT   = 3,     /* a value type; as a type row, the struct itself */
    CATALOGUE_ARRAY    = 4,     /* an array of integers */
};

struct catalogue_field {
    const char *name;
    const char *type;           /* element type as written */
    uint32_t    offset;         /* offsetof, from the compiler */
    uint32_t    size;           /* sizeof the whole field */
    uint32_t    element;        /* sizeof one element, for arrays; 0 otherwise */
    int         kind;           /* enum catalogue_kind */
};

struct catalogue_type {
    const char                   *name;      /* "struct text", "int64_t" */
    uint32_t                      size;
    int                           kind;      /* CATALOGUE_STRUCT, or an integer kind */
    const struct catalogue_field *fields;
    int                           n_fields;
    int                         (*order)(const void *a, const void *b);
};

struct catalogue_row {
    const char       *address;  /* "src/boxes/062-arithmetic.c:add" */
    const struct box *box;
};

struct embedded_map {
    const char *path;           /* where it was read from, so its addresses resolve as from the file */
    const char *text;
};

/* What one unit compiled on the device hands the loader (issue 409): the
 * generator writes a function answering this as the unit's only public
 * name (GEN_UNIT_ENTRY, 060-generator.h). The rows' addresses are already
 * "file:function", with the file the source was saved to. */
struct catalogue_unit {
    const struct catalogue_row  *rows;
    int                          n_rows;
    const struct catalogue_type *types;
    int                          n_types;
};

/* Written by the generator. */
extern const struct catalogue_row  catalogue_rows[];
extern const int                   catalogue_row_count;
extern const struct catalogue_type catalogue_types[];
extern const int                   catalogue_type_count;
extern const struct embedded_map   embedded_maps[];
extern const int                   embedded_map_count;

/* A box by its full address, or NULL. When a file has been compiled more
 * than once (somebody saving a box again), the newest row with the address
 * answers; the older ones keep their rows and stay placed wherever they
 * already are (411 moves the arrows; 410 reclaims what nothing places). */
const struct box *catalogue_box(const char *address);

/* Add a box compiled after startup, as unit -1 (a box made by hand).
 * Refuses an address the image's own rows hold. Answers 0 or a negative
 * engine error. */
int catalogue_add(const char *address, const struct box *box);

/* Add every row of a unit compiled on the device, all appearing at once,
 * and a copy of each of its types the catalogue does not already know by
 * name (a name the catalogue knows keeps its first row: types are compared
 * by width, never by layout, issue 303). `unit` is the compile pipeline's
 * number for it (086-compile.h). Refuses — adding nothing — a row whose
 * address the image's own rows hold. Answers 0 or a negative engine error. */
int catalogue_add_unit(const struct catalogue_unit *u, int unit);

/* Every row, built-in first, for listings and "did you mean". */
int         catalogue_count(void);
const char *catalogue_address(int index);
const struct box *catalogue_box_at(int index);
/* The compile pipeline's unit a row came from: -1 for the image's own rows
 * and for boxes added by hand. */
int         catalogue_unit_at(int index);

/* A value type or integer type by the name a box's parameter uses: the
 * image's own first, then those units compiled on the device brought. */
const struct catalogue_type *catalogue_type_named(const char *name);

/* An embedded map by path, or NULL. */
const char *catalogue_embedded_map(const char *path);

#endif
