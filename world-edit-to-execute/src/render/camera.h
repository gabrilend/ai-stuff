/*
 * camera.h - the game camera as numbers (issue 501d)
 *
 * Where the camera looks, from how far, at what angle, and the two answers
 * the rest of the renderer needs from it: which ground point is under a
 * screen point (picking, minimap clicks), and which ground is in view
 * (terrain culling 502e, the minimap's view box 507d). Plain C, in WC3's
 * own units and axes: x east, y north, z up, angles in degrees as WC3's
 * camera natives give them. Needs neither raylib nor Lua; the window
 * (scene_viewer.c) places its raylib camera from it.
 *
 * WC3's default game camera (Blizzard.j's bj_CAMERA_DEFAULT_* constants):
 * distance 1650, angle of attack 304 (56 degrees below level), rotation
 * 90 (looking north), field of view 70, far clip 5000. Whether WC3's 70 is
 * the vertical or the horizontal angle is unmeasured (516d); it is taken
 * as vertical here, as the window does.
 */

#ifndef CAMERA_H
#define CAMERA_H

#include <stdbool.h>

/* {{{ WC3's defaults, and the stand-ins */
#define CAMERA_DEFAULT_DISTANCE 1650.0f
#define CAMERA_DEFAULT_AOA      304.0f   /* degrees; 360 - 304 = 56 below level */
#define CAMERA_DEFAULT_ROTATION 90.0f    /* degrees; 90 looks north */
#define CAMERA_DEFAULT_FOV      70.0f    /* degrees, taken as vertical */
#define CAMERA_DEFAULT_FARZ     5000.0f
#define CAMERA_MIN_DISTANCE     250.0f   /* STAND-IN, as the window's (516d) */
#define CAMERA_MAX_DISTANCE     9000.0f  /* STAND-IN, as the window's (516d) */
/* }}} */

/* {{{ CameraBounds - where the camera's target may go, on the ground */
typedef struct camera_bounds {
    float min_x, min_y, max_x, max_y;
} CameraBounds;
/* }}} */

/* {{{ GameCamera */
typedef struct game_camera {
    float x, y;             /* the target: the ground point at the view's centre */
    float z;                /* the ground's height there */
    float distance;         /* from the target to the eye */
    float rotation;         /* degrees: 0 looks east, 90 north */
    float aoa;              /* angle of attack, degrees, WC3's: 304 is 56 below level */
    float fov;              /* degrees, vertical */
    float farz;             /* nothing further than this along the view is drawn */
    float min_distance, max_distance;
    CameraBounds bounds;
    bool has_bounds;
} GameCamera;
/* }}} */

/* {{{ CameraFrame - what the camera works out from its numbers, for a screen */
typedef struct camera_frame {
    float eye[3];           /* where the eye is */
    float forward[3];       /* unit length, the way it looks */
    float right[3];         /* unit length, the screen's right on the world */
    float up[3];            /* unit length, the screen's up on the world */
    float tan_x, tan_y;     /* half the view's width and height at depth 1 */
    float width, height;    /* the screen, pixels */
} CameraFrame;
/* }}} */

/* {{{ Functions */

/* WC3's default camera looking at (x, y) on the ground at height z, with
 * no bounds and the stand-in zoom limits. */
void camera_init(GameCamera* cam, float x, float y, float z);

/* The bounds as war3map.w3i stores them: eight floats, four corners as
 * (x, y) pairs (lower left, upper right, upper left, lower right). The
 * bounds are the rectangle around the four. Then clamps the target. */
void camera_bounds_from_w3i(GameCamera* cam, const float corners[8]);

/* Holds the target inside the bounds (when it has any) and the distance
 * within its limits. */
void camera_clamp(GameCamera* cam);

/* Looks at (x, y), held inside the bounds: the map's start location on
 * load, a unit, a minimap click. */
void camera_look_at(GameCamera* cam, float x, float y);

/* The eye and the screen's axes on the world, for a screen of the given
 * size in pixels. Every answer below starts from one. */
void camera_frame(const GameCamera* cam, float width, float height, CameraFrame* out);

/* The ground point under screen point (sx, sy), taking the ground as level
 * at height `ground_z`. False when the point's ray never comes down to it
 * in front of the eye (at or above the horizon). */
bool camera_screen_to_ground(const CameraFrame* f, float sx, float sy, float ground_z,
                             float* x, float* y);

/* The screen point of world point (x, y, z). False when the point is not
 * in front of the eye (the screen point is then not set). */
bool camera_world_to_screen(const CameraFrame* f, float x, float y, float z, float* sx, float* sy);

/* The ground in view: the four screen corners (top left, top right,
 * bottom right, bottom left) taken to the ground at `ground_z`, as
 * corners[0..7] (x, y pairs). A corner whose ray does not reach the ground
 * within farz (from the eye, along the view) is taken where it crosses
 * farz, over the ground. Returns how many corners reached the ground. */
int camera_view_quad(const GameCamera* cam, const CameraFrame* f, float ground_z, float corners[8]);

/* The rectangle around camera_view_quad's four corners. */
void camera_view_rect(const GameCamera* cam, const CameraFrame* f, float ground_z, CameraBounds* out);

/* }}} */

#endif /* CAMERA_H */
