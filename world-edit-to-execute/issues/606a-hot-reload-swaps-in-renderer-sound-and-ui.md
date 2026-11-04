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

- The renderer reads textures through `assets.open` (`assets/gpu.lua`,
  `assets/ground.lua`), not the loader, and `render/models.c` can make a
  texture (`tex_create`) but not replace one.
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
2. Move `assets/gpu.lua` and `assets/ground.lua` onto the loader (601's
   decision 8 left them on `assets.open`), keeping which texture id came
   from which path, and give them an `on_reload` that updates it.
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
