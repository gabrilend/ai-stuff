/*
 * 063-demo-phase-4.c -- three people connect, and one of them tries it on.
 *
 * Phase four claims that the geometry from phase two decides which bytes are
 * allowed onto a socket. That is a claim about bytes, so this demonstrates it by
 * looking at bytes -- the raw outbound buffers, searched for things their owner
 * must not know about.
 *
 * The participants here are test programs rather than browsers, deliberately.
 * The security claim needs a client that can be made to misbehave, and a browser
 * cannot be.
 *
 * Run through ./run-phase-demo 4.
 */

#include "061-door.h"
#include "059-outbound.h"
#include "037-fixture.h"
#include "033-validate.h"
#include "031-region.h"
#include "070-scope.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define M(n) ((wcoord)((n) * WC_ONE))

#define DEMO_DOOR_PORT   47901
#define DEMO_RANGE_FIRST 47910
#define DEMO_RANGE_LAST  47919

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

/* {{{ static int stream_mentions */
static int stream_mentions(struct viewer *v, const struct world *w, uint32_t thing)
{
    const struct thing *t = world_thing_const(w, thing);
    uint8_t needle[8];
    uint32_t x = (uint32_t)t->x;
    uint32_t y = (uint32_t)t->y;

    needle[0] = (uint8_t)(x & 0xFFu);
    needle[1] = (uint8_t)((x >> 8) & 0xFFu);
    needle[2] = (uint8_t)((x >> 16) & 0xFFu);
    needle[3] = (uint8_t)((x >> 24) & 0xFFu);
    needle[4] = (uint8_t)(y & 0xFFu);
    needle[5] = (uint8_t)((y >> 8) & 0xFFu);
    needle[6] = (uint8_t)((y >> 16) & 0xFFu);
    needle[7] = (uint8_t)((y >> 24) & 0xFFu);

    return buffer_contains(&v->outbound, needle, 8);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    struct world w;
    struct pool *pool;
    struct session session;
    struct viewer_set viewers;
    struct door d;
    struct validation_failure failure;
    char message[256];
    const char *why = NULL;

    uint32_t viewer_index[3];
    uint32_t watcher[3];
    const char *names[3] = { "Aelfwine", "Brytha", "Cuthbert" };
    wcoord starts_x[3] = { M(5),  M(15), M(45) };
    wcoord starts_y[3] = { M(5),  M(15), M(10) };

    uint32_t ambush;
    uint32_t i;

    printf("\n");
    printf("  ===========================================================\n");
    printf("   PHASE FOUR -- People connect\n");
    printf("  ===========================================================\n");
    printf("\n");
    printf("  No browser yet. The participants below are test programs, because\n");
    printf("  the claim being made is about bytes on a socket and proving it\n");
    printf("  needs a client that can be told to misbehave.\n");

    fixture_make_two_rooms(&w);

    /* One body with eyes per participant, plus something they must not see. */
    for (i = 0; i < 3; i++) {
        watcher[i] = world_add_thing(&w);
        {
            struct thing *t = world_thing(&w, watcher[i]);
            t->x = starts_x[i];
            t->y = starts_y[i];
            t->facing = 0;
            t->sight_arc = 65535;
            t->sight_range = (uint32_t)M(100);
            t->radius = (uint16_t)(WC_ONE / 2);
            t->kind = 1;
            /*
             * Asked for rather than assumed. An earlier version of this demo set
             * every body's region to 1 and the validator refused the world -- the
             * east room is region 3, and a body claiming to be in the west one is
             * exactly the drift that check exists to catch.
             */
            t->region = region_deepest_containing(&w, t->x, t->y);
        }
    }

    ambush = world_add_thing(&w);
    {
        struct thing *t = world_thing(&w, ambush);
        t->x = M(35);
        t->y = M(17);
        t->kind = 9;
        t->radius = (uint16_t)(WC_ONE / 2);
        t->region = region_deepest_containing(&w, t->x, t->y);
    }

    if (!world_validate(&w, &failure)) {
        printf("\n  The world does not validate: %s\n",
               validation_failure_describe(&failure, message, sizeof(message)));
        world_release(&w);
        return 1;
    }

    pool = pool_start(2);
    session_start(&session, &w, pool, 4207, 8, 10);
    viewer_set_init(&viewers, 8);

    /* --------------------------------------------------------------------- */
    rule("The door, and the price of it");

    if (!door_open(&d, DEMO_DOOR_PORT, DEMO_RANGE_FIRST, DEMO_RANGE_LAST, &why)) {
        printf("    Could not open the door: %s\n", why);
        session_release(&session);
        viewer_set_release(&viewers);
        world_release(&w);
        pool_stop(pool);
        return 1;
    }

    printf("    door port:  %u\n", DEMO_DOOR_PORT);
    printf("    port range: %u to %u  (%u ports)\n",
           DEMO_RANGE_FIRST, DEMO_RANGE_LAST,
           DEMO_RANGE_LAST - DEMO_RANGE_FIRST + 1);
    printf("\n");
    printf("    That range is this design's real cost. A host behind a home\n");
    printf("    router forwards all of it, not one port -- a longer conversation\n");
    printf("    with a router than anybody wants to have.\n");
    printf("\n");
    printf("    What it buys: bytes arriving on a port belong to whoever that\n");
    printf("    port was bound for, decided by the kernel before any of our code\n");
    printf("    runs. No session lookup in the receive path means no bug possible\n");
    printf("    in one -- and the per-viewer filter binds to a socket once rather\n");
    printf("    than being passed along on every message.\n");

    /* --------------------------------------------------------------------- */
    rule("Three people join");

    for (i = 0; i < 3; i++) {
        uint8_t outcome = 0;
        uint16_t port = 0;

        /*
         * Each client does its whole handshake while the server is asked to look
         * in between. One process, taking turns -- a demo that needs three
         * terminals is a demo nobody runs.
         */
        {
            pid_t child = fork();

            if (child == 0) {
                /*
                 * The child is the participant. It joins and then simply waits,
                 * so the parent can accept at its leisure.
                 */
                int fd = door_join_as_client(DEMO_DOOR_PORT, names[i], &outcome, &port);
                if (fd >= 0) {
                    sleep(3);
                    close(fd);
                }
                _exit(0);
            }

            /* The parent admits, then accepts the private connection. */
            {
                /*
                 * Polled with a rest between attempts rather than spun.
                 * Non-blocking accepts in a tight loop burn a processor for the
                 * whole wait, and a demo that heats somebody's machine while it
                 * waits for a socket is a badly behaved demo.
                 */
                struct timespec rest;
                double until;

                rest.tv_sec = 0;
                rest.tv_nsec = 2000000;   /* two milliseconds */

                until = wall_now() + 2.0;
                while (wall_now() < until && viewer_count(&viewers) < i + 2) {
                    door_admit(&d, &viewers, &w, WC_ONE);
                    nanosleep(&rest, NULL);
                }

                until = wall_now() + 2.0;
                while (wall_now() < until && viewer_connected_count(&viewers) < i + 1) {
                    door_connect_waiting(&d, &viewers);
                    nanosleep(&rest, NULL);
                }
            }
        }

        viewer_index[i] = i + 1;

        printf("    %-10s joined, and was given port %u\n",
               names[i], viewer_at(&viewers, viewer_index[i])->port);
    }

    printf("\n    ports in use: %u of %u\n",
           door_ports_in_use(&d), DEMO_RANGE_LAST - DEMO_RANGE_FIRST + 1);
    printf("    connected:    %u\n", viewer_connected_count(&viewers));

    printf("\n");
    printf("    Permission did not travel in any of those requests. A client\n");
    printf("    cannot ask to be a GM -- the server looks up what somebody may\n");
    printf("    command and informs them, and that is enforced by the request\n");
    printf("    having no field for it rather than by a check somebody could\n");
    printf("    forget to write.\n");

    /* --------------------------------------------------------------------- */
    rule("What each of them is told");

    for (i = 0; i < 3; i++) {
        struct viewpoint from;
        struct viewer *v = viewer_at(&viewers, viewer_index[i]);
        uint32_t written;

        viewpoint_gather(&from, &w, viewer_index[i]);

        fog_fold(&v->fog, &w, watcher[i]);
        written = outbound_build(&session, &viewers, viewer_index[i], &from);

        printf("    %-10s %4u instructions, %5u bytes  (%u walls, %u bodies)\n",
               names[i], written, v->outbound.count, v->walls_sent, v->things_sent);
    }

    printf("\n");
    printf("    Different people are told different amounts, because they are in\n");
    printf("    different places. That is the whole design showing up as a number.\n");

    /* --------------------------------------------------------------------- */
    rule("The leak sweep");

    printf("    A body waits at (35, 17), in the east room. Cuthbert is in that\n");
    printf("    room. The other two are not.\n\n");

    for (i = 0; i < 3; i++) {
        struct viewer *v = viewer_at(&viewers, viewer_index[i]);
        int visible = sight_point_visible(&w, watcher[i],
                                          world_thing_const(&w, ambush)->x,
                                          world_thing_const(&w, ambush)->y);
        int in_stream = stream_mentions(v, &w, ambush);

        printf("    %-10s can see it: %-3s     in their bytes: %-3s   %s\n",
               names[i],
               visible ? "yes" : "no",
               in_stream ? "YES" : "no",
               (visible == in_stream) ? "" : "  <-- MISMATCH");
    }

    printf("\n");
    printf("    Searched in the raw outbound buffers rather than by asking the\n");
    printf("    filter whether it would have sent something. Asking the filter is\n");
    printf("    asking the accused: a test that shares an implementation with the\n");
    printf("    thing it tests agrees with it about the bug too.\n");

    printf("\n    Now the same body is flagged hidden and put right in front of\n");
    printf("    Cuthbert, three metres away with nothing in between:\n\n");

    world_thing(&w, ambush)->x = M(42);
    world_thing(&w, ambush)->y = M(10);
    world_thing(&w, ambush)->flags = THING_HIDDEN;
    world_thing(&w, ambush)->region =
        region_deepest_containing(&w, M(42), M(10));

    for (i = 0; i < 3; i++) {
        struct viewpoint from;
        struct viewer *v = viewer_at(&viewers, viewer_index[i]);
        int visible;
        int in_stream;

        viewpoint_gather(&from, &w, viewer_index[i]);

        outbound_build(&session, &viewers, viewer_index[i], &from);

        visible = sight_point_visible(&w, watcher[i], M(42), M(10));
        in_stream = stream_mentions(v, &w, ambush);

        printf("    %-10s geometry says: %-3s   in their bytes: %-3s\n",
               names[i], visible ? "yes" : "no", in_stream ? "YES" : "no");
    }

    printf("\n");
    printf("    The geometry says Cuthbert can see it. The bytes say nobody was\n");
    printf("    told. Hidden beats sight, in that order, always.\n");

    /* --------------------------------------------------------------------- */
    rule("A command that is refused");

    {
        uint16_t reason = session_command(&session, VERB_DRIVE, 9999, 0, WC_ONE);
        struct viewer *v = viewer_at(&viewers, viewer_index[0]);

        buffer_clear(&v->outbound);
        outbound_refusal(&viewers, viewer_index[0], VERB_DRIVE, 9999, reason);

        printf("    Aelfwine asks to drive thing 9999, which does not exist.\n\n");
        printf("      -> %s\n", refusal_sentence(reason));
        printf("\n");
        printf("    A sentence, not a number. Nobody reads a rules screen: the\n");
        printf("    refusal is where a person finds out what the rules are, at the\n");
        printf("    moment they try. If it were silence, the only way to learn\n");
        printf("    would be to be told by somebody who already knows.\n");
    }

    /* --------------------------------------------------------------------- */
    rule("What it costs");

    {
        double started;
        const int rounds = 200;
        int round;
        uint64_t total_bytes = 0;

        started = wall_now();

        for (round = 0; round < rounds; round++) {
            for (i = 0; i < 3; i++) {
                struct viewpoint from;
                viewpoint_gather(&from, &w, viewer_index[i]);
                outbound_build(&session, &viewers, viewer_index[i], &from);
                total_bytes += viewer_at(&viewers, viewer_index[i])->outbound.count;
            }
        }

        printf("    %d updates for each of 3 viewers, in %.4f seconds.\n",
               rounds, wall_now() - started);
        printf("    %.1f microseconds to build one viewer's update.\n",
               (wall_now() - started) * 1000000.0 / (double)(rounds * 3));
        printf("    %llu bytes per viewer per update, on average.\n",
               (unsigned long long)(total_bytes / (uint64_t)(rounds * 3)));
        printf("\n");
        printf("    At twenty beats a second that is about %llu kilobytes a second\n",
               (unsigned long long)((total_bytes / (uint64_t)(rounds * 3)) * 20 / 1024));
        printf("    per person, which phase five has to fit a browser inside.\n");
        printf("\n");
        printf("    Most of it is walls, and walls come from memory -- so the\n");
        printf("    number stops growing once somebody has explored the map, while\n");
        printf("    the bodies part keeps changing every beat.\n");
    }

    printf("\n");
    printf("  Next: phase five, where a browser draws all this and you can\n");
    printf("  actually walk around in it.\n");
    printf("\n");

    door_close(&d);
    session_release(&session);
    viewer_set_release(&viewers);
    world_release(&w);
    pool_stop(pool);

    return 0;
}
/* }}} */
