# 104b — Column Rasterizer & Framebuffer Path

> **Phase:** 1 (Engine Foundation) · **Depends on:** `104a` (the model it
> implements), `103` (the World it draws), `101` (the Framebuffer it fills and the
> Platform that blits it) · **Blocks:** `107` (the demo shows this on screen) ·
> **Difficulty:** hard · **Kind:** the renderer's implementation half.

The pixels. This half turns the decision from `104a` into an actual first-person
image: for each screen column, march the world, and paint a wall slice, the floor
below it, and the ceiling above it into the Framebuffer — then hand the buffer to
the Platform to show. It also opens the **spell-effect render seam** that Phase 3
draws into.

## Current Behavior

Nothing exists. The rendering model and camera are decided (issue `104a`) and the
World can be walked (issue `103`), but no code fills the Framebuffer, so the loop
(issue `102`) still shows only a placeholder frame.

## Intended Behavior

A software rasterizer that produces one Doom-style frame per render call:

- **Per-column ray march.** For each column of the internal Framebuffer, cast a
  ray from the Camera across the tile grid (a DDA-style grid traversal is the
  natural fit for square cells), find the first solid cell the ray hits, and
  compute the wall slice's distance.
- **Wall slices with real heights.** Draw the hit cell's wall slice using that
  cell's floor and ceiling heights and the camera z + pitch (per `104a`), so
  ledges, steps, and drops render believably — not a single flat horizon.
  Correct for fish-eye using the perpendicular distance so straight walls look
  straight.
- **Floor and ceiling fill.** Below each wall slice, fill the floor toward the
  camera; above it, fill the ceiling. Phase 1 may fill with flat shading or a
  simple distance-darkened colour per surface id; textured floors/ceilings are a
  later polish, not a blocker.
- **Distance cue.** Darken surfaces with distance (a cheap depth shade) so the
  space reads as a space — this also hides the low internal resolution.
- **Writes only the Framebuffer.** The rasterizer never talks to the Platform
  directly; it fills the shared Framebuffer and the loop's blit step (issue
  `102`, Platform verb from `101`) puts it on screen. Clean separation: data
  generation (this) is isolated from data viewing (the blit).
- **Spell-effect render seam.** Expose a hook that runs *after* world geometry is
  drawn and *before* the blit, receiving the same Framebuffer and Camera, where a
  later effects pass (Phase 3) can draw projectiles, glows, and the two-hand wand
  overlay. Phase 1 registers nothing on it; the hook simply exists and is empty.
- **Special-tile visual hook.** Where a cell/room carries a special-property tag
  (issue `103`), the wall surface id can select a distinct surface, so "something
  special about each room" can *look* special later without the renderer knowing
  what the specialness means.
- **Budget discipline.** The inner per-column loop is the hottest code in the
  whole engine; keep it allocation-free per frame (reuse buffers), LuaJIT-trace
  friendly (straight, branch-light inner loop), and measured — a small on-demand
  timing readout beats guessing.

## Suggested Implementation Steps

1. Implement the **grid ray march** (DDA over the tile grid) returning, per
   column, the hit cell, the perpendicular distance, and which wall face was hit.
2. Implement the **wall-slice draw** using the hit cell's heights + camera z/pitch
   from `104a`, with fish-eye correction; verify a plain room looks right first.
3. Add **floor/ceiling fill** and the **distance shade**.
4. Add the **per-cell height handling** so a raised-floor cell draws a visible
   step — test against the issue `103` test world's ledge.
5. Open the **spell-effect render hook** (post-geometry, pre-blit) and leave it
   empty; document its contract in the file's `.info.md` for Phase 3.
6. Wire the renderer in as the real replacement for issue `102`'s render stub,
   and confirm the loop now draws the test world. Keep the inner loop
   allocation-free; add a cheap frame-time readout for the budget.
7. Make several tiny visual tests (a known camera pose over the test world should
   produce a stable, checkable frame) — tests are cheap; a rendering bug is not.

## Related Documents / Tools

- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — the
  render transform, the Framebuffer, and the spell-effect render seam (Phase 3).
- Depends on `104a` (model + camera), `103` (world + heights), `101` (framebuffer
  + blit). Feeds `107` (the demo renders the walkable world).
