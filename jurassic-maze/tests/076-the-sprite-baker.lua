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

-- 076-the-sprite-baker.lua
--
-- The baked sprites are round, lit from the right direction, and empty outside.
--
-- A picture is the one kind of output nobody writes a test for, on the grounds
-- that you can just look at it. You can, and only at the moment you happen to
-- look -- which is why the sprite generation was kept clear of the engine in the
-- first place. It produces bytes, and bytes can be asserted about.
--
-- Nothing here checks that the ball is beautiful. It checks the things that would
-- be true of any correct lit sphere and are the ones a change is likely to break:
-- that it is round, that the corners are empty, that the edge is soft rather than
-- stepped, that the bright side is the side the light is on, and that it is
-- symmetric about the light's own axis.

local M = {}

-- {{{ local function pixel(data, w, x, y)
-- One pixel out of the byte string, as four numbers from 0 to 255.
local function pixel(data, w, x, y)
  local at = (y * w + x) * 4 + 1
  return data:byte(at), data:byte(at + 1), data:byte(at + 2), data:byte(at + 3)
end
-- }}}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local Baker = dofile(root .. "/src/075-the-sprite-baker.lua")

  local R = 32
  local w, h, data = Baker.ball(R)

  t.equal(w, R * 2, "the ball sprite is as wide as its diameter")
  t.equal(h, R * 2, "and as tall")
  t.equal(#data, w * h * 4, "there are four bytes for every pixel and no more")

  -- The four corners are outside the disc, so they are nothing at all. An alpha
  -- above zero there is a sprite drawn as a square, which shows as a box around
  -- every ball the moment two of them overlap.
  for _, c in ipairs({ { 0, 0 }, { w - 1, 0 }, { 0, h - 1 }, { w - 1, h - 1 } }) do
    local _, _, _, a = pixel(data, w, c[1], c[2])
    t.equal(a, 0, "a corner of the ball sprite is empty")
  end

  -- The middle is entirely covered.
  local _, _, _, centre_a = pixel(data, w, R, R)
  t.equal(centre_a, 255, "the centre of the ball is opaque")

  -- Round: every pixel's coverage follows from its distance from the centre, so
  -- well inside is solid, well outside is empty, and only the ring between is
  -- allowed to be partial. This is the assertion that a disc has not quietly
  -- become a square or an ellipse.
  local solid_wrong, empty_wrong, partial = 0, 0, 0
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local _, _, _, a = pixel(data, w, x, y)
      local dx, dy = x + 0.5 - R, y + 0.5 - R
      local d = math.sqrt(dx * dx + dy * dy)
      if d < R - 1.5 then
        if a ~= 255 then solid_wrong = solid_wrong + 1 end
      elseif d > R + 1.5 then
        if a ~= 0 then empty_wrong = empty_wrong + 1 end
      else
        if a > 0 and a < 255 then partial = partial + 1 end
      end
    end
  end
  t.equal(solid_wrong, 0, "everything well inside the silhouette is opaque")
  t.equal(empty_wrong, 0, "everything well outside it is empty")
  -- The soft edge. A vector circle gives a hard one, and the whole reason to bake
  -- is that six pixels of hard edge is a plus sign.
  t.truthy(partial > R, "the silhouette is a soft edge rather than a step")

  -- Lit from the upper left, which is where the stone is lit from. Two light
  -- directions in one picture is the kind of thing nobody can name and everybody
  -- can see.
  local light = Baker.LIGHT
  local toward_x = math.floor(R + light[1] * R * 0.5)
  local toward_y = math.floor(R + light[2] * R * 0.5)
  local away_x   = math.floor(R - light[1] * R * 0.5)
  local away_y   = math.floor(R - light[2] * R * 0.5)
  local lit  = pixel(data, w, toward_x, toward_y)
  local dark = pixel(data, w, away_x, away_y)
  t.truthy(lit > dark, "the side the light comes from is the brighter side")
  t.truthy(dark > 0, "the unlit side is a colour rather than a hole")

  -- Symmetric about the light's axis. A sphere has no other structure, so any
  -- asymmetry across that line is arithmetic that has gone wrong rather than
  -- shading that was intended.
  local worst = 0
  local axis = math.sqrt(light[1] ^ 2 + light[2] ^ 2)
  local ax, ay = light[1] / axis, light[2] / axis
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local dx, dy = x + 0.5 - R, y + 0.5 - R
      if dx * dx + dy * dy < (R - 2) ^ 2 then
        -- Reflect the point across the light's axis and compare the two.
        local along = dx * ax + dy * ay
        local rx = 2 * along * ax - dx
        local ry = 2 * along * ay - dy
        -- Read the mirrored point by interpolating between the four pixels
        -- around it, not by rounding to the nearest one.
        --
        -- Rounding was tried and it reports an asymmetry of eighteen levels on a
        -- sprite that is symmetric: the mirror of a pixel centre almost never
        -- lands on another pixel centre, so rounding compares a pixel with its
        -- neighbour, and across the specular highlight two neighbours differ a
        -- great deal. That is the test's own sampling error being reported as a
        -- fault in the thing under test, which is the most expensive kind of
        -- false alarm there is.
        local fx, fy = rx + R - 0.5, ry + R - 0.5
        local x0, y0 = math.floor(fx), math.floor(fy)
        local tx, ty = fx - x0, fy - y0
        if x0 >= 0 and y0 >= 0 and x0 + 1 < w and y0 + 1 < h then
          local p00 = pixel(data, w, x0,     y0)
          local p10 = pixel(data, w, x0 + 1, y0)
          local p01 = pixel(data, w, x0,     y0 + 1)
          local p11 = pixel(data, w, x0 + 1, y0 + 1)
          local top    = p00 + (p10 - p00) * tx
          local bottom = p01 + (p11 - p01) * tx
          local b = top + (bottom - top) * ty
          local a = pixel(data, w, x, y)
          local gap = math.abs(a - b)
          if gap > worst then worst = gap end
        end
      end
    end
  end
  t.truthy(worst < 6,
           string.format("the shading is symmetric about the light's axis " ..
                         "(worst gap %.1f of 255)", worst))

  -- The greys are what gets tinted, so all three channels have to agree. A sprite
  -- with a colour of its own would fight every creature colour in the palette.
  local channels_differ = 0
  for y = 0, h - 1, 3 do
    for x = 0, w - 1, 3 do
      local r, g, b = pixel(data, w, x, y)
      if r ~= g or g ~= b then channels_differ = channels_differ + 1 end
    end
  end
  t.equal(channels_differ, 0, "the ball sprite is a shading mask, not a colour")

  -- The shadow: black everywhere, densest in the middle, gone by the rim.
  do
    local sw, sh, sdata = Baker.shadow(R)
    t.equal(sw, R * 2, "the shadow sprite is as wide as its diameter")
    t.equal(#sdata, sw * sh * 4, "and has four bytes a pixel")

    local r, g, b, a = pixel(sdata, sw, R, R)
    t.equal(r, 0, "the shadow has no colour of its own, red")
    t.equal(g, 0, "the shadow has no colour of its own, green")
    t.equal(b, 0, "the shadow has no colour of its own, blue")
    t.truthy(a > 200, "the shadow is dense under the middle of the body")

    local _, _, _, corner = pixel(sdata, sw, 0, 0)
    t.equal(corner, 0, "the shadow's corners are empty")

    -- Full strength across the middle, then falling off. Sampled at four fifths
    -- of the radius, which is inside the falloff band -- half way out is
    -- deliberately still at full strength, because a shadow that starts fading
    -- at its centre is faint everywhere and the ball goes back to hovering.
    local _, _, _, mid  = pixel(sdata, sw, R + math.floor(R * 0.4), R)
    local _, _, _, outer = pixel(sdata, sw, R + math.floor(R * 0.8), R)
    t.equal(mid, a, "the shadow is at full strength across its middle")
    t.truthy(outer < a and outer > 0,
             "and fades over its outer edge rather than stopping")
  end
end
-- }}}

return M
