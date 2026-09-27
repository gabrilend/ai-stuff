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

/* Written by the generator. */
extern const struct catalogue_row  catalogue_rows[];
extern const int                   catalogue_row_count;
extern const struct catalogue_type catalogue_types[];
extern const int                   catalogue_type_count;
extern const struct embedded_map   embedded_maps[];
extern const int                   embedded_map_count;

/* A box by its full address, or NULL. */
const struct box *catalogue_box(const char *address);

/* Add a box compiled after startup (phase 4). Refuses an address already
 * present. Answers 0 or a negative engine error. */
int catalogue_add(const char *address, const struct box *box);

/* Every row, built-in first, for listings and "did you mean". */
int         catalogue_count(void);
const char *catalogue_address(int index);
const struct box *catalogue_box_at(int index);

/* A value type or integer type by the name a box's parameter uses. */
const struct catalogue_type *catalogue_type_named(const char *name);

/* An embedded map by path, or NULL. */
const char *catalogue_embedded_map(const char *path);

#endif
