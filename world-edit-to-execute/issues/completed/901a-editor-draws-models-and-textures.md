# Issue 901a: The Editor Draws Models and Textures

**Phase:** 9 (editor)
**Type:** Implementation
**Priority:** High
**Parent:** 901 (editor core)
**Dependencies:** 522 (assets, models), 523 (animation), 526 (ground textures)

---

## Current Behavior

The editor's window draws every doodad and unit with the geometry designs, and the ground in plain colours, even where the game shows models and textures.

## Intended Behavior

As the game draws a map:

- **Ground:** textured with the tilesets' own textures from the map and the owner's install, else stand-ins. The textures are made once; they are laid again after the ground is rebuilt once a stroke ends. During a stroke the ground shows its colours, since laying the textures takes a while.
- **Objects:** drawn with their models, the map's imports and the install's, where one is found, in their Stand animation. Units take their team colour.
  - **Live types:** the model lookup reads the editor's own object tables, so a type edited in the editor, or a new custom type, shows its model. The lookup is forgotten after each change to the types.
- **The rest:** objects without a model keep the designs, baked in blocks as before.
- **Switches:** WC3_MODELS=0 turns models off; WC3_TILES=0 gives plain colours, and WC3_TILES=standin the stand-ins.

## Suggested Implementation Steps

1. `assets/ground.lua`: `ground.textures` (made once) and `ground.lay` (laid again), with `ground.apply` still both.
2. `editor/main.lua`: the assets, the model cache and the model lookup with live types; draw modelled objects each frame near the camera; leave them out of the baked blocks.

## Acceptance Criteria

- [x] DAoW 5.4b in the editor: 16 ground tilesets laid (stand-ins here, the install's on the owner's machine); 419 of 18,650 objects drawn with the map's own models; the rest with designs (checked headless)
- [x] Ground textured again after a stroke
- [x] test_ground and test_editor still pass

## Notes

- **Without the install:** here only DAoW's imported models are found. Stock models and textures need the owner's install, where the game already finds them the same way.
- **Load time:** the editor opens DAoW in 6.3 s with models, against 1.9 s without.
