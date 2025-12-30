# Issue 507b: Terrain Texture

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 507
**Priority:** High
**Dependencies:** 507a, 502

---

## Current Behavior

No minimap terrain rendering. Minimap shows only black background.

---

## Intended Behavior

Pre-rendered terrain texture for minimap:

```lua
-- src/ui/minimap/terrain_texture.lua
local terrain_texture = {}

-- Color mapping for terrain types
local TERRAIN_COLORS = {
    -- Lordaeron Summer
    ["Ldrt"] = {100, 80, 60, 255},    -- Dirt
    ["Lgrs"] = {80, 140, 60, 255},    -- Grass
    ["Lrok"] = {100, 100, 100, 255},  -- Rock
    ["Lgrd"] = {60, 100, 40, 255},    -- Dark Grass

    -- Water types
    ["Lwtr"] = {40, 80, 160, 255},    -- Shallow Water
    ["Ldwt"] = {20, 40, 120, 255},    -- Deep Water

    -- Special
    ["Lbld"] = {30, 30, 30, 255},     -- Blight
    ["cBc2"] = {80, 80, 80, 255},     -- Cityscape

    -- Default
    default = {60, 60, 60, 255},
}

-- Height-based color modifier
local function apply_height_shading(color, height, min_h, max_h)
    local range = max_h - min_h
    if range == 0 then return color end

    local factor = 0.7 + 0.6 * ((height - min_h) / range)
    return {
        math.min(255, color[1] * factor),
        math.min(255, color[2] * factor),
        math.min(255, color[3] * factor),
        color[4],
    }
end

-- Generate minimap texture from terrain data
function terrain_texture.generate(w3e_data, width, height)
    local texture = {}
    texture.width = width
    texture.height = height
    texture.pixels = {}

    local terrain_width = w3e_data.width
    local terrain_height = w3e_data.height
    local tiles = w3e_data.tiles

    -- Find height range for shading
    local min_height, max_height = math.huge, -math.huge
    for _, tile in ipairs(tiles) do
        min_height = math.min(min_height, tile.height)
        max_height = math.max(max_height, tile.height)
    end

    -- Sample terrain at each minimap pixel
    for my = 0, height - 1 do
        for mx = 0, width - 1 do
            -- Map minimap pixel to terrain tile
            local tx = math.floor((mx / width) * terrain_width)
            local ty = math.floor((my / height) * terrain_height)

            local tile_index = ty * terrain_width + tx + 1
            local tile = tiles[tile_index]

            if tile then
                local terrain_type = tile.ground_type
                local base_color = TERRAIN_COLORS[terrain_type]
                                   or TERRAIN_COLORS.default

                local color = apply_height_shading(
                    base_color, tile.height, min_height, max_height
                )

                -- Check for water
                if tile.water_level > tile.height then
                    color = TERRAIN_COLORS["Lwtr"]
                end

                -- Check for cliff (large height difference)
                if tile_index > 1 then
                    local prev = tiles[tile_index - 1]
                    if prev and math.abs(tile.height - prev.height) > 128 then
                        color = TERRAIN_COLORS["Lrok"]  -- Cliff color
                    end
                end

                texture.pixels[my * width + mx + 1] = color
            else
                texture.pixels[my * width + mx + 1] = {0, 0, 0, 255}
            end
        end
    end

    return texture
end

-- Render texture to minimap
function terrain_texture.draw(renderer, texture, x, y)
    for py = 0, texture.height - 1 do
        for px = 0, texture.width - 1 do
            local color = texture.pixels[py * texture.width + px + 1]
            if color then
                renderer:draw_rect(x + px, y + py, 1, 1, color, true)
            end
        end
    end
end

-- Optimized: batch into image data
function terrain_texture.create_image(texture)
    -- Backend-specific: create drawable texture
    -- For LÖVE2D: love.image.newImageData + love.graphics.newImage
    -- For SDL: SDL_CreateTexture with pixel data
    return nil  -- Placeholder
end

return terrain_texture
```

---

## Suggested Implementation Steps

1. **Define terrain color palette**
   - Map terrain type codes to colors
   - Include all WC3 terrain types
   - Consistent with actual terrain appearance

2. **Implement terrain sampling**
   - Map minimap pixels to terrain tiles
   - Handle non-square maps

3. **Add height shading**
   - Brighter for higher terrain
   - Darker for lower terrain
   - Creates depth impression

4. **Handle special tiles**
   - Water (blue)
   - Cliffs (dark rock)
   - Blight (dark purple/black)
   - Buildings (grey)

5. **Pre-render to texture**
   - Generate once on map load
   - Cache for reuse
   - Re-generate on terrain change

6. **Optimize rendering**
   - Use image data instead of per-pixel draws
   - Only update changed regions

---

## Acceptance Criteria

- [ ] Terrain types render with appropriate colors
- [ ] Height shading visible on hills/valleys
- [ ] Water areas clearly blue
- [ ] Cliffs visible as dark lines
- [ ] Texture generates at correct resolution
- [ ] Pre-rendered texture cached

---

## Notes

The minimap terrain should be recognizable at a glance. Color choices matter.

**WC3 minimap colors (approximate):**
- Grass: Green (#5A8C3C)
- Dirt: Brown (#6B5A4A)
- Rock: Grey (#7B7B7B)
- Water: Blue (#2850A0)
- Trees: Dark green (may show as dots)
- Buildings: Team color dots

**Resolution:**
Minimap texture should be same size as display (200x200). Sampling terrain at this resolution provides good detail without excess computation.

---

## Related Documents

- issues/507a-minimap-module.md (parent component)
- issues/502-implement-terrain-rendering.md (terrain data structure)
- issues/105-parse-war3map-w3e.md (terrain file format)
