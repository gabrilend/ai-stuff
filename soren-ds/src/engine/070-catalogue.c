/*
 * 070-catalogue.c — looking boxes and types up, and adding boxes late.
 *
 * General description: the generated rows are searched first, then the
 * rows added at run time. Added rows live in shelves of 64 that are
 * allocated once and never move; the count of added rows only grows and
 * is published after the row is written, so a reader never sees a half-
 * written row. Adding takes a spin lock; looking up takes none.
 */
#include "031-engine-internal.h"
#include "070-catalogue.h"

#define ADDED_PER_SHELF 64
#define ADDED_SHELVES 64

struct added_row {
    char              address[160];
    const struct box *box;
};

static spin_lock_t       added_lock = SPIN_LOCK_INIT;
static struct added_row *added_shelves[ADDED_SHELVES];
static int32_t           added_count;

/* {{{ added_at */
static struct added_row *added_at(int i)
{
    return &added_shelves[i / ADDED_PER_SHELF][i % ADDED_PER_SHELF];
}
/* }}} */

/* {{{ catalogue_count */
int catalogue_count(void)
{
    return catalogue_row_count + atomic_load_acquire(&added_count);
}
/* }}} */

/* {{{ catalogue_address */
const char *catalogue_address(int index)
{
    if (index < catalogue_row_count) {
        return catalogue_rows[index].address;
    }
    return added_at(index - catalogue_row_count)->address;
}
/* }}} */

/* {{{ catalogue_box_at */
const struct box *catalogue_box_at(int index)
{
    if (index < catalogue_row_count) {
        return catalogue_rows[index].box;
    }
    return added_at(index - catalogue_row_count)->box;
}
/* }}} */

/* {{{ catalogue_box */
const struct box *catalogue_box(const char *address)
{
    int n = catalogue_count();
    for (int i = 0; i < n; i++) {
        if (text_equal(catalogue_address(i), address)) {
            return catalogue_box_at(i);
        }
    }
    return (const struct box *)0;
}
/* }}} */

/* {{{ catalogue_add */
int catalogue_add(const char *address, const struct box *box)
{
    if (text_length(address) >= sizeof(((struct added_row *)0)->address)) {
        return ENGINE_TOO_BIG;
    }
    struct core_ctx *c = engine_enter();
    spin_lock(&added_lock);
    int answer = ENGINE_OK;
    if (catalogue_box(address)) {
        answer = ENGINE_PLACE_BUSY;
        goto done;
    }
    int32_t i = added_count;
    if (i >= ADDED_PER_SHELF * ADDED_SHELVES) {
        answer = ENGINE_FULL;
        goto done;
    }
    if (!added_shelves[i / ADDED_PER_SHELF]) {
        added_shelves[i / ADDED_PER_SHELF] = block_alloc_zero(c->number, sizeof(struct added_row) * ADDED_PER_SHELF);
        if (!added_shelves[i / ADDED_PER_SHELF]) {
            answer = ENGINE_NO_MEMORY;
            goto done;
        }
    }
    struct added_row *row = added_at(i);
    bytes_copy(row->address, address, text_length(address) + 1);
    row->box = box;
    /* Build the row, then publish the count that reveals it. */
    atomic_store_release(&added_count, i + 1);
done:
    spin_unlock(&added_lock);
    engine_leave(c);
    return answer;
}
/* }}} */

/* {{{ catalogue_type_named */
const struct catalogue_type *catalogue_type_named(const char *name)
{
    for (int i = 0; i < catalogue_type_count; i++) {
        if (text_equal(catalogue_types[i].name, name)) {
            return &catalogue_types[i];
        }
    }
    return (const struct catalogue_type *)0;
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
