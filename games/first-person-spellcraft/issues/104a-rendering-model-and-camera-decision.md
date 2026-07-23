# 104a — Rendering Model & Camera Decision

> **Phase:** 1 (Engine Foundation) · **Depends on:** `101` (Framebuffer/Platform),
> `103` (the World it will draw) · **Blocks:** `104b` (the rasterizer implements
> this decision) · **Difficulty:** medium-hard (decision-heavy) · **Kind:**
> architecture-decision sub-issue of the renderer · **Status:** in progress —
> first-person 3D built; pitch, portal culling, and lighting pending. Supersedes
> `104b`.

The renderer is the largest single feature in Phase 1, so it is split. This
half **decides how the world becomes a first-person image** and defines the
camera — before a single pixel is drawn. The core tension: the vision wants both
a Doom-like square-room look **and** real platforming (verticality), and the
target is a weak handheld. The rendering model has to serve all three.

## Current Behavior

Reconceived — the software raycaster described below is superseded, and `104b`
(the column rasterizer) is obsolete. The engine renders the world **first-person
in 3D on the GPU** (raylib). Built and running (`src/002-render.{c,h}`,
`libs/platform` 3D verbs): the world's tile grid is turned once into **per-room
vertex meshes** — a floor and ceiling per open cell, and a wall wherever open
floor meets solid stone or a taller floor — each face carrying its corners, a
**normal** (for lighting to come), and a **fill + bright edge colour**. A
first-person camera flies from the player's eye, following the wandering player
through a four-room realm; the GPU depth buffer resolves occlusion. (Screenshots
in the session transcript.) Still to come: pitch/vertical-look, portal culling,
and lighting.

## Intended Behavior

A recorded rendering-model decision (superseding the raycaster) plus the camera:

- **The decision: GPU 3D with per-object vertex meshes.** Geometry is built once
  into per-object datastructures — one mesh per room now, chunked for heavy
  objects later — each face carrying its vertices, a normal, and a fill + edge
  colour. raylib draws it; the depth buffer gives correct per-pixel occlusion for
  free. This replaces the height-extended grid raycaster + software Framebuffer
  plan (kept on record below): the pure-C + raylib pivot (issue `101`) made the
  GPU path both simpler and truer to the vision's 3D, edge-lit look.
- **Visibility, in layers.** Per-pixel occlusion is the GPU depth buffer (free,
  in now). Coarse culling is the next layer: frustum-cull off-screen rooms, then
  **portal-cull through doors** — draw the room you're in, then each adjacent room
  clipped to the door it's seen through, recursively. That is the exact, elegant
  form of "only render what's visible through the openings," fitted to a
  rooms-and-doors world; it lands when the realm is big enough to need it. (The
  raycast-from-object-to-camera idea maps onto this portal walk.)
- **Colored edges** are drawn now (bright lines on every face); **normals** are
  stored now and will drive **diffuse + specular lighting** later.
- **The Camera**, derived from the player each frame: eye position (x, y, z +
  eye-height), **yaw** (facing — follows travel direction for now), **pitch**
  (look up/down for verticality — still to wire), and FOV. Kept separate from the
  player so a later spectator / NCP-possession view (Phase 5) can drive it.
- **Superseded, kept on record:** the height-extended grid raycaster rendering
  into a fixed-resolution software Framebuffer (and its sector-renderer
  alternative). Recorded so the software path can be revisited if the GPU target
  ever fails on the Anbernic. Issue `104b` (the column rasterizer) belongs to
  that superseded path.

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
