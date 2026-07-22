# platform.h / platform.c — public surface

The thin **Platform seam**: the only place the engine touches the window/GL
library (raylib today). Everything else speaks these verbs, so a later SDL or
raw-framebuffer backend (the Anbernic port) is a rewrite of `platform.c` alone —
issue 101's "packaging, not rewriting" promise.

**GL affinity:** every call touches the GL context, so all of them must run on
the single render thread that called `platform_open` — never a pool worker.

## Verbs

- `int platform_open(int w, int h, const char *title)` — open the surface.
  Returns 1 on success, 0 if no window/GL could be had (caller errors out; no
  headless fallback). Paces the frame to ~60 Hz.
- `int platform_should_close(void)` — has the user asked to close the window?
- `double platform_time(void)` — seconds since the surface opened.
- `void platform_begin_frame(void)` — start a frame; clears to the room colour.
- `void platform_draw_rect(x, y, w, h, r, g, b)` — one filled rectangle, screen
  pixels.
- `void platform_end_frame(void)` — present the frame (vsync-paced).
- `void platform_close(void)` — close the surface, release the GL context.

## Not here yet

Raw-input drain (the two mice) lands in Phase 2 as a fifth verb. Richer drawing
(sprites/models/the culled renderables list) replaces `draw_rect` as the renderer
grows (issue 104).

## Build

Links against raylib: `-I/usr/local/include -L/usr/local/lib -lraylib -lGL -lm
-lpthread -ldl -lrt -lX11`.

## Related

- `src/000-main.c` — the render thread that drives this seam.
- Issue `101` (the seam decision), `102` (the loop it serves).
