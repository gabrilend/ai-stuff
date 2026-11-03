/*
 * 128-vertex-grid.c — the modeller's grid of placed vertices (issue 1001).
 *
 * General description: each grid is a dense array of vertices and a hash
 * table of slots, each slot holding the index of a vertex in the array or
 * EMPTY. The table is open addressing with linear probing, kept at most
 * half full, so a lookup is a probe or two; a removal shifts the entries
 * after it back (no tombstones, so a table that sees many placements and
 * removals does not slowly fill with dead slots), and then the last
 * vertex of the array moves into the removed one's place so the array
 * stays dense.
 *
 * Both arrays start small and double when the array is full, up to the
 * whole cube (32768 vertices: 384 KB of vertices and 128 KB of slots).
 * They never shrink while the grid lives. Their memory is the app's,
 * through 127, the STAND-IN for 902.
 */
#include <stdint.h>
#include <stddef.h>
#include "../engine/027-primitives.h"
#include "../engine/127-app-memory.h"
#include "128-vertex-grid.h"

#define EMPTY            0xFFFFu
#define FIRST_CAPACITY   16

struct grid {
    spin_lock_t    lock;
    int            claimed;            /* taken from the table, under table_lock */
    int            in_use;             /* ready for calls, under its own lock */
    int            app;
    struct vertex *vertices;
    int            count;
    int            capacity;           /* vertices the array holds */
    uint16_t      *slots;
    int            slot_bits;          /* the table has 1 << slot_bits slots: twice capacity */
};

static struct grid grids[VERTEX_GRID_MAX];
static spin_lock_t table_lock = SPIN_LOCK_INIT;

/* {{{ sizes */
static size_t vertex_bytes(int capacity)
{
    return (size_t)capacity * sizeof(struct vertex);
}

static size_t slot_bytes(int bits)
{
    return ((size_t)1 << bits) * sizeof(uint16_t);
}

static int bits_for(int capacity)
{
    int bits = 0;
    while ((1 << bits) < capacity * 2) {
        bits++;
    }
    return bits;
}
/* }}} */

/* {{{ home */
/* Where a key's probe starts: a multiplicative hash, whose top bits are
 * well mixed even for keys that differ only in their low bits. */
static uint32_t home(const struct grid *g, uint32_t key)
{
    return (key * 2654435761u) >> (32 - g->slot_bits);
}

static uint32_t key_of(const struct vertex *v)
{
    return vertex_cell_key(v->x, v->y, v->z);
}
/* }}} */

/* {{{ probe */
/* The slot holding `key`'s vertex (answers 1), or the empty slot where it
 * would go (answers 0). Never loops forever: the table is never full. */
static int probe(const struct grid *g, uint32_t key, uint32_t *slot)
{
    uint32_t mask = ((uint32_t)1 << g->slot_bits) - 1;
    uint32_t i = home(g, key);
    for (;;) {
        uint16_t s = g->slots[i];
        if (s == EMPTY) {
            *slot = i;
            return 0;
        }
        if (key_of(&g->vertices[s]) == key) {
            *slot = i;
            return 1;
        }
        i = (i + 1) & mask;
    }
}
/* }}} */

/* {{{ fill_slots */
/* Point a fresh table (all EMPTY) at every vertex in the array. */
static void fill_slots(struct grid *g)
{
    size_t n = (size_t)1 << g->slot_bits;
    for (size_t i = 0; i < n; i++) {
        g->slots[i] = EMPTY;
    }
    for (int v = 0; v < g->count; v++) {
        uint32_t slot;
        probe(g, key_of(&g->vertices[v]), &slot);
        g->slots[slot] = (uint16_t)v;
    }
}
/* }}} */

/* {{{ grow */
/* Double both arrays. Called holding the grid's lock. On failure the grid
 * is exactly as it was. */
static int grow(struct grid *g)
{
    int capacity = g->capacity * 2;
    if (capacity > VERTEX_GRID_CELLS) {
        return VERTEX_NO_MEMORY;                     /* cannot happen: a full cube is every cell */
    }
    int bits = bits_for(capacity);
    struct vertex *vertices = app_memory_alloc(g->app, vertex_bytes(capacity));
    uint16_t *slots = vertices ? app_memory_alloc(g->app, slot_bytes(bits)) : NULL;
    if (!slots) {
        app_memory_free(g->app, vertices, vertex_bytes(capacity));
        return VERTEX_NO_MEMORY;
    }
    bytes_copy(vertices, g->vertices, vertex_bytes(g->count));
    app_memory_free(g->app, g->vertices, vertex_bytes(g->capacity));
    app_memory_free(g->app, g->slots, slot_bytes(g->slot_bits));
    g->vertices = vertices;
    g->slots = slots;
    g->capacity = capacity;
    g->slot_bits = bits;
    fill_slots(g);
    return 0;
}
/* }}} */

/* {{{ enter */
/* The grid, locked, if it is in use; NULL (and unlocked) if not. */
static struct grid *enter(int grid)
{
    if (grid < 0 || grid >= VERTEX_GRID_MAX) {
        return NULL;
    }
    struct grid *g = &grids[grid];
    spin_lock(&g->lock);
    if (!g->in_use) {
        spin_unlock(&g->lock);
        return NULL;
    }
    return g;
}

static int outside(int x, int y, int z)
{
    return x < 0 || y < 0 || z < 0 || x >= VERTEX_GRID_SIDE || y >= VERTEX_GRID_SIDE || z >= VERTEX_GRID_SIDE;
}
/* }}} */

/* {{{ vertex_grid_alloc */
int vertex_grid_alloc(int app)
{
    int grid = -1;
    spin_lock(&table_lock);
    for (int i = 0; i < VERTEX_GRID_MAX; i++) {
        if (!grids[i].claimed) {
            grids[i].claimed = 1;
            grid = i;
            break;
        }
    }
    spin_unlock(&table_lock);
    if (grid < 0) {
        return VERTEX_NO_GRID;
    }
    int bits = bits_for(FIRST_CAPACITY);
    struct vertex *vertices = app_memory_alloc(app, vertex_bytes(FIRST_CAPACITY));
    uint16_t *slots = vertices ? app_memory_alloc(app, slot_bytes(bits)) : NULL;
    if (!slots) {
        app_memory_free(app, vertices, vertex_bytes(FIRST_CAPACITY));
        spin_lock(&table_lock);
        grids[grid].claimed = 0;
        spin_unlock(&table_lock);
        return VERTEX_NO_MEMORY;
    }
    struct grid *g = &grids[grid];
    spin_lock(&g->lock);
    g->app = app;
    g->vertices = vertices;
    g->count = 0;
    g->capacity = FIRST_CAPACITY;
    g->slots = slots;
    g->slot_bits = bits;
    fill_slots(g);
    g->in_use = 1;
    spin_unlock(&g->lock);
    return grid;
}
/* }}} */

/* {{{ vertex_grid_free */
int vertex_grid_free(int grid)
{
    struct grid *g = enter(grid);
    if (!g) {
        return VERTEX_NO_GRID;
    }
    g->in_use = 0;
    int app = g->app;
    struct vertex *vertices = g->vertices;
    uint16_t *slots = g->slots;
    size_t vb = vertex_bytes(g->capacity), sb = slot_bytes(g->slot_bits);
    g->vertices = NULL;
    g->slots = NULL;
    g->count = g->capacity = 0;
    spin_unlock(&g->lock);
    app_memory_free(app, vertices, vb);
    app_memory_free(app, slots, sb);
    spin_lock(&table_lock);
    g->claimed = 0;
    spin_unlock(&table_lock);
    return 0;
}
/* }}} */

/* {{{ vertex_grid_place */
int vertex_grid_place(int grid, int x, int y, int z)
{
    struct grid *g = enter(grid);
    if (!g) {
        return VERTEX_NO_GRID;
    }
    if (outside(x, y, z)) {
        spin_unlock(&g->lock);
        return VERTEX_OUTSIDE;
    }
    uint32_t key = vertex_cell_key(x, y, z), slot;
    if (probe(g, key, &slot)) {
        spin_unlock(&g->lock);
        return VERTEX_UNCHANGED;
    }
    if (g->count == g->capacity) {
        int grew = grow(g);
        if (grew < 0) {
            spin_unlock(&g->lock);
            return grew;
        }
        probe(g, key, &slot);                        /* the table moved */
    }
    struct vertex *v = &g->vertices[g->count];
    v->x = (uint8_t)x;
    v->y = (uint8_t)y;
    v->z = (uint8_t)z;
    v->unused = 0;
    v->first_face = VERTEX_NO_FACE;
    v->face_count = 0;
    g->slots[slot] = (uint16_t)g->count;
    g->count++;
    spin_unlock(&g->lock);
    return VERTEX_PLACED;
}
/* }}} */

/* {{{ vertex_grid_remove */
int vertex_grid_remove(int grid, int x, int y, int z)
{
    struct grid *g = enter(grid);
    if (!g) {
        return VERTEX_NO_GRID;
    }
    if (outside(x, y, z)) {
        spin_unlock(&g->lock);
        return VERTEX_OUTSIDE;
    }
    uint32_t slot;
    if (!probe(g, vertex_cell_key(x, y, z), &slot)) {
        spin_unlock(&g->lock);
        return VERTEX_UNCHANGED;
    }
    uint16_t gone = g->slots[slot];

    /* Empty the slot, then walk the run after it, moving back each entry
     * whose probe would have passed through the hole: an entry may sit at
     * `j` only if every slot from its home up to `j` is full. */
    uint32_t mask = ((uint32_t)1 << g->slot_bits) - 1;
    uint32_t hole = slot;
    for (uint32_t j = (hole + 1) & mask; g->slots[j] != EMPTY; j = (j + 1) & mask) {
        uint32_t k = home(g, key_of(&g->vertices[g->slots[j]]));
        int stays = hole <= j ? (hole < k && k <= j) : (hole < k || k <= j);
        if (!stays) {
            g->slots[hole] = g->slots[j];
            hole = j;
        }
    }
    g->slots[hole] = EMPTY;

    /* Keep the array dense: the last vertex fills the gap. */
    int last = g->count - 1;
    if (gone != last) {
        g->vertices[gone] = g->vertices[last];
        uint32_t moved;
        probe(g, key_of(&g->vertices[gone]), &moved);
        g->slots[moved] = gone;
    }
    g->count--;
    spin_unlock(&g->lock);
    return VERTEX_PLACED;
}
/* }}} */

/* {{{ vertex_grid_at */
int vertex_grid_at(int grid, int x, int y, int z, struct vertex *out)
{
    struct grid *g = enter(grid);
    if (!g) {
        return VERTEX_NO_GRID;
    }
    if (outside(x, y, z)) {
        spin_unlock(&g->lock);
        return VERTEX_OUTSIDE;
    }
    uint32_t slot;
    int found = probe(g, vertex_cell_key(x, y, z), &slot);
    if (found && out) {
        *out = g->vertices[g->slots[slot]];
    }
    spin_unlock(&g->lock);
    return found;
}
/* }}} */

/* {{{ walking */
int vertex_grid_count(int grid)
{
    struct grid *g = enter(grid);
    if (!g) {
        return VERTEX_NO_GRID;
    }
    int n = g->count;
    spin_unlock(&g->lock);
    return n;
}

int vertex_grid_list(int grid, int start, struct vertex *out, int max)
{
    struct grid *g = enter(grid);
    if (!g) {
        return VERTEX_NO_GRID;
    }
    int n = 0;
    for (int i = start < 0 ? 0 : start; i < g->count && n < max; i++) {
        out[n++] = g->vertices[i];
    }
    spin_unlock(&g->lock);
    return n;
}

int vertex_grid_app(int grid)
{
    struct grid *g = enter(grid);
    if (!g) {
        return VERTEX_NO_GRID;
    }
    int app = g->app;
    spin_unlock(&g->lock);
    return app;
}

size_t vertex_grid_bytes(int grid)
{
    struct grid *g = enter(grid);
    if (!g) {
        return 0;
    }
    size_t bytes = vertex_bytes(g->capacity) + slot_bytes(g->slot_bits);
    spin_unlock(&g->lock);
    return bytes;
}
/* }}} */
