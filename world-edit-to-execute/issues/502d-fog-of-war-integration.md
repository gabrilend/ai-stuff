# Issue 502d: Fog of War Integration

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 502
**Priority:** Medium
**Dependencies:** 502a

---

## Current Behavior

No fog of war rendering. All terrain is fully visible regardless of player's explored/visible state.

---

## Intended Behavior

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

## Suggested Implementation Steps

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

## Acceptance Criteria

- [ ] Unexplored tiles are black
- [ ] Explored-but-not-visible tiles are darkened
- [ ] Visible tiles show at full brightness
- [ ] Fog updates when units move
- [ ] Fog respects player's vision
- [ ] Can toggle fog for debugging

---

## Notes

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

## Related Documents

- issues/502a-core-terrain-renderer.md (base rendering)
- issues/407-create-player-state-management.md (player ownership)
- src/runtime/systems/ (vision system if exists)
