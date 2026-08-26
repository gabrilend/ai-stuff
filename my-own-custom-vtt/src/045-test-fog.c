/*
 * 045-test-fog.c -- memory only ever grows, until a turn is taken back.
 *
 * The property that makes this memory rather than sight: bits are set and never
 * cleared, so walking away from a room does not forget it. The exception is
 * rollback, which restores the fog along with the world -- and that is a copy,
 * not a clear.
 */

#include "020-test-harness.h"
#include "044-fog.h"
#include "042-sight.h"
#include "037-fixture.h"

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static uint32_t add_eye */
static uint32_t add_eye(struct world *w, wcoord x, wcoord y)
{
    uint32_t index = world_add_thing(w);
    struct thing *t = world_thing(w, index);

    t->x = x;
    t->y = y;
    t->facing = 0;
    t->sight_arc = 65535;
    t->sight_range = (uint32_t)M(100);

    return index;
}
/* }}} */

/* {{{ static void test_it_only_grows */
static void test_it_only_grows(void)
{
    struct world w;
    struct fog f;
    uint32_t eye;
    uint32_t before;
    uint32_t after_first;
    uint32_t after_walking;

    TEST_CASE("a fresh fog remembers nothing");

    CHECK(fixture_make_two_rooms(&w) == 1);
    CHECK(fog_init(&f, &w, WC_ONE) == 1);

    before = fog_cells_seen(&f);
    CHECK_EQ(before, 0);

    TEST_CASE("standing somewhere records it");

    eye = add_eye(&w, M(5), M(5));
    fog_fold(&f, &w, eye);

    after_first = fog_cells_seen(&f);
    CHECK(after_first > 0);
    CHECK(fog_remembers(&f, M(5), M(5)) == 1);

    TEST_CASE("walking away does not forget it");

    /*
     * The whole difference between memory and sight. The body moves to the other
     * room; the first room is no longer visible and is still remembered.
     */
    world_thing(&w, eye)->x = M(40);
    world_thing(&w, eye)->y = M(10);
    fog_fold(&f, &w, eye);

    after_walking = fog_cells_seen(&f);

    CHECK(after_walking > after_first);
    CHECK(fog_remembers(&f, M(5), M(5)) == 1);
    CHECK(sight_point_visible(&w, eye, M(5), M(5)) == 0);

    fog_release(&f);
    world_release(&w);
}
/* }}} */

/* {{{ static void test_it_does_not_remember_through_walls */
static void test_it_does_not_remember_through_walls(void)
{
    struct world w;
    struct fog f;
    uint32_t eye;

    TEST_CASE("a room never entered is not remembered");

    /*
     * If this fails, the fog is not a security boundary, because the outbound
     * filter reads it to decide which walls a viewer may be sent.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);
    CHECK(fog_init(&f, &w, WC_ONE) == 1);

    eye = add_eye(&w, M(5), M(5));
    fog_fold(&f, &w, eye);

    CHECK(fog_remembers(&f, M(5), M(5)) == 1);
    CHECK(fog_remembers(&f, M(40), M(10)) == 0);
    CHECK(fog_remembers(&f, M(45), M(15)) == 0);

    fog_release(&f);
    world_release(&w);
}
/* }}} */

/* {{{ static void test_it_agrees_with_sight */
static void test_it_agrees_with_sight(void)
{
    struct world w;
    struct fog f;
    uint32_t eye;
    uint32_t column;
    uint32_t row;
    uint32_t disagreements = 0;
    uint32_t sampled = 0;

    TEST_CASE("every remembered cell was one sight would have allowed");

    /*
     * The fog and the outbound filter share one primitive on purpose. If a cell
     * is remembered that sight_point_visible would refuse, then the map shows
     * somewhere the filter would never have sent -- which is a leak wearing a
     * drawing's clothes.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);
    CHECK(fog_init(&f, &w, WC_ONE) == 1);

    eye = add_eye(&w, M(10), M(10));
    fog_fold(&f, &w, eye);

    for (row = 0; row < f.rows; row++) {
        for (column = 0; column < f.columns; column++) {
            wcoord x = f.origin_x + (wcoord)(column * f.cell_size) + (f.cell_size / 2);
            wcoord y = f.origin_y + (wcoord)(row * f.cell_size) + (f.cell_size / 2);

            int remembered = fog_remembers(&f, x, y);
            int visible = sight_point_visible(&w, eye, x, y);

            sampled++;

            if (remembered && !visible) {
                disagreements++;
            }
        }
    }

    CHECK(sampled > 500);
    CHECK_EQ(disagreements, 0);

    fog_release(&f);
    world_release(&w);
}
/* }}} */

/* {{{ static void test_rollback_restores_it */
static void test_rollback_restores_it(void)
{
    struct world w;
    struct fog live;
    struct fog snapshot;
    uint32_t eye;
    uint32_t at_head;

    TEST_CASE("a fog can be snapshotted and restored exactly");

    /*
     * What rollback does. Fog goes back with the world -- a full state restore --
     * because the alternative leaves a map holding a place reached in a turn that
     * never happened, contradicting the world every time anybody walks there
     * again.
     *
     * The cost is real and is not pretended away: the person still remembers the
     * corridor. They looked at it. Their map closes over a room they can describe
     * out loud.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);
    CHECK(fog_init(&live, &w, WC_ONE) == 1);
    CHECK(fog_init(&snapshot, &w, WC_ONE) == 1);

    eye = add_eye(&w, M(5), M(5));
    fog_fold(&live, &w, eye);

    at_head = fog_cells_seen(&live);
    CHECK(at_head > 0);

    /* The head of the turn. */
    CHECK(fog_copy(&snapshot, &live) == 1);

    /* The turn happens: the body walks into the far room and looks around. */
    world_thing(&w, eye)->x = M(40);
    world_thing(&w, eye)->y = M(10);
    fog_fold(&live, &w, eye);

    CHECK(fog_cells_seen(&live) > at_head);
    CHECK(fog_remembers(&live, M(40), M(10)) == 1);

    TEST_CASE("and taking the turn back closes the map over what was seen");

    CHECK(fog_copy(&live, &snapshot) == 1);

    CHECK_EQ(fog_cells_seen(&live), at_head);
    CHECK(fog_remembers(&live, M(40), M(10)) == 0);
    CHECK(fog_remembers(&live, M(5), M(5)) == 1);

    fog_release(&live);
    fog_release(&snapshot);
    world_release(&w);
}
/* }}} */

/* {{{ static void test_outside_the_grid */
static void test_outside_the_grid(void)
{
    struct world w;
    struct fog f;

    TEST_CASE("somewhere outside the map's extent is never remembered");

    /*
     * A real case rather than an error. Positions are not constrained by the
     * extent -- the extent is only what the fog was sized from.
     */
    CHECK(fixture_make_two_rooms(&w) == 1);
    CHECK(fog_init(&f, &w, WC_ONE) == 1);

    CHECK(fog_remembers(&f, M(-100), M(-100)) == 0);
    CHECK(fog_remembers(&f, M(9999), M(9999)) == 0);

    TEST_CASE("the grid covers the world's extent");

    CHECK(fog_cell_count(&f) > 0);
    CHECK(f.columns > 50);   /* the fixture is 50 metres wide */
    CHECK(f.rows > 20);      /* and 20 tall */

    fog_release(&f);
    world_release(&w);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_it_only_grows();
    test_it_does_not_remember_through_walls();
    test_it_agrees_with_sight();
    test_rollback_restores_it();
    test_outside_the_grid();

    return vtt_test_finish("045-test-fog");
}
/* }}} */
