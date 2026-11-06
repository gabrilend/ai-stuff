/*
 * camera_input.h - WC3's camera controls on the camera model (issue 505c)
 *
 * What one frame of input does to the camera (camera.h): the arrow keys
 * and the screen's edges pan it, the mouse wheel zooms it, and it stays
 * inside the map's camera bounds and its zoom limits. Plain C, no raylib:
 * the window reads its keys and mouse into a CameraInput and calls
 * camera_step once a frame. Jumping to a unit is camera_look_at.
 *
 * The speeds are the window's stand-ins (scene_viewer.c) until 516d
 * measures WC3's: 1400 units a second at the default distance, faster
 * zoomed out; 150 units of distance a wheel notch; the edge is the outer
 * 3 pixels of the screen.
 */

#ifndef CAMERA_INPUT_H
#define CAMERA_INPUT_H

#include <stdbool.h>
#include "camera.h"

/* {{{ The stand-ins */
#define CAMERA_PAN_SPEED   1400.0f   /* WC3 units a second at the default distance */
#define CAMERA_WHEEL_STEP  150.0f    /* distance a wheel notch */
#define CAMERA_EDGE        3.0f      /* pixels: the screen's edge that scrolls */
/* }}} */

/* {{{ CameraInput - one frame's input */
typedef struct camera_input {
    bool left, right, up, down;   /* arrow keys held */
    bool edges;                   /* the screen's edges scroll (an interface, the window focused) */
    float mouse_x, mouse_y;       /* pixels */
    float width, height;          /* the screen, pixels */
    float wheel;                  /* notches this frame; forward (positive) comes closer */
} CameraInput;
/* }}} */

/* {{{ Functions */

/* Which ways the input pans: bit 0 left, 1 right, 2 up, 3 down, from the
 * keys and, when edges are on, the mouse at the screen's edges. */
int camera_pan_ways(const CameraInput* in);

/* One frame of `dt` seconds: pans along the view's own heading (up the
 * screen is the way the camera looks, on the ground), zooms, clamps. */
void camera_step(GameCamera* cam, const CameraInput* in, float dt);

/* }}} */

#endif /* CAMERA_INPUT_H */
