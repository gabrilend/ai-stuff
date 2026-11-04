# Issue 606a: Hot-Reload Swaps in the Renderer, Sound and UI

**Phase:** 6
**Type:** Implementation
**Priority:** Low
**Dependencies:** 606 (hot-reload), Phase 5 (render interface)
**Blocks:** 608

---

## Current Behavior

`assets/hotreload.lua` (606) notices a changed file in an asset pack,
reads it again through the loader (601) and hands the new value to its
`on_reload(path, value, source)` callback. Nothing on screen changes yet:

- (Done on the Lua side, PR "606a: the renderer reads through the
  loader": `assets/gpu.lua`, `assets/ground.lua`, the map viewer and the
  editor read through the loader, and `gpu.on_reload` /
  `ground.on_reload` put a saved texture into its texture id.)
  `render/models.c` can make a texture (`tex_create`) but not replace
  one, so nothing changes on screen yet.
- There is no audio library yet.
- There is no UI layout file reader yet.
- (Done in 604a, PR #121: stored files are read-only, and
  `storage.lua edit` turns a pack's link into a private copy to edit.)

## Intended Behavior

Saving a texture in an editor changes it in the running game.

**Where it shows (2026-11-04).** This project's Lua renderer is now the
editor's alone; the editor keeps it, and playing happens in the W client,
which Test Map opens (`docs/wow-client-bridge.md`, "2026-11-04: the editor
keeps its own renderer"; issue 913). So "the running game" here is the
editor's view of the map being edited: saving a texture in a pack changes
it there without a restart. A pack changing while a game is played would
be the W client's, through its own asset lookup (its 105a). Step 8's flag
is the editor's; the map viewer's play mode gives way to Test Map.

## Suggested Implementation Steps

1. Add `tex_update(id, w, h, rgba)` to `render/models.c` (and the ground's
   textures), replacing a texture's pixels in place, size included.
2. ~~Move `assets/gpu.lua` and `assets/ground.lua` onto the loader (601's
   decision 8 left them on `assets.open`), keeping which texture id came
   from which path, and give them an `on_reload` that updates it.~~ Done
   on the Lua side (2026-11-03); waits on step 1 to show on screen.
3. Models: rebuild the meshes of a changed model; reset its animation.
4. Sounds: swap the sound in place once the audio library is in.
5. UI: rebuild the UI tree from a changed layout once UI layouts are read.
6. A corner message (console overlay) for each reload and error.
7. ~~Make stored files read-only, and a storage command that turns a
   pack's link into a copy for editing.~~ Done in 604a (PR #121), decided
   by Ritz on 2026-11-02.
8. A viewer or editor flag (`--hot-reload`) that makes a hot-reloader and
   polls it each frame.

## Acceptance Criteria

- [ ] A texture saved in a pack changes on screen without a restart
- [ ] A model saved in a pack is rebuilt (its animation may restart)
- [ ] A sound saved in a pack plays the new sound next time
- [x] An editor can't write through a pack's link into the shared store
      (604a, PR #121)

## Related Documents

- [606](./completed/606-hot-reload-system.md) - hot-reload (watching, cache invalidation)
- [601](./completed/601-asset-loader-resolution.md) - asset loader

## Progress Notes

### Step 2, the Lua side (2026-11-03)

Built without a screen: the renderer is a fake in the tests, and the map
viewer and editor changes are **unseen** (compiled, not run).

- `assets/loader.lua`: `L:texture`, `L:model`, `L:table`, `L:model_for`,
  `L:scale_for`, answering as `assets.open`'s handle does.
- `assets/gpu.lua`: `C:retexture(path, img)` and `gpu.on_reload(cache)`;
  texture keys are now one per path whatever its case and slashes.
- `assets/ground.lua`: `ground.on_reload(render, ids, terrain, report)`.
- `demo/wc3map/main.lua`, `editor/main.lua`: read art through a loader
  over the map's handle.
- `src/tests/test_renderer_loader.lua`: 37 tests.

After the editor-and-client split (2026-11-04): the editor's reading
through the loader (`editor/main.lua`) is the part "Where it shows" asks
for. The map viewer's (`demo/wc3map/main.lua`, decision 3) serves a play
mode that gives way to Test Map (913); it is left as built until the
owner says whether to take it out.

Decisions made while building:

1. **The loader borrows `model_for` and `scale_for` from the handle**
   rather than copying them: they're the handle's own functions run with
   the loader as `self`, so they read stock tables through the handle and
   models packs first, and stay one piece of code.
2. **Stock tables stay with the handle.** Packs hold art; `L:table` passes
   through. A pack that overrides a `.slk` is not read for it (not asked
   for; another issue if wanted).
3. **The map viewer keeps the handle for everything but art** (stock
   tables, the unit stock, sounds, the game): only the ground, the model
   cache and `model_of` take the loader. When the packs can't be read
   (a broken pack folder) they fall back to the handle and print why,
   rather than not starting.
4. **The model gallery (`demo/models`) stays on the handle**: it shows the
   map's own models and counts the handle's textures in its report.
5. **A texture made for a `.tga` read as its `.blp` is swapped** when the
   `.blp` is saved again, as either reader would have found it.
6. **Texture ids are matched by path whatever its case or slashes**, and
   `gpu.lua` now makes one texture for `Textures\A.blp` and
   `textures/a.blp`, where it made two before.
7. **Without `render.tex_update`** both callbacks swap nothing and give
   false, so a hot-reloader can be wired today and starts working when the
   C side lands.
8. **A tileset saved in a new shape** (plain to extended) gets its new
   pixels, but the ground keeps its old layout until it is laid again.
9. **Not wired yet: a `--hot-reload` flag** (step 8). Polling each frame
   from the viewer needs a screen to check; left for step 8.

