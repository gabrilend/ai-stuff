# Issue 526: Ground Textures

**Phase:** 5 (rendering)
**Type:** Implementation
**Priority:** High
**Dependencies:** 517b (landscape), 522 (BLP decoding, the asset source); related: 502a (terrain renderer, planned)

---

## Current Behavior

The ground is flat-shaded colour: each cell gets a colour guessed from its
tileset's id (grass green, dirt brown ...), steep triangles a rock colour.
The tilesets' own textures (BLP files in the install) aren't used, and
there is no blending between tilesets: each cell is one colour.

## Intended Behavior

The ground is drawn as WC3 draws it:

- **Textures:** each tileset's texture, from the install (or the map's import of it).
- **Blending:** where tilesets meet, the higher one is drawn over the lower with WC3's corner shapes: the blend masks painted into each tileset's texture.
- **Variations:** whole cells use the tile point's variation.
- **Stand-ins:** without the install, stand-in textures in the same layout, so the blending still shows.

## Suggested Implementation Steps

1. Per cell: its corners' tilesets, lowest first. The lowest is drawn whole (by variation); each higher one as the subtile for the corners it's on.
2. The renderer: a textured mesh per chunk per tileset, drawn in order over the land with alpha blending, shaded like the land.
3. Tile paths from `TerrainArt\Terrain.slk`; the textures through the asset source.
4. Stand-in tilesets drawn in WC3's extended layout.
5. Tests; screenshots.

## Acceptance Criteria

- [x] `render.land_tiles(textures, cells)`: up to 16 tileset layers over the landscape, drawn lowest first with alpha blending, flat-shaded like the land; builds against raylib 5.5 and 5.0
- [x] Per cell, up to four (tileset, subtile) pairs: the lowest tileset whole (plain: subtile 15; extended: the whole variations from the tile point's variation), the others by corner bits
- [x] Tileset textures from `TerrainArt\Terrain.slk` through the asset source (the map's import first); stand-ins in the same 512 × 256 layout without them
- [x] Cliff cells (corners on different cliff levels, no ramp) and blight keep the landscape's colours; slopes are textured
- [x] The map viewer logs where each tileset came from; `WC3_TILES=0` for plain colours, `WC3_TILES=standin` to force stand-ins
- [x] `test_ground.lua`: 26 tests; full suite passes

## Implementation Notes

**Date:** 2026-09-30

### The layout (`assets/ground.lua`)

The texture:

- **Grid:** a tileset texture is 4 × 4 subtiles (256 × 256), or 8 × 4 when extended (512 × 256). Subtiles are a quarter of the height square, north at the top.
- **Left half:** subtiles 0–15 are the corner shapes. Subtile n covers the corners whose bits are in n: south-east 1, south-west 2, north-east 4, north-west 8. That is `ground.BITS`, as the published map viewers read the tilesets. 15 is the whole tile.
- **Right half** (extended tilesets): 16 whole variations.

Per cell:

- **Order:** its four corners' tilesets, distinct, lowest index first (the map's tileset order is the layering order).
- **The lowest,** drawn whole, from the south-west tile point's variation v (5 bits):
  - Extended tilesets: v < 16 gives subtile 16 + v; v = 16 gives 15; above that, 0.
  - Plain tilesets: v = 0 gives 15; otherwise 0.
- **Each higher tileset:** the subtile of the corners it's on.
- **Encoding:** 8 bytes a cell (four pairs, 255 ends the list), handed to the renderer.

Sources and skipped cells:

- **The install's:** `TerrainArt\Terrain.slk`'s `dir` and `file`, plus `.blp`, read through the asset source (the map's own file at that path first, as for all art).
- **Stand-ins** (`ground.standin`):
  - The tileset's colour (`demo/wc3map/scene.lua`'s keyword colours), with value noise that joins across subtiles.
  - The corner shapes: the bilinear coverage of the set corners, with ragged edges.
  - Whole variations shaded a little apart.
  - Drawn by the same `ground.BITS`, so they always blend right. All 16 for DAoW take 0.44 s.
- **Skipped cells:** cliffs (corners on different cliff levels, not a ramp; WC3 draws cliffs as models) and blighted cells keep the landscape's colours.

### The renderer (`render/landscape.c`)

- **Keeps what it was given:** `land_build` now keeps the heights and the grid, for `land_tiles`.
- **Meshes:** `land_tiles(textures, cells)` builds, per chunk (32 × 32 cells) and per tileset, one mesh with texture coordinates (inset half a texel against bleeding) and the land's flat shading as vertex colours.
- **Drawing:** after each chunk's coloured land, its tileset meshes, lowest first, alpha-blended. The depth test is less-or-equal, so the coplanar layers stack.
- **Textures:** they come from the model renderer's texture list (`models_texture`), clamped.

### Checked

- **Screenshots of DAoW 5.4b:**
  - Grass, dirt, road and rock stand-ins blending at the base.
  - Hills textured once cliff levels, not steepness, decided what is a cliff.
  - The same view in plain colours for comparison.
- **Size on DAoW 5.4b:** 225,790 cells textured, 652,932 triangles in the layers.

### Not yet

- **Checked against real tiles:** the corner bits have only been checked against the stand-ins, which follow the same rule. If the install's tiles show their blends mirrored or rotated, `ground.BITS` is the one table to change.
- **Cliffs:** cliff models and textures (Cliff0/Cliff1 per tileset): cliffs are still rock-coloured slopes.
- **Blight,** and the terrain texture changes a script makes (SetTerrainType).
- **Minimap:** it still uses the keyword colours.
- **Water** is still flat colour.
