/*
 * camera_input.c - WC3's camera controls on the camera model (issue 505c)
 *
 * See camera_input.h.
 */

#include <math.h>
#include "camera_input.h"

/* {{{ camera_pan_ways */
int camera_pan_ways(const CameraInput* in) {
    bool left = in->left, right = in->right, up = in->up, down = in->down;
    if (in->edges) {
        left |= in->mouse_x < CAMERA_EDGE;
        right |= in->mouse_x >= in->width - CAMERA_EDGE;
        up |= in->mouse_y < CAMERA_EDGE;
        down |= in->mouse_y >= in->height - CAMERA_EDGE;
    }
    return (left ? 1 : 0) | (right ? 2 : 0) | (up ? 4 : 0) | (down ? 8 : 0);
}
/* }}} */

/* {{{ camera_step */
void camera_step(GameCamera* cam, const CameraInput* in, float dt) {
    int ways = camera_pan_ways(in);
    float pan = CAMERA_PAN_SPEED * dt * (cam->distance / CAMERA_DEFAULT_DISTANCE);
    double rot = cam->rotation * 3.14159265358979323846 / 180.0;
    float ahead_x = (float)cos(rot), ahead_y = (float)sin(rot);   /* up the screen, on the ground */
    float side = 0.0f, ahead = 0.0f;
    if (ways & 1) side -= pan;
    if (ways & 2) side += pan;
    if (ways & 4) ahead += pan;
    if (ways & 8) ahead -= pan;
    /* the screen's right is a quarter turn clockwise from the heading */
    cam->x += ahead * ahead_x + side * ahead_y;
    cam->y += ahead * ahead_y - side * ahead_x;
    cam->distance -= in->wheel * CAMERA_WHEEL_STEP;
    camera_clamp(cam);
}
/* }}} */
