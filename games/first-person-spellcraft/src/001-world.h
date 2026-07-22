/* 001-world.h — the square-room world: what a map IS.
 *
 * Two lenses over one map (issue 103):
 *   - the TILE GRID the renderer marches and collision tests against;
 *   - the ROOM TABLE + DOOR graph gameplay reasons about.
 * Both point at the same underlying cells.
 *
 * Coordinate & unit conventions (written here so the renderer and collision
 * can't let them drift):
 *   - The grid is `cells[y * width + x]`. x is the column (0..width-1, +x =
 *     east); y is the row (0..height-1, +y = south). One cell = one tile.
 *   - Moving things carry float tile positions, so (1.5, 2.5) sits mid-cell
 *     (1,2). Convert to a cell with (int)floorf(pos).
 *   - Height (z) is a SEPARATE vertical axis. floor_h / ceil_h are per cell, in
 *     tile units; a body stands on its cell's floor_h. Per-cell heights are what
 *     make ledges (issue 104) and jumping (issue 106) possible.
 *   - A SOLID cell blocks BOTH movement and sight. An open cell belongs to a
 *     room (room_id >= 0); void/solid cells outside any room carry room_id -1.
 */
#ifndef FPS_WORLD_H
#define FPS_WORLD_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* {{{ cell_t — one tile of the grid */
typedef struct {
    uint8_t  solid;    /* 1 = blocks movement and sight; 0 = open */
    uint16_t wall_id;  /* wall surface id (which surface to draw); used when solid */
    float    floor_h;  /* floor height, tile units (a body stands here) */
    float    ceil_h;   /* ceiling height, tile units */
    int16_t  room_id;  /* room this cell belongs to, or -1 for none/void */
} cell_t;
/* }}} */

/* {{{ door_t — an edge of the room graph */
typedef struct {
    int     room_a, room_b; /* the two rooms this door links */
    int     x, y;           /* the opening cell on the shared edge (grid coords) */
    uint8_t passable;       /* 1 = open, 0 = locked (a puzzle may toggle later) */
} door_t;
/* }}} */

/* {{{ room_t — a node of the room graph */
typedef struct {
    int   id;
    int   x0, y0, x1, y1;   /* footprint: cells [x0,x1) x [y0,y1) (half-open) */
    float floor_h, ceil_h;
    int   special;          /* special-property tag: index into the behaviour table */
} room_t;
/* }}} */

/* {{{ world_t — the whole map, both lenses */
typedef struct {
    int     width, height;  /* grid size in cells */
    cell_t *cells;          /* width*height cells, indexed [y*width + x] */
    room_t *rooms;
    int     n_rooms;
    door_t *doors;
    int     n_doors;
    int     spawn_room;     /* room id where a body starts */
} world_t;
/* }}} */

/* {{{ room-behaviour dispatch (the Phase-4/6 seam) */
/* A room's `special` tag indexes this table (dispatch over if-else, house
 * style). Phase 1 registers only trivial `plain` and `spawn` entries, but the
 * TABLE and its enter/step/exit contract are the deliverable: Phase 4
 * (puzzles/traps) and Phase 6 (combat/treasure) register real behaviours here,
 * and the engine fires the callbacks without ever learning what a puzzle is. */
enum { ROOM_PLAIN = 0, ROOM_SPAWN = 1, ROOM_BEHAVIOUR_MAX = 16 };

typedef void (*room_cb_t)(world_t *w, room_t *r, void *ctx);
typedef struct { const char *name; room_cb_t on_enter, on_step, on_exit; } room_behaviour_t;

/* Register a behaviour at a tag index (returns 1 ok, 0 if the index is out of
 * range). Fire the enter/step/exit callback for a room's special tag. */
int  world_register_behaviour(int tag, room_behaviour_t b);
void world_room_enter(world_t *w, int room_id, void *ctx);
void world_room_step (world_t *w, int room_id, void *ctx);
void world_room_exit (world_t *w, int room_id, void *ctx);
/* }}} */

/* {{{ build / destroy / query */
/* Assemble the hand-authored Phase-1 test world: two square rooms side by side,
 * a wall between them with one passable door, and a height change to jump onto.
 * NULL on allocation failure. */
world_t *world_build_test(void);
void     world_destroy(world_t *w);

/* Cell at (cx,cy), or NULL out of bounds. */
const cell_t *world_cell(const world_t *w, int cx, int cy);
/* 1 if (cx,cy) is solid OR out of bounds (the void beyond the grid blocks too). */
int           world_is_solid(const world_t *w, int cx, int cy);
/* Room id at (cx,cy), or -1 (out of bounds / void). */
int           world_room_at(const world_t *w, int cx, int cy);
/* }}} */

/* {{{ validator */
typedef struct {
    int grid_w, grid_h, n_cells, n_solid, n_open, n_rooms, n_doors;
    int problems;   /* count of coherence problems found */
} world_stats_t;

/* Check a world for coherence (cell room ids valid, doors link real rooms,
 * spawn room present, rooms don't overlap) and fill `out` with counts. Returns 1
 * if coherent (problems == 0), 0 otherwise. Runnable standalone so docs can cite
 * it instead of hardcoding map sizes. */
int world_validate(const world_t *w, world_stats_t *out);
/* }}} */

#ifdef __cplusplus
}
#endif

#endif /* FPS_WORLD_H */
