/*
 * 070-catalogue.c — looking boxes and types up, and adding boxes late.
 *
 * General description: the generated rows are searched first, then the
 * rows added at run time. Added rows and added types live in tables that
 * grow by shelves and never move (086-shelves.h); the count of added rows
 * only grows and is published after the rows it reveals are written, so a
 * reader never sees a half-written row and looking up takes no lock.
 *
 * A file compiled again adds rows with the same addresses as before. They
 * do not replace the older rows — a station may be placed on an older one
 * right now, and its ports were sized to that box — so looking an address
 * up searches the added rows newest first.
 *
 * A retired row (410) stays where it is, so no index moves, but answers no
 * address and no box: nothing new can be placed from code that is about
 * to be freed.
 *
 * A type a unit brings is copied into the catalogue's own memory, name and
 * fields and all, so the row outlives the unit's code when 410 frees it.
 * The copy leaves the ordering out: nothing reads a type row's ordering
 * (a comparator uses the box record's, 037-build.c), and an ordering is
 * code that 410 may free.
 */
#include "031-engine-internal.h"
#include "070-catalogue.h"
#include "086-shelves.h"

#define ADDRESS_BYTES 160

struct added_row {
    char              address[ADDRESS_BYTES];
    const struct box *box;
    int               unit;
    int               retired;      /* 410: its unit's code may be freed; the row answers nothing */
};

static struct shelves added_rows = SHELVES_INIT(struct added_row, 64);
static struct shelves added_types = SHELVES_INIT(struct catalogue_type, 64);

/* {{{ catalogue_count */
int catalogue_count(void)
{
    return catalogue_row_count + shelves_count(&added_rows);
}
/* }}} */

/* {{{ catalogue_address */
const char *catalogue_address(int index)
{
    if (index < catalogue_row_count) {
        return catalogue_rows[index].address;
    }
    struct added_row *row = shelves_at(&added_rows, index - catalogue_row_count);
    return atomic_load_acquire(&row->retired) ? "" : row->address;
}
/* }}} */

/* {{{ catalogue_box_at */
const struct box *catalogue_box_at(int index)
{
    if (index < catalogue_row_count) {
        return catalogue_rows[index].box;
    }
    struct added_row *row = shelves_at(&added_rows, index - catalogue_row_count);
    return atomic_load_acquire(&row->retired) ? (const struct box *)0 : row->box;
}
/* }}} */

/* {{{ catalogue_unit_at */
int catalogue_unit_at(int index)
{
    if (index < catalogue_row_count) {
        return -1;
    }
    return ((struct added_row *)shelves_at(&added_rows, index - catalogue_row_count))->unit;
}
/* }}} */

/* {{{ built_in */
static const struct box *built_in(const char *address)
{
    for (int i = 0; i < catalogue_row_count; i++) {
        if (text_equal(catalogue_rows[i].address, address)) {
            return catalogue_rows[i].box;
        }
    }
    return (const struct box *)0;
}
/* }}} */

/* {{{ catalogue_box */
const struct box *catalogue_box(const char *address)
{
    const struct box *b = built_in(address);
    if (b) {
        return b;
    }
    for (int32_t i = shelves_count(&added_rows) - 1; i >= 0; i--) {
        struct added_row *row = shelves_at(&added_rows, i);
        if (!atomic_load_acquire(&row->retired) && text_equal(row->address, address)) {
            return row->box;
        }
    }
    return (const struct box *)0;
}
/* }}} */

/* {{{ type_named */
static const struct catalogue_type *type_named(const char *name)
{
    for (int i = 0; i < catalogue_type_count; i++) {
        if (text_equal(catalogue_types[i].name, name)) {
            return &catalogue_types[i];
        }
    }
    int32_t n = shelves_count(&added_types);
    for (int32_t i = 0; i < n; i++) {
        const struct catalogue_type *t = shelves_at(&added_types, i);
        if (text_equal(t->name, name)) {
            return t;
        }
    }
    return (const struct catalogue_type *)0;
}
/* }}} */

/* {{{ catalogue_type_named */
const struct catalogue_type *catalogue_type_named(const char *name)
{
    return type_named(name);
}
/* }}} */

/* {{{ copy_text */
static const char *copy_text(char **into, const char *s)
{
    size_t n = text_length(s) + 1;
    char *at = *into;
    bytes_copy(at, s, n);
    *into += n;
    return at;
}
/* }}} */

/* {{{ copy_type */
/* One block holding the field table and every string the row names. */
static int copy_type(struct core_ctx *c, const struct catalogue_type *from, struct catalogue_type *to)
{
    size_t bytes = sizeof(struct catalogue_field) * (size_t)from->n_fields + text_length(from->name) + 1;
    for (int f = 0; f < from->n_fields; f++) {
        bytes += text_length(from->fields[f].name) + 1 + text_length(from->fields[f].type) + 1;
    }
    uint8_t *block = block_alloc(c->number, bytes);
    if (!block) {
        return ENGINE_NO_MEMORY;
    }
    struct catalogue_field *fields = (struct catalogue_field *)block;
    char *strings = (char *)(block + sizeof(struct catalogue_field) * (size_t)from->n_fields);
    for (int f = 0; f < from->n_fields; f++) {
        fields[f] = from->fields[f];
        fields[f].name = copy_text(&strings, from->fields[f].name);
        fields[f].type = copy_text(&strings, from->fields[f].type);
    }
    to->name     = copy_text(&strings, from->name);
    to->size     = from->size;
    to->kind     = from->kind;
    to->fields   = from->n_fields ? fields : (const struct catalogue_field *)0;
    to->n_fields = from->n_fields;
    to->order    = 0;
    return ENGINE_OK;
}
/* }}} */

/* {{{ add_rows */
/* Under the rows' lock: every row written, then one count revealing them
 * all. A row whose address is the image's own is refused before anything
 * is written. */
static int add_rows(struct core_ctx *c, const struct catalogue_row *rows, int n, int unit)
{
    for (int i = 0; i < n; i++) {
        if (text_length(rows[i].address) >= ADDRESS_BYTES) {
            return ENGINE_TOO_BIG;
        }
        if (built_in(rows[i].address)) {
            return ENGINE_PLACE_BUSY;
        }
    }
    int32_t first = added_rows.count;
    if (first + n > shelves_capacity(&added_rows)) {
        return ENGINE_FULL;
    }
    for (int i = 0; i < n; i++) {
        struct added_row *row = shelves_place(&added_rows, c->number, first + i);
        if (!row) {
            return ENGINE_NO_MEMORY;
        }
        bytes_copy(row->address, rows[i].address, text_length(rows[i].address) + 1);
        row->box     = rows[i].box;
        row->unit    = unit;
        row->retired = 0;
    }
    shelves_publish(&added_rows, first + n);
    return ENGINE_OK;
}
/* }}} */

/* {{{ catalogue_add */
int catalogue_add(const char *address, const struct box *box)
{
    struct catalogue_row row = { address, box };
    struct core_ctx *c = engine_enter();
    spin_lock(&added_rows.lock);
    int answer = add_rows(c, &row, 1, -1);
    spin_unlock(&added_rows.lock);
    engine_leave(c);
    return answer;
}
/* }}} */

/* {{{ catalogue_add_unit */
int catalogue_add_unit(const struct catalogue_unit *u, int unit)
{
    struct core_ctx *c = engine_enter();
    spin_lock(&added_rows.lock);
    int answer = add_rows(c, u->rows, u->n_rows, unit);
    spin_unlock(&added_rows.lock);
    if (answer == ENGINE_OK) {
        /* The types after the rows: a type the catalogue already knows by
         * name keeps its row; one it cannot copy for want of memory is
         * said and left out, since every box is placeable without it and
         * only a fixed value written in a map needs it. */
        spin_lock(&added_types.lock);
        for (int i = 0; i < u->n_types; i++) {
            if (type_named(u->types[i].name)) {
                continue;
            }
            int32_t at = added_types.count;
            struct catalogue_type *t = shelves_place(&added_types, c->number, at);
            if (!t || copy_type(c, &u->types[i], t) != ENGINE_OK) {
                say_line("catalogue: no room for type %s; a map cannot write a fixed value of it", u->types[i].name);
                continue;
            }
            shelves_publish(&added_types, at + 1);
        }
        spin_unlock(&added_types.lock);
    }
    engine_leave(c);
    return answer;
}
/* }}} */

/* {{{ catalogue_retire_unit */
int catalogue_retire_unit(int unit)
{
    int retired = 0;
    int32_t n = shelves_count(&added_rows);
    for (int32_t i = 0; i < n; i++) {
        struct added_row *row = shelves_at(&added_rows, i);
        if (row->unit == unit && unit >= 0 && !atomic_load_acquire(&row->retired)) {
            atomic_store_release(&row->retired, 1);
            retired++;
        }
    }
    return retired;
}
/* }}} */

/* {{{ catalogue_embedded_map */
const char *catalogue_embedded_map(const char *path)
{
    for (int i = 0; i < embedded_map_count; i++) {
        if (text_equal(embedded_maps[i].path, path)) {
            return embedded_maps[i].text;
        }
    }
    return (const char *)0;
}
/* }}} */
