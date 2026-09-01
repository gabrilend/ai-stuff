-- jurassic-maze — a simulation living inside an isometric maze of stacked stone
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

-- 031-carving.lua
--
-- Five passes from a seed to a maze.
--
-- The maze is not placed and it is not drawn. It is grown, and each pass may
-- look only at what the previous one left behind. Given the same seed, the same
-- maze comes out, on any machine, forever.
--
-- Passes A and B work on a height field; only pass E touches the stone. That
-- ordering is the reason staircases can be *cut* into slabs rather than built on
-- top of them -- there has to be something to cut into, and a height field is
-- the cheapest thing that can be notched.

local M = {}

-- {{{ local function require_local(root, name)
-- Loads a sibling source file by name. The simulation is loaded with plain Lua
-- rather than through a package path, so that the very same files run under a
-- bare luajit with no window -- which is how ten thousand mazes get built
-- overnight. See docs/009-seeing-it-without-a-window.md.
local function require_local(root, name)
  return dofile(root .. "/src/" .. name .. ".lua")
end
-- }}}

-- The four compass directions, as a table rather than as four cases, so that
-- iterating them is a loop. Movement is four-directional throughout the project;
-- see docs/004-standing-somewhere-and-going-elsewhere.md for why a diagonal is
-- refused rather than special-cased.
M.DIRECTIONS = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} }

-- {{{ function M.is_room(x, y)
-- The lattice, decided before anything random happens. Rooms are where a body
-- stands; links are the single cell between two rooms, opened into a corridor or
-- left as wall; pillars are both-even and are always wall.
--
-- Storing walls *as cells* rather than as edges between cells means the whole
-- maze lives in the one array of columns and there is nothing else to keep in
-- step with it. The cost is that a grid holds only about a quarter as many rooms
-- as cells, which is the price of one-cell-wide walls, and one-cell-wide walls
-- are what the reference picture has.
function M.is_room(x, y)
  return x % 2 == 1 and y % 2 == 1
end
-- }}}

-- {{{ function M.is_link(x, y)
function M.is_link(x, y)
  return (x % 2) ~= (y % 2)
end
-- }}}

-- {{{ local function link_height(ha, hb)
-- What height the cell between two rooms takes, given their heights.
--
--   difference 0 -> the same as both; flat
--   difference 1 -> the lower room's; one step of one layer
--   difference 2 -> one above the lower; two steps of one layer each
--
-- Three or more cannot be bridged by a single cell and is refused by the
-- neighbour filter in pass B. Those rooms are joined by a staircase in pass D.
local function link_height(ha, hb)
  local low  = math.min(ha, hb)
  local diff = math.abs(ha - hb)
  if diff <= 1 then return low end
  return low + 1
end
-- }}}

-- {{{ local function pass_a_terraces(p, streams, room_height, rooms_x, rooms_y)
-- The terraces. Produces a landscape and knows nothing about mazes.
--
-- Slabs are piled **nested**, each one smaller than the last and roughly on top
-- of it, with its centre wandering by a fraction of its own size. That is the
-- literal reading of what was asked for -- a successive layer of flat stones,
-- rectangular, piled upon one another -- and it is a stepped mound, which is
-- what the reference picture is.
--
-- The first thing tried here was scattered rectangles of random size and
-- position, and it is worth recording why it was wrong, because it looked
-- reasonable written down. Seventy overlapping rectangles do not make terraces;
-- they make noise. Every rectangle edge is a height change, edges land
-- everywhere, and each cell ends up at (however many rectangles happen to cover
-- it) times the rise. The result renders as a field of individual cubes at a
-- hundred different heights -- a city, not a maze -- and the corridors stop
-- being legible because the walls flanking one are all different heights.
--
-- Nesting fixes it by making the edges few and long. Within one slab every room
-- is at the same height, so every wall on that terrace stands at the same
-- height, so a corridor reads as a channel between two long walls. That is the
-- entire visual difference between this and the reference picture.
local function pass_a_terraces(p, streams, room_height, rooms_x, rooms_y)
  local rng = streams.terrace

  -- Rooms are capped below the world's ceiling by exactly the height of a wall,
  -- so that a wall standing on the tallest possible room still fits. Without the
  -- cap the walls around a summit would clamp to the room's own height and stop
  -- being walls, and the summit would silently become one open plaza.
  local ceiling = p.layers - 1 - p.wall_rise
  if ceiling < 1 then
    error("layers=" .. p.layers .. " and wall_rise=" .. p.wall_rise ..
          " leave no room for a room below a wall")
  end

  for i = 0, rooms_x * rooms_y - 1 do
    room_height[i] = 0
  end

  -- Sizes are quoted in cells; the room lattice is half as dense in each axis.
  local largest  = math.max(1, math.floor(p.terrace_max / 2))
  local smallest = math.max(1, math.floor(p.terrace_min / 2))

  local cx = rooms_x * 0.5
  local cy = rooms_y * 0.5

  for k = 1, p.terrace_count do
    -- Shrink from the largest slab to the smallest across the whole pile, so the
    -- bottom terrace is nearly the footprint and the summit is a plinth.
    local t = (p.terrace_count > 1) and ((k - 1) / (p.terrace_count - 1)) or 0
    local half_w = (largest + (smallest - largest) * t) * 0.5
    local half_h = half_w * (rooms_y / rooms_x)

    -- The centre wanders by a fraction of the slab's own size. Perfectly
    -- concentric slabs read as a wedding cake; wandering ones read as a ruin
    -- that settled, which is what the picture looks like.
    local wander = p.terrace_wander
    local ox = (rng:next_float() * 2 - 1) * half_w * wander
    local oy = (rng:next_float() * 2 - 1) * half_h * wander

    -- A slab is allowed to be a bit oblong, so the pile is not a stack of
    -- squares seen from above.
    local stretch = 1 + (rng:next_float() * 2 - 1) * 0.25
    local sw = half_w * stretch
    local sh = half_h / stretch

    local x0 = math.floor(cx + ox - sw)
    local x1 = math.ceil (cx + ox + sw)
    local y0 = math.floor(cy + oy - sh)
    local y1 = math.ceil (cy + oy + sh)

    for ry = math.max(0, y0), math.min(rooms_y - 1, y1) do
      for rx = math.max(0, x0), math.min(rooms_x - 1, x1) do
        local i = rx + ry * rooms_x
        local lifted = room_height[i] + p.terrace_rise
        -- Clamping produces a flat summit rather than an error, and a flat
        -- summit is a real feature of a pile of slabs rather than a failure.
        room_height[i] = (lifted > ceiling) and ceiling or lifted
      end
    end
  end

  -- A handful of small outcrops and hollows on top of the terraces, so the
  -- silhouette is not perfectly monotonic from the edge to the summit. These are
  -- the only slabs allowed to be scattered, and there are few enough of them
  -- that they read as features rather than as noise.
  for _ = 1, p.outcrops do
    local w = rng:next_between(2, math.max(3, smallest))
    local h = rng:next_between(2, math.max(3, smallest))
    local x0 = rng:next_below(rooms_x) - 1
    local y0 = rng:next_below(rooms_y) - 1
    local rise = rng:chance(0.5) and p.terrace_rise or -p.terrace_rise

    for ry = math.max(0, y0), math.min(rooms_y - 1, y0 + h) do
      for rx = math.max(0, x0), math.min(rooms_x - 1, x0 + w) do
        local i = rx + ry * rooms_x
        local lifted = room_height[i] + rise
        if lifted < 0 then lifted = 0 end
        room_height[i] = (lifted > ceiling) and ceiling or lifted
      end
    end
  end
end
-- }}}

-- {{{ local function room_regions(room_height, rooms_x, rooms_y, region)
-- Groups rooms into the sets the maze carver will be able to join by itself.
--
-- Pass B can bridge a gap of two layers with the single cell between two rooms
-- and no more, so a "region" here is a maximal set of rooms reachable through
-- gaps of two or less. On a pile of terraces four layers apart, that is one
-- region per terrace.
local function room_regions(room_height, rooms_x, rooms_y, region)
  local n = rooms_x * rooms_y
  for i = 0, n - 1 do region[i] = 0 end

  local count = 0
  local stack = {}

  for start = 0, n - 1 do
    if region[start] == 0 then
      count = count + 1
      region[start] = count
      stack[1] = start
      local top = 1

      while top > 0 do
        local i = stack[top]
        top = top - 1
        local rx = i % rooms_x
        local ry = (i - rx) / rooms_x

        for di = 1, 4 do
          local d = M.DIRECTIONS[di]
          local nx, ny = rx + d[1], ry + d[2]
          if nx >= 0 and ny >= 0 and nx < rooms_x and ny < rooms_y then
            local j = nx + ny * rooms_x
            if region[j] == 0
               and math.abs(room_height[j] - room_height[i]) <= 2 then
              region[j] = count
              top = top + 1
              stack[top] = j
            end
          end
        end
      end
    end
  end

  return count
end
-- }}}

-- {{{ local function pass_a2_staircases(p, streams, room_height, rooms_x, rooms_y, forced, locked, report)
-- Places the flights of steps **before** the maze is carved.
--
-- This is the pass that used to run last, and moving it is the single largest
-- correction in the generator. Cutting a staircase into a maze that already
-- exists means overwriting cells the maze was relying on: the flight lands
-- correctly, and whatever was reachable only through the room it dropped three
-- layers is severed. Six hundred flights would get built and rejected for that,
-- terraces stayed unreachable, and the generator blamed its own parameters. The
-- fix is not a better rejection test. It is to place the flights first and let
-- the maze be carved around them.
--
-- A flight is expressed entirely in the room heights, which is what makes it
-- cheap. Rooms sit two cells apart and a link between two rooms two layers apart
-- takes the height between them, so a run of rooms whose heights step by two is
-- already a staircase of single-layer steps once pass C fills the links in. A
-- flight from a room at height h to one `gap` cells away at h+gap is therefore
-- just: set the rooms along the way to h+2, h+4, ... and force the links between
-- them open.
--
-- Nothing here touches a cell. Pass C builds the whole thing out of the ordinary
-- machinery, and the flight is part of the maze rather than a wound in it.
local function pass_a2_staircases(p, streams, room_height, rooms_x, rooms_y,
                                  forced, locked, report)
  local rng = streams.stair
  local region = {}
  local placed, extra = 0, 0

  -- {{{ local function try_flight(from, d, steps)
  -- Lays the rooms of one flight, or reports why it will not fit.
  local function try_flight(from, d, steps)
    local rx = from % rooms_x
    local ry = (from - rx) / rooms_x
    local h0 = room_height[from]

    local target_rx = rx + d[1] * steps
    local target_ry = ry + d[2] * steps
    if target_rx < 0 or target_ry < 0
       or target_rx >= rooms_x or target_ry >= rooms_y then return false end

    local target = target_rx + target_ry * rooms_x
    local h1 = room_height[target]
    local rise = (h1 - h0) / steps
    -- Each room-step covers two layers, because the single cell between two
    -- rooms can hold exactly one step of one layer on each side of itself.
    if rise ~= 2 and rise ~= -2 then return false end

    -- Nothing along the way may already belong to another flight, or two
    -- staircases would each rewrite the other's steps and neither would climb.
    for k = 1, steps - 1 do
      local i = (rx + d[1] * k) + (ry + d[2] * k) * rooms_x
      if locked[i] then return false end
    end

    for k = 1, steps - 1 do
      local i = (rx + d[1] * k) + (ry + d[2] * k) * rooms_x
      room_height[i] = h0 + rise * k
      locked[i] = true
    end

    -- Force every link along the flight open, including the two at its ends, so
    -- the carver cannot decide to wall the staircase off.
    for k = 0, steps - 1 do
      local a = (rx + d[1] * k)       + (ry + d[2] * k)       * rooms_x
      local b = (rx + d[1] * (k + 1)) + (ry + d[2] * (k + 1)) * rooms_x
      forced[a .. ":" .. b] = true
      forced[b .. ":" .. a] = true
    end

    locked[from]   = true
    locked[target] = true
    return true
  end
  -- }}}

  -- {{{ local function gather_sites()
  -- Every straight run between two rooms whose height difference is exactly the
  -- number of room-steps between them, times two -- which is to say, every place
  -- a flight of single-layer steps would fit exactly.
  local function gather_sites(want_cross_region)
    local sites = {}
    for ry = 0, rooms_y - 1 do
      for rx = 0, rooms_x - 1 do
        local i = rx + ry * rooms_x
        if not locked[i] then
          for di = 1, 4 do
            local d = M.DIRECTIONS[di]
            for steps = 2, p.stair_steps do
              local nx, ny = rx + d[1] * steps, ry + d[2] * steps
              if nx < 0 or ny < 0 or nx >= rooms_x or ny >= rooms_y then break end
              local j = nx + ny * rooms_x
              local diff = room_height[j] - room_height[i]
              if diff == steps * 2 or diff == -steps * 2 then
                if (not want_cross_region) or region[i] ~= region[j] then
                  sites[#sites + 1] = { from = i, dir = d, steps = steps,
                                        a = region[i], b = region[j] }
                end
                break
              end
            end
          end
        end
      end
    end
    return sites
  end
  -- }}}

  -- Connectivity first: a spanning tree of flights over the terraces, cheapest
  -- (shortest) first, joining each pair once.
  for _ = 1, p.stair_rounds do
    local count = room_regions(room_height, rooms_x, rooms_y, region)
    if count <= 1 then break end

    local sites = gather_sites(true)
    if #sites == 0 then break end
    table.sort(sites, function(x, y) return x.steps < y.steps end)

    local parent = {}
    local function find(a)
      while parent[a] and parent[a] ~= a do a = parent[a] end
      return a
    end

    local joined = 0
    for _, site in ipairs(sites) do
      parent[site.a] = parent[site.a] or site.a
      parent[site.b] = parent[site.b] or site.b
      local ra, rb = find(site.a), find(site.b)
      if ra ~= rb then
        if try_flight(site.from, site.dir, site.steps) then
          parent[ra] = rb
          joined = joined + 1
          placed = placed + 1
        end
      end
    end

    if joined == 0 then break end
  end

  -- Then more than connectivity needed, at random, for the same reason the
  -- links get braided: a maze with exactly one way up to each terrace is one
  -- where every journey is forced.
  room_regions(room_height, rooms_x, rooms_y, region)
  local sites = gather_sites(false)
  rng:shuffle(sites)
  local want = math.floor(#sites * p.extra_stairs)
  for k = 1, math.min(want, #sites) do
    if try_flight(sites[k].from, sites[k].dir, sites[k].steps) then
      extra = extra + 1
    end
  end

  report.staircases_cut   = placed
  report.extra_staircases = extra
  report.staircase_sites  = #sites
end
-- }}}

-- {{{ local function pass_b_spanning_tree(p, streams, room_height, rooms_x, rooms_y, opened)
-- A randomized depth-first walk over the room lattice, opening the link between
-- each pair it steps across. What it leaves behind is a spanning tree: exactly
-- one route between any two rooms it could reach.
--
-- The neighbour relation is filtered by height -- a gap of three layers or more
-- cannot be bridged by one cell -- so this pass deliberately leaves several
-- components behind wherever a slab was piled high in one place. Pass D joins
-- them. That is expected, not a failure.
--
-- The walk is iterative with an explicit stack. A recursive one blows the Lua
-- stack somewhere around a few thousand rooms, which a 129-cell maze reaches,
-- and it does it as a crash that looks nothing to do with the maze.
local function pass_b_spanning_tree(p, streams, room_height, rooms_x, rooms_y,
                                    opened, forced)
  local rng = streams.carve
  local visited = {}

  -- The flights placed in pass A2 arrive already open, and the carver may add to
  -- them but never take them away. A staircase the maze decided to wall off at
  -- one end is a staircase to nowhere, and it would look completely deliberate.
  for key in pairs(forced or {}) do opened[key] = true end
  local stack   = {}
  local order   = {1, 2, 3, 4}

  -- A spanning **forest**, not a spanning tree.
  --
  -- The height filter below refuses to step across a gap of three layers or
  -- more, and a terrace stands four layers above the one under it, so a single
  -- walk carves exactly the terrace it started on and stops. Every other terrace
  -- is then left with all its links closed -- which is to say, left solid, with
  -- no corridors in it at all, a plateau of undisturbed stone that looks
  -- perfectly deliberate from above and has nothing inside it.
  --
  -- So the walk is restarted from every room it has not reached, and each
  -- restart carves another terrace. Pass D joins them afterwards with staircases,
  -- which is the only way between terraces and is the point of them.
  for origin = 0, rooms_x * rooms_y - 1 do
   if not visited[origin] then
    visited[origin] = true
    stack[1] = origin

    while #stack > 0 do
      local here = stack[#stack]
      local rx = here % rooms_x
      local ry = math.floor(here / rooms_x)

      rng:shuffle(order)

      local stepped = false
      for oi = 1, 4 do
        local d  = M.DIRECTIONS[order[oi]]
        local nx, ny = rx + d[1], ry + d[2]
        if nx >= 0 and ny >= 0 and nx < rooms_x and ny < rooms_y then
          local there = nx + ny * rooms_x
          if not visited[there] then
            local diff = math.abs(room_height[here] - room_height[there])
            if diff <= 2 then
              visited[there] = true
              opened[here .. ":" .. there] = true
              opened[there .. ":" .. here] = true
              stack[#stack + 1] = there
              stepped = true
              break
            end
          end
        end
      end

      -- Nothing left to step to from here: back out. This is the whole of the
      -- backtracking, and it is why the stack exists at all.
      if not stepped then
        stack[#stack] = nil
      end
    end
   end
  end

  -- Braiding. A spanning tree has no loops, and on a maze with no loops there is
  -- one route between any two rooms -- so a chase has a known ending and the
  -- pursued creature is cornered every time. The games in phase six need loops
  -- to exist at all. See docs/020-games-that-creatures-play.md.
  local braid_rng = streams.braid
  for ry = 0, rooms_y - 1 do
    for rx = 0, rooms_x - 1 do
      local here = rx + ry * rooms_x
      -- Only the two forward directions, or every link is considered twice and
      -- the effective braid rate is double what was asked for.
      for _, d in ipairs({ {1, 0}, {0, 1} }) do
        local nx, ny = rx + d[1], ry + d[2]
        if nx < rooms_x and ny < rooms_y then
          local there = nx + ny * rooms_x
          if not opened[here .. ":" .. there] then
            -- Only where the height rule permits. Braiding a link a body cannot
            -- use would make the maze look connected where it is not, which is
            -- worse than leaving it closed.
            if math.abs(room_height[here] - room_height[there]) <= 2
               and braid_rng:chance(p.braid) then
              opened[here .. ":" .. there] = true
              opened[there .. ":" .. here] = true
            end
          end
        end
      end
    end
  end

  return visited
end
-- }}}

-- {{{ local function pass_c_realise_heights(p, height, walkable, room_height, rooms_x, rooms_y, opened, width, depth)
-- Every cell gets a height, and every cell is marked floor or wall.
--
-- Rooms and opened links are floor and take their height from the maze.
-- Everything else -- closed links, pillars, and the rim -- becomes wall, at the
-- tallest neighbouring room's height plus `wall_rise`.
--
-- wall_rise is two, and the number matters. A body may climb one layer, so a
-- wall two layers above the corridor it flanks is exactly one layer taller than
-- the tallest thing anybody can climb: the cheapest a wall is allowed to be
-- while still being a wall. Three would look heavier and change nothing; one
-- would turn every wall in the maze into a step, and there would be no maze.
--
-- Taking the tallest *room* in the surrounding three-by-three, rather than the
-- tallest neighbour of any kind, is what guarantees that. A wall's four
-- neighbours are floors whose heights are all at or below that tallest room, so
-- the wall stands at least two above every one of them. Using the tallest
-- neighbour instead would let a wall beside a low corridor and a lower one
-- become exactly one layer up -- a step, in a place that is drawn as a wall.
local function pass_c_realise_heights(p, height, walkable, room_height,
                                      rooms_x, rooms_y, opened, width, depth)
  local ceiling = p.layers - 1

  for i = 0, width * depth - 1 do
    height[i]   = -1
    walkable[i] = false
  end

  for y = 0, depth - 1 do
    for x = 0, width - 1 do
      if M.is_room(x, y) then
        local i = x + y * width
        local rx, ry = (x - 1) / 2, (y - 1) / 2
        height[i]   = room_height[rx + ry * rooms_x]
        walkable[i] = true
      end
    end
  end

  for y = 0, depth - 1 do
    for x = 0, width - 1 do
      if M.is_link(x, y) then
        local i = x + y * width
        -- A link lies between two rooms along whichever axis it is odd in.
        local ax, ay, bx, by
        if x % 2 == 1 then ax, ay, bx, by = x, y - 1, x, y + 1
        else               ax, ay, bx, by = x - 1, y, x + 1, y end

        if ax >= 0 and ay >= 0 and bx < width and by < depth then
          local ra = ((ax - 1) / 2) + ((ay - 1) / 2) * rooms_x
          local rb = ((bx - 1) / 2) + ((by - 1) / 2) * rooms_x
          if opened[ra .. ":" .. rb] then
            height[i]   = link_height(room_height[ra], room_height[rb])
            walkable[i] = true
          end
        end
      end
    end
  end

  for y = 0, depth - 1 do
    for x = 0, width - 1 do
      local i = x + y * width
      if not walkable[i] then
        local tallest = 0
        for dy = -1, 1 do
          for dx = -1, 1 do
            local nx, ny = x + dx, y + dy
            if nx >= 0 and ny >= 0 and nx < width and ny < depth
               and M.is_room(nx, ny) then
              local rk = ((nx - 1) / 2) + ((ny - 1) / 2) * rooms_x
              if room_height[rk] > tallest then tallest = room_height[rk] end
            end
          end
        end
        local h = tallest + p.wall_rise
        height[i] = (h > ceiling) and ceiling or h
      end
    end
  end
end
-- }}}

-- {{{ local function floor_components(height, walkable, width, depth, climb_limit, label)
-- Labels the connected pieces **of the floor**, flooding only through floor.
--
-- Flooding through every cell and then counting which labels happen to contain
-- floor was the first version, and it reports a maze as whole that is not. Two
-- terraces with no staircase between them are joined, in that version, by any
-- chain of wall tops that happens to run from one to the other at climbable
-- heights -- a route along the tops of the walls, which nothing can reach and
-- nothing would take. The generator then cuts no staircase, because it believes
-- there is nothing to join, and the maze it hands over is in two pieces.
--
-- Every wall top in the maze is still a surface and still a piece of its own;
-- there are about a thousand of them and there always will be, because a wall
-- you can climb onto is not a wall. They are simply not this function's
-- business.
local function floor_components(height, walkable, width, depth, climb_limit, label)
  for i = 0, width * depth - 1 do label[i] = 0 end

  local sizes = {}
  local count = 0
  local stack = {}

  for start = 0, width * depth - 1 do
    if walkable[start] and label[start] == 0 then
      count = count + 1
      local size = 0
      label[start] = count
      stack[1] = start
      local top = 1

      while top > 0 do
        local i = stack[top]
        top = top - 1
        size = size + 1

        local x = i % width
        local y = (i - x) / width
        local h = height[i]

        for di = 1, 4 do
          local d = M.DIRECTIONS[di]
          local nx, ny = x + d[1], y + d[2]
          if nx >= 0 and ny >= 0 and nx < width and ny < depth then
            local j = nx + ny * width
            if walkable[j] and label[j] == 0
               and math.abs(height[j] - h) <= climb_limit then
              label[j] = count
              top = top + 1
              stack[top] = j
            end
          end
        end
      end

      sizes[count] = size
    end
  end

  return count, sizes, count
end
-- }}}

-- {{{ local function stranded_floor(height, walkable, width, depth, climb_limit, label)
-- How many floor cells are not in the biggest piece.
--
-- The obvious measure -- how many pieces there are -- turns out to be the wrong
-- one to steer by, and the reason is worth keeping. A flight cut into the side
-- of a terrace lands on a room and, in doing so, drops that room three layers
-- below the corridor it used to belong to. Whatever was reachable *only* through
-- that room is now cut off. So the flight joins two pieces and severs a third,
-- the count comes out unchanged, and a check that insists the count fall rejects
-- a staircase that did most of its job.
--
-- Stranded floor falls whenever a flight brings more into the main piece than it
-- strands, which is what actually wanted asking. It falls strictly, so the loop
-- still terminates, and what is left at the end is a handful of small pockets
-- for the orphan fill rather than whole terraces.
local function stranded_floor(height, walkable, width, depth, climb_limit, label)
  local count, sizes = floor_components(height, walkable, width, depth,
                                        climb_limit, label)
  local total, biggest = 0, 0
  for _, size in pairs(sizes) do
    total = total + size
    if size > biggest then biggest = size end
  end
  return total - biggest, count
end
-- }}}

-- {{{ local function cut_notch(p, height, walkable, width, depth, from, dir, target_h, saved)
-- Cuts a flight of steps from a floor cell in one direction until it meets the
-- ground on the other side.
--
-- The run rises (or falls) by exactly one layer per cell and **stops when the
-- next cell along is already within one layer of it** -- so the staircase finds
-- its own length instead of being told one. Cutting into a slab four layers
-- taller produces three steps; cutting through a single wall produces one.
--
-- `target_h` is the height of the floor this flight is meant to reach, and it is
-- passed in rather than worked out here. Working it out here meant taking the
-- height of the *first* floor cell along the ray -- which, on a run that has to
-- pass through the near edge of a terrace to reach the far one, is a cell at the
-- same height as the start. The slope came out as zero, the flight came out
-- flat, and it landed after one cell having climbed nothing and joined nothing.
-- Dozens of those get cut and the maze stays in pieces while the count of
-- staircases climbs.
--
-- Every cell it passes through is lowered or raised in place, floor included. In
-- the reference picture a staircase is a gash cut into the side of a block,
-- never a structure standing on top of one, and this is that cut.
--
-- Returns the number of cells changed, or nil if the run could not land.
local function cut_notch(p, height, walkable, width, depth, from, dir, target_h, saved)
  local fx, fy = from % width, math.floor(from / width)
  local h0 = height[from]

  local sign = 0
  if     target_h > h0 then sign =  1
  elseif target_h < h0 then sign = -1 end

  local changed = 0
  for step = 1, p.stair_reach do
    local cx, cy = fx + dir[1] * step, fy + dir[2] * step
    -- Never touch the rim. It is the only thing stopping a body that has gone
    -- wrong from leaving the world, and a staircase through it would be a hole
    -- in the side of the aquarium.
    if cx < 1 or cy < 1 or cx > width - 2 or cy > depth - 2 then return nil end

    local c = cx + cy * width
    local h = h0 + sign * step
    -- Once the flight is level with where it was going, it stops climbing and
    -- runs flat until it finds somewhere to land.
    if (sign > 0 and h > target_h) or (sign < 0 and h < target_h) then
      h = target_h
    end
    if h < 0 or h >= p.layers then return nil end

    changed = changed + 1
    saved[changed] = { c, height[c], walkable[c] }
    height[c]   = h
    walkable[c] = true

    -- Has it landed? The cell after this one is already close enough to step on.
    local nx, ny = cx + dir[1], cy + dir[2]
    if nx >= 0 and ny >= 0 and nx < width and ny < depth then
      local n = nx + ny * width
      if walkable[n] and math.abs(height[n] - h) <= p.climb_limit then
        return changed
      end
    end
  end

  return nil
end
-- }}}

-- {{{ local function pass_d_staircases(p, streams, height, walkable, width, depth, label, report)
-- Cuts staircases until the floor is one connected piece.
--
-- The obvious loop -- find one place to cut, cut it, relabel the whole maze,
-- repeat -- is correct and far too slow. A maze this size splits into dozens of
-- terraces, and relabelling sixteen thousand cells to join two of them means
-- doing that work dozens of times over.
--
-- So a round joins *all* of them at once. Scan once for every place two pieces
-- could be joined; sort those candidates by how big a staircase they need; then
-- walk them cheapest-first, cutting one only when it joins two pieces that are
-- still separate. That is Kruskal's algorithm with a staircase for an edge, and
-- it builds a spanning tree over the terraces in a single scan.
--
-- Rounds repeat because a cut can sever something on its way through -- lowering
-- a cell by three disconnects it from neighbours it used to reach. Two rounds in
-- a row that fail to reduce the count is a maze that will not converge, and it
-- stops loudly rather than spinning.
local function pass_d_staircases(p, streams, height, walkable, width, depth,
                                 label, report)
  local rng = streams.stair
  local cut = 0
  local saved = {}
  local stranded, count = stranded_floor(height, walkable, width, depth,
                                         p.climb_limit, label)
  local stalled = 0

  -- The per-cut check needs somewhere to label into that is **not** the array
  -- the round's decisions are reading.
  --
  -- Relabelling into `label` after each cut renumbers every piece in the maze,
  -- and the candidate list and the union-find were both built against the
  -- numbering from the start of the round. Every candidate after the first
  -- successful cut then reasons about piece numbers that no longer refer to
  -- anything, so the union-find believes pieces are already joined that are not,
  -- and skips the very flights that would have joined them. The symptom is a
  -- maze left in three or four pieces, each of which the diagnosis says has
  -- hundreds of perfectly good places to put a staircase.
  local scratch = {}

  -- Where the attempts went. A generator that fails should be able to say
  -- whether its flights could not be built, or were built and did not help.
  local tried, unbuilt, unhelpful = 0, 0, 0

  for _ = 1, p.stair_rounds do
    if count <= 1 then break end

    -- One scan. For every floor cell, look along each of the four directions for
    -- the first floor cell within reach; if it belongs to another piece, that is
    -- a candidate. Keep only the cheapest candidate per pair of pieces -- there
    -- are thousands of places two terraces touch and only one staircase is
    -- wanted between them.
    local candidates = {}
    local best_for   = {}
    for y = 1, depth - 2 do
      for x = 1, width - 2 do
        local i = x + y * width
        if walkable[i] then
          local li = label[i]
          for di = 1, 4 do
            local d = M.DIRECTIONS[di]
            -- The ray does **not** stop at the first floor cell it meets.
            --
            -- It did, and that was wrong in a way that took a failing seed to
            -- find. A terrace standing four layers above its neighbour has floor
            -- two cells away across the edge -- too close, because four layers
            -- of steps will not fit in two cells. Stopping there discarded the
            -- site, and the floor four or six cells along, which had room for
            -- the flight, was never considered. Whole terraces came out
            -- unreachable and the generator blamed its parameters.
            --
            -- A flight is allowed to cut straight through the near floor on its
            -- way, which is what a staircase notched into the side of a slab
            -- does anyway.
            for step = 2, p.stair_reach do
              local cx, cy = x + d[1] * step, y + d[2] * step
              if cx < 1 or cy < 1 or cx > width - 2 or cy > depth - 2 then break end
              local c = cx + cy * width
              if walkable[c] then
                local lc = label[c]
                if lc ~= li then
                  local gap = math.abs(height[c] - height[i])
                  -- A staircase needs somewhere to put its steps: a gap of four
                  -- layers cannot be climbed in three cells.
                  if step >= gap then
                    local a, b = li, lc
                    if a > b then a, b = b, a end
                    local key  = a * 1000000 + b
                    -- Cost is dominated by the height gap, with the run length
                    -- breaking ties, so a short steep flight beats a long ramp.
                    local cost = gap * 8 + step + rng:next_below(3)

                    -- Several candidates per pair of pieces, not one.
                    --
                    -- Keeping only the cheapest gives each pair exactly one
                    -- attempt per round, and a flight that lands correctly but
                    -- severs a branch on the way through is rejected -- after
                    -- which that pair is not tried again, because the next round
                    -- computes the same cheapest flight. Whole terraces stay
                    -- unreachable while the diagnosis reports hundreds of
                    -- perfectly good places to put a staircase, which is exactly
                    -- what it did.
                    local held = best_for[key]
                    if not held then
                      held = {}
                      best_for[key] = held
                      candidates[#candidates + 1] = key
                    end
                    if #held < p.stair_candidates then
                      held[#held + 1] = { cost = cost, from = i, dir = d,
                                          target_h = height[c] }
                    else
                      -- Replace the worst one held, so what survives is the
                      -- cheapest handful rather than the first handful found.
                      local worst, worst_at = -1, nil
                      for hi = 1, #held do
                        if held[hi].cost > worst then
                          worst, worst_at = held[hi].cost, hi
                        end
                      end
                      if cost < worst then
                        held[worst_at] = { cost = cost, from = i, dir = d,
                                           target_h = height[c] }
                      end
                    end
                    break   -- this ray has found its landing
                  end
                end
              end
            end
          end
        end
      end
    end

    if #candidates == 0 then break end

    -- Sort each pair's handful cheapest-first, then order the pairs by their
    -- cheapest option.
    for _, key in ipairs(candidates) do
      table.sort(best_for[key], function(a, b) return a.cost < b.cost end)
    end
    table.sort(candidates, function(a, b)
      return best_for[a][1].cost < best_for[b][1].cost
    end)

    -- Union-find over the pieces, so that walking the sorted candidates cuts a
    -- staircase only where it actually joins two things that are still apart.
    local parent = {}
    local function find(a)
      while parent[a] and parent[a] ~= a do
        parent[a] = parent[parent[a]] or parent[a]
        a = parent[a]
      end
      return a
    end

    local joined = 0
    for _, key in ipairs(candidates) do
      local b = key % 1000000
      local a = (key - b) / 1000000
      parent[a] = parent[a] or a
      parent[b] = parent[b] or b
      local ra, rb = find(a), find(b)
      if ra ~= rb then
        -- Try this pair's options in turn, stopping at the first that helps.
        for oi = 1, #best_for[key] do
        local pick = best_for[key][oi]
        tried = tried + 1
        local n = cut_notch(p, height, walkable, width, depth,
                            pick.from, pick.dir, pick.target_h, saved)

        -- Verified one at a time, and it has to be.
        --
        -- A flight is allowed to cut straight through floor on its way -- that
        -- is what notching a staircase into the side of a slab means -- and a
        -- cell it lowers by three is a cell that has lost its connections to the
        -- terrace it used to be part of. Sometimes that severs a branch of that
        -- terrace's maze. Cutting a round's worth and checking the total
        -- afterwards hides it: the count falls, because the flights joined more
        -- than they broke, and the maze quietly ends up in more pieces than it
        -- started with a hundred staircases in it. Checking each cut catches it
        -- on the one that did it.
        --
        -- Kruskal is what makes this affordable. It proposes one flight per pair
        -- of pieces rather than one per place they touch, so there are a few
        -- dozen relabels here rather than a few thousand.
        if n then
          local after = stranded_floor(height, walkable, width, depth,
                                       p.climb_limit, scratch)
          if after < stranded then
            stranded = after
            parent[ra] = rb
            joined = joined + 1
            cut = cut + 1
          else
            unhelpful = unhelpful + 1
            for k = 1, #saved do
              height[saved[k][1]]   = saved[k][2]
              walkable[saved[k][1]] = saved[k][3]
            end
          end
        else
          unbuilt = unbuilt + 1
          -- A flight that could not land must put back every cell it wrote on
          -- the way. Leaving the half-cut steps behind produces a staircase that
          -- climbs into a wall and stops -- floor cells at heights nothing else
          -- expects, and pieces of maze joined or severed by a thing that was
          -- never finished. Every symptom of it appears somewhere else entirely.
          for k = 1, #saved do
            height[saved[k][1]]   = saved[k][2]
            walkable[saved[k][1]] = saved[k][3]
          end
        end
        for k = 1, #saved do saved[k] = nil end
        if find(a) == find(b) then break end
        end
      end
    end

    if joined == 0 then
      stalled = stalled + 1
      if stalled >= 2 then break end
    else
      stalled = 0
    end

    -- Now, between rounds, the decisions may see the new numbering.
    stranded, count = stranded_floor(height, walkable, width, depth,
                                     p.climb_limit, label)
  end

  -- Whatever the staircases could not reach gets filled in.
  --
  -- A small pocket of floor at the bottom of a shaft, with no straight run to
  -- anywhere in ten cells, is not a place -- nothing can get to it, nothing can
  -- leave it, and a body spawned in it would stand there for the rest of the
  -- run. Raising it to wall height *removes* the problem rather than papering
  -- over it, which is why this is a pass and not a fallback. It is counted, and
  -- a pocket bigger than `orphan_max` is still an error: that is a terrace the
  -- generator failed to connect, not a crevice.
  count = floor_components(height, walkable, width, depth, p.climb_limit, label)
  local filled = 0
  if count > 1 then
    local _, sizes_now = floor_components(height, walkable, width, depth,
                                          p.climb_limit, label)
    local biggest_label, biggest = nil, -1
    for l, s in pairs(sizes_now) do
      if s > biggest then biggest, biggest_label = s, l end
    end
    for i = 0, width * depth - 1 do
      if walkable[i] and label[i] ~= biggest_label then
        if sizes_now[label[i]] <= p.orphan_max then
          walkable[i] = false
          -- Wall height, taken from whatever is tallest nearby, so the filled
          -- pocket reads as solid rock rather than as a suspiciously flat plug.
          local x, y = i % width, math.floor(i / width)
          local tallest = height[i]
          for dy = -1, 1 do
            for dx = -1, 1 do
              local nx, ny = x + dx, y + dy
              if nx >= 0 and ny >= 0 and nx < width and ny < depth then
                local h = height[nx + ny * width]
                if h > tallest then tallest = h end
              end
            end
          end
          height[i] = math.min(tallest, p.layers - 1)
          filled = filled + 1
        end
      end
    end
  end

  local _, sizes, total = floor_components(height, walkable, width, depth,
                                           p.climb_limit, label)
  count = 0
  for _ in pairs(sizes) do count = count + 1 end

  report.orphans_filled = filled
  report.repair_flights      = cut
  report.stair_attempts_made = tried
  report.stair_unbuildable   = unbuilt
  report.stair_unhelpful     = unhelpful
  report.floor_pieces   = count
  report.total_pieces   = total
  report.floor_sizes    = sizes

  if count > 1 then
    -- Loudly, and with the diagnosis attached.
    --
    -- A maze that needed a fallback tunnel to be connected is a maze whose
    -- parameters are wrong, and hiding that behind a repair means the parameters
    -- stay wrong forever. But "it is in four pieces" is not actionable on its
    -- own -- what is wanted is *why the pieces could not be joined*, which is
    -- one of a small number of things, and the numbers below say which.
    local pieces = {}
    for i = 0, width * depth - 1 do
      if walkable[i] then
        local l = label[i]
        local piece = pieces[l]
        if not piece then
          piece = { size = 0, low = 1e9, high = -1, rays = 0, near = 1e9 }
          pieces[l] = piece
        end
        piece.size = piece.size + 1
        if height[i] < piece.low  then piece.low  = height[i] end
        if height[i] > piece.high then piece.high = height[i] end
      end
    end

    -- For each piece, how many rays out of it reach other floor at all, and what
    -- the shallowest gap it could ever climb would be. A piece with no rays is
    -- walled in beyond the staircase reach; a piece with rays whose shallowest
    -- gap exceeds the distance is one where the flight has nowhere to put its
    -- steps.
    for i = 0, width * depth - 1 do
      if walkable[i] then
        local piece = pieces[label[i]]
        local x, y = i % width, math.floor(i / width)
        for di = 1, 4 do
          local d = M.DIRECTIONS[di]
          for step = 2, p.stair_reach do
            local cx, cy = x + d[1] * step, y + d[2] * step
            if cx < 1 or cy < 1 or cx > width - 2 or cy > depth - 2 then break end
            local c = cx + cy * width
            if walkable[c] and label[c] ~= label[i] then
              piece.rays = piece.rays + 1
              local need = math.abs(height[c] - height[i]) - step
              if need < piece.near then piece.near = need end
              break
            end
          end
        end
      end
    end

    local lines = {}
    for l, piece in pairs(pieces) do
      lines[#lines + 1] = string.format(
        "    piece %d: %d cells, layers %d to %d, %d rays to other floor, " ..
        "shallowest flight needs %d more cells than it has",
        l, piece.size, piece.low, piece.high, piece.rays,
        (piece.near == 1e9) and -1 or piece.near)
    end
    table.sort(lines)

    error(string.format(
      "maze seed %d has its floor in %d pieces after %d rounds of staircase " ..
      "cutting (%d cut of %d attempted; %d could not be built, %d were built " ..
      "and joined nothing). The parameters are wrong, not the maze.\n%s\n" ..
      "    stair_reach is %d and orphan_max is %d.",
      p.seed, count, p.stair_rounds, cut, tried, unbuilt, unhelpful,
      table.concat(lines, "\n"), p.stair_reach, p.orphan_max))
  end
end
-- }}}

-- {{{ local function pass_c2_plazas(p, streams, height, walkable, width, depth, report)
-- Clearings. A few rectangles on the terraces with their walls taken out.
--
-- The reference picture has them -- open courts among the corridors, which is
-- most of what stops it reading as uniform hatching. They earn their place for a
-- second reason as well, and it is the one that made them necessary rather than
-- decorative: **a body wider than one cell cannot stand anywhere in a maze of
-- one-cell corridors.** A three-by-three dinosaur needs nine contiguous cells at
-- one height, and the carver produces essentially none. Ninety dinosaurs were
-- spawned into a maze and fifty-seven of them never moved, because there was
-- nowhere for them to go.
--
-- A plaza only ever removes walls, so it can only help connectivity -- which is
-- why this can run before the repair pass without the repair having to know
-- about it.
local function pass_c2_plazas(p, streams, height, walkable, width, depth, report)
  local rng = streams.terrace
  local opened = 0

  -- Grown from a seed rather than placed blind.
  --
  -- Placing a rectangle at random and rejecting it if it straddles terraces
  -- rejects most of them -- six clearings out of twenty-six attempts -- because
  -- a terrace is not very large and a rectangle dropped anywhere is likely to
  -- cross an edge. Starting from a cell and growing while the ground stays level
  -- puts the clearing *on* a terrace by construction.
  for _ = 1, p.plaza_count do
    local sx = rng:next_between(3, width - 4)
    local sy = rng:next_between(3, depth - 4)
    local level = height[sx + sy * width]

    -- {{{ local function level_here(x0, y0, x1, y1)
    -- Whether a rectangle may be cleared.
    --
    -- A cell may be included when it is **already floor at exactly this level**,
    -- or when it is **wall** -- walls are what the clearing removes. Floor at a
    -- different level may not: lowering it detaches it from whatever it was
    -- connected to outside the rectangle, and a clearing that severs a terrace is
    -- not a courtyard.
    --
    -- The first version allowed anything within a wall's height of the level,
    -- which reads as generous and quietly moves floor. On some seeds it left a
    -- hundred and sixty-five cells stranded, and the maze validator -- correctly
    -- -- refused to hand the maze over.
    local function level_here(x0, y0, x1, y1)
      if x0 < 2 or y0 < 2 or x1 > width - 3 or y1 > depth - 3 then return false end
      for y = y0, y1 do
        for x = x0, x1 do
          local i = x + y * width
          if walkable[i] and height[i] ~= level then return false end
          -- A wall that would have to fall more than its own height to join the
          -- clearing is a different terrace's wall, not this one's.
          if not walkable[i] and math.abs(height[i] - level) > p.wall_rise + 1 then
            return false
          end
        end
      end
      return true
    end
    -- }}}

    local x0, y0, x1, y1 = sx, sy, sx, sy
    if level_here(x0, y0, x1, y1) then
      -- Grow one side at a time, in a shuffled order, so the clearings are not
      -- all squares with the same aspect.
      local sides = { 1, 2, 3, 4 }
      rng:shuffle(sides)
      local grew = true
      while grew do
        grew = false
        for _, side in ipairs(sides) do
          local nx0, ny0, nx1, ny1 = x0, y0, x1, y1
          if     side == 1 then nx0 = x0 - 1
          elseif side == 2 then nx1 = x1 + 1
          elseif side == 3 then ny0 = y0 - 1
          else                  ny1 = y1 + 1 end
          if (nx1 - nx0 + 1) <= p.plaza_max and (ny1 - ny0 + 1) <= p.plaza_max
             and level_here(nx0, ny0, nx1, ny1) then
            x0, y0, x1, y1 = nx0, ny0, nx1, ny1
            grew = true
          end
        end
      end

      if (x1 - x0 + 1) >= p.plaza_min and (y1 - y0 + 1) >= p.plaza_min then
        for y = y0, y1 do
          for x = x0, x1 do
            local i = x + y * width
            height[i]   = level
            walkable[i] = true
          end
        end
        opened = opened + 1
      end
    end
  end

  report.plazas = opened
end
-- }}}

-- {{{ local function pass_f_restore_walls(p, height, walkable, width, depth, report)
-- Puts the walls back to being walls after the staircases have been cut.
--
-- Pass C set every wall to the tallest room near it plus the wall rise, which
-- made it exactly one layer higher than anything could climb. Then passes D and
-- E cut flights of steps *through* terraces, raising and lowering cells that
-- those walls were measured against -- and a wall beside a step that has risen
-- to meet it is no longer a wall. It is a step, in a place the renderer draws as
-- a wall, which a body can climb onto and then walk along the top of.
--
-- So every wall is re-measured against whatever floor is actually beside it now.
-- This has to run after all the cutting and before the final connectivity check,
-- because a climbable wall also joins two pieces of floor through its own top,
-- and the check would then report a maze as whole on the strength of a route
-- that runs along the tops of the walls.
local function pass_f_restore_walls(p, height, walkable, width, depth, report)
  local ceiling = p.layers - 1
  local raised = 0

  for y = 0, depth - 1 do
    for x = 0, width - 1 do
      local i = x + y * width
      if not walkable[i] then
        local tallest_floor = -1
        for di = 1, 4 do
          local d = M.DIRECTIONS[di]
          local nx, ny = x + d[1], y + d[2]
          if nx >= 0 and ny >= 0 and nx < width and ny < depth then
            local n = nx + ny * width
            if walkable[n] and height[n] > tallest_floor then
              tallest_floor = height[n]
            end
          end
        end

        if tallest_floor >= 0 then
          local want = tallest_floor + p.wall_rise
          if want > ceiling then want = ceiling end
          if height[i] < want then
            height[i] = want
            raised = raised + 1
          end
        end
      end
    end
  end

  report.walls_raised = raised
end
-- }}}

-- {{{ function M.generate(root, p, streams)
-- The five passes, in order, returning the stone store and a report.
function M.generate(root, p, streams)
  local Stone = require_local(root, "030-the-stone")

  local width, depth = p.width, p.depth
  local rooms_x = (width - 1) / 2
  local rooms_y = (depth - 1) / 2

  local report = { seed = p.seed, width = width, depth = depth, layers = p.layers }

  local room_height = {}
  local opened      = {}
  local forced      = {}
  local locked      = {}
  local height      = {}
  local walkable    = {}
  local label       = {}

  pass_a_terraces(p, streams, room_height, rooms_x, rooms_y)
  pass_a2_staircases(p, streams, room_height, rooms_x, rooms_y, forced, locked, report)
  local visited = pass_b_spanning_tree(p, streams, room_height, rooms_x, rooms_y,
                                       opened, forced)

  local reached = 0
  for _ in pairs(visited) do reached = reached + 1 end
  report.rooms         = rooms_x * rooms_y
  report.rooms_reached = reached

  pass_c_realise_heights(p, height, walkable, room_height, rooms_x, rooms_y,
                         opened, width, depth)
  pass_c2_plazas(p, streams, height, walkable, width, depth, report)
  -- The flights are already in the maze, so this is a check that finds nothing
  -- to do rather than the pass that does the work. It stays because "nothing to
  -- do" is a claim worth testing on every maze: if it ever starts cutting, the
  -- terraces have grown a shape pass A2 cannot span, and that is worth knowing
  -- on the maze it first happens to rather than a hundred mazes later.
  pass_d_staircases(p, streams, height, walkable, width, depth, label, report)

  -- Last, because the repair pass above cuts notches, and a notch raises floor
  -- that the walls beside it were measured against. Running this before the
  -- repair leaves a handful of walls exactly one layer above a step somebody
  -- can climb -- two of them in a maze of sixteen thousand cells, which is
  -- precisely the sort of thing that is never found by looking.
  pass_f_restore_walls(p, height, walkable, width, depth, report)

  -- Pass E. Only now does anything touch the stone.
  local store = Stone.new(width, depth, p.layers)
  for i = 0, width * depth - 1 do
    Stone.fill_to(store, i, height[i])
  end
  Stone.recompute_surfaces(store)

  store.height   = height     -- kept: the ball's floor field reads it every tick
  store.walkable = walkable   -- kept: the spawner only ever places bodies on floor
  store.label    = label

  local histogram = {}
  for l = 0, p.layers - 1 do histogram[l] = 0 end
  for i = 0, width * depth - 1 do
    histogram[height[i]] = (histogram[height[i]] or 0) + 1
  end
  report.height_histogram = histogram

  return store, report
end
-- }}}

M.floor_components = floor_components
M.link_height      = link_height

return M
