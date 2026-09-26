/*
 * crowd.h - the crowd of round units, in C, for running on every threading design (issue 515k)
 *
 * What this is: src/runtime/crowd.lua ported line for line, so the crowd
 * can run on threads (Lua can't share one crowd across threads). The Lua
 * crowd stays the reference; the port visits neighbours in the same
 * order, breaks ties the same way and does its arithmetic in the same
 * order, and a test compares the two positions tick by tick.
 *
 * A tick is three calls:
 *   cr_tick_begin(c)        on one thread: the snapshot of where everyone is
 *   cr_decide(c, i, dt)     for every unit index i, on any thread, in any
 *                           order, at once: each unit reads only the snapshot
 *                           and its own state, and writes only its own state
 *   cr_tick_end(c, dt)      on one thread: every unit settles, in id order
 * cr_tick() does all three on one thread.
 *
 * Units are numbered 1..n in the order added (their ids); index = id - 1.
 */
#ifndef CERAMIC_CROWD_H
#define CERAMIC_CROWD_H

#include <stdint.h>

typedef struct { double x, y; } cr_point;
typedef struct { double x, y, radius; } cr_circle;
typedef struct { double x, y, packed; } cr_group;

/* A request one unit makes of another while deciding: done when it settles. */
typedef struct { int kind; int target; double x, y; } cr_request;   /* kind: 1 nudge, 2 back off */
#define CR_MOST_REQUESTS 32

/* One unit: the Lua unit's fields, same names. */
typedef struct {
    int      id, team;
    double   x, y, radius, speed, path_radius;
    int      moving, arrived, gave_up, exact, path_changed;
    cr_point *path; int path_len, path_cap, step;      /* step counts from 1, as in Lua; path_len 0 with has_path 0 is "no path" */
    int      has_path;
    double   goal_x, goal_y, vx, vy, facing;
    cr_group *group;
    int      orbit, blocked_id, mutual, settle;
    long     wait_until;
    int      slide_since_progress;
    cr_circle *bundle; int bundle_len, bundle_cap, has_bundle;
    long     bundle_until;
    double   closest;
    long     no_progress, nudged_at, planned_at;
    int      planned;                                  /* 0: never (Lua's nil planned_at) */
    int      backing, back_offs, back_offs_done;
    int      steer_from, steer_side;                   /* steer_from 0: nobody */
    int      proposed, target_step;
    double   step_x, step_y;
    cr_request requests[CR_MOST_REQUESTS]; int nrequests, decided;
    int      has_before_nudge, bn_arrived, bn_gave_up;
    double   bn_goal_x, bn_goal_y;
    int      bucket;
} cr_unit;

/* What another unit may read of a unit while deciding. */
typedef struct {
    int      id, team, moving, arrived, blocked_id, backing, back_offs;
    double   x, y, radius, path_radius, goal_x, goal_y, speed;
    cr_group *group;
    long     nudged_at, no_progress;
} cr_record;

typedef struct cr_crowd cr_crowd;

/* {{{ the crowd */
cr_crowd *cr_new(int w, int h, const unsigned char *walkable, double cell);   /* walkable[(y-1)*w + (x-1)], y from the top */
void      cr_free(cr_crowd *c);
void      cr_add(cr_crowd *c, double x, double y, double radius, double speed, int team);   /* the next id */
void      cr_move_group(cr_crowd *c, const int *ids, int n, double x, double y);
void      cr_tick_begin(cr_crowd *c);
void      cr_decide(cr_crowd *c, int index, double dt);
void      cr_tick_end(cr_crowd *c, double dt);
void      cr_tick(cr_crowd *c, double dt);
int       cr_count(const cr_crowd *c);
cr_unit  *cr_units(cr_crowd *c);
long      cr_tick_count(const cr_crowd *c);
double    cr_look_ahead(const cr_crowd *c);
void      cr_set_look_ahead(cr_crowd *c, double ahead);
int       cr_any_overlap(const cr_crowd *c, int *a, int *b);   /* 1 and the ids, or 0 */
/* }}} */

#endif
