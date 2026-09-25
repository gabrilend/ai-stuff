/*
 * pose-boxes.c - the pose math, as ceramic boxes (issue 515a)
 *
 * What this is: the work the copy-cost benchmark measures, written once and
 * used by all four ways of running it. A unit's pose is 30 bone matrices
 * (4x4 floats, 1920 bytes); each bone turns by an angle that depends on the
 * time, the bone and the unit, and is composed onto its parent, down the
 * chain from the root. That is roughly the work a real skeleton does per
 * frame (a rotation and a matrix product per bone), so the per-task cost
 * of the engine is measured against realistic work rather than an empty box.
 *
 * Boxes (non-static functions) take their arguments by value and return one
 * value, and keep nothing between calls: the engine's rule. The static
 * helpers are private to this file and invisible to maps.
 */
#include <math.h>

#define POSE_BONES 30
#define CHUNK_UNITS 64

/* The value types -- mat4 (16 floats), pose (30 mat4) and chunk_pose (64
 * poses) -- are written by pose-types.lua and spliced in here by the build,
 * because the engine's value types can't hold number arrays (only char
 * arrays, as text), so each element is its own named field. The math below
 * addresses them as arrays: a struct whose fields all share one type has no
 * padding between them, so the fields sit exactly where array elements
 * would. */
/* @@POSE-TYPES@@ */

/* What the host asks for one unit: which unit, at what time. */
typedef struct {
    int   unit;
    float time;
} pose_request;

/* What the host asks for a chunk: CHUNK_UNITS units from `first`. */
typedef struct {
    int   first;
    float time;
} chunk_request;

/* {{{ static void bone_local(float angle, float length, float *out) */
/* A bone's own transform: a turn about z by `angle`, then a step of
 * `length` along the turned x axis (the bone's length). */
static void bone_local(float angle, float length, float *out)
{
    float c = cosf(angle), s = sinf(angle);
    for (int i = 0; i < 16; i++) out[i] = 0.0f;
    out[0] = c;  out[1] = s;
    out[4] = -s; out[5] = c;
    out[10] = 1.0f;
    out[12] = c * length; out[13] = s * length;
    out[15] = 1.0f;
}
/* }}} */

/* {{{ static void mat4_mul(const float *a, const float *b, float *out) */
/* out = a x b (column-major). */
static void mat4_mul(const float *a, const float *b, float *out)
{
    for (int col = 0; col < 4; col++)
        for (int row = 0; row < 4; row++) {
            float sum = 0.0f;
            for (int k = 0; k < 4; k++) sum += a[k * 4 + row] * b[col * 4 + k];
            out[col * 4 + row] = sum;
        }
}
/* }}} */

/* {{{ static void pose_into(int unit, float time, pose *out) */
/* The one pose function all four ways share. Bone 0 hangs from the
 * origin; each later bone is its parent's matrix times its own turn. */
static void pose_into(int unit, float time, pose *out)
{
    float local[16];
    float *bone = (float *)out;   /* 30 matrices of 16 floats, back to back */
    for (int b = 0; b < POSE_BONES; b++) {
        float angle = 0.3f * sinf(time * 2.0f + (float)b * 0.37f + (float)unit * 0.011f);
        bone_local(angle, 10.0f, local);
        if (b == 0) {
            for (int i = 0; i < 16; i++) bone[i] = local[i];
        } else {
            mat4_mul(bone + (b - 1) * 16, local, bone + b * 16);
        }
    }
}
/* }}} */

/* {{{ pose pose_unit(pose_request r) */
/* A task per unit: one unit's pose. */
pose pose_unit(pose_request r)
{
    pose p;
    pose_into(r.unit, r.time, &p);
    return p;
}
/* }}} */

/* {{{ chunk_pose pose_chunk(chunk_request r) */
/* A task per chunk: CHUNK_UNITS units' poses in one value. */
chunk_pose pose_chunk(chunk_request r)
{
    chunk_pose c;
    pose *each = (pose *)&c;      /* 64 poses, back to back */
    for (int u = 0; u < CHUNK_UNITS; u++) pose_into(r.first + u, r.time, &each[u]);
    return c;
}
/* }}} */
