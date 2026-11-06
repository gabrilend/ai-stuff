/*
 * 087-compile.c — compiling a box on the running device (issue 409).
 *
 * General description: three steps, and the engine is held only for the
 * first and the last, because the middle one is a compiler and may take
 * a long time:
 *
 *   read    the generator reads the source and writes the unit's C, in
 *           memory the engine lends (held: the allocator is per owner)
 *   compile the platform's compiler turns that C into loaded code, or
 *           says why not in its own words (not held)
 *   add     the source is copied and recorded as a unit, and the unit's
 *           rows go into the catalogue all at once (held)
 *
 * A failure at any step leaves nothing behind: code that loaded is
 * unloaded again, memory is given back, and no row appears.
 */
#include "031-engine-internal.h"
#include "060-generator.h"
#include "070-catalogue.h"
#include "086-shelves.h"
#include "087-compile.h"

/* {{{ the units */
struct unit {
    char     path[COMPILE_PATH_BYTES];
    int32_t  state;
    int32_t  boxes;
    uint64_t when_ns;
    char    *source;                /* a copy, in the engine's memory */
    size_t   length;
    void    *handle;                /* the platform's, for unloading (410) */
};

static struct shelves units = SHELVES_INIT(struct unit, 64);
/* }}} */

/* {{{ the generator's memory */
/* Every piece the generator is lent is on one list, so all of them go
 * back at the end; growing a piece hands the old one back at once, as
 * the host tool's realloc does. */
struct piece {
    struct piece *next;
    struct piece *prev;
    uint64_t      pad[2];           /* keeps what follows 16-byte aligned */
};

struct arena {
    int          owner;
    struct piece list;
};

/* {{{ arena_grow */
static void *arena_grow(void *ctx, void *old, size_t old_size, size_t size)
{
    struct arena *a = ctx;
    struct piece *p = block_alloc(a->owner, sizeof *p + size);
    if (!p) {
        /* The generator has no way to hear "no": it was written to be
         * lent memory by a laptop. Running the allocator dry is reported
         * by the allocator itself; there is nothing safe to do but stop. */
        platform_halt("compile: the allocator ran dry inside the generator");
    }
    p->next = a->list.next;
    p->prev = &a->list;
    a->list.next->prev = p;
    a->list.next = p;
    if (old) {
        struct piece *o = (struct piece *)old - 1;
        bytes_copy(p + 1, old, old_size < size ? old_size : size);
        o->prev->next = o->next;
        o->next->prev = o->prev;
        block_free(a->owner, o);
    }
    return p + 1;
}
/* }}} */

/* {{{ arena_drop */
static void arena_drop(struct arena *a)
{
    struct piece *p = a->list.next;
    while (p != &a->list) {
        struct piece *next = p->next;
        block_free(a->owner, p);
        p = next;
    }
    a->list.next = a->list.prev = &a->list;
}
/* }}} */
/* }}} */

/* {{{ path_ok */
/* A file a box address can name: the map reader splits an address at its
 * last ':', and the unit's C writes the path inside a #line mark. */
static int path_ok(const char *path)
{
    size_t n = text_length(path);
    if (n < 3 || n >= COMPILE_PATH_BYTES || path[n - 2] != '.' || path[n - 1] != 'c') {
        return 0;
    }
    for (size_t i = 0; i < n; i++) {
        char c = path[i];
        if (c == ':' || c == '"' || c == '\\' || c == '\n' || c == '\r') {
            return 0;
        }
    }
    return 1;
}
/* }}} */

/* {{{ say */
static void say(struct compile_report *report, const char *fmt, const char *a, const char *b)
{
    text_format(report->text, sizeof report->text, fmt, a, b);
}
/* }}} */

/* {{{ copy_words */
/* As much of `words` as fits, whole lines where it can, so the report is
 * the generator's or compiler's own text and never a summary of it. */
static void copy_words(struct compile_report *report, const char *words, size_t n)
{
    size_t room = sizeof report->text - 1;
    if (n > room) {
        n = room;
        while (n > 0 && words[n - 1] != '\n') n--;
        if (n == 0) n = room;
    }
    bytes_copy(report->text, words, n);
    report->text[n] = 0;
}
/* }}} */

/* {{{ compile_box_source */
int compile_box_source(const char *path, const char *text, size_t length, struct compile_report *report)
{
    report->text[0] = 0;
    if (!path_ok(path)) {
        say(report, "%s cannot be a box's file: a path ending in .c, under %s characters, with no ':', '\"' or '\\'",
            path, "128");
        return COMPILE_BAD_PATH;
    }

    /* {{{ read: the generator, holding the engine for its memory */
    struct core_ctx *c = engine_enter();
    struct arena a = { c->number, { 0, 0, { 0, 0 } } };
    a.list.next = a.list.prev = &a.list;
    struct gen_memory memory = { arena_grow, &a };
    struct gen_source source = { path, (const char *)0, text, length };
    struct gen_description d;
    bytes_zero(&d, sizeof d);
    struct gen_text errors = { 0, 0, 0 };
    struct gen_text unit_c = { 0, 0, 0 };
    int answer = 0;
    if (gen_read(&source, 1, &memory, &d, &errors) != 0) {
        copy_words(report, errors.data, errors.length);
        answer = COMPILE_UNREADABLE;
    } else if (d.n_boxes == 0) {
        say(report, "%s defines no box: a box is a function that is not static%s", path, "");
        answer = COMPILE_NO_BOXES;
    } else {
        for (int i = 0; i < d.n_boxes && !answer; i++) {
            char address[COMPILE_PATH_BYTES + 64];
            text_format(address, sizeof address, "%s:%s", path, d.boxes[i].name);
            for (int r = 0; r < catalogue_row_count; r++) {
                if (text_equal(catalogue_rows[r].address, address)) {
                    say(report, "%s is a box the device was built with; a box compiled here needs a file of its own%s",
                        address, "");
                    answer = COMPILE_TAKEN;
                    break;
                }
            }
        }
        if (!answer) {
            gen_emit_unit(&source, 1, &d, &memory, &unit_c);
        }
    }
    if (answer) {
        arena_drop(&a);
        engine_leave(c);
        return answer;
    }
    engine_leave(c);
    /* }}} */

    /* {{{ compile: nothing held */
    void *entry = (void *)0;
    void *handle = platform_compile(unit_c.data, unit_c.length, GEN_UNIT_ENTRY, &entry, report->text, sizeof report->text);
    const struct catalogue_unit *u = handle && entry ? ((const struct catalogue_unit *(*)(void))entry)() : 0;
    if (handle && (!u || u->n_rows != d.n_boxes)) {
        say(report, "%s compiled, but its unit did not describe the boxes the generator read%s", path, "");
        platform_unload(handle);
        handle = (void *)0;
    }
    /* }}} */

    /* {{{ add: the source kept, the unit recorded, the rows all at once */
    c = engine_enter();
    arena_drop(&a);
    if (!handle) {
        engine_leave(c);
        return COMPILE_FAILED;
    }
    char *copy = block_alloc(c->number, length ? length : 1);
    if (!copy) {
        platform_unload(handle);
        engine_leave(c);
        say(report, "no memory to keep the source of %s%s", path, "");
        return ENGINE_NO_MEMORY;
    }
    bytes_copy(copy, text, length);
    spin_lock(&units.lock);
    int32_t number = units.count;
    struct unit *rec = shelves_place(&units, c->number, number);
    int added = rec ? catalogue_add_unit(u, number) : ENGINE_FULL;
    if (added == ENGINE_OK) {
        bytes_copy(rec->path, path, text_length(path) + 1);
        rec->state   = UNIT_LOADED;
        rec->boxes   = u->n_rows;
        rec->when_ns = platform_now_ns();
        rec->source  = copy;
        rec->length  = length;
        rec->handle  = handle;
        shelves_publish(&units, number + 1);
    }
    spin_unlock(&units.lock);
    if (added != ENGINE_OK) {
        block_free(c->number, copy);
        platform_unload(handle);
        engine_leave(c);
        say(report, "%s: the catalogue would not take its rows (%s)", path, engine_error_text(added));
        return added == ENGINE_FULL ? COMPILE_FULL : added == ENGINE_PLACE_BUSY ? COMPILE_TAKEN : added;
    }
    engine_leave(c);
    /* }}} */
    return number;
}
/* }}} */

/* {{{ compile_source */
const char *compile_source(const char *path_or_address, size_t *length)
{
    char path[COMPILE_PATH_BYTES];
    size_t n = text_length(path_or_address);
    size_t colon = n;
    for (size_t i = 0; i < n; i++) if (path_or_address[i] == ':') colon = i;
    if (colon >= sizeof path) {
        return (const char *)0;
    }
    bytes_copy(path, path_or_address, colon);
    path[colon] = 0;
    for (int32_t i = shelves_count(&units) - 1; i >= 0; i--) {
        struct unit *u = shelves_at(&units, i);
        if (u->state == UNIT_LOADED && text_equal(u->path, path)) {
            *length = u->length;
            return u->source;
        }
    }
    return (const char *)0;
}
/* }}} */

/* {{{ compile_unit_count */
int compile_unit_count(void)
{
    return shelves_count(&units);
}
/* }}} */

/* {{{ compile_unit_facts */
int compile_unit_facts(int unit, struct compile_unit_facts *out)
{
    if (unit < 0 || unit >= shelves_count(&units)) {
        return ENGINE_NO_BOX;
    }
    struct unit *u = shelves_at(&units, unit);
    out->path    = u->path;
    out->state   = u->state;
    out->boxes   = u->boxes;
    out->when_ns = u->when_ns;
    out->source  = u->source;
    out->length  = u->length;
    return ENGINE_OK;
}
/* }}} */

/* {{{ compile_error_text */
const char *compile_error_text(int error)
{
    switch (error) {
    case COMPILE_BAD_PATH:   return "not a file a box address can name";
    case COMPILE_UNREADABLE: return "the generator could not read the source";
    case COMPILE_NO_BOXES:   return "the source defines no box";
    case COMPILE_FAILED:     return "the compiler refused it";
    case COMPILE_TAKEN:      return "a box the device was built with has that address";
    case COMPILE_FULL:       return "no room for another unit";
    default:                 return engine_error_text(error);
    }
}
/* }}} */
