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
-- so a wave looks like it is walking down a road rather than scraping both verges.
local WIDTH_USE = 0.78

-- How hard a body out of place corrects, and the span over which the correction
-- reaches full strength. Gain is unitless; scale is in paces.
local COHESION_GAIN = 0.9
local COHESION_SCALE = 34

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

-- The most and least a body's speed may be scaled to. A straggler that could
-- sprint would catch up in a way that reads as teleporting; a leader that could
-- stop dead would be overtaken by its own second rank.
local SPEED_CEILING = 1.55
local SPEED_FLOOR = 0.55

-- How fast a body slides sideways toward its file, as a fraction of its speed.
-- Lower than one, so correcting laterally costs forward progress and a wave that
-- has been bent by a turn visibly takes a moment to straighten.
local LATERAL_RATE = 0.55

-- How much clear ground between two formations standing abreast. Small: enough that
-- they read as two lines rather than one wide one, and no more.
local ABREAST_GAP = 6

-- The most bodies that ever stand abreast, however wide the road is.
--
-- Without a cap this is circular in a way that cannot be solved by widening
-- anything: the centre lane is wide so that three formations fit abreast during a
-- challenge, but a wider lane makes the centre's own formation wider, which pushes
-- the other two further out, which needs a wider lane. Every attempt to make the
-- corridor contain them made them bigger.
--
-- So a rank stops growing at some point and a lane wider than that is simply
-- **room**. Which is the right relationship anyway: a road twice as wide does not
-- make an army twice as broad, it makes it comfortable.
local MAX_FILES = 5

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
  local files = math.floor((lane.width * WIDTH_USE) / FILE_SPACING)
  if files < 2 then files = 2 end
  if files > MAX_FILES then files = MAX_FILES end
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

  local rank, file
  if role == "front" then
    rank = math.floor(role_index / files)
    file = role_index % files
  else
    -- Ranged start behind however many ranks the melee will occupy, plus a gap so
    -- they are shooting over the line rather than standing in the back of it.
    local melee_ranks = math.ceil(melee_total / files)
    rank = melee_ranks + 1 + math.floor(role_index / files)
    file = role_index % files
  end

  soldier.slot_along[id] = -rank * RANK_SPACING
  soldier.slot_across[id] = M.file_offset(files, file)
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
  return wave.anchor + soldier.slot_along[id] * soldier.facing[id],
         soldier.slot_across[id] + (wave.across_offset or 0)
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

  -- A wave advances at its slowest member's pace, so it does not walk away from
  -- its own rear rank. The captain is the slowest body in a wave, which is why a
  -- wave moves at a captain's speed whether or not its captain is still alive --
  -- a wave that sped up when its captain died would be a wave rewarded for losing
  -- the most valuable thing in it.
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

  local handed_out = 0
  for index = 1, count do
    local id = members[index]
    local deviation = wave.lag_of[id] - mean
    local scale = 1 + COHESION_GAIN * (deviation / COHESION_SCALE)
    if scale > SPEED_CEILING then scale = SPEED_CEILING end
    if scale < SPEED_FLOOR then scale = SPEED_FLOOR end
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

M.RANK_SPACING = RANK_SPACING
M.FILE_SPACING = FILE_SPACING
M.CONTACT_RANGE = CONTACT_RANGE

return M
