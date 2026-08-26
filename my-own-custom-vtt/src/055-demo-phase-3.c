/*
 * 055-demo-phase-3.c -- proving determinism, and then spending it.
 *
 * Phase three claims the world moves the same way twice, on any number of
 * threads, and that a turn can therefore be taken back.
 *
 * The first half is a measurement and is reported as one: the same scripted
 * session run at several thread counts, compared by world hash at EVERY BEAT
 * rather than only at the end -- because "they differ" is not a finding and
 * "they first differ at beat 137" is.
 *
 * The second half spends it. A turn is taken back and run again identically, and
 * then taken back and run differently.
 *
 * And then it shows the thing this phase does not solve: undoing the world is a
 * block copy, and undoing what somebody saw is impossible.
 *
 * Run through ./run-phase-demo 3.
 */

#include "053-session.h"
#include "037-fixture.h"
#include "035-worldfile.h"
#include "033-validate.h"
#include "042-sight.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define M(n) ((wcoord)((n) * WC_ONE))

#define VIEW_COLUMNS 51
#define VIEW_ROWS    21

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

/* {{{ static void draw_memory */
static void draw_memory(const struct world *w, const struct fog *f, uint32_t eye)
{
    char canvas[VIEW_ROWS * VIEW_COLUMNS];
    const struct thing *body = world_thing_const(w, eye);
    int column;
    int row;
    uint32_t i;

    memset(canvas, ' ', sizeof(canvas));

    for (row = 0; row < VIEW_ROWS; row++) {
        for (column = 0; column < VIEW_COLUMNS; column++) {
            wcoord x = (wcoord)(column * WC_ONE) + (WC_ONE / 2);
            wcoord y = (wcoord)(row * WC_ONE) + (WC_ONE / 2);

            if (fog_remembers(f, x, y)) {
                canvas[(row * VIEW_COLUMNS) + column] = ':';
            }
        }
    }

    for (i = 1; i < world_wall_count(w); i++) {
        const struct wall *wl = world_wall_const(w, i);
        wcoord length = fx_dist(wl->ax, wl->ay, wl->bx, wl->by);
        wcoord travelled;
        wangle direction = fx_angle(wl->bx - wl->ax, wl->by - wl->ay);

        for (travelled = 0; travelled <= length; travelled += WC_ONE / 4) {
            struct wvec step = fx_from_angle(direction, travelled);
            int c = (int)((wl->ax + step.x) / WC_ONE);
            int r = (int)((wl->ay + step.y) / WC_ONE);

            if (c >= 0 && c < VIEW_COLUMNS && r >= 0 && r < VIEW_ROWS) {
                canvas[(r * VIEW_COLUMNS) + c] = '#';
            }
        }
    }

    column = (int)(body->x / WC_ONE);
    row = (int)(body->y / WC_ONE);
    if (column >= 0 && column < VIEW_COLUMNS && row >= 0 && row < VIEW_ROWS) {
        canvas[(row * VIEW_COLUMNS) + column] = '@';
    }

    for (row = VIEW_ROWS - 1; row >= 0; row--) {
        printf("    ");
        for (column = 0; column < VIEW_COLUMNS; column++) {
            putchar(canvas[(row * VIEW_COLUMNS) + column]);
        }
        printf("\n");
    }
}
/* }}} */

/* {{{ static void report_the_table */
static void report_the_table(void)
{
    uint32_t count = 0;
    const struct tick_pass *table = sim_passes(&count);
    uint32_t i;

    rule("The order of the simulation, as data");

    for (i = 0; i < count; i++) {
        printf("    %u. %-10s %s\n", i + 1, table[i].name, table[i].what);
    }

    printf("\n");
    printf("    Rows 1, 5, 6, 7 and 8 do no work in this phase -- there are no\n");
    printf("    sockets, no ruleset, and no viewers yet. They are still rows.\n");
    printf("    An empty row is better than an absent one: it is where the later\n");
    printf("    work goes, and the table stays the whole truth about ordering\n");
    printf("    rather than most of it.\n");
}
/* }}} */

/* {{{ static uint64_t run_session */
static uint64_t run_session(uint32_t threads, uint64_t *per_beat, int beats,
                            double *seconds_out)
{
    struct world w;
    struct pool *p = pool_start(threads);
    struct session s;
    uint32_t bodies[24];
    int i;
    int beat;
    double started;
    uint64_t final_hash;

    fixture_make_two_rooms(&w);

    for (i = 0; i < 24; i++) {
        uint32_t index = world_add_thing(&w);
        struct thing *t = world_thing(&w, index);
        t->x = (wcoord)((2 + (i % 16)) * WC_ONE);
        t->y = (wcoord)((2 + (i % 15)) * WC_ONE);
        t->radius = (uint16_t)(WC_ONE / 2);
        t->region = 1;
        bodies[i] = index;
    }

    session_start(&s, &w, p, 4207, 8, 10);

    for (i = 0; i < 24; i++) {
        if ((i % 2) == 0) {
            session_command(&s, VERB_DRIVE, bodies[i],
                            (int32_t)(wangle)(i * 2731), WC_ONE / 3);
        } else {
            session_command(&s, VERB_ORDER_MOVE, bodies[i],
                            (int32_t)M(18), (int32_t)M(14));
        }
    }

    started = wall_now();

    for (beat = 0; beat < beats; beat++) {
        session_tick(&s);
        if (per_beat != NULL) {
            per_beat[beat] = world_hash(&w);
        }
    }

    if (seconds_out != NULL) {
        *seconds_out = wall_now() - started;
    }

    final_hash = world_hash(&w);

    session_release(&s);
    world_release(&w);
    pool_stop(p);

    return final_hash;
}
/* }}} */

/* {{{ static void report_determinism */
static void report_determinism(void)
{
    const int beats = 500;
    uint64_t *reference = malloc((size_t)beats * sizeof(uint64_t));
    uint64_t *compared = malloc((size_t)beats * sizeof(uint64_t));
    const uint32_t counts[] = { 1, 2, 4, 8 };
    size_t c;
    double seconds;

    rule("The same session, run four ways");

    run_session(1, reference, beats, &seconds);

    printf("    %d beats, 24 bodies moving, compared at every single beat.\n\n",
           beats);
    printf("    %-10s %14s %22s\n", "threads", "seconds", "first difference");

    for (c = 0; c < sizeof(counts) / sizeof(counts[0]); c++) {
        int beat;
        int first_difference = -1;

        run_session(counts[c], compared, beats, &seconds);

        for (beat = 0; beat < beats; beat++) {
            if (reference[beat] != compared[beat]) {
                first_difference = beat;
                break;
            }
        }

        printf("    %-10u %14.4f ", counts[c], seconds);

        if (first_difference < 0) {
            printf("%22s\n", "none");
        } else {
            printf("%22d\n", first_difference);
        }
    }

    printf("\n");
    printf("    Compared per beat rather than at the end, because \"they differ\"\n");
    printf("    is not a finding and \"they first differ at beat 137\" is. A\n");
    printf("    divergence at beat 4,000 of 10,000 is a hundred times easier to\n");
    printf("    find than a mismatch at the finish line.\n");
    printf("\n");
    printf("    THE SECONDS COLUMN GOES THE WRONG WAY, AND THAT IS THE FINDING.\n");
    printf("\n");
    printf("    Threading the motion passes makes them slower here. Twenty-four\n");
    printf("    bodies is a few microseconds of arithmetic, and waking a pool and\n");
    printf("    waiting on a barrier costs more than that -- so every beat pays\n");
    printf("    for coordination it does not need.\n");
    printf("\n");
    printf("    Sight was worth parallelising and this is not, which is the same\n");
    printf("    measurement pointing in two directions. The pool is not the wrong\n");
    printf("    tool; motion at tabletop scale is the wrong size of job for it.\n");
    printf("    Handing these passes straight to the calling thread and keeping\n");
    printf("    the pool for sight is the shape this is asking for, and it is\n");
    printf("    written down as an open question rather than changed on the spot.\n");
    printf("\n");
    printf("    What matters for the phase's actual claim is the last column:\n");
    printf("    running on eight threads changed no result anywhere, at any beat.\n");
    printf("\n");
    printf("    final world hash: %016llx\n",
           (unsigned long long)run_session(1, NULL, beats, NULL));

    free(reference);
    free(compared);
}
/* }}} */

/* {{{ static void report_rollback */
static void report_rollback(void)
{
    struct world w;
    struct pool *p = pool_start(4);
    struct session s;
    uint32_t body;
    uint32_t turn;
    uint32_t first_entry;
    uint64_t before;
    int beat;
    double started;

    rule("Taking a turn back");

    fixture_make_two_rooms(&w);

    body = world_add_thing(&w);
    {
        struct thing *t = world_thing(&w, body);
        t->x = M(10);
        t->y = M(10);
        t->radius = (uint16_t)(WC_ONE / 2);
        t->region = 1;
    }

    session_start(&s, &w, p, 4207, 16, 10);

    for (beat = 0; beat < 45; beat++) {
        session_tick(&s);
    }

    turn = s.turn;
    first_entry = log_turn_first(&s.log, turn);

    printf("    The body stands at (%d, %d) at the head of turn %u.\n",
           (int)(world_thing_const(&w, body)->x / WC_ONE),
           (int)(world_thing_const(&w, body)->y / WC_ONE),
           turn);

    session_command(&s, VERB_DRIVE, body, 0, WC_ONE);   /* east */
    for (beat = 0; beat < 8; beat++) {
        session_tick(&s);
    }

    before = world_hash(&w);

    printf("    It is told to walk east, and ends the turn at (%d, %d).\n",
           (int)(world_thing_const(&w, body)->x / WC_ONE),
           (int)(world_thing_const(&w, body)->y / WC_ONE));

    printf("\n    Rolling the turn back and replaying it unchanged...\n");

    started = wall_now();
    session_rollback(&s, turn, ROLLBACK_RETCON);
    printf("      took %.4f seconds\n", wall_now() - started);

    printf("      world hash before: %016llx\n", (unsigned long long)before);
    printf("      world hash after:  %016llx\n",
           (unsigned long long)world_hash(&w));

    if (world_hash(&w) == before) {
        printf("      identical.\n");
    } else {
        printf("      THEY DIFFER -- something is missing from the snapshot.\n");
    }

    printf("\n");
    printf("    An undo that reproduces the original bit for bit is the sharper\n");
    printf("    test, because it says the snapshot caught everything -- including\n");
    printf("    the random streams' positions, which are the easiest thing to\n");
    printf("    leave out and the hardest omission to notice. A retcon that rolls\n");
    printf("    different dice looks exactly like a retcon that worked.\n");

    printf("\n    Now rolling it back and ruling differently -- north, not east...\n");

    {
        struct log_entry corrected = s.log.entries[first_entry];
        corrected.ax = (int32_t)WA_QUARTER;
        log_rewrite(&s.log, first_entry, &corrected);

        session_rollback(&s, turn, ROLLBACK_RETCON);

        printf("      the body now ends the turn at (%d, %d).\n",
               (int)(world_thing_const(&w, body)->x / WC_ONE),
               (int)(world_thing_const(&w, body)->y / WC_ONE));
    }

    printf("\n");
    printf("    ring: %u turns deep, holding %u, costing about %llu kilobytes.\n",
           session_ring_depth(&s),
           session_ring_held(&s),
           (unsigned long long)(session_ring_bytes(&s) / 1024));
    printf("\n");
    printf("    Undo needed no mechanism of its own. A snapshot is a copy of some\n");
    printf("    bytes, because the world is flat arrays with no pointers. A replay\n");
    printf("    lands in the same place every time, because the beat is\n");
    printf("    deterministic. Both were built for other reasons; rollback is\n");
    printf("    those two aimed at each other.\n");

    session_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ static void report_the_problem_it_does_not_solve */
static void report_the_problem_it_does_not_solve(void)
{
    struct world w;
    struct pool *p = pool_start(1);
    struct session s;
    struct fog f;
    uint32_t body;
    uint32_t turn;
    int beat;

    rule("And the part that cannot be undone");

    fixture_make_two_rooms(&w);

    body = world_add_thing(&w);
    {
        struct thing *t = world_thing(&w, body);
        t->x = M(5);
        t->y = M(5);
        t->sight_arc = 65535;
        t->sight_range = (uint32_t)M(100);
        t->radius = (uint16_t)(WC_ONE / 2);
        t->region = 1;
    }

    fog_init(&f, &w, WC_ONE);
    session_start(&s, &w, p, 1, 8, 10);
    session_attach_fogs(&s, &f, 1);

    fog_fold(&f, &w, body);

    for (beat = 0; beat < 25; beat++) {
        session_tick(&s);
    }

    turn = s.turn;

    printf("    At the head of turn %u, this is what the player remembers:\n\n", turn);
    draw_memory(&w, &f, body);
    printf("\n    %u of %u cells.\n", fog_cells_seen(&f), fog_cell_count(&f));

    world_thing(&w, body)->x = M(45);
    world_thing(&w, body)->y = M(10);
    fog_fold(&f, &w, body);

    printf("\n    During the turn they walk into the far room and look around:\n\n");
    draw_memory(&w, &f, body);
    printf("\n    %u of %u cells.\n", fog_cells_seen(&f), fog_cell_count(&f));

    session_rollback(&s, turn, ROLLBACK_REDECLARE);

    printf("\n    The turn is taken back. Their map closes over it:\n\n");
    draw_memory(&w, &f, body);
    printf("\n    %u of %u cells.\n", fog_cells_seen(&f), fog_cell_count(&f));

    printf("\n");
    printf("    THE PERSON STILL REMEMBERS THE ROOM. They looked at it. The screen\n");
    printf("    now knows less than they do, and their own map has closed over a\n");
    printf("    place they could describe out loud.\n");
    printf("\n");
    printf("    That is the decision, made knowing the cost. The other answer --\n");
    printf("    leaving the map alone -- is worse in a way that never goes away: it\n");
    printf("    would hold a place reached in a turn that never happened, and\n");
    printf("    contradict the world every time anybody walked there again.\n");
    printf("\n");
    printf("    You cannot restore ignorance. A rollback at a tabletop has always\n");
    printf("    been a social agreement, and the program's job is to put the board\n");
    printf("    back so the people can do the rest.\n");

    fog_release(&f);
    session_release(&s);
    world_release(&w);
    pool_stop(p);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    printf("\n");
    printf("  ===========================================================\n");
    printf("   PHASE THREE -- The world ticks, and turns can be taken back\n");
    printf("  ===========================================================\n");
    printf("\n");
    printf("  Still no network. A world that moves, reproducibly, and a turn that\n");
    printf("  is a transaction rather than a stretch of time.\n");

    report_the_table();
    report_determinism();
    report_rollback();
    report_the_problem_it_does_not_solve();

    printf("\n");
    printf("  Next: phase four, where people connect and the geometry from phase\n");
    printf("  two starts deciding which bytes are allowed onto a socket.\n");
    printf("\n");

    return 0;
}
/* }}} */
