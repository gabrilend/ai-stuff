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

-- 038-combat.lua
--
-- Everything between "this soldier swings" and "that soldier is dead."
--
-- ## Damage is buffered, then applied
--
-- Nothing writes to a health value during the attack pass. Attacks write into
-- `pending_damage`, a flat array with one slot per body, cleared at the top of
-- every tick. A separate resolve pass adds the buffer into health and marks
-- anything at or below zero as dying.
--
-- The reason is simultaneity. Two soldiers on their last sliver of health, both
-- off cooldown on the same tick, should both die. If damage were applied
-- immediately, whichever one the loop happened to reach first would win -- and
-- which one that is depends on slot ordering, which depends on which soldier
-- died four minutes ago and freed its slot. That is a real, reproducible,
-- completely unexplainable unfairness, and buffering removes it.
--
-- It also makes the attack pass safe to slice across a pool of workers: every
-- worker writes into distinct slots of a preallocated array and reads nothing
-- another worker is writing.
--
-- ## Kill attribution: there isn't any
--
-- When a body dies, the opposing team is paid. That is the whole rule. The reap
-- pass reads the *dead body's own team* and pays the other one; it never asks
-- what killed it, because it does not need to.
--
-- So there is no last-hit accounting in this game at all. Nothing to steal, and
-- no reason to position a body for a finishing blow. Three consequences worth
-- knowing: nobody can be locked out of the economy by dying badly, teammates
-- have identical incomes, and a team winning lanes earns more and therefore wins
-- harder -- a snowball, by design.

local M = {}

-- A blow never heals, and armour never makes a body literally immune. Immunity
-- in a lane-pusher means a permanent stalemate, which is the exact failure this
-- whole game exists to avoid.
local MINIMUM_DAMAGE = 1

-- {{{ function M.clear_buffers()
-- The top of the tick. Both damage buffers are zeroed before anything writes to
-- them, so a blow can never be applied twice.
function M.clear_buffers(world)
  local pending = world.pending_damage
  for id = 1, world.high_water do
    pending[id] = 0
  end
  local structure_pending = world.pending_structure_damage
  for id = 1, #structure_pending do
    structure_pending[id] = 0
  end
end
-- }}}

-- {{{ function M.strike()
-- One blow landing on a body. The single place a soldier's health is ever
-- reduced, so that the armour arithmetic exists once.
--
-- Abilities, when they exist, come through here too. They are not a parallel
-- damage system -- anything an ability can do to a health value, it does through
-- this buffer, on the same tick boundary, with the same subtraction.
function M.strike(world, target_id, raw)
  local soldier = world.soldier
  local landed = raw - soldier.armour[target_id]
  if landed < MINIMUM_DAMAGE then
    landed = MINIMUM_DAMAGE
  end
  world.pending_damage[target_id] = world.pending_damage[target_id] + landed
end
-- }}}

-- {{{ function M.strike_structure()
-- Stone has no armour and takes full damage, which keeps siege arithmetic simple
-- enough that a player can hold "how many swings is that tower" in their head.
function M.strike_structure(world, structure_id, raw)
  world.pending_structure_damage[structure_id] =
    world.pending_structure_damage[structure_id] + raw
end
-- }}}

-- {{{ function M.attack_pass()
-- Every body whose cooldown has come up and whose target is in reach.
--
-- A body's `damage` already carries whatever its upgrades gave it -- the stamp
-- happens at birth, not here. See the chest, which explains why the modifiers
-- are folded into the body's own fields rather than walked on every swing: the
-- two produce identical numbers, and one of them does the multiplication once
-- per body instead of once per blow.
function M.attack_pass(world)
  local soldier = world.soldier

  for id = 1, world.high_water do
    if soldier.alive[id] == 1 then
      -- Cooldown comes down whatever the body is doing. A body that only ticked
      -- its cooldown while in contact would swing late every time it re-engaged,
      -- and the delay would be invisible and would always favour whoever stood
      -- still.
      if soldier.cooldown[id] > 0 then
        soldier.cooldown[id] = soldier.cooldown[id] - 1
      end

      if soldier.cooldown[id] <= 0 and soldier.state[id] == 3 then
        local target = soldier.target[id]
        if target ~= 0 and soldier.alive[target] == 1 then
          local dx = soldier.x[target] - soldier.x[id]
          local dy = soldier.y[target] - soldier.y[id]
          if dx * dx + dy * dy <= soldier.range[id] ^ 2 then
            -- A frightened body hits softer. Fear is not damage and never was --
            -- it is what the enemy actually does to you, and it is inflicted on
            -- purpose by something that meant to.
            local blow = soldier.damage[id]
            if soldier.fear[id] > 0 then
              blow = blow * world.abilities.FEAR_MULTIPLIER
            end
            M.strike(world, target, blow)
            soldier.cooldown[id] = soldier.cooldown_max[id]
          end
        elseif soldier.target_structure[id] ~= 0 then
          local structure = world.structure[soldier.target_structure[id]]
          if structure.alive == 1 then
            local node = world.map.node[structure.node]
            local dx = node.x - soldier.x[id]
            local dy = node.y - soldier.y[id]
            if dx * dx + dy * dy <= soldier.range[id] ^ 2 then
              M.strike_structure(world, structure.id, soldier.damage[id])
              soldier.cooldown[id] = soldier.cooldown_max[id]
            end
          end
        end
      end
    end
  end
end
-- }}}

-- {{{ function M.resolve_pass()
-- The buffer is added into health. Anything at or below zero enters the dying
-- state; nothing is freed here, because freeing a slot mid-pass would let a
-- later body in the same pass be handed a slot that this pass still refers to.
function M.resolve_pass(world)
  local soldier = world.soldier
  local pending = world.pending_damage

  for id = 1, world.high_water do
    if soldier.alive[id] == 1 and pending[id] > 0 then
      soldier.health[id] = soldier.health[id] - pending[id]
      if soldier.health[id] <= 0 then
        soldier.health[id] = 0
        soldier.state[id] = 5   -- dying
      end
    end
  end

  local structure_pending = world.pending_structure_damage
  for _, structure in ipairs(world.structure) do
    if structure.alive == 1 and structure_pending[structure.id] > 0 then
      structure.health = structure.health - structure_pending[structure.id]
      if structure.health <= 0 then
        structure.health = 0
        -- Marked, not yet processed. Both libraries can reach zero in the same
        -- pass, and that is a draw -- picking a winner by team number would mean
        -- team 1 wins ties forever, which is the kind of invisible asymmetry only
        -- ever discovered by the player it kept losing to.
        structure.falling = true
      end
    end
  end
end
-- }}}

-- {{{ function M.reap_pass()
-- Turns deaths into consequences, then frees the slots.
--
-- Runs on one thread. It mutates shared structures -- wave counters, team chests,
-- the free list -- and it is short.
function M.reap_pass(world)
  local soldier = world.soldier

  -- Bodies first. A body's death decrements exactly one wave's living count;
  -- nothing scans every wave every tick.
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 and soldier.state[id] == 5 then
      local dead_team = soldier.team[id]
      local wave_id = soldier.wave[id]

      world.raise(world, "killed", {
        team    = dead_team,
        flavour = soldier.flavour[id],
        lane    = soldier.lane[id],
        x       = soldier.x[id],
        y       = soldier.y[id],
      })

      -- Every player on the other team is paid, in full, in this body's colour.
      -- Nothing asks what killed it.
      world.commanders.pay_for_kill(world, dead_team, soldier.flavour[id],
                                    soldier.archetype[id], soldier.bounty_colour[id])

      if soldier.flavour[id] == 2 then
        -- A hero is gone, and the resource that bought it is gone with it. There
        -- is no respawn: what a player forms an attachment to is the decision, not
        -- the body.
        world.commanders.hero_died(world, soldier.owner[id])
      end

      if wave_id ~= 0 then
        world.waves.member_died(world, wave_id)
      end

      if soldier.flavour[id] == 3 and soldier.leash_node[id] ~= 0 then
        world.structures.guard_died(world, id)
      end

      world.release(world, id)
    end
  end

  -- Then stone. A felled tower kills its guards, pays three upgrades, and stops
  -- being an obstacle; a felled library ends the match.
  local library_fell = {}
  for _, structure in ipairs(world.structure) do
    if structure.falling then
      structure.falling = nil
      structure.alive = 0
      world.map.node[structure.node].structure = 0

      if structure.kind == 3 then
        library_fell[#library_fell + 1] = structure.team
      else
        world.structures.tower_fell(world, structure)
      end

      world.raise(world, "structure_fell", {
        team = structure.team,
        kind = structure.kind,
        lane = structure.lane,
        id   = structure.id,
      })
    end
  end

  if #library_fell == 1 then
    -- The team that destroyed it wins, and the match ends on this tick. There is
    -- no second objective, no throne behind it, and no comeback after it falls.
    world.winner = (library_fell[1] == 1) and 2 or 1
    world.phase = 5
    world.raise(world, "match_over", {winner = world.winner})
  elseif #library_fell > 1 then
    -- Both fell in the same buffered pass. A draw, recorded as such.
    world.winner = 3
    world.phase = 5
    world.raise(world, "match_over", {winner = 3})
  end
end
-- }}}

return M
