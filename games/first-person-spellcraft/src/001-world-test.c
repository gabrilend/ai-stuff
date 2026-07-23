/* 001-world-test.c — proves the square-room world: it validates coherent, its
 * walls/floors/rooms/doors read as authored, and the room-behaviour dispatch
 * fires. Temporary prover; build + run from the Makefile.
 */
#include "001-world.h"

#include <stdio.h>

static int failures = 0;
static void check(const char *name, int cond)
{
    if (cond) printf("  ok  %s\n", name);
    else    { printf("  FAIL %s\n", name); failures++; }
}

/* {{{ a behaviour that records it was fired, to prove dispatch works */
static int g_entered;
static void counting_enter(world_t *w, room_t *r, void *ctx)
{
    (void)w; (void)r; (void)ctx; g_entered++;
}
/* }}} */

int main(void)
{
    printf("world:\n");
    world_t *w = world_build_test();
    check("world built", w != NULL);

    /* Validates coherent, and the counts are self-consistent. */
    world_stats_t s;
    int ok = world_validate(w, &s);
    check("world validates coherent (0 problems)", ok && s.problems == 0);
    check("cell count = grid area", s.n_cells == s.grid_w * s.grid_h);
    check("solid + open = all cells", s.n_solid + s.n_open == s.n_cells);
    check("four rooms, four doors", s.n_rooms == 4 && s.n_doors == 4);

    /* Geometry reads as authored: perimeter solid, interiors open, the step-up. */
    check("outer corner is solid (the void wall)", world_is_solid(w, 0, 0));
    check("off-map is solid too", world_is_solid(w, -1, 5) && world_is_solid(w, 999, 5));
    check("room 0 interior is open", !world_is_solid(w, 5, 5));
    check("room 1 interior is open", !world_is_solid(w, 15, 5));
    check("dividing wall is solid", world_is_solid(w, 12, 3));
    check("door punched through the wall is open", !world_is_solid(w, 12, 4));

    check("cell (5,5) belongs to room 0", world_room_at(w, 5, 5) == 0);
    check("cell (15,5) belongs to room 1", world_room_at(w, 15, 5) == 1);

    const cell_t *r0 = world_cell(w, 5, 5);
    const cell_t *r1 = world_cell(w, 15, 5);
    check("room 1 floor is a step higher than room 0",
          r1->floor_h > r0->floor_h);

    /* The behaviour dispatch fires for a room's tag, and skips harmlessly when
     * the tag is unregistered. */
    world_register_behaviour(ROOM_SPAWN,
        (room_behaviour_t){ "spawn-test", counting_enter, NULL, NULL });
    g_entered = 0;
    world_room_enter(w, w->spawn_room, NULL);   /* spawn room uses ROOM_SPAWN */
    check("entering the spawn room fired its behaviour", g_entered == 1);
    world_room_step(w, w->spawn_room, NULL);    /* no on_step registered: no-op, no crash */
    check("stepping with no registered callback is a safe no-op", g_entered == 1);

    printf("  (grid %dx%d, %d solid / %d open, %d rooms, %d doors)\n",
           s.grid_w, s.grid_h, s.n_solid, s.n_open, s.n_rooms, s.n_doors);

    world_destroy(w);
    printf(failures ? "\n%d FAILURE(S)\n" : "\nall checks passed\n", failures);
    return failures ? 1 : 0;
}
