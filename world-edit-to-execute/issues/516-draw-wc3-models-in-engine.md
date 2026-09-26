# Issue 516: Draw WC3 Models in the Engine

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** High
**Dependencies:** 116 (model reader), 117 (texture reader)
**Builds on (completed):** 508 (the vertical slice: C draws, Lua writes render slots)
**Related:** 503 and 503b (the placeholder sprite plan, to be re-cut), W03 (WoW models in the engine), 603 (where community models come from)

---

## Current Behavior

The renderer (`src/render/`, C on raylib) draws every unit and doodad as one
of four placeholder shapes, chosen by the `mesh_id` field of its render slot
(`slots.h`), coloured by team. Each slot also carries `facing`, `scale`,
`selected`, `team_id` and an `anim` field, which nothing yet reads as an
animation. No model file is read anywhere in the project.

## Intended Behavior

The owner (2026-09-26): "Why use capsules when you could use footmen and
grunts?" The renderer draws real WC3 models where a model is available, and
keeps the placeholder shapes for everything else.

**Which models (the owner's rule, 2026-09-26):**

> "Ideally, we'd try as much as possible to use the models posted online
> rather than the ones in the game. We want to respect and honor Warcraft 3
> and the most respectful way to do that I can think of is to use their
> models only when we are building in compatibility with their formats. For
> the rest of it, we can use placeholders."

So a unit's model is looked up in this order:
1. **A community model** the player has installed: fetched from a public
   site (603) or received from another person (609).
2. **A placeholder shape**, as today. Every placeholder use is counted and
   reported, as W03's resolver does.

The stock models in the player's own WC3 install are **not** a step in that
order. They are read only while building compatibility with Blizzard's
formats: testing the reader (116), the texture decoder (117) and this
renderer against Blizzard's own files, and comparing a community model with
the original it stands in for.

**Drawing a model:**
- Each geoset becomes a mesh (positions, normals, texture coordinates,
  triangles), uploaded once per model and shared by every unit using it.
- Each material layer's texture is decoded (117) and uploaded; blend modes
  map to raylib's blend modes.
- **Team colour:** a texture slot with replaceable id 1 (team colour) or 2
  (team glow) takes the unit's team colour from its slot, not a file.
- **Pose and animation:** first the model's rest pose, then animation: the
  slot's `anim` field names a sequence, the bone tracks are sampled at the
  current frame, and each vertex follows the average of the bones in its
  vertex group. This matches how WC3 skins its classic models.
- The slot's `facing`, `scale` and `selected` apply as they do to the
  placeholder shapes.

**How a unit finds its model.** A unit type's model path comes from the
map's object data and the stock tables (issue 112). A community model is
matched to that path by a table kept as data, one line per path, so the
matching can be edited without touching code.

## Suggested Implementation Steps

1. Model cache in C: load a parsed model once, keep its meshes and textures,
   hand out an id. The Lua side asks for a model by path; the render slot
   carries the id where it now carries a placeholder shape.
2. Rest-pose drawing of geosets with their textures and blend modes.
3. Team colour and team glow through replaceable ids.
4. The resolver: installed community model, else placeholder, with counts.
5. The path-to-model table, as a data file.
6. Animation: sequence lookup by name, track sampling, vertex-group
   skinning.
7. Tests: headless, a test model loads into the cache with the expected
   mesh and triangle counts; the resolver picks the community model when
   installed and the placeholder when not, and counts each; a screenshot of
   a footman-shaped test model under the fixed camera is compared with a
   saved one.

## Acceptance Criteria

- [ ] A community model draws in the vertical slice in place of a placeholder
- [ ] Team colour shows on replaceable-id textures
- [ ] Units with no installed community model draw as placeholder shapes, and the count is reported
- [ ] Stock WC3 models are never drawn in play; they are read only by compatibility tests
- [ ] A unit plays its stand and walk animations
- [ ] One model's meshes are shared by every unit that uses it

## Open Questions

1. Does this go into the current C renderer, the ceramic render path (515),
   or both? (`issues/CRITICAL-PATH.md`, Q-4)
2. When a map uses a unit type no community model covers, is the placeholder
   enough, or should the catalogue (1001) suggest community models for it?
3. How does this share work with W03, which draws WoW models through its own
   resolver (override pack, then the WoW client, then a placeholder)? One
   resolver with two chains, or two resolvers?

## Related Documents

- `issues/116-read-wc3-models.md`, `issues/117-read-wc3-textures.md`
- `issues/completed/508-vertical-slice-testing-room.md`
- `issues/W03-show-wow-models-with-wc3-unit-behavior.md`
- `issues/603-fetch-maps-and-models-from-public-sites.md`
- `docs/render-architecture.md`
