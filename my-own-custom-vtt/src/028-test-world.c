/*
 * 028-test-world.c -- pins down the world's storage and its record layouts.
 *
 * Two things are checked here that look pedantic and are not.
 *
 * The record sizes are asserted, because the world file writes fields one at a
 * time precisely so that a compiler's padding never reaches the file -- and if a
 * record silently grows a hole, that is the moment to find out, rather than when
 * a world written on one machine will not load on another.
 *
 * And the sight and movement flags are checked to be the same bits on a body as
 * on a wall. An earlier draft numbered them differently in the two places, which
 * produces a curtain you cannot walk through and a wall you can see past, with
 * nothing obviously wrong in either file.
 */

#include "020-test-harness.h"
#include "027-world.h"

#include <string.h>

/* {{{ static int start_world */
static int start_world(struct world *w)
{
    return world_init(w, 16, 16, 8, 64, 8, 1024);
}
/* }}} */

/* {{{ static void test_record_layouts */
static void test_record_layouts(void)
{
    TEST_CASE("records are packed with no padding the writer would have to skip");

    CHECK_EQ(sizeof(struct thing), 36);
    CHECK_EQ(sizeof(struct wall), 24);
    CHECK_EQ(sizeof(struct region), 16);
    CHECK_EQ(sizeof(struct vertex), 8);
    CHECK_EQ(sizeof(struct light), 20);

    TEST_CASE("sight and movement mean the same bits on a body as on a wall");

    /*
     * Shared constants, not two parallel definitions. This check exists because
     * the two were once numbered differently, and the symptom was subtle in both
     * directions at once.
     */
    CHECK_EQ(BLOCKS_SIGHT, 1u);
    CHECK_EQ(BLOCKS_MOVEMENT, 2u);
    CHECK(BLOCKS_SIGHT != BLOCKS_MOVEMENT);
}
/* }}} */

/* {{{ static void test_sentinels */
static void test_sentinels(void)
{
    struct world w;

    TEST_CASE("every block starts with its empty record already claimed");

    CHECK(start_world(&w) == 1);

    CHECK_EQ(world_thing_count(&w), 1);
    CHECK_EQ(world_wall_count(&w), 1);
    CHECK_EQ(world_region_count(&w), 1);
    CHECK_EQ(world_vertex_count(&w), 1);
    CHECK_EQ(world_light_count(&w), 1);

    TEST_CASE("nothing reads as an empty record rather than as a null pointer");

    {
        const struct thing *nothing = world_thing_const(&w, 0);
        CHECK_EQ(nothing->x, 0);
        CHECK_EQ(nothing->scope, 0);
        CHECK_EQ(nothing->sight_range, 0);

        /* And so a body that does not exist also does not see. */
        CHECK_EQ(thing_can_see(nothing), 0);
    }

    world_release(&w);
}
/* }}} */

/* {{{ static void test_a_coffee_cup_is_a_thing */
static void test_a_coffee_cup_is_a_thing(void)
{
    struct world w;
    uint32_t goblin;
    uint32_t cup;

    TEST_CASE("a goblin and a coffee cup are the same record");

    /*
     * The load-bearing claim of the data model. If this ever stops being true,
     * the control dial stops being one mechanism and becomes four.
     */
    CHECK(start_world(&w) == 1);

    goblin = world_add_thing(&w);
    cup    = world_add_thing(&w);

    CHECK(goblin != BLOCK_NOTHING);
    CHECK(cup != BLOCK_NOTHING);

    {
        struct thing *g = world_thing(&w, goblin);
        g->x = 10 * WC_ONE;
        g->y = 20 * WC_ONE;
        g->sight_range = 12 * WC_ONE;
        g->sight_arc = WA_HALF;
        g->radius = (uint16_t)(WC_ONE / 2);
        g->flags = BLOCKS_MOVEMENT;
    }

    {
        struct thing *c = world_thing(&w, cup);
        c->x = 11 * WC_ONE;
        c->y = 20 * WC_ONE;
        /* No sight range, no arc, no blocking. A cup. */
    }

    {
        const struct thing *g = world_thing_const(&w, goblin);
        const struct thing *c = world_thing_const(&w, cup);

        CHECK_EQ(thing_can_see(g), 1);
        CHECK_EQ(thing_can_see(c), 0);
        CHECK_EQ(thing_blocks_movement(g), 1);
        CHECK_EQ(thing_blocks_movement(c), 0);
        CHECK_EQ(thing_blocks_sight(g), 0);
    }

    world_release(&w);
}
/* }}} */

/* {{{ static void test_walls_disagree_usefully */
static void test_walls_disagree_usefully(void)
{
    struct world w;
    uint32_t chasm;
    uint32_t curtain;
    uint32_t portcullis;

    TEST_CASE("the two blocking flags are separate because they disagree");

    /*
     * The three cases that a single "solid" flag would delete.
     */
    CHECK(start_world(&w) == 1);

    chasm      = world_add_wall(&w);
    curtain    = world_add_wall(&w);
    portcullis = world_add_wall(&w);

    world_wall(&w, chasm)->flags      = BLOCKS_MOVEMENT;
    world_wall(&w, curtain)->flags    = BLOCKS_SIGHT;
    world_wall(&w, portcullis)->flags = BLOCKS_MOVEMENT;

    {
        const struct wall *c = world_wall_const(&w, chasm);
        CHECK_EQ(wall_blocks_movement(c), 1);
        CHECK_EQ(wall_blocks_sight(c), 0);
    }

    {
        const struct wall *c = world_wall_const(&w, curtain);
        CHECK_EQ(wall_blocks_movement(c), 0);
        CHECK_EQ(wall_blocks_sight(c), 1);
    }

    {
        const struct wall *p = world_wall_const(&w, portcullis);
        CHECK_EQ(wall_blocks_movement(p), 1);
        CHECK_EQ(wall_blocks_sight(p), 0);
    }

    world_release(&w);
}
/* }}} */

/* {{{ static void test_regions_and_vertices */
static void test_regions_and_vertices(void)
{
    struct world w;
    uint32_t tavern;
    uint32_t cellar;
    uint32_t first;

    TEST_CASE("a region's boundary is a run of consecutive vertices");

    CHECK(start_world(&w) == 1);

    first = world_add_vertex(&w, 0, 0);
    world_add_vertex(&w, 10 * WC_ONE, 0);
    world_add_vertex(&w, 10 * WC_ONE, 10 * WC_ONE);
    world_add_vertex(&w, 0, 10 * WC_ONE);

    tavern = world_add_region(&w);
    {
        struct region *r = world_region(&w, tavern);
        r->first_vertex = first;
        r->vertex_count = 4;
        r->parent = 0;
        r->name_offset = string_pool_add(&w.strings, "The Tavern", 10);
    }

    {
        const struct region *r = world_region_const(&w, tavern);
        CHECK_EQ(r->vertex_count, 4);
        CHECK_EQ(r->parent, 0);

        /* The boundary is closed without the last vertex being repeated. */
        CHECK_EQ(world_vertex_const(&w, r->first_vertex)->x, 0);
        CHECK_EQ(world_vertex_const(&w, r->first_vertex + 3)->y, 10 * WC_ONE);
    }

    TEST_CASE("a region nests inside another by naming it as parent");

    cellar = world_add_region(&w);
    world_region(&w, cellar)->parent = tavern;

    CHECK_EQ(world_region_const(&w, cellar)->parent, tavern);
    CHECK_EQ(world_region_const(&w, tavern)->parent, 0);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_copy_is_exact */
static void test_copy_is_exact(void)
{
    struct world source;
    struct world destination;
    uint32_t i;

    TEST_CASE("a copied world is byte-identical to its original");

    /*
     * What the rollback ring does at the head of every turn. It has to be exact:
     * if a copy differs anywhere, an undone turn replays differently for a
     * reason nobody can see.
     */
    CHECK(start_world(&source) == 1);
    CHECK(start_world(&destination) == 1);

    for (i = 0; i < 50; i++) {
        uint32_t index = world_add_thing(&source);
        struct thing *t = world_thing(&source, index);
        t->x = (wcoord)(i * WC_ONE);
        t->y = (wcoord)(i * 2 * WC_ONE);
        t->facing = (wangle)(i * 1000);
        t->kind = i;
    }

    string_pool_add(&source.strings, "The Forest", 10);
    source.tick = 4207;
    source.max_x = 120 * WC_ONE;

    CHECK(world_copy(&destination, &source) == 1);

    CHECK_EQ(world_thing_count(&destination), world_thing_count(&source));
    CHECK_EQ(destination.tick, source.tick);
    CHECK_EQ(destination.max_x, source.max_x);
    CHECK_EQ(destination.strings.used, source.strings.used);

    CHECK_EQ(memcmp(destination.things.data,
                    source.things.data,
                    block_bytes_used(&source.things)), 0);

    CHECK_EQ(memcmp(destination.strings.data,
                    source.strings.data,
                    source.strings.used), 0);

    world_release(&source);
    world_release(&destination);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_record_layouts();
    test_sentinels();
    test_a_coffee_cup_is_a_thing();
    test_walls_disagree_usefully();
    test_regions_and_vertices();
    test_copy_is_exact();

    return vtt_test_finish("028-test-world");
}
/* }}} */
