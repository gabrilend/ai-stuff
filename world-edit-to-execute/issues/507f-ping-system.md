# Issue 507f: Ping System

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 507
**Priority:** Low
**Dependencies:** 507a, 803 (the gameplay messages)
**Re-cut:** 2026-09-26, from "Ping System" (it waited on Phase 7 networking, now archived; the messages are 803's)

---

## Current Behavior

No minimap and no pings. Messages between players and the host are built
(803), with no ping message among them.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #320 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- `PingMinimapForForceEx` treats any style other than 2 as a ping; Blizzard.j ignores styles other than 0, 1 and 2, so maps can show pings the game never would.
- Percent-to-0-255 colour conversion rounds; Blizzard.j truncates (50% is 127 in the game, 128 here, and the test asserts 128).
- The ping rate limit is judged by arrival time, and one batch of arrivals shares a time, so pings sent 300 ms apart can be refused under link delay.
- The list of showing pings compares trigger pings (game clock) and heard pings (caller's clock) against one `now`; heard pings freeze during pause, or trigger pings come out wrong.
- Every refused ping adds an entry to the server's refusal list, which is never trimmed; a client holding the ping key grows it without limit.
- Missing values silently become defaults (a null location pings the map centre), and the test locks that in.
- The drop-expired and append-capped steps are each written two or three times with separate limits.
- `src/ui/wc3/pings.lua` has no info file; this issue's Current Behavior still says there is no ping message; it carries a fixed check count.

## Intended Behavior

A player pings a point (Alt-click on the minimap or the world): a pulsing
marker on the minimap and in the world for that player's allies, with a
sound. Triggers can ping too (`PingMinimap` natives, Phase 3). The ping is
a message through the host (803), sent only to allies.

## Suggested Implementation Steps

1. A ping message in 803's set.
2. The marker on the minimap and in the world, fading out.
3. Trigger natives wired to it.

## Acceptance Criteria

- [ ] An ally sees another player's ping
- [ ] A trigger's ping shows

## Progress (2026-11-06)

Built and tested without a window (`src/tests/test_pings.lua`, 92
checks); the drawing is not built:

- Step 1: `ping` (12, client to server) and `pinged` (13, server to client)
  in `net/messages.lua`; the server's `takes.ping` sends each ping at once
  to the pinger and their allies; `link.ping(x, y)` in
  `net/renderer_link.lua` for the renderer.
- Step 3: the `PingMinimap` natives (`PingMinimap`, `PingMinimapEx`,
  `PingMinimapForForce`, `PingMinimapLocForForce`, `PingMinimapForForceEx`)
  are no longer no-ops; they keep pings on the VM as `V.pings`, which
  `V:tick` drops when their time is up.
- Step 2, the part with no drawing: `ui/wc3/pings.lua` keeps the players'
  pings heard from `pinged` messages and says, for every ping showing
  (trigger or player), its point, colour, how faded it is and how far its
  ring has spread. Drawing it on the minimap (507a's module, PR #316) and
  in the world view needs raylib and is left for that wiring; the sound
  waits on 508.

Neither box is ticked: both say a player *sees* the ping, which needs the
drawing.

### Decisions (2026-11-06)

- **The messages carry only the point.** `ping` is `{x, y}` in world
  units; `pinged` adds the tick it was made on and who pinged. There are
  no ping kinds (the January design's alert/attack/defend/retreat): the
  game has one player ping, and a trigger's colour comes with its native.
- **Allies are the game's to say.** The server asks the simulation's
  optional `sim.allied(a, b)`. A game that has no such function sends a
  ping back to its own player only, so no position reaches an enemy by
  default. Dropped players hear nothing.
- **At most one ping every 250 ms per player** (`server.PING_EVERY_MS`).
  Faster ones are refused and recorded in `server.refused` like any other
  refused message; a refused ping doesn't restart the wait.
- **Pings go through while the game is paused**, unlike orders: talking
  to allies is most of what a paused player can do.
- **A ping at a point that isn't a finite number is refused**, so a
  NaN or infinity never reaches another player's minimap.
- **A player's ping shows for 3 seconds, in yellow**, as the January
  notes have the game's ("Yellow animated marker", "Disappears after ~3
  seconds"). Showing it in the pinger's colour instead is a one-line
  change (`pings.PLAYER_COLOUR`) if Ritz prefers.
- **Trigger pings follow Blizzard.j.** `PingMinimap` and `PingMinimapEx`
  ping the local minimap (every player's game runs them); the ForForce
  ones only when the local player is in the force. `PingMinimap` is
  yellow. Ex colours are held to 0-255; ForForceEx's percent colours are
  turned to 0-255 by `percent * 255 / 100`, rounded. Style 0 is simple, 1
  flashy, 2 attack (pure red whatever colour is given), and a pure red
  simple or flashy ping is made 254 red so it doesn't become an attack
  ping, as Blizzard.j does.
- **An attack ping is pure red and not flashing**, as in the game, and is
  marked `attack` for the drawing side to give it its own look.
- **The look:** solid, then fading over its last half second; an
  expanding ring every second (every half second when flashy). These are
  `pings.FADE_SECONDS`, `RING_SECONDS` and `FLASHY_RING_SECONDS`.
- **At most 16 pings are kept** on the VM (`vm.PINGS_KEPT`) and among
  heard player pings (`pings.KEPT`); the oldest goes first. A ping given
  no time shows for 3 seconds (`vm.PING_SECONDS`).

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

No ping system. Players cannot mark locations on the map for teammates.

---

### Intended Behavior

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

### Suggested Implementation Steps

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

### Acceptance Criteria

- Pings appear at correct world position
- Pings visible on both minimap and world
- Pulsing animation plays
- Pings fade and disappear after duration
- Different ping types have different colors
- Audio plays on ping creation

---

### Notes

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

### Related Documents

- issues/507e-minimap-interaction.md (ping trigger)
- issues/507a-minimap-module.md (parent component)
- issues/508-audio-system.md (ping sounds - future)
