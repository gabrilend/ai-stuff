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

  -- How many zones each milestone interval is cut into.
  --
  -- A zone is a range of distance along a lane and nothing else -- not a node, no
  -- neighbours, nothing walks to one. Two things read them: how deeply a lane has
  -- been pushed, which used to be counted in milestones and was therefore a number
  -- between 0 and 8, and where a wave's next waypoint sits.
  --
  -- **Written as a division rather than a total**, so every milestone stays exactly
  -- on a zone boundary by construction. A total would have to be a multiple of eight
  -- and somebody would eventually write a number that is not.
  zone_divisions = 4,

  -- How many bodies stand abreast in a wave walking each lane.
  --
  -- **The decision, and it is read directly.** It used to be divided out of the
  -- width below, which was fine while a width was a number somebody chose and became
  -- circular the moment a width became a multiple of the formation walking it: the
  -- road would decide the formation and the formation would decide the road.
  --
  -- So this is the design fact -- a side lane carries three, the centre carries five
  -- -- and the width is the arithmetic that gives them room.
  lane_files = {
    [1] = 3,
    [2] = 5,
    [3] = 3,
  },

  -- How many **standard formation widths** of road each lane is.
  --
  -- A standard formation is a side lane's: three abreast. The centre's own formation
  -- is wider than that, and this is still counted in side-lane widths, because the
  -- question the number answers is "how much room is there" and the answer wants one
  -- yardstick rather than one per lane.
  --
  -- A road is three of them: one formation, with a formation's width of clear ground
  -- either side to wander through. The centre is nine, which is also what lets three
  -- formations stand abreast there during a challenge with room to spare rather than
  -- exactly fitting.
  lane_wander_multiple = {
    [1] = 3,
    [2] = 9,
    [3] = 3,
  },

  -- How many paces across each lane is, and it is **derived from the two tables
  -- above**: the width of a standard formation, times the multiple.
  --
  -- Written out rather than computed here because the spacing a formation is built
  -- from lives in the formation module and this file holds no logic. The map
  -- validator does the multiplication and refuses a map where these have drifted
  -- from it -- which is not hypothetical, it is what a lane silently carrying one
  -- body fewer in every rank looks like from the outside.
  --
  -- It is not a movement constraint. A body may stand anywhere; this is how much
  -- road there is.
  lane_width = {
    [1] = 132,    -- top
    [2] = 396,    -- centre -- the wide one
    [3] = 132,    -- bottom
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

  -- How far apart two bodies stand when they are queueing, and how close a guard
  -- has to get to its tower to call itself home. Those are the only two readers.
  --
  -- It used to say the renderer drew bodies about this size and that was never true
  -- -- the renderer keeps its own table of radii, one per archetype, because how big
  -- a thing is drawn is a question about looking at it and this is a question about
  -- standing in a crowd. The two numbers are free to disagree and currently do: a
  -- body is drawn a good deal smaller than the room it keeps around itself, which is
  -- what makes a rank read as a rank rather than as a solid bar.
  personal_space = 18,
}
-- }}}

return M
