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
