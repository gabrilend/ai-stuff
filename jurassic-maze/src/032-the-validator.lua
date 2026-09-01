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

-- 032-the-validator.lua
--
-- Refuses a broken maze and counts what is merely interesting.
--
-- Every generated maze comes through here before anything else sees it. The
-- findings split into two kinds and the split is the point: some of them stop
-- the maze being returned at all, and the rest become numbers in a report.
--
-- A warning is an error here. Anything genuinely acceptable is *counted*, which
-- is a number somebody can compare against last week's, rather than a message in
-- a log that is ignored the first time and invisible the second.

local M = {}

-- {{{ local function require_local(root, name)
local function require_local(root, name)
  return dofile(root .. "/src/" .. name .. ".lua")
end
-- }}}

-- {{{ local function longest_shortest_path(Stone, Moving, store, drop_limit)
-- How far apart the two most distant reachable places are.
--
-- Not a correctness question at all. It is the number that says whether the maze
-- is interesting: a maze whose longest path is short is a maze that is mostly
-- plaza, and no amount of looking at a screenshot will tell you that as quickly
-- as one integer will.
--
-- Two breadth-first sweeps: from anywhere, find the furthest surface; from
-- there, find the furthest again. That is exact on a tree and an underestimate
-- on a graph with cycles, and this graph has cycles because braiding put them
-- there. Close enough for a number that exists to be compared against itself.
local function longest_shortest_path(Stone, Moving, store, drop_limit, start_key)
  local dist = {}
  local queue = { start_key }
  local head, tail = 1, 1
  dist[start_key] = 0
  local far_key, far_dist = start_key, 0

  while head <= tail do
    local here = queue[head]
    head = head + 1
    local hc, hl = Moving.unpack(store, here)
    local d = dist[here]

    if d > far_dist then far_dist, far_key = d, here end

    for di = 1, 4 do
      local answer, nc, nl = Moving.step(Stone, store, hc, hl, di, drop_limit, 1)
      if answer ~= Moving.BLOCKED then
        local nkey = Moving.pack(store, nc, nl)
        if dist[nkey] == nil then
          dist[nkey] = d + 1
          tail = tail + 1
          queue[tail] = nkey
        end
      end
    end
  end

  return far_key, far_dist
end
-- }}}

-- {{{ function M.validate(root, store, p, report)
-- The whole check. Raises on anything that makes the maze not a maze; fills the
-- report with everything else.
function M.validate(root, store, p, report)
  local Stone      = require_local(root, "030-the-stone")
  local Moving     = require_local(root, "033-moving")
  local Iso        = require_local(root, "040-the-projection")
  local Sightlines = require_local(root, "067-sightlines")

  report = report or {}
  local bit = require("bit")

  -- Hard: every column must be a plain pile with no holes in it.
  --
  -- The bitmask can express far more than that -- tunnels, bridges, ceilings --
  -- and today nothing produces one. This check is how anybody finds out the day
  -- something does, which will be the day a golem walks through a wall in phase
  -- seven. At that point this check takes a flag rather than being deleted.
  if not p.allow_holes then
    for i = 0, store.cells - 1 do
      if not Stone.height_shaped(store.column[i]) then
        local x, y = Stone.coords(store, i)
        error(string.format(
          "maze seed %d: column at (%d, %d) has a hole in it (bits %s). " ..
          "Nothing in the generator makes those; something else did.",
          p.seed, x, y, string.format("%x", store.column[i])))
      end
    end
  end

  -- Hard: the rim must be wall, because it is the only thing stopping a body
  -- that has gone wrong from walking out of the array.
  local rim_floor = 0
  for x = 0, store.width - 1 do
    if store.walkable[Stone.index(store, x, 0)] then rim_floor = rim_floor + 1 end
    if store.walkable[Stone.index(store, x, store.depth - 1)] then rim_floor = rim_floor + 1 end
  end
  for y = 0, store.depth - 1 do
    if store.walkable[Stone.index(store, 0, y)] then rim_floor = rim_floor + 1 end
    if store.walkable[Stone.index(store, store.width - 1, y)] then rim_floor = rim_floor + 1 end
  end
  if rim_floor > 0 then
    error(string.format("maze seed %d: %d rim cells are floor -- the world has a hole in its side",
                        p.seed, rim_floor))
  end

  -- Hard: the floor must be one connected piece.
  --
  -- A maze in two pieces is a maze where bodies pile up in whichever piece they
  -- spawned in. From a camera two hundred cells away that looks like a busy
  -- corner and a quiet one, which is exactly what a maze is supposed to look
  -- like -- so this can never be left to somebody noticing.
  local drop_limit = p.max_drop_limit or 2
  local label, piece_count, piece_sizes = Moving.label_surfaces(Stone, store)

  local floor_labels, floor_pieces = {}, 0
  local biggest_label, biggest = nil, -1
  for i = 0, store.cells - 1 do
    if store.walkable[i] then
      local h = store.height[i]
      local key = Moving.pack(store, i, h)
      local l = label[key]
      if l and not floor_labels[l] then
        floor_labels[l] = true
        floor_pieces = floor_pieces + 1
        if piece_sizes[l] > biggest then
          biggest, biggest_label = piece_sizes[l], l
        end
      end
    end
  end

  if floor_pieces > 1 then
    error(string.format(
      "maze seed %d: the floor is in %d mutually unreachable pieces " ..
      "(largest %d surfaces)", p.seed, floor_pieces, biggest))
  end

  store.label = label
  store.main_component = biggest_label

  -- Counted, not fatal, from here down.
  local surfaces, pits, floor_cells = 0, 0, 0
  for i = 0, store.cells - 1 do
    local s = store.surfaces[i]
    for l = 0, store.layers - 1 do
      if bit.band(s, bit.lshift(1, l)) ~= 0 then
        surfaces = surfaces + 1
        if label[Moving.pack(store, i, l)] == biggest_label then
          if Moving.is_pit(Stone, store, i, l, drop_limit) then
            pits = pits + 1
          end
        end
      end
    end
    if store.walkable[i] then floor_cells = floor_cells + 1 end
  end

  -- The longest journey anybody could be asked to make.
  local start = nil
  for i = 0, store.cells - 1 do
    if store.walkable[i] then
      start = Moving.pack(store, i, store.height[i])
      break
    end
  end
  local far_key = longest_shortest_path(Stone, Moving, store, drop_limit, start)
  local _, diameter = longest_shortest_path(Stone, Moving, store, drop_limit, far_key)

  report.surfaces        = surfaces
  report.floor_cells     = floor_cells
  report.surface_pieces  = piece_count
  report.wall_top_pieces = piece_count - floor_pieces
  report.pits            = pits
  report.ledges          = Moving.count_ledges(Stone, store, label, biggest_label, drop_limit)
  report.diameter        = diameter

  -- How much of the world is stone. A number near one is a solid block with a
  -- scratch in it; a number near zero is a plain with some pebbles on it.
  local stone_layers = 0
  for i = 0, store.cells - 1 do
    stone_layers = stone_layers + (store.height[i] + 1)
  end
  report.fill_fraction = stone_layers / (store.cells * store.layers)

  -- How much of the maze the camera can actually see.
  --
  -- Counted rather than fatal, and it is the one count here that is about the
  -- projection rather than about the stone -- a maze can be perfectly connected,
  -- perfectly carved, and completely invisible, and every other number on this
  -- report will say it is fine. It is here because the alternative was judging it
  -- from screenshots, and a maze that is three quarters wall tops looks like a
  -- maze in a screenshot.
  local climb = Sightlines.climb(Iso)
  local seen = Sightlines.survey(store, climb)
  report.sight_climb        = climb
  report.wall_fits          = Sightlines.wall_fits_behind_a_step(Iso, p.wall_rise)
  report.floor_seen_centre  = seen.floor_centre / math.max(1, seen.floor_cells)
  report.floor_seen_any     = seen.floor_any    / math.max(1, seen.floor_cells)
  report.tops_seen_centre   = seen.top_centre   / math.max(1, seen.column_tops)
  report.hidden_by          = seen.hidden_by

  return report
end
-- }}}

-- {{{ function M.describe(report)
-- The report as lines of text, for the terminal and for a phase demo. Built from
-- the same table the headless runner consumes, so the two can never disagree
-- about what a run did.
function M.describe(report)
  local lines = {}
  local function add(fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end

  add("seed %d, %d by %d cells, %d layers",
      report.seed, report.width, report.depth, report.layers)

  -- The generator's own bookkeeping, and only it has any. A world built from a
  -- hand-authored map has no rooms to reach and no orphans to fill, and printing
  -- a zero for each would be a report about a maze that was never made. The test
  -- is on rooms rather than on a flag because the absence of the number is the
  -- fact being reported.
  if report.map then
    add("  from the map       '%s'", report.map)
  end
  if report.rooms then
    add("  rooms reached      %d of %d", report.rooms_reached, report.rooms)
    add("  staircases cut     %d  (%d for connectivity, %d extra of %d possible sites)",
        (report.staircases_cut or 0) + (report.extra_staircases or 0),
        report.staircases_cut or 0, report.extra_staircases or 0,
        report.staircase_sites or 0)
    add("  orphan cells filled %d", report.orphans_filled or 0)
  end
  add("  floor cells        %d", report.floor_cells or 0)
  add("  surfaces           %d", report.surfaces or 0)
  add("  wall-top pieces    %d   (a wall you can climb onto is not a wall)",
      report.wall_top_pieces or 0)
  add("  dead-end surfaces  %d   (nowhere at all to go from there)", report.pits or 0)
  add("  ledges             %d   (steps down a body cannot climb straight back)",
      report.ledges or 0)
  add("  diameter           %d steps", report.diameter or 0)
  add("  fill fraction      %.3f", report.fill_fraction or 0)

  -- The sightline block. Printed last because it is the newest question asked of
  -- a maze and the only one whose answer is currently bad.
  if report.floor_seen_any then
    add("  floor in view      %.1f%% any of it, %.1f%% at the centre",
        100 * report.floor_seen_any, 100 * report.floor_seen_centre)
    add("  column tops in view %.1f%%   (sight climbs %.2f layers per diagonal cell)",
        100 * report.tops_seen_centre, report.sight_climb or 0)
    if not report.wall_fits then
      add("  a wall is taller than one step of sight, so it hides the floor behind it")
    end
  end

  return table.concat(lines, "\n")
end
-- }}}

return M
