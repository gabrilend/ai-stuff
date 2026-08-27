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
    challenge_index = 0,
    -- When the current phase ends, so the banner can count down. **A visible clock
    -- on purpose**: a surge a team can see coming becomes an event they play
    -- toward, and the minutes before one are their own phase of the match. A hidden
    -- trigger produces one interesting moment; a visible one produces an
    -- interesting approach to that moment, three times.
    phase_ends_at = 0,
    -- The two a player has been offered, or empty. Nothing else in this project
    -- decides for a player, so this being empty means the choice is already made.
    boon_offer = {},

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
    -- One per player, but **only the viewing player's team is ever filled in** on
    -- a real match: a wallet is the one thing in this game that belongs to a single
    -- person, and the enemy's is not on the machine at all.
    wallet = {},
    -- The stones this player can see: their own, and the communal ones they have
    -- not set aside. A dismissed stone is gone from **theirs**, not from the pool --
    -- everybody else still sees it.
    stone = {},
    stone_count = 0,
    -- What each teammate is pointing at. Synced continuously and never opt-in, which
    -- is half of why you can see somebody reaching for a thing before they touch it.
    cursor = {},

    -- One per lane, for the viewing team only. The enemy's are not drawn greyed
    -- out or drawn without a direction -- they are not drawn.
    signpost = {},
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

  local colours = #world.parameters.commander.colour
  for number = 1, world.parameters.team_size * 2 do
    frame.wallet[number] = {
      team = 0, commander = 0, rung = 1, hero_alive = 0,
      points = zeroed(colours),
      points_max = zeroed(colours),
      points_wasted = zeroed(colours),
      affordable = {},
    }
  end

  for lane = 1, lane_count do
    frame.signpost[lane] = {branch = 0, set_by = 0, set_tick = 0, options = 0,
                            x = 0, y = 0}
  end

  for number = 1, world.parameters.team_size * 2 do
    frame.cursor[number] = {x = 0, y = 0, tick = 0, team = 0}
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
  frame.challenge_index = world.challenge_index
  frame.phase_ends_at = world.phase_ends_at or 0

  for index = #frame.boon_offer, 1, -1 do
    frame.boon_offer[index] = nil
  end
  local watching_player = (world.viewing_team == 2)
    and (world.parameters.team_size + 1) or 1
  local offer = world.boon_offer[watching_player]
  if offer ~= nil then
    for index, boon_id in ipairs(offer) do
      frame.boon_offer[index] = boon_id
    end
  end

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

  -- Wallets. Both teams' are copied because this prototype runs both sides on one
  -- machine; a real match would fill in one.
  local catalogue = world.parameters.commander
  for number, player in ipairs(world.player) do
    local wallet = frame.wallet[number]
    wallet.team = player.team
    wallet.commander = player.commander
    wallet.rung = player.rung
    wallet.hero_alive = player.hero_alive
    for colour = 1, #catalogue.colour do
      wallet.points[colour] = player.points[colour]
      wallet.points_max[colour] = player.points_max[colour]
      wallet.points_wasted[colour] = player.points_wasted[colour]
    end
    -- Worked out here rather than in the panel, because "can I buy this" is a
    -- question about the world and the viewer is not allowed to decide anything the
    -- simulation could decide.
    local roster = catalogue.commander[player.commander].roster
    for index, row in ipairs(roster) do
      wallet.affordable[index] = world.commanders.can_afford(world, player, row) and 1 or 0
    end
  end

  -- The stones, for the player being watched.
  local watching = (world.viewing_team == 2)
    and (world.parameters.team_size + 1) or 1
  local shown = 0
  for _, stone in ipairs(world.stone[world.viewing_team or 1]) do
    if world.stones.visible_to(world, stone, watching) then
      shown = shown + 1
      local view = frame.stone[shown]
      if view == nil then
        view = {}
        frame.stone[shown] = view
      end
      view.id = stone.id
      view.kind = stone.kind
      view.slot_kind = stone.slot_kind
      view.slot_lane = stone.slot_lane
      -- Whether it is mine or in the pool. **Never whose it was** -- a shared thing
      -- you have to remember is shared is not shared, and the point of the pool is
      -- to delete the question rather than to answer it discreetly.
      view.mine = (stone.held_by == watching) and 1 or 0
      view.communal = (stone.held_by == 0) and 1 or 0
      view.moving_to_kind = stone.moving_to_kind
      view.moving_to_lane = stone.moving_to_lane
      view.arrives_turn = stone.arrives_turn
    end
  end
  frame.stone_count = shown

  for number, cursor in ipairs(world.cursor) do
    local view = frame.cursor[number]
    view.x, view.y, view.tick = cursor.x, cursor.y, cursor.tick
    view.team = world.player[number].team
  end
  frame.wave_turn = world.wave_turn or 0

  -- Sign-posts, for the team being watched.
  for lane_id = 1, world.parameters.lane_count do
    local post = world.signpost[world.viewing_team or 1][lane_id]
    local node = world.map.node[post.node]
    local view = frame.signpost[lane_id]
    view.branch = post.branch
    view.set_by = post.set_by
    view.set_tick = post.set_tick
    view.options = #post.options
    view.x, view.y = node.x, node.y
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
