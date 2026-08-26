/*
 * 068-server-main.c -- the program a host runs.
 *
 * Holds the world, opens the door, and beats. This is the only place in the
 * project where the eight passes of the tick are wired to real sockets, and it
 * is deliberately thin: everything it calls has been built and tested on its own,
 * and this file is the order they go in.
 *
 * Usage:
 *   068-server        -- door on the default port, the two-room fixture
 *   068-server 47901  -- a different door port
 *
 * The first thing it does is read input/ and the last thing it does is write to
 * output/. Right now that is a report rather than a configuration, because
 * nothing in input/ has been decided yet.
 */

#include "061-door.h"
#include "059-outbound.h"
#include "037-fixture.h"
#include "033-validate.h"
#include "031-region.h"
#include "070-scope.h"
#include "035-worldfile.h"
#include "096-engrave.h"
#include "094-creature.h"

/*
 * Where a session leaves its carving. The RAM tier, because it is regenerated
 * every time a session ends -- and ./share-engraving is what moves one somewhere
 * durable, which is the other half of the trade for a format that cannot be
 * repaired.
 *
 * The bridge reads this same path at startup and hangs it in the action bar.
 */
#define ENGRAVING_PATH "/dev/shm/my-own-custom-vtt/engravings/last.engraving"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <time.h>

#define M(n) ((wcoord)((n) * WC_ONE))

#define DEFAULT_DOOR_PORT   47901
#define DEFAULT_RANGE_FIRST 47910
#define DEFAULT_RANGE_LAST  47929

/* Twenty beats a second. Phase 2 measured that sight does not constrain this. */
#define TICKS_PER_SECOND 20

static volatile sig_atomic_t asked_to_stop = 0;

/* {{{ static void note_the_interrupt */
static void note_the_interrupt(int which)
{
    (void)which;

    /*
     * A flag, not a shutdown. Doing real work in a signal handler is how a clean
     * exit becomes a crash in the middle of a socket write.
     */
    asked_to_stop = 1;
}
/* }}} */

/* {{{ static double wall_now */
static double wall_now(void)
{
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (double)now.tv_sec + ((double)now.tv_nsec / 1000000000.0);
}
/* }}} */

/* {{{ static void rest_until */
static void rest_until(double when)
{
    double now = wall_now();
    struct timespec gap;

    if (when <= now) {
        return;   /* Already late. Do not sleep negatively. */
    }

    gap.tv_sec = (time_t)(when - now);
    gap.tv_nsec = (long)(((when - now) - (double)gap.tv_sec) * 1000000000.0);

    nanosleep(&gap, NULL);
}
/* }}} */

/* {{{ static uint32_t body_for_viewer */
static uint32_t body_for_viewer(struct world *w, uint32_t which)
{
    uint32_t index = world_add_thing(w);
    struct thing *t = world_thing(w, index);

    /*
     * Somewhere in the west room, spread out so two people do not start standing
     * inside each other. Bodies pass through each other, so that is cosmetic
     * rather than a rule -- how much space a creature claims is a ruleset's
     * business.
     */
    t->x = M(4) + (wcoord)((which % 5) * 2 * WC_ONE);
    t->y = M(4) + (wcoord)((which % 3) * 2 * WC_ONE);
    t->facing = 0;
    t->sight_arc = 65535;
    t->sight_range = (uint32_t)M(40);
    t->radius = (uint16_t)(WC_ONE / 2);
    t->kind = 1;
    t->region = region_deepest_containing(w, t->x, t->y);

    return index;
}
/* }}} */

/* {{{ int main */
int main(int argc, char **argv)
{
    struct world w;
    struct pool *pool;
    struct session session;
    struct viewer_set viewers;
    struct door d;
    struct validation_failure failure;
    char message[256];
    const char *why = NULL;

    uint16_t door_port = DEFAULT_DOOR_PORT;
    uint32_t bodies[64];
    uint32_t i;

    double next_beat;
    uint64_t beats = 0;
    uint64_t bytes_out = 0;
    double started;

    if (argc > 1) {
        door_port = (uint16_t)atoi(argv[1]);
    }

    /*
     * Line buffering, so that what this prints appears when it is printed rather
     * than when the program ends. Redirected to a file, C buffers a whole block
     * by default -- which makes a server that is running perfectly well look
     * exactly like a server that hung on startup.
     */
    setvbuf(stdout, NULL, _IOLBF, 0);

    signal(SIGINT, note_the_interrupt);
    signal(SIGTERM, note_the_interrupt);

    memset(bodies, 0, sizeof(bodies));

    printf("reading input/ ... nothing configured yet; using the two-room fixture\n");

    if (!fixture_make_two_rooms(&w)) {
        printf("could not build the world\n");
        return 1;
    }

    if (!world_validate(&w, &failure)) {
        printf("the world does not validate: %s\n",
               validation_failure_describe(&failure, message, sizeof(message)));
        world_release(&w);
        return 1;
    }

    pool = pool_start(0);
    session_start(&session, &w, pool, 4207, 16, 10);
    viewer_set_init(&viewers, 16);

    if (!door_open(&d, door_port, DEFAULT_RANGE_FIRST, DEFAULT_RANGE_LAST, &why)) {
        printf("could not open the door: %s\n", why);
        session_release(&session);
        viewer_set_release(&viewers);
        world_release(&w);
        pool_stop(pool);
        return 1;
    }

    printf("\n");
    printf("  the door is open on port %u\n", door_port);
    printf("  private ports %u to %u\n", DEFAULT_RANGE_FIRST, DEFAULT_RANGE_LAST);
    printf("  beating %d times a second\n", TICKS_PER_SECOND);
    printf("\n");
    printf("  a participant runs:  069-bridge 127.0.0.1 %u <name>\n", door_port);
    printf("  and opens:           http://localhost:12345\n");
    printf("\n");
    printf("  ctrl-c to stop\n\n");

    started = wall_now();
    next_beat = started;

    while (!asked_to_stop) {
        uint32_t joined;

        /* ---- pass 1: intake ------------------------------------------- */

        joined = door_admit(&d, &viewers, &w, WC_ONE);
        door_connect_waiting(&d, &viewers);

        if (joined > 0) {
            /*
             * Somebody new. Give them a body and tell them which one it is --
             * they cannot ask, and they do not get to choose.
             */
            for (i = 1; i < viewer_count(&viewers) && i < 64; i++) {
                struct viewer *v = viewer_at(&viewers, i);

                if (v->state != VIEWER_EMPTY && bodies[i] == 0) {
                    bodies[i] = body_for_viewer(&w, i);
                    sim_fit_to_world(&session.sim);

                    /*
                     * A scope over that one body, driven with keys. The simplest
                     * position on the dial -- and it goes through exactly the
                     * same machinery a commander or a tavern would.
                     */
                    scope_make_list(&w, i, STYLE_DRIVEN, &bodies[i], 1, "a player");

                    {
                        struct instruction hello;
                        instruction_begin(&hello, OP_HELLO);
                        instruction_set(&hello, 0, bodies[i]);
                        instruction_set(&hello, 1, (uint32_t)w.min_x);
                        instruction_set(&hello, 2, (uint32_t)w.min_y);
                        instruction_set(&hello, 3, (uint32_t)w.max_x);
                        instruction_set(&hello, 4, (uint32_t)w.max_y);
                        instruction_encode(&hello, &v->outbound);
                    }

                    printf("  %s joined on port %u, driving thing %u\n",
                           "somebody", v->port, bodies[i]);
                }
            }
        }

        door_drain(&d, &viewers);

        for (i = 1; i < viewer_count(&viewers) && i < 64; i++) {
            struct viewer *v = viewer_at(&viewers, i);
            struct instruction in;

            if (v->state != VIEWER_CONNECTED) {
                continue;
            }

            while (buffer_remaining(&v->inbound) > 0) {
                uint8_t how = instruction_decode(&in, &v->inbound);

                if (how != PROTO_OK) {
                    /*
                     * Not our language. The socket closes; there is nobody honest
                     * on the other end to explain anything to. A truncated
                     * instruction is the exception -- the rest of it is simply
                     * still in flight, so the bytes stay for next beat.
                     */
                    if (how != PROTO_TRUNCATED) {
                        viewer_departs(&viewers, i);
                    }
                    break;
                }

                {
                    /*
                     * From this viewer, so the gauntlet's membership and style
                     * gates have somebody to check against. The viewer index came
                     * from the port these bytes arrived on -- the kernel decided
                     * it before any of our code ran.
                     */
                    uint16_t refusal = session_command_from(&session, i, in.opcode,
                                                       instruction_get(&in, 0),
                                                       (int32_t)instruction_get(&in, 1),
                                                       (int32_t)instruction_get(&in, 2));

                    if (refusal != REFUSED_NOT_AT_ALL) {
                        outbound_refusal(&viewers, i, in.opcode,
                                         instruction_get(&in, 0), refusal);
                    }
                }
            }

            buffer_clear(&v->inbound);
        }

        /* ---- passes 2 to 5: the world moves --------------------------- */

        session_tick(&session);

        /* ---- passes 6 and 7: sight, then memory ----------------------- */

        for (i = 1; i < viewer_count(&viewers) && i < 64; i++) {
            struct viewer *v = viewer_at(&viewers, i);

            if (v->state == VIEWER_CONNECTED && bodies[i] != 0) {
                fog_fold(&v->fog, &w, bodies[i]);
            }
        }

        /* ---- pass 8: outbound ----------------------------------------- */

        for (i = 1; i < viewer_count(&viewers) && i < 64; i++) {
            struct viewer *v = viewer_at(&viewers, i);
            struct viewpoint from;

            if (v->state != VIEWER_CONNECTED || bodies[i] == 0) {
                continue;
            }

            viewpoint_gather(&from, &w, i);

            outbound_build(&session, &viewers, i, &from);
            bytes_out += v->outbound.count;
        }

        door_flush(&d, &viewers);

        beats++;

        next_beat += 1.0 / (double)TICKS_PER_SECOND;
        rest_until(next_beat);

        /*
         * If we have fallen a long way behind -- the machine was busy, or
         * somebody suspended the process -- give up on catching up rather than
         * running a hundred beats back to back. A world that fast-forwards is
         * worse than one that skipped.
         */
        if (wall_now() - next_beat > 1.0) {
            next_beat = wall_now();
        }
    }

    printf("\n");
    printf("writing output/goodbye ...\n");
    printf("  %llu beats in %.1f seconds (%.1f a second)\n",
           (unsigned long long)beats,
           wall_now() - started,
           (double)beats / (wall_now() - started));
    printf("  %llu bytes sent to viewers\n", (unsigned long long)bytes_out);
    printf("  world hash at the end: %016llx\n",
           (unsigned long long)world_hash(&w));

    /*
     * THE LAST THING A SESSION DOES IS CARVE ITSELF.
     *
     * Eight numbers, drawn as an animal whose lines are the walls of the table
     * holding them. The next bridge to start hangs it in the action bar, so a
     * table's history is visible while the table is playing.
     *
     * Written to the RAM tier, which is the wrong place for the one artifact
     * meant to outlive the machine -- and that is what ./share-engraving is for.
     */
    {
        struct record r;
        const char *why = "";

        /*
         * Minus the sentinel. Index 0 of the viewer set is the reserved empty
         * record that is never handed out, the same convention as every block in
         * the world -- so a table with nobody at it reported one seat until this
         * was noticed in the first carving a real session produced.
         */
        record_gather(&r, &session, viewer_count(&viewers) - 1u);

        if (engrave_to_file(&r, ALPHABET_CARVED, ENGRAVING_PATH, &why)) {
            printf("  carved a %s at %s\n",
                   creature_name(creature_from_seed(r.seed)), ENGRAVING_PATH);
        } else {
            /*
             * Said out loud. A record log that silently failed to be written is
             * a session nobody can point at afterwards, and the failure is
             * always something specific -- a missing directory, a number too
             * wide for its chamber.
             */
            printf("  the engraving was not carved: %s\n", why);
        }
    }

    printf("goodbye\n");

    door_close(&d);
    session_release(&session);
    viewer_set_release(&viewers);
    world_release(&w);
    pool_stop(pool);

    return 0;
}
/* }}} */
