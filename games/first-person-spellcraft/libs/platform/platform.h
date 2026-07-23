/* platform.h — the thin seam between the engine and whatever opens a window and
 * draws (raylib today). The engine never names raylib directly; a later SDL or
 * raw-framebuffer backend swaps in behind these same verbs (issue 101's
 * "packaging, not rewriting" promise).
 *
 * The verbs, minimal for Phase 1: open a surface, ask whether to close, report
 * the time, begin/draw/end a frame. Raw-input drain lands in Phase 2 (the mice).
 *
 * GL affinity: every one of these calls touches the GL context, so they ALL must
 * run on the single render thread that called platform_open — never from a pool
 * worker. (docs/soramech-notes.md pattern 7.)
 */
#ifndef FPS_PLATFORM_H
#define FPS_PLATFORM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Open the drawing surface. Returns 1 on success, 0 if no window/GL could be
 * had — the caller errors out loudly rather than limping on headless (no
 * fallbacks). */
int    platform_open(int width, int height, const char *title);

/* Has the user asked to close the window (close button, etc.)? */
int    platform_should_close(void);

/* Seconds since the surface opened. */
double platform_time(void);

/* Frame bracket: begin clears the surface to a background; draw_rect paints one
 * filled rectangle in screen pixels; end presents the frame (vsync-paced). */
void   platform_begin_frame(void);
void   platform_draw_rect(float x, float y, float w, float h,
                          uint8_t r, uint8_t g, uint8_t b);
void   platform_end_frame(void);

/* 3D bracket, used inside a frame: begin sets a first-person camera (eye at
 * (px,py,pz) looking at (tx,ty,tz), vertical field of view `fovy` degrees, world
 * "up" is +Y); tri/line draw filled triangles and colored edges in world space,
 * with the GPU depth buffer resolving occlusion; end closes 3D mode. Coordinate
 * convention: the caller maps its world (x, y horizontal; z up) into raylib
 * space (x, z-height, y) — see src/002-render.c. Raw raylib never leaks past
 * this seam. */
void   platform_begin_3d(float px, float py, float pz,
                         float tx, float ty, float tz, float fovy);
void   platform_draw_tri3d(float ax, float ay, float az,
                           float bx, float by, float bz,
                           float cx, float cy, float cz,
                           uint8_t r, uint8_t g, uint8_t b);
void   platform_draw_line3d(float ax, float ay, float az,
                            float bx, float by, float bz,
                            uint8_t r, uint8_t g, uint8_t b);
void   platform_end_3d(void);

/* Save the current frame to a PNG at `path`. For debugging/demos — capture what
 * the render thread drew without a human at the window. */
void   platform_screenshot(const char *path);

/* Close the surface and release the GL context. */
void   platform_close(void);

#ifdef __cplusplus
}
#endif

#endif /* FPS_PLATFORM_H */
