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

-- 070-the-mountainside.lua
--
-- The mountainside, written by hand from the reference picture.
--
-- Nothing generates this and nothing about it is random. It is the known-good
-- map -- the one thing in the project that can be trusted while the code around
-- it is under suspicion, because when a ball does something strange here the
-- ball is what is wrong.
--
-- It is read off inspiration/inspiration-maze.png rather than traced from it.
-- What is taken from the picture is its idiom, and the four things in it that
-- matter:
--
--   * There are no walls in that picture. Not one. Every vertical surface is the
--     side of a higher flat plate, and what reads as a wall between two corridors
--     is the edge of a block whose own top is walkable.
--   * The maze lies on the face of a mountain with a high corner and a low one.
--     Elevation falls from the far corner toward the near one, which is the
--     entire reason the picture can be read: the ground tilts toward the viewer,
--     so nothing stands in front of anything.
--   * The shelves are flat, and there are a great many of them at slightly
--     different heights rather than a few large ones.
--   * The steps between them are the stairs, and stairs are everywhere.
--
-- The coordinate system, because it decides what "high corner" means: the
-- projection draws small x and y at the top of the screen, so (0, 0) is the far
-- corner and (47, 47) is the near one. Elevation therefore has to *fall* as x and
-- y rise, and every plate below obeys that.
--
-- **Why the shelves are two cells deep and not six.** The first version of this
-- map had eight shelves six cells wide with a kerb along each downhill edge, and
-- under a real physics it did nothing at all: a sphere resting on a level plate,
-- with gravity pointing straight down, has no reason to move, and three hundred
-- of them sat exactly where they were dropped. The old roller hid that by pushing
-- balls along the *interpolated* slope of the height field, which is nonzero near
-- every edge -- so the balls moved because of the smoothing rather than because
-- of the ground.
--
-- A mountain that a ball rolls down has to descend everywhere. So it does: one
-- layer for every two cells, all the way from the summit to the rim, which makes
-- every band a flat shelf two cells deep and every boundary between two bands a
-- single step. That is a staircase forty-two cells long, and it is what the
-- reference picture is covered in.

return {
  name  = "the mountainside",
  width = 48,
  depth = 48,

  -- What a cell sits at if no plate ever reaches it. Nothing relies on it, the
  -- outermost band covering the whole footprint, but a gap should be left at the
  -- ground rather than in the air.
  base = 0,

  plates = {
    -- The mountain.
    --
    -- Twenty-two nested squares anchored at the far corner, each two cells larger
    -- and one layer lower than the last. Nesting is why this is twenty-two lines
    -- rather than twenty-two L-shaped pieces: the higher plate wins wherever two
    -- overlap, so the small high squares simply sit on the large low ones and
    -- what shows of each is the two-cell band around the one before it.
    --
    -- Twenty-one layers of descent over forty-two cells. Shallower than the line
    -- of sight climbs, so every one of these bands is visible from the camera,
    -- and steep enough that a ball on one is always on a step rather than on a
    -- plain.
    { x = 0, y = 0, w =  6, d =  6, z = 24 },
    { x = 0, y = 0, w =  8, d =  8, z = 23 },
    { x = 0, y = 0, w = 10, d = 10, z = 22 },
    { x = 0, y = 0, w = 12, d = 12, z = 21 },
    { x = 0, y = 0, w = 14, d = 14, z = 20 },
    { x = 0, y = 0, w = 16, d = 16, z = 19 },
    { x = 0, y = 0, w = 18, d = 18, z = 18 },
    { x = 0, y = 0, w = 20, d = 20, z = 17 },
    { x = 0, y = 0, w = 22, d = 22, z = 16 },
    { x = 0, y = 0, w = 24, d = 24, z = 15 },
    { x = 0, y = 0, w = 26, d = 26, z = 14 },
    { x = 0, y = 0, w = 28, d = 28, z = 13 },
    { x = 0, y = 0, w = 30, d = 30, z = 12 },
    { x = 0, y = 0, w = 32, d = 32, z = 11 },
    { x = 0, y = 0, w = 34, d = 34, z = 10 },
    { x = 0, y = 0, w = 36, d = 36, z =  9 },
    { x = 0, y = 0, w = 38, d = 38, z =  8 },
    { x = 0, y = 0, w = 40, d = 40, z =  7 },
    { x = 0, y = 0, w = 42, d = 42, z =  6 },
    { x = 0, y = 0, w = 44, d = 44, z =  5 },
    { x = 0, y = 0, w = 46, d = 46, z =  4 },
    { x = 0, y = 0, w = 48, d = 48, z =  3 },

    -- The lip around the near two edges, so a ball that has come the whole way
    -- down stays on the mountain instead of leaving the world. The far edges need
    -- none: nothing ever travels uphill.
    { x = 47, y =  0, w =  1, d = 48, z =  6 },
    { x =  0, y = 47, w = 48, d =  1, z =  6 },

    -- The dividers.
    --
    -- Blocks standing three layers above the band they sit on, reaching partway
    -- across it. They are what makes the descent a route rather than a fall: a
    -- ball meeting one has to go round, and which way it goes round decides where
    -- on the mountain it comes out.
    --
    -- Each sits along a single contour -- one value of x, or one of y, with the
    -- other running across the slope -- so that the block is level rather than
    -- perched on a step. A divider that straddled a band boundary would be a
    -- block with one corner in the air.
    --
    -- Partway across, never all the way. A divider that spanned its band would be
    -- a wall, and a wall traps balls above it forever, since nothing here climbs.
    { x =  9, y =  0, w =  1, d =  6, z = 25 },
    { x =  0, y =  9, w =  6, d =  1, z = 25 },
    { x = 13, y =  4, w =  1, d =  7, z = 23 },
    { x =  4, y = 13, w =  7, d =  1, z = 23 },
    { x = 17, y =  0, w =  1, d =  9, z = 21 },
    { x =  0, y = 17, w =  9, d =  1, z = 21 },
    { x = 17, y = 12, w =  1, d =  5, z = 21 },
    { x = 12, y = 17, w =  5, d =  1, z = 21 },
    { x = 21, y =  5, w =  1, d = 10, z = 19 },
    { x =  5, y = 21, w = 10, d =  1, z = 19 },
    { x = 25, y =  0, w =  1, d = 11, z = 17 },
    { x =  0, y = 25, w = 11, d =  1, z = 17 },
    { x = 25, y = 16, w =  1, d =  8, z = 17 },
    { x = 16, y = 25, w =  8, d =  1, z = 17 },
    { x = 29, y =  6, w =  1, d = 14, z = 15 },
    { x =  6, y = 29, w = 14, d =  1, z = 15 },
    { x = 33, y =  0, w =  1, d = 12, z = 13 },
    { x =  0, y = 33, w = 12, d =  1, z = 13 },
    { x = 33, y = 18, w =  1, d = 12, z = 13 },
    { x = 18, y = 33, w = 12, d =  1, z = 13 },
    { x = 37, y =  8, w =  1, d = 16, z = 11 },
    { x =  8, y = 37, w = 16, d =  1, z = 11 },
    { x = 41, y =  0, w =  1, d = 14, z =  9 },
    { x =  0, y = 41, w = 14, d =  1, z =  9 },
    { x = 41, y = 22, w =  1, d = 14, z =  9 },
    { x = 22, y = 41, w = 14, d =  1, z =  9 },
    { x = 45, y = 10, w =  1, d = 20, z =  7 },
    { x = 10, y = 45, w = 20, d =  1, z =  7 },
  },

  -- The staircases.
  --
  -- The mountain already descends a layer every two cells, so these are not the
  -- way down -- they are the *fast* way down. A flight drops a layer per cell,
  -- twice as steep as the ground around it, and it cuts a channel through the
  -- bands rather than following them.
  --
  -- Treads overwrite whatever they land on rather than taking the higher of the
  -- two. That is what lets a flight cut through a divider standing in its way: a
  -- divider is by definition taller than the ground it sits on, and "higher wins"
  -- would fill the channel back in and leave a staircase drawn on a hillside that
  -- goes nowhere.
  stairs = {
    { x =  9, y =  2, dir = "+x", w = 2, from = 25, to = 18 },
    { x =  2, y =  9, dir = "+y", w = 2, from = 25, to = 18 },
    { x = 21, y =  8, dir = "+x", w = 2, from = 19, to = 12 },
    { x =  8, y = 21, dir = "+y", w = 2, from = 19, to = 12 },
    { x = 33, y =  3, dir = "+x", w = 2, from = 13, to =  7 },
    { x =  3, y = 33, dir = "+y", w = 2, from = 13, to =  7 },
    { x = 33, y = 24, dir = "+x", w = 2, from = 13, to =  7 },
    { x = 24, y = 33, dir = "+y", w = 2, from = 13, to =  7 },
    { x = 41, y = 14, dir = "+x", w = 2, from =  9, to =  5 },
    { x = 14, y = 41, dir = "+y", w = 2, from =  9, to =  5 },
  },

  -- Where a ball enters the world. The summit, above everything.
  spawn = { x = 2, y = 2, z = 24 },
}
