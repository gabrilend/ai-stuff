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

-- 056-signposts.lua
--
-- The three objects in the world that decide where a body turns.
--
-- ## What a sign-post actually is
--
-- **A lane swap on a timer, and the timer is the walk.** That is the whole feature,
-- and it is worth stating as the feature rather than as a consequence of one:
-- the ability to move a body into a neighbouring lane, once, with a delay.
--
-- A body arriving at a junction takes the branch the sign points at, and **after
-- that it goes straight on at every junction for the rest of its life**, whatever
-- the next sign says. That single rule is what keeps this from being a routing
-- system -- there is no looping a body around the anti-diagonal, no chaining two
-- posts to reach the far lane, and no policy that steers a body twice.
--
-- ## Who obeys
--
-- **Hero units, and nothing else.** Wave units ignore sign-posts completely and
-- always continue along their own lane -- not an oversight: if waves could be
-- rerouted, a team could feed two lanes into one and the lane structure of the map
-- would be decorative. **Waves are the map's skeleton; heroes are the thing that
-- moves across it.** Guards never reach a junction, and challenge monsters walk the
-- centre and are not redirected by anything.
--
-- ## Whose they are
--
-- Each team has one at each junction -- three apiece, six in all -- standing in the
-- same place and pointing wherever each team last set them. Any player on a team
-- may set any of their three at any time, with no lock and no objection: they are
-- cheap, instant and reversible, and a negotiation layer over something undoable in
-- one click would be ceremony with no stakes under it.
--
-- **The enemy cannot see yours.** Not greyed out, not drawn without a direction --
-- not drawn. So routing is concealed until it pays off: a team that has quietly
-- pointed all three junctions at the centre has committed every future hero
-- purchase to the middle, and the other side finds out when heroes start turning up
-- there, several purchases late. The fog is made of walking.

local M = {}

-- Branch values. Straight on is zero everywhere, so a player who never touches a
-- sign-post gets exactly what they would expect from a game that did not have them.
M.STRAIGHT = 0

-- {{{ function M.begin()
-- Plants the posts: one per lane per team, at that lane's junction.
function M.begin(world)
  world.signpost = {}
  for team = 1, 2 do
    world.signpost[team] = {}
    for lane_id = 1, world.parameters.lane_count do
      local lane = world.map.lane[lane_id]
      -- Which connectors leave this lane's junction. A side lane has one; the
      -- middle has two, which is why the middle post has three states and the
      -- others have two.
      local leaving = {}
      for _, connector in ipairs(world.map.connector) do
        if connector.path[1] == lane.junction[1]
           or connector.path[#connector.path] == lane.junction[1] then
          leaving[#leaving + 1] = connector.id
        end
      end

      world.signpost[team][lane_id] = {
        team = team,
        lane = lane_id,
        node = lane.junction[1],
        branch = M.STRAIGHT,
        options = leaving,
        set_by = 0,
        set_tick = 0,
      }
    end
  end
end
-- }}}

-- {{{ function M.cycle()
-- A click. Straight on, then each connector leaving this junction, then back to
-- straight on.
--
-- Cycling rather than toggling because the middle post has two alternatives -- the
-- top-left corner and the bottom-right -- and a toggle cannot express three states.
-- The side posts have one alternative each and cycling degenerates to a toggle
-- there, which is what a player expects.
function M.cycle(world, team, lane_id, player_number)
  local post = world.signpost[team][lane_id]
  if post.branch == M.STRAIGHT then
    post.branch = post.options[1] or M.STRAIGHT
  else
    local at = 0
    for index, id in ipairs(post.options) do
      if id == post.branch then at = index break end
    end
    post.branch = post.options[at + 1] or M.STRAIGHT
  end

  post.set_by = player_number
  post.set_tick = world.tick

  -- Raised because a teammate changing one **silently redirects every hero they
  -- have inbound**, which makes it the only unnegotiated change one player can make
  -- to another's plans. It happens without warning, so the viewer owes the other
  -- two a clear and immediate signal.
  world.raise(world, "signpost_set", {
    team = team, lane = lane_id, branch = post.branch, player = player_number,
  })
  return post
end
-- }}}

-- {{{ function M.consult()
-- A body has reached its lane's junction. Returns the connector it should take, or
-- nil for straight on.
--
-- Called only for bodies with a turn left in them, which is heroes that have not
-- turned yet, which is the only thing that ever reads a sign-post at all.
function M.consult(world, id)
  local soldier = world.soldier
  if soldier.flavour[id] ~= 2 or soldier.turns_left[id] <= 0 then
    return nil
  end

  local post = world.signpost[soldier.team[id]][soldier.lane[id]]
  if post == nil or post.branch == M.STRAIGHT then
    -- Straight on still uses up nothing. A hero that walks past a post pointing
    -- straight ahead keeps its turn for the next junction it meets, which it will
    -- only ever meet if something else sent it somewhere with two of them.
    return nil
  end
  return world.map.connector[post.branch]
end
-- }}}

-- {{{ function M.check_junction()
-- Whether this body has just reached its lane's junction, and if so, what to do.
--
-- The window is a body's own speed rather than a fixed distance, so a fast hero
-- cannot step over the junction between two ticks and miss the sign entirely --
-- which would be a silent failure of the only steering a player has.
function M.check_junction(world, id)
  local soldier = world.soldier
  if soldier.turns_left[id] <= 0 or soldier.crossing[id] ~= 0 then
    return false
  end

  local lane = world.map.lane[soldier.lane[id]]
  if lane == nil then
    return false
  end

  local junction_along = lane.cumulative[lane.milestone_index[4]]
  local gap = soldier.lane_along[id] - junction_along
  if gap < 0 then gap = -gap end
  if gap > soldier.speed[id] * 1.5 then
    return false
  end

  local connector = M.consult(world, id)
  if connector == nil then
    return false
  end

  world.walking.begin_crossing(world, id, connector, lane.id)
  world.raise(world, "hero_turned", {
    id = id, team = soldier.team[id], from_lane = lane.id,
  })
  return true
end
-- }}}

return M
