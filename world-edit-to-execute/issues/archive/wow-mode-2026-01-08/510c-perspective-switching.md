# Issue 510c: Perspective Switching

**Phase:** 5 - Rendering
**Type:** Feature
**Priority:** Medium
**Dependencies:** 510a (Warlord UI), 510b (Hero UI)

---

## Current Behavior

No concept of perspective modes or switching between them.

---

## Intended Behavior

Seamless transitions between Warlord (RTS) and Hero (RPG) perspectives, including
camera transitions, UI morphing, and control scheme adaptation.

---

## Switching Modes

### Trigger Methods

```lua
PERSPECTIVE_TRIGGERS = {
    -- Explicit toggle
    hotkey = "F5",  -- Press to toggle

    -- Zoom-based automatic
    zoom_threshold = {
        to_hero = 0.5,    -- Zoom in past 50% → Hero mode
        to_warlord = 2.0, -- Zoom out past 200% → Warlord mode
    },

    -- Selection-based
    selection = {
        hero_only = "suggest_hero_mode",  -- Prompt when only hero selected
        army = "suggest_warlord_mode",    -- Prompt when multiple units
    },

    -- Map-defined
    map_zones = {
        -- Certain zones force a perspective
        dungeon = "hero",
        battlefield = "warlord",
    },
}
```

### Transition Animation

```
WARLORD MODE                              HERO MODE
                    ┌───────────┐
    ┌─────────┐     │ TRANSITION│     ┌─────────┐
    │ Bird's  │────▶│           │────▶│ Third   │
    │   Eye   │     │  Camera   │     │ Person  │
    │  View   │     │  Lerp     │     │  View   │
    └─────────┘     │           │     └─────────┘
                    │ UI Morph  │
    ┌─────────┐     │           │     ┌─────────┐
    │ Command │────▶│  Crossfade│────▶│ Action  │
    │  Grid   │     │           │     │  Bar    │
    └─────────┘     │           │     └─────────┘
                    │           │
    ┌─────────┐     │ Controls  │     ┌─────────┐
    │ Click   │────▶│  Remap    │────▶│  WASD   │
    │ Select  │     │           │     │  Move   │
    └─────────┘     └───────────┘     └─────────┘
```

---

## Camera Transition

```lua
function transition_camera(from_mode, to_mode, duration)
    local duration = duration or 1.0  -- 1 second default

    if to_mode == "hero" then
        -- Zoom into hero character
        local hero = get_player_hero()
        local start_pos = camera.position
        local end_pos = hero.position + HERO_CAMERA_OFFSET

        local start_zoom = camera.zoom
        local end_zoom = HERO_ZOOM_LEVEL  -- Close in

        local start_angle = camera.angle
        local end_angle = hero.facing + OVER_SHOULDER_OFFSET

        tween(duration, function(t)
            camera.position = lerp(start_pos, end_pos, ease_out_cubic(t))
            camera.zoom = lerp(start_zoom, end_zoom, ease_out_cubic(t))
            camera.angle = lerp_angle(start_angle, end_angle, ease_out_cubic(t))
        end)

    elseif to_mode == "warlord" then
        -- Pull back to bird's eye
        local start_pos = camera.position
        local end_pos = {camera.position.x, camera.position.y, WARLORD_HEIGHT}

        local start_zoom = camera.zoom
        local end_zoom = WARLORD_ZOOM_LEVEL  -- Pull back

        local start_angle = camera.angle
        local end_angle = ISOMETRIC_ANGLE  -- 60 degrees typical

        tween(duration, function(t)
            camera.position = lerp(start_pos, end_pos, ease_out_cubic(t))
            camera.zoom = lerp(start_zoom, end_zoom, ease_out_cubic(t))
            camera.angle = lerp_angle(start_angle, end_angle, ease_out_cubic(t))
        end)
    end
end
```

---

## UI Morphing

### Element Mapping

When switching perspectives, some UI elements transform:

| Warlord Element | Hero Element | Transition |
|-----------------|--------------|------------|
| Command Grid (12 btn) | Action Bar (12 btn) | Slide + reflow |
| Unit Portrait | Player Frame | Expand + add bars |
| Multi-select Icons | (disappears) | Fade out |
| Minimap (square) | Minimap (circle) | Morph shape |
| Resource Bar | (moves to char panel) | Slide out |
| (none) | Target Frame | Fade in |
| (none) | Quest Tracker | Slide in |

### Morph Animation

```lua
function morph_ui(from_mode, to_mode, duration)
    -- Fade out exclusive elements
    local fade_out = get_exclusive_elements(from_mode)
    for _, element in ipairs(fade_out) do
        tween(duration * 0.5, function(t)
            element.alpha = 1 - t
        end)
    end

    -- Transform shared elements
    local transforms = get_element_transforms(from_mode, to_mode)
    for _, transform in ipairs(transforms) do
        tween(duration, function(t)
            transform.element.position = lerp(
                transform.from_pos,
                transform.to_pos,
                ease_in_out_cubic(t)
            )
            transform.element.size = lerp(
                transform.from_size,
                transform.to_size,
                ease_in_out_cubic(t)
            )
        end)
    end

    -- Fade in new elements
    local fade_in = get_exclusive_elements(to_mode)
    for _, element in ipairs(fade_in) do
        element.alpha = 0
        after(duration * 0.5, function()
            tween(duration * 0.5, function(t)
                element.alpha = t
            end)
        end)
    end
end
```

---

## Control Scheme Adaptation

### Input Remapping

```lua
CONTROL_SCHEMES = {
    warlord = {
        -- Mouse-driven
        left_click = "select_unit",
        right_click = "smart_order",
        middle_drag = "pan_camera",
        scroll = "zoom",

        -- Keyboard
        ["1-9"] = "control_group",
        ["Q-V"] = "command_buttons",
        tab = "cycle_subgroup",
        space = "center_on_alert",
    },

    hero = {
        -- WASD movement
        w = "move_forward",
        a = "strafe_left",
        s = "move_backward",
        d = "strafe_right",
        space = "jump",

        -- Mouse
        left_click = "target",
        right_click = "auto_attack",
        middle_drag = "rotate_camera",
        scroll = "zoom",

        -- Keyboard
        ["1-0,-,="] = "action_bar_1",
        ["shift+1-0"] = "action_bar_2",
        tab = "target_nearest_enemy",
    },
}

function on_perspective_change(new_mode)
    input.clear_bindings()
    input.apply_scheme(CONTROL_SCHEMES[new_mode])
end
```

### Cursor Changes

```lua
CURSORS = {
    warlord = {
        default = "gauntlet",
        over_enemy = "sword",
        over_friendly = "hand",
        over_ground = "move",
        over_resource = "gather",
    },

    hero = {
        default = "pointer",
        over_enemy = "attack",
        over_npc = "talk",
        over_loot = "loot_bag",
        over_interactable = "gear",
    },
}
```

---

## State Preservation

When switching modes, preserve:

```lua
function preserve_state_across_switch()
    return {
        -- Selection
        selected_units = get_selected_units(),  -- Remember selection
        control_groups = get_control_groups(),  -- Persist groups

        -- Camera
        last_warlord_camera = camera.save_state(),
        last_hero_camera = camera.save_state(),

        -- UI
        open_windows = get_open_windows(),  -- Reopen after switch
        chat_state = chat.save_state(),

        -- Hero-specific
        action_bar_config = action_bars.save_config(),
        target = get_current_target(),
    }
end
```

---

## Mode Indicator

```lua
-- Visual indicator of current mode
mode_indicator = {
    position = "top_center",
    show_during_transition = true,

    warlord = {
        icon = "commander_icon",
        text = "Warlord",
        color = "gold",
    },

    hero = {
        icon = "character_icon",
        text = "Hero",
        color = "blue",
    },

    -- Only show briefly after switching
    auto_hide_delay = 3.0,
}
```

---

## Edge Cases

### What Happens When...

| Scenario | Behavior |
|----------|----------|
| Switch to Hero but hero is dead | Switch anyway, show ghost/spirit mode |
| Switch to Warlord but no army | Allow, but show "no units" message |
| Enemy attacks during transition | Complete transition, then respond |
| Mid-ability-cast switch | Complete ability, then switch |
| Hero in dungeon (forced Hero mode) | Block switch, show "Cannot switch here" |
| Map forces Warlord mode | Block switch, show "Commander mode required" |

---

## Acceptance Criteria

- [ ] F5 (or configured key) toggles perspective
- [ ] Camera transitions smoothly between views
- [ ] UI elements morph/fade appropriately
- [ ] Control scheme changes on switch
- [ ] Cursor updates for current mode
- [ ] Selection state preserved across switch
- [ ] Camera state preserved (return to same view)
- [ ] Mode indicator appears briefly after switch
- [ ] Map-forced modes are respected
- [ ] Edge cases handled gracefully
- [ ] Unit tests for state preservation

---

## Notes

The transition should feel like "zooming into" your hero or "pulling back" to see
the battlefield. It's a shift in perspective, not a loading screen or mode change.

Think of it like Google Maps: you can zoom from satellite view (Warlord) to street
view (Hero) seamlessly. The world is continuous; only your viewpoint changes.

**Narrative justification**: As a commander, you can choose to experience the battle
from your war room (Warlord) or to lead from the front (Hero). Thrall can command
the Horde's armies OR personally charge into the fray.

