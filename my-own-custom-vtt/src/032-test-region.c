/*
 * 032-test-region.c -- nesting, and which region wins.
 *
 * The property everything else leans on: a body in the cellar is in the cellar,
 * not in the tavern above it. If the deepest region does not win, a scope over
 * the cellar never owns anything and "when they enter the cellar" never fires.
 */

#include "020-test-harness.h"
#include "031-region.h"

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static uint32_t add_box */
static uint32_t add_box(struct world *w,
                        wcoord x0, wcoord y0, wcoord x1, wcoord y1,
                        uint32_t parent)
{
    uint32_t first = world_add_vertex(w, x0, y0);
    uint32_t region;
    struct region *r;

    world_add_vertex(w, x1, y0);
    world_add_vertex(w, x1, y1);
    world_add_vertex(w, x0, y1);

    region = world_add_region(w);
    r = world_region(w, region);
    r->first_vertex = first;
    r->vertex_count = 4;
    r->parent = parent;

    return region;
}
/* }}} */

/* {{{ static void test_deepest_wins */
static void test_deepest_wins(void)
{
    struct world w;
    uint32_t tavern;
    uint32_t cellar;

    TEST_CASE("a body in the cellar is in the cellar, not the tavern");

    CHECK(world_init(&w, 16, 16, 8, 64, 8, 1024) == 1);

    /* A twenty-metre tavern with a five-metre cellar in one corner of it. */
    tavern = add_box(&w, 0, 0, M(20), M(20), 0);
    cellar = add_box(&w, M(2), M(2), M(7), M(7), tavern);

    CHECK(region_deepest_containing(&w, M(4), M(4)) == cellar);
    CHECK(region_deepest_containing(&w, M(15), M(15)) == tavern);

    TEST_CASE("outside everything is open ground, which is zero");

    CHECK_EQ(region_deepest_containing(&w, M(100), M(100)), 0);

    TEST_CASE("both polygons really do contain the point");

    /*
     * Not a trick question -- the cellar's point is genuinely inside the tavern
     * too. Which is why "deepest" has to be the rule rather than "first found".
     */
    CHECK(region_contains(&w, tavern, M(4), M(4)) == 1);
    CHECK(region_contains(&w, cellar, M(4), M(4)) == 1);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_depth */
static void test_depth(void)
{
    struct world w;
    uint32_t forest;
    uint32_t clearing;
    uint32_t hollow;

    TEST_CASE("depth counts the parents above a region");

    CHECK(world_init(&w, 16, 16, 8, 64, 8, 1024) == 1);

    forest   = add_box(&w, 0, 0, M(100), M(100), 0);
    clearing = add_box(&w, M(10), M(10), M(40), M(40), forest);
    hollow   = add_box(&w, M(15), M(15), M(20), M(20), clearing);

    CHECK_EQ(region_depth(&w, 0), 0);
    CHECK_EQ(region_depth(&w, forest), 1);
    CHECK_EQ(region_depth(&w, clearing), 2);
    CHECK_EQ(region_depth(&w, hollow), 3);

    TEST_CASE("three levels deep still resolves to the innermost");

    CHECK(region_deepest_containing(&w, M(17), M(17)) == hollow);
    CHECK(region_deepest_containing(&w, M(30), M(30)) == clearing);
    CHECK(region_deepest_containing(&w, M(80), M(80)) == forest);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_the_permission_walk */
static void test_the_permission_walk(void)
{
    struct world w;
    uint32_t forest;
    uint32_t clearing;
    uint32_t tavern;

    TEST_CASE("a scope over the forest covers the clearing inside it");

    /*
     * The whole reason regions nest through a single parent index. A commander
     * handed the forest does not have to list what is in it.
     */
    CHECK(world_init(&w, 16, 16, 8, 64, 8, 1024) == 1);

    forest   = add_box(&w, 0, 0, M(100), M(100), 0);
    clearing = add_box(&w, M(10), M(10), M(40), M(40), forest);
    tavern   = add_box(&w, M(200), M(200), M(220), M(220), 0);

    CHECK(region_is_within(&w, clearing, forest) == 1);
    CHECK(region_is_within(&w, forest, forest) == 1);

    TEST_CASE("and does not cover somewhere else entirely");

    CHECK(region_is_within(&w, tavern, forest) == 0);
    CHECK(region_is_within(&w, forest, clearing) == 0);
    CHECK(region_is_within(&w, forest, tavern) == 0);

    TEST_CASE("an ancestor of zero is the whole map, with no special case");

    /*
     * How a GM's scope is expressed. Everything is within the whole map,
     * including open ground, so the permission check needs no branch for it.
     */
    CHECK(region_is_within(&w, forest, 0) == 1);
    CHECK(region_is_within(&w, clearing, 0) == 1);
    CHECK(region_is_within(&w, 0, 0) == 1);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_malformed_does_not_hang */
static void test_malformed_does_not_hang(void)
{
    struct world w;
    uint32_t a;
    uint32_t b;

    TEST_CASE("a region cycle is survived rather than spun on");

    /*
     * A world with a parent cycle is malformed and the validator refuses it by
     * name. But the validator itself runs against worlds that have not been
     * checked yet, so the walk has to terminate on one rather than hang -- which
     * is what the step bound is for.
     */
    CHECK(world_init(&w, 16, 16, 8, 64, 8, 1024) == 1);

    a = add_box(&w, 0, 0, M(10), M(10), 0);
    b = add_box(&w, 0, 0, M(10), M(10), a);

    /* Deliberately broken: a now claims b as its parent, and b claims a. */
    world_region(&w, a)->parent = b;

    CHECK(region_depth(&w, a) <= REGION_MAX_DEPTH + 1);
    CHECK(region_depth(&w, b) <= REGION_MAX_DEPTH + 1);
    CHECK(region_is_within(&w, a, 99) == 0);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_empty_region */
static void test_empty_region(void)
{
    struct world w;
    uint32_t empty;

    TEST_CASE("a region with no boundary contains nothing");

    CHECK(world_init(&w, 16, 16, 8, 64, 8, 1024) == 1);

    empty = world_add_region(&w);

    CHECK(region_contains(&w, empty, 0, 0) == 0);
    CHECK(region_contains(&w, empty, M(5), M(5)) == 0);
    CHECK_EQ(region_deepest_containing(&w, M(5), M(5)), 0);

    world_release(&w);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_deepest_wins();
    test_depth();
    test_the_permission_walk();
    test_malformed_does_not_hang();
    test_empty_region();

    return vtt_test_finish("032-test-region");
}
/* }}} */
