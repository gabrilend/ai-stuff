/*
 * 060-generator.h — reading box sources, and writing what the engine
 * needs to call them (issues 302, 303).
 *
 * General description: a box is an ordinary C function in a file under
 * src/boxes/. The engine can only call a function whose signature it
 * knows, and it cannot learn one at run time — so this program reads the
 * box sources and writes C: one small calling adapter per box that
 * unpacks a task's bytes into real arguments, a record per box, a table
 * of every box keyed by its address ("src/boxes/062-arithmetic.c:add"),
 * and a field table per value type so text like { 5, "hey" } can become
 * bytes. Every size and offset in what it writes is an expression the C
 * compiler works out; the generator never guesses a number.
 *
 * It depends on nothing else in the engine — not even the engine's own
 * copying routines — because the build runs it before the engine exists,
 * and the device will run it (phase 4) to add a box somebody just wrote.
 * All its memory comes from one function the caller supplies.
 *
 * Reading and writing are separate: gen_read produces a description,
 * gen_describe prints it for a person, gen_emit turns it into C.
 */
#ifndef SOREN_GENERATOR_H
#define SOREN_GENERATOR_H

#include <stddef.h>

/* Memory: grow (or make, when `old` is NULL) a block to `size` bytes,
 * keeping its contents. The generator never frees anything one piece at
 * a time; the caller drops the whole arena when done. */
struct gen_memory {
    void *(*grow)(void *ctx, void *old, size_t old_size, size_t size);
    void  *ctx;
};

/* Text the generator writes into; it grows through gen_memory. */
struct gen_text {
    char  *data;
    size_t length;
    size_t capacity;
};

struct gen_source {
    const char *path;          /* as the address will name it: "src/boxes/062-arithmetic.c" */
    const char *include_path;  /* how the emitted C should #include it (often an absolute path) */
    const char *text;
    size_t      length;
};

enum gen_field_kind {
    GEN_FIELD_SIGNED,          /* a signed integer of `size` bytes */
    GEN_FIELD_UNSIGNED,        /* an unsigned integer */
    GEN_FIELD_TEXT,            /* a char array: written in a map as a quoted string */
    GEN_FIELD_STRUCT,          /* a nested value type */
    GEN_FIELD_ARRAY,           /* an array of integers */
};

struct gen_field {
    char *name;
    char *type;                /* the element type as written */
    char *count;               /* array length expression, or NULL */
    int   kind;                /* enum gen_field_kind */
    int   line;
};

struct gen_struct {
    char             *name;    /* "text" for "struct text" */
    struct gen_field *fields;
    int               n_fields;
    char             *compare; /* the ordering function's name, or NULL */
    int               source;  /* which source it came from */
    int               line;
};

struct gen_param {
    char *type;
    char *name;
};

struct gen_box {
    char             *name;    /* the function's name as written */
    char             *returns; /* its return type as written; "void" for a sink */
    struct gen_param *params;
    int               n_params;
    int               source;
    int               line;
};

struct gen_helper {
    char *name;
    int   source;
};

struct gen_description {
    struct gen_box    *boxes;
    int                n_boxes;
    struct gen_struct *structs;
    int                n_structs;
    struct gen_helper *helpers;     /* functions kept private to their file */
    int                n_helpers;
    int                n_errors;
};

/* Read every source. Answers 0, or the number of problems found — each
 * one written into `errors` as "path:line: what is wrong", one per line,
 * all of them, not just the first. */
int gen_read(const struct gen_source *sources, int n_sources, struct gen_memory *memory,
             struct gen_description *out, struct gen_text *errors);

/* What the reader saw, for a person diagnosing a build. */
void gen_describe(const struct gen_source *sources, const struct gen_description *d,
                  struct gen_memory *memory, struct gen_text *out);

/* The C: includes, adapters, box records, field tables, the catalogue. */
void gen_emit(const struct gen_source *sources, int n_sources, const struct gen_description *d,
              struct gen_memory *memory, struct gen_text *out);

/* A header naming every box record, for C code that places boxes directly. */
void gen_emit_header(const struct gen_source *sources, const struct gen_description *d,
                     struct gen_memory *memory, struct gen_text *out);

/* Embed map files as C string constants for a kernel that has no
 * filesystem yet (phase 3 before phase 4). */
void gen_emit_maps(const struct gen_source *maps, int n_maps, struct gen_memory *memory,
                   struct gen_text *out);

void gen_append(struct gen_memory *memory, struct gen_text *t, const char *s);

#endif
