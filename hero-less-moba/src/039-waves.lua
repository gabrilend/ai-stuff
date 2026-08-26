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

-- 039-waves.lua
--
-- Where bodies come from, and how the game notices a group of them is gone.
--
-- ## A wave is a group with a name
--
-- Ordinary soldiers are not spawned as loose individuals. A wave is a record, and
-- every soldier it spawns carries that record's id for its whole life. Without
-- this the game could never notice a wave being wiped, because "wiped" is a
-- statement about a group and a pile of unrelated bodies has no groups in it.
--
-- ## A wave is three kinds of body
--
-- Melee bodies, ranged bodies, and a captain -- **one captain per lane, every
-- wave.** That rule is what makes every lane worth contesting: each carries a
-- body worth three times an ordinary one, so a lane you never contest is a
-- captain you never collect.
--
-- All three are ordinary wave units with different rows in the unit table, and
-- all three are stamped with the lane's upgrades -- including the captain, which
-- is exactly what separates a captain from a hero. In a lane carrying a dozen
-- upgrades the captain walking out of it is enormous.
--
-- ## Who gets paid
--
-- The team that wiped the wave draws the upgrade -- that is, the team that did
-- *not* spawn it. Team 1's chest fills up by killing team 2's soldiers.
--
-- Which makes the upgrade economy a snowball by design: a team winning a lane is
-- killing more waves in it and therefore drawing more upgrades, which wins the
-- lane harder. The siege-surge is the only thing that brakes it, and it does so
-- by destroying the *arrangement* rather than by taking anything away.

local M = {}

-- Archetype rows, by name, so that the composition below reads as prose.
local MELEE   = 1
local RANGED  = 2
local CAPTAIN = 3

-- {{{ local function new_wave()
local function new_wave(world, team, lane, member_count)
  local id = #world.wave + 1
  local kind_count = #world.parameters.upgrade.kind

  -- The lane's upgrade counts at the instant of spawn, copied into the record.
  -- Not for the simulation -- the bodies carry their own copies -- but for the
  -- post-match report, which wants to say what a wave was carrying when it died.
  local carried = {}
  for kind = 1, kind_count do
    carried[kind] = world.team[team].lane_slot[lane][kind]
  end

  world.wave[id] = {
    id           = id,
    team         = team,
    lane         = lane,
    spawn_tick   = world.tick,
    member_count = member_count,
    living_count = member_count,
    killed_any   = 0,
    settled      = 0,
    upgrade_count = carried,
  }
  return id
end
-- }}}

-- {{{ function M.spawn_body()
-- Puts one body on the ground, stamped and facing the right way.
--
-- Team 1 enters its lane at path index 1 walking forward; team 2 enters at the
-- far end walking backward. One path array, read in two directions, which is why
-- every "how far along" comparison in the project multiplies by facing.
function M.spawn_body(world, team, lane_id, archetype, wave_id)
  local id = world.allocate(world)
  local soldier = world.soldier
  local row = world.parameters.unit.archetype[archetype]

  world.give_body(world, id, row)
  soldier.team[id] = team
  soldier.archetype[id] = archetype
  soldier.owner[id] = 0
  soldier.wave[id] = wave_id
  soldier.assigned_team[id] = 0
  soldier.leash_node[id] = 0

  local lane = world.map.lane[lane_id]
  if team == 1 then
    world.walking.place_on_lane(world, id, lane_id, 1, 1)
    soldier.milestone[id] = 0
  else
    world.walking.place_on_lane(world, id, lane_id, #lane.path, -1)
    soldier.milestone[id] = 8
  end

  -- Stamped at birth, and never corrected afterwards. Moving an upgrade out of a
  -- lane does not weaken the soldiers already walking in it -- they finish their
  -- lives carrying it. That delay is what makes a reassignment a decision worth
  -- arguing about instead of a switch.
  world.chest.stamp_from_lane(world, id, team, lane_id)

  return id
end
-- }}}

-- {{{ local function queue_wave()
-- Creates a wave record and schedules its bodies to leave the library a few
-- ticks apart, so a wave walks out as a column rather than as one stacked point.
local function queue_wave(world, team, lane)
  local settings = world.parameters.unit.wave
  local total = settings.melee_count + settings.ranged_count + settings.captain_count
  local wave_id = new_wave(world, team, lane, total)

  -- The order bodies leave in, and it is deliberate. The captain leads, the
  -- melee follow, and the ranged come last -- so that by the time the column
  -- meets anything, the bodies that want the front are already in front of the
  -- bodies that do not.
  local order = {}
  for _ = 1, settings.captain_count do order[#order + 1] = CAPTAIN end
  for _ = 1, settings.melee_count   do order[#order + 1] = MELEE   end
  for _ = 1, settings.ranged_count  do order[#order + 1] = RANGED  end

  for position, archetype in ipairs(order) do
    world.spawn_queue[#world.spawn_queue + 1] = {
      due       = world.tick + (position - 1) * settings.stagger,
      team      = team,
      lane      = lane,
      archetype = archetype,
      wave      = wave_id,
    }
  end

  return wave_id
end
-- }}}

-- {{{ function M.spawn_pass()
-- The tick's spawn system. Starts waves when the cadence says so, then puts on
-- the ground whatever is due this tick.
--
-- Both teams use the same intervals and counts, so an unmodified match is exactly
-- symmetric and any asymmetry on screen is the players' doing.
function M.spawn_pass(world)
  local settings = world.parameters.unit.wave

  if world.tick >= world.next_wave_tick then
    for team = 1, 2 do
      for lane = 1, world.parameters.lane_count do
        queue_wave(world, team, lane)
      end
    end
    world.next_wave_tick = world.next_wave_tick + settings.interval
    world.raise(world, "wave_spawned", {tick = world.tick})
  end

  -- Anything due. Walked backwards so that removing an entry does not move the
  -- entries that have not been looked at yet.
  local queue = world.spawn_queue
  for index = #queue, 1, -1 do
    local entry = queue[index]
    if world.tick >= entry.due then
      M.spawn_body(world, entry.team, entry.lane, entry.archetype, entry.wave)
      table.remove(queue, index)
    end
  end
end
-- }}}

-- {{{ function M.member_died()
-- One member of one wave is gone. Called from the reap pass, once per death,
-- with the wave the dead body pointed at -- this never scans all waves.
function M.member_died(world, wave_id)
  local wave = world.wave[wave_id]
  wave.living_count = wave.living_count - 1

  -- Set the first time a member dies to enemy damage of any kind -- enemy
  -- soldiers, enemy towers, an enemy monster. A wave that dies entirely to
  -- towers still counts. The vision does not distinguish, and neither does this.
  wave.killed_any = 1

  -- Fully defeated means living_count reached zero *and* something killed at
  -- least one member. Both halves matter: a wave can also empty by walking into
  -- an enemy library and ending the game, or by being removed at match end, and
  -- neither of those should pay anybody.
  if wave.living_count <= 0 and wave.killed_any == 1 and wave.settled == 0 then
    wave.settled = 1
    local killing_team = (wave.team == 1) and 2 or 1
    world.team[wave.team].waves_lost[wave.lane] =
      world.team[wave.team].waves_lost[wave.lane] + 1

    world.raise(world, "wave_wiped", {
      wave_id       = wave.id,
      spawning_team = wave.team,
      killing_team  = killing_team,
      lane          = wave.lane,
    })

    world.chest.draw(world, killing_team,
                     world.parameters.structure.reward.wave_wiped_draws)
  end
end
-- }}}

-- {{{ function M.begin()
-- Sets the cadence running. Called once, at world creation.
function M.begin(world)
  world.spawn_queue = {}
  world.next_wave_tick = world.parameters.unit.wave.first_at
end
-- }}}

return M
