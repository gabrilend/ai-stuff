/* platform.c — the raylib backing of the Platform seam.
 *
 * This is the only file in the engine that #includes raylib. Everything else
 * speaks the four-verb seam in platform.h, so the day we want SDL or a raw
 * framebuffer (the Anbernic port), only this file is rewritten.
 *
 * Runs entirely on the render thread — raylib owns one GL context bound to the
 * thread that called InitWindow, so these calls must never leave that thread.
 */
#include "platform.h"

#include "raylib.h"
#include "rlgl.h"   /* rlDisableBackfaceCulling: draw all faces for now */

/* {{{ platform_open() */
int platform_open(int width, int height, const char *title)
{
    /* Keep raylib's chatter down to real problems. */
    SetTraceLogLevel(LOG_WARNING);
    InitWindow(width, height, title);
    if (!IsWindowReady()) return 0;   /* no window/GL: caller errors out */
    /* Pace the frame to the display. EndDrawing then blocks to ~60 Hz, which is
     * what keeps the "always-unblocked" render loop from spinning a core flat. */
    SetTargetFPS(60);
    /* Until normals drive lighting/backface culling (issue 104), draw every
     * face regardless of winding so a room's walls are all visible; the depth
     * buffer still resolves what's in front of what. */
    rlDisableBackfaceCulling();
    return 1;
}
/* }}} */

/* {{{ platform_should_close() */
int platform_should_close(void)
{
    return WindowShouldClose();
}
/* }}} */

/* {{{ platform_time() */
double platform_time(void)
{
    return GetTime();
}
/* }}} */

/* {{{ platform_begin_frame() / platform_draw_rect() / platform_end_frame() */
void platform_begin_frame(void)
{
    BeginDrawing();
    ClearBackground((Color){ 18, 18, 24, 255 });   /* near-black room */
}

void platform_draw_rect(float x, float y, float w, float h,
                        uint8_t r, uint8_t g, uint8_t b)
{
    DrawRectangle((int)x, (int)y, (int)w, (int)h, (Color){ r, g, b, 255 });
}

void platform_end_frame(void)
{
    EndDrawing();   /* presents + vsync wait */
}
/* }}} */

/* {{{ platform_begin_3d() / platform_draw_tri3d() / platform_draw_line3d() / platform_end_3d() */
void platform_begin_3d(float px, float py, float pz,
                       float tx, float ty, float tz, float fovy)
{
    Camera3D cam = {
        .position   = (Vector3){ px, py, pz },
        .target     = (Vector3){ tx, ty, tz },
        .up         = (Vector3){ 0.0f, 1.0f, 0.0f },   /* +Y is up in raylib */
        .fovy       = fovy,
        .projection = CAMERA_PERSPECTIVE,
    };
    BeginMode3D(cam);   /* enables the depth test for this block */
}

void platform_draw_tri3d(float ax, float ay, float az,
                         float bx, float by, float bz,
                         float cx, float cy, float cz,
                         uint8_t r, uint8_t g, uint8_t b)
{
    DrawTriangle3D((Vector3){ ax, ay, az }, (Vector3){ bx, by, bz },
                   (Vector3){ cx, cy, cz }, (Color){ r, g, b, 255 });
}

void platform_draw_line3d(float ax, float ay, float az,
                          float bx, float by, float bz,
                          uint8_t r, uint8_t g, uint8_t b)
{
    DrawLine3D((Vector3){ ax, ay, az }, (Vector3){ bx, by, bz },
               (Color){ r, g, b, 255 });
}

void platform_end_3d(void) { EndMode3D(); }
/* }}} */

/* {{{ platform_screenshot() */
void platform_screenshot(const char *path)
{
    /* raylib writes the PNG relative to its working directory, so pass an
     * absolute path from the caller. Call it right after a frame is presented. */
    TakeScreenshot(path);
}
/* }}} */

/* {{{ platform_close() */
void platform_close(void)
{
    CloseWindow();
}
/* }}} */
