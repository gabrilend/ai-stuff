/*
 * camera.c - the game camera as numbers (issue 501d)
 *
 * See camera.h. WC3's axes: x east, y north, z up.
 */

#include <math.h>
#include "camera.h"

#define CAMERA_PI 3.14159265358979323846

/* {{{ camera_init */
void camera_init(GameCamera* cam, float x, float y, float z) {
    cam->x = x;
    cam->y = y;
    cam->z = z;
    cam->distance = CAMERA_DEFAULT_DISTANCE;
    cam->rotation = CAMERA_DEFAULT_ROTATION;
    cam->aoa = CAMERA_DEFAULT_AOA;
    cam->fov = CAMERA_DEFAULT_FOV;
    cam->farz = CAMERA_DEFAULT_FARZ;
    cam->min_distance = CAMERA_MIN_DISTANCE;
    cam->max_distance = CAMERA_MAX_DISTANCE;
    cam->bounds = (CameraBounds){ 0.0f, 0.0f, 0.0f, 0.0f };
    cam->has_bounds = false;
}
/* }}} */

/* {{{ camera_clamp */
void camera_clamp(GameCamera* cam) {
    if (cam->has_bounds) {
        if (cam->x < cam->bounds.min_x) cam->x = cam->bounds.min_x;
        if (cam->x > cam->bounds.max_x) cam->x = cam->bounds.max_x;
        if (cam->y < cam->bounds.min_y) cam->y = cam->bounds.min_y;
        if (cam->y > cam->bounds.max_y) cam->y = cam->bounds.max_y;
    }
    if (cam->distance < cam->min_distance) cam->distance = cam->min_distance;
    if (cam->distance > cam->max_distance) cam->distance = cam->max_distance;
}
/* }}} */

/* {{{ camera_bounds_from_w3i */
void camera_bounds_from_w3i(GameCamera* cam, const float corners[8]) {
    CameraBounds b = { corners[0], corners[1], corners[0], corners[1] };
    for (int i = 1; i < 4; i++) {
        float x = corners[i * 2], y = corners[i * 2 + 1];
        if (x < b.min_x) b.min_x = x;
        if (x > b.max_x) b.max_x = x;
        if (y < b.min_y) b.min_y = y;
        if (y > b.max_y) b.max_y = y;
    }
    cam->bounds = b;
    cam->has_bounds = true;
    camera_clamp(cam);
}
/* }}} */

/* {{{ camera_look_at */
void camera_look_at(GameCamera* cam, float x, float y) {
    cam->x = x;
    cam->y = y;
    camera_clamp(cam);
}
/* }}} */

/* {{{ camera_frame */
void camera_frame(const GameCamera* cam, float width, float height, CameraFrame* out) {
    double rot = cam->rotation * CAMERA_PI / 180.0;
    double down = (360.0 - cam->aoa) * CAMERA_PI / 180.0;   /* below level */
    double cr = cos(rot), sr = sin(rot), cd = cos(down), sd = sin(down);

    out->forward[0] = (float)(cd * cr);
    out->forward[1] = (float)(cd * sr);
    out->forward[2] = (float)(-sd);
    /* the screen's right: level, a quarter turn clockwise from the heading */
    out->right[0] = (float)sr;
    out->right[1] = (float)(-cr);
    out->right[2] = 0.0f;
    /* the screen's up: right x forward */
    out->up[0] = (float)(sd * cr);
    out->up[1] = (float)(sd * sr);
    out->up[2] = (float)cd;

    out->eye[0] = cam->x - out->forward[0] * cam->distance;
    out->eye[1] = cam->y - out->forward[1] * cam->distance;
    out->eye[2] = cam->z - out->forward[2] * cam->distance;

    out->width = width;
    out->height = height;
    out->tan_y = (float)tan(cam->fov * CAMERA_PI / 360.0);
    out->tan_x = height > 0.0f ? out->tan_y * width / height : out->tan_y;
}
/* }}} */

/* {{{ ray_of: the direction through screen point (sx, sy), scaled so that
 * one step along it is one unit of depth along the view */
static void ray_of(const CameraFrame* f, float sx, float sy, double d[3]) {
    double nx = (2.0 * sx / f->width - 1.0) * f->tan_x;
    double ny = (1.0 - 2.0 * sy / f->height) * f->tan_y;
    for (int i = 0; i < 3; i++) d[i] = f->forward[i] + f->right[i] * nx + f->up[i] * ny;
}
/* }}} */

/* {{{ camera_screen_to_ground */
bool camera_screen_to_ground(const CameraFrame* f, float sx, float sy, float ground_z,
                             float* x, float* y) {
    double d[3];
    ray_of(f, sx, sy, d);
    if (d[2] >= -1e-9) return false;                  /* level or rising: never comes down */
    double t = (ground_z - f->eye[2]) / d[2];
    if (t <= 0.0) return false;                       /* the ground is above the eye */
    *x = (float)(f->eye[0] + d[0] * t);
    *y = (float)(f->eye[1] + d[1] * t);
    return true;
}
/* }}} */

/* {{{ camera_world_to_screen */
bool camera_world_to_screen(const CameraFrame* f, float x, float y, float z, float* sx, float* sy) {
    double v[3] = { x - f->eye[0], y - f->eye[1], z - f->eye[2] };
    double depth = v[0] * f->forward[0] + v[1] * f->forward[1] + v[2] * f->forward[2];
    if (depth <= 1e-6) return false;
    double across = v[0] * f->right[0] + v[1] * f->right[1] + v[2] * f->right[2];
    double rise = v[0] * f->up[0] + v[1] * f->up[1] + v[2] * f->up[2];
    *sx = (float)((1.0 + across / (depth * f->tan_x)) * f->width / 2.0);
    *sy = (float)((1.0 - rise / (depth * f->tan_y)) * f->height / 2.0);
    return true;
}
/* }}} */

/* {{{ camera_view_quad */
int camera_view_quad(const GameCamera* cam, const CameraFrame* f, float ground_z, float corners[8]) {
    const float at[4][2] = { { 0.0f, 0.0f }, { f->width, 0.0f }, { f->width, f->height }, { 0.0f, f->height } };
    int reached = 0;
    for (int i = 0; i < 4; i++) {
        double d[3];
        ray_of(f, at[i][0], at[i][1], d);
        double t = d[2] < -1e-9 ? (ground_z - f->eye[2]) / d[2] : -1.0;
        if (t > 0.0 && t <= cam->farz) {
            reached++;
        } else {
            t = cam->farz;                            /* where the ray crosses the far clip */
        }
        corners[i * 2] = (float)(f->eye[0] + d[0] * t);
        corners[i * 2 + 1] = (float)(f->eye[1] + d[1] * t);
    }
    return reached;
}
/* }}} */

/* {{{ camera_view_rect */
void camera_view_rect(const GameCamera* cam, const CameraFrame* f, float ground_z, CameraBounds* out) {
    float c[8];
    camera_view_quad(cam, f, ground_z, c);
    *out = (CameraBounds){ c[0], c[1], c[0], c[1] };
    for (int i = 1; i < 4; i++) {
        if (c[i * 2] < out->min_x) out->min_x = c[i * 2];
        if (c[i * 2] > out->max_x) out->max_x = c[i * 2];
        if (c[i * 2 + 1] < out->min_y) out->min_y = c[i * 2 + 1];
        if (c[i * 2 + 1] > out->max_y) out->max_y = c[i * 2 + 1];
    }
}
/* }}} */
