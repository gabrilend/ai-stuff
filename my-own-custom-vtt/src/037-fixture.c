/*
 * 037-fixture.c -- two rooms, a corridor, a cellar, and a few things standing about.
 *
 * Interface and reasoning are in 037-fixture.h.
 *
 * The layout, in metres, looking down:
 *
 *      0        20   24   30        50
 *   20 +---------+           +---------+
 *      |         |           |         |
 *      |    P    |           |         |
 *   12 |         +-----D-----+         |
 *      |         :  corridor :         |
 *    8 |         +-----------+         |
 *      | +-----+ |           |         |
 *      | |cellar |           |         |
 *    0 +-+-----+-+           +---------+
 *
 *   P is a pillar, so that phase 2 has something to cast a shadow around.
 *   D is a door, so that the flags-change mechanism has something to change.
 *
 * Region boundaries are wound counter-clockwise, because the validator insists
 * on one convention and that is the one.
 */

#include "037-fixture.h"
#include "031-region.h"

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static uint32_t add_wall */
static uint32_t add_wall(struct world *w,
                         wcoord x0, wcoord y0, wcoord x1, wcoord y1,
                         uint16_t flags)
{
    uint32_t index = world_add_wall(w);
    struct wall *wl;

    if (index == 0) {
        return 0;
    }

    wl = world_wall(w, index);
    wl->ax = x0;
    wl->ay = y0;
    wl->bx = x1;
    wl->by = y1;
    wl->flags = flags;

    return index;
}
/* }}} */

/* {{{ static uint32_t add_box_region */
static uint32_t add_box_region(struct world *w,
                               wcoord x0, wcoord y0, wcoord x1, wcoord y1,
                               uint32_t parent, const char *name, uint32_t name_length)
{
    uint32_t first = world_add_vertex(w, x0, y0);
    uint32_t region;
    struct region *r;

    /* Counter-clockwise, which is the winding the validator requires. */
    world_add_vertex(w, x1, y0);
    world_add_vertex(w, x1, y1);
    world_add_vertex(w, x0, y1);

    region = world_add_region(w);
    if (region == 0) {
        return 0;
    }

    r = world_region(w, region);
    r->first_vertex = first;
    r->vertex_count = 4;
    r->parent = parent;
    r->name_offset = string_pool_add(&w->strings, name, name_length);

    return region;
}
/* }}} */

/* {{{ static uint32_t add_thing */
static uint32_t add_thing(struct world *w, wcoord x, wcoord y, uint16_t flags)
{
    uint32_t index = world_add_thing(w);
    struct thing *t;

    if (index == 0) {
        return 0;
    }

    t = world_thing(w, index);
    t->x = x;
    t->y = y;
    t->flags = flags;
    t->radius = (uint16_t)(WC_ONE / 2);

    /*
     * The region field is set here rather than left for a caller, because the
     * validator insists it be the deepest region actually containing the body --
     * and a fixture that does not validate is worse than no fixture, since every
     * test built on it would be testing a broken world.
     */
    t->region = region_deepest_containing(w, x, y);

    return index;
}
/* }}} */

/* {{{ void fixture_capacity_hint */
void fixture_capacity_hint(uint32_t *things,
                           uint32_t *walls,
                           uint32_t *regions,
                           uint32_t *vertices,
                           uint32_t *lights,
                           uint32_t *strings)
{
    *things   = 16;
    *walls    = 32;
    *regions  = 8;
    *vertices = 32;
    *lights   = 8;
    *strings  = 512;
}
/* }}} */

/* {{{ int fixture_build_two_rooms */
int fixture_build_two_rooms(struct world *w)
{
    uint32_t west_room;
    uint32_t cellar;
    uint32_t east_room;
    uint32_t door_leaf;
    uint32_t door_wall;
    uint32_t torch;
    uint32_t light;

    /*
     * Regions first, because add_thing asks which region a body is standing in
     * and needs the answer to already exist.
     */
    west_room = add_box_region(w, M(0), M(0), M(20), M(20), 0, "The West Room", 13);
    if (west_room == 0) return 0;

    cellar = add_box_region(w, M(2), M(2), M(8), M(8), west_room, "The Cellar", 10);
    if (cellar == 0) return 0;

    east_room = add_box_region(w, M(30), M(0), M(50), M(20), 0, "The East Room", 13);
    if (east_room == 0) return 0;

    /* The west room's outline, with a gap where the corridor leaves it. */
    add_wall(w, M(0),  M(0),  M(20), M(0),  BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    add_wall(w, M(0),  M(20), M(0),  M(0),  BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    add_wall(w, M(20), M(20), M(0),  M(20), BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    add_wall(w, M(20), M(0),  M(20), M(8),  BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    add_wall(w, M(20), M(12), M(20), M(20), BLOCKS_SIGHT | BLOCKS_MOVEMENT);

    /* The east room's outline, with the matching gap. */
    add_wall(w, M(30), M(0),  M(50), M(0),  BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    add_wall(w, M(50), M(0),  M(50), M(20), BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    add_wall(w, M(50), M(20), M(30), M(20), BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    add_wall(w, M(30), M(20), M(30), M(12), BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    add_wall(w, M(30), M(8),  M(30), M(0),  BLOCKS_SIGHT | BLOCKS_MOVEMENT);

    /* The corridor's two sides. */
    add_wall(w, M(20), M(8),  M(30), M(8),  BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    add_wall(w, M(30), M(12), M(20), M(12), BLOCKS_SIGHT | BLOCKS_MOVEMENT);

    /*
     * The pillar. Four short walls in the middle of the west room, so that a body
     * standing on one side of it cannot see what is on the other. Phase 2's demo
     * needs exactly this to have anything interesting to draw.
     */
    add_wall(w, M(9),  M(13), M(11), M(13), BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    add_wall(w, M(11), M(13), M(11), M(15), BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    add_wall(w, M(11), M(15), M(9),  M(15), BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    add_wall(w, M(9),  M(15), M(9),  M(13), BLOCKS_SIGHT | BLOCKS_MOVEMENT);

    /*
     * The door. A wall segment across the corridor whose blocking bits the
     * ruleset clears when the leaf is opened -- there is no door system, and the
     * sight code never learns what a door is.
     */
    door_leaf = add_thing(w, M(25), M(10), BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    if (door_leaf == 0) return 0;

    door_wall = add_wall(w, M(25), M(8), M(25), M(12), BLOCKS_SIGHT | BLOCKS_MOVEMENT);
    if (door_wall == 0) return 0;
    world_wall(w, door_wall)->door = door_leaf;

    /* A body with eyes, in the west room. */
    {
        uint32_t goblin = add_thing(w, M(5), M(15), BLOCKS_MOVEMENT);
        struct thing *t;

        if (goblin == 0) return 0;

        t = world_thing(w, goblin);
        t->facing = 0;                 /* Looking east, toward the corridor. */
        t->sight_range = M(30);
        t->sight_arc = WA_HALF;        /* Everything in front. */
        t->kind = 1;

        /*
         * And a face. Fixed words and fixed numbers, like everything else here:
         * a fixture whose appearance varies is a fixture that makes a test fail
         * for a reason that has nothing to do with what it was testing.
         */
        t->sprite_category = string_pool_add(&w->strings, "goblin", 6);
        t->sprite_seed = 11;
    }

    /*
     * A coffee cup, in the cellar. It has no sight, no blocking, and no ruleset
     * sheet -- and it is the same record as the goblin above, which is the point.
     */
    {
        uint32_t cup = add_thing(w, M(4), M(4), 0);
        if (cup == 0) return 0;
        world_thing(w, cup)->kind = 2;
        world_thing(w, cup)->radius = (uint16_t)(WC_ONE / 8);
        world_thing(w, cup)->sprite_category =
            string_pool_add(&w->strings, "cup", 3);
        world_thing(w, cup)->sprite_seed = 4;
    }

    /* A torch on the east room's wall. */
    torch = add_thing(w, M(45), M(10), THING_EMITS_LIGHT);
    if (torch == 0) return 0;
    world_thing(w, torch)->kind = 3;
    world_thing(w, torch)->sprite_category = string_pool_add(&w->strings, "torch", 5);
    world_thing(w, torch)->sprite_seed = 7;

    light = world_add_light(w);
    if (light == 0) return 0;
    {
        struct light *l = world_light(w, light);
        l->thing = torch;
        l->radius = M(8);
        l->dim_radius = M(4);
        l->colour = 0xFFCC8844u;
        l->arc = 65535;
    }

    w->min_x = M(0);
    w->min_y = M(0);
    w->max_x = M(50);
    w->max_y = M(20);

    return 1;
}
/* }}} */

/* {{{ int fixture_make_two_rooms */
int fixture_make_two_rooms(struct world *w)
{
    uint32_t things;
    uint32_t walls;
    uint32_t regions;
    uint32_t vertices;
    uint32_t lights;
    uint32_t strings;

    fixture_capacity_hint(&things, &walls, &regions, &vertices, &lights, &strings);

    if (!world_init(w, things, walls, regions, vertices, lights, strings)) {
        return 0;
    }

    return fixture_build_two_rooms(w);
}
/* }}} */
