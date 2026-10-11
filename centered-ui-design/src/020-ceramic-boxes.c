/*
 * 020-ceramic-boxes.c - the world's work, as ceramic boxes, and the door Lua knocks on.
 *
 * In plain terms: every step of the world is done here, in C, by the
 * ceramic engine's workers (soramech's engine, libs/ceramic). Two boxes do
 * the work, each on a chunk of the world at a time:
 *
 *   unit_chunk    each unit in the chunk decides what to do (wander, fetch
 *                 a cuboid, carry it to its color's section) and moves —
 *                 reading last step's world, writing only its own record
 *   cuboid_chunk  each cuboid in the chunk settles its own fate (who claims
 *                 it, who carries it, where it rests) — reading the units'
 *                 new records, writing only its own record
 *
 * Because every chunk writes only its own records, the chunks may run on
 * any worker in any order, and the result is always the same.
 *
 * The world itself is too big to travel as a value, so (as in the crowd
 * study, world-edit-to-execute issue 515k) it travels by pointer: the host
 * (the LÖVE render thread, through the ceramics_* functions at the bottom)
 * sets where the blocks are before handing a stage in, and nothing changes
 * those pointers while the stage runs.
 *
 * The motion part (ceramics_move_reference and move_unit) is the twin of
 * src/006-the-move-box.lua; a test checks they agree.
 */
#include <math.h>
#include <stdint.h>

/* One unit: 16 floats, 64 bytes, read unchanged by the graphics card as
 * four groups of four. Must match src/005-unit-records.lua exactly. */
typedef struct {
    float r;
    float angle;
    float heading;
    float length;
    float width;
    float owner;
    float level;
    float phase;
    float speed_r;
    float speed_angle;
    float order_kind;
    float named;
    float job;
    float target;
    float wants;
    float carrying;
} unit_record;

/* One cuboid: 12 floats, 48 bytes. Must match src/005-unit-records.lua. */
typedef struct {
    float r;
    float angle;
    float height;
    float size;
    float color;
    float state;
    float claimant;
    float carrier;
    float timer;
    float slot;
    float appearances;
    float turn;
} cuboid_record;

/* A chunk of work: which chunk, and records first .. last-1. */
typedef struct {
    int chunk;
    int first;
    int last;
} chunk_req;

/* The answer: which chunk, and how many records it did. */
typedef struct {
    int chunk;
    int count;
} chunk_done;

/* What a unit is doing (unit_record.job). */
#define JOB_IDLE 0
#define JOB_FETCHING 1
#define JOB_CARRYING 2
/* What a unit asks of its target cuboid this step (unit_record.wants). */
#define WANTS_NOTHING 0
#define WANTS_PICK_UP 1
#define WANTS_DROP 2
/* Where a cuboid is (cuboid_record.state). */
#define CUBE_LYING 0
#define CUBE_CARRIED 1
#define CUBE_DELIVERED 2
/* Owner number of a foe (foes do not haul). */
#define FOE 4

#define TWO_PI 6.283185307179586
#define HALF_TURN 3.141592653589793
#define MAX_SECTIONS 8

/* {{{ the world, by pointer (set by the host before each stage) */
unit_record *ceramics_units_front;
unit_record *ceramics_units_back;
cuboid_record *ceramics_cubes_front;
cuboid_record *ceramics_cubes_back;
int ceramics_unit_count;
int ceramics_cube_count;
double ceramics_step_seconds;
uint32_t ceramics_seed;

/* the sphere fold (src/004-the-sphere-fold.lua) */
double fold_strength, fold_tiers, fold_hub, fold_edge;
/* how tall a figure of size 1 is drawn at tier 1 (UNIT_WORLD_SCALE in 013) */
double figure_scale;
/* the size law: 0 things far out shrink as their tier is squeezed (the flat
 * and hub views); 1 they keep their full size (the slant view, where the
 * owner asked that the far stuff "remains the same size relative to the
 * part near the dashboard"). Set between steps only (022/023). */
double fold_size_keep;
/* the foes' pole, in tiers from ours: the world is a sphere with our hub at
 * one pole (see side_radius) */
double fold_far_pole;

/* the color-coded sections: where each color's cuboids are taken */
int section_count;
double section_r[MAX_SECTIONS], section_angle[MAX_SECTIONS], section_radius[MAX_SECTIONS];
/* }}} */

/* Tuning knobs (record changes in docs/balance-updates.md). */
#define INNER_LIMIT 0.75             /* units turn back this near the hub (tiers) */
#define STRIDE_WORLD_UNITS 2.4       /* ground per walking cycle at tier 1 */
#define IDLE_CYCLES_PER_SECOND 0.25  /* a standing unit's sway */
#define WALK_TIERS_PER_SECOND 0.12   /* a hauler's pace on the sphere */
#define REACH_TIERS 0.106            /* how close (on the sphere) a hauler must be to pick up */
#define RESTING_SECONDS 12.0         /* how long a delivered cuboid stays before reappearing */

/* {{{ static double fold_radius(double r) */
/* Tier distance -> ground radius. Twin of M.radius in 004. */
static double fold_radius(double r)
{
    double fraction;
    if (fold_strength < 1e-6) {
        /* no fold: a straight line */
        fraction = r / fold_tiers;
    } else {
        /* folded: logarithmic */
        fraction = log(1.0 + fold_strength * r) / log(1.0 + fold_strength * fold_tiers);
    }
    return fold_hub + fraction * (fold_edge - fold_hub);
}
/* }}} */

/* {{{ static double fold_tier_distance(double radius) */
/* Ground radius -> tier distance; the exact inverse of fold_radius. */
static double fold_tier_distance(double radius)
{
    double fraction = (radius - fold_hub) / (fold_edge - fold_hub);
    if (fold_strength < 1e-6) {
        /* no fold */
        return fraction * fold_tiers;
    }
    /* folded */
    return (exp(fraction * log(1.0 + fold_strength * fold_tiers)) - 1.0) / fold_strength;
}
/* }}} */

/* {{{ static double fold_slope(double r) */
/* Ground units per tier at r. Twin of M.slope in 004. */
static double fold_slope(double r)
{
    double span = fold_edge - fold_hub;
    if (fold_strength < 1e-6) {
        /* no fold: constant */
        return span / fold_tiers;
    }
    /* folded */
    return span * fold_strength / ((1.0 + fold_strength * r) * log(1.0 + fold_strength * fold_tiers));
}
/* }}} */

/* {{{ static double fold_size_scale(double r) */
static double fold_size_scale(double r)
{
    /* the slant view: everything full size */
    if (fold_size_keep > 0.5) {
        return 1.0;
    }
    /* the other views: shrunk as the tier is squeezed */
    return (1.0 + fold_strength) / (1.0 + fold_strength * r);
}
/* }}} */

/* {{{ static double side_radius(double r) */
/* The radius, on the sphere, of the lap around the hub at tier distance r
 * (tiers): (P / pi) sin(pi r / P), our hub one pole and the foes' P tiers
 * out. Twin of M.side_radius in 004. */
static double side_radius(double r)
{
    return fold_far_pole / HALF_TURN * sin(HALF_TURN * r / fold_far_pole);
}
/* }}} */

/* {{{ double ceramics_side_radius(double r) */
/* side_radius, for the tests to compare with its Lua twin. */
double ceramics_side_radius(double r)
{
    return side_radius(r);
}
/* }}} */

/* {{{ static void ground_xz(double r, double angle, double *x, double *z) */
/* A place (tier, angle) -> ground x, z. Angle 0 is north (-z), clockwise. */
static void ground_xz(double r, double angle, double *x, double *z)
{
    double radius = fold_radius(r);
    *x = radius * sin(angle);
    *z = -radius * cos(angle);
}
/* }}} */

/* {{{ static void place_from_xz(double x, double z, float *r, float *angle) */
/* Ground x, z -> a place (tier, angle). */
static void place_from_xz(double x, double z, float *r, float *angle)
{
    double radius = sqrt(x * x + z * z);
    double a = atan2(x, -z);
    if (a < 0) a += TWO_PI;
    *r = (float)fold_tier_distance(radius);
    *angle = (float)a;
}
/* }}} */

/* {{{ static void move_unit(const unit_record *source, unit_record *unit, double dt) */
/* Moves one unit by its speeds for dt seconds, bouncing off the inner and
 * outer limits, wrapping its angle, facing where it goes, and turning its
 * walking phase by the ground it covered. The twin of move_unit in
 * src/006-the-move-box.lua, line for line. `unit` already holds a copy. */
static void move_unit(const unit_record *source, unit_record *unit, double dt)
{
    double outer_limit = fold_tiers - 0.3;
    double r = source->r + source->speed_r * dt;
    double speed_r = source->speed_r;
    if (r < INNER_LIMIT) {
        /* walked in past the inner wall: reflect outward */
        r = INNER_LIMIT + (INNER_LIMIT - r);
        speed_r = -speed_r;
    } else if (r > outer_limit) {
        /* walked out past the outer wall: reflect inward */
        r = outer_limit - (r - outer_limit);
        speed_r = -speed_r;
    }
    unit->r = (float)r;
    unit->speed_r = (float)speed_r;

    double angle = fmod(source->angle + source->speed_angle * dt, TWO_PI);
    if (angle < 0) angle += TWO_PI;
    unit->angle = (float)angle;

    double slope = fold_slope(r);
    double radius = fold_radius(r);
    double outward = slope * speed_r;
    double sideways = radius * source->speed_angle;

    double ground_speed = sqrt(outward * outward + sideways * sideways);
    double stride = STRIDE_WORLD_UNITS * fold_size_scale(r);
    double cycles = IDLE_CYCLES_PER_SECOND + ground_speed / stride;
    unit->phase = (float)fmod(source->phase + TWO_PI * cycles * dt, TWO_PI);

    if (fabs(outward) + fabs(sideways) < 1e-6) {
        /* standing still: keep facing the way it was */
        unit->heading = source->heading;
    } else {
        /* moving: face along the ground direction of travel */
        double dx = outward * sin(angle) + sideways * cos(angle);
        double dz = -outward * cos(angle) + sideways * sin(angle);
        unit->heading = (float)atan2(dx, -dz);
    }
}
/* }}} */

/* {{{ static double steer_toward(unit_record *u, double tr, double ta) */
/* Points a unit's speeds at a place (tier distance, angle) at a steady pace
 * measured on the sphere, not on the folded map: outward in tiers, sideways
 * along the lap (side_radius x angle). So the walk is the same under every
 * view, and on the map a walker far out goes left-right fast (its lap is
 * short on the sphere but drawn wide) and in-out densely (the fold squeezes
 * the outer tiers). Steering by the local split is greedy, which is enough
 * for the short walks of hauling. Returns the sphere distance left (tiers). */
static double steer_toward(unit_record *u, double tr, double ta)
{
    double side = side_radius(u->r);
    double turn = fmod(ta - u->angle, TWO_PI);
    /* the short way round */
    if (turn > HALF_TURN) turn -= TWO_PI;
    if (turn < -HALF_TURN) turn += TWO_PI;
    double outward = tr - u->r;
    double sideways = side * turn;
    double distance = sqrt(outward * outward + sideways * sideways);
    if (distance < 1e-9) {
        /* already there */
        u->speed_r = 0;
        u->speed_angle = 0;
        return 0;
    }
    u->speed_r = (float)(outward / distance * WALK_TIERS_PER_SECOND);
    u->speed_angle = (float)(sideways / distance * WALK_TIERS_PER_SECOND / side);
    return distance;
}
/* }}} */

/* {{{ static void stop(unit_record *u) */
static void stop(unit_record *u)
{
    u->speed_r = 0;
    u->speed_angle = 0;
}
/* }}} */

/* {{{ static void forget_hauling(unit_record *u) */
static void forget_hauling(unit_record *u)
{
    u->job = JOB_IDLE;
    u->target = -1;
    u->wants = WANTS_NOTHING;
    u->carrying = 0;
}
/* }}} */

/* {{{ static int nearest_free_cuboid(const unit_record *u, int me) */
/* The nearest lying cuboid that nobody but this unit has claimed, or -1. */
static int nearest_free_cuboid(const unit_record *u, int me)
{
    double x, z;
    ground_xz(u->r, u->angle, &x, &z);
    int best = -1;
    double best_distance = 1e300;
    for (int k = 0; k < ceramics_cube_count; k++) {
        const cuboid_record *c = &ceramics_cubes_front[k];
        if (c->state != CUBE_LYING) continue;                     /* not lying about */
        if (c->claimant >= 0 && (int)c->claimant != me) continue;  /* someone else's */
        double cx, cz;
        ground_xz(c->r, c->angle, &cx, &cz);
        double d = (cx - x) * (cx - x) + (cz - z) * (cz - z);
        if (d < best_distance) {
            best_distance = d;
            best = k;
        }
    }
    return best;
}
/* }}} */

/* {{{ static void think(unit_record *u, int me) */
/* A unit decides its speeds and its asks for this step, from last step's
 * world. Writes only into `u` (the unit's own new record). */
static void think(unit_record *u, int me)
{
    u->wants = WANTS_NOTHING;
    if ((int)u->owner == FOE || u->order_kind != 0) {
        /* foes never haul; a unit given an order follows the order */
        forget_hauling(u);
        return;
    }
    int job = (int)u->job;
    if (job == JOB_IDLE) {
        /* idle: look for the nearest free cuboid; none: keep wandering */
        int k = nearest_free_cuboid(u, me);
        if (k < 0) return;
        u->job = JOB_FETCHING;
        u->target = (float)k;
        job = JOB_FETCHING;
    }
    const cuboid_record *c = &ceramics_cubes_front[(int)u->target];
    if (job == JOB_FETCHING) {
        if (c->state == CUBE_CARRIED && (int)c->carrier == me) {
            /* it took to us last step: now we carry it */
            u->job = JOB_CARRYING;
            u->carrying = c->color + 1;
            job = JOB_CARRYING;
        } else if (c->state != CUBE_LYING || (c->claimant >= 0 && (int)c->claimant != me)) {
            /* it went to someone else, or away: give up, look again next step */
            forget_hauling(u);
            return;
        } else {
            /* walk to it; close enough: stand and ask to pick it up */
            if (steer_toward(u, c->r, c->angle) < REACH_TIERS) {
                stop(u);
                u->wants = WANTS_PICK_UP;
            }
            return;
        }
    }
    /* carrying */
    if (c->state == CUBE_DELIVERED) {
        /* it has been set down in its section: free again */
        forget_hauling(u);
        stop(u);
        return;
    }
    int s = (int)c->color % section_count;
    /* within six tenths of the section's radius (tiers) counts as inside */
    if (steer_toward(u, section_r[s], section_angle[s]) < section_radius[s] * 0.6) {
        /* inside its section: stand and ask to set it down */
        stop(u);
        u->wants = WANTS_DROP;
    }
}
/* }}} */

/* {{{ chunk_done unit_chunk(chunk_req q) */
/* The unit box: every unit in the chunk thinks, then moves. */
chunk_done unit_chunk(chunk_req q)
{
    for (int i = q.first; i < q.last; i++) {
        unit_record u = ceramics_units_front[i];
        think(&u, i);
        unit_record moved = u;
        move_unit(&u, &moved, ceramics_step_seconds);
        ceramics_units_back[i] = moved;
    }
    chunk_done d = { q.chunk, q.last - q.first };
    return d;
}
/* }}} */

/* {{{ static double hashed_fraction(uint32_t a, uint32_t b, uint32_t c) */
/* A fraction in [0, 1) from three whole numbers, the same on every machine. */
static double hashed_fraction(uint32_t a, uint32_t b, uint32_t c)
{
    uint32_t x = a * 0x9E3779B1u ^ (b + 0x7F4A7C15u) * 0x85EBCA77u ^ (c + 0x165667B1u) * 0xC2B2AE3Du;
    x ^= x >> 15; x *= 0x2C1B3C6Du; x ^= x >> 12; x *= 0x297A2D39u; x ^= x >> 15;
    return x / 4294967296.0;
}
/* }}} */

/* {{{ static int stack_slot(int k, int color) */
/* Where a delivered cuboid sits in its section's stack: its rank among the
 * delivered cuboids of its color, by number. */
static int stack_slot(int k, int color)
{
    int slot = 0;
    for (int j = 0; j < k; j++) {
        const cuboid_record *o = &ceramics_cubes_front[j];
        if (o->state == CUBE_DELIVERED && (int)o->color == color) slot++;
    }
    return slot;
}
/* }}} */

/* {{{ chunk_done cuboid_chunk(chunk_req q) */
/* The cuboid box: every cuboid in the chunk settles who has it and where
 * it is, from the units' new records. */
chunk_done cuboid_chunk(chunk_req q)
{
    for (int k = q.first; k < q.last; k++) {
        cuboid_record c = ceramics_cubes_front[k];
        int state = (int)c.state;
        if (state == CUBE_LYING) {
            /* claimed by the lowest-numbered unit fetching it */
            c.claimant = -1;
            for (int j = 0; j < ceramics_unit_count; j++) {
                const unit_record *u = &ceramics_units_back[j];
                if ((int)u->job == JOB_FETCHING && (int)u->target == k) {
                    c.claimant = (float)j;
                    break;
                }
            }
            if (c.claimant >= 0 && (int)ceramics_units_back[(int)c.claimant].wants == WANTS_PICK_UP) {
                /* the claimant asked to pick it up: it is carried */
                c.state = CUBE_CARRIED;
                c.carrier = c.claimant;
                state = CUBE_CARRIED;
            }
        }
        if (state == CUBE_CARRIED) {
            const unit_record *u = &ceramics_units_back[(int)c.carrier];
            double height = u->length * figure_scale * fold_size_scale(u->r);
            double ux, uz;
            ground_xz(u->r, u->angle, &ux, &uz);
            if ((int)u->wants == WANTS_DROP) {
                /* set down in its section */
                c.state = CUBE_DELIVERED;
                c.timer = 0;
                c.carrier = -1;
                c.claimant = -1;
                state = CUBE_DELIVERED;
            } else if ((int)u->job == JOB_IDLE) {
                /* the carrier was given an order and let go: it falls where it
                 * is. (Not "fetching": in the very step a cuboid is picked up,
                 * its carrier still says fetching — it only learns next step
                 * that it carries. Reading that as letting go dropped every
                 * cuboid the moment it was lifted.) */
                c.state = CUBE_LYING;
                c.carrier = -1;
                c.claimant = -1;
                c.r = u->r;
                c.angle = u->angle;
                c.height = 0;
            } else {
                /* held in front of the carrier's chest */
                double ahead = 0.3 * height;
                place_from_xz(ux + ahead * sin(u->heading), uz - ahead * cos(u->heading), &c.r, &c.angle);
                c.height = (float)(0.48 * height);
                c.turn = u->heading;
            }
        }
        if (state == CUBE_DELIVERED) {
            c.timer += (float)ceramics_step_seconds;
            if (c.timer > RESTING_SECONDS) {
                /* it has rested long enough: it appears somewhere new */
                c.appearances += 1;
                uint32_t n = (uint32_t)c.appearances;
                c.r = (float)(0.9 + (fold_tiers - 1.4) * hashed_fraction(ceramics_seed, (uint32_t)k, n * 2));
                c.angle = (float)(TWO_PI * hashed_fraction(ceramics_seed, (uint32_t)k, n * 2 + 1));
                c.height = 0;
                c.state = CUBE_LYING;
                c.timer = 0;
            } else {
                /* stacked in its section: nine to a layer, in a three by three grid */
                int s = (int)c.color % section_count;
                int slot = stack_slot(k, (int)c.color);
                double size = c.size * fold_size_scale(section_r[s]) * 1.15;
                double sx, sz;
                ground_xz(section_r[s], section_angle[s], &sx, &sz);
                int cell = slot % 9, layer = slot / 9;
                /* the cell's column and row (whole-number division on purpose) */
                int column = cell % 3, row = cell / 3;
                double across = (column - 1) * size;
                double along = (row - 1) * size;
                double a = section_angle[s];
                place_from_xz(sx + across * cos(a) + along * sin(a), sz + across * sin(a) - along * cos(a),
                              &c.r, &c.angle);
                c.height = (float)(layer * size);
                c.slot = (float)slot;
                c.turn = (float)a;
            }
        }
        if ((int)c.state == CUBE_LYING && c.height == 0) {
            /* lying cuboids face along their own angle */
            c.turn = c.angle;
        }
        ceramics_cubes_back[k] = c;
    }
    chunk_done d = { q.chunk, q.last - q.first };
    return d;
}
/* }}} */
