/*
 * 059-outbound.c -- four gates, and one door out.
 *
 * Interface and reasoning are in 059-outbound.h.
 *
 * EVERY CALLER OF write_thing IS IN THIS FILE. That is the audit: if this
 * function is only reachable from here, and every path here runs the gates, then
 * the one rule holds. Adding a caller anywhere else breaks the argument, and the
 * companion file lists them so the check is a glance rather than a search.
 */

#include "059-outbound.h"
#include "056-protocol.h"
#include "031-region.h"
#include "070-scope.h"

#include <string.h>

/* ------------------------------------------------------------------------- *
 * The gates
 * ------------------------------------------------------------------------- */

/* {{{ void viewpoint_gather */
void viewpoint_gather(struct viewpoint *from, const struct world *w, uint32_t viewer)
{
    uint32_t scope;

    memset(from, 0, sizeof(struct viewpoint));
    from->viewer = viewer;

    if (viewer == 0) {
        return;
    }

    from->sees_all = (uint8_t)viewer_has_flag(w, viewer, SCOPE_SEES_ALL);

    /*
     * SEES_REGION is a design question wearing a performance costume. Computing
     * one region's interior once beats computing thirty overlapping wedges and
     * unioning them -- but whether the tavern's commander SHOULD be blind to the
     * corner their crockery cannot see is about what it feels like to play a
     * building, and is not settled.
     */
    for (scope = 1; scope < world_scope_count(w); scope++) {
        const struct scope *s = world_scope_const(w, scope);

        if (s->viewer == viewer && (s->flags & SCOPE_SEES_REGION) != 0) {
            from->sees_region = s->region;
            break;
        }
    }

    from->eyes_in_total = scope_eyes_of_viewer(w, viewer, from->bodies,
                                               VIEWPOINT_MAX_EYES);

    from->body_count = (from->eyes_in_total < VIEWPOINT_MAX_EYES)
                     ? from->eyes_in_total
                     : VIEWPOINT_MAX_EYES;
}
/* }}} */

/* {{{ static int gate_scope */
static int gate_scope(const struct session *s, uint32_t viewer_index, uint32_t thing)
{
    /*
     * GATE 1. Is this thing inside a scope this viewer holds? If so it passes
     * everything below -- YOU ALWAYS KNOW ABOUT WHAT YOU COMMAND, whether or not
     * you can currently see it.
     *
     * This was a stub returning 0 until phase 6, deliberately: "admits nothing"
     * is the direction that cannot leak, so the geometry below decided
     * everything. Now it is real, and it is the reason a commander does not lose
     * track of a goblin that walks behind a pillar.
     */
    return scope_of_viewer_containing(s->world, viewer_index, thing) != 0;
}
/* }}} */

/* {{{ static int gate_hidden */
static int gate_hidden(const struct session *s, uint32_t viewer_index, uint32_t thing)
{
    const struct thing *t = world_thing_const(s->world, thing);

    /*
     * GATE 2. THING_HIDDEN overrides the geometry completely. The GM's ambush
     * standing in plain view of a corridor nobody has walked down is visible to
     * the sweep and must not be sent.
     *
     * MAY_SEE_HIDDEN lifts it -- but only for somebody who holds a scope with the
     * flag, which currently means whoever was given it deliberately. Whether one
     * GM's hidden things should be hidden from another GM is open question 6.5,
     * and the answer this builds is "no, a flag is a flag" rather than a
     * per-GM secret.
     */
    if (!thing_is_hidden(t)) {
        return 1;
    }

    return viewer_has_flag(s->world, viewer_index, SCOPE_MAY_SEE_HIDDEN);
}
/* }}} */

/* {{{ static int gate_sight */
static int gate_sight(const struct session *s,
                      const struct viewpoint *from,
                      uint32_t thing)
{
    const struct thing *t = world_thing_const(s->world, thing);
    uint32_t i;

    /* GATE 3. A GM's scope skips the geometry rather than running it and winning. */
    if (from->sees_all) {
        return 1;
    }

    /*
     * A scope that sees its whole region sees everything standing in it, without
     * a sweep. What the tavern's commander plausibly wants: they ARE the tavern,
     * and a tavern knows where its own crockery is.
     */
    if (from->sees_region != 0 &&
        region_is_within(s->world, t->region, from->sees_region)) {
        return 1;
    }

    /*
     * Otherwise, the union: inside any of this viewer's eyes' wedges. A loop with
     * early exit, which is why the fans were never merged -- merging would have
     * bought a harder problem to answer the same question.
     *
     * Bodies need sight, not memory. You keep the shape of a room you have left
     * and have no idea whether anybody is still standing in it.
     */
    for (i = 0; i < from->body_count; i++) {
        if (sight_point_visible(s->world, from->bodies[i], t->x, t->y)) {
            return 1;
        }
    }

    return 0;
}
/* }}} */

/* {{{ int outbound_may_send_thing */
int outbound_may_send_thing(const struct session *s,
                            const struct viewer_set *set,
                            uint32_t viewer_index,
                            const struct viewpoint *from,
                            uint32_t thing)
{
    (void)set;

    /* Nothing is never sent. It is not a thing; it is the absence of one. */
    if (thing == 0 || thing >= world_thing_count(s->world)) {
        return 0;
    }

    /* You always know about what you command. */
    if (gate_scope(s, viewer_index, thing)) {
        return 1;
    }

    /* Hidden beats geometry, in that order, always. */
    if (!gate_hidden(s, viewer_index, thing)) {
        return 0;
    }

    return gate_sight(s, from, thing);
}
/* }}} */

/* {{{ int outbound_may_send_wall */
int outbound_may_send_wall(const struct session *s,
                           const struct viewer_set *set,
                           uint32_t viewer_index,
                           uint32_t wall)
{
    const struct viewer *v = viewer_at_const(set, viewer_index);
    const struct wall *wl;
    wcoord midpoint_x;
    wcoord midpoint_y;

    if (wall == 0 || wall >= world_wall_count(s->world)) {
        return 0;
    }

    wl = world_wall_const(s->world, wall);

    /*
     * GATE 4. Walls need only memory. Terrain is remembered and bodies are not,
     * which is why a viewer keeps the floor plan of a corridor they walked an
     * hour ago and learns nothing about who is in it now.
     *
     * A wall is a segment and memory is per cell, so the question "is this wall
     * remembered" has to be reduced to a point. The midpoint is used, which is a
     * simplification: a very long wall with only one end explored is sent whole
     * or not at all.
     *
     * That is acceptable because it errs toward sending LESS in the common case
     * -- a wall whose middle is unexplored stays unsent -- and because walls in a
     * generated dungeon are short. If walls ever get long, this becomes a wall
     * that pops into existence, which is a visible symptom rather than a silent
     * leak.
     */
    midpoint_x = (wcoord)(((int64_t)wl->ax + (int64_t)wl->bx) / 2);
    midpoint_y = (wcoord)(((int64_t)wl->ay + (int64_t)wl->by) / 2);

    return fog_remembers(&v->fog, midpoint_x, midpoint_y);
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * The one door out
 * ------------------------------------------------------------------------- */

/* {{{ static int write_thing */
static int write_thing(struct viewer *v, const struct world *w, uint32_t index)
{
    const struct thing *t = world_thing_const(w, index);
    struct instruction out;

    /*
     * THE ONLY FUNCTION IN THE SERVER THAT PUTS A THING ON A SOCKET.
     *
     * It is static, so nothing outside this file can call it at all, and every
     * caller inside this file has already been through the gates.
     *
     * PASSING A GATE IS NOT BEING SENT WHOLE. A goblin a player can see goes out
     * as a position, a facing, a radius, and a kind. Its `sheet` -- the door into
     * the ruleset's numbers for it -- does not, because seeing a goblin does not
     * entitle you to its hit points. Its `scope` does not either, because who
     * commands a body is not something looking at it tells you.
     */
    instruction_begin(&out, OP_THING);
    instruction_set(&out, 0, index);
    instruction_set(&out, 1, (uint32_t)t->x);
    instruction_set(&out, 2, (uint32_t)t->y);
    instruction_set(&out, 3, t->facing);
    instruction_set(&out, 4, t->radius);
    instruction_set(&out, 5, t->kind);

    if (!instruction_encode(&out, &v->outbound)) {
        return 0;
    }

    v->things_sent++;

    return 1;
}
/* }}} */

/* {{{ static int write_wall */
static int write_wall(struct viewer *v, const struct world *w, uint32_t index)
{
    const struct wall *wl = world_wall_const(w, index);
    struct instruction out;

    instruction_begin(&out, OP_WALL);
    instruction_set(&out, 0, index);
    instruction_set(&out, 1, (uint32_t)wl->ax);
    instruction_set(&out, 2, (uint32_t)wl->ay);
    instruction_set(&out, 3, (uint32_t)wl->bx);
    instruction_set(&out, 4, (uint32_t)wl->by);
    instruction_set(&out, 5, wl->flags);

    if (!instruction_encode(&out, &v->outbound)) {
        return 0;
    }

    v->walls_sent++;

    return 1;
}
/* }}} */

/* {{{ uint32_t outbound_build */
uint32_t outbound_build(struct session *s,
                        struct viewer_set *set,
                        uint32_t viewer_index,
                        const struct viewpoint *from)
{
    struct viewer *v = viewer_at(set, viewer_index);
    uint32_t written = 0;
    uint32_t i;

    if (viewer_index == 0 || v->state == VIEWER_EMPTY) {
        return 0;
    }

    /*
     * The whole of what this viewer should have, not a difference from something
     * they might have missed. A difference-based protocol needs both ends to
     * agree about what was received, and a rollback breaks that agreement in a
     * way neither end can detect.
     */
    buffer_clear(&v->outbound);

    {
        struct instruction tick;
        instruction_begin(&tick, OP_TICK);
        instruction_set(&tick, 0, (uint32_t)(s->sim.tick & 0xFFFFFFFFu));
        instruction_set(&tick, 1, (uint32_t)(s->sim.tick >> 32));
        if (instruction_encode(&tick, &v->outbound)) {
            written++;
        }
    }

    /* Walls, from memory. */
    for (i = 1; i < world_wall_count(s->world); i++) {
        if (!outbound_may_send_wall(s, set, viewer_index, i)) {
            continue;
        }

        if (write_wall(v, s->world, i)) {
            written++;
        }
    }

    /* Bodies, from sight. */
    for (i = 1; i < world_thing_count(s->world); i++) {
        if (!outbound_may_send_thing(s, set, viewer_index, from, i)) {
            continue;
        }

        if (write_thing(v, s->world, i)) {
            written++;
        }
    }

    /*
     * The visibility polygon, so the view can draw a clean edge between
     * torchlight and dark. It was computed to decide what may be sent; sending
     * it costs nothing extra and is what makes the picture look right.
     */
    if (from->body_count > 0 && !from->sees_all) {
        struct sight_fan fan;

        if (sight_fan_init(&fan, sight_fan_capacity_for(s->world))) {
            uint32_t eye;

            /*
             * One fan per pair of eyes, sent in turn rather than merged. The view
             * composites them, which is easier than any polygon union and is what
             * a renderer would rather have anyway.
             */
            for (eye = 0; eye < from->body_count; eye++) {
                if (!sight_compute(s->world, from->bodies[eye], &fan)) {
                    continue;
                }

                {
                    uint32_t point;

                    for (point = 0; point < fan.count; point++) {
                        struct instruction out;
                        instruction_begin(&out, OP_FAN);
                        instruction_set(&out, 0, fan.points[point].angle);
                        instruction_set(&out, 1, (uint32_t)fan.points[point].distance);
                        if (instruction_encode(&out, &v->outbound)) {
                            written++;
                        }
                    }
                }
            }

            sight_fan_release(&fan);
        }
    }

    {
        struct instruction end;
        instruction_begin(&end, OP_END);
        instruction_set(&end, 0, written);
        if (instruction_encode(&end, &v->outbound)) {
            written++;
        }
    }

    v->bytes_sent += v->outbound.count;

    return written;
}
/* }}} */

/* {{{ void outbound_refusal */
void outbound_refusal(struct viewer_set *set, uint32_t viewer_index,
                      uint16_t verb, uint32_t subject, uint16_t reason)
{
    struct viewer *v = viewer_at(set, viewer_index);
    struct instruction out;

    if (viewer_index == 0) {
        return;
    }

    /*
     * The reason travels as a number and the client turns it back into the
     * sentence, because both ends share the table. What must never happen is the
     * number arriving with no sentence anywhere -- which is why every reason has
     * one from the day it exists, including the one nobody wrote, which says so.
     */
    instruction_begin(&out, OP_REFUSAL);
    instruction_set(&out, 0, verb);
    instruction_set(&out, 1, subject);
    instruction_set(&out, 2, reason);

    if (instruction_encode(&out, &v->outbound)) {
        v->refusals++;
    }
}
/* }}} */

/* {{{ void outbound_recall */
void outbound_recall(struct viewer_set *set, uint32_t viewer_index, uint32_t turn)
{
    struct viewer *v = viewer_at(set, viewer_index);
    struct instruction out;

    if (viewer_index == 0) {
        return;
    }

    /*
     * Said out loud rather than implied by the next update contradicting the
     * last. A client that is never told is a client that flickers, and somebody
     * who has watched their screen contradict itself once stops trusting it.
     */
    instruction_begin(&out, OP_RECALL);
    instruction_set(&out, 0, turn);
    instruction_encode(&out, &v->outbound);
}
/* }}} */
