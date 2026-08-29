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

-- 052-formations.lua
--
-- A wave leaves the base **already in formation**, and marches as one body.
--
-- Not a column that deploys into a line when it meets something. There is no
-- moment of forming up, because there is no moment at which the wave was not
-- formed: it walks out of the library in its ranks and it is battle-ready the
-- whole way down the lane. The only thing that ever walks in single file is a
-- siege-surge, which is a stream rather than a wave and has no formation at all.
--
-- ## Held in lane coordinates, which is why a rank survives a corner
--
-- A body's place is two numbers: **how far along the lane** the wave's anchor has
-- got, plus this body's offset from it, and **how far across** the lane it stands.
-- The world position is derived from those against the lane's own curve.
--
-- That is the whole trick. Hold a formation in world coordinates and a rank going
-- round a bend either tears apart or scythes through the inside of the turn,
-- because the bodies on the outside have further to walk and nothing tells them
-- so. Hold it in lane coordinates and **the formation curves to match the path it
-- is on** for free -- every body in a rank shares one distance-along, and the lane
-- carries the line round the corner as a line.
--
-- ## Cohesion is a budget, not a bonus
--
-- Turning still pulls a formation out of shape, because the outside of a bend is
-- longer than the inside. So bodies out of place correct, and **the correction is
-- conserved**: those furthest behind their place hurry, and what they gain is
-- taken from those in front of them, ahead of their own place, or nearest to it --
-- so the leaders wait and the stragglers close up and the two meet.
--
-- Expressed as a deviation from the wave's own mean lag, which makes the
-- conservation structural rather than something arithmetic has to be careful
-- about: the deviations sum to zero, so the speed handed out equals the speed
-- given up, exactly, every tick, without anybody checking.

local M = {}

-- Rank layouts, cached by how many bodies stand abreast. See file_offset.
M.file_order = {}

-- Paces between two ranks, and between two files in a rank.
--
-- These are the room a body keeps, not the size a body is drawn. The renderer's
-- radii are a good deal smaller, deliberately: a rank drawn at the spacing it walks
-- at would be a solid bar, and what a player needs to see is a line made of
-- countable people.
--
-- **Widening these widens the lanes**, because a lane's width is derived from them
-- and the file counts it is supposed to carry. The validator asserts the derivation
-- still holds, so raising a spacing without moving a width fails at load rather than
-- quietly dropping a body from every rank.
local RANK_SPACING = 30
local FILE_SPACING = 22

-- How much of the lane's width the marching formation uses. Less than all of it,

-- **The three speeds, as multiples of a body's own pace.**
--
-- A body is in a gear rather than on a dial. The version this replaces scaled a
-- body's speed smoothly with how far behind its place it stood, and a formation of
-- those never settles -- everybody always slightly correcting, each at a slightly
-- different rate, so the line breathes instead of marching. It is also unmeasurable:
-- "how fast is that soldier going" has a different answer for every soldier and every
-- tick, so nothing about it can be compared to anything.
--
--   walking   giving way, for a body that has got ahead of its place
--   marching  the pace, and the catching-up pace -- both, deliberately, because a
--             body that is where it should be and a body hurrying to get there are
--             doing the same thing at the same speed. What differs is who is
--             *slowing*, and that is what shares the budget out.
--   running   leaving, and nothing else. Not built here: it belongs to a body that
--             has been beaten and is getting out, which is issue 212.
--
-- The increments are proportional to a body's own speed rather than absolute, so a
-- slow body's gears are close together and a fast one's are far apart -- a gear is a
-- fraction of what that body can do, not a number of paces somebody chose.
local WALKING = 0.70
local MARCHING = 1.00

-- How far out of place a body has to be before it changes gear, in paces.
--
-- A dead band, and it is the whole of what keeps this from feeling hesitant. Without
-- it a body a hair ahead of its place drops into walking, arrives a hair behind, goes
-- back to marching, and does that every tick forever.
-- Measured rather than chosen. The two things it trades off pull opposite ways, and
-- the sandbox prints both every run so the equilibrium can be found rather than
-- guessed at:
--
--   band   line bends   gear changes per hundred body-ticks
--   0.5      4.8          17.3      -- about once every six ticks. Chatter.
--   1.0     11.8           9.4
--   2.0     13.7           5.4      -- about one and a half times a second
--   3.0     20.7           3.7
--   5.0     24.8           0.9      -- steady, and the line is nearly a rank out
--
-- Two is the knee. Below it the line is barely tidier and bodies start switching
-- several times a second, which is the hesitancy this is here to prevent; above it
-- the shape goes and the gears stop doing anything at all on a bend.
local GEAR_CHANGE = 2

-- How far the formation may fall behind its own front before the front stops and
-- waits for it, in paces.
--
-- **This is what replaces hurrying.** With a dial, a body behind its place was given
-- extra speed out of a budget taken from the bodies ahead of it. With gears, nothing
-- exceeds marching pace -- so a body on the outside of a bend, which has further to
-- walk than a body on the inside, simply cannot keep up, and the line would stretch
-- for as long as the turn lasted.
--
-- So the front waits. Which is what a real body of troops does going round a corner:
-- it does not ask the outside rank to run, it slows the whole march until the line is
-- dressed again. Half a rank of stretch is the tolerance, which is loose enough that
-- an ordinary march never touches it and tight enough that a turn cannot pull the
-- formation into a column.
local ANCHOR_PATIENCE = RANK_SPACING * 0.5

-- How far behind its place a body can be and still be **in** the formation.
--
-- Beyond this it is not out of position, it is **rejoining** -- it fell out of the
-- line to mend and is walking back up, or it was spawned late, or it got round the
-- wrong side of something. Either way it is a long way from where it should be, and
-- averaging it into the budget tells every body that is standing exactly right that
-- it is badly ahead.
--
-- So a rejoining body is outside the budget: it neither takes speed nor gives any,
-- and simply walks back at its own pace. It rejoins when it arrives.
-- Measured in ranks rather than in paces, so that spreading a formation out does
-- not silently redefine what counts as having fallen out of it.
local REJOIN_DISTANCE = RANK_SPACING * 3

-- What the gears used to be clamped between, when a body's speed was a dial. Nothing
-- reads them for movement now -- there are two gears and neither can leave its own
-- range -- and they are kept because the tests measure the budget's imbalance against
-- what one body's worth of clamping can produce, and that is still the question.
local SPEED_CEILING = 1.55
local SPEED_FLOOR = 0.55

-- How fast a body slides sideways toward its file, as a fraction of its speed.
-- Lower than one, so correcting laterally costs forward progress and a wave that
-- has been bent by a turn visibly takes a moment to straighten.
local LATERAL_RATE = 0.55

-- How fast a formation slides toward its waypoint, as a fraction of its marching
-- pace. Slow: a wave crossing a zone boundary should drift, not step sideways.
--
-- Low enough that a wave usually reaches one waypoint about as it is given the next,
-- which is what makes the path a long shallow curve rather than a sequence of
-- corrections. **They generally march straight on a straight road.**
local WANDER_RATE = 0.10

-- How much clear ground between two formations standing abreast. Small: enough that
-- they read as two lines rather than one wide one, and no more.
local ABREAST_GAP = 6

-- How much of the lane's width a marching formation is allowed to occupy, back when
-- the file count was divided out of the width. **Nothing reads it now** -- the count
-- is declared and the width is derived from it -- and it is left here as the record
-- of a circularity that used to be real:
--
-- the centre lane is wide so that three formations fit abreast during a challenge,
-- but a wider lane made the centre's own formation wider, which pushed the other two
-- further out, which needed a wider lane. Every attempt to make the corridor contain
-- them made them bigger. It was capped rather than solved.
--
-- Declaring the count dissolves it: a road twice as wide does not make an army twice
-- as broad, it makes it comfortable, and that is now true by construction instead of
-- by a ceiling.

-- How near an enemy has to be to the front of a wave before the wave stops
-- advancing and lets its bodies fight.
local CONTACT_RANGE = 62

-- {{{ function M.files_for()
-- How many bodies stand abreast in a wave marching down a given lane.
--
-- **This is where the lane's width earns its keep.** It does not decide how many
-- bodies may fight at once -- nothing does; the world is flat and a lane is a
-- suggestion. It decides how wide a formation *travels*, which is a different
-- question with a real answer: a road's width is how many people can walk down it
-- side by side without leaving it.
--
-- The consequence is the one the wide centre lane always wanted. A wave marching
-- up the middle arrives with more of itself abreast, so more of it is in contact
-- the moment contact happens, and a numerical advantage tells sooner.
function M.files_for(lane)
  -- **Declared, not derived.** This used to divide the lane's width by the file
  -- spacing, which was fine while a width was a number somebody chose and became
  -- circular the moment a width became *three times the formation walking it*: the
  -- road's width would then decide the formation's width, which decides the road's.
  --
  -- So the count is a design decision written down in the shape parameters, and the
  -- width is the arithmetic that gives that many bodies room to walk and room to
  -- wander. The validator checks the arithmetic; this reads the decision.
  local files = lane.files
  if files == nil or files < 2 then
    error("lane " .. tostring(lane.id) .. " does not say how many walk it abreast")
  end
  return files
end
-- }}}

-- {{{ function M.radius_of()
-- The formation's **radius**: half the width of the rank, so that a circle of this
-- radius drawn about the formation's centre has its edges touching the left and
-- right of the line as it walks.
--
-- It is what decides how far apart two formations stand when they have to stand
-- abreast -- one radius for this one, one for the other, and a small gap so they
-- read as two lines rather than one wide one.
function M.radius_of(lane)
  local files = M.files_for(lane)
  return (files - 1) * 0.5 * FILE_SPACING
end
-- }}}

-- {{{ function M.abreast_offset()
-- Where a wave raised for one lane stands, across the lane it is actually walking.
--
-- Zero everywhere except during a challenge, when all three lanes' production goes
-- into the middle. There, **the three waves stand abreast of one another** rather
-- than on top of each other: the centre lane's wave keeps the middle, and the side
-- lanes' waves sit one full formation to either side.
--
-- The spacing is derived rather than chosen -- this formation's radius, plus the
-- neighbour's, plus a small gap -- so widening a wave moves them apart by exactly
-- as much as it needs to and never has to be re-tuned alongside.
--
-- And **this is what the centre lane is wide for.** Three formations abreast is the
-- thing the width has to accommodate, which is the reason the document gave for
-- widening it in the first place, now with an arithmetic behind it instead of an
-- intention.
function M.abreast_offset(map, from_lane, centre_lane)
  if from_lane == centre_lane then
    return 0
  end
  -- **This formation's radius, plus the neighbour's, plus a gap.** Not twice one
  -- radius: a wave funnelled in from a side lane keeps its own lane's shape -- the
  -- same principle that has it keep its own lane's upgrades -- so the two circles
  -- being separated are different sizes, and using either one twice would either
  -- overlap them or leave a hole.
  local step = M.radius_of(map.lane[from_lane])
             + M.radius_of(map.lane[centre_lane])
             + ABREAST_GAP
  -- The lane that was raised on the low side sits on the low side, so the three
  -- keep their left-to-right order and a player watching can still tell which
  -- group came from where.
  return (from_lane < centre_lane) and -step or step
end
-- }}}

-- {{{ function M.file_offset()
-- Where the nth body in a rank stands, across the lane.
--
-- Two things have to be true at once and they pull against each other. The rank as
-- a whole must be **centred on the lane**, so a wave marches down the middle of the
-- road rather than scraping one verge. And **file zero must be the middle one**, so
-- that the captain -- which is always given the first place -- stands in the centre
-- of the line, where it is both most useful and most visible.
--
-- So the positions are laid out evenly and centred, and then the *order they are
-- handed out in* runs from the middle outward: the centre slot first, then the one
-- beside it, then the one on the other side, and so on. A rank that is not full is
-- therefore short at its edges rather than at its middle, which is what a thinning
-- line should look like.
--
-- Cached per rank width, because the ordering cannot change and rebuilding it for
-- every body of every wave would be a sort per soldier per spawn.
function M.file_offset(files, file)
  local order = M.file_order[files]
  if order == nil then
    local centre = (files - 1) * 0.5
    local slots = {}
    for k = 0, files - 1 do
      slots[#slots + 1] = k
    end
    table.sort(slots, function(a, b)
      local da, db = math.abs(a - centre), math.abs(b - centre)
      if da == db then
        -- A deterministic tiebreak for the two slots either side of an even
        -- centre. Which one is chosen does not matter; that it is always the same
        -- one does, because the simulation has to replay.
        return a > b
      end
      return da < db
    end)
    order = {}
    for index, k in ipairs(slots) do
      order[index - 1] = (k - centre) * FILE_SPACING
    end
    M.file_order[files] = order
  end
  return order[file] or 0
end
-- }}}

-- {{{ function M.assign_wave_slots()
-- Gives every body a place in its wave's formation, once, at birth.
--
-- Melee take the front ranks and ranged the ones behind, which is the arrangement
-- and not an accident of who spawned first. The captain takes the centre of the
-- front rank, where it is both the most useful and the most visible -- a player
-- should be able to see the enemy's signature body coming.
--
-- `order` is the index of this body within its wave, counted separately per role.
function M.assign_wave_slots(world, id, lane, role_index, role, melee_total)
  local soldier = world.soldier
  local files = M.files_for(lane)
  local half_width = (files - 1) * 0.5 * FILE_SPACING

  local forward, sideways
  if role == "front" then
    -- The line. Ranks across the face, filled from the middle of the arc outward,
    -- so a rank that is not full is short **at its ends** rather than in its middle.
    -- That is what a thinning line looks like, and it also keeps the captain -- which
    -- is always given the first place -- on the bearing straight ahead, where it is
    -- both most useful and most visible.
    local rank = math.floor(role_index / files)
    local file = role_index % files
    forward = -rank * RANK_SPACING
    sideways = M.file_offset(files, file)
  else
    -- **The shoulders, not the back.**
    --
    -- These stood directly behind the line, in the same files, one gap further back,
    -- on the reasoning that they were shooting over it. They cannot shoot over it.
    -- Only artillery does that -- a longbow lofting across a glen -- and a body with
    -- a javelin or a sling is shooting **around**, which means it needs a bearing to
    -- its target that does not pass through a friend.
    --
    -- So they stand at the **shoulders**: behind the last rank of the line and out at
    -- its ends, on a bearing of about five-eighths of a turn from dead ahead. From
    -- there the line is diagonally in front of them rather than squarely so, and
    -- anything they want to shoot that is not directly up the middle has a clear
    -- bearing past it. Alternating sides, so a wave with two has one on each shoulder
    -- rather than both on the left.
    --
    -- **This is a placement, not a guarantee.** There is no line-of-fire check in this
    -- game -- nothing occludes anything, and a shot is a distance and a cooldown. So
    -- standing them where their line is clearest is the whole of the mechanism, and
    -- it is worth knowing that it is a shape rather than a rule.
    --
    -- The formation gets no wider for it. They occupy the outermost file rather than
    -- a new one, which matters because a road's width is derived from how wide the
    -- formation walking it is -- widening the shape here would widen every road in
    -- the game.
    local side = (role_index % 2 == 0) and 1 or -1
    local depth_index = math.floor(role_index / 2)
    -- Behind the last rank of the line, at its **ends**. Not in the line: the outer
    -- file of every rank is already occupied by somebody holding it, and a place is
    -- not a place if somebody is standing in it.
    local line_ranks = math.ceil(melee_total / files)
    forward = -(line_ranks + depth_index) * RANK_SPACING
    sideways = side * half_width
  end

  -- The offsets from the front of the formation, which is what the movement works
  -- in. The bearing and distance from its **centre** -- the description everything
  -- angular is asked of -- are written by `settle_the_disc` once the whole wave has
  -- been placed, because where the centre is depends on how deep the formation
  -- turned out to be, and that is not known until the last body has a place.
  soldier.slot_along[id] = forward
  soldier.slot_across[id] = sideways

  -- How deep the formation reaches behind its anchor, kept as bodies are given
  -- places rather than measured afterwards. The anchor is the **front** of a wave,
  -- and the question "which zone is this formation in" is about its middle, which is
  -- half of this behind the front.
  --
  -- Accumulated rather than computed from the member count, because the bodies on the
  -- shoulders sit further back than the line does and how far depends on how many
  -- there are.
  local wave = world.wave[soldier.wave[id]]
  if wave ~= nil then
    local reach = -forward
    if wave.depth == nil or reach > wave.depth then
      wave.depth = reach
    end
  end
end
-- }}}

-- {{{ function M.settle_the_disc()
-- Writes every body's **bearing and distance from the formation's centre**, once the
-- whole formation has been placed.
--
-- Polar because the questions asked about a place are angular ones. Can this body
-- shoot past that one. Is it on the flank or in the middle where the heavy troops
-- belong. Which way should it face. Every one of those is a bearing with a distance
-- attached, and none of them is a row and a column.
--
-- **After the wave is built, not during.** A circle has a centre and does not have a
-- front, so a bearing has to be measured from the middle -- and where the middle is
-- depends on how deep the formation turned out to be, which is not known until the
-- last body has been given somewhere to stand. Computed body by body as they were
-- born, every bearing came out measured from a centre that was still moving, and the
-- front rank came out at a quarter turn from dead ahead, which is where the flanks
-- are.
--
-- Bearings run from 0 dead ahead, through a quarter turn at the flanks, to half a
-- turn at the rear. The sign is which side.
function M.settle_the_disc(world, wave_id)
  local soldier = world.soldier
  local wave = world.wave[wave_id]
  if wave == nil then
    return
  end
  -- The centre sits half the formation's depth behind its front.
  local middle = -(wave.depth or 0) * 0.5

  for id = 1, world.high_water do
    if soldier.wave[id] == wave_id then
      local forward = soldier.slot_along[id] - middle
      local sideways = soldier.slot_across[id]
      soldier.slot_bearing[id] = math.atan2(sideways, forward)
      soldier.slot_distance[id] = math.sqrt(forward * forward + sideways * sideways)
    end
  end
end
-- }}}

-- {{{ function M.target_of()
-- Where a body's place currently is, in lane coordinates.
--
-- The slot's along-offset is negative -- behind the anchor -- and is multiplied by
-- facing, because team 2 walks down the lane's numbering rather than up it and
-- "behind" is the other way for them.
function M.target_of(world, id)
  local soldier = world.soldier
  local wave = world.wave[soldier.wave[id]]
  if wave == nil then
    return soldier.lane_along[id], soldier.lane_across[id]
  end
  -- Three things decide how far across the lane a body's place is: where it stands
  -- in its own rank, where its whole formation has been shifted to stand abreast of
  -- the others during a challenge, and where the formation is currently wandering.
  -- They add rather than override -- a wave funnelled into the middle still wanders,
  -- and a wandering wave still keeps its place in the three.
  return wave.anchor + soldier.slot_along[id] * soldier.facing[id],
         soldier.slot_across[id] + (wave.across_offset or 0) + (wave.wander or 0)
end
-- }}}

-- {{{ function M.live_radius()
-- **How wide this formation actually is**, right now, from the bodies in it.
--
-- Not the road's. `radius_of` answers "how wide is a full rank on this lane", which
-- is what the road has to be built to hold and what two formations standing abreast
-- have to be separated by. This answers "how wide is *this* wave", which is a
-- different number and moves.
--
-- It moves for two reasons. A wave that never had enough melee to fill its rank was
-- born narrow -- the places are handed out from the middle of the line outward, so a
-- short rank is short at its edges. And a wave that has been fought down is narrower
-- than it was, because the bodies that die first are the ones at the front and the
-- flanks.
--
-- The circle has to be resizable or every use of it is wrong in one direction or the
-- other: a bound computed from a full rank puts a wide formation's edge in the ditch
-- and keeps a narrow one further from the verge than it needs to be.
--
-- Measured from the places rather than from the positions. A body knocked out of its
-- file by a corner is not evidence that the formation got wider; it is evidence that
-- the body is out of place, which the cohesion budget is already dealing with.
function M.live_radius(world, members, count)
  local soldier = world.soldier
  local widest = 0
  for index = 1, count do
    local across = soldier.slot_across[members[index]]
    if across < 0 then across = -across end
    if across > widest then widest = across end
  end
  return widest
end
-- }}}

-- {{{ local function advance_anchor()
-- Moves a wave's anchor down the lane, unless it has run into something.
--
-- The anchor is the formation's front, not its centre of mass, so stopping it when
-- an enemy is near the front stops the whole wave at the point of contact rather
-- than letting the ranks behind push the front through the enemy.
local function advance_anchor(world, wave)
  local lane = world.map.lane[wave.lane]
  local facing = (wave.team == 1) and 1 or -1

  -- Where the front of the formation is standing.
  local front = wave.anchor
  local x, y = world.map_builder.point_at(world.map, lane, front, wave.hint)

  local blocked = false
  world.targeting.for_each_near(world, x, y, CONTACT_RANGE, function(id)
    if not blocked and world.targeting.hostile(wave.team, world.soldier.team[id]) then
      blocked = true
    end
  end)

  wave.engaged = blocked and 1 or 0
  if blocked then
    return
  end

  -- Where the **middle** of the formation is. The anchor is its front, deliberately
  -- -- a wave stops when something is near the front of it, not when something is
  -- near the middle -- but which zone a wave has reached is a question about the
  -- body of it.
  local centre = front - (wave.depth or 0) * 0.5 * facing
  local zone = world.map_builder.zone_at(lane, centre,
                                         world.parameters.shape.zone_divisions)

  if zone ~= wave.zone then
    wave.zone = zone

    -- **The room this formation has, and it is this formation's own.**
    --
    -- Half the road, less **its own radius** -- not the road's standard formation's.
    -- A wave that has been whittled down is narrower than a fresh one and has more
    -- room to move about in; a wave that is wider has less. Measuring the room with
    -- one number for the whole road would put the edge of a wide formation in the
    -- ditch and keep a narrow one further from the verge than it needs to be.
    local room = lane.width * 0.5 - (wave.radius or 0)
    if room < 0 then room = 0 end

    -- **Its own stream, made from its own id.**
    --
    -- Not the team's. A stream shared across a team is advanced by whichever wave
    -- happens to cross a boundary first, so a wave's wander would depend on how many
    -- other waves that team had walking and where they were -- which makes the
    -- wander an amplifier for any difference between two machines rather than a
    -- property of a wave. Two runs a hair apart would take entirely different roads.
    --
    -- Seeded from the match seed, the team and the wave's own number, so the answer
    -- depends on nothing but which wave this is. Made once, on the wave, and kept.
    local stream = wave.waypoint_stream
    if stream == nil then
      stream = world.random_streams.new(world.parameters.seed,
                                        "waypoint-" .. wave.team .. "-" .. wave.id)
      wave.waypoint_stream = stream
    end

    -- **A column, chosen once and kept.** The road divides into three lengthways,
    -- and a wave picks one on its way out and stays in it: a wave that started on
    -- the left tends to stay on the left.
    --
    -- Without this a wave draws an independent offset in every zone and crosses the
    -- road repeatedly on the way down it, which is not an army with an approach --
    -- it is an army that cannot make up its mind. The column is the decision; the
    -- draw inside it is the imprecision.
    if wave.column == nil then
      wave.column = stream:next_below(3) - 2
    end

    -- One column's width, and the destination somewhere inside it. Three equal
    -- bands covering the room exactly: the outer two reach the shoulder and the
    -- middle one straddles the centre line.
    local band = room * 2 / 3
    wave.wander_to = wave.column * band
                     + (stream:next_float() * 2 - 1) * band * 0.5
  end

  -- Eased rather than snapped, and slowly. A formation that jumped sideways the
  -- instant it crossed a boundary would read as the whole line stepping left; what
  -- it should read as is a body of people drifting toward a place none of them could
  -- name. **They generally march straight on a straight road** -- the wander is a
  -- variation in where a wave sits and what angle it arrives at, not a weave.
  local wander = wave.wander or 0
  local want = wave.wander_to or 0
  local step = wave.pace * WANDER_RATE
  if want - wander > step then
    wander = wander + step
  elseif wander - want > step then
    wander = wander - step
  else
    wander = want
  end
  wave.wander = wander

  -- A wave advances at its slowest member's pace, so it does not walk away from
  -- its own rear rank. The captain is the slowest body in a wave, which is why a
  -- wave moves at a captain's speed whether or not its captain is still alive --
  -- a wave that sped up when its captain died would be a wave rewarded for losing
  -- the most valuable thing in it.
  --
  -- **And it waits when the formation is stretched.** Nothing goes faster than
  -- marching pace, so a body on the outside of a bend cannot make up the extra ground
  -- by hurrying -- the front has to stop asking for it. Read from last tick's
  -- measurement, which is a tick of latency and invisible at a tenth of a pace.
  if (wave.mean_lag or 0) > ANCHOR_PATIENCE then
    wave.waiting = 1
    return
  end
  wave.waiting = 0

  wave.anchor = wave.anchor + wave.pace * facing
  if wave.anchor < 0 then wave.anchor = 0 end
  if wave.anchor > lane.length then wave.anchor = lane.length end
end
-- }}}

-- {{{ local function share_out_speed()
-- The conserved correction.
--
-- Each body's lag is how far behind its place it is, measured along the direction
-- of travel. The wave's mean lag is subtracted, so what is left is a **deviation**
-- that sums to zero across the wave -- and a multiplier built from it hands out
-- exactly as much speed as it takes away, every tick, structurally, rather than
-- because somebody remembered to balance the books.
--
-- The mean matters as well as the deviation: a wave whose every member is behind
-- is not out of formation, it is a wave whose anchor has got ahead of it, and
-- speeding all of them up would be a wave that accelerates for no reason.
local function share_out_speed(world, wave, members, count)
  local soldier = world.soldier
  if count == 0 then
    return
  end

  -- **Only bodies still marching are in the budget.** One that has closed on an
  -- enemy has left the formation's business -- *once fighting begins it is less
  -- important to retain cohesion* -- and including it would be the formation trying
  -- to drag a body out of a fight by the collar.
  --
  -- It also keeps the budget honest. A body that has charged is a very long way
  -- from its place, and averaging that in would tell every body still in line that
  -- it was badly out of position when it is standing exactly where it should be.
  local marching, marching_count = wave.marching_scratch, 0
  if marching == nil then
    marching = {}
    wave.marching_scratch = marching
  end

  local sum = 0
  for index = 1, count do
    local id = members[index]
    if soldier.state[id] == 1 then
      local target_along = M.target_of(world, id)
      -- Positive means behind. Multiplying by facing folds the two directions into
      -- one sign, so team 2 lags the same way team 1 does.
      local lag = (target_along - soldier.lane_along[id]) * soldier.facing[id]
      wave.lag_of[id] = lag

      if lag > REJOIN_DISTANCE or lag < -REJOIN_DISTANCE then
        -- Rejoining rather than out of position. Outside the budget entirely.
        soldier.speed_scale[id] = 1
      else
        marching_count = marching_count + 1
        marching[marching_count] = id
        sum = sum + lag
      end
    else
      wave.lag_of[id] = 0
      soldier.speed_scale[id] = 1
    end
  end

  if marching_count == 0 then
    wave.speed_balance = 0
    wave.speed_shared_among = 0
    return
  end

  members, count = marching, marching_count
  local mean = sum / count
  -- Published so the anchor can read it next tick and wait if the formation has been
  -- pulled out of shape. Positive means the wave as a whole is behind its own front.
  wave.mean_lag = mean

  local handed_out = 0
  for index = 1, count do
    local id = members[index]
    local deviation = wave.lag_of[id] - mean

    -- **A body is in a gear, not on a dial.**
    --
    -- This was a continuous multiplier -- a body's speed scaled smoothly with how far
    -- behind its place it was -- and a formation of them never settles: everybody is
    -- always slightly correcting, at a slightly different rate, and the line breathes
    -- rather than marches. It also cannot be measured, because "how fast is that
    -- soldier going" has a different answer for every soldier and every tick.
    --
    -- So there are three speeds and a body is in one of them:
    --
    --   walking   giving way. A body ahead of its place, letting the line catch up.
    --   marching  the pace, and the catching-up pace: what a body does when it is
    --             where it should be, and what it does to get back there.
    --   running   leaving. Nothing running is in a formation any more -- see 212.
    --
    -- Which one is a question about the deviation, asked with a dead band around
    -- zero so that a body standing very nearly right does not switch gear every tick
    -- over a fraction of a pace. The band is the hesitancy this replaces.
    local scale = MARCHING
    if deviation < -GEAR_CHANGE then
      scale = WALKING
    end
    soldier.speed_scale[id] = scale
    handed_out = handed_out + scale
  end

  -- How far off the books came out this tick, recorded rather than asserted.
  --
  -- It should be zero: the deviations sum to zero by construction, so the speed
  -- handed out equals the speed given up without anybody counting. The clamps are
  -- allowed to break that, and are supposed to -- a straggler that could sprint
  -- would read as teleporting -- so what this number is for is noticing a
  -- *systematic* drift, which would mean a wave quietly moving faster than its
  -- catalogue says.
  --
  -- Kept here rather than measured from outside because the set of bodies this was
  -- shared among is the set that was alive when it was shared, and some of them
  -- will be dead by the time anybody else looks.
  wave.speed_balance = handed_out - count
  wave.speed_shared_among = count
end
-- }}}

-- {{{ function M.plan()
-- Advances every wave's anchor and shares out the cohesion budget. Once per tick,
-- before the brain runs.
function M.plan(world)
  local soldier = world.soldier

  -- Gather each wave's living members. Waves accumulate for the whole match, so
  -- only the ones with anybody left in them are worth walking.
  local members = world.formation_scratch
  for _, wave in ipairs(world.wave) do
    if wave.living_count > 0 then
      local count = 0
      for id = 1, world.high_water do
        if soldier.alive[id] == 1 and soldier.wave[id] == wave.id then
          count = count + 1
          members[count] = id
        end
      end
      if count > 0 then
        wave.radius = M.live_radius(world, members, count)
        advance_anchor(world, wave)
        share_out_speed(world, wave, members, count)
      end
    end
  end
end
-- }}}

-- {{{ function M.side_of_line()
-- Which side of the lane a body stands on: -1, 0 or +1.
--
-- The second thing the formation is asked for, and it belongs here because it is
-- the same geometry. A ranged body with nothing to shoot orbits toward the side it
-- is already on and commits to that direction -- so both sides send their long-reach
-- bodies to the same shoulders and they end up facing each other, which is a fight
-- at the flanks nobody had to write a rule for.
function M.side_of_line(world, id)
  local across = world.soldier.lane_across[id]
  if across > 0 then return 1 end
  if across < 0 then return -1 end
  return 0
end
-- }}}

-- {{{ function M.begin()
function M.begin(world)
  world.formation_scratch = {}
end
-- }}}

-- The numbers other files measure against, exported so that nothing keeps a copy.
-- A tolerance written as a literal in a test is a tolerance that stops matching the
-- thing it was chosen for the first time anybody edits these.
M.RANK_SPACING = RANK_SPACING
M.FILE_SPACING = FILE_SPACING
M.CONTACT_RANGE = CONTACT_RANGE
M.WALKING = WALKING
M.MARCHING = MARCHING
M.SPEED_CEILING = SPEED_CEILING
M.SPEED_FLOOR = SPEED_FLOOR

return M
