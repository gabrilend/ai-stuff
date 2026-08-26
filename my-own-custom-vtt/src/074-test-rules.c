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

/* {{{ int main */
int main(void)
{
    test_the_doors_are_closed();
    test_the_window_is_narrow();
    test_the_two_rulesets_disagree();
    test_no_hook_sends_nothing();

    return vtt_test_finish("074-test-rules");
}
/* }}} */
