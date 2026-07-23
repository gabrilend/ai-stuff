# 202 — Vertical window and dual-screen layout

**Phase:** 2
**Blocked by:** 201 (the render seam must support viewports).
**Blocks:** 203, 207, 208, 209.

## Current behavior

Phase 1's hello-rumble drew to one screen on NDS and one window on
native, without a formal "top half / bottom half" abstraction. The
game does not yet think in terms of two halves.

## Intended behavior

A new abstraction `platform_screen_pair` represents the two play
surfaces — the top (3D scene view) and the bottom (tactical inset /
touch surface). Game code asks for either by symbolic name:

```c
platform_render_target target = platform_screen_pair_top(pair);
platform_render_set_viewport(target);
/* now any submission renders to top */
```

- **On NDS**: top half = top physical screen (256×192, 3D engine
  primary). Bottom half = bottom physical screen (256×192, 2D engine
  primary, stylus input source).
- **On native**: a single window sized 256×384 (or doubled, 512×768,
  for visibility). The top 192 rows render the "top" target; the
  bottom 192 rows render the "bottom" target. A 1-pixel gutter is
  drawn between them to make the seam legible.

The two halves are addressable independently for clearing,
rendering, and reading input (stylus → bottom; D-pad/A/B → either).

## Suggested implementation steps

1. Declare `platform_screen_pair`, `platform_render_target`, and
   accessors in `src/01-platform.h` (or a new
   `src/04-screen-pair.h`; index counter advances).
2. NDS implementation: configure both 2D engines and the 3D engine to
   target the correct screen. The 3D engine in libnds is primary on
   either main or sub at a time — we put 3D on main (top) and use 2D
   sprites for the bottom inset.
3. Native implementation: divide the raylib window into two render
   textures, blit them with the gutter line in `platform_frame_end`.
4. Update `src/10-hello-rumble.c` (from issue 107) to render the
   bobbing knight to the top half and write "press A" to the bottom
   half via the new API.
5. Verify on both targets that input from the bottom half (stylus on
   NDS, mouse on the lower window region on native) is reported with
   coordinates in the bottom-half's local frame.

## Deliverable artifacts

- New `src/04-screen-pair.h`, `.c`, `.info.md`.
- Updated NDS and native platform implementations.
- Updated hello-rumble using the new API.
- `.file-index-counter` advanced.

## Related documents

- `docs/003-controls-and-ui.md` — the dual-screen-vs-native-window seam.
- `docs/004-architecture.md` — platform seam.
