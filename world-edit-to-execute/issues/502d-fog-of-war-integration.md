# Issue 502d: Fog of War Integration

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 502
**Priority:** Medium
**Dependencies:** 502 (chunk meshes); a visibility system in the runtime (no issue yet)
**Re-cut:** 2026-09-26, from "Fog of War Integration"

---

## Current Behavior

Nothing is hidden. The runtime (`src/runtime/`) has no visibility system:
nothing records what each player sees or has seen, so there is nothing for
the renderer to show.

## Intended Behavior

The backend works out, per player, which cells are visible now, explored
before, or never seen (units' sight radii, blocked by terrain height as WC3
does). The page carries that as a small texture, one texel per cell; the
renderer darkens explored cells and blacks out unexplored ones, over the
terrain and over units. Units in unexplored or fogged cells are left off
the page for that player.

The visibility system is game logic, not rendering: it belongs in the
runtime with its own issue (Phase 4, or the gameplay mechanics that Phase 7
listed). Fog also matters to the network (803): a player's client should
not be sent what that player can't see.

## Suggested Implementation Steps

1. An issue for the runtime's visibility system (sight, line of sight by
   height, explored memory).
2. The fog texture on the page.
3. Darkening in the renderer; hidden units left off the page.

## Acceptance Criteria

- [ ] A player sees only around their units; explored ground stays dim
- [ ] Hidden enemy units are not drawn
- [ ] The visibility system has its own issue and tests

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

No fog of war rendering. All terrain is fully visible regardless of player's explored/visible state.

---

### Intended Behavior

Integrate fog of war with terrain rendering:

```lua
-- Visibility states per tile
local VISIBILITY = {
    UNEXPLORED = 0,  -- Never seen (black)
    EXPLORED = 1,    -- Seen before but not now (darkened)
    VISIBLE = 2,     -- Currently in view (full brightness)
}

-- Draw terrain with fog overlay
function terrain.draw_with_fog(renderer, camera, player)
    for each visible tile do
        local visibility = get_tile_visibility(player, x, y)

        if visibility == VISIBILITY.UNEXPLORED then
            -- Draw black
            renderer:draw_rect(sx, sy, sw, sh, BLACK, true)
        elseif visibility == VISIBILITY.EXPLORED then
            -- Draw darkened terrain
            terrain.draw_tile(renderer, camera, x, y, tile)
            renderer:draw_rect(sx, sy, sw, sh, FOG_OVERLAY, true)
        else
            -- Draw full brightness
            terrain.draw_tile(renderer, camera, x, y, tile)
        end
    end
end
```

**Fog Colors:**
```lua
BLACK = {0, 0, 0, 255}           -- Unexplored
FOG_OVERLAY = {0, 0, 0, 128}     -- 50% darkening for explored
```

---

### Suggested Implementation Steps

1. **Create visibility grid**
   ```lua
   -- Per-player visibility state
   local visibility = {
       [player_id] = {
           -- 2D grid of VISIBILITY enum
       }
   }
   ```

2. **Integrate with player visibility system**
   - Connect to Phase 4 player/vision systems
   - Update visibility when units move
   - Mark tiles explored when first seen

3. **Implement three-state rendering**
   - Unexplored: solid black overlay
   - Explored: semi-transparent dark overlay
   - Visible: no overlay

4. **Add smooth fog edges (optional)**
   - Gradient at visibility boundaries
   - Less jarring than hard edges

5. **Optimize fog updates**
   - Only recalculate when visibility changes
   - Cache fog overlay as texture if supported

6. **Add fog toggle**
   - terrain.show_fog = true/false
   - Useful for map editor / cheat mode

---

### Acceptance Criteria

- Unexplored tiles are black
- Explored-but-not-visible tiles are darkened
- Visible tiles show at full brightness
- Fog updates when units move
- Fog respects player's vision
- Can toggle fog for debugging

---

### Notes

Fog of war is crucial for competitive play. Without it, all player positions are known.

**WC3 fog behavior:**
- Units reveal area around them (sight range)
- Buildings reveal statically
- Revealed areas stay "explored" (show terrain, not units)
- Flying units often have larger sight range

**Performance consideration:**
Fog can be expensive to update every frame. Consider:
- Update only when units move
- Use dirty flags for changed regions
- Render fog to texture, update incrementally

---

### Related Documents

- issues/502a-core-terrain-renderer.md (base rendering)
- issues/407-create-player-state-management.md (player ownership)
- src/runtime/systems/ (vision system if exists)

## Implementation Notes

**Date:** 2026-09-29

Done as part of issue 524 (`issues/completed/524-fog-of-war.md`). How it differs from the plan above:

- **One pass for everything:** fog is not drawn over the terrain alone. The 3D view is drawn into a texture, and a last pass (`render/fog.c`) darkens every pixel by the fog at its place on the ground. Terrain, doodads and models are all shaded, whatever drew them.
- **Where visibility lives:** it is worked out in `demo/wc3map/vision.lua`, not in the renderer.
