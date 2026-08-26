/*
 * 072-demo-phase-6.c -- four seats on one dial, in the same room at once.
 *
 * Phase six claims that "player", "commander", "the tavern" and "GM" are four
 * positions on one dial rather than four systems. The way to show that is to sit
 * all four down together and print the same table for each of them.
 *
 * No browser. The claim is about permission, and a browser proves nothing about
 * permission.
 *
 * Run through ./run-phase-demo 6.
 */

#include "070-scope.h"
#include "059-outbound.h"
#include "037-fixture.h"
#include "033-validate.h"
#include "031-region.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ static double wall_now */
static double wall_now(void)
{
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (double)now.tv_sec + ((double)now.tv_nsec / 1000000000.0);
}
/* }}} */

/* {{{ static void rule */
static void rule(const char *title)
{
    size_t i;
    size_t width = strlen(title);

    printf("\n  %s\n  ", title);
    for (i = 0; i < width; i++) {
        printf("-");
    }
    printf("\n\n");
}
/* }}} */

/* {{{ static uint32_t add_body */
static uint32_t add_body(struct world *w, wcoord x, wcoord y, int with_eyes)
{
    uint32_t index = world_add_thing(w);
    struct thing *t = world_thing(w, index);

    t->x = x;
    t->y = y;
    t->radius = (uint16_t)(WC_ONE / 2);
    t->kind = with_eyes ? 1 : 2;
    t->region = region_deepest_containing(w, x, y);

    if (with_eyes) {
        t->sight_arc = 65535;
        t->sight_range = (uint32_t)M(30);
    }

    return index;
}
/* }}} */

/* {{{ static const char *name_of */
static const char *name_of(const struct world *w, uint32_t scope, char *into)
{
    uint32_t length = 0;
    const char *text = string_pool_read(&w->strings,
                                        world_scope_const(w, scope)->name_offset,
                                        &length);

    memcpy(into, text, length);
    into[length] = '\0';

    return into;
}
/* }}} */

/* {{{ int main */
int main(void)
{
    struct world w;
    struct pool *pool;
    struct session session;
    struct viewer_set viewers;
    struct validation_failure failure;
    char message[256];
    char label[64];

    uint32_t west;
    uint32_t east;

    uint32_t player_body;
    uint32_t party[4];
    uint32_t cups[3];
    uint32_t barman;

    uint32_t seats[4];
    uint32_t viewer_of[4] = { 1, 2, 3, 4 };
    uint32_t i;

    printf("\n");
    printf("  ===========================================================\n");
    printf("   PHASE SIX -- Control is a dial\n");
    printf("  ===========================================================\n");
    printf("\n");
    printf("  Four seats, one server, one room. The claim is that these are\n");
    printf("  four positions on one dial rather than four systems, so every\n");
    printf("  one of them below is printed with the same columns.\n");

    fixture_make_two_rooms(&w);

    west = region_deepest_containing(&w, M(15), M(5));
    east = region_deepest_containing(&w, M(40), M(10));

    /* One body somebody drives with the keys. */
    player_body = add_body(&w, M(6), M(6), 1);

    /* Four bodies somebody gives orders to. */
    for (i = 0; i < 4; i++) {
        party[i] = add_body(&w, M(12) + (wcoord)(i * WC_ONE), M(16), 1);
    }

    /* And a room full of crockery, plus somebody to stand behind the bar. */
    for (i = 0; i < 3; i++) {
        cups[i] = add_body(&w, M(38) + (wcoord)(i * WC_ONE), M(14), 0);
    }
    barman = add_body(&w, M(44), M(14), 1);

    /* --- The four seats, as configuration and nothing else. --- */

    seats[0] = scope_make_list(&w, viewer_of[0], STYLE_DRIVEN,
                               &player_body, 1, "a player");

    seats[1] = scope_make_list(&w, viewer_of[1], STYLE_ORDERED,
                               party, 4, "a commander");

    seats[2] = scope_make_region(&w, viewer_of[2], STYLE_ORDERED, east,
                                 SCOPE_SEES_REGION, "the tavern");

    seats[3] = scope_make_region(&w, viewer_of[3], STYLE_ORDERED, 0,
                                 SCOPE_SEES_ALL | SCOPE_MAY_EDIT_WORLD |
                                 SCOPE_MAY_SEE_HIDDEN, "a GM");

    if (!world_validate(&w, &failure)) {
        printf("\n  The world does not validate: %s\n",
               validation_failure_describe(&failure, message, sizeof(message)));
        world_release(&w);
        return 1;
    }

    pool = pool_start(2);
    session_start(&session, &w, pool, 4207, 8, 10);
    viewer_set_init(&viewers, 8);

    for (i = 0; i < 4; i++) {
        uint32_t v = viewer_add(&viewers, &w, WC_ONE);
        viewer_at(&viewers, v)->state = VIEWER_CONNECTED;
    }

    /* --------------------------------------------------------------------- */
    rule("The dial, as one table");

    printf("    %-14s %-10s %-9s %7s %8s\n",
           "seat", "membership", "style", "things", "eyes");

    for (i = 0; i < 4; i++) {
        const struct scope *s = world_scope_const(&w, seats[i]);
        struct viewpoint from;
        uint32_t eyes[VIEWPOINT_MAX_EYES];

        viewpoint_gather(&from, &w, viewer_of[i]);

        printf("    %-14s %-10s %-9s %7u %8u\n",
               name_of(&w, seats[i], label),
               (s->membership == SCOPE_LIST) ? "a list" : "a region",
               (s->style == STYLE_DRIVEN) ? "driven" : "ordered",
               scope_size(&w, seats[i]),
               scope_eyes_of_viewer(&w, viewer_of[i], eyes, VIEWPOINT_MAX_EYES));
    }

    printf("\n");
    printf("    Two rules and one axis. \"One body\" is a list of length one and\n");
    printf("    \"the map\" is a region that is the whole map -- there is no third\n");
    printf("    rule, and style does not constrain membership. That is why a GM\n");
    printf("    can drive one goblin with the keys and a player with a party of\n");
    printf("    four gets the strategy interface.\n");

    /* --------------------------------------------------------------------- */
    rule("The tavern, which needed no new code");

    printf("    The tavern's holder commands %u things: %u coffee cups and a\n",
           scope_size(&w, seats[2]), 3);
    printf("    barman, plus whatever else is standing in that room.\n\n");

    printf("    Moving a cup goes through the same membership question, the same\n");
    printf("    gauntlet, the same motion pass, and the same filter as a player\n");
    printf("    walking down a corridor -- because a coffee cup IS a thing record\n");
    printf("    with a position and an owning scope.\n\n");

    {
        uint16_t moved = session_command_from(&session, viewer_of[2],
                                              VERB_ORDER_MOVE, cups[0],
                                              (int32_t)M(41), (int32_t)M(16));

        printf("      the tavern moves a cup            -> %s\n",
               refusal_sentence(moved));
    }

    {
        uint16_t moved = session_command_from(&session, viewer_of[2],
                                              VERB_ORDER_MOVE, barman,
                                              (int32_t)M(45), (int32_t)M(15));

        printf("      the tavern moves the barman       -> %s\n",
               refusal_sentence(moved));
    }

    printf("\n");
    printf("    If this had required a prop system beside the creature system,\n");
    printf("    one of the earlier issues would have been wrong. It did not.\n");

    /* --------------------------------------------------------------------- */
    rule("And the gauntlet refusing across seats");

    {
        uint16_t r;

        r = session_command_from(&session, viewer_of[0], VERB_ORDER_MOVE,
                                 cups[1], (int32_t)M(39), (int32_t)M(15));
        printf("      the player tries to move a cup    -> %s\n",
               refusal_sentence(r));

        r = session_command_from(&session, viewer_of[2], VERB_DRIVE,
                                 player_body, 0, WC_ONE);
        printf("      the tavern tries to drive them    -> %s\n",
               refusal_sentence(r));

        r = session_command_from(&session, viewer_of[0], VERB_ORDER_MOVE,
                                 player_body, (int32_t)M(8), (int32_t)M(8));
        printf("      the player orders their own body  -> %s\n",
               refusal_sentence(r));

        r = session_command_from(&session, viewer_of[1], VERB_DRIVE,
                                 party[0], 0, WC_ONE);
        printf("      the commander drives one of four  -> %s\n",
               refusal_sentence(r));
    }

    printf("\n");
    printf("    The second-to-last one is worth reading twice. The player owns\n");
    printf("    that body and is still refused, because their seat is DRIVEN and\n");
    printf("    they asked for an order. Somebody whose keys do nothing needs to\n");
    printf("    be told it is a category error rather than a broken keyboard.\n");

    /* --------------------------------------------------------------------- */
    rule("A body crossing a boundary changes hands");

    {
        uint32_t patrol = add_body(&w, M(40), M(10), 0);
        uint32_t before;
        uint32_t after;

        sim_fit_to_world(&session.sim);

        before = scope_of_viewer_containing(&w, viewer_of[2], patrol);

        printf("    A patrol stands in the east room, which the tavern holds.\n");
        printf("      contained by the tavern's scope: %s\n",
               (before != 0) ? "yes" : "no");

        world_thing(&w, patrol)->x = M(15);
        world_thing(&w, patrol)->y = M(5);
        world_thing(&w, patrol)->region =
            region_deepest_containing(&w, M(15), M(5));

        after = scope_of_viewer_containing(&w, viewer_of[2], patrol);

        printf("\n    It walks into the west room.\n");
        printf("      contained by the tavern's scope: %s\n",
               (after != 0) ? "yes" : "no");

        printf("\n");
        printf("    It changed hands at the doorway, because region membership is\n");
        printf("    read from where a body IS. That is what the mechanism does.\n");
        printf("    Whether anybody wants it is open question 6.1 -- the tavern's\n");
        printf("    holder may have been walking that patrol for ten minutes with\n");
        printf("    an intention, and having it taken away at a threshold is a\n");
        printf("    strange experience. It is shown rather than decided.\n");

        (void)west;
    }

    /* --------------------------------------------------------------------- */
    rule("Handing a seat over");

    {
        uint16_t r;

        printf("    The GM gives the tavern to the player.\n\n");

        r = session_command_from(&session, viewer_of[3], VERB_GIVE_SCOPE, 0,
                                 (int32_t)seats[2], (int32_t)viewer_of[0]);
        printf("      the GM hands it over              -> %s\n",
               refusal_sentence(r));

        r = session_command_from(&session, viewer_of[2], VERB_ORDER_MOVE,
                                 cups[2], (int32_t)M(39), (int32_t)M(13));
        printf("      the old holder moves a cup        -> %s\n",
               refusal_sentence(r));

        r = session_command_from(&session, viewer_of[0], VERB_ORDER_MOVE,
                                 cups[2], (int32_t)M(39), (int32_t)M(13));
        printf("      the new holder moves a cup        -> %s\n",
               refusal_sentence(r));

        r = session_command_from(&session, viewer_of[1], VERB_GIVE_SCOPE, 0,
                                 (int32_t)seats[2], (int32_t)viewer_of[1]);
        printf("      the commander tries to take it    -> %s\n",
               refusal_sentence(r));

        /* Put it back, so the costs below measure what the table above described. */
        session_command_from(&session, viewer_of[3], VERB_GIVE_SCOPE, 0,
                             (int32_t)seats[2], (int32_t)viewer_of[2]);
    }

    printf("\n");
    printf("    The standing orders went with it. A body walking somewhere keeps\n");
    printf("    walking, so the new holder inherits an intention nobody told them\n");
    printf("    about -- which is what falls out of doing nothing, and is a\n");
    printf("    default rather than a decision. Open question 6.3.\n");

    /* --------------------------------------------------------------------- */
    rule("What each seat costs to look out of");

    printf("    %-14s %8s %14s\n", "seat", "sweeps", "microseconds");

    for (i = 0; i < 4; i++) {
        struct viewpoint from;
        double started;
        const int rounds = 200;
        int round;

        viewpoint_gather(&from, &w, viewer_of[i]);

        started = wall_now();
        for (round = 0; round < rounds; round++) {
            uint32_t thing;
            for (thing = 1; thing < world_thing_count(&w); thing++) {
                outbound_may_send_thing(&session, &viewers, viewer_of[i],
                                        &from, thing);
            }
        }

        printf("    %-14s %8u %14.1f\n",
               name_of(&w, seats[i], label),
               from.sees_all ? 0 : from.body_count,
               (wall_now() - started) * 1000000.0 / (double)rounds);
    }

    printf("\n");
    printf("    The GM runs no sweeps at all -- SEES_ALL skips the geometry\n");
    printf("    rather than running it and winning. Without that flag a GM would\n");
    printf("    sweep once for every creature on the map, every beat, which is\n");
    printf("    why it is a flag rather than a quantity of patience.\n");
    printf("\n");
    printf("    The tavern has one pair of eyes -- the barman's -- and does not\n");
    printf("    have to use them, because SEES_REGION answers the same question\n");
    printf("    about a whole room before any sweep is reached. That is why its\n");
    printf("    cost sits near the GM's rather than near the player's.\n");
    printf("\n");
    printf("    Whether it SHOULD -- whether somebody playing a building ought to\n");
    printf("    be blind to the corner their crockery cannot see -- is a question\n");
    printf("    about what that feels like, not about cost.\n");

    printf("\n");
    printf("  Next: phase seven, where a ruleset gets to have opinions.\n");
    printf("\n");

    session_release(&session);
    viewer_set_release(&viewers);
    world_release(&w);
    pool_stop(pool);

    return 0;
}
/* }}} */
