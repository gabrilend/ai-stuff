/*
 * 046-demo-phase-2.c -- what a body can see, drawn.
 *
 * Phase two claims that sight can be computed exactly, that memory is a
 * different thing from sight, and that the whole pass is cheap enough to run per
 * viewer per tick.
 *
 * The first two are geometric facts and a table of numbers would hide them, so
 * this draws them: a body walks from one room to the other and the picture shows
 * what it can see now, what it remembers, and what it has never laid eyes on.
 *
 * The third is a measurement, and it is reported from the run rather than quoted
 * from a document -- including the number the tick rate will have to fit inside.
 *
 * Run through ./run-phase-demo 2.
 */

#include "037-fixture.h"
#include "042-sight.h"
#include "044-fog.h"
#include "040-threadpool.h"
#include "033-validate.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define M(n) ((wcoord)((n) * WC_ONE))

/* The fixture is fifty metres by twenty. One character per metre fits a terminal. */
#define VIEW_COLUMNS 51
#define VIEW_ROWS    21

/*
 * Two clocks, because they answer different questions and confusing them makes a
 * parallel measurement look like a slowdown.
 *
 *   clock() counts PROCESSOR time -- the sum across every thread. It says how
 *   much work was done, and it goes UP when work is shared, because coordinating
 *   costs something.
 *
 *   clock_gettime(CLOCK_MONOTONIC) counts WALL time -- how long you waited. It
 *   goes DOWN when work is shared, and it is what a person at a table feels.
 *
 * A table reporting only the first would show threading making things worse.
 */

/* {{{ static double cpu_seconds_since */
static double cpu_seconds_since(clock_t start)
{
    return (double)(clock() - start) / (double)CLOCKS_PER_SEC;
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

/* {{{ static void paint_walls */
static void paint_walls(const struct world *w, char *canvas)
{
    uint32_t i;

    /*
     * Each wall is walked in small steps and the cell under each step is marked.
     * A wall is a line segment and the canvas is characters, so something has to
     * quantise -- and doing it here, in the viewer, is the right place. The world
     * itself never learns that a character grid exists.
     */
    for (i = 1; i < world_wall_count(w); i++) {
        const struct wall *wl = world_wall_const(w, i);
        wcoord length = fx_dist(wl->ax, wl->ay, wl->bx, wl->by);
        wcoord travelled;
        wangle direction = fx_angle(wl->bx - wl->ax, wl->by - wl->ay);

        for (travelled = 0; travelled <= length; travelled += WC_ONE / 4) {
            struct wvec step = fx_from_angle(direction, travelled);
            int column = (int)((wl->ax + step.x) / WC_ONE);
            int row = (int)((wl->ay + step.y) / WC_ONE);

            if (column >= 0 && column < VIEW_COLUMNS && row >= 0 && row < VIEW_ROWS) {
                canvas[(row * VIEW_COLUMNS) + column] = '#';
            }
        }
    }
}
/* }}} */

/* {{{ static void draw */
static void draw(const struct world *w, const struct fog *f, uint32_t eye)
{
    char canvas[VIEW_ROWS * VIEW_COLUMNS];
    const struct thing *body = world_thing_const(w, eye);
    int column;
    int row;
    uint32_t i;

    memset(canvas, ' ', sizeof(canvas));

    /*
     * Three layers, painted in order of increasing certainty: never seen, then
     * remembered, then visible right now, then what is standing in it.
     */
    for (row = 0; row < VIEW_ROWS; row++) {
        for (column = 0; column < VIEW_COLUMNS; column++) {
            wcoord x = (wcoord)(column * WC_ONE) + (WC_ONE / 2);
            wcoord y = (wcoord)(row * WC_ONE) + (WC_ONE / 2);
            char *cell = &canvas[(row * VIEW_COLUMNS) + column];

            if (sight_point_visible(w, eye, x, y)) {
                *cell = '.';
            } else if (fog_remembers(f, x, y)) {
                *cell = ':';
            }
        }
    }

    paint_walls(w, canvas);

    /* Bodies, but only the ones this eye can actually see. */
    for (i = 1; i < world_thing_count(w); i++) {
        const struct thing *t = world_thing_const(w, i);
        int c = (int)(t->x / WC_ONE);
        int r = (int)(t->y / WC_ONE);

        if (i == eye) {
            continue;
        }

        if (!sight_point_visible(w, eye, t->x, t->y)) {
            continue;
        }

        if (c >= 0 && c < VIEW_COLUMNS && r >= 0 && r < VIEW_ROWS) {
            canvas[(r * VIEW_COLUMNS) + c] = 'o';
        }
    }

    /* The eye itself, last, so nothing paints over it. */
    column = (int)(body->x / WC_ONE);
    row = (int)(body->y / WC_ONE);
    if (column >= 0 && column < VIEW_COLUMNS && row >= 0 && row < VIEW_ROWS) {
        canvas[(row * VIEW_COLUMNS) + column] = '@';
    }

    /* Drawn top row last, so north is up rather than down. */
    for (row = VIEW_ROWS - 1; row >= 0; row--) {
        printf("    ");
        for (column = 0; column < VIEW_COLUMNS; column++) {
            putchar(canvas[(row * VIEW_COLUMNS) + column]);
        }
        printf("\n");
    }
}
/* }}} */

/* {{{ static void walk_and_look */
static void walk_and_look(struct world *w, struct fog *f, uint32_t eye)
{
    struct { wcoord x; wcoord y; const char *note; } stops[] = {
        { M(5),  M(5),  "In the west room. The pillar and the far wall are in the way." },
        { M(15), M(10), "By the corridor mouth. The corridor opens up." },
        { M(23), M(10), "Inside the corridor, short of the door." },
        { M(27), M(10), "Past the door. The east room appears." },
        { M(45), M(10), "By the torch. The west room is only a memory now." }
    };
    size_t s;

    for (s = 0; s < sizeof(stops) / sizeof(stops[0]); s++) {
        struct thing *body = world_thing(w, eye);

        body->x = stops[s].x;
        body->y = stops[s].y;

        fog_fold(f, w, eye);

        printf("\n    Step %d of %d -- %s\n\n",
               (int)s + 1, (int)(sizeof(stops) / sizeof(stops[0])), stops[s].note);

        draw(w, f, eye);

        printf("\n    remembered: %u of %u cells (%.0f%%)\n",
               fog_cells_seen(f),
               fog_cell_count(f),
               100.0 * (double)fog_cells_seen(f) / (double)fog_cell_count(f));
    }
}
/* }}} */

/* {{{ struct sweep_work */
struct sweep_work {
    const struct world *world;
    struct sight_fan   *fans;
    uint32_t            first_body;
};
/* }}} */

/* {{{ static void sweep_span */
static void sweep_span(void *context, uint32_t first, uint32_t last)
{
    struct sweep_work *work = context;
    uint32_t i;

    /*
     * No lock. Each worker writes only into its own fans, and nothing here reads
     * what another worker writes -- which is what makes sight the pass that goes
     * to the pool without any thought.
     */
    for (i = first; i < last; i++) {
        sight_compute(work->world, work->first_body + i, &work->fans[i]);
    }
}
/* }}} */

/* {{{ static void report_cost */
static void report_cost(struct world *w)
{
    const uint32_t viewers = 64;
    uint32_t first_body = world_thing_count(w);
    struct sight_fan *fans;
    struct sweep_work work;
    uint32_t i;
    double single_thread_seconds = 0.0;

    rule("What it costs");

    /*
     * Sixty-four bodies with eyes, scattered through the map. Far more than a
     * tabletop will have, so that the per-body number is measured rather than
     * lost in the noise of a handful.
     */
    for (i = 0; i < viewers; i++) {
        uint32_t index = world_add_thing(w);
        struct thing *t = world_thing(w, index);

        t->x = (wcoord)(((i * 7) % 48 + 1) * WC_ONE);
        t->y = (wcoord)(((i * 5) % 18 + 1) * WC_ONE);
        t->facing = (wangle)(i * 1024);
        t->sight_arc = 65535;
        t->sight_range = (uint32_t)M(60);
    }

    fans = calloc(viewers, sizeof(struct sight_fan));
    for (i = 0; i < viewers; i++) {
        sight_fan_init(&fans[i], sight_fan_capacity_for(w));
    }

    work.world = w;
    work.fans = fans;
    work.first_body = first_body;

    printf("    %u walls in the world, %u bodies with eyes, on a machine with\n",
           world_wall_count(w) - 1, viewers);
    printf("    %u cores.\n", pool_default_worker_count() + 1);
    printf("\n");
    printf("    %-9s %11s %11s %11s %9s\n",
           "threads", "wall (s)", "cpu (s)", "per body", "speedup");

    {
        uint32_t thread_counts[] = { 1, 2, 4, 8 };
        size_t k;

        for (k = 0; k < sizeof(thread_counts) / sizeof(thread_counts[0]); k++) {
            struct pool *p = pool_start(thread_counts[k]);
            clock_t cpu_start;
            double wall_start;
            double wall_seconds;
            double cpu_seconds;
            const int rounds = 20;
            int round;

            if (p == NULL) {
                continue;
            }

            cpu_start = clock();
            wall_start = wall_now();
            for (round = 0; round < rounds; round++) {
                pool_run(p, sweep_span, &work, viewers);
            }
            wall_seconds = wall_now() - wall_start;
            cpu_seconds = cpu_seconds_since(cpu_start);

            if (k == 0) {
                single_thread_seconds = wall_seconds;
            }

            printf("    %-9u %11.4f %11.4f %8.1f us %8.2fx\n",
                   thread_counts[k],
                   wall_seconds,
                   cpu_seconds,
                   wall_seconds * 1000000.0 / (double)(rounds * viewers),
                   single_thread_seconds / wall_seconds);

            pool_stop(p);
        }
    }

    printf("\n");
    printf("    Wall time is how long you waited; processor time is the sum across\n");
    printf("    every thread. The second column climbing while the first falls is\n");
    printf("    the coordination being paid for, and it is the shape a parallel\n");
    printf("    pass is supposed to have.\n");

    {
        double per_body = single_thread_seconds * 1000000.0 / (double)(20 * viewers);
        double per_tick_six = per_body * 6.0;

        printf("\n");
        printf("    A table of six costs about %.0f microseconds of sight per tick.\n",
               per_tick_six);
        printf("    At twenty ticks a second that is %.2f%% of one core.\n",
               per_tick_six * 20.0 / 10000.0);
        printf("\n");
        printf("    That number is what open question 3.2 -- how fast should the\n");
        printf("    world beat -- has been waiting for. It says the tick rate is\n");
        printf("    not constrained by sight at tabletop scale.\n");
    }

    {
        uint32_t total_boundaries = 0;
        for (i = 0; i < viewers; i++) {
            total_boundaries += fans[i].count;
        }
        printf("\n");
        printf("    A visibility polygon here has about %u boundaries.\n",
               total_boundaries / viewers);
        printf("    That is what phase 4 will have to put on a socket, per viewer,\n");
        printf("    per tick, and it is small.\n");
    }

    for (i = 0; i < viewers; i++) {
        sight_fan_release(&fans[i]);
    }
    free(fans);
}
/* }}} */

/* {{{ static void report_the_security_claim */
static void report_the_security_claim(struct world *w)
{
    uint32_t eye;
    uint32_t ambush;

    rule("And the part that is not about drawing");

    /*
     * The whole reason this geometry runs on the host's machine rather than in
     * the client, where it would be a great deal more convenient and completely
     * worthless.
     */
    eye = world_add_thing(w);
    {
        struct thing *t = world_thing(w, eye);
        t->x = M(5);
        t->y = M(5);
        t->facing = 0;
        t->sight_arc = 65535;
        t->sight_range = (uint32_t)M(100);
    }

    ambush = world_add_thing(w);
    {
        struct thing *t = world_thing(w, ambush);
        t->x = M(40);
        t->y = M(10);
        t->kind = 9;
    }

    printf("    A body waits in the east room, forty metres away, with nothing\n");
    printf("    between it and the watcher but two walls and a shut door.\n\n");

    printf("      watcher at (5, 5)  -- can it see the far room?   %s\n",
           sight_point_visible(w, eye, M(40), M(10)) ? "YES" : "no");

    world_thing(w, eye)->x = M(23);
    world_thing(w, eye)->y = M(10);
    printf("      watcher at (23, 10) -- in the corridor?           %s\n",
           sight_point_visible(w, eye, M(40), M(10)) ? "YES" : "no");

    world_thing(w, eye)->x = M(27);
    world_thing(w, eye)->y = M(10);
    printf("      watcher at (27, 10) -- past the door?             %s\n",
           sight_point_visible(w, eye, M(40), M(10)) ? "YES" : "no");

    printf("\n");
    printf("    In phase 4 that answer becomes the difference between a record\n");
    printf("    being written to a socket and never being written at all. Not\n");
    printf("    sent and hidden by the client -- never sent. A client that has\n");
    printf("    been tampered with learns nothing, because it was never told.\n");
}
/* }}} */

/* {{{ int main */
int main(void)
{
    struct world w;
    struct fog f;
    struct validation_failure failure;
    char message[256];
    uint32_t eye;

    printf("\n");
    printf("  ===========================================================\n");
    printf("   PHASE TWO -- The world can be seen\n");
    printf("  ===========================================================\n");
    printf("\n");
    printf("  Still no network and no clock. A world that does not move, and a\n");
    printf("  body inside it that can work out what it can see.\n");

    if (!fixture_make_two_rooms(&w)) {
        printf("\n  Could not build the fixture world.\n");
        return 1;
    }

    if (!world_validate(&w, &failure)) {
        printf("\n  The fixture does not validate: %s\n",
               validation_failure_describe(&failure, message, sizeof(message)));
        world_release(&w);
        return 1;
    }

    if (!fog_init(&f, &w, WC_ONE)) {
        printf("\n  Could not build the fog.\n");
        world_release(&w);
        return 1;
    }

    eye = world_add_thing(&w);
    {
        struct thing *t = world_thing(&w, eye);
        t->facing = 0;
        t->sight_arc = 65535;
        t->sight_range = (uint32_t)M(100);
        t->radius = (uint16_t)(WC_ONE / 2);
    }

    rule("Walking from one room to the other");

    printf("    @ is the body      . is what it can see now\n");
    printf("    : is what it remembers seeing     # is wall\n");
    printf("    o is something it can see        (blank) is never seen\n");

    walk_and_look(&w, &f, eye);

    printf("\n");
    printf("    The map fills in behind the body and never empties. Sight is\n");
    printf("    recomputed every time it is asked for; memory only ever grows.\n");
    printf("    Those are different things, stored differently, and the outbound\n");
    printf("    filter in phase 4 reads one for walls and the other for bodies --\n");
    printf("    which is why you keep the shape of a room you have left and have\n");
    printf("    no idea whether anybody is still standing in it.\n");

    report_the_security_claim(&w);
    report_cost(&w);

    printf("\n");
    printf("  Next: phase three, where the world starts moving and a turn can be\n");
    printf("  taken back.\n");
    printf("\n");

    fog_release(&f);
    world_release(&w);
    return 0;
}
/* }}} */
