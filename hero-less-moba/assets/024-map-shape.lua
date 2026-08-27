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

-- 024-map-shape.lua
--
-- The map's shape parameters. Every number that decides where the ground is
-- lives here and nowhere else -- no document quotes one, because a document that
-- quotes a number is a document that will be wrong.
--
-- The field is a square. Team 1's base sits at the bottom-left corner and team
-- 2's at the top-right, so the two bases face each other across one diagonal.
-- The *other* diagonal -- top-left to bottom-right, through the middle -- is
-- where the three junctions stand. That is the whole geometry, and everything
-- below is a measurement of it.
--
-- Coordinates are in paces, with y increasing downward, matching the screen. The
-- simulation never cares which way is up; only the renderer does, and it is
-- cheaper to agree with the display than to flip every position every frame.

local M = {}

-- {{{ M.parameters
M.parameters = {

  -- One side of the square field, in paces. Everything else is measured against
  -- this, so widening the map is one edit.
  field_size = 1400,

  -- How far a library sits in from its own corner. The base is the wedge of
  -- ground between the corner and the library, and this is how deep that wedge
  -- is. Too small and the three base towers have no room to be distinct
  -- positions; too large and the lanes are shorter than the bases.
  base_inset = 190,

  -- Target paces between two plain lane nodes. The builder puts down as many as
  -- it needs to hold roughly this spacing between consecutive milestones, so a
  -- smaller number is a finer graph and a slower move pass, and nothing else.
  node_spacing = 26,

  -- How many nodes a connector is built from, not counting the two junctions it
  -- joins. The connector is the ground the jungle used to occupy; it is short on
  -- purpose, because the only thing it is for is letting a body leave the middle.
  connector_nodes = 5,

  -- Where each milestone sits along its lane, as a fraction of the lane's total
  -- length, running from team 1's library at 0 to team 2's library at 1.
  --
  -- Indexed 0 through 8 to match the milestone indices the whole project uses.
  -- This table is deliberately not an array -- do not take its length, walk it
  -- with milestone_count below.
  --
  -- The table is a mirror of itself: fraction[k] + fraction[8 - k] == 1 for
  -- every k. The map validator asserts exactly that, because an asymmetric map
  -- would hand one team a shorter walk and nobody would ever find out why they
  -- kept losing.
  milestone_fraction = {
    [0] = 0.00,   -- team 1's library
    [1] = 0.11,   -- team 1's base guard tower at this lane's mouth
    [2] = 0.25,   -- team 1's inner lane tower
    [3] = 0.38,   -- team 1's outer lane tower
    [4] = 0.50,   -- the midpoint, which is also this lane's junction
    [5] = 0.62,   -- team 2's outer lane tower
    [6] = 0.75,   -- team 2's inner lane tower
    [7] = 0.89,   -- team 2's base guard tower
    [8] = 1.00,   -- team 2's library
  },
  milestone_count = 9,

  -- How many paces across each lane is. This feeds exactly two things: how many
  -- bodies the frontline queue lets stand abreast, and how wide the renderer
  -- draws the lane. It is not a movement constraint -- soldiers walk the graph in
  -- single file regardless.
  --
  -- The centre is wider, permanently, as topography. That is the only difference
  -- between the three lanes and it is this one number: stacking a side lane is a
  -- bet on quality, because only so many of your bodies will ever be in contact;
  -- stacking the centre is a bet on quantity.
  lane_width = {
    [1] = 62,     -- top
    -- The centre, and the number is derived rather than chosen. Three formations
    -- stand abreast here during a challenge -- a side lane's, the centre's, and the
    -- other side lane's -- and this is how much road that takes: the centre's own
    -- radius, plus a side lane's on either side of it, plus the gaps.
    --
    -- **That is what the centre lane is wide for**, and it is the reason the
    -- document gave for widening it before anybody had arithmetic to put behind it.
    [2] = 140,    -- centre -- the wide one
    [3] = 62,     -- bottom
  },

  -- How the junction's corner is rounded.
  --
  -- A lane bends ninety-odd degrees at its junction, and a vertex is a corner a
  -- formation cannot walk round: the body on the outside would have to cover most
  -- of an arc in a single step. So the nodes either side of the bend are relaxed
  -- toward their neighbours, a few passes over, which cuts the corner into a curve.
  --
  -- The window is how many nodes each way are allowed to move, and therefore how
  -- wide the curve is; the passes are how round it gets. Both are shape rather than
  -- balance, but they live here because they are numbers and numbers live here.
  bend_smoothing_window = 12,
  bend_smoothing_passes = 60,

  -- How far apart two bodies stand when they are queueing. The frontline queue
  -- measures in these; the renderer draws bodies about this size.
  personal_space = 13,
}
-- }}}

return M
