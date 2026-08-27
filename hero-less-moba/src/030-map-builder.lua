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

-- 030-map-builder.lua
--
-- Builds the path graph. There is no map editor and no hand-editable map file --
-- a map that has been hand-tweaked cannot be regenerated, and a map that cannot
-- be regenerated is a map nobody dares change. So this takes the shape
-- parameters and emits the ground.
--
-- The shape, once, in words, because the arithmetic below is much easier to read
-- with the picture already in your head:
--
--   The field is a square. Team 1's library sits in from the bottom-left corner
--   and team 2's in from the top-right, so the two bases face each other along
--   one diagonal. The three junctions sit on the *other* diagonal -- the
--   top-left corner, the middle of the field, the bottom-right corner.
--
--   The top lane leaves team 1's base, runs to the top-left corner, bends there,
--   and runs on to team 2's base. The bottom lane does the same through the
--   bottom-right corner. The centre lane runs straight from base to base and its
--   junction is simply its midpoint -- a plain point on a straight line rather
--   than a bend.
--
--   A short connector joins each side lane's junction to the middle. That
--   diagonal is the ground the jungle used to occupy with everything that made
--   it jungle taken out of it. Nothing spawns there and no tower covers it.
--
-- The one fact that makes the rest of this file short: **milestone 4 is exactly
-- the bend.** Team 1's library and team 2's library are mirror images about the
-- anti-diagonal, so a side lane's two legs are the same length, so the bend
-- falls at exactly half the lane's length -- which is where milestone 4 goes.
-- Every pair of consecutive milestones is therefore joined by a straight line,
-- and placing nodes between them is linear interpolation rather than walking a
-- polyline by arc length.

local M = {}

-- Node kinds. Named here so that no other file writes the bare integer.
M.NODE_PLAIN    = 1
M.NODE_JUNCTION = 2
M.NODE_TOWER    = 3
M.NODE_SPAWN    = 4
M.NODE_LIBRARY  = 5

-- Structure kinds, same reasoning.
M.STRUCTURE_LANE_TOWER = 1
M.STRUCTURE_BASE_TOWER = 2
M.STRUCTURE_LIBRARY    = 3

-- {{{ local function side_of_field()
-- Which team's half a point sits in. The anti-diagonal y == x divides the field:
-- team 1's library is below-left of it, team 2's above-right. A point exactly on
-- the line -- every junction, every connector node -- belongs to neither, which
-- is what team 0 means.
local function side_of_field(x, y)
  if y > x then
    return 1
  elseif y < x then
    return 2
  end
  return 0
end
-- }}}

-- {{{ local function add_node()
-- Appends one node and returns its id. Every field is written here, so there is
-- exactly one place in the project where a node comes into being with all of its
-- fields present -- which is what lets the movement loop skip nil checks
-- entirely.
local function add_node(map, x, y, kind, lane, milestone)
  local id = #map.node + 1
  map.node[id] = {
    id        = id,
    x         = x,
    y         = y,
    kind      = kind,
    lane      = lane,
    milestone = milestone,
    team      = side_of_field(x, y),
    neighbour = {},
    -- Zero, not nil. A node with no structure holds a sentinel with a meaning;
    -- nil would be a question about whether this builder did its job, and that
    -- question belongs to the validator, asked once, not to the move pass asked
    -- a thousand times a tick.
    structure = 0,
  }
  return id
end
-- }}}

-- {{{ local function join()
-- Makes two nodes neighbours of each other. Undirected, and idempotent, because
-- the library node is reached once per lane and would otherwise collect three
-- copies of the same neighbour.
local function join(map, a, b)
  local node_a = map.node[a]
  local node_b = map.node[b]
  for _, existing in ipairs(node_a.neighbour) do
    if existing == b then
      return
    end
  end
  node_a.neighbour[#node_a.neighbour + 1] = b
  node_b.neighbour[#node_b.neighbour + 1] = a
end
-- }}}

-- {{{ local function interpolate()
-- The point a fraction u of the way from one point to another.
local function interpolate(ax, ay, bx, by, u)
  return ax + (bx - ax) * u, ay + (by - ay) * u
end
-- }}}

-- {{{ local function milestone_point()
-- Where milestone m of a lane sits, given the lane's three defining points.
--
-- Milestones 0 through 4 lie on the first leg and 4 through 8 on the second, and
-- the fraction table is rescaled onto whichever leg the milestone belongs to.
-- This is the function that depends on milestone 4 being the bend; if the two
-- legs were ever different lengths this would place milestones unevenly and the
-- validator's mirror check is what would catch it.
local function milestone_point(shape, from_x, from_y, bend_x, bend_y, to_x, to_y, m)
  local fraction = shape.milestone_fraction[m]
  if m <= 4 then
    return interpolate(from_x, from_y, bend_x, bend_y, fraction / 0.5)
  end
  return interpolate(bend_x, bend_y, to_x, to_y, (fraction - 0.5) / 0.5)
end
-- }}}

-- {{{ local function fill_between()
-- Lays plain nodes along the straight line between two already-placed nodes,
-- joining them into a chain. Returns nothing; the chain is written into the
-- lane's path as it goes.
--
-- The count is chosen to hold roughly the target spacing, and is at least one
-- segment -- two milestones are never allowed to be the same node, because the
-- push-depth arithmetic reads a node's milestone field and a node cannot carry
-- two of them.
local function fill_between(map, lane, first_id, second_id, spacing)
  local first  = map.node[first_id]
  local second = map.node[second_id]
  local dx, dy = second.x - first.x, second.y - first.y
  local distance = math.sqrt(dx * dx + dy * dy)

  local segments = math.floor(distance / spacing + 0.5)
  if segments < 1 then
    segments = 1
  end

  local previous = first_id
  for step = 1, segments - 1 do
    local u = step / segments
    local x, y = interpolate(first.x, first.y, second.x, second.y, u)
    -- Milestone 0 on a plain node means "this node is not a milestone". It is
    -- always read together with the node's kind, never alone -- a plain node and
    -- team 1's library both store zero here and they are not the same thing.
    local id = add_node(map, x, y, M.NODE_PLAIN, lane.id, 0)
    join(map, previous, id)
    lane.path[#lane.path + 1] = id
    previous = id
  end

  join(map, previous, second_id)
  lane.path[#lane.path + 1] = second_id
end
-- }}}

-- {{{ local function smooth_the_bend()
-- Rounds a lane's corner, in place, by relaxing the node positions around it.
--
-- Each node in a window centred on the junction is pulled toward the midpoint of
-- its two neighbours, a few times over, with the two ends of the window pinned. On
-- a straight that does nothing; at a vertex it cuts the corner, and repeating it
-- turns the cut into an arc.
--
-- **The junction node moves and keeps its identity.** Its id, its milestone index
-- and the sign-post standing on it are all unchanged -- only its position shifts
-- inward, to the apex of the new curve. Everything that refers to the junction goes
-- on referring to the same node.
--
-- The window is symmetric about the junction and the relaxation is symmetric, so a
-- lane that was a mirror of itself before still is afterwards. The map validator
-- checks that, which is what makes this safe to do to a finished lane.
local function smooth_the_bend(map, lane, shape)
  local junction = lane.path_index[lane.milestone_node[4]]
  if junction == nil then
    return
  end

  local window = shape.bend_smoothing_window
  local passes = shape.bend_smoothing_passes
  local first = junction - window
  local last  = junction + window
  if first < 2 then first = 2 end
  if last > #lane.path - 1 then last = #lane.path - 1 end
  if last - first < 2 then
    return
  end

  for _ = 1, passes do
    -- Read from a copy so that every node in a pass moves against the same
    -- positions. Relaxing in place would sweep the curve toward one end.
    local was_x, was_y = {}, {}
    for index = first - 1, last + 1 do
      local node = map.node[lane.path[index]]
      was_x[index], was_y[index] = node.x, node.y
    end
    for index = first, last do
      local node = map.node[lane.path[index]]
      node.x = (was_x[index - 1] + was_x[index] * 2 + was_x[index + 1]) * 0.25
      node.y = (was_y[index - 1] + was_y[index] * 2 + was_y[index + 1]) * 0.25
    end
  end
end
-- }}}

-- {{{ local function build_lane()
-- Emits one lane: its nine milestone nodes, the plain nodes between them, and
-- the tower and library sites standing on it.
local function build_lane(map, shape, lane_id, width,
                          from_x, from_y, bend_x, bend_y, to_x, to_y,
                          library_node_1, library_node_2)
  local lane = {
    id             = lane_id,
    path           = {},
    milestone_node = {},
    junction       = {},
    length         = 0,
    width          = width,
  }

  -- Milestones 0 and 8 are the two libraries, and all three lanes share them --
  -- one library node per team, not three. A wave leaves the library and fans out
  -- into whichever lane it was spawned for.
  lane.milestone_node[0] = library_node_1
  lane.milestone_node[8] = library_node_2

  for m = 1, 7 do
    local x, y = milestone_point(shape, from_x, from_y, bend_x, bend_y, to_x, to_y, m)
    -- Milestone 4 is the junction -- the bend on a side lane, the midpoint on the
    -- centre. It is the only node on a lane where a body has a choice to make.
    local kind = M.NODE_TOWER
    if m == 4 then
      kind = M.NODE_JUNCTION
    end
    lane.milestone_node[m] = add_node(map, x, y, kind, lane_id, m)
  end

  lane.junction[1] = lane.milestone_node[4]

  -- Walk the milestones in order, filling plain nodes between each pair. The
  -- path array comes out ordered from team 1's library to team 2's, which is the
  -- direction every "which way am I facing" question in the game is asked in.
  lane.path[1] = library_node_1
  for m = 0, 7 do
    fill_between(map, lane, lane.milestone_node[m], lane.milestone_node[m + 1],
                 shape.node_spacing)
  end

  -- Where each node sits in this lane's path, built first because the bend
  -- smoothing below needs to find the junction and everything after it needs the
  -- positions the smoothing settles on.
  lane.path_index = {}
  for index, node_id in ipairs(lane.path) do
    -- A library is both the first and last entry of every lane's path. The first
    -- wins, because a body entering a lane is always entering it from team 1's
    -- end; team 2's bodies are placed by index directly rather than by lookup.
    if lane.path_index[node_id] == nil then
      lane.path_index[node_id] = index
    end
  end

  -- Round the bend, before anything measures the lane.
  --
  -- A lane's junction was an infinitely sharp corner -- two straight legs meeting at
  -- a vertex -- and a body walking it turned ninety-odd degrees between one tick and
  -- the next. That was invisible while a formation could teleport round the outside
  -- of a turn, and became a hole in the map the moment movement was capped by the
  -- distance actually travelled: the body on the outside needed to cover most of a
  -- right angle's arc in one step, could not, and fell most of a formation's length
  -- behind.
  --
  -- **Real roads do not have vertices.** And a curve is what makes "the formation
  -- curves to match the path it is on" a sentence with something to match.
  smooth_the_bend(map, lane, shape)

  -- The length of every step along the path, and the lane's total.
  --
  -- Precomputed because the move pass divides a body's speed by the length of the
  -- edge it is on, once per body per tick. Computing that square root a thousand
  -- times a tick to get an answer that cannot change is the definition of work the
  -- map should have done once.
  --
  -- **After the smoothing**, because the smoothing moves nodes and every one of
  -- these numbers is a distance between two of them.
  lane.step_length = {}
  -- How far along the lane each path node sits, measured from team 1's library.
  --
  -- This is what lets a body's position be a **single number** -- how far down the
  -- lane it is -- rather than an edge and a fraction of it. A formation is a set of
  -- offsets from one such number, so a rank stays a rank when the lane bends: every
  -- body in it is at the same distance along, and the lane's own curve carries them
  -- round the corner together.
  lane.cumulative = {}
  local total = 0
  lane.cumulative[1] = 0
  for index = 1, #lane.path - 1 do
    local a = map.node[lane.path[index]]
    local b = map.node[lane.path[index + 1]]
    local step = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
    lane.step_length[index] = step
    total = total + step
    lane.cumulative[index + 1] = total
  end
  lane.length = total

  -- Where each milestone sits in the path array, so that "how far has this lane
  -- been pushed" is an integer comparison rather than a geometry problem.
  --
  -- Milestones 0 and 8 are both the shared library nodes, so their path indices
  -- cannot be looked up by node id -- both would answer 1. They are written
  -- directly instead: the start of the path and the end of it.
  lane.milestone_index = {}
  lane.milestone_index[0] = 1
  lane.milestone_index[8] = #lane.path
  for m = 1, 7 do
    lane.milestone_index[m] = lane.path_index[lane.milestone_node[m]]
  end

  -- The stone. Milestones 1, 2, 3 are team 1's base tower, inner tower and outer
  -- tower; 7, 6, 5 are team 2's, mirrored. The milestone recorded on the site is
  -- counted from the **owning** team's end, which is why team 2's outer tower at
  -- lane milestone 5 records a 3.
  local sites = {
    {team = 1, m = 1, own = 1, kind = M.STRUCTURE_BASE_TOWER},
    {team = 1, m = 2, own = 2, kind = M.STRUCTURE_LANE_TOWER},
    {team = 1, m = 3, own = 3, kind = M.STRUCTURE_LANE_TOWER},
    {team = 2, m = 5, own = 3, kind = M.STRUCTURE_LANE_TOWER},
    {team = 2, m = 6, own = 2, kind = M.STRUCTURE_LANE_TOWER},
    {team = 2, m = 7, own = 1, kind = M.STRUCTURE_BASE_TOWER},
  }
  for _, site in ipairs(sites) do
    map.site[#map.site + 1] = {
      team      = site.team,
      kind      = site.kind,
      lane      = lane_id,
      milestone = site.own,
      node      = lane.milestone_node[site.m],
    }
  end

  map.lane[lane_id] = lane
  return lane
end
-- }}}

-- {{{ local function build_connector()
-- Joins a side lane's junction to the middle with a short chain of nodes that
-- belong to no lane.
--
-- Connector nodes carry lane = 0 so that nothing treats them as part of a lane:
-- no wave spawns onto them, no tower covers them, and no push depth counts a
-- body standing on one. The only thing a connector is for is letting a body
-- leave the middle, which is a decision the four-junction layout never allowed
-- anybody to make.
local function build_connector(map, from_node, to_node, count, lane_a, lane_b)
  local first = map.node[from_node]
  local last  = map.node[to_node]

  -- The chain is recorded as an explicit list, because it is the one piece of
  -- ground in the game that a body walks without being on a lane. A hero that has
  -- obeyed a sign-post is out here, following this list node by node, and it needs
  -- to be a list rather than something rediscovered from the neighbour graph --
  -- the middle junction has four neighbours and two of them are connectors.
  local path = {from_node}

  local previous = from_node
  for step = 1, count do
    local u = step / (count + 1)
    local x, y = interpolate(first.x, first.y, last.x, last.y, u)
    local id = add_node(map, x, y, M.NODE_PLAIN, 0, 0)
    join(map, previous, id)
    path[#path + 1] = id
    previous = id
  end
  join(map, previous, to_node)
  path[#path + 1] = to_node

  map.connector[#map.connector + 1] = {
    id = #map.connector + 1,
    path = path,
    lane_a = lane_a,   -- the lane at path[1]
    lane_b = lane_b,   -- the lane at path[#path]
  }
end
-- }}}

-- {{{ function M.build()
-- Builds the whole map from the match parameters. Returns the map record:
--
--   node   array of node structs, 1-based, ids are indices
--   lane   array of lane structs, 1-based
--   site   array of structure sites the world will turn into structures
--   bounds {min_x, min_y, max_x, max_y} -- what the camera frames at rest
function M.build(parameters)
  local shape = parameters.shape

  if parameters.lane_count ~= 3 then
    error("the map builder lays out three lanes and was asked for " ..
          tostring(parameters.lane_count) ..
          " -- the geometry for other lane counts has not been written")
  end

  local size  = shape.field_size
  local inset = shape.base_inset

  local map = { node = {}, lane = {}, site = {}, connector = {} }

  -- The two libraries, created before any lane, because all three lanes share
  -- them and a lane cannot be built until its endpoints exist.
  local library_1 = add_node(map, inset, size - inset, M.NODE_LIBRARY, 0, 0)
  local library_2 = add_node(map, size - inset, inset, M.NODE_LIBRARY, 0, 0)

  local lib1 = map.node[library_1]
  local lib2 = map.node[library_2]

  -- The three bends, on the anti-diagonal.
  local top_left_x,     top_left_y     = 0, 0
  local centre_x,       centre_y       = size * 0.5, size * 0.5
  local bottom_right_x, bottom_right_y = size, size

  build_lane(map, shape, 1, shape.lane_width[1],
             lib1.x, lib1.y, top_left_x, top_left_y, lib2.x, lib2.y,
             library_1, library_2)

  build_lane(map, shape, 2, shape.lane_width[2],
             lib1.x, lib1.y, centre_x, centre_y, lib2.x, lib2.y,
             library_1, library_2)

  build_lane(map, shape, 3, shape.lane_width[3],
             lib1.x, lib1.y, bottom_right_x, bottom_right_y, lib2.x, lib2.y,
             library_1, library_2)

  -- The libraries themselves, one site each. A library node is also its team's
  -- spawn point -- waves leave the library, fan into the three lanes, and never
  -- come back.
  map.site[#map.site + 1] = {team = 1, kind = M.STRUCTURE_LIBRARY, lane = 0,
                             milestone = 0, node = library_1}
  map.site[#map.site + 1] = {team = 2, kind = M.STRUCTURE_LIBRARY, lane = 0,
                             milestone = 0, node = library_2}

  map.library_node = {library_1, library_2}

  -- The two connectors, from each side lane's junction to the middle.
  build_connector(map, map.lane[1].junction[1], map.lane[2].junction[1],
                  shape.connector_nodes, 1, 2)
  build_connector(map, map.lane[3].junction[1], map.lane[2].junction[1],
                  shape.connector_nodes, 3, 2)

  -- What the camera frames at rest, computed from the map rather than written
  -- down, so that changing the field size reframes the view with no second edit.
  local min_x, min_y = math.huge, math.huge
  local max_x, max_y = -math.huge, -math.huge
  for _, node in ipairs(map.node) do
    if node.x < min_x then min_x = node.x end
    if node.y < min_y then min_y = node.y end
    if node.x > max_x then max_x = node.x end
    if node.y > max_y then max_y = node.y end
  end
  map.bounds = {min_x = min_x, min_y = min_y, max_x = max_x, max_y = max_y}

  return map
end
-- }}}

-- {{{ function M.lane_from_polyline()
-- Builds a single lane along an arbitrary path, with no milestones, no stone and
-- no second lane, and returns a map holding only that.
--
-- **This exists so that the formation can be tested without a match.** Asking
-- "does a rank stay a rank round a bend" through a whole world -- two teams, three
-- lanes, waves on a cadence, a chest, an economy, a phase clock -- means the answer
-- arrives buried in the noise of everything else, and means a change to any of
-- those can break the test for reasons that have nothing to do with formations.
--
-- A test that wants a sine wave should be able to ask for a sine wave.
--
-- `points` is a flat list of x, y pairs. `spacing` is the target distance between
-- generated nodes; the polyline is resampled to it, so a caller can hand over three
-- corners or three hundred samples of a curve and get the same kind of lane back.
function M.lane_from_polyline(points, width, spacing)
  local map = {node = {}, lane = {}, site = {}, connector = {}, library_node = {0, 0}}

  local lane = {
    id = 1, path = {}, milestone_node = {}, milestone_index = {},
    junction = {}, step_length = {}, cumulative = {}, path_index = {},
    length = 0, width = width,
  }

  -- Resample the polyline at the requested spacing, so that step lengths are even
  -- and the arc-length arithmetic behaves the way it does on a real lane.
  local corner_count = #points / 2
  local previous_x, previous_y = points[1], points[2]
  local emitted = {previous_x, previous_y}

  for corner = 2, corner_count do
    local target_x, target_y = points[corner * 2 - 1], points[corner * 2]
    local dx, dy = target_x - previous_x, target_y - previous_y
    local run = math.sqrt(dx * dx + dy * dy)
    local steps = math.floor(run / spacing + 0.5)
    if steps < 1 then steps = 1 end
    for step = 1, steps do
      local u = step / steps
      emitted[#emitted + 1] = previous_x + dx * u
      emitted[#emitted + 1] = previous_y + dy * u
    end
    previous_x, previous_y = target_x, target_y
  end

  for index = 1, #emitted / 2 do
    local id = add_node(map, emitted[index * 2 - 1], emitted[index * 2],
                        M.NODE_PLAIN, 1, 0)
    lane.path[index] = id
    lane.path_index[id] = index
    if index > 1 then
      join(map, lane.path[index - 1], id)
    end
  end

  local total = 0
  lane.cumulative[1] = 0
  for index = 1, #lane.path - 1 do
    local a, b = map.node[lane.path[index]], map.node[lane.path[index + 1]]
    local step = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
    lane.step_length[index] = step
    total = total + step
    lane.cumulative[index + 1] = total
  end
  lane.length = total

  -- Milestones evenly spaced along it, so that anything reading them finds nine
  -- and does not have to know this lane was made for a test.
  for m = 0, 8 do
    local want = total * (m / 8)
    local at = 1
    for index = 1, #lane.path do
      if lane.cumulative[index] <= want then at = index end
    end
    lane.milestone_index[m] = at
    lane.milestone_node[m] = lane.path[at]
  end
  lane.junction[1] = lane.milestone_node[4]

  map.lane[1] = lane
  map.bounds = {min_x = math.huge, min_y = math.huge, max_x = -math.huge, max_y = -math.huge}
  for _, node in ipairs(map.node) do
    if node.x < map.bounds.min_x then map.bounds.min_x = node.x end
    if node.y < map.bounds.min_y then map.bounds.min_y = node.y end
    if node.x > map.bounds.max_x then map.bounds.max_x = node.x end
    if node.y > map.bounds.max_y then map.bounds.max_y = node.y end
  end

  return map
end
-- }}}

-- {{{ function M.point_at()
-- Where a lane is, a given distance along it, and which way it is heading there.
--
-- Returns x, y, the unit tangent, and the path index the point falls in. The
-- **normal** -- across the lane -- is the tangent turned a quarter turn, and every
-- caller derives it that way rather than being handed it, so there is one
-- definition of which side is which.
--
-- `hint` is the path index to start searching from. A body asking where it is has
-- barely moved since last tick, so the search is two or three steps rather than a
-- scan of the whole lane. Passing a wrong hint is slow but never incorrect.
function M.point_at(map, lane, distance, hint)
  local last = #lane.path

  if distance <= 0 then
    local a, b = map.node[lane.path[1]], map.node[lane.path[2]]
    local dx, dy = b.x - a.x, b.y - a.y
    local length = math.sqrt(dx * dx + dy * dy)
    return a.x, a.y, dx / length, dy / length, 1
  end
  if distance >= lane.length then
    local a, b = map.node[lane.path[last - 1]], map.node[lane.path[last]]
    local dx, dy = b.x - a.x, b.y - a.y
    local length = math.sqrt(dx * dx + dy * dy)
    return b.x, b.y, dx / length, dy / length, last
  end

  local index = hint
  if index == nil or index < 1 or index > last - 1 then
    index = 1
  end
  -- Walk to whichever step contains the distance. Both directions, because a body
  -- can be behind its hint as well as ahead of it -- a rank re-forming after a turn
  -- has bodies moving backwards relative to the formation.
  while index > 1 and lane.cumulative[index] > distance do
    index = index - 1
  end
  while index < last - 1 and lane.cumulative[index + 1] <= distance do
    index = index + 1
  end

  local a, b = map.node[lane.path[index]], map.node[lane.path[index + 1]]
  local step = lane.step_length[index]
  local u = (distance - lane.cumulative[index]) / step
  local dx, dy = b.x - a.x, b.y - a.y
  return a.x + dx * u, a.y + dy * u, dx / step, dy / step, index
end
-- }}}

-- {{{ function M.dump()
-- Prints the graph as a coordinate list, so it can be checked before anything is
-- able to draw it. This existed before the renderer did and is kept, because it
-- is the only view of the map that can be diffed against yesterday's.
function M.dump(map)
  local lines = {}
  lines[#lines + 1] = string.format("%d nodes, %d lanes, %d structure sites",
                                    #map.node, #map.lane, #map.site)
  for _, lane in ipairs(map.lane) do
    lines[#lines + 1] = string.format(
      "lane %d: %d nodes, length %.1f paces, width %.0f",
      lane.id, #lane.path, lane.length, lane.width)
    for m = 0, 8 do
      local node = map.node[lane.milestone_node[m]]
      lines[#lines + 1] = string.format(
        "    milestone %d -> node %4d at (%7.1f, %7.1f) kind %d team %d",
        m, node.id, node.x, node.y, node.kind, node.team)
    end
  end
  return table.concat(lines, "\n")
end
-- }}}

return M
