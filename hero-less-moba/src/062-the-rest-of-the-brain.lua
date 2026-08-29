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

-- 062-the-rest-of-the-brain.lua
--
-- What a body does that is not walking forward and swinging.
--
-- Everything here is the **soldier brain**, which is still one brain. None of it is a
-- second controller or a special case for a flavour -- it is rules on the common
-- record, which is the constraint that keeps the brain small enough to be good.
--
-- In a game with the heroes subtracted out, that brain is the whole product. There
-- is no second system to distract from a bad one.
--
-- ## The four things
--
-- **Standing off.** A ranged body backs away when an enemy is inside its weapon range
-- but nearer than the maximum, at half speed -- which makes it a tendency rather than
-- a flinch. The intent does most of the work: a ranged body should spend most of its
-- life at the far edge of its own reach. Close enough to shoot, far enough that
-- closing on it costs something. And it is **contestable** -- another ranged body can
-- push into that space and trade at a distance neither is comfortable at, which is
-- the whole reason it is a movement rule rather than a fixed spacing.
--
-- **Orbiting.** A ranged body with nothing to shoot does not stand still and does not
-- walk into the line. It moves laterally, holding its own maximum range, and **which
-- way it goes is not random**: a body already on the left of the fight orbits left,
-- one on the right orbits right, and it commits.
--
-- > Both sides' ranged bodies do this, so they drift toward the same flanks and end
-- > up facing each other.
--
-- Nothing anywhere says *ranged units should fight ranged units*. It falls out of two
-- formations each sending their long-reach bodies wide, and it produces the thing
-- every lane battle should have -- a fight at the shoulders as well as one in the
-- middle, with the flanks resolving on their own timetable while the melee grinds.
--
-- **Falling back.** A body under fire withdraws when its side can spare it, and comes
-- back when its side cannot. Read together those are one rule: **the line pulls its
-- wounded out while it is winning and feeds them back in while it is losing.** Nothing
-- decides that centrally and no player issues it.
--
-- **Healing.** Five archetypes that differ in **shape** rather than in strength, each
-- answering the who-heals-whom problem a different way. That is the design rather
-- than a side effect: the answer to "how do we solve the assignment" is that we do not
-- solve it once.

local M = {}

-- How much of a road's half-width a fanned-out rank spreads across. Not all of it:
-- the very edge is where a flanking body arrives, and a rank pressed against the
-- verge has nowhere to go when one does.
local FANNED_OUT = 0.8

-- How much closer than the enemy's own middle a body pulls when something is close
-- enough to be harassing it, in paces. Small -- this is a rank tightening, not a
-- charge.
local CLOSING_UP = 12

-- Ranged bodies and healers give ground at half speed while engaged. Melee closes at
-- full. That single asymmetry produces most of what a frontline looks like: **a melee
-- body that commits will reach a ranged one** -- eventually, having been shot the
-- whole way -- and the question a player is watching is whether it arrives with
-- anything left.
local GIVING_GROUND = 0.5

-- How far inside its own reach a ranged body is willing to let something get before
-- it starts backing away, as a fraction of that reach.
local COMFORTABLE = 0.72

-- How fast a body orbits, as a fraction of its speed. Slower than walking: an orbit
-- is a body keeping station, not a body going somewhere.
local ORBIT_RATE = 0.55

-- {{{ function M.stand_off()
-- A ranged body giving ground. Returns true if it moved.
--
-- Backing away **along the lane**, which is the direction the enemy is coming from,
-- rather than in world space away from one particular body. A body that fled the
-- nearest individual would be steered by whoever happened to be closest and would
-- wander out of its own formation to escape one soldier.
function M.stand_off(world, id)
  local soldier = world.soldier
  local target = soldier.target[id]
  if soldier.reach[id] ~= 2 or target == 0 or soldier.alive[target] ~= 1 then
    return false
  end
  -- A guard has no lane to give ground down, and would not if it had one.
  if soldier.lane[id] == 0 then
    return false
  end

  local dx = soldier.x[target] - soldier.x[id]
  local dy = soldier.y[target] - soldier.y[id]
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance >= soldier.range[id] * COMFORTABLE then
    return false
  end

  -- Away from the enemy is backwards down my own lane.
  local step = soldier.speed[id] * GIVING_GROUND
  world.walking.move_limited(world, id, -step * soldier.facing[id], 0, step)
  return true
end
-- }}}

-- {{{ function M.orbit()
-- A body with a reach, spreading out or closing up depending on what is in front of
-- it.
--
-- **Two behaviours, and which one is a question about threat rather than about
-- distance.**
--
--   fan out     nothing hostile nearby. The rank behind spreads across the road, so
--               it covers more ground and more of it has an angle on whatever
--               arrives. A block of archers standing on top of each other is a block
--               of archers most of whom cannot see anything.
--   concentrate something is harassing the edges. They close up toward whichever
--               side the threat is on and put their fire in one place, which is what
--               "just enough to disable whatever comes near" means when it is a
--               group doing it rather than one body.
--
-- What this replaces was gated on the *wave* being engaged and picked its side from
-- which half of the road the body already stood on. Both were wrong. The first meant
-- a body only ever moved once its own front rank was in contact, which is exactly too
-- late for a rank whose job is to make contact expensive; the second meant the
-- direction had nothing to do with where the enemy was.
--
-- The direction now comes from **which side of the enemy's mass the body stands on**,
-- and is held for as long as the body stays in the same milestone, so it reads as a
-- decision rather than as dithering.
function M.orbit(world, id)
  local soldier = world.soldier
  if soldier.reach[id] ~= 2 then
    return false
  end

  local lane = world.map.lane[soldier.lane[id]]
  if lane == nil then
    return false
  end

  -- **Only near a fight.** Both behaviours below are about a rank arranging itself
  -- against something; neither is about a rank three hundred paces down an empty
  -- road. Without this gate every archer in the game spreads to the verge the moment
  -- it leaves the library, which is not keeping station -- it is refusing to march,
  -- and it pulls the whole formation apart before it ever meets anybody. Measured:
  -- the line bends by two and a half ranks and the sandbox stops recognising it as a
  -- formation at all.
  --
  -- "Near a fight" is either: this body's own wave has run into something, or there is
  -- something hostile inside its own reach. The first covers the rank behind a line
  -- that is already in contact, which is most of it; the second covers a body being
  -- come at from the side, which is the case the whole concentrating behaviour exists
  -- for and which the wave's own contact check cannot see.
  local wave = world.wave[soldier.wave[id]]
  local engaged = (wave ~= nil and wave.engaged == 1)

  -- Where the enemy is, as one number: the mean position across the road of every
  -- hostile body within this one's acquisition range, and how many there were.
  local sum, seen, nearest = 0, 0, math.huge
  world.targeting.for_each_near(world, soldier.x[id], soldier.y[id],
                                soldier.acquire_range[id], function(other)
    if soldier.alive[other] == 1
       and world.targeting.hostile(soldier.team[id], soldier.team[other]) then
      sum = sum + soldier.lane_across[other]
      seen = seen + 1
      local dx = soldier.x[other] - soldier.x[id]
      local dy = soldier.y[other] - soldier.y[id]
      local distance = math.sqrt(dx * dx + dy * dy)
      if distance < nearest then nearest = distance end
    end
  end)

  if seen == 0 and not engaged then
    return false
  end

  local want
  if seen == 0 then
    -- **Fan out.** Nothing to shoot at, so spread: away from the middle of the road,
    -- on whichever side this body already leans, out to the shoulder. Spreading is a
    -- posture rather than a retreat -- it costs nothing while there is nobody about
    -- and it means whatever does arrive is met by a rank that is already wide.
    local side = soldier.orbit_side[id]
    if side == 0 or soldier.orbit_milestone[id] ~= soldier.milestone[id] then
      side = (soldier.lane_across[id] >= 0) and 1 or -1
      soldier.orbit_side[id] = side
      soldier.orbit_milestone[id] = soldier.milestone[id]
    end
    want = side * lane.width * 0.5 * FANNED_OUT
  else
    -- **Concentrate.** Something is there, so close toward it and put the fire in one
    -- place. The side is the enemy's mean position across the road, held for as long
    -- as this body stays in the same milestone so that a rank does not sway between
    -- two groups.
    local middle = sum / seen
    local side = soldier.orbit_side[id]
    if side == 0 or soldier.orbit_milestone[id] ~= soldier.milestone[id] then
      side = (middle >= 0) and 1 or -1
      soldier.orbit_side[id] = side
      soldier.orbit_milestone[id] = soldier.milestone[id]
    end
    want = middle
    -- Harassed at the edge rather than met head on: closer still, so the fire lands
    -- on the thing that is actually reaching them.
    if nearest < soldier.range[id] then
      want = middle + side * CLOSING_UP
    end
  end

  -- Never off the road. A body that spread without limit would walk out of the fight
  -- it is supposed to be shooting into.
  local edge = lane.width * 0.5
  if want > edge then want = edge elseif want < -edge then want = -edge end

  local gap = want - soldier.lane_across[id]
  if math.abs(gap) < 1 then
    return false
  end

  local step = soldier.speed[id] * ORBIT_RATE
  if gap > step then gap = step elseif gap < -step then gap = -step end
  world.walking.move_limited(world, id, 0, gap, step)
  return true
end
-- }}}

-- {{{ local function health_on_the_ground()
-- How much health each side has standing near a point.
--
-- The measure the fall-back rule turns on, and it is deliberately about **the ground
-- around a body rather than the body itself.** A body that withdrew at the first
-- scratch is a body that spends the match walking; what decides is whether its side
-- can spare it.
local function health_on_the_ground(world, id, radius)
  local soldier = world.soldier
  local team = soldier.team[id]
  local mine, theirs = 0, 0

  world.targeting.for_each_near(world, soldier.x[id], soldier.y[id], radius,
    function(other)
      if soldier.team[other] == team then
        mine = mine + soldier.health[other]
      elseif world.targeting.hostile(team, soldier.team[other]) then
        theirs = theirs + soldier.health[other]
      end
    end)
  return mine, theirs
end
-- }}}

-- {{{ function M.should_fall_back()
-- Whether a body under fire should pull out of the line.
--
-- **It withdraws when its side can spare it**: under fire, and its team has more
-- health nearby than the enemy does. The team is ahead on the ground it is standing
-- on, so it can afford to be one body lighter for a while.
function M.should_fall_back(world, id)
  local soldier = world.soldier

  -- **A guard never falls back.** It is standing on a piece of ground it was told not
  -- to leave, it has no lane to withdraw down, and the place a wounded body goes to
  -- mend is the tower it is already standing at. The whole rule is about a body
  -- leaving a line, and a guard is not in one.
  if soldier.flavour[id] == 3 or soldier.lane[id] == 0 then
    return false
  end

  if soldier.incoming_dps[id] <= 0 then
    return false
  end
  -- Only a body that is actually hurt. Withdrawing at full health is not falling
  -- back, it is refusing to fight.
  if soldier.health[id] > soldier.health_max[id] * 0.5 then
    return false
  end

  local mine, theirs = health_on_the_ground(world, id, soldier.acquire_range[id])
  return mine > theirs
end
-- }}}

-- {{{ function M.should_return()
-- Whether a recovering body should go back in.
--
-- **It returns when its side cannot spare it** -- the frontline has turned and the
-- enemy has more health on it than we do. It is needed now, in whatever condition it
-- is in.
--
-- Read with the rule above, the two are one: the line pulls its wounded out while it
-- is winning and feeds them back in while it is losing, with nobody deciding that
-- centrally, and it produces a frontline that visibly thickens and thins.
function M.should_return(world, id)
  local soldier = world.soldier
  if soldier.health[id] >= soldier.health_max[id] * 0.9 then
    return true
  end
  local mine, theirs = health_on_the_ground(world, id, soldier.acquire_range[id] * 1.6)
  return theirs > mine
end
-- }}}

-- {{{ function M.recover()
-- A body mending. It withdraws down its own lane toward its own stone, and
-- regenerates while it is back there.
--
-- **A tower is not only a thing that shoots** -- it is the place a lane's wounded go,
-- which gives the ground behind it a job it did not have and makes losing one cost
-- more than its arrows.
function M.recover(world, id)
  local soldier = world.soldier
  soldier.target[id] = 0
  soldier.target_structure[id] = 0

  if soldier.lane[id] == 0 then
    -- Nothing to withdraw down. It mends where it stands, which is what a body with
    -- no line to leave would do anyway.
    local rate = world.parameters.unit.recovery.regeneration
    soldier.health[id] = math.min(soldier.health_max[id], soldier.health[id] + rate)
    return
  end

  local rate = world.parameters.unit.recovery.regeneration
  soldier.health[id] = soldier.health[id] + rate
  if soldier.health[id] > soldier.health_max[id] then
    soldier.health[id] = soldier.health_max[id]
  end

  local step = soldier.speed[id] * GIVING_GROUND
  world.walking.move_limited(world, id, -step * soldier.facing[id], 0, step)
end
-- }}}

-- {{{ M.healer
-- Five ways to heal, and they are five different units.
--
-- The archetypes differ in **shape**, not in strength, and each one answers the
-- who-heals-whom problem differently. Read down the table and the matching problem
-- appears and disappears several times: the priest has it fully, the paladin does not
-- have it at all, the druid has it spread over time rather than over bodies, the
-- curse-doctor inverts it by aiming at an enemy, and the shaman resolves it
-- sequentially one bounce at a time.
--
-- **So the answer to "how do we solve the assignment" is that we do not solve it
-- once.** Five units answer it five ways, and the difference between them is what
-- makes them different units rather than five numbers.
M.healer = {

  -- {{{ priest
  -- One target, slowly and powerfully: **the soonest to die.** Has the matching
  -- problem in full -- one target, contested, assignment required.
  priest = function(world, id, ability)
    return M.soonest_to_die(world, id, ability.radius, false)
  end,
  -- }}}

  -- {{{ druid
  -- The soonest to die **among those not already regenerating**. Has the matching
  -- problem spread over time rather than over bodies: many regenerations can be
  -- running at once, built up by applying them one at a time.
  druid = function(world, id, ability)
    return M.soonest_to_die(world, id, ability.radius, true)
  end,
  -- }}}

  -- {{{ paladin
  -- The wounded ally **nearest full health whose gap the heal still fills.** A little
  -- overheal is fine, so a heal of 350 wants a body missing about 400.
  --
  -- The opposite instinct to the priest's -- *spend it where none of it is wasted*
  -- against *spend it where it is needed most* -- and a team fielding both has two
  -- healers who will reliably disagree about who matters.
  paladin = function(world, id, ability)
    local soldier = world.soldier
    local best, best_gap = 0, math.huge
    world.targeting.for_each_near(world, soldier.x[id], soldier.y[id], ability.radius,
      function(other)
        if other ~= id and soldier.team[other] == soldier.team[id] then
          local gap = soldier.health_max[other] - soldier.health[other]
          if gap >= ability.power * 0.85 and gap < best_gap then
            best, best_gap = other, gap
          end
        end
      end)
    return best
  end,
  -- }}}

  -- {{{ curse_doctor
  -- Heals allies **in melee range of a cursed enemy**, which makes its choice a
  -- targeting decision about the other side. The matching problem inverted.
  --
  -- Returns the enemy to curse: whichever has the most of our bodies around it, since
  -- that is where the healing lands.
  curse_doctor = function(world, id, ability)
    local soldier = world.soldier
    local best, best_count = 0, 1
    world.targeting.for_each_near(world, soldier.x[id], soldier.y[id], ability.radius,
      function(enemy)
        if world.targeting.hostile(soldier.team[id], soldier.team[enemy]) then
          local touching = 0
          world.targeting.for_each_near(world, soldier.x[enemy], soldier.y[enemy], 40,
            function(ally)
              if soldier.team[ally] == soldier.team[id]
                 and soldier.health[ally] < soldier.health_max[ally] then
                touching = touching + 1
              end
            end)
          if touching > best_count then
            best, best_count = enemy, touching
          end
        end
      end)
    return best
  end,
  -- }}}

  -- {{{ rain_shaman
  -- A chain, bouncing between allies, each bounce preferring the **farthest wounded
  -- ally that can fully accept the bounce's value.** The matching problem resolved
  -- sequentially, one bounce at a time.
  --
  -- Returns the first link; the effect walks the rest.
  rain_shaman = function(world, id, ability)
    local soldier = world.soldier
    local best, best_distance = 0, -1
    world.targeting.for_each_near(world, soldier.x[id], soldier.y[id], ability.radius,
      function(other)
        if other ~= id and soldier.team[other] == soldier.team[id] then
          local gap = soldier.health_max[other] - soldier.health[other]
          if gap >= ability.power then
            local dx = soldier.x[other] - soldier.x[id]
            local dy = soldier.y[other] - soldier.y[id]
            local distance = dx * dx + dy * dy
            if distance > best_distance then
              best, best_distance = other, distance
            end
          end
        end
      end)
    return best
  end,
  -- }}}
}
-- }}}

-- {{{ function M.soonest_to_die()
-- The ally who will die soonest, which is **not** the ally with the least health.
--
-- Built from the target's current health as an absolute number and the damage per
-- second currently aimed at it. A body at four hundred health with nothing attacking
-- it is fine; a body at four hundred with three enemies on it is next. **Percentage
-- is the wrong measure and absolute health alone is only half of one** -- what a
-- healer is answering is *how long has this one got.*
--
-- And a healer only takes a target nobody else is already healing. That sounds like a
-- courtesy and is not: it is the thing that stops two healers both reaching for the
-- most wounded body in sight while everything else bleeds out beside it.
--
-- **When there are not enough wounded to go round the rule relaxes rather than
-- deadlocking** -- heal whoever has the fewest healers on them. Somebody gets doubled
-- up, which is a waste, but nobody stands idle, and a healer with nothing to do is
-- worse than a healer doing something redundant.
function M.soonest_to_die(world, id, radius, skip_regenerating)
  local soldier = world.soldier
  local claimed = world.healing_claim

  local best, best_time = 0, math.huge
  local fallback, fewest = 0, math.huge

  world.targeting.for_each_near(world, soldier.x[id], soldier.y[id], radius,
    function(other)
      if other == id or soldier.team[other] ~= soldier.team[id] then
        return
      end
      if soldier.health[other] >= soldier.health_max[other] then
        return
      end
      if skip_regenerating and soldier.regenerating[other] > 0 then
        return
      end

      local incoming = soldier.incoming_dps[other]
      local time = (incoming > 0) and (soldier.health[other] / incoming)
                                   or (soldier.health[other] * 10)
      local on_them = claimed[other] or 0

      if on_them == 0 and time < best_time then
        best, best_time = other, time
      end
      if on_them < fewest or (on_them == fewest and time < best_time) then
        fallback, fewest = other, on_them
      end
    end)

  local chosen = (best ~= 0) and best or fallback
  if chosen ~= 0 then
    claimed[chosen] = (claimed[chosen] or 0) + 1
  end
  return chosen
end
-- }}}

-- {{{ function M.begin_tick()
-- Clears the healing claims for this tick.
--
-- Rebuilt every tick rather than maintained, on the same principle as everything else
-- here: a claim that outlived its healer would keep a body permanently un-healable by
-- anybody else, and nothing would ever notice.
function M.begin_tick(world)
  local claimed = world.healing_claim
  for id in pairs(claimed) do
    claimed[id] = nil
  end
end
-- }}}

-- {{{ function M.begin()
function M.begin(world)
  world.healing_claim = {}
end
-- }}}

M.GIVING_GROUND = GIVING_GROUND

return M
