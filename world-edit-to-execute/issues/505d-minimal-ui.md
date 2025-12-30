# Issue 505d: Minimal UI

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 505
**Priority:** Medium
**Dependencies:** 505b, 506

---

## Current Behavior

No UI elements. Players cannot see resources, selected unit info, or game time.

---

## Intended Behavior

Minimal but functional game UI:

```lua
-- src/ui/game_ui.lua
local game_ui = {}

-- Layout (WC3-style)
--  ┌─────────────────────────────────┐
--  │ Gold: 500  Lumber: 200  12:34   │  <- Resource bar
--  ├─────────────────────────────────┤
--  │                                 │
--  │        Game View                │
--  │                                 │
--  ├───────┬───────────┬─────────────┤
--  │Minimap│ Unit Info │ Commands    │  <- Bottom panels
--  └───────┴───────────┴─────────────┘

function game_ui.draw(renderer, player, selection)
    -- Top: Resources
    game_ui.draw_resources(renderer, player)

    -- Bottom Left: Minimap placeholder
    game_ui.draw_minimap_frame(renderer)

    -- Bottom Center: Selected unit info
    game_ui.draw_unit_info(renderer, selection)

    -- Bottom Right: Command buttons (placeholder)
    game_ui.draw_command_panel(renderer)

    -- Game time
    game_ui.draw_time(renderer)
end

function game_ui.draw_resources(renderer, player)
    local y = 5
    renderer:draw_text(10, y, "Gold: " .. player.gold, 16, GOLD_COLOR)
    renderer:draw_text(100, y, "Lumber: " .. player.lumber, 16, LUMBER_COLOR)
    renderer:draw_text(200, y, "Food: " .. player.food_used .. "/" .. player.food_cap, 16, WHITE)
end
```

---

## Suggested Implementation Steps

1. **Create resource bar**
   - Gold with gold color
   - Lumber with green color
   - Food as used/max
   - Supply warning (red when near cap)

2. **Create unit info panel**
   - Portrait area (placeholder shape)
   - Unit name
   - HP/MP bars
   - Attack/armor stats

3. **Create command panel placeholder**
   - 3x4 grid of buttons
   - Placeholder icons (letters or shapes)
   - Click areas defined

4. **Create minimap frame**
   - Just the border for now
   - Actual minimap from 507

5. **Add game time display**
   - Minutes:seconds format
   - Top-right corner

6. **Style consistently**
   - Dark background panels
   - Light text
   - Consistent margins

---

## Acceptance Criteria

- [ ] Resource bar shows gold/lumber/food
- [ ] Resources update when values change
- [ ] Unit info panel shows selected unit
- [ ] Command panel area reserved
- [ ] Game time displays correctly
- [ ] UI doesn't overlap game view

---

## Notes

This is "minimal" UI - enough to play but not polished. Full UI comes from 506.

**Layout priorities:**
1. Resources always visible
2. Game view as large as possible
3. Bottom panels sized appropriately

---

## Related Documents

- issues/506-build-ui-framework.md (full UI system)
- issues/505b-wire-render-systems.md (renders after game view)
- issues/407-create-player-state-management.md (player resources)
