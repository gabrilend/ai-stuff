/*
 * crowd.c - the crowd of round units, ported from src/runtime/crowd.lua (issue 515k)
 *
 * What this is: the Lua crowd, line for line, in C, so it can run on
 * threads. Every function here has the Lua function of the same name; the
 * comments there explain why each rule is as it is, and aren't repeated.
 * What is particular to the port is noted where it happens:
 *   - neighbours are visited in the same order (bucket by bucket, dx then
 *     dy, each bucket in the order units entered it), ties broken the same
 *     way, and arithmetic done in the same order, so positions can be
 *     compared with the Lua crowd's;
 *   - the planner's working arrays are per thread (a thread may plan for
 *     any unit while others plan for theirs);
 *   - back-offs are counted per unit (a shared count would be written by
 *     several deciding threads at once).
 */
#include "crowd.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* {{{ The numbers: the Lua crowd's, same names */
#define GAP 0.05
#define GIVE_WAY_TICKS 6
#define GIVE_WAY_FOR 30
#define BUNDLE_TICKS 25
#define BUNDLE_GAP 0.3
#define BUNDLE_KEEP 120
#define NUDGE_EVERY 20
#define NO_PROGRESS_TICKS 1250
#define PROGRESS 0.25
#define ARRIVE 0.02
#define SLIDE_OUTWARD 0.15
#define SLIDE_AROUND 0.5
#define REPLAN_EVERY 15
#define SETTLE_TICKS 10
#define SETTLE_FAR_TICKS 90
#define PACKING 0.6
#define CLEARANCE_REACH 3
#define PATHING_EXTRA 0.2
#define GRIDLOCK_TICKS 125
#define BACK_OFF 1.0
#define BACK_OFFS 3
#define NEVER (-1000000000L)   /* Lua's -math.huge for "never nudged" */
/* }}} */

/* A bucket of the spatial hash: unit indices in the order they entered. */
typedef struct { int *items; int n, cap; } cr_bucket;

struct cr_crowd {
    int w, h;
    double cell;
    unsigned char *walk;
    double *clearance;
    cr_unit *units; int n, cap;
    cr_record *snap;
    long tick_count;
    double largest, bucket_size, look_ahead;
    /* the spatial hash over the field, one bucket more on every side (Lua's
     * buckets at -1 simply don't exist; here they are empty) */
    int bw, bh;
    cr_bucket *live, *snapped;
    int deciding;               /* 1 while units decide: neighbours come from the snapshot */
    cr_group **groups; int ngroups, groups_cap;
};

/* {{{ small helpers */
static double length(double x, double y) { return sqrt(x * x + y * y); }
static double max2(double a, double b) { return a > b ? a : b; }
static double min2(double a, double b) { return a < b ? a : b; }
/* {{{ static double max3(double a, double b, double c) */
/* math.max(a, b, c) */
static double max3(double a, double b, double c)
{
    double m = a;
    if (b > m) m = b;
    if (c > m) m = c;
    return m;
}
/* }}} */
/* {{{ static void *grow(void *p, int *cap, int need, size_t each) */
static void *grow(void *p, int *cap, int need, size_t each)
{
    if (need <= *cap) return p;
    int c = *cap ? *cap : 8;
    while (c < need) c *= 2;
    p = realloc(p, (size_t)c * each);
    if (!p) { fprintf(stderr, "crowd: out of memory\n"); exit(71); }
    *cap = c;
    return p;
}
/* }}} */
/* }}} */

/* {{{ The ground */
static int cell_of(const cr_crowd *c, double v) { return (int)floor(v / c->cell) + 1; }
static double centre_of(const cr_crowd *c, int k) { return (k - 0.5) * c->cell; }

/* {{{ static int walkable(const cr_crowd *c, int cx, int cy) */
static int walkable(const cr_crowd *c, int cx, int cy)
{
    if (cx < 1 || cx > c->w || cy < 1 || cy > c->h) return 0;
    return c->walk[(cy - 1) * c->w + (cx - 1)];
}
/* }}} */

/* {{{ static double to_rect(...) */
static double to_rect(double px, double py, double x1, double y1, double x2, double y2)
{
    double dx = max3(x1 - px, 0, px - x2);
    double dy = max3(y1 - py, 0, py - y2);
    return length(dx, dy);
}
/* }}} */

/* {{{ static int clear_of_walls(const cr_crowd *c, double x, double y, double r) */
static int clear_of_walls(const cr_crowd *c, double x, double y, double r)
{
    int x1 = cell_of(c, x - r), y1 = cell_of(c, y - r);
    int x2 = cell_of(c, x + r), y2 = cell_of(c, y + r);
    double k = c->cell;
    for (int cy = y1; cy <= y2; cy++)
        for (int cx = x1; cx <= x2; cx++)
            if (!walkable(c, cx, cy) && to_rect(x, y, (cx - 1) * k, (cy - 1) * k, cx * k, cy * k) < r) return 0;
    return 1;
}
/* }}} */

/* {{{ static void measure_clearance(cr_crowd *c) */
static void measure_clearance(cr_crowd *c)
{
    double k = c->cell;
    int reach = CLEARANCE_REACH;
    for (int y = 1; y <= c->h; y++)
        for (int x = 1; x <= c->w; x++) {
            double best = 0;
            if (walkable(c, x, y)) {
                best = reach * k;
                double px = centre_of(c, x), py = centre_of(c, y);
                for (int wy = y - reach; wy <= y + reach; wy++)
                    for (int wx = x - reach; wx <= x + reach; wx++)
                        if (!walkable(c, wx, wy)) {
                            double d = to_rect(px, py, (wx - 1) * k, (wy - 1) * k, wx * k, wy * k);
                            if (d < best) best = d;
                        }
            }
            c->clearance[(y - 1) * c->w + (x - 1)] = best;
        }
}
/* }}} */
/* }}} */

/* {{{ The spatial hash */
/* {{{ static int bucket_index(const cr_crowd *c, int bx, int by) */
/* Lua's bucket key floor(x/size), floor(y/size), shifted by one; -1 when
 * outside the field's buckets (no unit is ever there). */
static int bucket_index(const cr_crowd *c, int bx, int by)
{
    bx += 1; by += 1;
    if (bx < 0 || by < 0 || bx >= c->bw || by >= c->bh) return -1;
    return by * c->bw + bx;
}
/* }}} */

/* {{{ static void size_buckets(cr_crowd *c) */
static void size_buckets(cr_crowd *c)
{
    int bw = (int)floor(c->w * c->cell / c->bucket_size) + 3;
    int bh = (int)floor(c->h * c->cell / c->bucket_size) + 3;
    if (bw == c->bw && bh == c->bh && c->live) return;
    for (int i = 0; c->live && i < c->bw * c->bh; i++) { free(c->live[i].items); free(c->snapped[i].items); }
    free(c->live); free(c->snapped);
    c->bw = bw; c->bh = bh;
    c->live = calloc((size_t)bw * bh, sizeof(cr_bucket));
    c->snapped = calloc((size_t)bw * bh, sizeof(cr_bucket));
    if (!c->live || !c->snapped) { fprintf(stderr, "crowd: out of memory\n"); exit(71); }
}
/* }}} */

/* {{{ static void bucket_add(cr_bucket *b, int i) */
static void bucket_add(cr_bucket *b, int i)
{
    b->items = grow(b->items, &b->cap, b->n + 1, sizeof(int));
    b->items[b->n++] = i;
}
/* }}} */

/* {{{ static int key_of(const cr_crowd *c, double x, double y) */
static int key_of(const cr_crowd *c, double x, double y)
{
    return bucket_index(c, (int)floor(x / c->bucket_size), (int)floor(y / c->bucket_size));
}
/* }}} */

/* {{{ static void rehash(cr_crowd *c) */
static void rehash(cr_crowd *c)
{
    size_buckets(c);
    for (int i = 0; i < c->bw * c->bh; i++) c->live[i].n = 0;
    for (int i = 0; i < c->n; i++) {
        cr_unit *u = &c->units[i];
        int k = key_of(c, u->x, u->y);
        bucket_add(&c->live[k], i);
        u->bucket = k;
    }
}
/* }}} */

/* {{{ static void rebucket(cr_crowd *c, cr_unit *u) */
static void rebucket(cr_crowd *c, cr_unit *u)
{
    int k = key_of(c, u->x, u->y);
    if (k == u->bucket) return;
    cr_bucket *old = &c->live[u->bucket];
    int i = u->id - 1;
    for (int j = 0; j < old->n; j++)
        if (old->items[j] == i) {
            memmove(&old->items[j], &old->items[j + 1], (size_t)(old->n - j - 1) * sizeof(int));
            old->n--;
            break;
        }
    bucket_add(&c->live[k], i);
    u->bucket = k;
}
/* }}} */

/* A neighbour as either phase sees it: its record while deciding, the unit
 * itself while settling. */
typedef struct {
    int id, team, moving, arrived, blocked_id, backing, back_offs;
    double x, y, radius, path_radius, goal_x, goal_y, speed;
    cr_group *group;
    long nudged_at, no_progress;
} cr_view;

/* {{{ static void view_of(const cr_crowd *c, int i, cr_view *v) */
static void view_of(const cr_crowd *c, int i, cr_view *v)
{
    if (c->deciding) {
        const cr_record *r = &c->snap[i];
        *v = (cr_view){ r->id, r->team, r->moving, r->arrived, r->blocked_id, r->backing, r->back_offs,
                        r->x, r->y, r->radius, r->path_radius, r->goal_x, r->goal_y, r->speed,
                        r->group, r->nudged_at, r->no_progress };
    } else {
        const cr_unit *u = &c->units[i];
        *v = (cr_view){ u->id, u->team, u->moving, u->arrived, u->blocked_id, u->backing, u->back_offs,
                        u->x, u->y, u->radius, u->path_radius, u->goal_x, u->goal_y, u->speed,
                        u->group, u->nudged_at, u->no_progress };
    }
}
/* }}} */

/* The 3x3 buckets round a point, as one list of unit indices in Lua's
 * visiting order. Filled into a caller's buffer. */
typedef struct { int *items; int n, cap; } cr_list;

/* {{{ static void near(const cr_crowd *c, double x, double y, cr_list *out) */
static void near(const cr_crowd *c, double x, double y, cr_list *out)
{
    const cr_bucket *buckets = c->deciding ? c->snapped : c->live;
    int bx = (int)floor(x / c->bucket_size), by = (int)floor(y / c->bucket_size);
    out->n = 0;
    for (int dx = -1; dx <= 1; dx++)
        for (int dy = -1; dy <= 1; dy++) {
            int k = bucket_index(c, bx + dx, by + dy);
            if (k < 0) continue;
            const cr_bucket *b = &buckets[k];
            out->items = grow(out->items, &out->cap, out->n + b->n, sizeof(int));
            memcpy(&out->items[out->n], b->items, (size_t)b->n * sizeof(int));
            out->n += b->n;
        }
}
/* }}} */

/* per-thread scratch for neighbour lists */
static _Thread_local cr_list scratch_near, scratch_near2;

/* {{{ static int overlapping(const cr_crowd *c, const cr_unit *u, double x, double y, cr_view *found) */
/* The unit a circle of u's size at (x, y) would overlap most deeply; 1
 * and its view in `found`, or 0. */
static int overlapping(const cr_crowd *c, const cr_unit *u, double x, double y, cr_view *found)
{
    double deepest = 0;
    int have = 0;
    near(c, x, y, &scratch_near);
    for (int j = 0; j < scratch_near.n; j++) {
        cr_view o;
        view_of(c, scratch_near.items[j], &o);
        if (o.id == u->id) continue;
        double reach = u->radius + o.radius;
        double dx = o.x - x, dy = o.y - y;
        double d2 = dx * dx + dy * dy;
        if (d2 < reach * reach - 1e-9) {
            double depth = reach - sqrt(d2);
            if (depth > deepest || (depth == deepest && have && o.id < found->id)) { *found = o; deepest = depth; have = 1; }
        }
    }
    return have;
}
/* }}} */
/* }}} */

/* {{{ Planning */
typedef struct { int node; double f; } cr_heap_item;

/* the planner's working arrays, per thread; `seen` stamps each array with
 * the plan that last wrote it, so nothing is cleared between plans */
typedef struct {
    cr_heap_item *heap; int hn, hcap;
    double *g; int *from; unsigned *g_stamp, *closed_stamp; int cells;
    unsigned stamp;
    cr_point *points; int pn, pcap;
    cr_point *pulled; int pln, plcap;
} cr_planner;
static _Thread_local cr_planner planner;

/* {{{ static void heap_push(cr_planner *p, int node, double f) */
static void heap_push(cr_planner *p, int node, double f)
{
    p->heap = grow(p->heap, &p->hcap, p->hn + 2, sizeof(cr_heap_item));
    int n = ++p->hn;                       /* 1-based, as in Lua */
    p->heap[n] = (cr_heap_item){ node, f };
    while (n > 1) {
        int parent = n / 2;
        if (p->heap[parent].f <= p->heap[n].f) break;
        cr_heap_item t = p->heap[parent]; p->heap[parent] = p->heap[n]; p->heap[n] = t;
        n = parent;
    }
}
/* }}} */

/* {{{ static int heap_pop(cr_planner *p) */
static int heap_pop(cr_planner *p)
{
    cr_heap_item top = p->heap[1];
    cr_heap_item last = p->heap[p->hn--];
    if (p->hn > 0) {
        p->heap[1] = last;
        int n = 1;
        for (;;) {
            int l = 2 * n, r = 2 * n + 1, small = n;
            if (l <= p->hn && p->heap[l].f < p->heap[small].f) small = l;
            if (r <= p->hn && p->heap[r].f < p->heap[small].f) small = r;
            if (small == n) break;
            cr_heap_item t = p->heap[small]; p->heap[small] = p->heap[n]; p->heap[n] = t;
            n = small;
        }
    }
    return top.node;
}
/* }}} */

static const int STEPS[8][2] = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } };
static const double STEP_COST[8] = { 1, 1, 1, 1, 1.41421356, 1.41421356, 1.41421356, 1.41421356 };

/* {{{ static int inside_any(double x, double y, double r, const cr_circle *circles, int n) */
static int inside_any(double x, double y, double r, const cr_circle *circles, int n)
{
    for (int i = 0; i < n; i++) {
        double reach = r + circles[i].radius;
        double dx = circles[i].x - x, dy = circles[i].y - y;
        if (dx * dx + dy * dy < reach * reach) return 1;
    }
    return 0;
}
/* }}} */

/* {{{ static int line_clear(...) */
static int line_clear(const cr_crowd *c, double x1, double y1, double x2, double y2, double r, const cr_circle *circles, int nc)
{
    double d = length(x2 - x1, y2 - y1);
    double steps = max2(1, ceil(d / (c->cell * 0.25)));
    for (int i = 0; i <= (int)steps; i++) {
        double t = i / steps;
        double x = x1 + (x2 - x1) * t, y = y1 + (y2 - y1) * t;
        if (!clear_of_walls(c, x, y, r) || inside_any(x, y, r, circles, nc)) return 0;
    }
    return 1;
}
/* }}} */

/* the plan's own fields, set for open() */
typedef struct { const cr_crowd *c; int sx, sy; double r; const cr_circle *circles; int nc; } cr_plan_ctx;

/* {{{ static int open_cell(const cr_plan_ctx *p, int cx, int cy) */
static int open_cell(const cr_plan_ctx *p, int cx, int cy)
{
    if (cx == p->sx && cy == p->sy) return 1;
    if (cx < 1 || cx > p->c->w || cy < 1 || cy > p->c->h) return 0;
    if (p->c->clearance[(cy - 1) * p->c->w + (cx - 1)] < p->r) return 0;
    return !inside_any(centre_of(p->c, cx), centre_of(p->c, cy), p->r, p->circles, p->nc);
}
/* }}} */

/* {{{ static int plan(...) */
/* A path for u to (tx, ty), in planner.pulled (planner.pln points); 1 and
 * *exact, or 0 when u can't leave where it is. */
static int plan(const cr_crowd *c, const cr_unit *u, double tx, double ty, const cr_circle *circles, int nc, int *exact)
{
    cr_planner *p = &planner;
    int cells = c->w * c->h;
    if (p->cells < cells) {
        p->g = realloc(p->g, (size_t)cells * sizeof(double));
        p->from = realloc(p->from, (size_t)cells * sizeof(int));
        p->g_stamp = calloc((size_t)cells, sizeof(unsigned));
        p->closed_stamp = calloc((size_t)cells, sizeof(unsigned));
        if (!p->g || !p->from || !p->g_stamp || !p->closed_stamp) { fprintf(stderr, "crowd: out of memory\n"); exit(71); }
        p->cells = cells;
        p->stamp = 0;
    }
    p->stamp++;
    cr_plan_ctx ctx = { c, cell_of(c, u->x), cell_of(c, u->y), u->radius, circles, nc };
    int sx = ctx.sx, sy = ctx.sy;
    int gx = cell_of(c, tx), gy = cell_of(c, ty);
    int fits = clear_of_walls(c, tx, ty, ctx.r) && !inside_any(tx, ty, ctx.r, circles, nc);
#define CELL(x, y) (((y) - 1) * c->w + ((x) - 1))
#define H(x, y) (max2(fabs((double)((x) - gx)), fabs((double)((y) - gy))) + 0.41421356 * min2(fabs((double)((x) - gx)), fabs((double)((y) - gy))))
    p->hn = 0;
    int start = CELL(sx, sy);
    p->g[start] = 0; p->g_stamp[start] = p->stamp;
    heap_push(p, start, H(sx, sy));
    int closest = start;
    double closest_h = H(sx, sy);
    int found = 0;
    while (p->hn > 0) {
        int key = heap_pop(p);
        if (p->closed_stamp[key] == p->stamp) continue;
        p->closed_stamp[key] = p->stamp;
        int cx = key % c->w + 1, cy = key / c->w + 1;
        if (cx == gx && cy == gy) { found = 1; break; }
        double hh = H(cx, cy);
        if (hh < closest_h) { closest = key; closest_h = hh; }
        for (int s = 0; s < 8; s++) {
            int nx = cx + STEPS[s][0], ny = cy + STEPS[s][1];
            int diagonal_ok = STEPS[s][0] == 0 || STEPS[s][1] == 0 ||
                              (open_cell(&ctx, cx + STEPS[s][0], cy) && open_cell(&ctx, cx, cy + STEPS[s][1]));
            int enterable = open_cell(&ctx, nx, ny) || (nx == gx && ny == gy && fits);
            if (diagonal_ok && enterable) {
                int nk = CELL(nx, ny);
                double ng = p->g[key] + STEP_COST[s];
                if (p->g_stamp[nk] != p->stamp || ng < p->g[nk]) {
                    p->g[nk] = ng; p->g_stamp[nk] = p->stamp;
                    p->from[nk] = key;
                    heap_push(p, nk, ng + H(nx, ny));
                }
            }
        }
    }
    *exact = found && fits;
    int key = CELL(gx, gy);
    if (!found) {
        key = closest;
        if (key == start) return 0;
    }
    /* the cells back to the start, then the right way round */
    p->pn = 0;
    while (key != start) {
        p->points = grow(p->points, &p->pcap, p->pn + 1, sizeof(cr_point));
        p->points[p->pn++] = (cr_point){ centre_of(c, key % c->w + 1), centre_of(c, key / c->w + 1) };
        key = p->from[key];
    }
    for (int i = 0, j = p->pn - 1; i < j; i++, j--) { cr_point t = p->points[i]; p->points[i] = p->points[j]; p->points[j] = t; }
    if (*exact) {
        if (p->pn > 0) p->points[p->pn - 1] = (cr_point){ tx, ty };
        else { p->points = grow(p->points, &p->pcap, 1, sizeof(cr_point)); p->points[0] = (cr_point){ tx, ty }; p->pn = 1; }
    }
    if (p->pn == 0) return 0;
    /* pull straight */
    p->pln = 0;
    double fx = u->x, fy = u->y;
    int i = 0;
    while (i < p->pn) {
        int far = i;
        for (int j = p->pn - 1; j > i; j--)
            if (line_clear(c, fx, fy, p->points[j].x, p->points[j].y, ctx.r, circles, nc)) { far = j; break; }
        p->pulled = grow(p->pulled, &p->plcap, p->pln + 1, sizeof(cr_point));
        p->pulled[p->pln++] = p->points[far];
        fx = p->points[far].x; fy = p->points[far].y;
        i = far + 1;
    }
    return 1;
#undef CELL
#undef H
}
/* }}} */

/* {{{ static void set_path(cr_unit *u, const cr_point *pts, int n) */
static void set_path(cr_unit *u, const cr_point *pts, int n)
{
    u->path = grow(u->path, &u->path_cap, n, sizeof(cr_point));
    memcpy(u->path, pts, (size_t)n * sizeof(cr_point));
    u->path_len = n;
    u->has_path = 1;
}
/* }}} */

/* {{{ static void head_for(cr_crowd *c, cr_unit *u, double tx, double ty, const cr_circle *circles, int nc) */
static void head_for(cr_crowd *c, cr_unit *u, double tx, double ty, const cr_circle *circles, int nc)
{
    u->planned_at = c->tick_count; u->planned = 1;
    u->goal_x = tx; u->goal_y = ty;
    int exact = 0;
    int ok = plan(c, u, tx, ty, circles, nc, &exact);
    if (!ok && circles) {
        u->has_bundle = 0; u->bundle_len = 0; u->bundle_until = 0;
        ok = plan(c, u, tx, ty, NULL, 0, &exact);
    }
    if (ok) set_path(u, planner.pulled, planner.pln);
    else { u->has_path = 0; u->path_len = 0; }
    u->step = 1;
    u->exact = exact;
    u->path_changed = 1;
    u->moving = 1;
}
/* }}} */

/* {{{ static void replan(cr_crowd *c, cr_unit *u, int with_bundle) */
static void replan(cr_crowd *c, cr_unit *u, int with_bundle)
{
    if (u->planned && c->tick_count - u->planned_at < REPLAN_EVERY) return;
    if (with_bundle && u->has_bundle) head_for(c, u, u->goal_x, u->goal_y, u->bundle, u->bundle_len);
    else head_for(c, u, u->goal_x, u->goal_y, NULL, 0);
}
/* }}} */
/* }}} */

/* {{{ Moving */
/* {{{ static void stand(cr_unit *u, int gave_up) */
static void stand(cr_unit *u, int gave_up)
{
    u->moving = 0; u->has_path = 0; u->path_len = 0; u->step = 0;
    u->vx = 0; u->vy = 0;
    u->gave_up = gave_up;
    u->arrived = !gave_up;
    u->orbit = 0; u->blocked_id = 0; u->mutual = 0; u->settle = 0;
    u->proposed = 0;
    u->path_changed = 1;
}
/* }}} */

/* {{{ static int try_step(cr_crowd *c, cr_unit *u, double dx, double dy, cr_view *blocker) */
/* 1: proposed; 0: a wall; 2: a unit, in *blocker. */
static int try_step(cr_crowd *c, cr_unit *u, double dx, double dy, cr_view *blocker)
{
    double nx = u->x + dx, ny = u->y + dy;
    if (!clear_of_walls(c, nx, ny, u->radius)) return 0;
    if (overlapping(c, u, nx, ny, blocker)) return 2;
    u->step_x = dx; u->step_y = dy; u->proposed = 1;
    return 1;
}
/* }}} */

/* {{{ static void request(cr_unit *u, int kind, int target, double x, double y) */
static void request(cr_unit *u, int kind, int target, double x, double y)
{
    if (u->nrequests >= CR_MOST_REQUESTS) { fprintf(stderr, "crowd: unit %d asked more than %d things in one tick\n", u->id, CR_MOST_REQUESTS); exit(70); }
    u->requests[u->nrequests++] = (cr_request){ kind, target, x, y };
}
/* }}} */

/* {{{ static void nudge(cr_crowd *c, const cr_view *o, cr_unit *u, double dx, double dy) */
static void nudge(cr_crowd *c, const cr_view *o, cr_unit *u, double dx, double dy)
{
    if (o->moving || o->team != u->team || c->tick_count - o->nudged_at < NUDGE_EVERY) return;
    double d = length(dx, dy);
    if (d == 0) return;
    double ux = dx / d, uy = dy / d;
    double ox = o->x - u->x, oy = o->y - u->y;
    double across = ux * oy - uy * ox;
    int side = across >= 0 ? 1 : -1;
    int sides[2] = { side, -side };
    for (int k = 0; k < 2; k++) {
        int s = sides[k];
        double shift = u->radius + o->radius + GAP - s * across;
        double tx = o->x - uy * s * shift, ty = o->y + ux * s * shift;
        if (clear_of_walls(c, tx, ty, o->radius)) { request(u, 1, o->id, tx, ty); return; }
    }
}
/* }}} */

/* {{{ static int step_aside(cr_crowd *c, cr_unit *u, const cr_view *o) */
static int step_aside(cr_crowd *c, cr_unit *u, const cr_view *o)
{
    double dx = o->goal_x - o->x, dy = o->goal_y - o->y;
    double d = length(dx, dy);
    if (d == 0) return 0;
    double ox = dx / d, oy = dy / d;
    double across = ox * (u->y - o->y) - oy * (u->x - o->x);
    int side = across >= 0 ? 1 : -1;
    int sides[2] = { side, -side };
    for (int k = 0; k < 2; k++) {
        int sgn = sides[k];
        double shift = u->radius + o->radius + GAP - sgn * across;
        double tx = u->x - oy * sgn * shift, ty = u->y + ox * sgn * shift;
        cr_view b;
        if (clear_of_walls(c, tx, ty, u->radius) && !overlapping(c, u, tx, ty, &b)) {
            /* the aside step first, then its own way on from there */
            int rest = u->has_path ? u->path_len - u->step + 1 : 0;
            if (rest < 0) rest = 0;
            int n = 1 + rest + (rest == 0 ? 1 : 0);
            cr_point *path = malloc((size_t)n * sizeof(cr_point));
            path[0] = (cr_point){ tx, ty };
            for (int i = 0; i < rest; i++) path[1 + i] = u->path[u->step - 1 + i];
            if (rest == 0) path[1] = (cr_point){ u->goal_x, u->goal_y };
            set_path(u, path, n);
            free(path);
            u->step = 1;
            u->path_changed = 1;
            return 1;
        }
    }
    return 0;
}
/* }}} */

/* {{{ static void bundle_of(cr_crowd *c, cr_unit *u, const cr_view *o) */
/* Into u's own bundle: the standing units touching o, and those touching
 * them (a depth-first walk, taking from the end, as Lua's table.remove). */
static void bundle_of(cr_crowd *c, cr_unit *u, const cr_view *o)
{
    static _Thread_local int *seen; static _Thread_local int seen_cap;
    static _Thread_local cr_view *queue; static _Thread_local int queue_cap;
    seen = grow(seen, &seen_cap, c->n + 1, sizeof(int));
    memset(seen, 0, (size_t)(c->n + 1) * sizeof(int));
    int qn = 0;
    queue = grow(queue, &queue_cap, 1, sizeof(cr_view));
    queue[qn++] = *o;
    seen[o->id] = 1;
    u->bundle_len = 0;
    while (qn > 0) {
        cr_view a = queue[--qn];
        u->bundle = grow(u->bundle, &u->bundle_cap, u->bundle_len + 1, sizeof(cr_circle));
        u->bundle[u->bundle_len++] = (cr_circle){ a.x, a.y, a.radius };
        near(c, a.x, a.y, &scratch_near2);
        for (int j = 0; j < scratch_near2.n; j++) {
            cr_view b;
            view_of(c, scratch_near2.items[j], &b);
            if (!seen[b.id] && !b.moving) {
                double reach = a.radius + b.radius + BUNDLE_GAP;
                double dx = a.x - b.x, dy = a.y - b.y;
                if (dx * dx + dy * dy < reach * reach) {
                    seen[b.id] = 1;
                    queue = grow(queue, &queue_cap, qn + 1, sizeof(cr_view));
                    queue[qn++] = b;
                }
            }
        }
    }
    u->has_bundle = 1;
}
/* }}} */

/* {{{ static int slide(cr_crowd *c, cr_unit *u, const cr_view *o, double wx, double wy, double reach) */
static int slide(cr_crowd *c, cr_unit *u, const cr_view *o, double wx, double wy, double reach)
{
    double nx = u->x - o->x, ny = u->y - o->y;
    double nd = length(nx, ny);
    if (nd == 0) return 0;
    nx = nx / nd; ny = ny / nd;
    if (u->orbit == 0) {
        double along = -ny * wx + nx * wy;
        if (fabs(along) < 0.2 * reach) u->orbit = (-ny * wy + nx * -wx) >= 0 ? 1 : -1;
        else u->orbit = along > 0 ? 1 : -1;
    }
    double into = wx * nx + wy * ny;
    double px = wx, py = wy;
    if (into < 0) { px = wx - into * nx; py = wy - into * ny; }
    double sx = px + (-ny * u->orbit * SLIDE_AROUND + SLIDE_OUTWARD * nx) * reach;
    double sy = py + (nx * u->orbit * SLIDE_AROUND + SLIDE_OUTWARD * ny) * reach;
    double sd = length(sx, sy);
    if (sd == 0) return 0;
    sx = sx / sd * reach; sy = sy / sd * reach;
    cr_view b;
    if (try_step(c, u, sx, sy, &b) == 1) return 1;
    return try_step(c, u, sx * 0.5, sy * 0.5, &b) == 1;
}
/* }}} */

/* {{{ static int nearest_wall_point(const cr_crowd *c, double x, double y, double r, double *qx, double *qy) */
static int nearest_wall_point(const cr_crowd *c, double x, double y, double r, double *qx, double *qy)
{
    double reach = r + c->cell;
    int x1 = cell_of(c, x - reach), y1 = cell_of(c, y - reach);
    int x2 = cell_of(c, x + reach), y2 = cell_of(c, y + reach);
    double k = c->cell, best = INFINITY;
    int have = 0;
    for (int cy = y1; cy <= y2; cy++)
        for (int cx = x1; cx <= x2; cx++)
            if (!walkable(c, cx, cy)) {
                double px = max2((cx - 1) * k, min2(x, cx * k));
                double py = max2((cy - 1) * k, min2(y, cy * k));
                double d = length(x - px, y - py);
                if (d < best) { best = d; *qx = px; *qy = py; have = 1; }
            }
    return have;
}
/* }}} */

/* {{{ static int slide_on_wall(cr_crowd *c, cr_unit *u, double wx, double wy, double reach) */
static int slide_on_wall(cr_crowd *c, cr_unit *u, double wx, double wy, double reach)
{
    double qx, qy;
    if (!nearest_wall_point(c, u->x + wx, u->y + wy, u->radius, &qx, &qy)) return 0;
    double nx = u->x - qx, ny = u->y - qy;
    double nd = length(nx, ny);
    if (nd == 0) return 0;
    nx = nx / nd; ny = ny / nd;
    double into = wx * nx + wy * ny;
    double px = wx, py = wy;
    if (into < 0) { px = wx - into * nx; py = wy - into * ny; }
    px = px + SLIDE_OUTWARD * nx * reach; py = py + SLIDE_OUTWARD * ny * reach;
    double pd = length(px, py);
    if (pd < 1e-9) return 0;
    px = px / pd * reach; py = py / pd * reach;
    cr_view b;
    if (try_step(c, u, px, py, &b) == 1) return 1;
    return try_step(c, u, px * 0.5, py * 0.5, &b) == 1;
}
/* }}} */

/* {{{ static void steer(cr_crowd *c, cr_unit *u, double *wx, double *wy, double reach, double ahead) */
static void steer(cr_crowd *c, cr_unit *u, double *wx, double *wy, double reach, double ahead)
{
    double d = length(*wx, *wy);
    if (d == 0 || ahead <= 0) return;
    double ux = *wx / d, uy = *wy / d;
    cr_view best;
    int have = 0;
    double best_along = 0;
    near(c, u->x, u->y, &scratch_near);
    for (int j = 0; j < scratch_near.n; j++) {
        cr_view o;
        view_of(c, scratch_near.items[j], &o);
        if (o.id == u->id) continue;
        if (o.arrived && o.group == u->group) continue;
        if (!o.moving && o.team == u->team) continue;
        if (o.moving) {
            double gx = o.goal_x - o.x, gy = o.goal_y - o.y;
            double gd = length(gx, gy);
            if (gd > 0 && (gx * ux + gy * uy) / gd > 0.5) continue;
        }
        double cx = o.x - u->x, cy = o.y - u->y;
        double along = cx * ux + cy * uy;
        if (along <= 0 || along > ahead + o.path_radius) continue;
        double across = fabs(cx * uy - cy * ux);
        if (across < u->path_radius + o.path_radius && (!have || along < best_along)) { best = o; best_along = along; have = 1; }
    }
    if (!have) { u->steer_from = 0; return; }
    double cx = best.x - u->x, cy = best.y - u->y;
    double D = length(cx, cy);
    double R = u->path_radius + best.path_radius;
    int side = u->steer_from ? u->steer_side : 0;
    if (!side) {
        double cross = cx * uy - cy * ux;
        if (fabs(cross) < 0.05 * D) side = 1; else side = cross > 0 ? 1 : -1;
        u->steer_from = best.id; u->steer_side = side;
    }
    double angle = atan2(cy, cx);
    double off = D > R ? asin(R / D) : M_PI / 2;
    double a = angle - side * off;
    *wx = cos(a) * reach; *wy = sin(a) * reach;
}
/* }}} */

/* {{{ static void back_off(cr_crowd *c, cr_unit *u) */
static void back_off(cr_crowd *c, cr_unit *u)
{
    double ax = 0, ay = 0;
    int n = 0;
    near(c, u->x, u->y, &scratch_near2);
    for (int j = 0; j < scratch_near2.n; j++) {
        cr_view o;
        view_of(c, scratch_near2.items[j], &o);
        if (o.id != u->id && length(o.x - u->x, o.y - u->y) < u->radius + o.radius + BUNDLE_GAP) { ax = ax + o.x; ay = ay + o.y; n++; }
    }
    double bx, by;
    if (n > 0) { bx = u->x - ax / n; by = u->y - ay / n; } else { bx = u->x - u->goal_x; by = u->y - u->goal_y; }
    double bd = length(bx, by);
    if (bd == 0) return;
    bx = bx / bd; by = by / bd;
    double far = BACK_OFF + u->radius;
    int have = 0;
    double tx = 0, ty = 0;
    for (int k = 8; k >= 1; k--) {
        double x = u->x + bx * far * k / 8, y = u->y + by * far * k / 8;
        if (clear_of_walls(c, x, y, u->radius)) { tx = x; ty = y; have = 1; break; }
    }
    if (!have) return;
    u->back_offs++;
    u->back_offs_done++;
    u->backing = 1;
    u->orbit = 0; u->has_bundle = 0; u->bundle_len = 0; u->bundle_until = 0;
    cr_point p = { tx, ty };
    set_path(u, &p, 1);
    u->step = 1; u->path_changed = 1;
    u->closest = INFINITY; u->no_progress = 0;
}
/* }}} */

/* {{{ void cr_decide(cr_crowd *c, int index, double dt) */
void cr_decide(cr_crowd *c, int index, double dt)
{
    cr_unit *u = &c->units[index];
    if (!u->moving) return;
    long t = c->tick_count;
    u->vx = 0; u->vy = 0;
    u->proposed = 0;
    u->nrequests = 0; u->decided = 1;
    if (u->wait_until > t) return;

    double to_goal = length(u->goal_x - u->x, u->goal_y - u->y);
    if (to_goal < u->closest - PROGRESS) { u->closest = to_goal; u->no_progress = 0; u->slide_since_progress = 0; }
    else u->no_progress++;
    if (u->no_progress >= NO_PROGRESS_TICKS) { stand(u, 1); return; }
    if (!u->backing && u->back_offs < BACK_OFFS && u->no_progress >= (long)GRIDLOCK_TICKS * (u->back_offs + 1)) {
        back_off(c, u);
        near(c, u->x, u->y, &scratch_near2);
        for (int j = 0; j < scratch_near2.n; j++) {
            cr_view o;
            view_of(c, scratch_near2.items[j], &o);
            if (o.id != u->id && o.moving && !o.backing && o.back_offs < BACK_OFFS
                && o.no_progress >= GRIDLOCK_TICKS / 2.0
                && length(o.x - u->x, o.y - u->y) < u->radius + o.radius + 1.0)
                request(u, 2, o.id, 0, 0);
        }
    }

    if (!u->has_path) {
        replan(c, u, u->bundle_until > t);
        if (!u->has_path) return;
    }

    cr_point target = u->path[u->step - 1];
    double dx = target.x - u->x, dy = target.y - u->y;
    double dist = length(dx, dy);
    double reach = u->speed * dt;
    double wx, wy;
    if (dist <= reach) { wx = dx; wy = dy; } else { wx = dx / dist * reach; wy = dy / dist * reach; }
    if (!u->backing && c->look_ahead > 0) steer(c, u, &wx, &wy, reach, min2(dist, c->look_ahead));

    u->target_step = u->step;
    cr_view o;
    int moved = try_step(c, u, wx, wy, &o);
    if (moved == 1) {
        u->orbit = 0; u->blocked_id = 0; u->mutual = 0;
    } else if (moved == 0) {
        if (!slide_on_wall(c, u, wx, wy, reach)) { replan(c, u, 0); return; }
    } else {
        u->blocked_id = o.id;
        if (!o.moving && o.arrived && o.group == u->group) {
            u->settle++;
            int inside = to_goal <= u->group->packed + u->radius;
            int patience = inside ? SETTLE_TICKS : SETTLE_FAR_TICKS;
            if (u->settle >= patience) { stand(u, 0); return; }
            if (!slide(c, u, &o, wx, wy, reach)) {
                if (inside) stand(u, 0); else u->orbit = -u->orbit;
                return;
            }
            if (u->no_progress == 0) u->settle = 0;
            return;
        }
        if (!o.moving && to_goal < u->radius + 2 * o.radius + GAP) { stand(u, 0); return; }
        if (!o.moving) nudge(c, &o, u, wx, wy);
        if (o.moving && o.blocked_id == u->id) {
            u->mutual++;
            if (u->mutual >= GIVE_WAY_TICKS && u->id > o.id) {
                u->mutual = 0;
                if (!step_aside(c, u, &o)) u->wait_until = t + GIVE_WAY_FOR;
                return;
            }
        }
        int slid = slide(c, u, &o, wx, wy, reach);
        u->slide_since_progress++;
        if (u->slide_since_progress >= BUNDLE_TICKS && u->bundle_until <= t) {
            bundle_of(c, u, &o);
            u->bundle_until = t + BUNDLE_KEEP;
            u->slide_since_progress = 0;
            u->orbit = 0;
            u->planned = 0;
            replan(c, u, 1);
        }
        if (!slid) return;
    }
}
/* }}} */

/* {{{ static int settle(cr_crowd *c, cr_unit *u, double dt, int last_try) */
static int settle(cr_crowd *c, cr_unit *u, double dt, int last_try)
{
    int moved = 0;
    const double fs[2] = { 1, 0.5 };
    for (int k = 0; k < 2; k++) {
        double f = fs[k];
        double nx = u->x + u->step_x * f, ny = u->y + u->step_y * f;
        cr_view b;
        if (clear_of_walls(c, nx, ny, u->radius) && !overlapping(c, u, nx, ny, &b)) {
            u->x = nx; u->y = ny;
            rebucket(c, u);
            u->vx = u->step_x * f / dt; u->vy = u->step_y * f / dt;
            u->facing = atan2(u->vy, u->vx);
            moved = 1;
            break;
        }
    }
    if (!moved && !last_try) return 0;
    u->proposed = 0;
    if (moved && u->has_path && u->target_step >= 1 && u->target_step <= u->path_len) {
        cr_point target = u->path[u->target_step - 1];
        if (fabs(u->x - target.x) < ARRIVE && fabs(u->y - target.y) < ARRIVE) {
            u->step = u->target_step + 1;
            if (u->step > u->path_len) {
                if (u->backing) {
                    u->backing = 0;
                    u->has_path = 0; u->path_len = 0; u->planned = 0;
                } else if (!u->exact) {
                    u->has_path = 0; u->path_len = 0;
                } else {
                    stand(u, 0);
                    if (u->has_before_nudge) {
                        u->arrived = u->bn_arrived; u->gave_up = u->bn_gave_up;
                        u->goal_x = u->bn_goal_x; u->goal_y = u->bn_goal_y;
                        u->has_before_nudge = 0;
                    }
                }
            }
        }
    }
    return 1;
}
/* }}} */

/* {{{ static void do_requests(cr_crowd *c, cr_unit *u) */
static void do_requests(cr_crowd *c, cr_unit *u)
{
    for (int i = 0; i < u->nrequests; i++) {
        cr_request *r = &u->requests[i];
        cr_unit *o = &c->units[r->target - 1];
        if (r->kind == 1) {
            if (!o->moving && c->tick_count - o->nudged_at >= NUDGE_EVERY) {
                o->has_before_nudge = 1;
                o->bn_arrived = o->arrived; o->bn_gave_up = o->gave_up;
                o->bn_goal_x = o->goal_x; o->bn_goal_y = o->goal_y;
                o->nudged_at = c->tick_count;
                o->closest = INFINITY; o->no_progress = 0;
                o->goal_x = r->x; o->goal_y = r->y;
                cr_point p = { r->x, r->y };
                set_path(o, &p, 1);
                o->step = 1; o->exact = 1; o->moving = 1; o->path_changed = 1;
            }
        } else if (o->moving && !o->backing && o->back_offs < BACK_OFFS) {
            back_off(c, o);
        }
    }
    u->nrequests = 0;
    u->decided = 0;
}
/* }}} */

/* {{{ void cr_tick_begin(cr_crowd *c) */
/* The tick's snapshot, and its buckets, in id order. */
void cr_tick_begin(cr_crowd *c)
{
    c->tick_count++;
    size_buckets(c);
    for (int i = 0; i < c->bw * c->bh; i++) c->snapped[i].n = 0;
    for (int i = 0; i < c->n; i++) {
        cr_unit *u = &c->units[i];
        c->snap[i] = (cr_record){ u->id, u->team, u->moving, u->arrived, u->blocked_id, u->backing, u->back_offs,
                                  u->x, u->y, u->radius, u->path_radius, u->goal_x, u->goal_y, u->speed,
                                  u->group, u->nudged_at, u->no_progress };
        bucket_add(&c->snapped[key_of(c, u->x, u->y)], i);
    }
    c->deciding = 1;
}
/* }}} */

/* {{{ void cr_tick_end(cr_crowd *c, double dt) */
void cr_tick_end(cr_crowd *c, double dt)
{
    c->deciding = 0;
    rehash(c);
    for (int i = 0; i < c->n; i++) {
        cr_unit *u = &c->units[i];
        if (u->proposed) settle(c, u, dt, 0);
        if (u->decided) do_requests(c, u);
    }
    for (int i = 0; i < c->n; i++) {
        cr_unit *u = &c->units[i];
        if (u->proposed) settle(c, u, dt, 1);
    }
}
/* }}} */

/* {{{ void cr_tick(cr_crowd *c, double dt) */
void cr_tick(cr_crowd *c, double dt)
{
    cr_tick_begin(c);
    for (int i = 0; i < c->n; i++) cr_decide(c, i, dt);
    cr_tick_end(c, dt);
}
/* }}} */
/* }}} */

/* {{{ The crowd */
/* {{{ cr_crowd *cr_new(int w, int h, const unsigned char *walkable, double cell) */
cr_crowd *cr_new(int w, int h, const unsigned char *walkable_cells, double cell)
{
    cr_crowd *c = calloc(1, sizeof *c);
    if (!c) return NULL;
    c->w = w; c->h = h; c->cell = cell;
    c->walk = malloc((size_t)w * h);
    c->clearance = malloc((size_t)w * h * sizeof(double));
    if (!c->walk || !c->clearance) { fprintf(stderr, "crowd: out of memory\n"); exit(71); }
    memcpy(c->walk, walkable_cells, (size_t)w * h);
    c->bucket_size = 1;
    c->look_ahead = 0;
    measure_clearance(c);
    return c;
}
/* }}} */

/* {{{ void cr_add(cr_crowd *c, double x, double y, double radius, double speed, int team) */
void cr_add(cr_crowd *c, double x, double y, double radius, double speed, int team)
{
    c->units = grow(c->units, &c->cap, c->n + 1, sizeof(cr_unit));
    c->snap = realloc(c->snap, (size_t)c->cap * sizeof(cr_record));
    cr_unit *u = &c->units[c->n];
    memset(u, 0, sizeof *u);
    u->id = c->n + 1;
    u->x = x; u->y = y; u->radius = radius; u->speed = speed; u->team = team;
    u->path_radius = radius + PATHING_EXTRA;
    u->goal_x = x; u->goal_y = y; u->exact = 1;
    u->closest = INFINITY;
    u->nudged_at = NEVER;
    c->n++;
    if (radius > c->largest) {
        c->largest = radius;
        c->bucket_size = 2 * radius + BUNDLE_GAP;
    }
}
/* }}} */

/* {{{ void cr_move_group(cr_crowd *c, const int *ids, int n, double x, double y) */
void cr_move_group(cr_crowd *c, const int *ids, int n, double x, double y)
{
    cr_group *g = malloc(sizeof *g);
    c->groups = grow(c->groups, &c->groups_cap, c->ngroups + 1, sizeof(cr_group *));
    c->groups[c->ngroups++] = g;
    g->x = x; g->y = y;
    double area = 0;
    for (int k = 0; k < n; k++) {
        cr_unit *u = &c->units[ids[k] - 1];
        area = area + (u->radius + GAP) * (u->radius + GAP);
        u->moving = 1; u->gave_up = 0; u->arrived = 0; u->group = g;
        u->closest = INFINITY; u->no_progress = 0; u->orbit = 0; u->wait_until = 0;
        u->has_bundle = 0; u->bundle_len = 0; u->bundle_until = 0;
        u->slide_since_progress = 0; u->mutual = 0; u->blocked_id = 0; u->settle = 0;
        u->backing = 0; u->back_offs = 0; u->has_before_nudge = 0;
    }
    g->packed = sqrt(area / PACKING);
    rehash(c);
    for (int k = 0; k < n; k++) head_for(c, &c->units[ids[k] - 1], x, y, NULL, 0);
}
/* }}} */

/* {{{ void cr_free(cr_crowd *c) */
void cr_free(cr_crowd *c)
{
    for (int i = 0; i < c->n; i++) { free(c->units[i].path); free(c->units[i].bundle); }
    for (int i = 0; i < c->ngroups; i++) free(c->groups[i]);
    for (int i = 0; c->live && i < c->bw * c->bh; i++) { free(c->live[i].items); free(c->snapped[i].items); }
    free(c->live); free(c->snapped); free(c->groups);
    free(c->units); free(c->snap); free(c->walk); free(c->clearance);
    free(c);
}
/* }}} */

int cr_count(const cr_crowd *c) { return c->n; }
cr_unit *cr_units(cr_crowd *c) { return c->units; }
long cr_tick_count(const cr_crowd *c) { return c->tick_count; }
double cr_look_ahead(const cr_crowd *c) { return c->look_ahead; }
void cr_set_look_ahead(cr_crowd *c, double ahead) { c->look_ahead = ahead; }

/* {{{ int cr_any_overlap(const cr_crowd *c, int *a, int *b) */
int cr_any_overlap(const cr_crowd *c, int *a, int *b)
{
    for (int i = 0; i < c->n; i++)
        for (int j = i + 1; j < c->n; j++) {
            const cr_unit *p = &c->units[i], *q = &c->units[j];
            double reach = p->radius + q->radius;
            double dx = p->x - q->x, dy = p->y - q->y;
            if (dx * dx + dy * dy < reach * reach - 1e-6) { *a = p->id; *b = q->id; return 1; }
        }
    return 0;
}
/* }}} */
/* }}} */
