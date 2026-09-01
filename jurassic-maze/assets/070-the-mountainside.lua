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
--   * The shelves are flat and several cells deep, and they run across the slope.
--   * Staircases are the only way down that is not a fall, and there are a great
--     many of them.
--
-- The coordinate system, because it decides what "high corner" means: the
-- projection draws small x and y at the top of the screen, so (0, 0) is the far
-- corner and (47, 47) is the near one. Elevation therefore has to *fall* as x and
-- y rise, and every plate below obeys that.
--
-- Elevations here are spaced three layers apart rather than four, and that is a
-- concession rather than a design choice: the old world stores a column as a
-- 32-bit integer with one bit per layer, and a mountain with four-layer shelves
-- comes to thirty-four. The map format has no such ceiling. See open question two
-- of issue 801.

return {
  name  = "the mountainside",
  width = 48,
  depth = 48,

  -- What a cell sits at if no plate ever reaches it. Nothing here relies on it,
  -- since the bottom shelf covers the whole footprint, but a map that leaves a
  -- gap should leave it at the ground rather than in the air.
  base = 0,

  plates = {
    -- The shelves.
    --
    -- Eight nested squares anchored at the far corner, each one lower and larger
    -- than the last, which makes each shelf an L-shaped band six cells wide
    -- wrapping the corner. This is what a stepped mountain face is when it is
    -- built out of axis-aligned rectangles, and the nesting is why they can be
    -- written as eight lines rather than as twenty-four L-shaped pieces: the
    -- higher plate wins wherever two overlap, so the small high squares simply
    -- sit on top of the large low ones.
    --
    -- Three layers between shelves. Deep enough that the drop is a real barrier
    -- a ball cannot climb back up, which is what makes finding the staircase
    -- mean something.
    { x = 0, y = 0, w = 48, d = 48, z =  1 },
    { x = 0, y = 0, w = 42, d = 42, z =  4 },
    { x = 0, y = 0, w = 36, d = 36, z =  7 },
    { x = 0, y = 0, w = 30, d = 30, z = 10 },
    { x = 0, y = 0, w = 24, d = 24, z = 13 },
    { x = 0, y = 0, w = 18, d = 18, z = 16 },
    { x = 0, y = 0, w = 12, d = 12, z = 19 },
    { x = 0, y = 0, w =  6, d =  6, z = 22 },

    -- The rims.
    --
    -- One cell wide along each shelf's downhill edge, standing two layers above
    -- its own floor. This is the closest thing in the map to a wall, and it is
    -- deliberately not one: it is a lip on the edge of a plate, and its top is a
    -- surface like any other.
    --
    -- Two layers rather than one because a rolling ball has to be turned by it
    -- rather than hopped over, and rather than four because a rim is meant to
    -- read as a kerb on the edge of a terrace and not as a fence around it.
    --
    -- They are also the only thing in this map that hides anything. A rim stands
    -- two layers above the shelf behind it and the line of sight only gains 1.6
    -- layers per diagonal cell, so each one takes the single cell immediately
    -- uphill of it. Three hundred and fifty-one cells, and every one of them a
    -- deliberate feature rather than an accident of the geometry.
    { x =  5, y =  0, w =  1, d =  6, z = 24 },
    { x =  0, y =  5, w =  6, d =  1, z = 24 },
    { x = 11, y =  0, w =  1, d = 12, z = 21 },
    { x =  0, y = 11, w = 12, d =  1, z = 21 },
    { x = 17, y =  0, w =  1, d = 18, z = 18 },
    { x =  0, y = 17, w = 18, d =  1, z = 18 },
    { x = 23, y =  0, w =  1, d = 24, z = 15 },
    { x =  0, y = 23, w = 24, d =  1, z = 15 },
    { x = 29, y =  0, w =  1, d = 30, z = 12 },
    { x =  0, y = 29, w = 30, d =  1, z = 12 },
    { x = 35, y =  0, w =  1, d = 36, z =  9 },
    { x =  0, y = 35, w = 36, d =  1, z =  9 },
    { x = 41, y =  0, w =  1, d = 42, z =  6 },
    { x =  0, y = 41, w = 42, d =  1, z =  6 },

    -- The lip around the bottom shelf, so that a ball which has come all the way
    -- down stays on the mountain instead of rolling off the near corner and out
    -- of the world. The far edges need no lip: nothing ever travels uphill.
    { x = 47, y =  0, w =  1, d = 48, z =  3 },
    { x =  0, y = 47, w = 48, d =  1, z =  3 },

    -- The dividers.
    --
    -- Short blocks standing on the shelves, three layers up, reaching partway
    -- across a band. They are what turns a shelf from a corridor into a choice:
    -- a ball arriving on one has to go round, and which side it goes round
    -- decides which staircase it reaches.
    --
    -- Partway across, never all the way. A divider that spans a whole band is a
    -- wall, and a wall would trap balls on the uphill side of it forever, since
    -- nothing in this world can climb.
    { x =  7, y =  2, w =  4, d =  1, z = 22 },
    { x =  2, y =  8, w =  1, d =  3, z = 22 },
    { x = 13, y =  4, w =  4, d =  1, z = 19 },
    { x =  4, y = 13, w =  1, d =  4, z = 19 },
    { x = 14, y =  9, w =  3, d =  1, z = 19 },
    { x = 19, y =  6, w =  4, d =  1, z = 16 },
    { x =  6, y = 19, w =  1, d =  4, z = 16 },
    { x = 20, y = 15, w =  3, d =  1, z = 16 },
    { x = 25, y =  8, w =  4, d =  1, z = 13 },
    { x =  8, y = 25, w =  1, d =  4, z = 13 },
    { x = 26, y = 18, w =  3, d =  1, z = 13 },
    { x = 31, y = 10, w =  4, d =  1, z = 10 },
    { x = 10, y = 31, w =  1, d =  4, z = 10 },
    { x = 32, y = 24, w =  3, d =  1, z = 10 },
    { x = 37, y = 14, w =  4, d =  1, z =  7 },
    { x = 14, y = 37, w =  1, d =  4, z =  7 },
    { x = 38, y = 28, w =  3, d =  1, z =  7 },
    { x = 43, y = 18, w =  4, d =  1, z =  4 },
    { x = 18, y = 43, w =  1, d =  4, z =  4 },
  },

  -- The staircases.
  --
  -- One tread per layer, so a flight is a ramp a ball accelerates down rather
  -- than a set of ledges it stalls on. Each cuts through the rim of the shelf it
  -- leaves, which is why the treads overwrite whatever was there rather than
  -- taking the higher of the two -- a rim is by definition taller than the flight
  -- passing through it, and "higher wins" would fill the cut back in.
  --
  -- Placed alternately on the x edge and the y edge of successive shelves, so
  -- that the way down the mountain is a switchback. A ball leaving one flight has
  -- to cross its new shelf to reach the next, which is the whole journey.
  stairs = {
    { x =  5, y =  2, dir = "+x", w = 2, from = 22, to = 19 },
    { x =  3, y = 11, dir = "+y", w = 2, from = 19, to = 16 },
    { x = 17, y = 13, dir = "+x", w = 2, from = 16, to = 13 },
    { x =  5, y = 23, dir = "+y", w = 2, from = 13, to = 10 },
    { x = 29, y = 20, dir = "+x", w = 2, from = 10, to =  7 },
    { x =  8, y = 35, dir = "+y", w = 2, from =  7, to =  4 },
    { x = 41, y = 30, dir = "+x", w = 2, from =  4, to =  1 },

    -- Second ways down, so that some shelves offer a choice rather than a single
    -- destination. A maze with one route through it is a corridor.
    { x = 12, y = 17, dir = "+y", w = 2, from = 16, to = 13 },
    { x = 23, y =  9, dir = "+x", w = 2, from = 13, to = 10 },
    { x = 20, y = 29, dir = "+y", w = 2, from = 10, to =  7 },
    { x = 35, y = 26, dir = "+x", w = 2, from =  7, to =  4 },
    { x = 20, y = 41, dir = "+y", w = 2, from =  4, to =  1 },
  },

  -- Where a ball enters the world. The summit shelf, above everything.
  spawn = { x = 2, y = 2, z = 22 },
}
