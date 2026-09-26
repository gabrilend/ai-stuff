# Issue 516: Draw WC3 Models in the Engine

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** High
**Dependencies:** 116 (model reader), 117 (texture reader)
**Builds on (completed):** 508 (the vertical slice: C draws, Lua writes render slots)
**Related:** 515 (the ceramic backend that builds each frame's page), 503 and 503b (the placeholder sprite plan, to be re-cut), W03 (WoW models in the engine, and the model chooser both systems will share), 603 (where community models come from)

---

## Current Behavior

The renderer (`src/render/`, C on raylib) draws every unit and doodad as one
of four placeholder shapes, chosen by the `mesh_id` field of its render slot
(`slots.h`), coloured by team. Each slot also carries `facing`, `scale`,
`selected`, `team_id` and an `anim` field, which nothing yet reads as an
animation. No model file is read anywhere in the project.

## Intended Behavior

The owner (2026-09-26): "Why use capsules when you could use footmen and
grunts?" The renderer draws real WC3 models, and keeps the placeholder
shapes for any model it cannot find or read.

### Which model a unit gets

The owner, in two answers on 2026-09-26:

> "Ideally, we'd try as much as possible to use the models posted online
> rather than the ones in the game. We want to respect and honor Warcraft 3
> and the most respectful way to do that I can think of is to use their
> models only when we are building in compatibility with their formats. For
> the rest of it, we can use placeholders."

> "use the models that the map requests. Even if they're stock. The user
> will build per-stock-model overrides that they can then have rendered on
> their end."

Drawing the model a map asks for *is* building compatibility with the
format, so the second answer settles how the first applies in play. A
unit's model is looked up in this order:
1. **The player's own override** for that model path: a community model (or
   one they made) that the player has chosen to stand in for it. Overrides
   live on the player's machine and are drawn only there; no other player
   sees them unless they install the same ones.
2. **The model the map requests:** one imported into the map, or a stock
   model read from the player's own WC3 install. Nothing Blizzard-made is
   shipped with the project.
3. **A placeholder shape**, as today, when neither can be found or read.
   Every placeholder use is counted and reported.

A unit type's model path comes from the map's object data and the stock
tables (issue 112).

**The chooser, now and later.** The owner (2026-09-26): "the WoW path is the
desired path for both systems. But it's a ways off. We can implement a
placeholder solution for now." The WoW path is W03's resolver (an override
pack, then the source, then a placeholder, with counts per source and a
warning for each placeholder). Both systems will share that design when it
exists. Until then this issue builds a small stand-in with the same three
steps and the same counts, kept behind one function so W03's resolver can
replace it without the renderer noticing.

### Where the drawing happens

The owner (2026-09-26): "We are building the backend in ceramic, and the
renderer in raylib, with C being used (probably as soramech boxes) to create
the 'page' that the renderer will draw from with a single thread to display
on the screen."

So:
- **At map load,** the model reader (116, Lua) reads each model the map
  uses, once. Its result is handed to C and stored for the whole map: each
  geoset's positions, normals, texture coordinates and triangles uploaded as
  a mesh, each texture decoded (117) and uploaded, and a model id handed
  back.
- **Each frame,** the ceramic backend (515) works out the game state, and C
  boxes turn it into the **page**: for each thing to draw, its model id, its
  pose (the animation and frame, resolved to bone transforms), position,
  facing, scale, team colour and selection.
- **The raylib renderer,** on its one thread, draws the page: meshes with
  their textures and blend modes, textures with replaceable id 1 (team
  colour) or 2 (team glow) filled from the page's team colour, and each
  vertex following the average of the bones in its vertex group (how WC3
  skins its classic models).

One model's meshes and textures are shared by every unit that uses it.

## Suggested Implementation Steps

1. The C model store: take the reader's result, upload meshes and textures,
   hand back a model id, free everything when the map ends.
2. Rest-pose drawing of geosets, with textures and blend modes, in the
   current renderer, from the render slots, so models show up before the
   page exists.
3. Team colour and team glow through replaceable ids.
4. The stand-in chooser: override, then the requested model, then
   placeholder, with counts.
5. Animation: sequence lookup by name, bone track sampling, vertex-group
   skinning.
6. Move the per-frame pose work into C boxes that write the page, once 515's
   backend builds pages; the renderer then reads the page instead of slots.
7. Tests: headless, a test model goes into the store with the expected mesh
   and triangle counts; the chooser picks the override when one exists, the
   requested model when not, and the placeholder when neither reads, and
   counts each; a screenshot of a test model under the fixed camera is
   compared with a saved one.

## Acceptance Criteria

- [ ] A map's requested model draws in place of a placeholder, whether imported or stock
- [ ] A player's override for a model path replaces it, on that player's machine only
- [ ] Team colour shows on replaceable-id textures
- [ ] A model that can't be found or read draws as a placeholder shape, and the count is reported
- [ ] Each model is read once per map and stored until the map ends
- [ ] A unit plays its stand and walk animations
- [ ] One model's meshes are shared by every unit that uses it

## Open Questions

1. ~~The current C renderer, the ceramic path, or both?~~ Answered
   2026-09-26: the raylib renderer draws, from a page the ceramic backend
   and C boxes build (see Where the drawing happens).
2. ~~When no community model covers a unit type, is a placeholder enough?~~
   Answered 2026-09-26: draw the model the map requests, even a stock one;
   players make their own overrides.
3. ~~One chooser with W03, or two?~~ Answered 2026-09-26: W03's design, for
   both, when it exists; a stand-in until then.
4. ~~How does a player make an override?~~ Answered 2026-09-26: through the
   game's UI ("we'll do it through the UI we haven't planned yet"). The UI
   framework (506) will carry an override screen; until it exists, this
   issue's chooser reads overrides from a plain data file the screen will
   later write. Whether an override applies to every map or to one is
   decided with that screen.

## Related Documents

- `issues/116-read-wc3-models.md`, `issues/117-read-wc3-textures.md`
- `issues/515-render-graph-on-the-ceramic-engine.md`
- `issues/completed/508-vertical-slice-testing-room.md`
- `issues/W03-show-wow-models-with-wc3-unit-behavior.md`
- `issues/603-fetch-maps-and-models-from-public-sites.md`
- `docs/render-architecture.md`
