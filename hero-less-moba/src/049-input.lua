-- hero-less-moba — a lane-pushing game with the heroes subtracted out
-- Copyright (C) 2026 gabrilend
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU Affero General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or (at
-- your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero
-- General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/>.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

-- 049-input.lua
--
-- Clicks and keys in, camera motion and command records out. Nothing else.
--
-- This file is allowed to move the camera, because the camera is not world state
-- -- it is where a person is looking, and nobody else needs to know. It is **not**
-- allowed to touch a chest, a slot, a body, or a structure. Everything it wants
-- the world to do, it asks for by putting a command in the queue and waiting for
-- the next tick to apply it, exactly as a bot or a replay would.
--
-- Keeping that line means every bug has a side. If a frontline moved wrong, this
-- file is innocent, because it cannot move a frontline.
--
-- ## The two gestures that matter
--
-- **The wheel zooms to the cursor.** Not to the centre of the screen. A player
-- puts the cursor on the fight they want to read and turns the wheel.
--
-- **An upgrade is placed by dragging it onto the thing it should affect** -- a
-- lane in the world, or a tower in the world -- rather than by picking it out of
-- one menu and picking a destination out of another. The chest and the lanes are
-- the two things a player's eyes move between constantly, so a placement should
-- be a short drag and not a trip across the screen.

local M = {}

-- How near the cursor has to be to a lane, in paces, for a drop to land on it.
-- Generous, because a lane is a long thin thing and a player aiming at one is
-- aiming at a corridor rather than at a point.
local LANE_DROP_REACH = 90

-- How near a tower, in paces. Tighter than a lane, because a tower sits *on* a
-- lane and the two targets overlap -- so the tower has to win only when the
-- cursor is genuinely on it.
local STONE_DROP_REACH = 46

-- {{{ function M.create()
-- The input state: what is held, what is being dragged, which team is being
-- watched.
function M.create()
  return {
    -- The upgrade kind riding the cursor, or 0 for none.
    held_kind = 0,
    -- Which team's board is on screen. A prototype affordance; a real match has
    -- no such thing, because the other team's board is not on this machine.
    watching = 1,
    -- Whether the camera is being dragged, and with which button.
    panning = false,
    paused = false,
    speed = 1,
    mouse_x = 0,
    mouse_y = 0,
  }
end
-- }}}

-- {{{ local function nearest_lane()
-- Which lane the cursor is over, and how far from it. Walks the path arrays
-- directly rather than through any index.
--
-- Every node of every lane is about two hundred and fifty comparisons, which is
-- nothing once per click and would be too much once per body per tick. That
-- difference is why this lives here and not in the simulation.
local function nearest_lane(world, world_x, world_y)
  local best_lane, best_distance = 0, math.huge
  for _, lane in ipairs(world.map.lane) do
    for _, node_id in ipairs(lane.path) do
      local node = world.map.node[node_id]
      local dx, dy = node.x - world_x, node.y - world_y
      local distance = dx * dx + dy * dy
      if distance < best_distance then
        best_lane, best_distance = lane.id, distance
      end
    end
  end
  return best_lane, math.sqrt(best_distance)
end
-- }}}

-- {{{ local function structure_under()
-- The player's own structure under the cursor, if any.
--
-- Only their own. Dropping an upgrade on an enemy tower is not a refusal worth
-- explaining -- it is a miss, and it should fall through to whatever else is
-- under the cursor rather than producing a message about ownership.
local function structure_under(world, team_id, world_x, world_y)
  for _, structure in ipairs(world.structure) do
    if structure.team == team_id and structure.alive == 1 then
      local node = world.map.node[structure.node]
      local dx, dy = node.x - world_x, node.y - world_y
      if dx * dx + dy * dy <= STONE_DROP_REACH * STONE_DROP_REACH then
        return structure
      end
    end
  end
  return nil
end
-- }}}

-- {{{ function M.world_drop()
-- What dropping an upgrade at a screen point in the world would mean.
--
-- Returns a command table, or nil if the cursor is over nothing that will take
-- one. Returning nil rather than a refusal is deliberate: a drop into empty space
-- is a player changing their mind, not a player being told no, and filling the
-- refusal log with "you dropped that on the grass" would train them to ignore it.
function M.world_drop(world, camera_module, camera, team_id, kind, screen_x, screen_y)
  local world_x, world_y = camera_module.screen_to_world(camera, screen_x, screen_y)

  -- Stone first, because a tower sits on a lane and both would otherwise answer.
  local structure = structure_under(world, team_id, world_x, world_y)
  if structure ~= nil then
    if structure.kind == 3 then
      -- The library. Upgrades cannot be slotted into base guard towers directly;
      -- they go into the library, which applies them to all three at once. Rare,
      -- and usually the shape of a last stand.
      return {verb = "place_in_library", team = team_id, player = team_id, kind = kind}
    end
    if structure.kind == 2 then
      -- A base tower. Refused by name, because a player who tries it is reaching
      -- for a real rule and deserves to be told which one.
      return {verb = "place_in_stone", team = team_id, player = team_id,
              kind = kind, lane = structure.lane,
              note = "base towers take no upgrade directly -- use the library"}
    end
    return {verb = "place_in_stone", team = team_id, player = team_id,
            kind = kind, lane = structure.lane}
  end

  local lane, distance = nearest_lane(world, world_x, world_y)
  if lane ~= 0 and distance <= LANE_DROP_REACH then
    return {verb = "place_in_lane", team = team_id, player = team_id,
            kind = kind, lane = lane}
  end

  return nil
end
-- }}}

-- {{{ M.key
-- The key dispatch table. Adding a binding is adding a row.
--
-- Home and space both frame the whole map. Two keys for one action because it is
-- the action that must never be hunted for: if getting back to the whole map were
-- ever a small navigation task, players would stop zooming in at all, and the
-- detail the camera exists to show would go unread.
M.key = {
  home   = function(state, context) context.camera_module.home(context.camera) end,
  space  = function(state, context) context.camera_module.home(context.camera) end,
  tab    = function(state) state.watching = (state.watching == 1) and 2 or 1 end,
  p      = function(state) state.paused = not state.paused end,
  ["1"]  = function(state) state.speed = 1 end,
  ["2"]  = function(state) state.speed = 4 end,
  ["3"]  = function(state) state.speed = 16 end,
  ["="]  = function(state, context) context.camera_module.zoom_centre(context.camera, 2) end,
  ["-"]  = function(state, context) context.camera_module.zoom_centre(context.camera, -2) end,
  escape = function(state, context) love.event.quit() end,
}
-- }}}

-- {{{ function M.keypressed()
function M.keypressed(state, context, key)
  local action = M.key[key]
  if action ~= nil then
    action(state, context)
  end
end
-- }}}

-- {{{ function M.wheel()
-- The whole point. Positive is toward the player, which every wheel everywhere
-- means "closer".
function M.wheel(state, context, dx, dy)
  context.camera_module.wheel(context.camera, dy, state.mouse_x, state.mouse_y)
end
-- }}}

-- {{{ function M.mousepressed()
function M.mousepressed(state, context, x, y, button)
  state.mouse_x, state.mouse_y = x, y

  -- Right and middle drag the world. Left is reserved for the chest, because the
  -- chest is the thing a player is actually doing and it should have the button
  -- their hand is already on.
  if button == 2 or button == 3 then
    state.panning = true
    context.camera_module.begin_drag(context.camera, x, y)
    return
  end

  if button ~= 1 then
    return
  end

  local hot = context.panel.hit_test(x, y)
  if hot ~= nil then
    if hot.kind == "chest_chip" then
      -- Picked up. It is not removed from the chest here -- nothing is moved
      -- until a command is applied at the top of a tick, and a chip that vanished
      -- on pick-up would be the viewer holding state the simulation needs.
      state.held_kind = hot.upgrade
      -- And the camera pulls back to the whole map, because **the act of zooming
      -- out is the act of asking where to put it.** Picking a rune up is a
      -- question about the whole board -- which lane is losing, where the enemy
      -- armies are, which stone is still standing -- and none of that is visible
      -- from inside the fight you were watching a moment ago.
      --
      -- Eased rather than instant, unlike home: the motion is the question being
      -- asked, so it has to be seen being asked.
      context.camera_module.pull_back(context.camera)
    elseif hot.kind == "slot_pip" then
      -- Taking one back out. Recalling from a lane does not weaken anything
      -- already walking in it, for the same reason placing into one does not
      -- strengthen it -- those bodies were stamped at birth and are nobody's to
      -- change any more.
      context.queue({verb = "recall", team = state.watching, player = state.watching,
                     kind = hot.upgrade, lane = hot.lane, from = hot.from})
    end
  end
end
-- }}}

-- {{{ function M.mousereleased()
function M.mousereleased(state, context, x, y, button)
  state.mouse_x, state.mouse_y = x, y

  if button == 2 or button == 3 then
    state.panning = false
    context.camera_module.end_drag(context.camera)
    return
  end

  if button ~= 1 or state.held_kind == 0 then
    return
  end

  local kind = state.held_kind
  state.held_kind = 0
  -- Whatever happens to the drop, the question has been answered, so the camera
  -- goes back to whatever the player was watching before it was asked -- unless
  -- they moved it themselves in the meantime, in which case the camera stays
  -- where they put it.
  context.camera_module.return_to_remembered(context.camera)

  -- Dropped on the panel: one of the two slot targets in a lane row.
  local hot = context.panel.hit_test(x, y)
  if hot ~= nil and hot.kind == "drop" then
    context.queue({verb = hot.verb, team = state.watching, player = state.watching,
                   kind = kind, lane = hot.lane})
    return
  end

  -- Dropped on the map.
  if x < context.panel.panel_left() then
    local command = M.world_drop(context.world, context.camera_module, context.camera,
                                 state.watching, kind, x, y)
    if command ~= nil then
      if command.note ~= nil then
        context.panel.note_refusal(command.note)
        return
      end
      context.queue(command)
    end
  end
end
-- }}}

-- {{{ function M.mousemoved()
function M.mousemoved(state, context, x, y)
  state.mouse_x, state.mouse_y = x, y
  if state.panning then
    context.camera_module.drag_to(context.camera, x, y)
  end
end
-- }}}

-- {{{ function M.update()
-- Held keys, once a frame. Panning is here rather than in keypressed because a
-- held arrow key should pan continuously and a key repeat is not a smooth motion.
function M.update(state, context, delta_time)
  local right, down = 0, 0
  if love.keyboard.isDown("left")  or love.keyboard.isDown("a") then right = right - 1 end
  if love.keyboard.isDown("right") or love.keyboard.isDown("d") then right = right + 1 end
  if love.keyboard.isDown("up")    or love.keyboard.isDown("w") then down  = down  - 1 end
  if love.keyboard.isDown("down")  or love.keyboard.isDown("s") then down  = down  + 1 end
  context.camera_module.pan_by_keys(context.camera, right, down, delta_time)
end
-- }}}

return M
