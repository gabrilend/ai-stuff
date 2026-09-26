/* ---- frame-boxes.c: the fabricated frame's boxes (issue 515h) ----
 *
 * Appended by run-frame.sh to pose-boxes.c (whose value types are spliced
 * in), so the pose lanes use the real pose math. Every box takes its
 * inputs by value and returns one value, keeps nothing between calls, and
 * does its stage's work from frame-plan.h; the hand-written programs
 * include this same file, so all three ways run these very functions.
 *
 * Every value carries its frame number, so the host can check that answers
 * belong to the frame it is waiting for.
 */
#include "frame-plan.h"

/* The frame's tick, handed in by the host. */
typedef struct {
    int frame;
    int seed;
} tick;

/* The simulation step's answer, fanned out to every fog and pose station. */
typedef struct {
    int          frame;
    unsigned int hash;
} sim_state;

/* A pose lane's request: which lane, which frame. */
typedef struct {
    int frame;
    int lane;
} lane_req;

/* A pose lane's answer, handed to that lane's culling. */
typedef struct {
    int          frame;
    int          lane;
    unsigned int hash;
} lane_out;

/* A pathfinding or decoding request: its number and its cost in rounds. */
typedef struct {
    int          frame;
    int          id;
    unsigned int rounds;
} job;

/* An answer the host collects. */
typedef struct {
    int          frame;
    int          id;
    unsigned int hash;
} done;

/* {{{ sim_state simulate(tick t) */
/* The simulation step: SIM_US of work from the frame's seed. */
sim_state simulate(tick t)
{
    sim_state s = { t.frame, churn((unsigned int)t.seed ^ (unsigned int)t.frame, us_rounds(SIM_US)) };
    return s;
}
/* }}} */

/* {{{ done fog(sim_state s, int player) */
/* Fog of war for one player (the player is a constant on a static port):
 * 400 to 1000 us, different every frame. */
done fog(sim_state s, int player)
{
    done d = { s.frame, player, churn(s.hash ^ (unsigned int)player, us_rounds(fog_us(s.frame, player))) };
    return d;
}
/* }}} */

/* {{{ lane_out pose_lane(lane_req r, sim_state s) */
/* One lane's poses: FRAME_UNITS_PER_LANE units of real skeleton math at
 * the frame's time, folded to one number with the simulation's. A join:
 * it runs when both the host's request and the simulation's answer are in. */
lane_out pose_lane(lane_req r, sim_state s)
{
    pose p;
    unsigned int x = s.hash;
    float t = (float)r.frame / 60.0f;
    for (int u = 0; u < FRAME_UNITS_PER_LANE; u++) {
        pose_into(r.lane * FRAME_UNITS_PER_LANE + u, t, &p);
        const unsigned int *w = (const unsigned int *)&p;
        for (unsigned long i = 0; i < sizeof(pose) / 4; i++) x ^= w[i];
    }
    lane_out o = { r.frame, r.lane, x };
    return o;
}
/* }}} */

/* {{{ done cull(lane_out l) */
/* Culling one lane's units: CULL_US, starting the moment that lane's poses land. */
done cull(lane_out l)
{
    done d = { l.frame, l.lane, churn(l.hash, us_rounds(CULL_US)) };
    return d;
}
/* }}} */

/* {{{ done pathfind(job j) */
/* One pathfinding request: its cost is in the request. */
done pathfind(job j)
{
    done d = { j.frame, j.id, churn((unsigned int)(j.frame * 4096 + j.id), j.rounds) };
    return d;
}
/* }}} */

/* {{{ done decode(job j) */
/* One background decode: DECODE_US, not needed by the frame that asked. */
done decode(job j)
{
    done d = { j.frame, j.id, churn((unsigned int)(j.frame * 16 + j.id) ^ 0xdec0u, j.rounds) };
    return d;
}
/* }}} */
