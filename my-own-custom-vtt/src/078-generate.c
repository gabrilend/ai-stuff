/*
 * 078-generate.c -- the graph, the geometry, and the check that it is what was
 * asked for.
 *
 * Interface and reasoning are in 078-generate.h.
 *
 * Everything here draws from named streams rather than one generator, so that
 * adding a draw in the layout does not silently change what gets furnished --
 * which would make a written-down seed stop meaning anything the moment anybody
 * edited anything.
 */

#include "078-generate.h"
#include "073-rules.h"
#include "031-region.h"
#include "033-validate.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define M(n) ((wcoord)((n) * WC_ONE))

/* {{{ int layout_build */
int layout_build(struct layout *l, const struct description *d,
                 struct stream_registry *streams, const char **why)
{
    uint32_t shape = stream_named(streams, "dungeon-layout");
    uint32_t i;

    memset(l, 0, sizeof(struct layout));

    if (d->rooms > LAYOUT_MAX_NODES) {
        *why = "that is more rooms than this generator will lay out";
        return 0;
    }

    if (d->required_count > d->rooms) {
        /*
         * Named rather than approximated. Somebody who asked for four rooms and
         * six features has made a mistake, and quietly dropping two of the
         * features would produce a dungeon missing something they said they
         * wanted.
         */
        *why = "more required features than rooms to put them in";
        return 0;
    }

    /*
     * Sizes are chosen from the range the description gave. Randomness only
     * where the description does not care -- a generator that ignores its
     * description and produces noise is not a generator, it is a random number
     * visualiser.
     */
    for (i = 0; i < d->rooms; i++) {
        l->nodes[i].wanted_size =
            (uint32_t)stream_between(streams, shape,
                                     (int64_t)d->smallest, (int64_t)d->largest);
        l->nodes[i].feature = 0;
    }

    /*
     * Required features get rooms, one each, starting at the front. Deliberately
     * not scattered randomly: "this tavern has a cellar" is a promise, and a
     * promise kept in a predictable place is easier to check than one kept
     * somewhere a seed decided.
     */
    for (i = 0; i < d->required_count; i++) {
        l->nodes[i].feature = i + 1;
    }

    l->node_count = d->rooms;

    /*
     * A CHAIN, not an arbitrary tree.
     *
     * Connected by construction either way, but a chain has a property an
     * arbitrary tree does not: every edge joins rooms that will end up next to
     * each other, so every one of them becomes a straight corridor rather than a
     * passage that has to be routed around whatever is in the way.
     *
     * The layout stage is choosing a shape it knows the realise stage can build.
     * That is a constraint the two share, and it is written down here because it
     * is invisible from either file alone.
     */
    for (i = 1; i < l->node_count; i++) {
        l->edges[l->edge_count].from = i - 1;
        l->edges[l->edge_count].to = i;
        l->edge_count++;
    }

    /*
     * Then the loops the description asked for, on top of the tree.
     *
     * RETRIED UNTIL THEY ARE ALL PLACED, not attempted once each.
     *
     * An earlier version drew two rooms per loop and gave up on a collision --
     * so a description asking for one loop routinely got none, and the checker
     * below only capped the count rather than requiring it. The result was a
     * generator quietly ignoring its description, which is the exact failure
     * this phase exists to make impossible.
     *
     * The attempt bound is what stops an impossible request spinning: a complete
     * graph has n(n-1)/2 edges and a tree has n-1, so beyond that difference
     * there is genuinely nowhere left to put one.
     */
    {
        uint32_t placed = 0;
        uint32_t attempts = 0;
        uint32_t room_for = (l->node_count < 3)
                          ? 0
                          : ((l->node_count * (l->node_count - 1)) / 2)
                            - (l->node_count - 1);

        if (d->loops > room_for) {
            *why = "more loops than there are rooms to connect";
            return 0;
        }

        while (placed < d->loops &&
               l->edge_count < LAYOUT_MAX_EDGES &&
               attempts < 4096) {
            uint32_t a = (uint32_t)stream_below(streams, shape, l->node_count);
            uint32_t b = (uint32_t)stream_below(streams, shape, l->node_count);
            uint32_t existing;
            int already = 0;

            attempts++;

            if (a == b) {
                continue;
            }

            for (existing = 0; existing < l->edge_count; existing++) {
                if ((l->edges[existing].from == a && l->edges[existing].to == b) ||
                    (l->edges[existing].from == b && l->edges[existing].to == a)) {
                    already = 1;
                    break;
                }
            }

            if (already) {
                continue;
            }

            l->edges[l->edge_count].from = a;
            l->edges[l->edge_count].to = b;
            l->edge_count++;
            placed++;
        }

        if (placed < d->loops) {
            *why = "could not find room for every loop the description asked for";
            return 0;
        }
    }

    return 1;
}
/* }}} */

/* {{{ int layout_is_connected */
int layout_is_connected(const struct layout *l)
{
    uint8_t reached[LAYOUT_MAX_NODES];
    uint32_t frontier[LAYOUT_MAX_NODES];
    uint32_t frontier_count = 0;
    uint32_t i;

    /*
     * A walk. Against a graph this is ten lines; against a pile of wall segments
     * it is a flood fill over what, exactly -- which is the whole reason the
     * graph exists before the geometry does.
     */
    if (l->node_count == 0) {
        return 1;
    }

    memset(reached, 0, sizeof(reached));
    reached[0] = 1;
    frontier[frontier_count++] = 0;

    while (frontier_count > 0) {
        uint32_t here = frontier[--frontier_count];

        for (i = 0; i < l->edge_count; i++) {
            uint32_t other = LAYOUT_MAX_NODES;

            if (l->edges[i].from == here) {
                other = l->edges[i].to;
            } else if (l->edges[i].to == here) {
                other = l->edges[i].from;
            }

            if (other < l->node_count && !reached[other]) {
                reached[other] = 1;
                frontier[frontier_count++] = other;
            }
        }
    }

    for (i = 0; i < l->node_count; i++) {
        if (!reached[i]) {
            return 0;
        }
    }

    return 1;
}
/* }}} */

/* {{{ uint32_t layout_loop_count */
uint32_t layout_loop_count(const struct layout *l)
{
    /*
     * A tree over n nodes has n-1 edges. Anything beyond that is a loop, which
     * is a fact about graphs and would be an afternoon's work about geometry.
     */
    if (l->node_count == 0 || l->edge_count < l->node_count - 1) {
        return 0;
    }

    return l->edge_count - (l->node_count - 1);
}
/* }}} */

/* {{{ static uint32_t add_wall */
static uint32_t add_wall(struct world *w, wcoord x0, wcoord y0,
                         wcoord x1, wcoord y1)
{
    uint32_t index = world_add_wall(w);
    struct wall *wl;

    if (index == 0) {
        return 0;
    }

    wl = world_wall(w, index);
    wl->ax = x0; wl->ay = y0;
    wl->bx = x1; wl->by = y1;
    wl->flags = BLOCKS_SIGHT | BLOCKS_MOVEMENT;

    return index;
}
/* }}} */

/*
 * How wide a doorway is, and how far apart rooms sit.
 *
 * The gap is what makes a corridor walkable: a wall is a run of segments with a
 * hole in it, not one segment that is somehow permeable. That falls out of walls
 * being segments -- a picture-based map would have had to paint a door.
 */
#define DOORWAY_HALF_WIDTH  (WC_ONE * 3 / 2)
#define CORRIDOR_LENGTH     M(6)
#define LOOP_CHANNEL_GAP    M(6)

#define MAX_GAPS_PER_SIDE 6

/* {{{ struct side_gaps */
struct side_gaps {
    wcoord   from[MAX_GAPS_PER_SIDE];
    wcoord   to[MAX_GAPS_PER_SIDE];
    uint32_t count;
};
/* }}} */

/* {{{ static void note_gap */
static void note_gap(struct side_gaps *g, wcoord from, wcoord to)
{
    if (g->count >= MAX_GAPS_PER_SIDE) {
        return;
    }

    g->from[g->count] = from;
    g->to[g->count] = to;
    g->count++;
}
/* }}} */

/*
 * Emit one side of a room as a run of segments, skipping the gaps.
 *
 * `along` runs from `low` to `high`; `fixed` is the other coordinate. `vertical`
 * says which is which. The gaps are sorted first, because two doorways on one
 * side in the wrong order would emit a segment running backwards -- which is a
 * wall of negative length, and the validator refuses those for good reason.
 */
/* {{{ static void emit_side */
static void emit_side(struct world *w, struct side_gaps *g,
                      wcoord fixed, wcoord low, wcoord high, int vertical)
{
    wcoord at = low;
    uint32_t i;

    if (g->count > 1) {
        /* Sorted in step, so a from always keeps its to. */
        for (i = 0; i + 1 < g->count; i++) {
            uint32_t j;
            for (j = 0; j + 1 < g->count - i; j++) {
                if (g->from[j] > g->from[j + 1]) {
                    wcoord swap = g->from[j];
                    g->from[j] = g->from[j + 1];
                    g->from[j + 1] = swap;

                    swap = g->to[j];
                    g->to[j] = g->to[j + 1];
                    g->to[j + 1] = swap;
                }
            }
        }
    }

    for (i = 0; i < g->count; i++) {
        if (g->from[i] > at) {
            if (vertical) {
                add_wall(w, fixed, at, fixed, g->from[i]);
            } else {
                add_wall(w, at, fixed, g->from[i], fixed);
            }
        }

        if (g->to[i] > at) {
            at = g->to[i];
        }
    }

    if (high > at) {
        if (vertical) {
            add_wall(w, fixed, at, fixed, high);
        } else {
            add_wall(w, at, fixed, high, fixed);
        }
    }
}
/* }}} */

/* {{{ int realise */
int realise(struct world *w, struct layout *l, const struct description *d,
            struct stream_registry *streams, const char **why)
{
    struct side_gaps left[LAYOUT_MAX_NODES];
    struct side_gaps right[LAYOUT_MAX_NODES];
    struct side_gaps top[LAYOUT_MAX_NODES];
    uint32_t i;
    wcoord cursor_x = M(4);
    wcoord floor_y = M(4);
    wcoord tallest = 0;
    wcoord channel_y;

    (void)streams;

    memset(left, 0, sizeof(left));
    memset(right, 0, sizeof(right));
    memset(top, 0, sizeof(top));

    /*
     * ONE ROW, left to right, deterministically.
     *
     * Not a physical relaxation -- "push apart until it settles" is a different
     * number of steps on a different machine, and the whole point of a seed is
     * gone. A row is duller and reproducible, and reproducible is the
     * requirement.
     *
     * It is also what makes every chain edge a straight corridor, which is the
     * constraint the layout stage was built to respect.
     */
    for (i = 0; i < l->node_count; i++) {
        wcoord size = (wcoord)(l->nodes[i].wanted_size * WC_ONE);

        l->nodes[i].x = cursor_x;
        l->nodes[i].y = floor_y;
        l->nodes[i].size = size;

        cursor_x += size + CORRIDOR_LENGTH;

        if (size > tallest) {
            tallest = size;
        }
    }

    channel_y = floor_y + tallest + LOOP_CHANNEL_GAP;

    /*
     * Now the doorways. Each edge cuts a hole in two walls and adds a passage
     * between them -- the hole first, so that emit_side below knows where not to
     * put stone.
     */
    for (i = 0; i < l->edge_count; i++) {
        uint32_t a = l->edges[i].from;
        uint32_t b = l->edges[i].to;
        uint32_t lower = (a < b) ? a : b;
        uint32_t higher = (a < b) ? b : a;

        if (higher == lower + 1) {
            /* Neighbours in the row: a straight corridor between them. */
            wcoord middle = l->nodes[lower].y +
                            ((l->nodes[lower].size < l->nodes[higher].size)
                                 ? l->nodes[lower].size / 2
                                 : l->nodes[higher].size / 2);

            note_gap(&right[lower], middle - DOORWAY_HALF_WIDTH,
                     middle + DOORWAY_HALF_WIDTH);
            note_gap(&left[higher], middle - DOORWAY_HALF_WIDTH,
                     middle + DOORWAY_HALF_WIDTH);

            {
                wcoord x0 = l->nodes[lower].x + l->nodes[lower].size;
                wcoord x1 = l->nodes[higher].x;

                add_wall(w, x0, middle - DOORWAY_HALF_WIDTH,
                            x1, middle - DOORWAY_HALF_WIDTH);
                add_wall(w, x0, middle + DOORWAY_HALF_WIDTH,
                            x1, middle + DOORWAY_HALF_WIDTH);
            }
        } else {
            /*
             * A loop, joining rooms that are not neighbours. Routed up over the
             * row and back down -- an L on each end, meeting in a channel above
             * everything.
             *
             * Going over rather than between is what keeps a loop from having to
             * be threaded past whatever rooms lie in the way.
             */
            wcoord ax = l->nodes[lower].x + (l->nodes[lower].size / 2);
            wcoord bx = l->nodes[higher].x + (l->nodes[higher].size / 2);
            wcoord a_top = l->nodes[lower].y + l->nodes[lower].size;
            wcoord b_top = l->nodes[higher].y + l->nodes[higher].size;

            note_gap(&top[lower], ax - DOORWAY_HALF_WIDTH,
                     ax + DOORWAY_HALF_WIDTH);
            note_gap(&top[higher], bx - DOORWAY_HALF_WIDTH,
                     bx + DOORWAY_HALF_WIDTH);

            /* Up from each room. */
            add_wall(w, ax - DOORWAY_HALF_WIDTH, a_top,
                        ax - DOORWAY_HALF_WIDTH, channel_y);
            add_wall(w, ax + DOORWAY_HALF_WIDTH, a_top,
                        ax + DOORWAY_HALF_WIDTH, channel_y - DOORWAY_HALF_WIDTH * 2);

            add_wall(w, bx - DOORWAY_HALF_WIDTH, b_top,
                        bx - DOORWAY_HALF_WIDTH, channel_y - DOORWAY_HALF_WIDTH * 2);
            add_wall(w, bx + DOORWAY_HALF_WIDTH, b_top,
                        bx + DOORWAY_HALF_WIDTH, channel_y);

            /* And across the top. */
            add_wall(w, ax - DOORWAY_HALF_WIDTH, channel_y,
                        bx + DOORWAY_HALF_WIDTH, channel_y);
            add_wall(w, ax + DOORWAY_HALF_WIDTH,
                        channel_y - DOORWAY_HALF_WIDTH * 2,
                        bx - DOORWAY_HALF_WIDTH,
                        channel_y - DOORWAY_HALF_WIDTH * 2);
        }
    }

    /* Each room's outline, with the doorways left out, and its region. */
    for (i = 0; i < l->node_count; i++) {
        wcoord x0 = l->nodes[i].x;
        wcoord y0 = l->nodes[i].y;
        wcoord x1 = x0 + l->nodes[i].size;
        wcoord y1 = y0 + l->nodes[i].size;
        struct side_gaps none;
        uint32_t first_vertex;
        uint32_t region;
        char label[64];

        memset(&none, 0, sizeof(none));

        emit_side(w, &none,     y0, x0, x1, 0);   /* south */
        emit_side(w, &top[i],   y1, x0, x1, 0);   /* north */
        emit_side(w, &left[i],  x0, y0, y1, 1);   /* west */
        emit_side(w, &right[i], x1, y0, y1, 1);   /* east */

        /* Counter-clockwise, which is what the validator insists on. */
        first_vertex = world_add_vertex(w, x0, y0);
        world_add_vertex(w, x1, y0);
        world_add_vertex(w, x1, y1);
        world_add_vertex(w, x0, y1);

        region = world_add_region(w);
        if (region == 0) {
            *why = "ran out of room for regions";
            return 0;
        }

        if (l->nodes[i].feature != 0) {
            snprintf(label, sizeof(label), "%s",
                     d->required[l->nodes[i].feature - 1]);
        } else {
            snprintf(label, sizeof(label), "room %u", i + 1);
        }

        world_region(w, region)->first_vertex = first_vertex;
        world_region(w, region)->vertex_count = 4;
        world_region(w, region)->parent = 0;
        world_region(w, region)->name_offset =
            string_pool_add(&w->strings, label, (uint32_t)strlen(label));

        l->nodes[i].region = region;
    }

    w->min_x = 0;
    w->min_y = 0;
    w->max_x = cursor_x + M(4);
    w->max_y = channel_y + M(4);

    return 1;
}
/* }}} */

/* {{{ int furnish */
int furnish(struct world *w, struct layout *l, const struct description *d,
            struct stream_registry *streams, void *ruleset, const char **why)
{
    uint32_t dressing = stream_named(streams, "dungeon-furnishing");
    uint32_t lit = 0;
    uint32_t i;

    (void)ruleset;

    for (i = 0; i < l->node_count && lit < d->lights; i++) {
        uint32_t torch;
        uint32_t light;
        wcoord x = l->nodes[i].x + (l->nodes[i].size / 2);
        wcoord y = l->nodes[i].y + (l->nodes[i].size / 2);

        torch = world_add_thing(w);
        if (torch == 0) {
            *why = "ran out of room for things";
            return 0;
        }

        {
            struct thing *t = world_thing(w, torch);
            t->x = x;
            t->y = y;
            t->kind = 3;
            t->radius = (uint16_t)(WC_ONE / 4);
            t->flags = THING_EMITS_LIGHT;
            t->region = region_deepest_containing(w, x, y);
        }

        light = world_add_light(w);
        if (light == 0) {
            *why = "ran out of room for lights";
            return 0;
        }

        {
            struct light *lt = world_light(w, light);
            lt->thing = torch;
            lt->radius = (uint32_t)(l->nodes[i].size);
            lt->dim_radius = (uint32_t)(l->nodes[i].size / 2);
            lt->colour = 0xFFCC8844u;
            lt->arc = 65535;
        }

        lit++;
    }

    /*
     * A scattering of props, placed away from the walls so nothing is born
     * inside stone. A ruleset with a `furnish` hook would say what these are;
     * without one they are anonymous kinds, which is an empty but VALID world
     * rather than a failure.
     */
    for (i = 0; i < l->node_count; i++) {
        uint32_t how_many = (uint32_t)stream_below(streams, dressing, 3);
        uint32_t n;

        for (n = 0; n < how_many; n++) {
            uint32_t prop = world_add_thing(w);
            wcoord inset = WC_ONE + (wcoord)stream_below(streams, dressing,
                                     (uint64_t)(l->nodes[i].size - 2 * WC_ONE));

            if (prop == 0) {
                break;   /* Out of room is not fatal for decoration. */
            }

            {
                struct thing *t = world_thing(w, prop);
                t->x = l->nodes[i].x + inset;
                t->y = l->nodes[i].y + (l->nodes[i].size / 2);
                t->kind = 2;
                t->radius = (uint16_t)(WC_ONE / 8);
                t->region = region_deepest_containing(w, t->x, t->y);
            }
        }
    }

    return 1;
}
/* }}} */

/* {{{ void generate_capacity_hint */
void generate_capacity_hint(const struct description *d,
                            uint32_t *things, uint32_t *walls,
                            uint32_t *regions, uint32_t *vertices,
                            uint32_t *lights, uint32_t *strings)
{
    /*
     * Generous. Running out part-way through produces a half-built world, and
     * the memory saved by being tight is a few kilobytes.
     */
    *things   = (d->rooms * 6) + 32;
    *walls    = (d->rooms * 8) + 32;
    *regions  = d->rooms + 8;
    *vertices = (d->rooms * 6) + 32;
    *lights   = d->rooms + 8;
    *strings  = (d->rooms * 40) + 512;
}
/* }}} */

/* {{{ int generate */
int generate(struct world *w, const struct description *d, uint64_t seed,
             void *ruleset, struct layout *layout_out, const char **why)
{
    struct stream_registry streams;
    struct layout local;
    struct layout *l = (layout_out != NULL) ? layout_out : &local;

    streams_init(&streams, seed);

    if (!layout_build(l, d, &streams, why)) {
        return 0;
    }

    /*
     * Checked as a graph, before it has coordinates. Connectivity against a
     * graph is a walk; against geometry it is a question nobody can phrase.
     */
    if (!layout_is_connected(l)) {
        *why = "the layout came out disconnected, which is a bug in the generator";
        return 0;
    }

    if (!realise(w, l, d, &streams, why)) {
        return 0;
    }

    if (!furnish(w, l, d, &streams, ruleset, why)) {
        return 0;
    }

    return 1;
}
/* }}} */

/* {{{ static void add_generator_fault */
static void add_generator_fault(struct fault_list *faults, const char *word,
                                const char *found, const char *expected)
{
    struct fault *f;

    if (faults->count >= DESCRIPTION_MAX_FAULTS) {
        faults->overflowed = 1;
        return;
    }

    f = &faults->faults[faults->count];
    faults->count++;

    f->line = 0;
    snprintf(f->word, sizeof(f->word), "%s", word);
    snprintf(f->found, sizeof(f->found), "%s", found);
    f->expected = expected;
    f->nearest = NULL;
}
/* }}} */

/*
 * Can you actually WALK from every room to every other one?
 *
 * A different question from whether the graph is connected, and the difference
 * is not academic: an early version of this generator produced a perfectly
 * connected graph and then emitted four solid walls per room, so the layout
 * claimed passages that the geometry did not have. Nothing caught it. The demo
 * drew a row of sealed boxes and that is how it was found.
 *
 * So this asks the geometry rather than the graph: paint every wall onto a
 * coarse grid, flood fill from the first room, and see whether the others are
 * reached.
 *
 * A metre per cell, because doorways are three metres wide and anything coarser
 * would seal them by rounding.
 */
#define REACH_MAX_CELLS 262144

/* {{{ static int every_room_is_reachable */
static int every_room_is_reachable(const struct world *w, const struct layout *l)
{
    uint32_t columns = (uint32_t)(w->max_x / WC_ONE) + 2;
    uint32_t rows = (uint32_t)(w->max_y / WC_ONE) + 2;
    uint8_t *blocked;
    uint8_t *reached;
    uint32_t *frontier;
    uint32_t frontier_count = 0;
    uint32_t i;
    int all_reached = 1;

    if (l->node_count == 0) {
        return 1;
    }

    if ((uint64_t)columns * rows > REACH_MAX_CELLS) {
        /*
         * Larger than this check will look at. Reported as unreachable rather
         * than as passing -- a check that quietly gives up on big inputs is a
         * check that stops working exactly when it matters.
         */
        return 0;
    }

    blocked = calloc((size_t)columns * rows, 1);
    reached = calloc((size_t)columns * rows, 1);
    frontier = calloc((size_t)columns * rows, sizeof(uint32_t));

    if (blocked == NULL || reached == NULL || frontier == NULL) {
        free(blocked); free(reached); free(frontier);
        return 0;
    }

    /* Paint the walls. */
    for (i = 1; i < world_wall_count(w); i++) {
        const struct wall *wl = world_wall_const(w, i);
        wcoord length;
        wcoord travelled;
        wangle direction;

        if (!wall_blocks_movement(wl)) {
            continue;
        }

        length = fx_dist(wl->ax, wl->ay, wl->bx, wl->by);
        direction = fx_angle(wl->bx - wl->ax, wl->by - wl->ay);

        for (travelled = 0; travelled <= length; travelled += WC_ONE / 3) {
            struct wvec step = fx_from_angle(direction, travelled);
            int32_t c = (int32_t)((wl->ax + step.x) / WC_ONE);
            int32_t r = (int32_t)((wl->ay + step.y) / WC_ONE);

            if (c >= 0 && (uint32_t)c < columns && r >= 0 && (uint32_t)r < rows) {
                blocked[((uint32_t)r * columns) + (uint32_t)c] = 1;
            }
        }
    }

    /* Flood from the middle of the first room. */
    {
        uint32_t c = (uint32_t)((l->nodes[0].x + l->nodes[0].size / 2) / WC_ONE);
        uint32_t r = (uint32_t)((l->nodes[0].y + l->nodes[0].size / 2) / WC_ONE);
        uint32_t at = (r * columns) + c;

        if (c >= columns || r >= rows) {
            free(blocked); free(reached); free(frontier);
            return 0;
        }

        reached[at] = 1;
        frontier[frontier_count++] = at;
    }

    while (frontier_count > 0) {
        uint32_t at = frontier[--frontier_count];
        uint32_t c = at % columns;
        uint32_t r = at / columns;
        int step;

        /*
         * Four directions, not eight. A diagonal step can slip between two walls
         * that meet at a corner, which would report a sealed room as reachable --
         * the exact false pass this check exists to prevent.
         */
        for (step = 0; step < 4; step++) {
            int32_t nc = (int32_t)c + ((step == 0) ? 1 : (step == 1) ? -1 : 0);
            int32_t nr = (int32_t)r + ((step == 2) ? 1 : (step == 3) ? -1 : 0);
            uint32_t next;

            if (nc < 0 || (uint32_t)nc >= columns || nr < 0 || (uint32_t)nr >= rows) {
                continue;
            }

            next = ((uint32_t)nr * columns) + (uint32_t)nc;

            if (blocked[next] || reached[next]) {
                continue;
            }

            reached[next] = 1;
            frontier[frontier_count++] = next;
        }
    }

    for (i = 1; i < l->node_count; i++) {
        uint32_t c = (uint32_t)((l->nodes[i].x + l->nodes[i].size / 2) / WC_ONE);
        uint32_t r = (uint32_t)((l->nodes[i].y + l->nodes[i].size / 2) / WC_ONE);

        if (c >= columns || r >= rows || !reached[(r * columns) + c]) {
            all_reached = 0;
            break;
        }
    }

    free(blocked);
    free(reached);
    free(frontier);

    return all_reached;
}
/* }}} */

/* {{{ int generate_check */
int generate_check(const struct world *w, const struct layout *l,
                   const struct description *d, struct fault_list *faults)
{
    char number[64];
    uint32_t i;

    memset(faults, 0, sizeof(struct fault_list));

    /*
     * A DIFFERENT QUESTION from world_validate. That one asks whether a world is
     * coherent, and would happily pass a dungeon with three rooms when somebody
     * asked for eight. This asks whether it is the world that was described.
     *
     * Only this can tell a generator from a random number visualiser.
     */

    if (l->node_count != d->rooms) {
        snprintf(number, sizeof(number), "%u", l->node_count);
        add_generator_fault(faults, "rooms", number,
                            "as many rooms as the description asked for");
    }

    if (!layout_is_connected(l)) {
        add_generator_fault(faults, "the graph", "disconnected",
                            "every room joined to every other in the layout");
    }

    /*
     * And the geometry, which is a DIFFERENT QUESTION. A connected graph whose
     * rooms were emitted as sealed boxes passes the check above and fails this
     * one -- which is exactly what happened, and how the missing doorways were
     * found.
     */
    if (!every_room_is_reachable(w, l)) {
        add_generator_fault(faults, "the geometry", "sealed",
                            "a doorway wherever the layout claims a passage");
    }

    /*
     * EXACTLY as many loops as were asked for, not "no more than".
     *
     * The first version of this check only capped the count, and a generator
     * that produced none when one was requested sailed through it. A check that
     * can only catch too many is half a check, and the half it is missing is the
     * one that catches a generator ignoring its description.
     */
    if (layout_loop_count(l) != d->loops) {
        snprintf(number, sizeof(number), "%u", layout_loop_count(l));
        add_generator_fault(faults, "loops", number,
                            "exactly as many loops as the description asked for");
    }

    for (i = 0; i < l->node_count; i++) {
        uint32_t across = (uint32_t)(l->nodes[i].size / WC_ONE);

        if (across < d->smallest || across > d->largest) {
            snprintf(number, sizeof(number), "%u metres", across);
            add_generator_fault(faults, "a room's size", number,
                                "a size inside the range the description gave");
            break;
        }
    }

    /* Every required feature has a room, and the room is named for it. */
    for (i = 0; i < d->required_count; i++) {
        uint32_t node;
        int found = 0;

        for (node = 0; node < l->node_count; node++) {
            if (l->nodes[node].feature == i + 1) {
                found = 1;
                break;
            }
        }

        if (!found) {
            add_generator_fault(faults, d->required[i], "missing",
                                "a room for every required feature");
        }
    }

    /* Rooms must not sit on top of each other. */
    for (i = 0; i < l->node_count; i++) {
        uint32_t other;

        for (other = i + 1; other < l->node_count; other++) {
            int apart_in_x =
                (l->nodes[i].x + l->nodes[i].size <= l->nodes[other].x) ||
                (l->nodes[other].x + l->nodes[other].size <= l->nodes[i].x);
            int apart_in_y =
                (l->nodes[i].y + l->nodes[i].size <= l->nodes[other].y) ||
                (l->nodes[other].y + l->nodes[other].size <= l->nodes[i].y);

            if (!apart_in_x && !apart_in_y) {
                add_generator_fault(faults, "room placement", "overlapping",
                                    "rooms that do not sit on top of each other");
                i = l->node_count;   /* One report is enough. */
                break;
            }
        }
    }

    if (world_region_count(w) < l->node_count + 1) {
        add_generator_fault(faults, "regions", "too few",
                            "one region per room");
    }

    return faults->count == 0 && !faults->overflowed;
}
/* }}} */
