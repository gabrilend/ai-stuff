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

-- 072-the-model.lua
--
-- The model says exactly what the height field says, face by face.
--
-- The model is built by two greedy merges, and a greedy merge is the sort of
-- thing that is correct on the case somebody pictured and wrong one cell to the
-- left of it. So nothing here checks the merge. Everything here checks the
-- *result* against the field it came from, cell by cell and edge by edge, with
-- loops that could not be more obvious if they tried:
--
--   * every cell is under exactly one top, at exactly its own elevation
--   * every edge between two unequal cells has exactly one riser on it, spanning
--     exactly the two elevations, facing the lower of the two
--   * every edge between two equal cells has none
--
-- Together those say the model and the field describe the same solid, which is
-- the only thing the model is for. The merge may then group faces however it
-- likes, and the greedy version and a hand-written one both pass.

local M = {}

-- {{{ local function fields()
-- Small worlds with known answers, plus the real map.
--
-- The flat one exists because it is the case a merge gets right by accident and
-- the case a *coverage* bug shows up in instantly: one face, four risers, and
-- any other answer is wrong without needing to think about it.
local function fields()
  local out = {}

  local flat = { name = "flat", width = 4, depth = 4, height = {} }
  for i = 0, 15 do flat.height[i] = 5 end
  out[#out + 1] = flat

  -- One block standing on a plain. Four risers around it, and the plain broken
  -- into whatever pieces the merge chooses.
  local block = { name = "one block", width = 5, depth = 5, height = {} }
  for i = 0, 24 do block.height[i] = 2 end
  block.height[2 + 2 * 5] = 6
  out[#out + 1] = block

  -- A staircase: every cell one layer below the last. Nothing merges along the
  -- fall, everything merges across it, and it is the shape the whole map is made
  -- of.
  local stair = { name = "a stair", width = 6, depth = 3, height = {} }
  for y = 0, 2 do
    for x = 0, 5 do stair.height[x + y * 6] = 10 - x end
  end
  out[#out + 1] = stair

  return out
end
-- }}}

-- {{{ local function run(t, Model, field, floor_z)
local function run(t, Model, field, floor_z)
  local m = Model.build(field, floor_z)
  local w, d = field.width, field.depth
  local what = field.name

  -- Every cell under exactly one top, at its own elevation.
  local tops_over = {}
  for i = 0, m.count - 1 do
    if m.kind[i] == Model.TOP then
      for y = m.y0[i], m.y1[i] - 1 do
        for x = m.x0[i], m.x1[i] - 1 do
          local c = x + y * w
          tops_over[c] = (tops_over[c] or 0) + 1
          if m.z0[i] ~= field.height[c] then
            t.fail(what .. ": a top over (" .. x .. ", " .. y .. ") sits at " ..
                   m.z0[i] .. " and the ground there is " .. field.height[c])
          end
        end
      end
      -- A top is horizontal by definition, and a normal that is not straight up
      -- would send a ball rolling along a floor.
      t.equal(m.z0[i], m.z1[i], what .. ": a top is level")
      t.equal(m.nz[i], 1, what .. ": a top faces upward")
    end
  end

  local wrong = 0
  for c = 0, w * d - 1 do
    if tops_over[c] ~= 1 then wrong = wrong + 1 end
  end
  t.equal(wrong, 0, what .. ": every cell is under exactly one top")

  -- Every edge between two cells carries the riser it should and no other.
  --
  -- Counted as a map from edge to how many risers cover it, built by walking the
  -- faces, and then compared against what the field says the answer is. Both
  -- directions matter: a missing riser is a hole a ball falls through, and a
  -- doubled one is a surface that pushes twice.
  local covered = {}
  for i = 0, m.count - 1 do
    if m.kind[i] == Model.RISER then
      t.truthy(m.z1[i] > m.z0[i], what .. ": a riser has height")
      if m.nx[i] ~= 0 then
        -- A plane of constant x, stretching in y. The cells it separates are the
        -- ones either side of that plane.
        local px = m.x0[i]
        for y = m.y0[i], m.y1[i] - 1 do
          local high = (m.nx[i] > 0) and (px - 1) or px
          local key = "x " .. px .. " " .. y
          covered[key] = (covered[key] or 0) + 1
          local hi = field.height[high + y * w]
          local lo = (high + m.nx[i] < 0 or high + m.nx[i] >= w)
                     and floor_z or field.height[high + m.nx[i] + y * w]
          t.equal(m.z1[i], hi, what .. ": a riser's top is the taller ground")
          t.equal(m.z0[i], lo, what .. ": a riser's bottom is the lower ground")
        end
      else
        local py = m.y0[i]
        for x = m.x0[i], m.x1[i] - 1 do
          local high = (m.ny[i] > 0) and (py - 1) or py
          local key = "y " .. x .. " " .. py
          covered[key] = (covered[key] or 0) + 1
          local hi = field.height[x + high * w]
          local lo = (high + m.ny[i] < 0 or high + m.ny[i] >= d)
                     and floor_z or field.height[x + (high + m.ny[i]) * w]
          t.equal(m.z1[i], hi, what .. ": a riser's top is the taller ground")
          t.equal(m.z0[i], lo, what .. ": a riser's bottom is the lower ground")
        end
      end
    end
  end

  -- Now the other direction: for every edge in the world, work out from the
  -- field alone whether a riser belongs there, and see whether one is.
  local function ground(x, y)
    if x < 0 or y < 0 or x >= w or y >= d then return floor_z end
    return field.height[x + y * w]
  end

  local missing, extra = 0, 0
  for y = 0, d - 1 do
    for x = 0, w do
      local want = (ground(x - 1, y) ~= ground(x, y)) and 1 or 0
      local got = covered["x " .. x .. " " .. y] or 0
      if got < want then missing = missing + 1 end
      if got > want then extra = extra + 1 end
    end
  end
  for y = 0, d do
    for x = 0, w - 1 do
      local want = (ground(x, y - 1) ~= ground(x, y)) and 1 or 0
      local got = covered["y " .. x .. " " .. y] or 0
      if got < want then missing = missing + 1 end
      if got > want then extra = extra + 1 end
    end
  end
  t.equal(missing, 0, what .. ": no edge that needs a riser is without one")
  t.equal(extra, 0, what .. ": no edge carries a riser twice")

  -- The index has to name a face for every cell, or the physics will scan the
  -- whole model looking for the ground under a ball and find nothing.
  local unindexed = 0
  for c = 0, w * d - 1 do
    if not m.at[c] or #m.at[c] == 0 then unindexed = unindexed + 1 end
  end
  t.equal(unindexed, 0, what .. ": every cell names at least one face")

  return m
end
-- }}}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local Map   = dofile(root .. "/src/069-the-map.lua")
  local Model = dofile(root .. "/src/071-the-model.lua")

  for _, field in ipairs(fields()) do run(t, Model, field, 0) end

  -- The flat world's answer is known without any reasoning: one merged top, and
  -- one riser down each of the four sides.
  local flat = fields()[1]
  local m = Model.build(flat, 0)
  local tops, risers = 0, 0
  for i = 0, m.count - 1 do
    if m.kind[i] == Model.TOP then tops = tops + 1 else risers = risers + 1 end
  end
  t.equal(tops, 1, "a flat world is one top face")
  t.equal(risers, 4, "a flat world is four risers, one down each side")

  -- And the real map, which is the case that matters and the one no hand-worked
  -- answer exists for.
  local field = Map.load(dofile(root .. "/assets/070-the-mountainside.lua"))
  local built = run(t, Model, field, 0)
  t.truthy(built.count > 100, "the mountainside is more than a handful of faces")
  t.truthy(built.count < field.width * field.depth,
           "the merge leaves fewer faces than there are cells")
end
-- }}}

return M
