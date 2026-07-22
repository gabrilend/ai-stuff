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

/* Close the surface and release the GL context. */
void   platform_close(void);

#ifdef __cplusplus
}
#endif

#endif /* FPS_PLATFORM_H */
