# Issue 523: Models Play Their Own Animations

**Phase:** 5 (rendering)
**Type:** Implementation
**Priority:** High
**Dependencies:** 522 (MDX reader, model renderer), 519 (combat: swings, deaths)

---

## Current Behavior

Models are drawn in their rest pose (the pose their vertices are stored
in). Their sequences, bones, pivots, keyframes and vertex groups are all
parsed (522b) but nothing plays them. Units slide across the ground
frozen; the fallen fade where they stood.

## Intended Behavior

- **Renderer:** meshes move with the model's bones, on the GPU.
- **Playback:** any of a model's sequences plays by name, as WC3's names work (Stand and its variants, Walk, Attack, Death ...).
- **Gallery:** the model gallery plays every model's own sequences, to show that it works.
- **Map:** units play what they're doing: stand, walk at their speed, attack in time with their swing, die. Doodads stand (and sway).

## Suggested Implementation Steps

1. Skinning in `render/models.c`: a matrix group per vertex, a pose per instance (group matrices and part alphas), a vertex shader that applies them.
2. `assets/anim.lua`: track sampling, the node hierarchy about pivots, the groups' matrices, part alphas, playheads, a pose cache.
3. `assets/gpu.lua`: every geoset kept (hidden ones with alpha 0), vertex groups uploaded, a rig per model.
4. The gallery's programme of sequences; `demo/wc3map/animate.lua` for units' states.
5. Tests; every model of the test maps posed through every sequence.

## Acceptance Criteria

- [x] Vertices move by their matrix group's matrix (the average of its bones'), on the GPU; builds against raylib 5.5 and 5.0
- [x] Translation, rotation (slerp) and scaling tracks, linear, Hermite and Bezier; global sequences; nodes about their pivots under their parents
- [x] Geoset and layer alpha animation (parts appear and vanish: corpses, swapped weapons)
- [x] Sequences by name with variants by rarity; looping ones start over, others hold their end
- [x] The model gallery plays every model's sequences in turn (checked in screenshots)
- [x] The map's units stand, walk, attack and die with their models; doodads stand
- [x] `test_anim.lua`: 40 tests; all 256 rigged models of the 16 maps posed through every sequence with finite values

## Implementation Notes

**Date:** 2026-09-29

### Renderer (`render/models.c`)

WC3 skinning is simple: each vertex belongs to one matrix group, a list of
bones; its matrix is the plain average of their matrices (no weights).
So a pose is, per geoset, one matrix per group, not per bone, and the
shader needs one index per vertex:

- **Vertex attribute:** the group index rides in the vertex colour's first two bytes, so it uses a slot both raylib 5.0 and 5.5 upload (5.0 has no bone attributes).
- **Uniforms:** a `vec4 bones[384]` array: up to 128 groups of 3 rows. A geoset with more groups than that stays in its rest pose; none in the test maps has more.
- **API:** `mesh_create(verts, idx, skin)`, `model_create(parts, skin_groups)` and `model_draw(..., alpha, pose)`. A pose is one string of floats: one alpha per part, then 12 floats per group per skin. Without a pose, a model draws as before (rest pose, the parts' Stand alphas).

### Animation (`assets/anim.lua`)

- **Nodes:** every node type (bones, helpers, attachments, emitters ...), sorted parents first. Local = T(pivot + translation) · R · S · T(−pivot); world = parent · local.
- **Tracks:** keys found by binary search within the sequence's interval (the interval's key range is cached per track). Hermite and Bezier values use their tangents; rotations are slerped.
- **Bad data:** one DAoW model (a Warcraft II–style Great Hall) stores NaN rotations; they're read as no rotation. Repeated key frames don't divide by zero.
- **Playheads:** a name, a sequence, a time and a rate. Stand variants are picked by rarity, again each loop. A unit's death holds its last frame.
- **Cache:** poses are cached per model, at 20 ms steps (4,096 per model, then cleared), so a crowd of one unit type costs little. A pose takes about 0.4 ms to work out.

### Where it plays

- **Gallery** (`demo/models/main.lua`): all models are asked for the same sequence together, four seconds each. The order is Stand, Walk, Attack, Spell, Stand Ready, Death, then every other name any model has; a model without the one asked for stands. `MODEL_GALLERY_ANIM=walk` plays one only; `none` leaves the rest pose. On DAoW 5.4b: 38 of 40 models stand, 29 walk, 26 attack.
- **Map** (`demo/wc3map/animate.lua`):
  - The dead play Death.
  - A swing plays Attack from its start, its rate fitted to the swing's wind-up and backswing (0.5–3×).
  - A unit on a route plays Walk at its speed over the sequence's move speed (0.5–2.5×).
  - Everything else plays Stand; doodads play Stand from a random point.
  - `WC3_ANIMATE=0` gives the old rest pose.

### Checked

- **Screenshots:** the textured battle-rager through stand, walk, attack and death; the whole gallery at stand, walk and attack; DAoW's modelled units in the map.
- **All models:** 256 models (2,395 skinned geosets) × every sequence × 3 moments, all finite.

### Not yet

- **Billboarded nodes** (they face the camera in WC3) turn with their parent here.
- **Node flags:** the "don't inherit translation / rotation / scaling" flags aren't applied.
- **Not animated yet:**
  - Geoset colour (KGAC).
  - Texture animation (TXAN), and layer texture swaps (KMTF).
  - Particles and ribbons.
- **Hermite and Bezier rotations** are slerped, not squad.
- **Blending:** WC3 blends from one sequence into the next (the model's blend time); here the switch is immediate.
- **Other units' states:** Stand Work (building, harvesting), Spell (no abilities yet), Birth, and Decay after death.
- **Off screen:** a unit's playhead only moves while it's on screen.
