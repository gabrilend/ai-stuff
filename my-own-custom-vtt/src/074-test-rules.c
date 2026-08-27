/*
 * 074-test-rules.c -- can a ruleset reach anything it should not?
 *
 * The sandbox is the whole subject. A ruleset that can read the clock makes a
 * replay diverge; one that can write a file is a program on somebody's machine;
 * one that can reach a socket could leak by being written badly.
 *
 * So most of these check that a name is ABSENT rather than that a feature works.
 */

#include "020-test-harness.h"
#include "073-rules.h"
#include "037-fixture.h"
#include "053-session.h"
#include "070-scope.h"

#include <lua.h>
#include <lauxlib.h>

#include <string.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>

#define M(n) ((wcoord)((n) * WC_ONE))

#define RULESETS "/mnt/mtwo/programming/ai-stuff/my-own-custom-vtt/rulesets"
#define SCRATCH  "/dev/shm/my-own-custom-vtt"

/* {{{ struct rig */
struct rig {
    struct world  world;
    struct pool  *pool;
    struct sim    sim;
    struct ruleset rules;
};
/* }}} */

/* {{{ static int rig_start */
static int rig_start(struct rig *r, const char *directory, const char **why)
{
    fixture_make_two_rooms(&r->world);
    r->pool = pool_start(1);
    sim_init(&r->sim, &r->world, r->pool, 4207);

    return rules_load(&r->rules, &r->world, &r->sim, directory, why);
}
/* }}} */

/* {{{ static void rig_stop */
static void rig_stop(struct rig *r)
{
    rules_release(&r->rules);
    sim_release(&r->sim);
    world_release(&r->world);
    pool_stop(r->pool);
}
/* }}} */

/* {{{ static int ruleset_says */
static int ruleset_says(struct rig *r, const char *source)
{
    lua_State *L = r->rules.state;

    if (luaL_loadstring(L, source) != 0) {
        lua_pop(L, 1);
        return 0;
    }

    if (lua_pcall(L, 0, 1, 0) != 0) {
        lua_pop(L, 1);
        return 0;
    }

    {
        int truth = lua_toboolean(L, -1);
        lua_pop(L, 1);
        return truth;
    }
}
/* }}} */

/* {{{ static void test_the_doors_are_closed */
static void test_the_doors_are_closed(void)
{
    struct rig r;
    const char *why = NULL;

    TEST_CASE("a ruleset cannot reach the clock");

    /*
     * Every one of these is a way to make a replay diverge silently, or to reach
     * off the machine. A ruleset that calls the clock destroys reproducibility
     * without anybody being able to see why.
     */
    CHECK(rig_start(&r, RULESETS "/a-table-with-none", &why) == 1);

    CHECK_EQ(ruleset_says(&r, "return os == nil"), 1);

    TEST_CASE("nor ambient randomness");

    CHECK_EQ(ruleset_says(&r, "return math.random == nil"), 1);
    CHECK_EQ(ruleset_says(&r, "return math.randomseed == nil"), 1);

    TEST_CASE("nor the file system");

    CHECK_EQ(ruleset_says(&r, "return io == nil"), 1);
    CHECK_EQ(ruleset_says(&r, "return dofile == nil"), 1);
    CHECK_EQ(ruleset_says(&r, "return loadfile == nil"), 1);
    CHECK_EQ(ruleset_says(&r, "return require == nil"), 1);
    CHECK_EQ(ruleset_says(&r, "return package == nil"), 1);

    TEST_CASE("nor arbitrary code, nor the debug interface");

    CHECK_EQ(ruleset_says(&r, "return load == nil"), 1);
    CHECK_EQ(ruleset_says(&r, "return loadstring == nil"), 1);
    CHECK_EQ(ruleset_says(&r, "return debug == nil"), 1);

    TEST_CASE("but it still has the parts that make Lua worth using");

    CHECK_EQ(ruleset_says(&r, "return type(pairs) == 'function'"), 1);
    CHECK_EQ(ruleset_says(&r, "return type(table.sort) == 'function'"), 1);
    CHECK_EQ(ruleset_says(&r, "return type(string.format) == 'function'"), 1);
    CHECK_EQ(ruleset_says(&r, "return type(math.floor) == 'function'"), 1);

    rig_stop(&r);
}
/* }}} */

/* {{{ static void test_the_window_is_narrow */
static void test_the_window_is_narrow(void)
{
    struct rig r;
    const char *why = NULL;

    TEST_CASE("a ruleset can read the world");

    CHECK(rig_start(&r, RULESETS "/a-table-with-none", &why) == 1);

    CHECK_EQ(ruleset_says(&r, "return vtt.thing_count() > 1"), 1);
    CHECK_EQ(ruleset_says(&r, "return vtt.thing(1) ~= nil"), 1);
    CHECK_EQ(ruleset_says(&r, "return type(vtt.thing(1).x) == 'number'"), 1);

    TEST_CASE("a bad index is nil rather than an empty record");

    /*
     * The one place in this project where nil is the right answer. A ruleset
     * author is not the validator's problem, and an error at the point of the
     * mistake beats a silent empty record.
     */
    CHECK_EQ(ruleset_says(&r, "return vtt.thing(99999) == nil"), 1);
    CHECK_EQ(ruleset_says(&r, "return vtt.thing(0) == nil"), 1);

    TEST_CASE("what it gets is a copy, not a handle into the world");

    /*
     * A ruleset holding a reference into the world could write through it, and
     * then there would be two ways for a body to end up somewhere -- which would
     * disagree about walls within a week.
     */
    CHECK_EQ(ruleset_says(&r,
        "local a = vtt.thing(1) a.x = 999 return vtt.thing(1).x ~= 999"), 1);

    TEST_CASE("it cannot see who commands a body, or where its numbers live");

    CHECK_EQ(ruleset_says(&r, "return vtt.thing(1).scope == nil"), 1);
    CHECK_EQ(ruleset_says(&r, "return vtt.thing(1).sheet == nil"), 1);

    TEST_CASE("and it has no way to reach a socket or a viewer's fog");

    CHECK_EQ(ruleset_says(&r, "return vtt.send == nil"), 1);
    CHECK_EQ(ruleset_says(&r, "return vtt.fog == nil"), 1);
    CHECK_EQ(ruleset_says(&r, "return vtt.set_scope == nil"), 1);

    rig_stop(&r);
}
/* }}} */

/* {{{ static void test_the_two_rulesets_disagree */
static void test_the_two_rulesets_disagree(void)
{
    struct rig strict;
    struct rig loose;
    const char *why = NULL;
    struct log_entry move;

    TEST_CASE("both load, over an unchanged server");

    CHECK(rig_start(&strict, RULESETS "/a-game-with-rules", &why) == 1);
    if (why != NULL && strict.rules.loaded_files == 0) {
        vtt_report_failure(__FILE__, __LINE__, why);
    }

    CHECK(rig_start(&loose, RULESETS "/a-table-with-none", &why) == 1);

    CHECK(strict.rules.loaded_files > 0);
    CHECK(loose.rules.loaded_files > 0);

    TEST_CASE("and disagree about what is legal");

    /*
     * The same command. One ruleset has turns and a movement limit; the other
     * has neither. The server is identical between them.
     */
    memset(&move, 0, sizeof(move));
    move.verb = VERB_ORDER_MOVE;
    move.subject = 1;
    move.ax = (int32_t)M(40);
    move.ay = (int32_t)M(40);

    {
        uint16_t strict_says = rules_on_command(&strict.rules, 1, &move);
        uint16_t loose_says = rules_on_command(&loose.rules, 1, &move);

        CHECK(strict_says != loose_says);
        CHECK_EQ(loose_says, REFUSED_NOT_AT_ALL);
        CHECK_EQ(strict_says, REFUSED_BY_THE_RULES);

        /* And the refusal is a sentence the ruleset wrote. */
        CHECK(strict.rules.last_refusal[0] != '\0');
        CHECK(strstr(strict.rules.last_refusal, "metres") != NULL ||
              strstr(strict.rules.last_refusal, "turn") != NULL);
    }

    TEST_CASE("and about what a thing is");

    {
        char strict_kind[128];
        char loose_kind[128];

        rules_describe(&strict.rules, 1, strict_kind, sizeof(strict_kind));
        rules_describe(&loose.rules, 1, loose_kind, sizeof(loose_kind));

        CHECK(strict_kind[0] != '\0');
        CHECK(loose_kind[0] != '\0');
        CHECK(strcmp(strict_kind, loose_kind) != 0);

        CHECK(strstr(strict_kind, "goblin") != NULL);
        CHECK(strstr(loose_kind, "token") != NULL);
    }

    TEST_CASE("and about who may know what");

    {
        char strict_fields[128];
        char loose_fields[128];

        rules_may_know(&strict.rules, 1, 1, strict_fields, sizeof(strict_fields));
        rules_may_know(&loose.rules, 1, 1, loose_fields, sizeof(loose_fields));

        CHECK(strict_fields[0] != '\0');
        CHECK_EQ(loose_fields[0], '\0');
    }

    rig_stop(&strict);
    rig_stop(&loose);
}
/* }}} */

/* {{{ static void test_no_hook_sends_nothing */
static void test_no_hook_sends_nothing(void)
{
    struct rig r;
    const char *why = NULL;
    char fields[128];

    TEST_CASE("a ruleset with no may_know widens nothing");

    /*
     * Adding a rules layer must not make a system MORE revealing. A default that
     * sends fields because nobody mentioned the subject has it backwards.
     */
    CHECK(rig_start(&r, SCRATCH "/silent-ruleset", &why) == 0);

    /* No such directory -- which is itself the refusal being named. */
    CHECK(why != NULL);
    CHECK(strstr(why, "ruleset directory") != NULL);

    rules_release(&r.rules);
    sim_release(&r.sim);
    world_release(&r.world);
    pool_stop(r.pool);

    TEST_CASE("and a ruleset with no hooks at all is a legal ruleset");

    {
        struct rig empty;
        FILE *f;

        /* The RAM tier, so a test never leaves anything on a disk. */
        mkdir(SCRATCH "/empty-ruleset", 0755);

        f = fopen(SCRATCH "/empty-ruleset/001-nothing-at-all.lua", "w");
        if (f != NULL) {
            fprintf(f, "-- deliberately empty\n");
            fclose(f);

            why = NULL;
            CHECK(rig_start(&empty, SCRATCH "/empty-ruleset", &why) == 1);

            CHECK_EQ(rules_has(&empty.rules, HOOK_ON_COMMAND), 0);
            CHECK_EQ(rules_on_command(&empty.rules, 1, NULL), REFUSED_NOT_AT_ALL);

            rules_may_know(&empty.rules, 1, 1, fields, sizeof(fields));
            CHECK_EQ(fields[0], '\0');

            rig_stop(&empty);
        }
    }
}
/* }}} */

/*
 * A rolled-back turn puts the hit points back.
 *
 * This was the largest known hole in the project for four phases: a rollback
 * restored geometry and not sheets, so everybody returned to where they had been
 * standing with their wounds intact. `rules_sheets_survive_rollback` returned 0
 * so a caller could at least SAY so.
 *
 * Issue 703 was reopened rather than a new issue written beside it, because the
 * fix belongs in the issue that built the storage.
 */
/* {{{ static void test_sheets_survive_a_rollback */
static void test_sheets_survive_a_rollback(void)
{
    struct rig r;
    const char *why = NULL;
    const char *trouble = "";

    TEST_CASE("a rolled-back turn puts the sheets back");

    CHECK(rig_start(&r, RULESETS "/a-game-with-rules", &why) == 1);
    CHECK_EQ(rules_sheets_survive_rollback(&r.rules), 1);

    /* Somebody has ten hit points at the head of turn 1. */
    CHECK_EQ(ruleset_says(&r,
        "vtt.sheet(1).hp = 10; return vtt.sheet(1).hp == 10"), 1);

    CHECK_EQ(rules_snapshot_sheets(&r.rules, 1, &trouble), 1);
    CHECK(trouble[0] == '\0');

    /* The fight goes badly. */
    CHECK_EQ(ruleset_says(&r,
        "vtt.sheet(1).hp = 2; return vtt.sheet(1).hp == 2"), 1);

    /* And the turn is taken back. */
    CHECK_EQ(rules_restore_sheets(&r.rules, 1, &trouble), 1);
    CHECK_EQ(ruleset_says(&r, "return vtt.sheet(1).hp == 10"), 1);

    TEST_CASE("a nested table in a sheet is copied, not shared");

    CHECK_EQ(ruleset_says(&r,
        "vtt.sheet(2).tags = { 'green', 'small' }; return true"), 1);
    CHECK_EQ(rules_snapshot_sheets(&r.rules, 2, &trouble), 1);

    CHECK_EQ(ruleset_says(&r, "vtt.sheet(2).tags[1] = 'red'; return true"), 1);
    CHECK_EQ(rules_restore_sheets(&r.rules, 2, &trouble), 1);

    /* If the copy had shared the inner table, the restore would put back a
     * table that had already been edited -- which is a rollback that looks like
     * it worked and is exactly the failure being fixed. */
    CHECK_EQ(ruleset_says(&r, "return vtt.sheet(2).tags[1] == 'green'"), 1);

    TEST_CASE("a turn can be rolled back to more than once");

    CHECK_EQ(ruleset_says(&r, "vtt.sheet(1).hp = 1; return true"), 1);
    CHECK_EQ(rules_restore_sheets(&r.rules, 1, &trouble), 1);
    CHECK_EQ(ruleset_says(&r, "return vtt.sheet(1).hp == 10"), 1);

    TEST_CASE("a snapshot nobody took cannot be restored");

    CHECK_EQ(rules_restore_sheets(&r.rules, 99, &trouble), 0);
    CHECK(strstr(trouble, "99") != NULL);

    rig_stop(&r);
}
/* }}} */

/*
 * And what cannot be copied is refused, twice: where it is stored, and where it
 * would be copied.
 */
/* {{{ static void test_an_uncopyable_sheet */
static void test_an_uncopyable_sheet(void)
{
    struct rig r;
    const char *why = NULL;
    const char *trouble = "";

    TEST_CASE("storing a function in a sheet fails at the line that did it");

    CHECK(rig_start(&r, RULESETS "/a-game-with-rules", &why) == 1);

    /* The guard refuses it, so the assignment itself raises. */
    CHECK_EQ(ruleset_says(&r,
        "local ok = pcall(function() vtt.sheet(1).attack = function() end end);"
        " return ok == false"), 1);

    /* And nothing was stored. */
    CHECK_EQ(ruleset_says(&r, "return vtt.sheet(1).attack == nil"), 1);

    TEST_CASE("and the copier refuses it even with the guard removed");

    /*
     * A ruleset can call setmetatable and take the guard off. The guard is for
     * the error message; the copier is the authority, and this is the check that
     * says so.
     */
    CHECK_EQ(ruleset_says(&r,
        "setmetatable(vtt.sheet(1), nil);"
        " rawset(vtt.sheet(1), 'attack', function() end); return true"), 1);

    CHECK_EQ(rules_snapshot_sheets(&r.rules, 5, &trouble), 0);
    CHECK(strstr(trouble, "function") != NULL);
    CHECK(strstr(trouble, "attack") != NULL);

    TEST_CASE("a sheet that points at itself is refused, not flattened");

    CHECK(rig_start(&r, RULESETS "/a-game-with-rules", &why) == 1);
    CHECK_EQ(ruleset_says(&r,
        "local s = vtt.sheet(1); s.me = s; return true"), 1);

    CHECK_EQ(rules_snapshot_sheets(&r.rules, 6, &trouble), 0);
    CHECK(strstr(trouble, "points back at itself") != NULL);

    rig_stop(&r);
}
/* }}} */

/*
 * The whole path, through a real session: a turn opens, a sheet changes, the
 * turn is taken back, and the sheet is what it was.
 *
 * The tests above exercise the copier directly. This one goes through
 * session_rollback, which is what an actual retcon calls -- because a copier
 * that works and a rollback that does not call it is the same hole with an extra
 * function in it.
 */
/* {{{ static void test_a_real_rollback_restores_the_sheets */
static void test_a_real_rollback_restores_the_sheets(void)
{
    struct world w;
    struct pool *threads = pool_start(1);
    struct session s;
    struct ruleset rules;
    const char *why = NULL;
    int beat;

    TEST_CASE("a retcon through the session puts the sheets back");

    fixture_make_two_rooms(&w);
    CHECK_EQ(session_start(&s, &w, threads, 4207, 8, 5), 1);

    CHECK_EQ(rules_load(&rules, &w, &s.sim, RULESETS "/a-game-with-rules", &why), 1);
    session_attach_rules(&s, &rules);

    /* Turn 1 opens with ten hit points. */
    for (beat = 0; beat < 5; beat++) {
        session_tick(&s);
    }

    {
        lua_State *L = rules.state;

        CHECK_EQ(luaL_loadstring(L, "vtt.sheet(1).hp = 10"), 0);
        CHECK_EQ(lua_pcall(L, 0, 0, 0), 0);
    }

    /* A turn passes, and the fight goes badly. */
    for (beat = 0; beat < 5; beat++) {
        session_tick(&s);
    }

    {
        lua_State *L = rules.state;

        CHECK_EQ(luaL_loadstring(L, "vtt.sheet(1).hp = 2"), 0);
        CHECK_EQ(lua_pcall(L, 0, 0, 0), 0);
    }

    CHECK(s.turn >= 1);
    CHECK_EQ(session_can_roll_back_to(&s, s.turn), 1);
    CHECK(session_why_not_rollbackable(&s, s.turn)[0] == '\0');

    CHECK_EQ(session_rollback(&s, s.turn, ROLLBACK_REDECLARE), 1);

    {
        lua_State *L = rules.state;
        int restored = 0;

        CHECK_EQ(luaL_loadstring(L, "return vtt.sheet(1).hp"), 0);
        CHECK_EQ(lua_pcall(L, 0, 1, 0), 0);
        restored = (int)lua_tointeger(L, -1);
        lua_pop(L, 1);

        /*
         * Ten, not two. For four phases this was two, and the demo showed it
         * happening because a rollback that looks like it worked is worse than
         * one that plainly did not.
         */
        CHECK_EQ(restored, 10);
    }

    TEST_CASE("a turn whose sheets could not be copied is not rollbackable");

    {
        lua_State *L = rules.state;
        uint32_t turn_with_a_closure;

        /* The guard removed and a function stored underneath it, which is the
         * only way to get an uncopyable sheet. */
        CHECK_EQ(luaL_loadstring(L,
            "setmetatable(vtt.sheet(2), nil);"
            " rawset(vtt.sheet(2), 'attack', function() end)"), 0);
        CHECK_EQ(lua_pcall(L, 0, 0, 0), 0);

        for (beat = 0; beat < 5; beat++) {
            session_tick(&s);
        }

        turn_with_a_closure = s.turn;

        /* Refused, and it says which sheet and where. Not half-restored: the
         * whole point is that the world is left exactly where it was. */
        CHECK_EQ(session_can_roll_back_to(&s, turn_with_a_closure), 0);
        CHECK(strstr(session_why_not_rollbackable(&s, turn_with_a_closure),
                     "attack") != NULL);
        CHECK_EQ(session_rollback(&s, turn_with_a_closure, ROLLBACK_REDECLARE), 0);
    }

    rules_release(&rules);
    session_release(&s);
    world_release(&w);
    pool_stop(threads);
}
/* }}} */

/*
 * Owning a piece is the right to move it. It is not a fence around it.
 *
 * A forest commander owns their goblin patrol. It walks into somebody else's
 * tavern. The tavern's owner cannot move it, and can absolutely poison its
 * drink -- but they had better explain how, and explaining how is the ruleset's
 * job rather than the server's.
 *
 * The gate that replaces ownership is SIGHT, and it is the same decision the
 * outbound path made rather than a second one that agrees most of the time. Two
 * answers to "can this person see that" is how a permission model develops a
 * hole nobody can find.
 */
/* {{{ static void test_commanding_is_not_affecting */
static void test_commanding_is_not_affecting(void)
{
    struct world w;
    struct pool *threads = pool_start(1);
    struct session s;
    struct ruleset rules;
    const char *why = NULL;
    uint32_t patrol;
    uint32_t innkeeper;
    uint32_t forest_seat = 1;
    uint32_t tavern_seat = 2;

    TEST_CASE("you cannot move what you do not command");

    fixture_make_two_rooms(&w);

    patrol = world_add_thing(&w);
    world_thing(&w, patrol)->x = M(5);
    world_thing(&w, patrol)->y = M(5);
    world_thing(&w, patrol)->radius = (uint16_t)(WC_ONE / 2);
    world_thing(&w, patrol)->region = 1;

    innkeeper = world_add_thing(&w);
    world_thing(&w, innkeeper)->x = M(6);
    world_thing(&w, innkeeper)->y = M(5);
    world_thing(&w, innkeeper)->radius = (uint16_t)(WC_ONE / 2);
    world_thing(&w, innkeeper)->region = 1;

    CHECK_EQ(session_start(&s, &w, threads, 4207, 8, 5), 1);
    sim_fit_to_world(&s.sim);

    CHECK_EQ(rules_load(&rules, &w, &s.sim, RULESETS "/a-game-with-rules", &why), 1);
    session_attach_rules(&s, &rules);

    scope_make_list(&w, forest_seat, STYLE_ORDERED, &patrol, 1, "the forest");
    scope_make_list(&w, tavern_seat, STYLE_ORDERED, &innkeeper, 1, "the tavern");

    /* The forest moves its own patrol. */
    CHECK_EQ(session_command_from(&s, forest_seat, VERB_ORDER_MOVE, patrol,
                                  M(8), M(8)), REFUSED_NOT_AT_ALL);

    /* The tavern cannot. */
    CHECK_EQ(session_command_from(&s, tavern_seat, VERB_ORDER_MOVE, patrol,
                                  M(2), M(2)), REFUSED_NOT_YOURS);

    TEST_CASE("and you can absolutely poison its drink");

    /*
     * Told about it first, because the gate is what the outbound path decided.
     * In a running server that happens every beat; here it is done directly, so
     * that the test is about the gate rather than about ray casting.
     */
    session_note_told(&s, tavern_seat, patrol);

    CHECK_EQ(session_command_from(&s, tavern_seat, VERB_INTERACT, patrol,
                                  1 /* poison the drink */, 0),
             REFUSED_NOT_AT_ALL);

    /* Whatever happened, the ruleset said it in words. */
    CHECK(rules.last_refusal[0] != '\0');

    TEST_CASE("but not to something you were not told about");

    session_forget_what_was_told(&s, tavern_seat);

    CHECK_EQ(session_command_from(&s, tavern_seat, VERB_INTERACT, patrol,
                                  1, 0),
             REFUSED_CANNOT_SEE_IT);

    /* And the refusal is a sentence about being told, not about ownership --
     * because the two are now different questions. */
    CHECK(strstr(refusal_sentence(REFUSED_CANNOT_SEE_IT), "told") != NULL);

    TEST_CASE("an intent this game has no rule for is refused, in its words");

    session_note_told(&s, tavern_seat, patrol);

    CHECK_EQ(session_command_from(&s, tavern_seat, VERB_INTERACT, patrol,
                                  9999, 0),
             REFUSED_BY_THE_RULES);
    CHECK(strstr(rules.last_refusal, "no rule in this game") != NULL);

    rules_release(&rules);
    session_release(&s);
    world_release(&w);
    pool_stop(threads);
}
/* }}} */

/*
 * A ruleset with no opinion about acting on things means a table where you
 * cannot. Refused rather than allowed: the server does not know what an intent
 * means, and allowing something it cannot describe would be the server having an
 * opinion by the back door.
 */
/* {{{ static void test_a_table_with_no_rules_about_it */
static void test_a_table_with_no_rules_about_it(void)
{
    struct world w;
    struct pool *threads = pool_start(1);
    struct session s;
    struct ruleset rules;
    const char *why = NULL;
    uint32_t thing;

    TEST_CASE("a ruleset with no interact hook refuses, and says why");

    fixture_make_two_rooms(&w);

    thing = world_add_thing(&w);
    world_thing(&w, thing)->x = M(5);
    world_thing(&w, thing)->y = M(5);
    world_thing(&w, thing)->region = 1;

    CHECK_EQ(session_start(&s, &w, threads, 1, 8, 5), 1);
    sim_fit_to_world(&s.sim);

    CHECK_EQ(rules_load(&rules, &w, &s.sim, RULESETS "/a-table-with-none", &why), 1);
    session_attach_rules(&s, &rules);

    session_note_told(&s, 1, thing);

    CHECK_EQ(session_command_from(&s, 1, VERB_INTERACT, thing, 1, 0),
             REFUSED_BY_THE_RULES);
    CHECK(strstr(rules.last_refusal, "no rules about acting") != NULL);

    TEST_CASE("and no ruleset at all refuses differently");

    session_attach_rules(&s, NULL);
    CHECK_EQ(session_command_from(&s, 1, VERB_INTERACT, thing, 1, 0),
             REFUSED_NO_RULES_FOR_THAT);

    rules_release(&rules);
    session_release(&s);
    world_release(&w);
    pool_stop(threads);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_the_doors_are_closed();
    test_the_window_is_narrow();
    test_the_two_rulesets_disagree();
    test_no_hook_sends_nothing();
    test_sheets_survive_a_rollback();
    test_an_uncopyable_sheet();
    test_a_real_rollback_restores_the_sheets();
    test_commanding_is_not_affecting();
    test_a_table_with_no_rules_about_it();

    return vtt_test_finish("074-test-rules");
}
/* }}} */
