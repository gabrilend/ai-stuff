/*
 * 081-demo-phase-8.c -- a written description becomes a place.
 *
 * Phase eight claims nothing needs to be hand-placed. Every phase before this
 * one used the same hand-written two-room fixture; this is where the project
 * stops needing one.
 *
 * The demo shows the CHAIN rather than the result, because the point of the
 * four-stage split is that each stage is separately answerable.
 *
 * Run through ./run-phase-demo 8.
 */

#include "078-generate.h"
#include "033-validate.h"
#include "035-worldfile.h"
#include "042-sight.h"
#include "044-fog.h"
#include "031-region.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define M(n) ((wcoord)((n) * WC_ONE))

#define DESCRIPTIONS "/mnt/mtwo/programming/ai-stuff/my-own-custom-vtt/input/descriptions"
#define SCRATCH      "/dev/shm/my-own-custom-vtt"

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

/* {{{ static int make */
static int make(struct world *w, const struct description *d, uint64_t seed,
                struct layout *l, const char **why)
{
    uint32_t things, walls, regions, vertices, lights, strings;

    generate_capacity_hint(d, &things, &walls, &regions,
                           &vertices, &lights, &strings);

    if (!world_init(w, things, walls, regions, vertices, lights, strings)) {
        *why = "no memory";
        return 0;
    }

    if (!generate(w, d, seed, NULL, l, why)) {
        return 0;
    }

    w->seed = seed;
    snprintf(w->origin, sizeof(w->origin), "%s", d->name);

    return 1;
}
/* }}} */

/* {{{ static void draw */
static void draw(const struct world *w, uint32_t eye, const struct fog *f)
{
    /* Sized from the world rather than fixed, because a dungeon is any size. */
    int columns = (int)(w->max_x / WC_ONE) + 1;
    int rows = (int)(w->max_y / WC_ONE) + 1;
    char *canvas;
    int column;
    int row;
    uint32_t i;

    if (columns > 110) columns = 110;
    if (rows > 44) rows = 44;

    canvas = malloc((size_t)(columns * rows));
    if (canvas == NULL) {
        return;
    }
    memset(canvas, ' ', (size_t)(columns * rows));

    for (row = 0; row < rows; row++) {
        for (column = 0; column < columns; column++) {
            wcoord x = (wcoord)(column * WC_ONE) + (WC_ONE / 2);
            wcoord y = (wcoord)(row * WC_ONE) + (WC_ONE / 2);

            if (eye != 0 && sight_point_visible(w, eye, x, y)) {
                canvas[(row * columns) + column] = '.';
            } else if (f != NULL && fog_remembers(f, x, y)) {
                canvas[(row * columns) + column] = ':';
            }
        }
    }

    for (i = 1; i < world_wall_count(w); i++) {
        const struct wall *wl = world_wall_const(w, i);
        wcoord length = fx_dist(wl->ax, wl->ay, wl->bx, wl->by);
        wcoord travelled;
        wangle direction = fx_angle(wl->bx - wl->ax, wl->by - wl->ay);

        for (travelled = 0; travelled <= length; travelled += WC_ONE / 3) {
            struct wvec step = fx_from_angle(direction, travelled);
            int c = (int)((wl->ax + step.x) / WC_ONE);
            int r = (int)((wl->ay + step.y) / WC_ONE);

            if (c >= 0 && c < columns && r >= 0 && r < rows) {
                canvas[(r * columns) + c] = '#';
            }
        }
    }

    for (i = 1; i < world_thing_count(w); i++) {
        const struct thing *t = world_thing_const(w, i);
        int c = (int)(t->x / WC_ONE);
        int r = (int)(t->y / WC_ONE);

        if (i == eye) continue;

        if (c >= 0 && c < columns && r >= 0 && r < rows) {
            canvas[(r * columns) + c] =
                ((t->flags & THING_EMITS_LIGHT) != 0) ? '*' : 'o';
        }
    }

    if (eye != 0) {
        const struct thing *t = world_thing_const(w, eye);
        int c = (int)(t->x / WC_ONE);
        int r = (int)(t->y / WC_ONE);

        if (c >= 0 && c < columns && r >= 0 && r < rows) {
            canvas[(r * columns) + c] = '@';
        }
    }

    for (row = rows - 1; row >= 0; row--) {
        printf("    ");
        for (column = 0; column < columns; column++) {
            putchar(canvas[(row * columns) + column]);
        }
        printf("\n");
    }

    free(canvas);
}
/* }}} */

/* {{{ static void report_the_chain */
static void report_the_chain(void)
{
    struct description d;
    struct fault_list faults;
    struct world w;
    struct layout l;
    const char *why = NULL;
    uint32_t i;

    rule("A description, and the four stages it goes through");

    if (!description_read_file(&d, DESCRIPTIONS "/the-old-inn", &faults)) {
        faults_report(&faults, "the-old-inn");
        return;
    }

    printf("    validated  \"%s\": %u rooms, %u to %u metres, %u loop%s\n",
           d.name, d.rooms, d.smallest, d.largest,
           d.loops, (d.loops == 1) ? "" : "s");
    printf("               requiring");
    for (i = 0; i < d.required_count; i++) {
        printf("%s %s", (i > 0) ? "," : "", d.required[i]);
    }
    printf("\n\n");

    if (!make(&w, &d, 4207, &l, &why)) {
        printf("    could not generate: %s\n", why);
        return;
    }

    printf("    laid out   a graph with no coordinates in it at all:\n\n");

    for (i = 0; i < l.node_count; i++) {
        uint32_t e;

        printf("                 room %u (%u metres)%s -> ",
               i + 1, l.nodes[i].wanted_size,
               (l.nodes[i].feature != 0) ? "*" : " ");

        for (e = 0; e < l.edge_count; e++) {
            if (l.edges[e].from == i) printf("%u ", l.edges[e].to + 1);
            if (l.edges[e].to == i)   printf("%u ", l.edges[e].from + 1);
        }
        printf("\n");
    }

    printf("\n               connected: %s, loops: %u\n",
           layout_is_connected(&l) ? "yes" : "NO", layout_loop_count(&l));
    printf("               (* is a room holding a required feature)\n\n");

    printf("    Both of those are questions about a GRAPH. Connectivity is a\n");
    printf("    walk; against a pile of wall segments it is a flood fill over\n");
    printf("    what, exactly. That is why the graph exists before the geometry.\n\n");

    printf("    realised   %u walls, %u regions, %u vertices\n",
           world_wall_count(&w) - 1, world_region_count(&w) - 1,
           world_vertex_count(&w) - 1);
    printf("    furnished  %u things, %u lights\n\n",
           world_thing_count(&w) - 1, world_light_count(&w) - 1);

    printf("    And it is what was described: ");
    printf("%s\n", generate_check(&w, &l, &d, &faults) ? "yes" : "NO");

    printf("\n");
    printf("    That last check is a DIFFERENT QUESTION from whether the world is\n");
    printf("    coherent. The validator would happily pass a tidy dungeon with\n");
    printf("    three rooms when somebody asked for six -- only this can tell a\n");
    printf("    generator from a random number visualiser.\n");

    world_release(&w);
}
/* }}} */

/* {{{ static void report_the_seed */
static void report_the_seed(void)
{
    struct description d;
    struct fault_list faults;
    struct world a;
    struct world b;
    struct layout la;
    struct layout lb;
    const char *why = NULL;

    rule("The same seed, twice");

    description_read_file(&d, DESCRIPTIONS "/the-old-inn", &faults);

    if (!make(&a, &d, 4207, &la, &why)) return;
    if (!make(&b, &d, 4207, &lb, &why)) { world_release(&a); return; }

    printf("    seed 4207, run once:  %016llx\n",
           (unsigned long long)world_hash(&a));
    printf("    seed 4207, run again: %016llx  %s\n",
           (unsigned long long)world_hash(&b),
           (world_hash(&a) == world_hash(&b)) ? "-- identical" : "-- THEY DIFFER");

    world_release(&b);

    if (make(&b, &d, 4208, &lb, &why)) {
        printf("    seed 4208:            %016llx  -- a different place\n",
               (unsigned long long)world_hash(&b));
        world_release(&b);
    }

    printf("\n");
    printf("    A description plus a seed is a few hundred bytes that name a\n");
    printf("    whole dungeon exactly. A GM can hand that to somebody, a test can\n");
    printf("    assert against it, and a bug report can include it.\n");

    world_release(&a);
}
/* }}} */

/* {{{ static void report_one_line_changed */
static void report_one_line_changed(void)
{
    struct description before;
    struct description after;
    struct fault_list faults;
    struct world wa;
    struct world wb;
    struct layout la;
    struct layout lb;
    const char *why = NULL;

    rule("One line changed");

    description_read(&before,
        "name = a small place\n"
        "rooms = 4\n"
        "smallest = 5\n"
        "largest = 9\n"
        "loops = 0\n", &faults);

    description_read(&after,
        "name = a small place\n"
        "rooms = 7\n"
        "smallest = 5\n"
        "largest = 9\n"
        "loops = 0\n", &faults);

    if (!make(&wa, &before, 11, &la, &why)) return;
    if (!make(&wb, &after, 11, &lb, &why)) { world_release(&wa); return; }

    printf("    %-14s %8s %8s %8s %8s\n",
           "", "rooms", "walls", "regions", "things");
    printf("    %-14s %8u %8u %8u %8u\n", "rooms = 4",
           la.node_count, world_wall_count(&wa) - 1,
           world_region_count(&wa) - 1, world_thing_count(&wa) - 1);
    printf("    %-14s %8u %8u %8u %8u\n", "rooms = 7",
           lb.node_count, world_wall_count(&wb) - 1,
           world_region_count(&wb) - 1, world_thing_count(&wb) - 1);

    printf("\n");
    printf("    That is the difference between a map you can edit and a map you\n");
    printf("    can only replace. Nothing was hand-placed, so nothing had to be\n");
    printf("    hand-moved.\n");

    world_release(&wa);
    world_release(&wb);
}
/* }}} */

/* {{{ static void report_a_refusal */
static void report_a_refusal(void)
{
    struct description d;
    struct fault_list faults;
    struct world w;
    struct layout l;
    const char *why = NULL;

    rule("Descriptions that are refused");

    printf("    A misspelled word, an impossible number, and two bad lines at once:\n\n");

    description_read(&d,
        "romes = 6\n"
        "smallest = plenty\n"
        "largest = 9999\n", &faults);

    faults_report(&faults, "that description");

    printf("    All of them at once, not the first. Stopping at the first turns\n");
    printf("    fixing a description into one guess per run -- and the nearest\n");
    printf("    legal word is offered only when it is actually close, because\n");
    printf("    suggesting \"rooms\" for \"banana\" sends somebody looking for a\n");
    printf("    relationship that is not there.\n\n");

    printf("    And a description that is sound but cannot be satisfied:\n\n");

    if (description_read(&d,
        "rooms = 3\n"
        "loops = 6\n", &faults)) {

        if (!make(&w, &d, 1, &l, &why)) {
            printf("      -> %s\n", why);
        } else {
            printf("      it was satisfied, which it should not have been\n");
            world_release(&w);
        }
    }

    printf("\n");
    printf("    Three rooms allow exactly one connection beyond the tree. Saying\n");
    printf("    so beats producing fewer loops and hoping nobody counts.\n");
}
/* }}} */

/* {{{ static void report_walking_into_it */
static void report_walking_into_it(void)
{
    struct description d;
    struct fault_list faults;
    struct world w;
    struct layout l;
    struct fog f;
    const char *why = NULL;
    uint32_t eye;
    uint32_t step;

    rule("And then walking into it");

    description_read_file(&d, DESCRIPTIONS "/the-old-inn", &faults);

    if (!make(&w, &d, 4207, &l, &why)) {
        printf("    could not generate: %s\n", why);
        return;
    }

    eye = world_add_thing(&w);
    {
        struct thing *t = world_thing(&w, eye);
        t->x = l.nodes[0].x + (l.nodes[0].size / 2);
        t->y = l.nodes[0].y + (l.nodes[0].size / 2);
        t->facing = 0;
        t->sight_arc = 65535;
        t->sight_range = (uint32_t)M(60);
        t->radius = (uint16_t)(WC_ONE / 2);
        t->region = region_deepest_containing(&w, t->x, t->y);
    }

    if (!fog_init(&f, &w, WC_ONE)) {
        world_release(&w);
        return;
    }

    printf("    @ is a body      . is what it can see      : is what it remembers\n");
    printf("    # is wall        o is a prop               * is a light\n\n");

    /*
     * A few stops, walking between the rooms the graph laid out. Bounded, so the
     * demo cannot run long.
     */
    for (step = 0; step < 3 && step < l.node_count; step++) {
        struct thing *t = world_thing(&w, eye);

        t->x = l.nodes[step].x + (l.nodes[step].size / 2);
        t->y = l.nodes[step].y + (l.nodes[step].size / 2);
        t->region = region_deepest_containing(&w, t->x, t->y);

        fog_fold(&f, &w, eye);
    }

    draw(&w, eye, &f);

    printf("\n    %u of %u cells remembered, after three stops.\n",
           fog_cells_seen(&f), fog_cell_count(&f));

    printf("\n");
    printf("    Every phase before this one used the same hand-written two-room\n");
    printf("    fixture. This is where the project stops needing one.\n");

    fog_release(&f);
    world_release(&w);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    printf("\n");
    printf("  ===========================================================\n");
    printf("   PHASE EIGHT -- Content generation\n");
    printf("  ===========================================================\n");
    printf("\n");
    printf("  No wall in this project is typed in by hand. Maps come out of a\n");
    printf("  generator, and the generator is the thing that gets maintained.\n");

    report_the_chain();
    report_the_seed();
    report_one_line_changed();
    report_a_refusal();
    report_walking_into_it();

    printf("\n");
    printf("  Next: phase nine, where the sprites get generated too -- and rated.\n");
    printf("\n");

    return 0;
}
/* }}} */
