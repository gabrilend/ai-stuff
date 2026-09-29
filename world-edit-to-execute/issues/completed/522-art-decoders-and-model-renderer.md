# Issue 522: WC3's Art, Decoded and Drawn

**Phase:** 5 (rendering), with pieces of 6 (assets)
**Type:** Implementation
**Priority:** High
**Dependencies:** 517 (map scene), 518 (viewer), 112b (game data chain)

---

## Current Behavior

Everything on screen is procedural: box designs for models, colours
guessed from tileset names, vector glyphs for icons. No texture or model
format is read. There's no BLP, MDX or JPEG reader: `.blp` and `.mdl`
appear only as path strings. The asset pipelines (packs, the WoW bridge,
the asset forge) are designs.

## Intended Behavior

- **Decoders:** WC3's own art formats, and the open formats that art-making tools use.
- **Renderer:** draws models with their textures, as the game does.
- **Map:** the map shows each object with its real model where one can be found.
- **ComfyUI:** workflow files that make art for the engine with ComfyUI's own nodes.

| Part | What | Where |
|------|------|-------|
| 522a | JPEG (baseline and progressive), BLP1 (JPEG and paletted, all alpha depths, mipmaps), TGA | `src/parsers/jpeg.lua`, `blp.lua`, `tga.lua` |
| 522b | MDX: every chunk | `src/parsers/mdx.lua` |
| 522c | Textured model renderer, and models onto it | `src/render/models.{c,h}`, `bridge.c`, `scene_viewer.c`, `src/assets/gpu.lua` |
| 522d | Asset source: the map, then the install; which model a type uses | `src/assets/init.lua` |
| 522e | The map drawn with models; a model gallery | `src/demo/wc3map/main.lua`, `scene.lua`, `src/demo/models/main.lua` |
| 522f | ComfyUI workflows, their checker, texture export | `src/assets/comfy.lua`, `comfyui/` |
| 522g | PNG and glTF (GLB) in, GLB out | `src/parsers/png.lua`, `gltf.lua`, `src/assets/tool.lua` |

## Acceptance Criteria

- [x] Every BLP and TGA in the 16 test maps decodes: 287 distinct images, 0 failures
- [x] JPEG and PNG decoders agree with ImageMagick. Details:
  - JPEG: within 3 levels, subsampled colour within 40.
  - PNG: 8-bit exactly, 16-bit within 1.
- [x] Every MDX in the 16 maps parses, every chunk read: 265 distinct models, 0 failures
- [x] Models drawn with their textures, WC3 filter modes and team colour; checked in a model gallery
- [x] The DAoW map draws objects with models when found (the map's imports here; the install's stock models on the owner's machine)
- [x] Six ComfyUI workflows in both shapes, using only core nodes, checked against ComfyUI's source; a checker against a running ComfyUI
- [x] GLB out and back in: the same vertices and triangles, textures embedded
- [x] `test_assets.lua`: 28 tests; full suite passes

## Implementation Notes

**Date:** 2026-09-29

### What the test maps hold

Across the 16 maps:

- 1,185 imported MDX models (265 distinct).
- 1,222 BLP1 textures (285 distinct), plus 2 distinct TGA previews.
- Every file is unnamed (no listfile). The object data names them by path, and the archive's hash finds them.

DAoW 5.4b alone imports 76 models. 30 of them are portraits (interface
heads, not drawn in the world). Most borrow stock textures: only 2 of its
models are complete without the install.

### 522a: images

- **JPEG:**
  - Huffman decoding, the IDCT, any sampling factors, restart intervals.
  - Progressive scans: spectral selection, successive approximation, end-of-band runs.
  - 19 of the maps' BLPs are progressive JPEG, made by modders' tools.
  - Four-component JPEGs (BLP's) are left unconverted: Blizzard stores B, G, R, A directly.
  - Colour that is subsampled is upsampled by repeating samples. libjpeg smooths it instead, so edges differ.
- **BLP1:** the shared JPEG header plus each mipmap's part; or a palette with 0, 1, 4 or 8 alpha bits. BLP2 (WoW's) is left to Phase W.
- **TGA:** 8, 24 and 32 bits, raw or run-length encoded, either origin.

### 522b: MDX

Decoded (version 800, plus the geoset fields later versions add):

- **Mesh and look:**
  - VERS, MODL, SEQS, GLBS.
  - TEXS: replaceable ids, wrap flags.
  - MTLS: layers, filter modes, shading flags, alpha and texture tracks.
  - GEOS: vertices, normals, triangles, vertex groups, matrix groups, UV sets, extents.
- **Animation:**
  - GEOA; BONE and HELP with their tracks; PIVT.
  - `mdx.sample` evaluates tracks: linear and slerp, and Hermite/Bezier taken as linear.
- **Other nodes:**
  - ATCH, EVTS and CLID decoded.
  - CAMS and TXAN decoded.
  - LITE, PREM, PRE2 and RIBB: their node decoded (they're in the hierarchy), their own fields kept raw.

Community models may repeat or skip node ids (one "portrait" gives all 17
bones id 0). The test checks that no node id lies beyond the pivot list.

### 522c: the renderer

C side (`render/models.c`):

- **Uploads:** textures (mipmapped, trilinear), meshes (position, normal, UV, uint16 triangles), models (lists of parts).
- **Instances:** queued each frame from Lua, culled by distance, drawn in the 3D pass after the landscape.
- **Blending:**
  - Opaque and alpha-tested parts first, with depth writes.
  - Blend, additive and modulate after, without them, unsorted.
- **Shader:** a small GLSL 330 one that alpha-tests WC3's "transparent" mode and lights from one direction.
- **Coordinates:** WC3's (Z up), turned into the renderer's in the instance matrix.
- **Build:** compiles against raylib 5.5 and 5.0.

Lua side (`assets/gpu.lua`), one part per geoset and material layer:

- **Hidden geosets:** those hidden at the start of Stand (geoset animation alpha 0) are left out: death and alternate parts.
- **Replaceable textures:**
  - Id 1 is the team colour: a white texture the instance tints.
  - Id 2 is the team glow: a generated soft disc, tinted.
  - Trees and cliffs use the stock replaceable textures when the install has them.
- **Missing textures:**
  - A solid layer gets a neutral grey stand-in.
  - A blended one is left out: a glow or rune without its texture would light up its whole quad.
  - A body whose skin is missing (team colour under a blended skin) is drawn solid grey.
- **Pose:** the model's rest pose; animation isn't played yet.

### 522d/e: where art comes from, and the map

`assets.open(map)` reads the map's archive first, then the install
through `gamedata.chain`:

- **Install location:** `$WC3_INSTALL`, else `wc3-installs/frozen-throne`.
- **Patch layer:** the map's own, else the install unpatched, with a note.

Which model a type uses:

- **The map's object data:** `umdl`, `dfil`, `bfil`, following stock parents.
- **Else the stock tables:** UnitUI, Doodads, DestructableData.
- **Doodad variations:** one file each.
- **Placed doodads:** tried as destructables, then as doodads.

The map viewer (`WC3_MODELS=0` turns this off):

- **Drawing:** units, buildings and doodads with a model draw it; the rest keep their box designs; baking skips what's drawn as a model.
- **Log:** prints how many have models.
- **In this cloud container (no install):** 193 of DAoW 5.4b's 4,379 units and 226 of its 13,561 doodads have models, all the map's imports.
- **On the owner's machine:** the stock models fill in the rest.

`src/demo/models/main.lua` is a gallery:

- **Contents:** every model a map carries, turning slowly; optionally only complete ones (`MODEL_GALLERY_TEXTURED=1`), and glTF files (`MODEL_GALLERY_GLB`).
- **Checked:** on DAoW 5.4b, 39 world models draw. A brick tower and an orc battle-rager draw fully textured, and so do their GLB round trips.

### 522f: ComfyUI

The workflows:

- **Six of them:** icon (512 and 64 × 64), ground tile, portrait art, texture restyle (image to image), texture restyle with Canny ControlNet, model from image (Hunyuan3D 2 → GLB).
- **Formats:** written in both of ComfyUI's shapes by the kanji project's graph writer (`kanji-learning-image-generator/src/028`). Its catalogue gains 12 node types from here.
- **Checked:** every node's sockets and controls, against ComfyUI's source (commit a716932, read only, not installed). That check changed one node: `VoxelToMeshBasic` is deprecated, so `VoxelToMesh` is used.
- **No custom nodes:** only core ComfyUI nodes, and no Python.

Tools:

- `comfy.lua check object_info.json` compares the files with a running ComfyUI.
- `comfy.lua export` and `tool.lua texture` write any map or install texture as PNG for the restyles.
- `comfyui/settings.lua` names the model files.

### 522g: open formats

- **PNG:** every colour type, 1-16 bits, all row filters. It uses the monorepo's own inflate (`kanji…/017a`).
- **glTF:**
  - Reads GLB and `.gltf`: node transforms, triangles, UVs, base colour and textures (PNG or JPEG).
  - Converts Y-up metres to WC3's Z-up units, or fits to a height.
  - Writes GLB with textures embedded.
- **Export:** `tool.lua model` writes any MDX (map or install) as GLB, for Blender and ComfyUI.

### Not yet

- **Animation:** models stand in their rest pose. Sequences, bones and interpolation are parsed; skinning isn't done.
- **Effects:** particle emitters, ribbons, lights and texture animation aren't drawn (their nodes are read).
- **Terrain:** ground textures (the tilesets' BLPs) aren't used yet; the ground is still coloured by keyword.
- **Portraits:** the portrait frame still uses the box designs, not the portrait models.
- **No sound:** audio decoding and playback aren't here (WAV/MP3).
- **Reforged formats:** MDX 900+ materials beyond version 800's, and BLP2/DDS, are not handled.
- **Tested only here:** stock models could only be tested with the maps' imports in this container. The install path is written against `gamedata.chain`, which has its own tests, but hasn't been run against a real install here.
