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

-- 036-the-frontline.lua
--
-- Why a wave reads as a wave rather than as a smear.
--
-- **Bodies are flesh and blood and rock and stone, and no two of them ever occupy
-- the same ground.** That is the whole rule in this file and it is enforced in one
-- place: the moment before a body is told where to walk, the destination is checked
-- against every body already standing near it, and moved if it is inside one.
--
-- ## The rule
--
-- A body is about to walk into another body if there is a body within
-- `self.radius + other.radius` of its **waypoint**. If there is, the waypoint snaps
-- to the point on that body's own circle nearest to us, and then moves back toward
-- our own centre by `self.radius`. The body may pick a new waypoint next tick.
--
-- Those two steps land the waypoint exactly `self.radius + other.radius` from the
-- obstacle's centre -- the only distance at which two bodies are touching and not
-- overlapping -- on the side we were approaching from. The near side matters: a body
-- pushed round to the far side of an obstacle would have passed through it to get
-- there, which is the one thing this rule exists to forbid.
--
-- ## What this replaced
--
-- A queue. The old rule asked one question -- would I end this step inside a friendly
-- body ahead of me, in roughly my own file -- and had one answer, *stop short*. It was
-- written for a rank forming up, where stopping is right, and it was wrong everywhere
-- else: one stationary body was an immovable plug, and everything behind it stopped
-- and never went round. A stream of bodies down a lane concertinaed into a stationary
-- column behind whichever one halted first, and two allied formations walking at each
-- other parked nose to nose with a hundred paces of clear road on either side.
--
-- The queue is not missed, because it was never what made a rank. The rank is the
-- formation module handing out places; this only ever stopped bodies standing inside
-- each other, and it now does that without stopping them.
--
-- ## Three things that fall out of it
--
-- **Enemies are obstacles too.** The queue only counted friendly bodies, on the
-- reasoning that an enemy in the way is not an obstacle but a target. Both are true
-- at once. You cannot walk through the enemy either; you stop against him and hit him.
--
-- **A rank compresses under pressure.** Bodies stand at their formation's spacing when
-- nothing is pushing, and can close to touching when something is. The floor is
-- physical rather than chosen, which is why the line thickens where it is being pressed
-- and stays open where it is not.
--
-- **There is no formation-level decision anywhere.** Fifteen bodies each declining to
-- stand inside somebody is a formation flowing round another formation, and it costs
-- one circle test per body per tick. See H16 in the open questions for the two designs
-- this replaced before either was built.

local M = {}

-- {{{ function M.clear_of_bodies()
-- Where a body may actually stand, given where it wants to stand.
--
-- Takes a waypoint in **world** coordinates and returns one that is not inside
-- anybody. Returns the point it was given, unchanged, when nothing is in the way --
-- which is the overwhelmingly common case and costs one grid query.
--
-- The grid query has to be sized for the **largest body standing on the field** rather
-- than for our own, because the body on that ground may be very much larger than the
-- one walking toward it: a soldier three and a half paces across can be standing
-- inside a Golem at thirty-one, and a query sized to the soldier would not find it.
--
-- The largest body *on the field*, not the largest in the catalogue. The grid rebuild
-- takes it every tick while it is already walking every body. Sized from the catalogue
-- it is the Golem's thirty-one for the whole of every match, including the great
-- majority of every match in which no monster exists -- nearly four times the ground to
-- search, per body, per tick, for nothing.
--
-- **The deepest overlap wins, and only one is resolved per call.** A waypoint inside
-- two bodies is moved out of the one it is furthest inside, which may leave it inside
-- the other; the body picks a waypoint again next tick and the second one is dealt
-- with then. Resolving them all at once means iterating to a fixed point that may not
-- exist -- three bodies round a gap one body wide have no answer -- and a body that
-- arrives one tick later is invisible, while a body in an infinite loop is a frozen
-- frame.
function M.clear_of_bodies(world, id, want_x, want_y)
  local soldier = world.soldier
  local mine = soldier.radius[id]
  local reach = mine + world.largest_body

  local worst_id, worst_overlap = 0, 0
  world.targeting.for_each_near(world, want_x, want_y, reach, function(other)
    if other == id or soldier.alive[other] ~= 1 then
      return
    end
    -- Everything solid counts. The old queue only looked at friendly bodies, on the
    -- reasoning that an enemy in the way is a target rather than an obstacle; he is
    -- both, and the half that got dropped is the half that keeps two lines from
    -- sliding through each other.
    local room = mine + soldier.radius[other]
    local dx = want_x - soldier.x[other]
    local dy = want_y - soldier.y[other]
    local gap = math.sqrt(dx * dx + dy * dy)
    local overlap = room - gap
    if overlap > worst_overlap then
      worst_overlap = overlap
      worst_id = other
    end
  end)

  soldier.gave_way[id] = (worst_id == 0) and 0 or 1
  if worst_id == 0 then
    return want_x, want_y
  end

  -- **Out along the line from the obstacle's centre to the ground we were headed for.**
  --
  -- Pushed radially out of him, in other words, rather than back the way we came. The
  -- difference is the difference between a body that slides round a shoulder and a body
  -- that stops dead, and it only shows up when the approach is very slightly off centre
  -- -- which is nearly always.
  --
  -- Measured from **our own** centre instead, the correction runs straight back along
  -- our own path and has no sideways in it at all when we are walking dead at somebody.
  -- That was tried: two formations meeting head-on stopped and never passed, and a
  -- single stationary ally was a plug the file behind him never got round.
  --
  -- This is only safe because the point being checked is **one pace ahead**, not a
  -- destination. A step cannot land on the far side of a body it has not reached, so
  -- pushing it radially out can never put us through him. Asked about a distant
  -- waypoint it could, which is a second reason the rule is about the step.
  local room = mine + soldier.radius[worst_id]
  local ox, oy = soldier.x[worst_id], soldier.y[worst_id]
  local dx = want_x - ox
  local dy = want_y - oy
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance < 0.0001 then
    -- Dead centre on him. Fall back to the direction we came from, which is the only
    -- other one available and is at least never through him.
    dx = soldier.x[id] - ox
    dy = soldier.y[id] - oy
    distance = math.sqrt(dx * dx + dy * dy)
  end

  if distance < 0.0001 then
    -- Two bodies standing on the same point. The rule above should have made this
    -- unreachable, so it is a symptom rather than a case: something placed a body on
    -- top of another one without asking, and the only place that can happen is a
    -- spawn. Raised so it is visible rather than smoothed over, and then pushed apart
    -- along the world's x axis by whichever of the two has the lower slot, which is
    -- an arbitrary direction chosen the same way on every machine -- a random one
    -- would put two machines' worlds into different shapes over a disagreement about
    -- nothing.
    world.raise(world, "bodies_coincide", {id = id, other = worst_id})
    local side = (id < worst_id) and -1 or 1
    return ox + room * side, oy
  end

  return ox + dx / distance * room, oy + dy / distance * room
end
-- }}}

-- {{{ function M.separate_pass()
-- After everybody has moved: anybody still standing inside anybody is pushed out.
--
-- **This is what makes "no two bodies overlap" a fact rather than an intention.** The
-- refusal above is a question about a step, and three things get past it. A cleared step
-- is scaled back afterwards by the body's own speed limit, so it lands short of the
-- circle it was aimed at -- which is to say inside. Only the deepest of several obstacles
-- is resolved per call. And a body that is not moving is never asked at all, so anything
-- standing still inside somebody stays there.
--
-- Each of those produces a small overlap, and small is not the same as none: a body
-- standing inside another body is a picture of a rule that is not working, and a player
-- reads it that way whatever the number is.
--
-- ## Every push is worked out before any is applied
--
-- Pairs resolved one at a time make the answer depend on the order the bodies were
-- visited. Two machines that walked the field differently would end up with different
-- worlds over a disagreement about nothing, and this game reconciles across machines
-- rather than replaying lockstep -- so an order-dependent rule is a divergence generator.
--
-- The displacements therefore accumulate into a buffer and land together at the end of
-- each round.
--
-- ## Rounds are counted, not iterated to a fixed point
--
-- Pushing A out of B can put A into C. Iterating until nobody overlaps is the thing that
-- need not terminate -- three bodies around a gap one body wide have no answer at all --
-- so this runs a fixed small number of rounds and lets whatever is left settle over the
-- following ticks. A body that is a hundredth of a pace inside somebody for one more tick
-- is invisible; a frozen frame is not.
--
-- ## The bigger body gives less ground
--
-- The overlap is split between the two in inverse proportion to their area, so a soldier
-- walking into a Golem moves and the Golem barely does, and two soldiers each give half.
-- Area rather than radius because a body's size is a disc and shoving is about how much
-- of it there is, and the difference is visible: at radii of 3.6 and 31 the soldier gives
-- up ninety-nine percent of the ground either way, but between a soldier and a body half
-- again its size the split is a fifth rather than a third.
-- How close two bodies may come and still be called touching rather than overlapping.
--
-- A millionth of a pace, which is not a tolerance in the sense of "close enough" -- it is
-- the width of the arithmetic. Two bodies pushed to exactly touching land a few parts in
-- ten thousand million either side of exact, half the time inside. Without this the pass
-- finds an overlap of one part in a thousand million million, corrects it, finds it
-- again, and runs its full round count every tick of every match for the rest of time.
-- Measured: it did exactly that, on two hundred and five ticks out of nine hundred.
--
-- A body is drawn at three and a half paces across on a road thirteen hundred paces long.
-- A millionth of a pace is not a pixel; it is not a millionth of a pixel.
local SEPARATION_SLACK = 1e-6
M.SEPARATION_SLACK = SEPARATION_SLACK

-- How many times to go round before giving up for this tick.
--
-- **A ceiling, not a budget.** The pass leaves the moment a round finds nothing to do, so
-- the number costs nothing on the ticks that do not need it -- and nearly every tick does
-- not. Clearing the worst state a whole match reaches, three hundred bodies with sixty
-- seven pairs touching, takes two thousandths of a second at this ceiling and the same
-- two thousandths at fifteen times it.
--
-- It exists because pushing A out of B can put A into C, and iterating until nobody
-- overlaps is the thing that need not terminate -- three bodies around a gap one body
-- wide have no answer at all. Whatever is left when the ceiling is reached settles over
-- the following ticks.
--
-- **A hundred and twenty-eight, and every smaller number that looked right was measured
-- and was not.** A dozen bodies on a short road converge in twenty-four. Three hundred
-- bodies in three lanes of a real match do not: at twenty-four rounds a match ends with
-- sixty-seven pairs touching, and the same state clears completely at a hundred. The
-- shape of the error is what makes it worth a paragraph -- the residue is *small*, a few
-- ten-thousandths of a pace, so every arena scene passed and nothing looked wrong. A
-- number tuned on the small case and never asked about the big one is the whole reason
-- the proving ground exists.
M.SEPARATION_ROUNDS = 128

-- How much further apart than touching two bodies may be and still be gathered as a
-- contact for this sweep.
--
-- A sweep looks at the field once and then relaxes the pairs it found, so a pair that
-- comes into contact during the relaxing -- A pushed out of B and into C -- is only seen
-- if C was already on A's list. Two paces covers a body being shoved about half its own
-- width, which is far more than any *settled* crowd ever moves in one round.
local SEPARATION_MARGIN = 2

-- How many times to look at the field again before giving up for this tick.
--
-- **The margin above is not a bound, and assuming it was is how this pass spent an
-- afternoon making overlaps instead of removing them.** A body placed deep inside a crowd
-- -- a hero bought and dropped onto a wave, which the spawner does -- is seven paces
-- inside somebody, and pushing it out moves it seven paces, straight through a body three
-- paces away that was never on the list because it was further off than the margin. The
-- pass then had no idea it had just created a worse overlap than the one it fixed.
--
-- So the field is looked at again, and the pass only leaves after a **look** that finds
-- nothing overlapping -- never after a push, because a push is exactly the thing that has
-- not been checked yet.
local SEPARATION_SWEEPS = 8

function M.separate_pass(world)
  for _ = 1, SEPARATION_SWEEPS do
    if M.gather_contacts(world) == 0 then
      -- A look that found nobody overlapping. This is the only way out that proves
      -- anything: leaving straight after a push would be leaving on an unchecked state.
      return
    end
    M.relax_contacts(world)
  end
end
-- }}}

-- {{{ function M.gather_contacts()
-- One look at the field: every pair close enough to be worth relaxing, into a flat list.
--
-- Returns how many of those pairs are **actually overlapping**, which is what the caller
-- decides on -- the list is deliberately wider than the overlaps, so its length would say
-- nothing.
--
-- One sweep of the grid, and then arithmetic. An earlier version asked the grid again on
-- every round, which is a hundred grid queries per body per tick, and made a whole match
-- four and a half times slower on its own.
function M.gather_contacts(world)
  local soldier = world.soldier
  local first, second = world.separation_first, world.separation_second
  local found, overlapping = 0, 0

  for id = 1, world.high_water do
    if soldier.alive[id] == 1 then
      local mine = soldier.radius[id]
      -- Sized for the largest body standing on the field rather than for our own, for
      -- the same reason the refusal is: a soldier three and a half paces across can be
      -- inside a Golem at thirty-one, and a query sized to the soldier would not find it.
      local reach = mine + world.largest_body + SEPARATION_MARGIN

      world.targeting.for_each_near(world, soldier.x[id], soldier.y[id], reach,
        function(other)
          -- Each pair is gathered once, by the lower of the two slots, so the push is
          -- computed from one piece of arithmetic rather than from two that have to
          -- agree with each other.
          if other <= id or soldier.alive[other] ~= 1 then
            return
          end
          local room = mine + soldier.radius[other]
          local dx = soldier.x[other] - soldier.x[id]
          local dy = soldier.y[other] - soldier.y[id]
          local distance_squared = dx * dx + dy * dy
          local watch = room + SEPARATION_MARGIN
          if distance_squared < watch * watch then
            found = found + 1
            first[found] = id
            second[found] = other
            -- **The same slack the relaxing uses.** Counted with an exact comparison
            -- instead, a crowd that has just been pushed to exactly touching reads as
            -- still overlapping about half the time -- floating point puts it a few
            -- parts in ten thousand million either side of exact -- so the pass never
            -- saw a clean field and burned its whole sweep ceiling on seven thousand
            -- four hundred ticks out of eight thousand, doing nothing.
            local settled = room - SEPARATION_SLACK
            if distance_squared < settled * settled then
              overlapping = overlapping + 1
            end
          end
        end)
    end
  end

  world.separation_count = found
  return overlapping
end
-- }}}

-- {{{ function M.relax_contacts()
-- Push apart everybody on the gathered list, over and over, until a round finds nothing.
function M.relax_contacts(world)
  local soldier = world.soldier
  local push_x, push_y = world.separation_x, world.separation_y
  local first, second = world.separation_first, world.separation_second
  local found = world.separation_count

  for _ = 1, M.SEPARATION_ROUNDS do
    -- Only the bodies on the list, rather than every slot in the world. A match with four
    -- hundred bodies on the field has two thousand slots, and clearing all of them on
    -- every round is most of a pass spent on nobody.
    for index = 1, found do
      push_x[first[index]] = 0
      push_y[first[index]] = 0
      push_x[second[index]] = 0
      push_y[second[index]] = 0
    end

    local anybody = false
    for index = 1, found do
      local id, other = first[index], second[index]
      local room = soldier.radius[id] + soldier.radius[other]
      local dx = soldier.x[other] - soldier.x[id]
      local dy = soldier.y[other] - soldier.y[id]
      local distance = math.sqrt(dx * dx + dy * dy)
      local overlap = room - distance

      if overlap > SEPARATION_SLACK then
        if distance < 0.0001 then
          -- Two bodies on the same point have no line between their centres to be pushed
          -- apart along. The refusal says this should be unreachable, so it is a symptom
          -- rather than a case -- something placed a body on top of another without
          -- asking -- and it is raised rather than smoothed over. The direction is the
          -- world's x axis, which is arbitrary but is the *same* arbitrary choice on
          -- every machine, and this game reconciles across machines rather than replaying
          -- lockstep.
          world.raise(world, "bodies_coincide", {id = id, other = other})
          dx, dy, distance = 1, 0, 1
        end

        -- Inverse-area shares, summing to one, so a soldier walking into a Golem moves
        -- and the Golem barely does, and two soldiers each give half. Area rather than
        -- radius because a body's size is a disc and shoving is about how much of it
        -- there is.
        --
        -- **Summed across a body's contacts rather than averaged over them.** Averaging
        -- under-corrects a body several neighbours are pushing, and a rank is a chain:
        -- averaging walks a correction down it one link per round, and was measured to
        -- converge several times slower.
        local mass_mine = soldier.radius[id] * soldier.radius[id]
        local mass_other = soldier.radius[other] * soldier.radius[other]
        local share_mine = mass_other / (mass_mine + mass_other)

        local ux, uy = dx / distance, dy / distance
        push_x[id] = push_x[id] - ux * overlap * share_mine
        push_y[id] = push_y[id] - uy * overlap * share_mine
        push_x[other] = push_x[other] + ux * overlap * (1 - share_mine)
        push_y[other] = push_y[other] + uy * overlap * (1 - share_mine)
        anybody = true
      end
    end

    if not anybody then
      return
    end

    -- **Every push is worked out before any is applied.** Resolving pairs one at a time
    -- makes the answer depend on the order the bodies were visited, and two machines that
    -- walked the field differently would end up with different worlds over a disagreement
    -- about nothing.
    for index = 1, found do
      local id = first[index]
      if push_x[id] ~= 0 or push_y[id] ~= 0 then
        world.walking.nudge(world, id, push_x[id], push_y[id])
        push_x[id] = 0
        push_y[id] = 0
      end
      local other = second[index]
      if push_x[other] ~= 0 or push_y[other] ~= 0 then
        world.walking.nudge(world, other, push_x[other], push_y[other])
        push_x[other] = 0
        push_y[other] = 0
      end
    end
  end
end
-- }}}

-- {{{ function M.for_each_candidate()
-- Every living body within `spacing` of this one, itself excluded.
--
-- Not used by the rule above, which queries around a **waypoint** rather than around
-- a body -- the two are different points and the whole rule turns on that. Kept
-- because the proving ground and the invariants both ask "who is standing near this
-- body" and neither of them wants to open the grid to do it.
function M.for_each_candidate(world, id, spacing, visit)
  local targeting = world.targeting
  local soldier = world.soldier
  targeting.for_each_near(world, soldier.x[id], soldier.y[id], spacing,
    function(other)
      if other ~= id and soldier.alive[other] == 1 then
        visit(other)
      end
    end)
end
-- }}}

return M
