/*
 * 108-demo-phase-12.c -- the table, as it is actually played.
 *
 * Four decisions made after the first eleven phases were built, each of which
 * turned out to be a design the documents did not have.
 *
 *   COMMANDING IS NOT AFFECTING. A forest commander owns their goblin patrol.
 *     The tavern's owner cannot move it and can absolutely poison its drink.
 *   NOTHING CHECKS WHO YOU ARE, and the remedy is the one a real table has:
 *     the host removes somebody and takes back what they did.
 *   THE CONTROLS ARE A DIAL, and its state is a picture of itself.
 *   AND PLAY RUNS CONTINUOUSLY, which was true all along and was called
 *     something that said otherwise.
 *
 * Run through ./run-phase-demo 12.
 */

#include "053-session.h"
#include "073-rules.h"
#include "070-scope.h"
#include "106-controls.h"
#include "037-fixture.h"
#include "035-worldfile.h"
#include "031-region.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define M(n) ((wcoord)((n) * WC_ONE))

#define RULESETS "/mnt/mtwo/programming/ai-stuff/my-own-custom-vtt/rulesets"

/* The sample game's catalogue. The server has no idea what any of these mean. */
#define POISON_THE_DRINK  1
#define SPRING_A_TRAPDOOR 2
#define REFUSE_THEM_MEAD  3
#define OFFER_A_BOUNTY    4

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

/* {{{ static uint32_t body_at */
static uint32_t body_at(struct world *w, wcoord x, wcoord y)
{
    uint32_t index = world_add_thing(w);
    struct thing *t = world_thing(w, index);

    t->x = x;
    t->y = y;
    t->facing = 0;
    t->sight_arc = 65535;
    t->sight_range = (uint32_t)M(30);
    t->radius = (uint16_t)(WC_ONE / 2);
    t->kind = 1;
    t->region = region_deepest_containing(w, x, y);

    return index;
}
/* }}} */

/* {{{ static void say_outcome */
static void say_outcome(const char *who, const char *what, uint16_t refusal,
                        struct ruleset *rules)
{
    if (refusal == REFUSED_NOT_AT_ALL) {
        printf("      %-16s %-24s allowed", who, what);

        if (rules != NULL && rules->last_refusal[0] != '\0') {
            printf("  -- %s", rules->last_refusal);
        }
        printf("\n");
        return;
    }

    if (refusal == REFUSED_BY_THE_RULES && rules != NULL) {
        printf("      %-16s %-24s refused  -- %s\n", who, what,
               rules->last_refusal);
        return;
    }

    printf("      %-16s %-24s refused  -- %s\n", who, what,
           refusal_sentence(refusal));
}
/* }}} */

/* {{{ static void the_patrol_in_the_tavern */
static void the_patrol_in_the_tavern(void)
{
    struct world w;
    struct pool *threads = pool_start(1);
    struct session s;
    struct ruleset rules;
    const char *why = NULL;
    uint32_t patrol;
    uint32_t innkeeper;
    uint32_t forest = 1;
    uint32_t tavern = 2;

    rule("A goblin patrol, in somebody else's tavern");

    fixture_make_two_rooms(&w);
    patrol = body_at(&w, M(5), M(5));
    innkeeper = body_at(&w, M(7), M(5));

    session_start(&s, &w, threads, 4207, 8, 5);
    sim_fit_to_world(&s.sim);

    if (!rules_load(&rules, &w, &s.sim, RULESETS "/a-game-with-rules", &why)) {
        printf("    the ruleset would not load: %s\n", why);
        return;
    }
    session_attach_rules(&s, &rules);

    scope_make_list(&w, forest, STYLE_ORDERED, &patrol, 1, "the forest");
    scope_make_list(&w, tavern, STYLE_ORDERED, &innkeeper, 1, "the tavern");

    printf("    The forest commands the patrol. The tavern commands its\n");
    printf("    innkeeper. The patrol walks in through the door.\n\n");

    printf("      who              what                     outcome\n");
    printf("      ---------------- ------------------------ -------\n");

    say_outcome("the forest", "move the patrol",
                session_command_from(&s, forest, VERB_ORDER_MOVE, patrol,
                                     M(8), M(8)), NULL);

    say_outcome("the tavern", "move the patrol",
                session_command_from(&s, tavern, VERB_ORDER_MOVE, patrol,
                                     M(2), M(2)), NULL);

    printf("\n    That is the rule that already existed, and for six phases it\n");
    printf("    was the only one -- so the tavern's owner could do NOTHING to a\n");
    printf("    patrol standing in their common room.\n\n");

    /* The tavern is told the patrol is there, which is what the gate reads. In a
     * running server that happens every beat, in the one function allowed to put
     * a body on a socket. */
    session_note_told(&s, tavern, patrol);

    printf("      who              what                     outcome\n");
    printf("      ---------------- ------------------------ -------\n");

    say_outcome("the tavern", "poison its drink",
                session_command_from(&s, tavern, VERB_INTERACT, patrol,
                                     POISON_THE_DRINK, 0), &rules);

    say_outcome("the tavern", "spring a trapdoor",
                session_command_from(&s, tavern, VERB_INTERACT, patrol,
                                     SPRING_A_TRAPDOOR, 0), &rules);

    say_outcome("the tavern", "refuse them mead",
                session_command_from(&s, tavern, VERB_INTERACT, patrol,
                                     REFUSE_THEM_MEAD, 0), &rules);

    say_outcome("the tavern", "offer a bounty",
                session_command_from(&s, tavern, VERB_INTERACT, patrol,
                                     OFFER_A_BOUNTY, 0), &rules);

    say_outcome("the tavern", "something else entirely",
                session_command_from(&s, tavern, VERB_INTERACT, patrol,
                                     8888, 0), &rules);

    printf("\n    Owning a piece is the right to MOVE it. It is not a fence\n");
    printf("    around it. And \"but you better explain how\" is the ruleset's\n");
    printf("    job, because the server has no idea what a drink is.\n");

    printf("\n    The bounty is there on purpose: it changes nothing about the\n");
    printf("    patrol at all. A system that only allowed attacks would have\n");
    printf("    quietly become a combat system.\n");

    rule("And you cannot act on what you were not told about");

    session_forget_what_was_told(&s, tavern);

    printf("      who              what                     outcome\n");
    printf("      ---------------- ------------------------ -------\n");
    say_outcome("the tavern", "poison its drink",
                session_command_from(&s, tavern, VERB_INTERACT, patrol,
                                     POISON_THE_DRINK, 0), &rules);

    printf("\n    The gate is what the outbound filter told you -- remembered,\n");
    printf("    not recomputed. Two answers to \"can this person see that\" is\n");
    printf("    how a permission model develops a hole nobody can find.\n");

    rules_release(&rules);
    session_release(&s);
    world_release(&w);
    pool_stop(threads);
}
/* }}} */

/* {{{ static void a_table_with_no_opinion */
static void a_table_with_no_opinion(void)
{
    struct world w;
    struct pool *threads = pool_start(1);
    struct session s;
    struct ruleset rules;
    const char *why = NULL;
    uint32_t thing;

    rule("The same attempt, at a table with no rules about it");

    fixture_make_two_rooms(&w);
    thing = body_at(&w, M(5), M(5));

    session_start(&s, &w, threads, 1, 8, 5);
    sim_fit_to_world(&s.sim);

    if (!rules_load(&rules, &w, &s.sim, RULESETS "/a-table-with-none", &why)) {
        printf("    the ruleset would not load: %s\n", why);
        return;
    }
    session_attach_rules(&s, &rules);
    session_note_told(&s, 1, thing);

    printf("      who              what                     outcome\n");
    printf("      ---------------- ------------------------ -------\n");
    say_outcome("anybody", "poison its drink",
                session_command_from(&s, 1, VERB_INTERACT, thing,
                                     POISON_THE_DRINK, 0), &rules);

    printf("\n    Refused, not allowed. The server does not know what an intent\n");
    printf("    means, and permitting something it cannot describe would be the\n");
    printf("    server having an opinion by the back door.\n");
    printf("\n    A table with no rules about poisoning drinks is a table where\n");
    printf("    you cannot poison a drink. That is correct rather than a gap.\n");

    rules_release(&rules);
    session_release(&s);
    world_release(&w);
    pool_stop(threads);
}
/* }}} */

/* {{{ static void removed_and_unwound */
static void removed_and_unwound(void)
{
    struct world troubled;
    struct world clean;
    struct pool *threads = pool_start(1);
    struct session with_them;
    struct session without_them;
    uint32_t theirs_a, ours_a, theirs_b, ours_b;
    uint32_t host = 1;
    uint32_t guest = 2;
    uint32_t taken[SESSION_MAX_EVICTIONS];
    uint32_t scope;
    uint32_t earliest;
    int beat;

    rule("Somebody removed, and what they did unwound");

    printf("    Nothing checks who anybody is. That is the decided answer, and\n");
    printf("    it is only honest because these two things exist.\n\n");

    fixture_make_two_rooms(&troubled);
    theirs_a = body_at(&troubled, M(4), M(4));
    ours_a = body_at(&troubled, M(6), M(4));

    fixture_make_two_rooms(&clean);
    theirs_b = body_at(&clean, M(4), M(4));
    ours_b = body_at(&clean, M(6), M(4));

    session_start(&with_them, &troubled, threads, 909, 16, 4);
    session_start(&without_them, &clean, threads, 909, 16, 4);
    sim_fit_to_world(&with_them.sim);
    sim_fit_to_world(&without_them.sim);

    scope = scope_make_list(&troubled, guest, STYLE_ORDERED, &theirs_a, 1, "guest");
    scope_make_list(&troubled, host, STYLE_ORDERED, &ours_a, 1, "host");
    world_scope(&troubled, 2)->flags |= SCOPE_MAY_EDIT_WORLD;

    /*
     * The comparison world has the guest too, holding the same scope and saying
     * nothing, and they are removed there as well.
     *
     * That is the honest comparison and the first attempt got it wrong: removing
     * somebody genuinely changes the world, because their scope is unheld and a
     * scope's holder is part of the world's checksum. Comparing "removed and
     * unwound" against "never existed" would have been comparing two different
     * questions -- and the demo would have reported a failure that was its own.
     */
    scope_make_list(&clean, guest, STYLE_ORDERED, &theirs_b, 1, "guest");
    scope_make_list(&clean, host, STYLE_ORDERED, &ours_b, 1, "host");
    world_scope(&clean, 2)->flags |= SCOPE_MAY_EDIT_WORLD;

    while (with_them.turn == 0) {
        session_tick(&with_them);
        session_tick(&without_them);
    }

    earliest = with_them.turn;

    for (beat = 0; beat < 12; beat++) {
        if (beat % 4 == 0) {
            session_command_from(&with_them, host, VERB_ORDER_MOVE, ours_a,
                                 M(9), M(7));
            session_command_from(&without_them, host, VERB_ORDER_MOVE, ours_b,
                                 M(9), M(7));

            /* Only in the troubled world. */
            session_command_from(&with_them, guest, VERB_ORDER_MOVE, theirs_a,
                                 M(2), M(9));
        }

        session_tick(&with_them);
        session_tick(&without_them);
    }

    printf("      a guest gave orders for %d beats\n", beat);
    printf("      the two worlds now differ:  %016llx  against  %016llx\n",
           (unsigned long long)world_hash(&troubled),
           (unsigned long long)world_hash(&clean));

    printf("\n    UNWIND FIRST, THEN REMOVE. That order matters and it is not\n");
    printf("    obvious: who holds a scope is world state, so unwinding past a\n");
    printf("    removal undoes the removal. Doing it the other way round leaves\n");
    printf("    the person back at the table.\n");

    printf("\n      their earliest command was in turn %u\n", (unsigned)earliest);

    if (session_expunge(&with_them, guest, earliest)) {
        printf("      replayed without it\n\n");
        printf("      %016llx  against  %016llx   %s\n",
               (unsigned long long)world_hash(&troubled),
               (unsigned long long)world_hash(&clean),
               world_hash(&troubled) == world_hash(&clean)
                   ? "IDENTICAL" : "DIFFERENT, WHICH IS WRONG");
    } else {
        printf("      it could not be unwound\n");
    }

    printf("\n    Now the host removes them.\n\n");

    printf("      the guest tries to remove the host:  %s\n",
           refusal_sentence(session_command_from(&with_them, guest, VERB_EVICT,
                                                 host, 0, 0)));
    printf("      the host tries to remove themselves: %s\n",
           refusal_sentence(session_command_from(&with_them, host, VERB_EVICT,
                                                 host, 0, 0)));
    printf("      the host removes the guest:          %s\n",
           refusal_sentence(session_command_from(&with_them, host, VERB_EVICT,
                                                 guest, 0, 0)));

    /* And in the comparison world, where the guest sat there and said nothing. */
    session_command_from(&without_them, host, VERB_EVICT, guest, 0, 0);

    printf("\n      their scope is now held by %u, which means nobody\n",
           (unsigned)world_scope(&troubled, scope)->viewer);
    printf("      their body still exists, because removing a person is not\n");
    printf("      removing a character\n");
    printf("      %u seat queued for the server, which owns the sockets\n",
           (unsigned)session_take_evictions(&with_them, taken,
                                            SESSION_MAX_EVICTIONS));
    printf("\n      and the two worlds are still  %s\n",
           world_hash(&troubled) == world_hash(&clean)
               ? "IDENTICAL" : "DIFFERENT, WHICH IS WRONG");

    printf("\n    Compared against a world where the guest sat there, said\n");
    printf("    nothing, and was removed just the same -- by checksum, because\n");
    printf("    \"it looks about right\" is not a comparison. The host's four\n");
    printf("    orders survived exactly.\n");
    printf("\n    Writing this demo found the ordering. Removing somebody\n");
    printf("    genuinely changes the world -- their scope is unheld, and who\n");
    printf("    holds a scope is part of the checksum -- so a rollback that\n");
    printf("    reaches back past the removal puts them back at the table.\n");
    printf("\n    Nothing was wrong with either piece. The order of the two is\n");
    printf("    a fact about how they compose, and it was not written down\n");
    printf("    anywhere until a demo tried them in the wrong order.\n");

    {
        uint32_t i;
        uint32_t theirs = 0;
        uint32_t marked = 0;

        for (i = 0; i < with_them.log.count; i++) {
            if (with_them.log.entries[i].viewer == guest) {
                theirs++;
                if (with_them.log.entries[i].refusal != REFUSED_NOT_AT_ALL) {
                    marked++;
                }
            }
        }

        printf("\n      %u of their commands are still in the log, %u marked\n",
               (unsigned)theirs, (unsigned)marked);
    }

    printf("      A log that quietly omits the parts somebody regretted is not\n");
    printf("      a log.\n");

    printf("\n    What this does not solve: they can knock again. There is no\n");
    printf("    ban list and no way to have one without the identity this\n");
    printf("    project has decided not to have.\n");

    session_release(&with_them);
    session_release(&without_them);
    world_release(&troubled);
    world_release(&clean);
    pool_stop(threads);
}
/* }}} */

/* {{{ static void the_dial */
static void the_dial(void)
{
    struct dial d;
    char picture[160];
    char said[160];
    uint8_t step;

    rule("The dial, and a picture of where it points");

    printf("    One keyboard genuinely cannot drive four bodies. The three\n");
    printf("    obvious answers are each half of what somebody wants. This is\n");
    printf("    all of it: a command is (which units) x (which way) x (how far)\n");
    printf("    x (what to do), and the first three are state that keys change.\n");

    dial_init(&d);

    for (step = 0; step < 5u; step++) {
        wcoord x = 0;
        wcoord y = 0;

        printf("\n    %s\n\n", dial_sentence(&d, 4, said, sizeof(said)));

        {
            const char *at = dial_diagram(&d, picture, sizeof(picture));
            const char *line = at;

            while (*line != '\0') {
                const char *stop = strchr(line, '\n');

                printf("      %.*s\n", stop != NULL ? (int)(stop - line)
                                                    : (int)strlen(line), line);
                if (stop == NULL) {
                    break;
                }
                line = stop + 1;
            }
        }

        dial_resolve(&d, M(20), M(20), &x, &y);
        printf("      a body at 20,20 is ordered to %d,%d metres\n",
               (int)(x / WC_ONE), (int)(y / WC_ONE));

        /* Turn it. */
        dial_turn_aim(&d, 2);
        dial_turn_reach(&d, (step % 2 == 0) ? 1 : -1);

        if (step == 2) {
            dial_cycle_choice(&d, 4);
        }
    }

    printf("\n    The diagram is drawn FROM the dial rather than from a copy of\n");
    printf("    it, so it cannot disagree with the state it is showing. That is\n");
    printf("    the third time this project has landed on the same idea from a\n");
    printf("    different direction -- the engraving, the paintbrush, and now\n");
    printf("    this. Make the state its own display.\n");

    printf("\n    And none of it reaches the server. The dials resolve into a\n");
    printf("    point and an ordinary order goes out, which is a verb the\n");
    printf("    server has had since phase three. A server that knew what\n");
    printf("    \"north-east, far\" meant would be a server with an opinion\n");
    printf("    about how people play.\n");
}
/* }}} */

/* {{{ static void play_runs_continuously */
static void play_runs_continuously(void)
{
    struct world w;
    struct pool *threads = pool_start(1);
    struct session s;
    uint32_t body;
    int beat;

    rule("And nothing was ever waiting");

    printf("    A field used to be called the length of a turn's window, and a\n");
    printf("    window is a thing you wait in. Nothing in this program has ever\n");
    printf("    waited: commands are accepted on every beat and applied on the\n");
    printf("    beat they arrive.\n\n");

    fixture_make_two_rooms(&w);
    body = body_at(&w, M(4), M(4));

    session_start(&s, &w, threads, 1, 8, 5);
    sim_fit_to_world(&s.sim);
    scope_make_list(&w, 1, STYLE_ORDERED, &body, 1, "somebody");

    printf("      beat  turn  a command sent on this beat\n");
    printf("      ----  ----  ---------------------------\n");

    for (beat = 0; beat < 12; beat++) {
        uint16_t answer = session_command_from(&s, 1, VERB_ORDER_MOVE, body,
                                               M(6 + (beat % 4)), M(6));

        printf("      %4d  %4u  %s\n", beat, (unsigned)s.turn,
               refusal_sentence(answer));

        session_tick(&s);
    }

    printf("\n    Every one of them accepted, on the beat it arrived, across\n");
    printf("    three turn boundaries. A turn is a place you can go back to.\n");
    printf("    That is the whole of what it is, and the field is called the\n");
    printf("    beats between checkpoints now.\n");

    printf("\n    Two open questions dissolved when the noun was corrected, and\n");
    printf("    three plausible answers had been written down for one of them.\n");
    printf("    All three were answers about a thing that does not exist.\n");

    session_release(&s);
    world_release(&w);
    pool_stop(threads);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    printf("\n");
    printf("  ===============================================================\n");
    printf("   PHASE TWELVE -- the table, as it is actually played\n");
    printf("  ===============================================================\n");

    the_patrol_in_the_tavern();
    a_table_with_no_opinion();
    removed_and_unwound();
    the_dial();
    play_runs_continuously();

    printf("\n  ===============================================================\n");
    printf("   Four answers, and every one of them was a design the documents\n");
    printf("   did not have.\n");
    printf("  ===============================================================\n\n");

    return 0;
}
/* }}} */
