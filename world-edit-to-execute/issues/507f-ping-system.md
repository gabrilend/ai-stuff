# Issue 507f: Ping System

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 507
**Priority:** Low
**Dependencies:** 507e

---

## Current Behavior

No ping system. Players cannot mark locations on the map for teammates.

---

## Intended Behavior

Visual ping markers with animation and audio:

```lua
-- src/ui/minimap/ping.lua
local ping_system = {}

-- Ping types with colors
local PING_TYPES = {
    alert = {
        color = {255, 255, 0, 255},     -- Yellow
        sound = "ping_alert",
        duration = 3.0,
        size = 12,
    },
    attack = {
        color = {255, 0, 0, 255},       -- Red
        sound = "ping_attack",
        duration = 3.0,
        size = 12,
    },
    defend = {
        color = {0, 200, 255, 255},     -- Cyan
        sound = "ping_defend",
        duration = 3.0,
        size = 12,
    },
    retreat = {
        color = {128, 128, 128, 255},   -- Grey
        sound = "ping_retreat",
        duration = 3.0,
        size = 12,
    },
}

local active_pings = {}
local ping_id_counter = 0

-- Create a new ping
function ping_system.create(world_x, world_y, ping_type, player_id)
    ping_id_counter = ping_id_counter + 1

    local type_data = PING_TYPES[ping_type] or PING_TYPES.alert

    local ping = {
        id = ping_id_counter,
        x = world_x,
        y = world_y,
        type = ping_type,
        color = type_data.color,
        size = type_data.size,
        duration = type_data.duration,
        time_remaining = type_data.duration,
        player_id = player_id,
        phase = 0,  -- Animation phase
    }

    table.insert(active_pings, ping)

    -- Play sound
    if type_data.sound then
        audio.play(type_data.sound)
    end

    -- Notify network (for multiplayer)
    -- network.broadcast_ping(ping)

    return ping.id
end

-- Update all active pings
function ping_system.update(dt)
    for i = #active_pings, 1, -1 do
        local ping = active_pings[i]

        ping.time_remaining = ping.time_remaining - dt
        ping.phase = ping.phase + dt * 6  -- Animation speed

        if ping.time_remaining <= 0 then
            table.remove(active_pings, i)
        end
    end
end

-- Draw pings on minimap
function ping_system.draw_minimap(renderer, minimap)
    for _, ping in ipairs(active_pings) do
        local mx, my = minimap:world_to_minimap(ping.x, ping.y)
        ping_system.draw_ping(renderer, mx, my, ping)
    end
end

-- Draw pings on game view
function ping_system.draw_world(renderer, camera)
    for _, ping in ipairs(active_pings) do
        local sx, sy = camera:world_to_screen(ping.x, ping.y)

        -- Only draw if on screen
        if sx > -50 and sx < screen_width + 50 and
           sy > -50 and sy < screen_height + 50 then
            ping_system.draw_ping(renderer, sx, sy, ping, true)
        end
    end
end

function ping_system.draw_ping(renderer, x, y, ping, is_world_view)
    local base_size = ping.size
    if is_world_view then
        base_size = base_size * 3  -- Larger in world view
    end

    -- Pulsing animation
    local pulse = math.sin(ping.phase) * 0.3 + 1.0
    local size = base_size * pulse

    -- Fade out near end
    local alpha = 255
    if ping.time_remaining < 0.5 then
        alpha = 255 * (ping.time_remaining / 0.5)
    end

    local color = {
        ping.color[1],
        ping.color[2],
        ping.color[3],
        alpha,
    }

    -- Draw concentric circles
    renderer:draw_circle(x, y, size, color, false)
    renderer:draw_circle(x, y, size * 0.7, color, false)

    -- Draw crosshair lines
    local line_len = size * 1.5
    renderer:draw_line(x - line_len, y, x + line_len, y, color, 1)
    renderer:draw_line(x, y - line_len, x, y + line_len, color, 1)

    -- Expanding ring animation
    local ring_phase = (ping.phase % 2) / 2  -- 0 to 1
    local ring_size = base_size + ring_phase * base_size * 2
    local ring_alpha = alpha * (1 - ring_phase)
    local ring_color = {color[1], color[2], color[3], ring_alpha}
    renderer:draw_circle(x, y, ring_size, ring_color, false)
end

-- Clear all pings
function ping_system.clear()
    active_pings = {}
end

-- Get pings (for network sync)
function ping_system.get_active()
    return active_pings
end

return ping_system
```

---

## Suggested Implementation Steps

1. **Define ping types**
   - Alert (yellow, general)
   - Attack (red, offensive)
   - Defend (blue, defensive)
   - Retreat (grey)

2. **Implement ping creation**
   - Store position, type, duration
   - Assign unique ID
   - Add to active list

3. **Implement ping animation**
   - Pulsing size
   - Expanding rings
   - Fade out at end

4. **Draw on minimap**
   - Convert world to minimap coords
   - Small animated marker
   - Color by type

5. **Draw on world view**
   - Draw at world position
   - Larger than minimap version
   - Only if on screen

6. **Add audio feedback**
   - Play sound on ping create
   - Different sounds per type

---

## Acceptance Criteria

- [ ] Pings appear at correct world position
- [ ] Pings visible on both minimap and world
- [ ] Pulsing animation plays
- [ ] Pings fade and disappear after duration
- [ ] Different ping types have different colors
- [ ] Audio plays on ping creation

---

## Notes

Pings are essential for team communication in RTS games. They should be noticeable but not distracting.

**WC3 ping behavior:**
- Alt+G or minimap alt-click
- Yellow animated marker
- Beep sound
- Visible to all allies
- Disappears after ~3 seconds

**Animation:**
- Concentric rings
- Pulsing center
- Expanding outer ring
- Gradual fade

---

## Related Documents

- issues/507e-minimap-interaction.md (ping trigger)
- issues/507a-minimap-module.md (parent component)
- issues/508-audio-system.md (ping sounds - future)
