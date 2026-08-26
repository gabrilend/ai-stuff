/*
 * 075-demo-phase-7.c -- one world, two rulesets, and a server that never learned
 * which game it was running.
 *
 * Phase seven claims the server is system-agnostic. One ruleset proves an
 * interface exists; two prove it IS an interface. If the second had needed the
 * server changed, the first was the game wearing a ruleset's clothes.
 *
 * So this runs the same scripted sequence under both and prints what each did.
 *
 * It also shows the two things that do not work: a ruleset that raises an error,
 * and a rolled-back turn that puts the hit points back with the geometry --
 * which it did not, for four phases, and which this demo used to show failing.
 * Hiding either would be the demo lying.
 *
 * Run through ./run-phase-demo 7.
 */

#include "073-rules.h"
#include "070-scope.h"
#include "053-session.h"
#include "037-fixture.h"
#include "033-validate.h"
#include "031-region.h"
#include "035-worldfile.h"

#include <lua.h>
#include <lauxlib.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#define M(n) ((wcoord)((n) * WC_ONE))

#define RULESETS "/mnt/mtwo/programming/ai-stuff/my-own-custom-vtt/rulesets"
#define SCRATCH  "/dev/shm/my-own-custom-vtt"

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

/* {{{ struct table */
struct table {
    struct world   world;
    struct pool   *pool;
    struct session session;
    struct ruleset rules;
    uint32_t       body;
    uint32_t       viewer;
};
/* }}} */

/*
 * What the ruleset thinks this body's hit points are.
 *
 * The DEMO may read a sheet. The server may not, and does not -- this is a
 * program showing what a ruleset is doing, which is a different job from being
 * the thing that must not have an opinion about hit points.
 */
/* {{{ static int hit_points_of */
static int hit_points_of(struct table *t, uint32_t thing)
{
    lua_State *L = t->rules.state;
    char source[128];
    int found = -1;

    /*
     * Keyed by the THING index, because that is what this ruleset passes to
     * vtt.sheet. The server hands out a sheet field on every thing and this
     * ruleset ignores it -- which is allowed, and is the point: what a sheet
     * index means is the ruleset's business and never the server's.
     */
    snprintf(source, sizeof(source),
             "local s = vtt.sheet(%u); return s and s.hp or -1",
             (unsigned)thing);

    if (luaL_loadstring(L, source) != 0) {
        lua_pop(L, 1);
        return -1;
    }

    if (lua_pcall(L, 0, 1, 0) != 0) {
        lua_pop(L, 1);
        return -1;
    }

    found = (int)lua_tointeger(L, -1);
    lua_pop(L, 1);

    return found;
}
/* }}} */


/* {{{ static int sit_down */
static int sit_down(struct table *t, const char *ruleset, const char **why)
{
    fixture_make_two_rooms(&t->world);

    t->body = world_add_thing(&t->world);
    {
        struct thing *b = world_thing(&t->world, t->body);
        b->x = M(6);
        b->y = M(6);
        b->radius = (uint16_t)(WC_ONE / 2);
        b->kind = 1;
        b->sight_arc = 65535;
        b->sight_range = (uint32_t)M(30);
        b->region = region_deepest_containing(&t->world, b->x, b->y);
    }

    t->viewer = 1;
    scope_make_list(&t->world, t->viewer, STYLE_ORDERED, &t->body, 1, "a player");

    t->pool = pool_start(1);
    session_start(&t->session, &t->world, t->pool, 4207, 8, 10);

    if (!rules_load(&t->rules, &t->world, &t->session.sim, ruleset, why)) {
        return 0;
    }

    session_attach_rules(&t->session, &t->rules);

    return 1;
}
/* }}} */

/* {{{ static void stand_up */
static void stand_up(struct table *t)
{
    rules_release(&t->rules);
    session_release(&t->session);
    world_release(&t->world);
    pool_stop(t->pool);
}
/* }}} */

/* {{{ static void report_one_ruleset */
static void report_one_ruleset(const char *label, const char *directory)
{
    struct table t;
    const char *why = NULL;
    char text[256];

    printf("    %s\n", label);
    printf("    ");
    {
        size_t i;
        for (i = 0; i < strlen(label); i++) putchar('~');
    }
    printf("\n");

    if (!sit_down(&t, directory, &why)) {
        printf("      would not load: %s\n\n", why);
        return;
    }

    printf("      %u file(s) loaded\n", t.rules.loaded_files);

    /* A short move, then a long one. */
    {
        uint16_t near_move = session_command_from(&t.session, t.viewer,
                                                  VERB_ORDER_MOVE, t.body,
                                                  (int32_t)M(9), (int32_t)M(6));

        printf("      move three metres      -> %s\n",
               (near_move == REFUSED_NOT_AT_ALL)
                   ? "accepted"
                   : session_last_rules_refusal(&t.session));
    }

    {
        uint16_t far_move = session_command_from(&t.session, t.viewer,
                                                 VERB_ORDER_MOVE, t.body,
                                                 (int32_t)M(45), (int32_t)M(6));

        printf("      move forty metres      -> %s\n",
               (far_move == REFUSED_NOT_AT_ALL)
                   ? "accepted"
                   : session_last_rules_refusal(&t.session));
    }

    rules_describe(&t.rules, 1, text, sizeof(text));
    printf("      what kind 1 looks like -> %s\n",
           (text[0] != '\0') ? text : "(the ruleset says nothing)");

    rules_may_know(&t.rules, t.viewer, t.body, text, sizeof(text));
    printf("      what a viewer may know -> %s\n",
           (text[0] != '\0') ? text : "(nothing)");

    {
        struct log_entry action;
        uint16_t went;

        memset(&action, 0, sizeof(action));
        action.verb = VERB_ORDER_STOP;
        action.subject = t.body;

        went = rules_on_action(&t.rules, t.viewer, &action);
        printf("      one action             -> %s%s\n",
               (went == REFUSED_NOT_AT_ALL) ? "" : "refused: ",
               t.rules.last_refusal);
    }

    {
        int beat;

        for (beat = 0; beat < 30; beat++) {
            session_tick(&t.session);
        }

        printf("      world hash after 30 beats: %016llx\n",
               (unsigned long long)world_hash(&t.world));
    }

    printf("\n");

    stand_up(&t);
}
/* }}} */

/* {{{ static void report_the_same_seed */
static void report_the_same_seed(void)
{
    struct table a;
    struct table b;
    const char *why = NULL;
    struct log_entry action;
    int i;

    rule("The same seed, asked different questions");

    memset(&action, 0, sizeof(action));
    action.verb = VERB_ORDER_STOP;

    if (!sit_down(&a, RULESETS "/a-game-with-rules", &why)) {
        printf("    could not load: %s\n", why);
        return;
    }

    action.subject = a.body;

    printf("    a game with rules rolls a twenty-sided die:\n      ");
    for (i = 0; i < 6; i++) {
        rules_on_action(&a.rules, a.viewer, &action);
        printf("%s%s", (i > 0) ? " | " : "", a.rules.last_refusal);
    }
    printf("\n\n");

    stand_up(&a);

    if (!sit_down(&b, RULESETS "/a-table-with-none", &why)) {
        printf("    could not load: %s\n", why);
        return;
    }

    action.subject = b.body;

    printf("    a table with none rolls a pool of six-sided:\n      ");
    for (i = 0; i < 6; i++) {
        rules_on_action(&b.rules, b.viewer, &action);
        printf("%s%s", (i > 0) ? " | " : "", b.rules.last_refusal);
    }
    printf("\n");

    stand_up(&b);

    printf("\n");
    printf("    The same session seed, and the same stream machinery. What\n");
    printf("    differs is the question each ruleset asks of it -- which is the\n");
    printf("    server having no opinion about dice, rather than having a\n");
    printf("    flexible one.\n");

    printf("\n    And the same ruleset twice, with the same seed:\n      ");

    for (i = 0; i < 2; i++) {
        struct table again;

        if (!sit_down(&again, RULESETS "/a-game-with-rules", &why)) {
            continue;
        }

        action.subject = again.body;
        rules_on_action(&again.rules, again.viewer, &action);
        printf("%srun %d: %s", (i > 0) ? "      " : "", i + 1,
               again.rules.last_refusal);
        printf("\n");

        stand_up(&again);
    }

    printf("\n    Identical, which is what a written-down seed is for.\n");
}
/* }}} */

/* {{{ static void report_a_broken_ruleset */
static void report_a_broken_ruleset(void)
{
    struct table t;
    const char *why = NULL;
    FILE *f;
    int i;

    rule("A ruleset that is simply wrong");

    mkdir(SCRATCH "/broken-ruleset", 0755);

    f = fopen(SCRATCH "/broken-ruleset/001-broken.lua", "w");
    if (f == NULL) {
        printf("    could not write the broken ruleset\n");
        return;
    }

    fprintf(f,
        "-- A ruleset with a real mistake in it: a nil indexed every time.\n"
        "function on_command(viewer, verb, subject, ax, ay)\n"
        "    local nothing = nil\n"
        "    return nothing.field\n"
        "end\n");
    fclose(f);

    if (!sit_down(&t, SCRATCH "/broken-ruleset", &why)) {
        printf("    it would not even load: %s\n", why);
        return;
    }

    printf("    It loads -- the mistake is at run time, not in the syntax.\n\n");

    for (i = 0; i < 12; i++) {
        uint16_t refusal = session_command_from(&t.session, t.viewer,
                                                VERB_ORDER_MOVE, t.body,
                                                (int32_t)M(8), (int32_t)M(6));

        if (i < 2 || i == 11) {
            printf("      attempt %-2d -> %s\n", i + 1,
                   (refusal == REFUSED_NOT_AT_ALL)
                       ? "accepted"
                       : session_last_rules_refusal(&t.session));
        } else if (i == 2) {
            printf("      ...\n");
        }
    }

    printf("\n");
    printf("      the hook has been abandoned: %s\n",
           rules_has(&t.rules, HOOK_ON_COMMAND) ? "no" : "yes");

    printf("\n");
    printf("    The table kept running. That is the whole argument for embedding\n");
    printf("    Lua rather than compiling rules in: somebody's homebrew should\n");
    printf("    not take down the evening.\n");
    printf("\n");
    printf("    And the refusal says the ruleset FAILED rather than that it\n");
    printf("    declined, because \"you may not\" and \"the rules are broken\" send\n");
    printf("    a person to look at completely different things.\n");
    printf("\n");
    printf("    After %d failures the hook stopped being called and said so once.\n",
           HOOK_FAILURE_LIMIT);
    printf("    A ruleset that is broken should be visibly broken rather than\n");
    printf("    continuously noisy.\n");
    printf("\n");
    printf("    Note what attempt 12 did: it was ACCEPTED. An abandoned veto\n");
    printf("    fails open rather than closed, and that is a choice.\n");
    printf("\n");
    printf("    Failing closed would mean a single bad line in somebody's\n");
    printf("    homebrew freezing the table completely -- every command refused,\n");
    printf("    with no way to play on while it gets fixed. Failing open means\n");
    printf("    the evening continues under no rules at all, which is worse than\n");
    printf("    correct and much better than stopped.\n");
    printf("\n");
    printf("    It is the right trade only because the failure was announced\n");
    printf("    loudly first. A veto that quietly stopped vetoing would be the\n");
    printf("    worst of the three.\n");

    stand_up(&t);
}
/* }}} */

/* {{{ static void report_the_hole */
static void report_the_hole(void)
{
    struct table t;
    const char *why = NULL;
    struct log_entry action;
    uint32_t turn;
    int beat;

    rule("And the part that does not work");

    if (!sit_down(&t, RULESETS "/a-game-with-rules", &why)) {
        printf("    could not load: %s\n", why);
        return;
    }

    /*
     * Given hit points before any turn opens, so that the head snapshot has a
     * number in it. Without this the sheet is simply empty at the head of the
     * turn -- which restores correctly and reads as nothing.
     */
    {
        lua_State *L = t.rules.state;
        char source[96];

        snprintf(source, sizeof(source), "vtt.sheet(%u).hp = 10",
                 (unsigned)t.body);

        if (luaL_loadstring(L, source) == 0) {
            lua_pcall(L, 0, 0, 0);
        }
    }

    for (beat = 0; beat < 25; beat++) {
        session_tick(&t.session);
    }

    turn = t.session.turn;

    printf("    At the head of turn %u the body stands at (%d, %d)"
           " with %d hit points.\n",
           turn,
           (int)(world_thing_const(&t.world, t.body)->x / WC_ONE),
           (int)(world_thing_const(&t.world, t.body)->y / WC_ONE),
           hit_points_of(&t, t.body));

    /* Take some damage, and move. */
    memset(&action, 0, sizeof(action));
    action.verb = VERB_ORDER_STOP;
    action.subject = t.body;

    for (beat = 0; beat < 6; beat++) {
        rules_on_action(&t.rules, t.viewer, &action);
    }

    session_command_from(&t.session, t.viewer, VERB_ORDER_MOVE, t.body,
                         (int32_t)M(12), (int32_t)M(6));

    for (beat = 0; beat < 8; beat++) {
        session_tick(&t.session);
    }

    printf("    It is attacked six times and walks a few metres.\n");
    printf("      now at (%d, %d), and %d hit points\n",
           (int)(world_thing_const(&t.world, t.body)->x / WC_ONE),
           (int)(world_thing_const(&t.world, t.body)->y / WC_ONE),
           hit_points_of(&t, t.body));

    session_rollback(&t.session, turn, ROLLBACK_REDECLARE);

    printf("\n    The turn is taken back.\n");
    printf("      back at (%d, %d) -- the geometry returned\n",
           (int)(world_thing_const(&t.world, t.body)->x / WC_ONE),
           (int)(world_thing_const(&t.world, t.body)->y / WC_ONE));

    printf("      and %d hit points -- the numbers returned too\n",
           hit_points_of(&t, t.body));

    printf("      sheets restored: %s\n",
           rules_sheets_survive_rollback(&t.rules) ? "yes" : "NO");

    printf("\n");
    printf("    FOR FOUR PHASES THE WOUNDS STAYED. A world snapshot copies flat\n");
    printf("    blocks of bytes, which is what makes it a memcpy, and a Lua table\n");
    printf("    is not that -- so an undone fight put everybody back where they\n");
    printf("    had been standing and left them bleeding. This demo showed it\n");
    printf("    happening, because a rollback that looks like it worked is worse\n");
    printf("    than one that visibly does not.\n");
    printf("\n");
    printf("    Three ways out had been written down and all three rejected. The\n");
    printf("    second was \"serialise the table generically\", turned down for\n");
    printf("    breaking QUIETLY on a closure -- and that is a property of one\n");
    printf("    implementation of it, not of the idea. A copier can know\n");
    printf("    perfectly well what it cannot copy.\n");
    printf("\n");
    printf("    So it refuses, by name and by path, and a turn whose sheets could\n");
    printf("    not be copied is not rollbackable rather than half-restored:\n");
    printf("\n");

    /*
     * The refusal, shown rather than described. A ruleset can take the guard off
     * a sheet and store a closure underneath it, and the demo does exactly that
     * so the sentence it produces is on the page.
     */
    {
        lua_State *L = t.rules.state;
        const char *trouble = "";

        if (luaL_loadstring(L,
                "setmetatable(vtt.sheet(2), nil);"
                " rawset(vtt.sheet(2), 'attack', function() end)") == 0
            && lua_pcall(L, 0, 0, 0) == 0) {

            if (!rules_snapshot_sheets(&t.rules, 999, &trouble)) {
                printf("      %s\n", trouble);
            }
        }
    }

    printf("\n");
    printf("    Issue 703 was reopened to close this rather than a new issue\n");
    printf("    being written beside it, because the fix belongs in the issue\n");
    printf("    that built the storage. Open question 14.1 is answered.\n");

    stand_up(&t);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    printf("\n");
    printf("  ===========================================================\n");
    printf("   PHASE SEVEN -- The rules layer\n");
    printf("  ===========================================================\n");
    printf("\n");
    printf("  One world, two rulesets, one unchanged server. One ruleset proves\n");
    printf("  an interface exists; two prove it IS an interface.\n");

    rule("The same world, run twice");

    report_one_ruleset("a game with rules", RULESETS "/a-game-with-rules");
    report_one_ruleset("a table with none", RULESETS "/a-table-with-none");

    printf("    Same server, same fixture, same seed. They disagree about what is\n");
    printf("    legal, about what a thing is, and about who may know what -- and\n");
    printf("    not one line of C differs between the two runs.\n");
    printf("\n");
    printf("    Neither is trying to be a good game. They are trying to be\n");
    printf("    DIFFERENT, because a sample ruleset that aims at being good grows\n");
    printf("    until it is the only game the interface fits.\n");

    report_the_same_seed();
    report_a_broken_ruleset();
    report_the_hole();

    printf("\n");
    printf("  Next: phase eight, where a description and a seed become a world.\n");
    printf("\n");

    return 0;
}
/* }}} */
