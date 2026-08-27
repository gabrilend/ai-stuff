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

-- 055-abilities.lua
--
-- What a hero does that a wave unit cannot.
--
-- **There is no cast key and no targeting cursor.** An ability fires by itself when
-- its cooldown is ready and its condition is met. A hero is a soldier you paid for
-- and pointed, not a puppet you drive, and that rule is what keeps the soldier
-- brain the only brain in the game -- every piece of manual control that gets added
-- is a behaviour the brain no longer has to be good at, and the end of that road is
-- a game where the soldiers are visibly stupider than the things you drive.
--
-- It also protects the chest. A player's hands are busy placing and arguing; a hero
-- demanding attention would compete directly with the system that replaced heroes
-- in the first place.
--
-- ## Which concentrates everything into the condition
--
-- With nobody able to intervene, a hero's entire personality is **the predicates
-- that decide when its ability fires.** Two heroes with identical stats and
-- different conditions are two genuinely different purchases, and there is nowhere
-- else for the design effort to go.
--
-- So an ability is a **(condition, effect, cooldown) triple assembled from two
-- tables**, and a new hero is usually a new pairing rather than new code.
--
-- ## Not a parallel damage system
--
-- Everything here writes into the same pending-damage buffer an ordinary swing
-- does, resolves on the same tick boundary, and passes through the same armour
-- arithmetic. There is no second way to hurt somebody.

local M = {}

-- {{{ M.condition
-- Each returns the target the effect should be applied to, or 0 for "do not fire".
-- Returning the target rather than a yes/no keeps the search in one place: a
-- condition that has found the right body should not make the effect find it again.
M.condition = {

  -- {{{ enemies_crowded
  -- Three or more enemies close together. The predicate that makes a body worth
  -- buying against a wave rather than against a hero.
  enemies_crowded = function(world, id, ability)
    local soldier = world.soldier
    local count = 0
    world.targeting.for_each_near(world, soldier.x[id], soldier.y[id], ability.radius,
      function(other)
        if world.targeting.hostile(soldier.team[id], soldier.team[other]) then
          count = count + 1
        end
      end)
    -- The caster's own position is the target; the effect sweeps from there.
    if count >= 3 then
      return id
    end
    return 0
  end,
  -- }}}

  -- {{{ structure_in_reach
  -- An enemy structure inside weapon range. A hero that only fires at stone is a
  -- hero a player buys for a specific job on a specific turn.
  structure_in_reach = function(world, id, ability)
    local soldier = world.soldier
    if soldier.target_structure[id] ~= 0
       and world.structure[soldier.target_structure[id]].alive == 1 then
      return soldier.target_structure[id]
    end
    return 0
  end,
  -- }}}

  -- {{{ ally_soonest_to_die
  -- **Not the ally with the least health.** The one that will die soonest, which is
  -- built from its current health *and* the damage per second currently aimed at
  -- it. A body at four hundred health with nothing attacking it is fine; a body at
  -- four hundred with three enemies on it is next.
  --
  -- Percentage is the wrong measure and absolute health alone is only half of one.
  -- What a healer is answering is *how long has this one got.*
  ally_soonest_to_die = function(world, id, ability)
    local soldier = world.soldier
    local best, best_time = 0, math.huge
    world.targeting.for_each_near(world, soldier.x[id], soldier.y[id], ability.radius,
      function(other)
        if other ~= id and soldier.team[other] == soldier.team[id]
           and soldier.health[other] < soldier.health_max[other] then
          local incoming = soldier.incoming_dps[other]
          -- Nothing aimed at it: it has as long as it likes, but it is still a
          -- candidate if nobody more urgent is about. A large finite number rather
          -- than infinity, so the comparison still orders them by health.
          local time = (incoming > 0) and (soldier.health[other] / incoming)
                                       or (soldier.health[other] * 10)
          if time < best_time then
            best, best_time = other, time
          end
        end
      end)
    return best
  end,
  -- }}}

  -- {{{ priest_target
  -- The ally who will die soonest, contested -- nobody else already healing them.
  priest_target = function(world, id, ability)
    return world.rest_of_brain.healer.priest(world, id, ability)
  end,
  -- }}}

  -- {{{ druid_target
  -- The same, **among those not already regenerating** -- the matching problem spread
  -- over time rather than over bodies.
  druid_target = function(world, id, ability)
    return world.rest_of_brain.healer.druid(world, id, ability)
  end,
  -- }}}

  -- {{{ curse_target
  -- An **enemy**, chosen for how many of ours are fighting it. The matching problem
  -- inverted: the choice is about the other side.
  curse_target = function(world, id, ability)
    return world.rest_of_brain.healer.curse_doctor(world, id, ability)
  end,
  -- }}}

  -- {{{ shaman_target
  -- The farthest wounded ally that can fully accept the bounce. Resolved
  -- sequentially, one link at a time.
  shaman_target = function(world, id, ability)
    return world.rest_of_brain.healer.rain_shaman(world, id, ability)
  end,
  -- }}}

  -- {{{ allies_hurt_nearby
  -- Two or more wounded allies close by. Fires on the state of the line rather than
  -- on the caster's own state, which is the difference between a body that props up
  -- a fight and one that saves itself.
  allies_hurt_nearby = function(world, id, ability)
    local soldier = world.soldier
    local count = 0
    world.targeting.for_each_near(world, soldier.x[id], soldier.y[id], ability.radius,
      function(other)
        if soldier.team[other] == soldier.team[id]
           and soldier.health[other] < soldier.health_max[other] * 0.7 then
          count = count + 1
        end
      end)
    if count >= 2 then
      return id
    end
    return 0
  end,
  -- }}}
}
-- }}}

-- {{{ M.effect
M.effect = {

  -- {{{ splash
  -- Damage to every enemy in the radius, through the ordinary buffer and the
  -- ordinary armour arithmetic.
  splash = function(world, id, target, ability)
    local soldier = world.soldier
    local hit = 0
    world.targeting.for_each_near(world, soldier.x[id], soldier.y[id], ability.radius,
      function(other)
        if world.targeting.hostile(soldier.team[id], soldier.team[other]) then
          world.combat.strike(world, other, ability.power)
          hit = hit + 1
        end
      end)
    return hit
  end,
  -- }}}

  -- {{{ breach
  -- Stone takes full damage and has no armour, which keeps siege arithmetic
  -- something a player can hold in their head.
  breach = function(world, id, target, ability)
    world.combat.strike_structure(world, target, ability.power)
    return 1
  end,
  -- }}}

  -- {{{ heal
  -- One ally, mended. Health is clamped at its maximum rather than allowed to
  -- overshoot, so a heal into a nearly-full body is partly wasted -- which is what
  -- makes *whose gap does this fit* a different instinct from *who is worst off*.
  heal = function(world, id, target, ability)
    local soldier = world.soldier
    soldier.health[target] = soldier.health[target] + ability.power
    if soldier.health[target] > soldier.health_max[target] then
      soldier.health[target] = soldier.health_max[target]
    end
    return 1
  end,
  -- }}}

  -- {{{ shield
  -- Mends everything close by, a little. The area version of a heal, and it needs
  -- no selection at all -- which is precisely why the hero that has it is a
  -- different unit from the one that mends a single body well.
  shield = function(world, id, target, ability)
    local soldier = world.soldier
    local mended = 0
    world.targeting.for_each_near(world, soldier.x[id], soldier.y[id], ability.radius,
      function(other)
        if soldier.team[other] == soldier.team[id] then
          soldier.health[other] = soldier.health[other] + ability.power
          if soldier.health[other] > soldier.health_max[other] then
            soldier.health[other] = soldier.health_max[other]
          end
          mended = mended + 1
        end
      end)
    return mended
  end,
  -- }}}

  -- {{{ regenerate
  -- A heal that **runs** rather than one that lands, which is what lets a druid have
  -- many going at once and build them up one at a time.
  regenerate = function(world, id, target, ability)
    local soldier = world.soldier
    soldier.regenerating[target] = ability.duration
    soldier.regen_rate[target] = ability.power / 30
    return 1
  end,
  -- }}}

  -- {{{ curse
  -- Marks an enemy. While it is marked, everything of ours in melee range of it is
  -- mended -- so the healing follows the fighting rather than being aimed at it.
  curse = function(world, id, target, ability)
    world.soldier.cursed[target] = ability.duration
    return 1
  end,
  -- }}}

  -- {{{ chain
  -- A bounce, and then another, each one to the **farthest** wounded ally that can
  -- take the whole value -- so a chain reaches across a line rather than pooling on
  -- whoever is nearest.
  chain = function(world, id, target, ability)
    local soldier = world.soldier
    local at = target
    local healed = 0
    local already = {[id] = true}

    for _ = 1, ability.bounces do
      if at == 0 or already[at] then
        break
      end
      already[at] = true
      soldier.health[at] = soldier.health[at] + ability.power
      if soldier.health[at] > soldier.health_max[at] then
        soldier.health[at] = soldier.health_max[at]
      end
      healed = healed + 1

      local next_link, farthest = 0, -1
      world.targeting.for_each_near(world, soldier.x[at], soldier.y[at], ability.radius,
        function(other)
          if not already[other] and soldier.team[other] == soldier.team[id]
             and soldier.health_max[other] - soldier.health[other] >= ability.power then
            local dx = soldier.x[other] - soldier.x[at]
            local dy = soldier.y[other] - soldier.y[at]
            local distance = dx * dx + dy * dy
            if distance > farthest then
              next_link, farthest = other, distance
            end
          end
        end)
      at = next_link
    end
    return healed
  end,
  -- }}}

  -- {{{ wither
  -- Fear, inflicted. Not damage -- a frightened body **hits softer** for a while,
  -- which is the enemy's actual weapon rather than a second way of doing the same
  -- thing swords already do.
  --
  -- It lands on a crowd because that is what fear is worst in, and the statue that
  -- emits it is definitely slayable: you just have to have a stronger spirit.
  wither = function(world, id, target, ability)
    local soldier = world.soldier
    local frightened = 0
    world.targeting.for_each_near(world, soldier.x[id], soldier.y[id], ability.radius,
      function(other)
        if world.targeting.hostile(soldier.team[id], soldier.team[other]) then
          soldier.fear[other] = ability.power * 10
          frightened = frightened + 1
        end
      end)
    return frightened
  end,
  -- }}}
}
-- }}}

-- How hard fear bites. A frightened body swings at this fraction of its damage.
M.FEAR_MULTIPLIER = 0.62

-- {{{ function M.run()
-- Every hero whose cooldown is ready and whose condition is met.
function M.run(world)
  local soldier = world.soldier
  local catalogue = world.parameters.commander.ability

  -- Nobody is claimed yet this tick. Rebuilt rather than maintained: a claim that
  -- outlived its healer would leave a body permanently un-healable by anybody else,
  -- and nothing would ever notice.
  world.rest_of_brain.begin_tick(world)

  for id = 1, world.high_water do
    if soldier.alive[id] == 1 then
      if soldier.fear[id] > 0 then
        soldier.fear[id] = soldier.fear[id] - 1
      end
      if soldier.cursed[id] > 0 then
        soldier.cursed[id] = soldier.cursed[id] - 1
      end
      if soldier.regenerating[id] > 0 then
        soldier.regenerating[id] = soldier.regenerating[id] - 1
        soldier.health[id] = soldier.health[id] + soldier.regen_rate[id]
        if soldier.health[id] > soldier.health_max[id] then
          soldier.health[id] = soldier.health_max[id]
        end
      end
      -- A cursed enemy mends whoever is fighting it. The one heal in the game that
      -- is not aimed at an ally at all.
      if soldier.cursed[id] > 0 then
        world.targeting.for_each_near(world, soldier.x[id], soldier.y[id], 40,
          function(other)
            if world.targeting.hostile(soldier.team[id], soldier.team[other]) then
              soldier.health[other] = soldier.health[other] + 0.25
              if soldier.health[other] > soldier.health_max[other] then
                soldier.health[other] = soldier.health_max[other]
              end
            end
          end)
      end
      if soldier.ability_cooldown[id] > 0 then
        soldier.ability_cooldown[id] = soldier.ability_cooldown[id] - 1
      end

      if soldier.flavour[id] == 2 and soldier.ability_cooldown[id] <= 0 then
        local row = world.parameters.unit.archetype[soldier.archetype[id]]
        if row.ability ~= nil then
          for _, name in ipairs(row.ability) do
            local ability = catalogue[name]
            if ability == nil then
              error("hero '" .. row.name .. "' names ability '" .. name ..
                    "', which has no row in the catalogue")
            end
            local condition = M.condition[ability.condition]
            if condition == nil then
              error("ability '" .. name .. "' names condition '" ..
                    ability.condition .. "', which does not exist")
            end
            local target = condition(world, id, ability)
            if target ~= 0 then
              M.effect[ability.effect](world, id, target, ability)
              soldier.ability_cooldown[id] = ability.cooldown
              world.raise(world, "ability", {
                id = id, team = soldier.team[id], name = name,
                x = soldier.x[id], y = soldier.y[id], radius = ability.radius or 0,
              })
              break
            end
          end
        end
      end
    end
  end
end
-- }}}

return M
