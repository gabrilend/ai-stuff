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

-- 043-snapshot.lua
--
-- The viewer's frame: a flat, read-only copy of everything the screen needs,
-- stamped at the end of every tick.
--
-- Not the whole world. The viewer has no use for cooldown timers, target
-- generations, or pending damage, and handing it those would invite it to start
-- reasoning about them -- which is the first step toward a viewer that decides
-- something, and a viewer that decides something has taken a job away from the
-- simulation and put it somewhere no test is looking.
--
-- ## Two frames, and never a third
--
-- The viewer keeps the two most recent frames and interpolates positions between
-- them by the fraction of a tick elapsed. It is **allowed to be behind and never
-- allowed to be ahead.** A viewer that extrapolates shows things that did not
-- happen, and in a game where a player judges a lane by looking at where the
-- frontline is, that is a lie that changes decisions.
--
-- ## Indexed by soldier id, not packed
--
-- The arrays below are indexed by soldier id rather than compacted into a dense
-- list. That wastes a little space and buys the thing the interpolation needs:
-- matching a body in this frame to the same body in the previous one is reading
-- the same index twice, with no search and no identity map. A packed frame would
-- have to be joined against the previous one every frame, and a body that moved
-- slots between them would be drawn as a teleport.

local M = {}

-- {{{ local function zeroed()
local function zeroed(count)
  local array = {}
  for index = 1, count do
    array[index] = 0
  end
  return array
end
-- }}}

-- {{{ local function make_frame()
-- One frame, allocated once. Frames are overwritten, never rebuilt -- a match
-- that allocated two frames' worth of arrays every tick would spend more time in
-- the collector than in the simulation.
local function make_frame(world)
  local capacity = #world.soldier.alive
  local kind_count = #world.parameters.upgrade.kind
  local lane_count = world.parameters.lane_count

  local frame = {
    tick  = 0,
    phase = 1,
    winner = 0,

    -- Per body, indexed by soldier id.
    alive     = zeroed(capacity),
    x         = zeroed(capacity),
    y         = zeroed(capacity),
    facing    = zeroed(capacity),
    team      = zeroed(capacity),
    flavour   = zeroed(capacity),
    archetype = zeroed(capacity),
    reach     = zeroed(capacity),
    lane      = zeroed(capacity),
    milestone = zeroed(capacity),
    -- A fraction rather than a figure, because the viewer draws a bar and never
    -- a number, and because the figure would tempt somebody to compare two of
    -- them across teams as though that meant something.
    health_fraction = zeroed(capacity),
    -- Which lane paid for this body. Equal to `lane` today; it stops being equal
    -- during a challenge, when all three lanes' soldiers fight in the centre
    -- carrying their own lane's upgrades, and without it that ruling is invisible.
    spawned_lane = zeroed(capacity),

    -- Per body per upgrade kind. This is what makes an enemy's arrangement
    -- readable off their frontline at close zoom, which is the only way to learn
    -- it at all -- you know roughly *what* they hold because the deck is shared,
    -- and you learn *where they put it* by looking at what walks at you.
    upgrade_count = {},

    -- The live ids, so the renderer walks bodies rather than slots.
    live = {},
    live_count = 0,

    structure = {},
    team_view = {},
    event = {},
  }

  for kind = 1, kind_count do
    frame.upgrade_count[kind] = zeroed(capacity)
  end

  for id = 1, #world.structure do
    frame.structure[id] = {
      id = id, team = 0, kind = 0, lane = 0, alive = 0,
      x = 0, y = 0, health_fraction = 0, command_radius = 0,
      guard_count = 0, upgrade_count = zeroed(kind_count),
    }
  end

  for team = 1, 2 do
    local view = {
      chest = zeroed(kind_count),
      library_slot = zeroed(kind_count),
      lane_slot = {},
      tower_slot = {},
      push_depth = zeroed(lane_count),
      waves_lost = zeroed(lane_count),
      draws_taken = 0,
    }
    for lane = 1, lane_count do
      view.lane_slot[lane]  = zeroed(kind_count)
      view.tower_slot[lane] = zeroed(kind_count)
    end
    frame.team_view[team] = view
  end

  return frame
end
-- }}}

-- {{{ function M.begin()
-- Allocates both frames. Called once, at assembly.
function M.begin(world)
  world.frame = { make_frame(world), make_frame(world) }
  -- Which of the two holds the newest stamp. The other is the previous one, and
  -- the pair alternate forever.
  world.frame_newest = 1
end
-- }}}

-- {{{ function M.stamp()
-- Copies the world into the older of the two frames and makes it the newer.
function M.stamp(world)
  local older = (world.frame_newest == 1) and 2 or 1
  local frame = world.frame[older]
  local soldier = world.soldier
  local kind_count = #world.parameters.upgrade.kind

  frame.tick   = world.tick
  frame.phase  = world.phase
  frame.winner = world.winner

  -- Bodies. Only the living are written; the dead keep whatever they had, and
  -- nothing reads them because the live list does not name them.
  local live = frame.live
  local count = 0
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 then
      count = count + 1
      live[count] = id

      frame.alive[id]     = 1
      frame.x[id]         = soldier.x[id]
      frame.y[id]         = soldier.y[id]
      frame.facing[id]    = soldier.facing[id]
      frame.team[id]      = soldier.team[id]
      frame.flavour[id]   = soldier.flavour[id]
      frame.archetype[id] = soldier.archetype[id]
      frame.reach[id]     = soldier.reach[id]
      frame.lane[id]      = soldier.lane[id]
      frame.milestone[id] = soldier.milestone[id]
      frame.spawned_lane[id] = soldier.lane[id]
      frame.health_fraction[id] = soldier.health[id] / soldier.health_max[id]

      for kind = 1, kind_count do
        frame.upgrade_count[kind][id] = soldier.upgrade_count[kind][id]
      end
    else
      frame.alive[id] = 0
    end
  end
  -- Truncate rather than clear. The array keeps its capacity so that a busy tick
  -- after a quiet one does not have to grow it again.
  for index = count + 1, frame.live_count do
    live[index] = 0
  end
  frame.live_count = count

  -- Stone.
  for _, structure in ipairs(world.structure) do
    local view = frame.structure[structure.id]
    local node = world.map.node[structure.node]
    view.team  = structure.team
    view.kind  = structure.kind
    view.lane  = structure.lane
    view.alive = structure.alive
    view.x, view.y = node.x, node.y
    view.health_fraction = structure.health / structure.health_max
    -- Drawn for **both** teams, deliberately. It is the one piece of information
    -- in this game both sides can see, because the attacker and the defender have
    -- to reason about the same circle at the same moment.
    view.command_radius = structure.command_radius
    view.guard_count = #structure.guard_slot
    for kind = 1, kind_count do
      view.upgrade_count[kind] = structure.upgrade_count[kind]
    end
  end

  -- Both teams' boards are copied here because this prototype runs both sides on
  -- one machine. **On a real match only the viewing player's team may be filled
  -- in** -- the enemy's chest is not on the machine at all, and their soldiers on
  -- the ground are the whole of what you learn about their arrangement. The
  -- renderer must never draw an enemy chest, an enemy slot, or an enemy
  -- sign-post; there is no fog-of-war system to build, only something not to
  -- accidentally reveal.
  for team_id = 1, 2 do
    local team = world.team[team_id]
    local view = frame.team_view[team_id]
    for kind = 1, kind_count do
      view.chest[kind] = team.chest[kind]
      view.library_slot[kind] = team.library_slot[kind]
      for lane = 1, world.parameters.lane_count do
        view.lane_slot[lane][kind]  = team.lane_slot[lane][kind]
        view.tower_slot[lane][kind] = team.tower_slot[lane][kind]
      end
    end
    for lane = 1, world.parameters.lane_count do
      view.push_depth[lane] = team.push_depth[lane]
      view.waves_lost[lane] = team.waves_lost[lane]
    end
    view.draws_taken = team.draws_taken
  end

  -- Events raised this tick. These fire the popups, and every one of them must be
  -- legible at the default camera framing -- zoom reveals detail, never events.
  for index = #frame.event, 1, -1 do
    frame.event[index] = nil
  end
  for index = 1, #world.event do
    frame.event[index] = world.event[index]
  end

  world.frame_newest = older
end
-- }}}

-- {{{ function M.newest()
function M.newest(world)
  return world.frame[world.frame_newest]
end
-- }}}

-- {{{ function M.previous()
function M.previous(world)
  return world.frame[(world.frame_newest == 1) and 2 or 1]
end
-- }}}

return M
