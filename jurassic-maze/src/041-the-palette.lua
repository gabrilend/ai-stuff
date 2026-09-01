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

-- 041-the-palette.lua
--
-- Three tones, a per-cell mottle, and every colour in the project.
--
-- This is the only file that names a colour. Anything drawn anywhere asks here
-- for its shade, so that the whole thing can be re-lit by editing one file.

local M = {}

-- Light comes from the upper left, as it does in the reference picture.
--
-- Every face in this world has one of exactly three orientations, and which
-- three was decided when the projection was chosen. So the shading is a lookup
-- with three entries. A lighting model here -- normals, dot products, a light
-- vector -- would be arithmetic performed to rediscover a constant.
M.TOP   = 1
M.LEFT  = 2
M.RIGHT = 3

M.TONE = { 1.00, 0.74, 0.52 }

-- Limestone, weathered. Grey-tan, with green in the cracks and paler sandstone
-- higher up, which is what the reference picture is. This is the only aesthetic
-- decision in the project that has not been made deliberately -- see open
-- question 10.
M.STONE_LOW  = { 0.62, 0.60, 0.52 }
M.STONE_HIGH = { 0.82, 0.80, 0.72 }
M.MOSS       = { 0.40, 0.52, 0.30 }
M.OUTLINE    = { 0.20, 0.19, 0.16 }
M.SKY        = { 0.68, 0.78, 0.85 }

-- {{{ local function mottle(cell)
-- A small stable per-cell brightness offset.
--
-- Drawn from a hash of the cell index rather than from a named stream. Three
-- reasons, and the third is the one that decides it: it costs no memory, it is
-- identical on every frame and every run so the stone does not shimmer, and the
-- renderer must not be able to move the simulation. A stream read here would
-- make the world depend on how many cells happened to be on screen.
local function mottle(cell)
  local h = cell * 2654435761 % 4294967296
  h = h % 1024
  return (h / 1024 - 0.5) * 0.14
end
-- }}}

-- {{{ function M.stone(cell, layer, layers, face)
-- The colour of one face of one block. Returns three numbers in zero to one.
--
-- Higher layers are tinted paler, which separates a wall from the wall behind it
-- when both would otherwise be the same tone, and reads as the upper terraces
-- being more weathered. Without it a maze twenty layers deep is a field of one
-- grey with invisible seams.
function M.stone(cell, layer, layers, face)
  local t = layer / (layers - 1)
  local m = mottle(cell)
  local tone = M.TONE[face]

  local r = (M.STONE_LOW[1] + (M.STONE_HIGH[1] - M.STONE_LOW[1]) * t + m) * tone
  local g = (M.STONE_LOW[2] + (M.STONE_HIGH[2] - M.STONE_LOW[2]) * t + m) * tone
  local b = (M.STONE_LOW[3] + (M.STONE_HIGH[3] - M.STONE_LOW[3]) * t + m) * tone
  return r, g, b
end
-- }}}

-- {{{ function M.mossy_top(cell, layer, layers)
-- The top face of a floor block, which grows things.
--
-- Only floor is mossed, never a wall top. In the reference picture the greenery
-- is in the walked places and the crevices, and putting it on the wall tops as
-- well flattens the whole picture into one texture -- the moss stops marking
-- anything.
function M.mossy_top(cell, layer, layers, mossiness)
  local r, g, b = M.stone(cell, layer, layers, M.TOP)
  local m = mossiness * (0.5 + mottle(cell) * 3)
  if m < 0 then m = 0 elseif m > 1 then m = 1 end
  return r + (M.MOSS[1] - r) * m,
         g + (M.MOSS[2] - g) * m,
         b + (M.MOSS[3] - b) * m
end
-- }}}

-- The creature colours. Team is a tint applied on top, so a third team is a
-- colour rather than a sprite.
M.CREATURE = {
  ball   = { 0.86, 0.35, 0.24 },
  guy    = { 0.92, 0.86, 0.72 },
  -- Pale, so that the team tint below is what you actually see. A fencer whose
  -- own colour is strong shows its side as a shift you have to look for; one
  -- that is nearly white shows it as the colour it is.
  fencer = { 0.90, 0.88, 0.84 },
  dino   = { 0.42, 0.52, 0.28 },
  human  = { 0.86, 0.70, 0.52 },
  golem  = { 0.52, 0.52, 0.56 },
  vine   = { 0.24, 0.62, 0.26 },
  automaton = { 0.70, 0.46, 0.22 },
}

-- A body that is alight. Drawn over its own colour rather than instead of it, so
-- that what is burning is still recognisable as what it was.
M.FIRE = { 1.00, 0.62, 0.18 }

local UNUSED = {
}

M.TEAM = {
  [0] = { 1.00, 1.00, 1.00 },
  [1] = { 1.00, 0.42, 0.34 },
  [2] = { 0.42, 0.62, 1.00 },
  [3] = { 0.95, 0.85, 0.40 },
}

-- {{{ function M.creature(kind_name, team)
function M.creature(kind_name, team)
  local c = M.CREATURE[kind_name] or { 1, 0, 1 }   -- magenta: an unnamed kind
  local t = M.TEAM[team or 0] or M.TEAM[0]
  return c[1] * t[1], c[2] * t[2], c[3] * t[3]
end
-- }}}

return M
