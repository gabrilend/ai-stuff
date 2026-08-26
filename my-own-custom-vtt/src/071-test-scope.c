/*
 * 071-test-scope.c -- is the dial one mechanism, or four?
 *
 * That is what these check. If a region scope needs a code path a list scope did
 * not, or if a tavern needs something a player did not, then the dial has
 * collapsed back into a list of roles and something earlier was wrong.
 */

#include "020-test-harness.h"
#include "070-scope.h"
#include "037-fixture.h"
#include "031-region.h"
#include "051-commandlog.h"
#include "033-validate.h"
#include <string.h>

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static uint32_t add_body */
static uint32_t add_body(struct world *w, wcoord x, wcoord y)
{
    uint32_t index = world_add_thing(w);
    struct thing *t = world_thing(w, index);

    t->x = x;
    t->y = y;
    t->radius = (uint16_t)(WC_ONE / 2);
    t->region = region_deepest_containing(w, x, y);

    return index;
}
/* }}} */

/* {{{ static void test_a_list_of_one */
static void test_a_list_of_one(void)
{
    struct world w;
    uint32_t body;
    uint32_t other;
    uint32_t scope;

    TEST_CASE("one body, driven -- the simplest position on the dial");

    fixture_make_two_rooms(&w);
    body = add_body(&w, M(5), M(5));
    other = add_body(&w, M(15), M(15));

    scope = scope_make_list(&w, 7, STYLE_DRIVEN, &body, 1, "a player");

    CHECK(scope != 0);
    CHECK_EQ(scope_contains(&w, scope, body), 1);
    CHECK_EQ(scope_contains(&w, scope, other), 0);
    CHECK_EQ(scope_size(&w, scope), 1);

    TEST_CASE("held by exactly one viewer, which is what makes 'who moved that' answerable");

    CHECK_EQ(scope_is_held_by(&w, scope, 7), 1);
    CHECK_EQ(scope_is_held_by(&w, scope, 8), 0);
    CHECK_EQ(scope_is_held_by(&w, scope, 0), 0);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_a_list_of_several */
static void test_a_list_of_several(void)
{
    struct world w;
    uint32_t party[4];
    uint32_t stranger;
    uint32_t scope;
    int i;

    TEST_CASE("a handful of bodies, ordered -- the same rule, a longer slice");

    fixture_make_two_rooms(&w);

    for (i = 0; i < 4; i++) {
        party[i] = add_body(&w, M(4) + (wcoord)(i * WC_ONE), M(6));
    }
    stranger = add_body(&w, M(15), M(15));

    scope = scope_make_list(&w, 3, STYLE_ORDERED, party, 4, "a commander");

    CHECK_EQ(scope_size(&w, scope), 4);

    for (i = 0; i < 4; i++) {
        CHECK_EQ(scope_contains(&w, scope, party[i]), 1);
    }

    CHECK_EQ(scope_contains(&w, scope, stranger), 0);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_a_region */
static void test_a_region(void)
{
    struct world w;
    uint32_t inside;
    uint32_t outside;
    uint32_t scope;
    uint32_t west_room;

    TEST_CASE("a region, and everything standing in it");

    fixture_make_two_rooms(&w);

    west_room = region_deepest_containing(&w, M(15), M(5));
    CHECK(west_room != 0);

    inside = add_body(&w, M(15), M(5));
    outside = add_body(&w, M(40), M(10));

    scope = scope_make_region(&w, 9, STYLE_ORDERED, west_room, 0, "the west room");

    CHECK_EQ(scope_contains(&w, scope, inside), 1);
    CHECK_EQ(scope_contains(&w, scope, outside), 0);

    TEST_CASE("including whatever is nested inside it");

    /*
     * The cellar is inside the west room, so a scope over the room covers it
     * without listing it. That is the whole reason regions nest through a single
     * parent index.
     */
    {
        uint32_t in_cellar = add_body(&w, M(4), M(4));
        uint32_t cellar = region_deepest_containing(&w, M(4), M(4));

        CHECK(cellar != west_room);
        CHECK_EQ(region_is_within(&w, cellar, west_room), 1);
        CHECK_EQ(scope_contains(&w, scope, in_cellar), 1);
    }

    TEST_CASE("a region of zero is the whole map, with no special case");

    {
        uint32_t everything = scope_make_region(&w, 9, STYLE_ORDERED, 0,
                                                SCOPE_SEES_ALL, "a GM");

        CHECK_EQ(scope_contains(&w, everything, inside), 1);
        CHECK_EQ(scope_contains(&w, everything, outside), 1);
    }

    world_release(&w);
}
/* }}} */

/* {{{ static void test_the_tavern_needs_no_new_code */
static void test_the_tavern_needs_no_new_code(void)
{
    struct world w;
    uint32_t cup;
    uint32_t goblin;
    uint32_t tavern_scope;
    uint32_t player_scope;
    uint32_t room;

    TEST_CASE("a coffee cup and a goblin go through the same machinery");

    /*
     * THE TEST THIS PHASE EXISTS TO PASS.
     *
     * If somebody playing a building needs a code path a player walking down a
     * corridor did not, the dial has collapsed back into a list of roles and one
     * of the earlier issues was wrong.
     */
    fixture_make_two_rooms(&w);
    room = region_deepest_containing(&w, M(15), M(5));

    cup = add_body(&w, M(14), M(5));
    world_thing(&w, cup)->kind = 2;
    /* No sight, no blocking, no ruleset sheet. A cup. */

    goblin = add_body(&w, M(16), M(6));
    world_thing(&w, goblin)->kind = 1;
    world_thing(&w, goblin)->sight_range = (uint32_t)M(20);
    world_thing(&w, goblin)->sight_arc = 65535;

    tavern_scope = scope_make_region(&w, 4, STYLE_ORDERED, room,
                                     SCOPE_SEES_REGION, "the tavern");

    /* The same question answers for both, because they are the same record. */
    CHECK_EQ(scope_contains(&w, tavern_scope, cup), 1);
    CHECK_EQ(scope_contains(&w, tavern_scope, goblin), 1);

    TEST_CASE("and a player elsewhere commands neither of them");

    {
        uint32_t elsewhere = add_body(&w, M(40), M(10));
        player_scope = scope_make_list(&w, 5, STYLE_DRIVEN, &elsewhere, 1, "a player");

        CHECK_EQ(scope_contains(&w, player_scope, cup), 0);
        CHECK_EQ(scope_of_viewer_containing(&w, 5, cup), 0);
        CHECK_EQ(scope_of_viewer_containing(&w, 4, cup), tavern_scope);
    }

    world_release(&w);
}
/* }}} */

/* {{{ static void test_style_is_a_separate_axis */
static void test_style_is_a_separate_axis(void)
{
    struct world w;
    uint32_t body;
    uint32_t driven;
    uint32_t ordered;

    TEST_CASE("driving and ordering are refused across each other");

    fixture_make_two_rooms(&w);
    body = add_body(&w, M(5), M(5));

    driven = scope_make_list(&w, 1, STYLE_DRIVEN, &body, 1, "keys");
    ordered = scope_make_list(&w, 2, STYLE_ORDERED, &body, 1, "orders");

    CHECK_EQ(scope_style_allows(&w, driven, VERB_DRIVE), 1);
    CHECK_EQ(scope_style_allows(&w, driven, VERB_ORDER_MOVE), 0);

    CHECK_EQ(scope_style_allows(&w, ordered, VERB_ORDER_MOVE), 1);
    CHECK_EQ(scope_style_allows(&w, ordered, VERB_DRIVE), 0);

    TEST_CASE("but both turn and both stop");

    CHECK_EQ(scope_style_allows(&w, driven, VERB_ORDER_FACE), 1);
    CHECK_EQ(scope_style_allows(&w, ordered, VERB_ORDER_FACE), 1);
    CHECK_EQ(scope_style_allows(&w, driven, VERB_ORDER_STOP), 1);
    CHECK_EQ(scope_style_allows(&w, ordered, VERB_ORDER_STOP), 1);

    TEST_CASE("style does not constrain membership, or the dial has collapsed");

    /*
     * A GM driving one goblin with the keys is legal. So is a player with a
     * party of four getting the strategy interface. The moment those two axes
     * constrain each other, four positions become four roles.
     */
    {
        uint32_t gm_driving = scope_make_region(&w, 6, STYLE_DRIVEN, 0,
                                                SCOPE_SEES_ALL, "a GM at the keys");

        CHECK_EQ(scope_style_allows(&w, gm_driving, VERB_DRIVE), 1);
        CHECK_EQ(scope_contains(&w, gm_driving, body), 1);
    }

    world_release(&w);
}
/* }}} */

/* {{{ static void test_the_patrol_crossing */
static void test_the_patrol_crossing(void)
{
    struct world w;
    uint32_t patrol;
    uint32_t west_scope;
    uint32_t east_scope;
    uint32_t west;
    uint32_t east;

    TEST_CASE("a body changes hands the moment it crosses a boundary");

    /*
     * OPEN QUESTION 6.1, made into a test rather than a decision.
     *
     * Region membership is evaluated from the thing's CURRENT region, so a
     * patrol walking out of one commander's ground and into another's changes
     * hands on the beat it crosses.
     *
     * That is mechanically what happens. Whether anybody WANTS it is not settled
     * -- the first commander may have been walking that patrol for ten minutes
     * with an intention, and having it taken away at a doorway is a strange
     * experience. This pins the behaviour so that changing it later is a
     * deliberate act with a failing test attached.
     */
    fixture_make_two_rooms(&w);

    west = region_deepest_containing(&w, M(15), M(5));
    east = region_deepest_containing(&w, M(40), M(10));
    CHECK(west != east);

    patrol = add_body(&w, M(15), M(5));

    west_scope = scope_make_region(&w, 1, STYLE_ORDERED, west, 0, "the west room");
    east_scope = scope_make_region(&w, 2, STYLE_ORDERED, east, 0, "the east room");

    CHECK_EQ(scope_contains(&w, west_scope, patrol), 1);
    CHECK_EQ(scope_contains(&w, east_scope, patrol), 0);

    /* It walks through the corridor into the other room. */
    world_thing(&w, patrol)->x = M(40);
    world_thing(&w, patrol)->y = M(10);
    world_thing(&w, patrol)->region = region_deepest_containing(&w, M(40), M(10));

    CHECK_EQ(scope_contains(&w, west_scope, patrol), 0);
    CHECK_EQ(scope_contains(&w, east_scope, patrol), 1);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_several_scopes_one_viewer */
static void test_several_scopes_one_viewer(void)
{
    struct world w;
    uint32_t character;
    uint32_t in_forest;
    uint32_t forest;
    uint32_t eyes[8];
    uint32_t found;

    TEST_CASE("a player who is also a commander holds two scopes");

    fixture_make_two_rooms(&w);
    forest = region_deepest_containing(&w, M(40), M(10));

    character = add_body(&w, M(5), M(5));
    world_thing(&w, character)->sight_range = (uint32_t)M(20);
    world_thing(&w, character)->sight_arc = 65535;

    in_forest = add_body(&w, M(42), M(10));
    world_thing(&w, in_forest)->sight_range = (uint32_t)M(20);
    world_thing(&w, in_forest)->sight_arc = 65535;

    scope_make_list(&w, 11, STYLE_DRIVEN, &character, 1, "Aelfwine");
    scope_make_region(&w, 11, STYLE_ORDERED, forest, 0, "the east room");

    CHECK_EQ(scope_of_viewer_containing(&w, 11, character) != 0, 1);
    CHECK_EQ(scope_of_viewer_containing(&w, 11, in_forest) != 0, 1);

    TEST_CASE("and sees from every body in both, gathered once each");

    found = scope_eyes_of_viewer(&w, 11, eyes, 8);

    CHECK_EQ(found, 2);

    TEST_CASE("a body in two of their scopes is swept once, not twice");

    /*
     * The eyes are gathered by walking things rather than scopes, precisely so
     * that a body in two of somebody's scopes does not cost two sweeps. Sweeping
     * is the expensive pass.
     */
    scope_make_list(&w, 11, STYLE_ORDERED, &in_forest, 1, "also the goblin");

    found = scope_eyes_of_viewer(&w, 11, eyes, 8);
    CHECK_EQ(found, 2);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_unheld_is_normal */
static void test_unheld_is_normal(void)
{
    struct world w;
    uint32_t body;
    uint32_t scope;

    TEST_CASE("a scope nobody holds is a normal thing, not an error");

    /*
     * The forest exists whether or not anybody is playing it tonight.
     */
    fixture_make_two_rooms(&w);
    body = add_body(&w, M(5), M(5));

    scope = scope_make_list(&w, 0, STYLE_ORDERED, &body, 1, "the forest");

    CHECK(scope != 0);
    CHECK_EQ(scope_contains(&w, scope, body), 1);
    CHECK_EQ(scope_is_held_by(&w, scope, 0), 0);
    CHECK_EQ(scope_of_viewer_containing(&w, 0, body), 0);

    TEST_CASE("and it can be handed to somebody");

    world_scope(&w, scope)->viewer = 12;

    CHECK_EQ(scope_is_held_by(&w, scope, 12), 1);
    CHECK_EQ(scope_of_viewer_containing(&w, 12, body), scope);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_scopes_are_world_state */
static void test_scopes_are_world_state(void)
{
    struct world source;
    struct world copy;
    uint32_t body;
    uint32_t scope;
    struct validation_failure failure;
    char message[256];

    TEST_CASE("a scope survives a snapshot, because who commands what is world state");

    fixture_make_two_rooms(&source);
    body = add_body(&source, M(5), M(5));
    scope = scope_make_list(&source, 3, STYLE_DRIVEN, &body, 1, "a player");

    fixture_make_two_rooms(&copy);
    CHECK(world_copy(&copy, &source) == 1);

    CHECK_EQ(world_scope_count(&copy), world_scope_count(&source));
    CHECK_EQ(world_scope_const(&copy, scope)->viewer, 3);
    CHECK_EQ(scope_contains(&copy, scope, body), 1);

    TEST_CASE("and a world with scopes still validates");

    if (!world_validate(&source, &failure)) {
        vtt_report_failure(__FILE__, __LINE__,
            validation_failure_describe(&failure, message, sizeof(message)));
    } else {
        CHECK(1);
    }

    TEST_CASE("a member pointing at nothing is caught");

    {
        struct world broken;
        uint32_t b;
        uint32_t sc;

        fixture_make_two_rooms(&broken);
        b = add_body(&broken, M(5), M(5));
        sc = scope_make_list(&broken, 1, STYLE_DRIVEN, &b, 1, "x");

        /* Point the member at a thing that does not exist. */
        {
            uint32_t first = world_scope(&broken, sc)->first_member;
            uint32_t *slot = block_at(&broken.members, first);
            *slot = 9999;
        }

        CHECK_EQ(world_validate(&broken, &failure), 0);
        CHECK_EQ(strcmp(failure.block, "scopes"), 0);

        world_release(&broken);
    }

    world_release(&source);
    world_release(&copy);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_a_list_of_one();
    test_a_list_of_several();
    test_a_region();
    test_the_tavern_needs_no_new_code();
    test_style_is_a_separate_axis();
    test_the_patrol_crossing();
    test_several_scopes_one_viewer();
    test_unheld_is_normal();
    test_scopes_are_world_state();

    return vtt_test_finish("071-test-scope");
}
/* }}} */
