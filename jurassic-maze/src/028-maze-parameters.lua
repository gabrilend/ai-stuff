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

-- 028-maze-parameters.lua
--
-- Every knob the maze generator has, in one table.
--
-- Documents name these fields and never restate their values, so that a number
-- turned here cannot leave a document quietly wrong. Why any of them is the
-- value it is belongs in docs/balance-updates.md, appended to, never edited.

local M = {}

-- {{{ function M.defaults()
-- The maze as it is built when nobody has said otherwise.
--
-- width and depth are odd on purpose. The room lattice sits at cells where both
-- coordinates are odd; an odd extent means the lattice fits exactly with a wall
-- rim on all four sides, and the rim is the only thing stopping a body that has
-- gone wrong from leaving the world.
function M.defaults()
  return {
    width  = 129,
    depth  = 129,
    layers = 32,        -- at most 32; a column is a 32-bit integer

    -- Pass one: the terraces. Slabs piled nested, each smaller than the last
    -- and roughly on top of it, which is a stepped mound. Scattered rectangles
    -- were tried first and make noise rather than terraces -- see the note over
    -- pass_a_terraces in 031-carving.lua.
    terrace_count  = 7,      -- how many slabs in the pile
    terrace_max    = 122,    -- the bottom slab's width, in cells
    terrace_min    = 16,     -- the summit's
    -- Four layers, not two. A terrace that is only two layers above the one
    -- below it is reachable by the single cell between two rooms, so the maze
    -- never needs a staircase and never grows one. Four means every terrace edge
    -- is a cliff a flight of steps has to be cut into, which is what the
    -- reference picture is full of.
    terrace_rise   = 4,      -- how much one slab lifts what it covers
    terrace_wander = 0.22,   -- how far a slab's centre strays, as a fraction of
                             -- its own size. Zero is a wedding cake.
    outcrops       = 14,     -- small bumps and hollows on top, for irregularity

    -- Clearings among the corridors. The reference picture has them, and a body
    -- wider than one cell has nowhere at all to stand without them -- nine
    -- contiguous cells at one height do not occur in a maze of one-cell
    -- corridors.
    plaza_count    = 26,
    plaza_min      = 5,
    plaza_max      = 13,

    -- Pass two and four. climb_limit is not a knob: wall_rise was chosen
    -- against it, so raising it does not make bodies more agile, it deletes
    -- every wall in the maze at once.
    wall_rise   = 2,
    climb_limit = 1,

    -- Braiding reopens closed links to make loops. A maze with no loops has one
    -- route between any two rooms, so a chase has a known ending and the pursued
    -- is cornered every time. The games need loops to exist at all.
    braid = 0.15,

    -- Pass three. Running out of rounds is an error with the piece sizes
    -- printed, not a fallback tunnel: a maze that needed a fallback to be
    -- connected is a maze whose parameters are wrong.
    stair_rounds   = 12,

    -- How far a staircase may look for ground on the other side. A run longer
    -- than this is a tunnel across the maze rather than a flight of steps.
    stair_reach    = 10,

    -- A floor pocket smaller than this, that no staircase could reach, is filled
    -- in rather than connected. Anything bigger is a terrace the generator
    -- failed to join, and that is an error.
    --
    -- A hundred and twenty cells sounds generous and is about one and a half
    -- percent of the floor in a maze this size. What lands here is a hollow the
    -- outcrops punched below its surroundings, with no straight run into it that
    -- does not sever more than it joins -- six hundred flights get tried and
    -- rejected before this pass ever sees it. The count of what was filled is in
    -- every report, so a change that starts quietly filling in a quarter of the
    -- maze shows up as a number rather than as a maze that feels smaller.
    orphan_max     = 120,

    -- What fraction of the possible staircase sites get a flight beyond the ones
    -- connectivity demanded. Braiding, for stairs: a maze with exactly one route
    -- up to each terrace is one where every journey is forced.
    extra_stairs   = 0.060,

    -- How many candidate flights are held per pair of pieces. One is not
    -- enough: a flight can land correctly and still sever a branch on the way
    -- through, and with only one on offer that pair never gets another chance.
    stair_candidates = 8,

    -- The longest flight pass A2 will lay, in room-steps. Each room-step spans
    -- two layers, so eight steps is a sixteen-layer climb -- half the world.
    stair_steps    = 8,

    -- How many bodies the store is allocated for. Fixed at world creation and
    -- never grown: a store that quietly reallocates is a store that quietly
    -- stops fitting in cache, and the frame rate falls off a cliff for reasons
    -- that look like nothing. Running out is an error with a message.
    capacity = 3000,

    seed = 1,
  }
end
-- }}}

-- {{{ function M.with(overrides)
-- The defaults with some fields replaced. Used by scenarios and by the command
-- line, so that neither has to know the full list.
function M.with(overrides)
  local p = M.defaults()
  for k, v in pairs(overrides or {}) do
    -- An unknown key is a typo, and a typo that is silently accepted produces a
    -- maze built with the default while somebody believes they changed it.
    if p[k] == nil then
      error("maze parameter '" .. tostring(k) .. "' does not exist")
    end
    p[k] = v
  end
  return p
end
-- }}}

-- {{{ function M.check(p)
-- Refuses parameters that cannot produce a maze, before anything is allocated.
function M.check(p)
  if p.layers < 3 or p.layers > 32 then
    error("layers must be between 3 and 32; a column is a 32-bit integer")
  end
  if p.width < 9 or p.depth < 9 then
    error("a maze smaller than 9 by 9 has fewer than four rooms in it")
  end
  if p.width % 2 == 0 or p.depth % 2 == 0 then
    error("width and depth must be odd, or the room lattice does not fit the rim")
  end
  if p.terrace_rise < 1 then
    error("terrace_rise below 1 produces a flat plain, not a pile of slabs")
  end
  -- The tallest a pile can get is terrace_count lifts of terrace_rise each. That
  -- is allowed to exceed the layer count -- heights clamp, which produces flat
  -- summits, and a flat summit is a real feature of a pile of slabs.
  return p
end
-- }}}

return M
