# 104a — Rendering Model & Camera Decision

> **Phase:** 1 (Engine Foundation) · **Depends on:** `101` (Framebuffer/Platform),
> `103` (the World it will draw) · **Blocks:** `104b` (the rasterizer implements
> this decision) · **Difficulty:** medium-hard (decision-heavy) · **Kind:**
> architecture-decision sub-issue of the renderer.

The renderer is the largest single feature in Phase 1, so it is split. This
half **decides how the world becomes a first-person image** and defines the
camera — before a single pixel is drawn. The core tension: the vision wants both
a Doom-like square-room look **and** real platforming (verticality), and the
target is a weak handheld. The rendering model has to serve all three.

## Current Behavior

Nothing exists. There is no camera, no projection, no chosen rendering technique.
The World (issue `103`) can describe rooms with per-cell floor and ceiling
heights, but nothing turns that description into a view.

## Intended Behavior

A recorded rendering-model decision plus a defined **Camera**:

- **The tension to resolve.** A textbook Wolfenstein-style raycaster is the
  cheapest thing that runs on weak hardware, but in its pure form every floor and
  ceiling is flat and the same height — which **kills platforming**. Doom's own
  sector/BSP renderer allows per-region floor/ceiling heights (real ledges and
  drops) but is heavier to build and reason about. The world is square-room /
  grid-shaped (issue `103`), which is a gift: it means a grid raycaster is
  viable *if* we extend it.
- **The recommendation (top = most likely to succeed):** a **grid raycaster
  extended with per-cell floor and ceiling heights** — cast one ray per screen
  column across the tile grid, and at each cell draw the wall slice using that
  cell's floor/ceiling heights rather than a single global horizon. This keeps
  the cheap, grid-friendly cost model of a raycaster while gaining the vertical
  steps platforming needs. It does not attempt rooms-stacked-over-rooms (Doom
  can't either), which the square-room vision doesn't require.
  - Alternative kept on record: a small **sector renderer** (more faithful to
    Doom, more capable, more expensive) if height-extended raycasting proves too
    limiting for the puzzles Phase 4 wants. Documented so the choice can be
    revisited with context.
- **The Camera**, defined here and derived from the Player each frame: eye
  position (x, y, and z + eye-height above the feet), **yaw** (facing), **pitch**
  (look up/down — required so verticality actually reads on screen when you jump
  or stand on a ledge), and field of view. Kept separate from the Player so a
  later spectator / NCP-possession view (Phase 5) can drive the camera from
  something other than the local player.
- **Fixed internal resolution.** Render into a small internal Framebuffer and let
  the Platform scale it up on blit, so the software rasterizer's per-frame pixel
  cost is constant regardless of window or screen size — the handheld budget
  wants this pinned down.
- **No fallbacks in the math.** Degenerate cases (ray parallel to an axis, camera
  exactly on a cell boundary) are handled explicitly with a correct branch, not
  papered over with a fudge factor that silently misdraws.

## Suggested Implementation Steps

1. Record the decision (height-extended grid raycaster, with the sector-renderer
   alternative noted) in `docs/datapath-engine-foundation.md`, including *why*
   verticality forces us past a plain Wolfenstein caster.
2. Define the **Camera** structure and the derive-camera-from-player transform
   (eye height, yaw, pitch, FOV), with axis/units conventions as comments.
3. Specify the projection: how a column ray maps to a wall slice's on-screen top
   and bottom given a cell's floor/ceiling heights, the camera z, and pitch.
   Write this as prose/diagram in the datapath doc so `104b` implements a
   decision, not a guess.
4. Decide the internal Framebuffer resolution and the FOV as named constants
   exposed to a stats utility (not hardcoded in prose docs).
5. Sanity-check the model on paper against the issue `103` test world: a room
   with a raised ledge should produce a believable step when viewed head-on.

## Related Documents / Tools

- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — the
  Camera and Framebuffer structures and the render transform.
- Depends on issues `101` (Framebuffer, Platform blit) and `103` (per-cell
  heights). Blocks `104b` (the rasterizer that implements this model).
