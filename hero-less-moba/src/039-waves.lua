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

-- {{{ function M.new_wave()
-- A wave record with nobody in it yet: the books a group of bodies is kept in.
--
-- Exported rather than private so that the arena can raise a formation without also
-- raising a commander, a bounty and a share of the chest. A test fixture that built
-- its own wave table would be a second definition of what a wave *is*, and the first
-- field somebody added to the real one would quietly not exist in tests.
function M.new_wave(world, team, lane, member_count)
  local id = #world.wave + 1
  local kind_count = #world.parameters.upgrade.kind

  -- The lane's upgrade counts at the instant of spawn, copied into the record.
  -- Not for the simulation -- the bodies carry their own copies -- but for the
  -- post-match report, which wants to say what a wave was carrying when it died.
  local carried = {}
  for kind = 1, kind_count do
    carried[kind] = world.team[team].lane_slot[lane][kind]
  end

  local lane_record = world.map.lane[lane]
  local facing = (team == 1) and 1 or -1

  -- The formation's front, as a distance along the lane. It starts a few ranks in
  -- from the library so that the wave is **already in its ranks the moment it
  -- appears** rather than piling up against the end of the lane and sorting itself
  -- out afterwards.
  local start_in = 70
  local anchor = (team == 1) and start_in or (lane_record.length - start_in)

  -- A wave advances at its slowest member's pace, so it does not walk away from
  -- its own rear rank. That is the captain's speed -- and it stays the captain's
  -- speed after the captain dies, because a wave that sped up when it lost the most
  -- valuable body in it would be a wave rewarded for losing it.
  local pace = math.huge
  for _, row in ipairs(world.parameters.unit.archetype) do
    if row.flavour == 1 and row.speed < pace then
      pace = row.speed
    end
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

    -- Which lane's shape it forms in, which lane paid for it, and how far across the
    -- road it stands. All three differ from `lane` only during a challenge, when the
    -- three lanes' waves are funnelled into the middle and stand abreast there --
    -- so the honest default is "the lane it belongs to, down the middle of it", and
    -- the challenge overwrites them when it applies.
    --
    -- **Written here rather than only at the call site**, so that a wave record is
    -- complete the moment it exists. They were set by the ordinary spawner alone, and
    -- anything else that raised a wave got a record with three holes in it that only
    -- showed up two calls later as a nil lane.
    shape_lane    = lane,
    upgrade_lane  = lane,
    across_offset = 0,

    anchor       = anchor,
    pace         = pace,
    facing       = facing,
    engaged      = 0,
    hint         = (team == 1) and 1 or #lane_record.path,
    -- How far behind its place each member currently is, rebuilt every tick by the
    -- cohesion pass. Kept on the wave rather than on the bodies because it is a
    -- statement about the group -- a body's lag only means anything next to its
    -- neighbours'.
    lag_of       = {},
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
function M.spawn_body(world, team, lane_id, archetype, wave_id, role, role_index, melee_total)
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
  soldier.speed_scale[id] = 1

  local lane = world.map.lane[lane_id]
  soldier.lane[id] = lane_id
  soldier.facing[id] = (team == 1) and 1 or -1
  soldier.path_index[id] = (team == 1) and 1 or #lane.path
  soldier.milestone[id] = (team == 1) and 0 or 8

  -- Its place in the line, decided before it is put anywhere, so that the body
  -- appears standing in the formation rather than walking into it.
  world.formations.assign_wave_slots(world, id, world.map.lane[world.wave[wave_id].shape_lane],
                                     role_index, role, melee_total)
  local wave = world.wave[wave_id]
  local along = wave.anchor + soldier.slot_along[id] * soldier.facing[id]
  world.walking.set_lane_position(world, id, along,
    soldier.slot_across[id] + (world.wave[wave_id].across_offset or 0))

  -- Stamped at birth, and never corrected afterwards. Moving an upgrade out of a
  -- lane does not weaken the soldiers already walking in it -- they finish their
  -- lives carrying it. That delay is what makes a reassignment a decision worth
  -- arguing about instead of a switch.
  --
  -- **From the lane it was spawned *for*, not the lane it walks.** During a
  -- challenge those differ: every lane's production funnels into the middle, and a
  -- funnelled body still carries its own lane's upgrades, so a team that invested
  -- heavily in the top lane does not watch that investment evaporate.
  world.chest.stamp_from_lane(world, id, team, world.wave[wave_id].upgrade_lane)

  return id
end
-- }}}

-- {{{ function M.spawn_stream_body()
-- One body of a siege-surge's stream.
--
-- It belongs to **no wave**, and that is the whole reason the chest cannot grow
-- during a surge: "wiped" is a statement about a group, and a stream has no groups
-- in it. Nothing can detect a wipe, so nothing pays a draw -- and with towers
-- unkillable for the duration there is no tower reward either.
--
-- It gets no formation for the same reason. A surge is the one thing in this game
-- that walks out in a line.
function M.spawn_stream_body(world, team, lane_id, archetype)
  local id = world.allocate(world)
  local soldier = world.soldier
  local row = world.parameters.unit.archetype[archetype]
  local lane = world.map.lane[lane_id]

  world.give_body(world, id, row)
  soldier.team[id] = team
  soldier.archetype[id] = archetype
  soldier.owner[id] = 0
  soldier.wave[id] = 0
  soldier.leash_node[id] = 0
  soldier.speed_scale[id] = 1
  soldier.lane[id] = lane_id
  soldier.facing[id] = (team == 1) and 1 or -1
  soldier.path_index[id] = (team == 1) and 1 or #lane.path
  soldier.milestone[id] = (team == 1) and 0 or 8
  soldier.slot_along[id] = 0
  soldier.slot_across[id] = 0

  local along = (team == 1) and 40 or (lane.length - 40)
  world.walking.set_lane_position(world, id, along, 0)

  -- Its colour still comes from a commander -- whoever's turn it would have been.
  local commander_id = world.commanders.commander_for_wave(world, team, world.wave_turn + 1)
  world.commanders.stamp_bounty(world, id, commander_id, world.stream_index or 1)
  world.stream_index = (world.stream_index or 0) + 1

  -- No stamp from a lane. What it carries is dealt to it by the surge, from
  -- everything the team owns, an instant after it appears.
  world.chest.apply_boons(world, id)
  soldier.health[id] = soldier.health_max[id]
  return id
end
-- }}}

-- {{{ local function queue_wave()
-- Creates a wave record and schedules its bodies to leave the library a few
-- ticks apart, so a wave walks out as a column rather than as one stacked point.
local function queue_wave(world, team, lane, turn)
  local settings = world.parameters.unit.wave
  local total = settings.melee_count + settings.ranged_count + settings.captain_count
  -- Where it walks, which during a challenge is the middle whatever lane it was
  -- raised for.
  local walks = world.phases.spawn_lane_for(world, lane)
  local wave_id = M.new_wave(world, team, walks, total)
  world.wave[wave_id].upgrade_lane = lane
  -- Where this wave stands across the lane it walks. Zero in ordinary play; during
  -- a challenge the three funnelled waves stand abreast rather than through one
  -- another.
  -- Only during a challenge, and only then. In ordinary play a wave has its whole
  -- lane to itself and sits down the middle of it.
  --
  -- Multiplied by facing, which is what makes the two teams mirror. `across` is
  -- measured against the lane's own fixed direction rather than against the body's,
  -- so the same signed value is the same side of the world for both teams -- and
  -- two armies walking at each other need the group that is on *my* left to be on
  -- *their* right, which is what the sign flip produces.
  local offset = 0
  if world.phase == 3 then
    offset = world.formations.abreast_offset(world.map, lane, 2)
             * ((team == 1) and 1 or -1)
  end
  world.wave[wave_id].across_offset = offset
  -- The shape it forms in is its **own** lane's, not the one it is walking. A wave
  -- raised for a side lane was formed for a side lane, and during a challenge it
  -- arrives in the middle still looking like one -- which is what lets a player see
  -- which of the three groups converging on the monster came from where.
  world.wave[wave_id].shape_lane = lane

  -- **The commanders take turns sending waves**, so a third of what leaves a base
  -- is somebody else's captain and somebody else's mixture. That is what makes
  -- commander selection a team conversation in the lobby rather than three private
  -- preferences -- and it is why a player learns the enemy's roster by watching
  -- rather than by being told.
  local commander_id = world.commanders.commander_for_wave(world, team, turn)
  local commander = world.parameters.commander.commander[commander_id]
  world.wave[wave_id].commander = commander_id

  -- **The whole wave appears at once, in its ranks.** There is no column that
  -- files out and arranges itself later: it is emitted from the base already in
  -- formation and it is battle-ready from the first tick. The only thing in this
  -- game that walks out in a line is a siege-surge, which is a stream and has no
  -- formation at all.
  --
  -- The captain takes index zero of the front rank, which puts it in the middle of
  -- the line -- both where it is most useful and where an opponent can see it
  -- coming, which matters because a captain is the one body a commander chooses.
  --
  -- The mixture is the commander's: how much of the wave is melee and how much is
  -- ranged. The bodies themselves are identical for every commander in the game --
  -- what differs is the ratio, the captain, and the colours they pay in.
  local body_count = settings.melee_count + settings.ranged_count
  local melee_count = math.floor(body_count * commander.melee_share + 0.5)
  local ranged_count = body_count - melee_count
  -- How many bodies the **line** holds, which is what decides how many ranks it
  -- occupies and therefore where the ranks behind it start.
  --
  -- The captain counts only if it stands in the line. One with a bow stands behind
  -- it, so counting it would push the archers a rank further back than they need to
  -- be and leave a hole where the captain was assumed to be.
  local captain_row = world.parameters.unit.archetype[commander.captain]
  local captain_in_the_line = (captain_row ~= nil and (captain_row.captain_rank or 0) == 0
                               and captain_row.reach ~= 2)
  local melee_total = melee_count + (captain_in_the_line and settings.captain_count or 0)

  local bounty_index = 0
  local function born(archetype, role, role_index)
    bounty_index = bounty_index + 1
    local id = M.spawn_body(world, team, lane, archetype, wave_id, role, role_index, melee_total)
    world.commanders.stamp_bounty(world, id, commander_id, bounty_index)
    return id
  end

  lane = walks
  local front_index = 0
  local behind_index = 0

  -- A captain is given its own role. Which rank it stands in is written on its
  -- archetype row -- the front of the line for one carrying a shield, back with the
  -- archers for one carrying a bow -- and it stands in the middle of that rank.
  --
  -- It does not consume a place in the line or in the ranks behind it. A captain in
  -- the middle of the front rank is *the* middle of that rank, and the melee lay out
  -- around it; a captain behind is a body standing in a gap of its own.
  for _ = 1, settings.captain_count do
    born(commander.captain, "captain", 0)
  end

  for _ = 1, melee_count do
    born(MELEE, "front", front_index)
    front_index = front_index + 1
  end
  for _ = 1, ranged_count do
    born(RANGED, "back", behind_index)
    behind_index = behind_index + 1
  end

  -- Now that every body has a place, the formation knows how deep it is, and every
  -- place can be written down as a bearing from its centre.
  world.formations.settle_the_disc(world, wave_id)

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

  -- Nothing spawns during a calm: the map is emptying and a body put down then
  -- would have nowhere to go and nothing to fight.
  if world.phase == 4 then
    return
  end

  -- A surge is a stream, not waves, and it has its own spawner.
  if world.phase == 2 then
    world.phases.stream_pass(world)
    return
  end

  if world.tick >= world.next_wave_tick then
    world.wave_turn = (world.wave_turn or 0) + 1
    -- Anything whose wave has come moves **before** this wave is raised, so the
    -- bodies leaving are stamped from the board as it now is. A transit that landed
    -- after the spawn would be a wave late, every time, invisibly.
    world.stones.land_transits(world, world.wave_turn)
    for team = 1, 2 do
      for lane = 1, world.parameters.lane_count do
        queue_wave(world, team, lane, world.wave_turn)
      end
    end
    world.next_wave_tick = world.next_wave_tick + settings.interval

    -- If the timer has fallen more than one interval behind -- which happens when
    -- something moves the clock rather than the clock moving itself -- it is snapped
    -- forward rather than allowed to catch up a wave at a time.
    --
    -- **Loudly.** Catching up is not obviously wrong and would put a match's worth of
    -- bodies on the field in a few seconds, so this is the kind of thing that has to
    -- announce itself rather than be quietly corrected.
    if world.tick - world.next_wave_tick > settings.interval then
      world.raise(world, "spawn_clock_snapped", {
        was = world.next_wave_tick, now = world.tick + settings.interval,
      })
      world.next_wave_tick = world.tick + settings.interval
    end
    world.raise(world, "wave_spawned", {tick = world.tick})
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

    world.stones.draw(world, killing_team,
                     world.parameters.structure.reward.wave_wiped_draws)
  end
end
-- }}}

-- {{{ function M.begin()
-- Sets the cadence running. Called once, at world creation.
function M.begin(world)
  world.spawn_queue = {}
  world.wave_turn = 0
  world.next_wave_tick = world.parameters.unit.wave.first_at
end
-- }}}

return M
