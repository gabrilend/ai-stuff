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

-- 031-map-validator.lua
--
-- Refuses a malformed path graph, once, at load.
--
-- This is where every "is this field really filled in?" question in the project
-- goes to be asked. The movement loop runs a thousand times a tick and has no
-- nil checks in it; that is only safe because this file has already established
-- that there is nothing there that could be nil. Every check below is a question
-- the simulation is thereby allowed to stop asking.
--
-- It refuses rather than repairs. A validator that quietly patches up a bad map
-- means the map builder has a bug that nobody will ever be told about, and the
-- bug will surface as soldiers walking into the sea three phases later.

local M = {}

-- How far apart two positions may be and still count as the same point. The
-- mirror checks compare doubles that went through different arithmetic to reach
-- the same place, so an exact comparison would fail on the last bit.
local TOLERANCE = 0.0001

-- {{{ local function complain()
local function complain(problems, format, ...)
  problems[#problems + 1] = string.format(format, ...)
end
-- }}}

-- {{{ local function check_nodes()
-- Every node is joined to something, and every joining is mutual.
local function check_nodes(map, problems)
  for _, node in ipairs(map.node) do
    if #node.neighbour == 0 then
      complain(problems, "node %d at (%.1f, %.1f) is joined to nothing",
               node.id, node.x, node.y)
    end
    -- A one-way neighbour would let a body walk somewhere it can never walk
    -- back from, which reads as the body being stuck rather than as a map bug.
    for _, other_id in ipairs(node.neighbour) do
      local other = map.node[other_id]
      if other == nil then
        complain(problems, "node %d names neighbour %d, which does not exist",
                 node.id, other_id)
      else
        local mutual = false
        for _, back in ipairs(other.neighbour) do
          if back == node.id then
            mutual = true
            break
          end
        end
        if not mutual then
          complain(problems, "node %d names %d as a neighbour but not the reverse",
                   node.id, other_id)
        end
      end
    end
  end
end
-- }}}

-- {{{ local function check_lane_paths()
-- Each lane runs from one library to the other, in one unbroken chain, and
-- carries all nine milestones.
local function check_lane_paths(map, problems)
  local library_1 = map.library_node[1]
  local library_2 = map.library_node[2]

  for _, lane in ipairs(map.lane) do
    if lane.path[1] ~= library_1 then
      complain(problems, "lane %d does not start at team 1's library", lane.id)
    end
    if lane.path[#lane.path] ~= library_2 then
      complain(problems, "lane %d does not end at team 2's library", lane.id)
    end

    -- Walking the path must be walking the graph. If these ever disagree, a
    -- soldier following the path array would step between nodes that are not
    -- joined, and its position would jump.
    for index = 1, #lane.path - 1 do
      local here = map.node[lane.path[index]]
      local next_id = lane.path[index + 1]
      local joined = false
      for _, neighbour in ipairs(here.neighbour) do
        if neighbour == next_id then
          joined = true
          break
        end
      end
      if not joined then
        complain(problems, "lane %d path step %d: node %d is not joined to %d",
                 lane.id, index, here.id, next_id)
      end
    end

    for m = 0, 8 do
      local node_id = lane.milestone_node[m]
      if node_id == nil or map.node[node_id] == nil then
        complain(problems, "lane %d is missing milestone %d", lane.id, m)
      elseif m > 0 and m < 8 then
        -- Milestones 0 and 8 are the libraries, which are shared by all three
        -- lanes and so cannot carry any one lane's milestone index. They store
        -- zero and are read through their kind instead -- which is exactly why
        -- the documents say a node's milestone field is never read alone.
        local node = map.node[node_id]
        if node.milestone ~= m then
          complain(problems, "lane %d milestone %d sits on node %d, which says %d",
                   lane.id, m, node.id, node.milestone)
        end
      end
    end

    if #lane.junction ~= 1 then
      complain(problems, "lane %d carries %d junctions, not one",
               lane.id, #lane.junction)
    elseif lane.junction[1] ~= lane.milestone_node[4] then
      complain(problems, "lane %d's junction is not its milestone 4", lane.id)
    end
  end
end
-- }}}

-- {{{ local function check_mirror()
-- The two halves are exact mirrors.
--
-- The mirror is the reflection about the junction diagonal, which swaps x and y.
-- Under it every lane maps onto *itself* with its milestones reversed, because
-- each lane's bend sits on that diagonal and is therefore its own reflection.
--
-- This is the check that matters most in the file. An asymmetric map hands one
-- team a shorter walk, and nothing else in the project would ever notice --
-- players would simply lose more often on one side and never learn why.
local function check_mirror(map, problems)
  for _, lane in ipairs(map.lane) do
    for m = 0, 4 do
      local near = map.node[lane.milestone_node[m]]
      local far  = map.node[lane.milestone_node[8 - m]]
      -- Reflecting the near milestone must land on the far one.
      if math.abs(near.y - far.x) > TOLERANCE or math.abs(near.x - far.y) > TOLERANCE then
        complain(problems,
          "lane %d is not mirrored: milestone %d at (%.3f, %.3f) reflects to " ..
          "(%.3f, %.3f), but milestone %d is at (%.3f, %.3f)",
          lane.id, m, near.x, near.y, near.y, near.x, 8 - m, far.x, far.y)
      end
    end
  end
end
-- }}}

-- {{{ local function check_fractions()
-- The milestone fractions themselves are symmetric, checked separately from the
-- geometry so that a bad table is reported as a bad table rather than as a
-- crooked map.
local function check_fractions(shape, problems)
  for m = 0, 4 do
    local near = shape.milestone_fraction[m]
    local far  = shape.milestone_fraction[8 - m]
    if near == nil or far == nil then
      complain(problems, "the milestone fraction table has no entry for %d", m)
    elseif math.abs((near + far) - 1.0) > TOLERANCE then
      complain(problems,
        "milestone fractions %d and %d are %.4f and %.4f, which do not sum to 1",
        m, 8 - m, near, far)
    end
  end
  if math.abs(shape.milestone_fraction[4] - 0.5) > TOLERANCE then
    complain(problems,
      "milestone 4 is at fraction %.4f, not 0.5 -- it must be the lane's bend, " ..
      "because the builder places every other milestone relative to it",
      shape.milestone_fraction[4])
  end
end
-- }}}

-- {{{ local function check_sites()
-- Every structure site stands on a node that exists and is the right kind of
-- node to hold it.
local function check_sites(map, problems)
  local expected_kind = {
    [1] = 3,  -- lane tower stands on a tower site
    [2] = 3,  -- base tower stands on a tower site
    [3] = 5,  -- library stands on a library site
  }
  for index, site in ipairs(map.site) do
    local node = map.node[site.node]
    if node == nil then
      complain(problems, "structure site %d stands on node %d, which does not exist",
               index, site.node)
    elseif node.kind ~= expected_kind[site.kind] then
      complain(problems,
        "structure site %d is kind %d but stands on a node of kind %d",
        index, site.kind, node.kind)
    end
  end
end
-- }}}

-- {{{ local function check_site_count()
-- Both teams get the same stone, and there is the right amount of it.
--
-- This check exists because the site emission was once deleted by accident during a
-- refactor, and **everything still worked**: the map built, the validator passed,
-- every existing check was about sites that were there rather than sites that should
-- be. A match ran for two hundred seconds with no towers on it at all before anybody
-- noticed the number in a report.
--
-- The lesson generalises past this one bug. A validator that only checks what it
-- finds cannot notice an absence, and an absence is exactly what a refactor
-- produces.
local function check_site_count(map, parameters, problems)
  local lanes = parameters.lane_count
  -- Three towers per lane per team -- an outer, an inner, and one at the lane's
  -- mouth inside the base -- plus one library each.
  local want_towers = lanes * 3
  local seen = {[1] = {tower = 0, library = 0}, [2] = {tower = 0, library = 0}}

  for _, site in ipairs(map.site) do
    local side = seen[site.team]
    if side == nil then
      complain(problems, "a structure site belongs to team %s", tostring(site.team))
    elseif site.kind == 3 then
      side.library = side.library + 1
    else
      side.tower = side.tower + 1
    end
  end

  for team = 1, 2 do
    if seen[team].tower ~= want_towers then
      complain(problems, "team %d has %d towers and should have %d",
               team, seen[team].tower, want_towers)
    end
    if seen[team].library ~= 1 then
      complain(problems, "team %d has %d libraries and should have exactly one",
               team, seen[team].library)
    end
  end

  -- And every tower's opposite number exists, so the two halves hold the same stone
  -- in the same places rather than merely the same amount of it.
  local mine = {}
  for _, site in ipairs(map.site) do
    if site.kind ~= 3 then
      local key = site.lane .. ":" .. site.milestone .. ":" .. site.kind
      mine[key] = (mine[key] or 0) + ((site.team == 1) and 1 or -1)
    end
  end
  for key, balance in pairs(mine) do
    if balance ~= 0 then
      complain(problems, "the two teams' stone does not match at %s", key)
    end
  end
end
-- }}}

-- {{{ local function check_reachable()
-- Every node is reachable from team 1's library. Catches a connector that was
-- built between the wrong pair of junctions, or a lane that was emitted and
-- never joined to anything.
local function check_reachable(map, problems)
  local seen = {}
  local frontier = {map.library_node[1]}
  seen[map.library_node[1]] = true
  local head = 1
  while head <= #frontier do
    local node = map.node[frontier[head]]
    head = head + 1
    for _, neighbour in ipairs(node.neighbour) do
      if not seen[neighbour] then
        seen[neighbour] = true
        frontier[#frontier + 1] = neighbour
      end
    end
  end

  local unreachable = 0
  for _, node in ipairs(map.node) do
    if not seen[node.id] then
      unreachable = unreachable + 1
    end
  end
  if unreachable > 0 then
    complain(problems, "%d of %d nodes cannot be reached from team 1's library",
             unreachable, #map.node)
  end
end
-- }}}

-- {{{ function M.check()
-- Runs every check and returns the list of problems found. Empty means the map
-- is sound.
function M.check(map, parameters)
  local problems = {}
  check_fractions(parameters.shape, problems)
  check_nodes(map, problems)
  check_lane_paths(map, problems)
  check_mirror(map, problems)
  check_sites(map, problems)
  check_site_count(map, parameters, problems)
  check_reachable(map, problems)
  return problems
end
-- }}}

-- {{{ function M.insist()
-- The form the rest of the project calls: check, and stop the program if
-- anything is wrong, naming every problem rather than only the first. One bad
-- map usually produces a family of related complaints, and seeing the family is
-- what identifies the cause.
function M.insist(map, parameters)
  local problems = M.check(map, parameters)
  if #problems > 0 then
    error("the map is malformed and the match cannot start:\n    " ..
          table.concat(problems, "\n    "))
  end
  return map
end
-- }}}

return M
