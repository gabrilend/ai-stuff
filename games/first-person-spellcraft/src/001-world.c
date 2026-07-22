/* 001-world.c — the square-room world.
 *
 * How it works, for a general reader: the map is a rectangle of tiles. Every
 * tile is either solid (a wall you can't pass or see through) or open floor that
 * belongs to a numbered room. Rooms are the big regions; doors are the openings
 * between them. A tiny "behaviour" table lets later work attach meaning to a room
 * (a puzzle, a shop) without this file knowing what any of that is. The builder
 * hand-lays one small two-room map with a step up between them; the validator
 * double-checks a map hangs together and counts its parts.
 */
#include "001-world.h"

#include <stdlib.h>
#include <string.h>

/* {{{ the room-behaviour table + its trivial Phase-1 entries */
static room_behaviour_t g_behaviours[ROOM_BEHAVIOUR_MAX];

/* plain and spawn do nothing yet — but registering them proves the dispatch
 * contract Phase 4/6 will fill in with real puzzle/combat behaviours. */
static void noop_cb(world_t *w, room_t *r, void *ctx) { (void)w; (void)r; (void)ctx; }

int world_register_behaviour(int tag, room_behaviour_t b)
{
    if (tag < 0 || tag >= ROOM_BEHAVIOUR_MAX) return 0;
    g_behaviours[tag] = b;
    return 1;
}

/* {{{ local ensure_default_behaviours() — register plain + spawn once */
static void ensure_default_behaviours(void)
{
    /* Idempotent: registering plain over itself is harmless, so a second world
     * build doesn't need to guard. */
    world_register_behaviour(ROOM_PLAIN, (room_behaviour_t){ "plain", noop_cb, noop_cb, noop_cb });
    world_register_behaviour(ROOM_SPAWN, (room_behaviour_t){ "spawn", noop_cb, noop_cb, noop_cb });
}
/* }}} */

/* {{{ local fire() — look up a room's behaviour and call one phase of it */
/* A room's `special` tag picks the behaviour; which callback (enter/step/exit)
 * is picked by `which`. A NULL callback (unregistered tag) is simply skipped —
 * an unpopulated seam is not an error, it just does nothing. */
static void fire(world_t *w, int room_id, int which, void *ctx)
{
    if (!w || room_id < 0 || room_id >= w->n_rooms) return;
    room_t *r = &w->rooms[room_id];
    if (r->special < 0 || r->special >= ROOM_BEHAVIOUR_MAX) return;
    room_behaviour_t *b = &g_behaviours[r->special];
    room_cb_t cb = (which == 0) ? b->on_enter : (which == 1) ? b->on_step : b->on_exit;
    if (cb) cb(w, r, ctx);
}
/* }}} */

void world_room_enter(world_t *w, int room_id, void *ctx) { fire(w, room_id, 0, ctx); }
void world_room_step (world_t *w, int room_id, void *ctx) { fire(w, room_id, 1, ctx); }
void world_room_exit (world_t *w, int room_id, void *ctx) { fire(w, room_id, 2, ctx); }
/* }}} */

/* {{{ world_cell() / world_is_solid() / world_room_at() */
const cell_t *world_cell(const world_t *w, int cx, int cy)
{
    if (!w || cx < 0 || cy < 0 || cx >= w->width || cy >= w->height) return NULL;
    return &w->cells[cy * w->width + cx];
}

int world_is_solid(const world_t *w, int cx, int cy)
{
    const cell_t *c = world_cell(w, cx, cy);
    /* The void beyond the grid blocks too — off-map is as solid as a wall. */
    return c ? c->solid : 1;
}

int world_room_at(const world_t *w, int cx, int cy)
{
    const cell_t *c = world_cell(w, cx, cy);
    return c ? c->room_id : -1;
}
/* }}} */

/* {{{ local carve_room() — set a rectangle of cells open and owned by a room */
static void carve_room(world_t *w, int x0, int y0, int x1, int y1,
                       int room_id, float floor_h, float ceil_h)
{
    for (int y = y0; y < y1; y++)
        for (int x = x0; x < x1; x++) {
            cell_t *c = &w->cells[y * w->width + x];
            c->solid = 0;
            c->wall_id = 0;
            c->room_id = (int16_t)room_id;
            c->floor_h = floor_h;
            c->ceil_h = ceil_h;
        }
}
/* }}} */

/* {{{ world_build_test() */
world_t *world_build_test(void)
{
    ensure_default_behaviours();

    const int W = 20, H = 12;
    world_t *w = calloc(1, sizeof *w);
    if (!w) return NULL;
    w->width = W; w->height = H;
    w->cells = calloc((size_t)W * H, sizeof *w->cells);
    if (!w->cells) { free(w); return NULL; }

    /* Start every cell solid (a block of stone); rooms are carved out of it. The
     * cells left solid at the end are the walls and the outer void. */
    for (int i = 0; i < W * H; i++) {
        w->cells[i].solid = 1;
        w->cells[i].wall_id = 1;
        w->cells[i].room_id = -1;
    }

    /* Two rooms with a one-tile wall between them at column x=10. Room 1 sits a
     * step higher (floor_h 1.0) so there is something to jump onto (issue 106). */
    carve_room(w, 1, 1, 10, 11, /*room*/0, /*floor*/0.0f, /*ceil*/3.0f);
    carve_room(w, 11, 1, 19, 11, /*room*/1, /*floor*/1.0f, /*ceil*/4.0f);

    /* The door: one open cell punched through the dividing wall at (10, 6),
     * assigned to room 0 as a threshold. */
    cell_t *d = &w->cells[6 * W + 10];
    d->solid = 0; d->wall_id = 0; d->room_id = 0; d->floor_h = 0.0f; d->ceil_h = 3.0f;

    w->n_rooms = 2;
    w->rooms = calloc(2, sizeof *w->rooms);
    w->rooms[0] = (room_t){ .id = 0, .x0 = 1,  .y0 = 1, .x1 = 10, .y1 = 11,
                            .floor_h = 0.0f, .ceil_h = 3.0f, .special = ROOM_SPAWN };
    w->rooms[1] = (room_t){ .id = 1, .x0 = 11, .y0 = 1, .x1 = 19, .y1 = 11,
                            .floor_h = 1.0f, .ceil_h = 4.0f, .special = ROOM_PLAIN };

    w->n_doors = 1;
    w->doors = calloc(1, sizeof *w->doors);
    w->doors[0] = (door_t){ .room_a = 0, .room_b = 1, .x = 10, .y = 6, .passable = 1 };

    w->spawn_room = 0;
    return w;
}
/* }}} */

/* {{{ world_destroy() */
void world_destroy(world_t *w)
{
    if (!w) return;
    free(w->cells);
    free(w->rooms);
    free(w->doors);
    free(w);
}
/* }}} */

/* {{{ world_validate() */
int world_validate(const world_t *w, world_stats_t *out)
{
    world_stats_t s = {0};
    if (!w) { if (out) *out = s; return 0; }

    s.grid_w = w->width; s.grid_h = w->height;
    s.n_cells = w->width * w->height;
    s.n_rooms = w->n_rooms; s.n_doors = w->n_doors;

    /* Every cell: count solid/open, and check an open cell's room id names a real
     * room (a solid/void cell is allowed room_id -1). */
    for (int i = 0; i < s.n_cells; i++) {
        const cell_t *c = &w->cells[i];
        if (c->solid) s.n_solid++;
        else {
            s.n_open++;
            if (c->room_id < 0 || c->room_id >= w->n_rooms) s.problems++;
        }
    }

    /* Every door links two rooms that exist. */
    for (int i = 0; i < w->n_doors; i++) {
        const door_t *d = &w->doors[i];
        if (d->room_a < 0 || d->room_a >= w->n_rooms) s.problems++;
        if (d->room_b < 0 || d->room_b >= w->n_rooms) s.problems++;
    }

    /* The spawn room exists. */
    if (w->spawn_room < 0 || w->spawn_room >= w->n_rooms) s.problems++;

    /* Rooms don't claim overlapping footprints (O(rooms^2 * area), fine at this
     * scale; the map is small and this only runs at load/test time). */
    for (int a = 0; a < w->n_rooms; a++)
        for (int b = a + 1; b < w->n_rooms; b++) {
            const room_t *ra = &w->rooms[a], *rb = &w->rooms[b];
            int ox = (ra->x0 < rb->x1) && (rb->x0 < ra->x1);
            int oy = (ra->y0 < rb->y1) && (rb->y0 < ra->y1);
            if (ox && oy) s.problems++;
        }

    if (out) *out = s;
    return s.problems == 0;
}
/* }}} */
