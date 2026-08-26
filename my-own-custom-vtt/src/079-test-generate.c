/*
 * 079-test-generate.c -- does the same seed give the same dungeon, and is the
 * dungeon the one that was asked for?
 *
 * Two different questions. The first is what makes a seed worth writing down.
 * The second is what tells a generator from a random number visualiser -- and
 * only generate_check can answer it, because world_validate would happily pass a
 * coherent dungeon with three rooms when somebody asked for eight.
 */

#include "020-test-harness.h"
#include "078-generate.h"
#include "033-validate.h"
#include "035-worldfile.h"

#include <string.h>

/* {{{ static void build_from */
static int build_from(struct world *w, const char *text, uint64_t seed,
                      struct layout *l, const char **why)
{
    struct description d;
    struct fault_list faults;
    uint32_t things, walls, regions, vertices, lights, strings;

    if (!description_read(&d, text, &faults)) {
        *why = "the description was refused";
        return 0;
    }

    generate_capacity_hint(&d, &things, &walls, &regions,
                           &vertices, &lights, &strings);

    if (!world_init(w, things, walls, regions, vertices, lights, strings)) {
        *why = "no memory";
        return 0;
    }

    return generate(w, &d, seed, NULL, l, why);
}
/* }}} */

/* {{{ static void test_the_wall_reports_everything */
static void test_the_wall_reports_everything(void)
{
    struct description d;
    struct fault_list faults;

    TEST_CASE("a sound description is accepted");

    CHECK(description_read(&d,
        "name = the old inn\n"
        "rooms = 5\n"
        "smallest = 4\n"
        "largest = 10\n"
        "loops = 1\n"
        "require = cellar\n", &faults) == 1);

    CHECK_EQ(d.rooms, 5);
    CHECK_EQ(d.required_count, 1);
    CHECK_EQ(strcmp(d.required[0], "cellar"), 0);
    CHECK_EQ(strcmp(d.name, "the old inn"), 0);

    TEST_CASE("an absent optional takes its documented default");

    /*
     * Vocabulary, not a fallback. The difference is that this default is written
     * in the vocabulary table and appears in the companion file, where somebody
     * can find it.
     */
    CHECK(description_read(&d, "rooms = 4\n", &faults) == 1);
    CHECK(d.smallest > 0);
    CHECK(d.largest > d.smallest);

    TEST_CASE("a malformed field is a fault and never takes a default");

    CHECK_EQ(description_read(&d, "rooms = lots\n", &faults), 0);
    CHECK_EQ(faults.count, 1);
    CHECK_EQ(strcmp(faults.faults[0].word, "rooms"), 0);
    CHECK_EQ(strcmp(faults.faults[0].found, "lots"), 0);

    TEST_CASE("every fault is reported, not the first");

    /*
     * Stopping at the first turns fixing a description into one guess per run.
     */
    CHECK_EQ(description_read(&d,
        "rooms = lots\n"
        "smallest = plenty\n"
        "largest = enormous\n"
        "loops = several\n", &faults), 0);

    CHECK_EQ(faults.count, 4);

    TEST_CASE("a misspelling gets the nearest legal word");

    CHECK_EQ(description_read(&d, "romes = 4\n", &faults), 0);
    CHECK_EQ(faults.count, 1);
    CHECK(faults.faults[0].nearest != NULL);
    CHECK_EQ(strcmp(faults.faults[0].nearest, "rooms"), 0);

    TEST_CASE("but nothing close is suggested for something far away");

    /*
     * Suggesting "rooms" for "banana" is worse than suggesting nothing -- it
     * sends somebody looking for a relationship that is not there.
     */
    CHECK_EQ(description_read(&d, "banana = 4\n", &faults), 0);
    CHECK(faults.faults[0].nearest == NULL);

    TEST_CASE("a number out of bounds is refused, naming the bounds");

    CHECK_EQ(description_read(&d, "rooms = 9999\n", &faults), 0);
    CHECK(strstr(faults.faults[0].expected, "between") != NULL);

    TEST_CASE("and a relationship between two fields is checked too");

    CHECK_EQ(description_read(&d,
        "smallest = 20\n"
        "largest = 5\n", &faults), 0);
    CHECK(faults.count >= 1);

    TEST_CASE("comments and blank lines are not faults");

    CHECK(description_read(&d,
        "# a comment\n"
        "\n"
        "rooms = 4\n"
        "\n", &faults) == 1);
}
/* }}} */

/* {{{ static void test_the_same_seed */
static void test_the_same_seed(void)
{
    struct world a;
    struct world b;
    struct layout la;
    struct layout lb;
    const char *why = NULL;
    const char *text =
        "name = the deep place\n"
        "rooms = 8\n"
        "smallest = 5\n"
        "largest = 12\n"
        "loops = 2\n"
        "lights = 3\n"
        "require = cellar\n"
        "require = well\n";

    TEST_CASE("the same description and seed give the same world");

    /*
     * What lets a map be REFERRED TO rather than stored. A description plus a
     * seed is a few hundred bytes naming a whole dungeon exactly -- and a GM can
     * hand that to somebody, a test can assert against it, a bug report can
     * include it.
     */
    CHECK(build_from(&a, text, 4207, &la, &why) == 1);
    CHECK(build_from(&b, text, 4207, &lb, &why) == 1);

    CHECK_EQ(world_hash(&a), world_hash(&b));
    CHECK_EQ(la.node_count, lb.node_count);
    CHECK_EQ(la.edge_count, lb.edge_count);

    world_release(&b);

    TEST_CASE("and a different seed gives a different one");

    CHECK(build_from(&b, text, 4208, &lb, &why) == 1);
    CHECK(world_hash(&a) != world_hash(&b));

    world_release(&a);
    world_release(&b);
}
/* }}} */

/* {{{ static void test_it_validates */
static void test_it_validates(void)
{
    struct world w;
    struct layout l;
    struct validation_failure failure;
    char message[256];
    const char *why = NULL;
    uint64_t seed;

    TEST_CASE("every generated world validates, across many seeds");

    /*
     * Produced correct from the start rather than repaired afterwards. A
     * generator that produces worlds the validator refuses is a generator nobody
     * can use, and repairing is how a generator stops matching its own output.
     */
    for (seed = 1; seed <= 40; seed++) {
        if (!build_from(&w,
                "rooms = 7\n"
                "smallest = 4\n"
                "largest = 14\n"
                "loops = 2\n"
                "lights = 2\n", seed, &l, &why)) {
            vtt_report_failure(__FILE__, __LINE__, why);
            continue;
        }

        if (!world_validate(&w, &failure)) {
            validation_failure_describe(&failure, message, sizeof(message));
            vtt_report_failure(__FILE__, __LINE__, message);
        } else {
            CHECK(1);
        }

        world_release(&w);
    }
}
/* }}} */

/* {{{ static void test_it_is_what_was_asked_for */
static void test_it_is_what_was_asked_for(void)
{
    struct world w;
    struct layout l;
    struct description d;
    struct fault_list faults;
    const char *why = NULL;
    uint64_t seed;
    const char *text =
        "rooms = 9\n"
        "smallest = 4\n"
        "largest = 10\n"
        "loops = 3\n"
        "require = cellar\n"
        "require = well\n"
        "require = shrine\n";

    TEST_CASE("the generated world satisfies its description, across many seeds");

    /*
     * A constraint that holds for one seed and not for others is exactly what
     * this catches -- and a single-seed test would have missed it.
     */
    description_read(&d, text, &faults);

    for (seed = 1; seed <= 40; seed++) {
        char message[256];

        if (!build_from(&w, text, seed, &l, &why)) {
            vtt_report_failure(__FILE__, __LINE__, why);
            continue;
        }

        if (!generate_check(&w, &l, &d, &faults)) {
            fault_describe(&faults.faults[0], message, sizeof(message));
            vtt_report_failure(__FILE__, __LINE__, message);
        } else {
            CHECK(1);
        }

        world_release(&w);
    }

    TEST_CASE("and the check is not vacuous -- a wrong world fails it");

    /*
     * A check that passes everything is a check nobody should trust. This asks
     * for one dungeon and compares it against a description of a different one.
     */
    {
        struct description other;

        CHECK(build_from(&w, text, 7, &l, &why) == 1);

        description_read(&other,
            "rooms = 40\n"
            "smallest = 4\n"
            "largest = 10\n", &faults);

        CHECK_EQ(generate_check(&w, &l, &other, &faults), 0);
        CHECK(faults.count > 0);

        world_release(&w);
    }
}
/* }}} */

/* {{{ static void test_sealing_a_doorway_is_caught */
static void test_sealing_a_doorway_is_caught(void)
{
    struct world w;
    struct layout l;
    struct description d;
    struct fault_list faults;
    const char *why = NULL;
    const char *text =
        "rooms = 4\n"
        "smallest = 6\n"
        "largest = 8\n"
        "loops = 0\n";

    TEST_CASE("a dungeon whose doorways are bricked up is caught");

    /*
     * THE CHECK THAT WAS MISSING, AND HOW IT WAS FOUND.
     *
     * An early version of this generator produced a perfectly connected graph
     * and then emitted four solid walls per room. The graph check passed, the
     * validator passed -- every wall was well-formed -- and the result was a row
     * of sealed boxes. The demo drew it and that is the only reason anybody
     * noticed.
     *
     * So the reachability check now asks the geometry rather than the graph. A
     * check that passes everything is worth nothing, so this seals a real
     * dungeon on purpose and insists the check notices.
     */
    description_read(&d, text, &faults);

    CHECK(build_from(&w, text, 5, &l, &why) == 1);
    CHECK_EQ(generate_check(&w, &l, &d, &faults), 1);

    /*
     * Brick up every gap by running a wall down the full height of each room's
     * east side and up the west side of the next.
     */
    {
        uint32_t i;

        for (i = 0; i < l.node_count; i++) {
            uint32_t wall = world_add_wall(&w);
            struct wall *wl;

            if (wall == 0) break;

            wl = world_wall(&w, wall);
            wl->ax = l.nodes[i].x + l.nodes[i].size;
            wl->ay = l.nodes[i].y;
            wl->bx = l.nodes[i].x + l.nodes[i].size;
            wl->by = l.nodes[i].y + l.nodes[i].size;
            wl->flags = BLOCKS_SIGHT | BLOCKS_MOVEMENT;
        }
    }

    CHECK_EQ(generate_check(&w, &l, &d, &faults), 0);

    TEST_CASE("and the fault names the geometry rather than the graph");

    /*
     * The graph is still perfectly connected. Only the geometry changed, and the
     * report has to say so or somebody goes looking in the wrong stage.
     */
    CHECK_EQ(layout_is_connected(&l), 1);

    {
        uint32_t i;
        int named_geometry = 0;

        for (i = 0; i < faults.count; i++) {
            if (strcmp(faults.faults[i].word, "the geometry") == 0) {
                named_geometry = 1;
            }
        }

        CHECK_EQ(named_geometry, 1);
    }

    world_release(&w);
}
/* }}} */

/* {{{ static void test_impossible_descriptions_are_refused */
static void test_impossible_descriptions_are_refused(void)
{
    struct world w;
    struct layout l;
    const char *why = NULL;

    TEST_CASE("more loops than there is room for is refused by name");

    /*
     * Three rooms allow exactly one loop beyond the tree. Asking for six is
     * impossible, and saying so beats spinning or quietly producing fewer.
     */
    CHECK_EQ(build_from(&w,
        "rooms = 3\n"
        "loops = 6\n", 1, &l, &why), 0);

    CHECK(why != NULL);
    CHECK(strstr(why, "loops") != NULL);

    world_release(&w);

    TEST_CASE("more features than rooms is refused by name");

    /*
     * Not "produce something close". A dungeon quietly missing the cellar
     * somebody asked for is worse than an error, because they will not find out
     * until they go looking for it during a session.
     */
    CHECK_EQ(build_from(&w,
        "rooms = 2\n"
        "require = cellar\n"
        "require = well\n"
        "require = shrine\n"
        "require = crypt\n", 1, &l, &why), 0);

    CHECK(why != NULL);
    CHECK(strstr(why, "required features") != NULL);

    world_release(&w);
}
/* }}} */

/* {{{ static void test_the_graph_questions */
static void test_the_graph_questions(void)
{
    struct world w;
    struct layout l;
    const char *why = NULL;

    TEST_CASE("connectivity and loops are questions about the graph");

    /*
     * Each of these is a few lines against a graph and nearly unanswerable
     * against a pile of segments, which is the whole reason the graph exists
     * before the geometry does.
     */
    CHECK(build_from(&w,
        "rooms = 10\n"
        "smallest = 4\n"
        "largest = 8\n"
        "loops = 0\n", 3, &l, &why) == 1);

    CHECK_EQ(layout_is_connected(&l), 1);
    CHECK_EQ(layout_loop_count(&l), 0);
    CHECK_EQ(l.edge_count, l.node_count - 1);   /* A bare tree. */

    world_release(&w);

    TEST_CASE("and asking for loops produces them");

    CHECK(build_from(&w,
        "rooms = 10\n"
        "smallest = 4\n"
        "largest = 8\n"
        "loops = 3\n", 3, &l, &why) == 1);

    /*
     * EXACTLY three, not at most three. The weaker assertion is what let a
     * generator that produced none when one was asked for pass -- the loop
     * placement gave up on a collision and nothing noticed.
     */
    CHECK_EQ(layout_loop_count(&l), 3);
    CHECK_EQ(layout_is_connected(&l), 1);

    world_release(&w);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_the_wall_reports_everything();
    test_the_same_seed();
    test_it_validates();
    test_it_is_what_was_asked_for();
    test_sealing_a_doorway_is_caught();
    test_impossible_descriptions_are_refused();
    test_the_graph_questions();

    return vtt_test_finish("079-test-generate");
}
/* }}} */
