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

-- 075-the-sprite-baker.lua
--
-- Bakes a lit sphere and its shadow into pixels, with no engine anywhere near it.
--
-- There is no art in this project and there is not going to be any. A sphere lit
-- from a fixed direction is a closed-form calculation -- for every pixel inside
-- the disc the surface normal follows from the offset alone, and the brightness
-- follows from the normal -- so the sprite is a function rather than a file. That
-- is the difference between an asset somebody has to maintain and a number
-- somebody can change.
--
-- Nothing here knows what a texture is. It produces width, height and a string of
-- red-green-blue-alpha bytes, which the viewer hands to the engine and the test
-- reads directly. That split is the reason a sprite can be checked at all: a
-- picture nobody can assert about is a picture that is wrong for as long as
-- nobody happens to look at it.

local M = {}

-- The light, in the sprite's own space: x to the right, y down the screen, z out
-- toward the viewer.
--
-- Upper left, and the same upper left the stone is lit from. Two light directions
-- in one picture is the sort of thing nobody can name and everybody can see.
local LIGHT = { -0.55, -0.62, 0.56 }

-- {{{ local function normalise(v)
local function normalise(v)
  local d = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
  return { v[1] / d, v[2] / d, v[3] / d }
end
-- }}}

local L = normalise(LIGHT)

-- How many samples across a pixel when measuring how much of it the disc covers.
--
-- Four by four, so sixteen. This is the whole reason a baked sprite beats the
-- vector circle it replaces: a ball is six pixels across at scale one, and at six
-- pixels a polygon approximation of a circle is a plus sign with corners. Coverage
-- measured as a fraction gives a smooth edge at any size, and it is paid for once
-- rather than sixty times a second.
local SUBSAMPLES = 4

-- {{{ local function shade(nx, ny, nz)
-- The brightness of a point on the sphere whose surface normal is given.
--
-- Three terms, and the third is the one that is easy to leave out and obvious
-- when it is missing. Diffuse alone makes a disc with a gradient on it; what says
-- *sphere* is the darkening near the silhouette, where the surface has turned
-- away from the viewer and would be catching light from nothing.
local function shade(nx, ny, nz)
  local lambert = nx * L[1] + ny * L[2] + nz * L[3]
  if lambert < 0 then lambert = 0 end

  -- Ambient, so the unlit side is a colour rather than a hole.
  --
  -- Low, and it has to be. The sprite is a mask that gets multiplied by the
  -- creature's colour, so the only thing that can carry the roundness is the
  -- range between the darkest pixel and the brightest. Raise the ambient and
  -- every ball flattens into a disc of flat colour with a ring around it, which
  -- is exactly what the vector circle it replaces looked like.
  local v = 0.22 + 0.78 * lambert

  -- A tight highlight, offset toward the light. Raised to a high power so it is a
  -- spot rather than a smear; the exponent is what separates a polished ball from
  -- a matte one and it is the only number here worth arguing about.
  local spec = lambert ^ 24
  v = v + 0.55 * spec

  -- The rim. `nz` falls to zero at the silhouette, so this is strongest exactly
  -- where the sphere turns away.
  local edge = 1 - nz
  v = v * (1 - 0.45 * edge * edge)

  if v > 1 then v = 1 end
  return v
end
-- }}}

-- {{{ function M.ball(radius)
-- A lit sphere, `radius` pixels from centre to silhouette.
--
-- Returned as a shading mask rather than as a coloured ball: the red, green and
-- blue channels all carry the same brightness, and the draw tints them with
-- whatever colour the creature happens to be. One sprite serves every kind and
-- every team, and a team colour changing is not a sprite sheet to rebuild.
function M.ball(radius)
  local size = radius * 2
  local bytes = {}
  local step = 1 / SUBSAMPLES
  local r2 = radius * radius

  for py = 0, size - 1 do
    for px = 0, size - 1 do
      -- Coverage first, by sampling inside the pixel. A pixel the disc crosses
      -- gets the fraction it covers, which is the antialiasing.
      local covered = 0
      local lit = 0
      for sy = 0, SUBSAMPLES - 1 do
        for sx = 0, SUBSAMPLES - 1 do
          local ox = px + (sx + 0.5) * step - radius
          local oy = py + (sy + 0.5) * step - radius
          local d2 = ox * ox + oy * oy
          if d2 < r2 then
            covered = covered + 1
            -- On a unit sphere seen head-on, the surface normal at an offset is
            -- that offset itself, with the third component making it unit
            -- length. No projection and no trigonometry.
            local nx, ny = ox / radius, oy / radius
            local nz2 = 1 - nx * nx - ny * ny
            local nz = (nz2 > 0) and math.sqrt(nz2) or 0
            lit = lit + shade(nx, ny, nz)
          end
        end
      end

      local n = SUBSAMPLES * SUBSAMPLES
      local alpha = covered / n
      -- Averaged over the samples that landed on the sphere, not over all of
      -- them. Dividing by the full count would darken every edge pixel toward
      -- black, which reads as a dirty outline rather than a soft edge.
      local value = (covered > 0) and (lit / covered) or 0

      local c = math.floor(value * 255 + 0.5)
      local a = math.floor(alpha * 255 + 0.5)
      bytes[#bytes + 1] = string.char(c, c, c, a)
    end
  end

  return size, size, table.concat(bytes)
end
-- }}}

-- {{{ function M.shadow(radius)
-- The mark a body leaves on the surface under it.
--
-- Not a nicety. There is no perspective in this projection to say how far away
-- the ground is, so a mark on the ground is the *only* cue that a thing is on a
-- surface rather than hanging above it. A ball without one reads as floating at
-- an indeterminate height.
--
-- Black in the colour channels and a soft falloff in alpha, so the draw can set
-- its own strength. Squashed to the isometric ratio by the draw rather than here,
-- because the ratio belongs to the projection.
function M.shadow(radius)
  local size = radius * 2
  local bytes = {}
  local step = 1 / SUBSAMPLES

  for py = 0, size - 1 do
    for px = 0, size - 1 do
      local sum = 0
      for sy = 0, SUBSAMPLES - 1 do
        for sx = 0, SUBSAMPLES - 1 do
          local ox = (px + (sx + 0.5) * step - radius) / radius
          local oy = (py + (sy + 0.5) * step - radius) / radius
          local d = math.sqrt(ox * ox + oy * oy)
          if d < 1 then
            -- Full strength across most of the disc, then a soft edge over the
            -- outer third.
            --
            -- A falloff that begins at the centre was tried and it is nearly
            -- invisible: almost all of a disc's area is in its outer half, so a
            -- shadow that fades from the middle outward is faint everywhere and
            -- the ball goes back to looking as though it is hovering. What a
            -- shadow has to be is dark, with an edge that is not a cut.
            local f
            if d < 0.62 then
              f = 1
            else
              local u = (d - 0.62) / 0.38
              f = 1 - u * u * (3 - 2 * u)
            end
            sum = sum + f
          end
        end
      end
      local a = math.floor((sum / (SUBSAMPLES * SUBSAMPLES)) * 255 + 0.5)
      if a > 255 then a = 255 end
      bytes[#bytes + 1] = string.char(0, 0, 0, a)
    end
  end

  return size, size, table.concat(bytes)
end
-- }}}

-- How big the baked sprites are, in pixels of radius.
--
-- Generous, and scaled down at the draw rather than up. A ball is six pixels
-- across at scale one and twenty-six at the zoom somebody actually watches at, so
-- every real size is smaller than this -- and a texture scaled down keeps its
-- shape while one scaled up shows the grid it was baked on.
M.BAKE_RADIUS = 48

M.LIGHT = L

return M
