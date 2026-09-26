/*
 * units-boxes.c - the host loop's boxes: where every unit is this frame (issues 515b, 515c)
 *
 * What this is: the ceramic side of the first real render frame. The host
 * hands in a tick and one request per lane; `advance` turns the tick into
 * the frame's clock, fanned out to every lane; each lane's `move` joins the
 * clock with its request and works out its units' places and colours.
 * `unit_place` is the one function both the box and the host's --check call,
 * so the check compares the engine's answer with the same arithmetic done
 * directly.
 *
 * The units stand in for a map's units until models arrive: each one
 * circles the centre on its own ring at its own speed, bobbing, coloured by
 * its team.
 */
#include <math.h>

#define UNIT_LANES 8
#define UNITS_PER_LANE 256
#define UNIT_COUNT (UNIT_LANES * UNITS_PER_LANE)

/* One unit's record, true at the state's time (issue 515c): where it is,
 * how fast it is moving (units a second), which way it faces and how far
 * through its animation it is (radians), and its colour as 0xRRGGBBAA.
 * Velocity, facing and animation are what the draw thread extrapolates
 * "now" from (issue 515d). 36 bytes, every field 32-bit. */
typedef struct {
    float        x;
    float        y;
    float        z;
    float        vx;
    float        vy;
    float        vz;
    float        facing;
    float        anim;
    unsigned int color;
} unit;

/* @@UNITS-TYPES@@ */

/* The host's tick: which frame, and the clock in seconds. */
typedef struct {
    int   frame;
    float time;
} tick;

/* The frame's clock, fanned out to every lane. */
typedef struct {
    int   frame;
    float time;
} frame_clock;

/* A lane's request: which lane, which frame. */
typedef struct {
    int frame;
    int lane;
} lane_req;

/* {{{ static void unit_place(int id, float t, unit *out) */
/* Where unit `id` is at time `t`: ring by number, speed by number, a bob,
 * a team colour. Plain arithmetic, the same wherever it is called. The
 * velocity is the exact rate of change of the position, so a straight-line
 * guess from it drifts off the circle only slowly. */
static void unit_place(int id, float t, unit *out)
{
    static const unsigned int teams[4] = { 0xd9483bffu, 0x3b7fd9ffu, 0x3bb56aff, 0xe0b23bffu };
    float ring = 4.0f + (float)(id % 48) * 0.55f;
    float speed = 0.15f + 0.04f * (float)(id % 7);     /* radians a second */
    float angle = t * speed + (float)id * 2.39996f;    /* the golden angle spreads them out */
    float bob = t * 2.0f + (float)id;
    out->x = cosf(angle) * ring;
    out->z = sinf(angle) * ring;
    out->y = 0.35f + 0.25f * sinf(bob);
    out->vx = -sinf(angle) * ring * speed;
    out->vz = cosf(angle) * ring * speed;
    out->vy = 0.5f * cosf(bob);
    out->facing = angle + 1.5707963f;                  /* along the circle, the way it moves */
    out->anim = fmodf(bob, 6.2831853f);
    out->color = teams[id % 4];
}
/* }}} */

/* {{{ frame_clock advance(tick t) */
/* The frame's clock, from the host's tick. */
frame_clock advance(tick t)
{
    frame_clock c = { t.frame, t.time };
    return c;
}
/* }}} */

/* {{{ lane_units move(lane_req r, frame_clock c) */
/* One lane's units, at the frame's clock. A join: it runs when both the
 * host's request and the clock are in. */
lane_units move(lane_req r, frame_clock c)
{
    lane_units out;
    unit *each = (unit *)&out;
    for (int i = 0; i < UNITS_PER_LANE; i++) unit_place(r.lane * UNITS_PER_LANE + i, c.time, &each[i]);
    return out;
}
/* }}} */
