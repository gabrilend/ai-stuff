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

-- 041-the-chest.lua
--
-- The shared upgrade pool: the deck both teams draw from, the slots upgrades sit
-- in, and the stamp a body takes at birth.
--
-- ## Everything is stamped, nothing is read through a reference
--
-- Every body's modifiers are a copy it owns. Nothing in the swing path
-- dereferences a lane, a tower, or a team record to find out how strong a body
-- is -- the numbers are in the body's own slot, already multiplied out.
--
-- That is a performance argument and a correctness argument at once. There is no
-- such thing as a stale reference to a slot that moved, because nothing holds a
-- reference to a slot.
--
-- **The modifiers are folded into the body's fields rather than walked on every
-- swing.** The documents describe the swing path walking the count vector and
-- applying each entry; folding at stamp time produces identical numbers and does
-- the multiplication once per body instead of once per blow. The two are
-- equivalent because a wave unit's vector never changes after birth and a guard's
-- only changes when its tower does -- which is precisely when it is re-stamped.
--
-- ## Clear, then re-stamp
--
-- When the thing a body copied from changes, the body is cleared and rebuilt from
-- scratch. Not patched -- cleared. A rebuild from the current truth cannot drift;
-- an incremental adjustment can, and will, in the direction nobody tests.
--
-- Three moments trigger a sweep, and only three: an upgrade arrives at or leaves a
-- lane's towers (every guard in that lane), a boon is chosen (every living body
-- that team owns), and a body spawns (that body).
--
-- **Wave units are never swept**, and that is not an oversight -- it is the rule
-- that makes the whole chest worth arguing about. A body that walks away from its
-- lane and dies somewhere else keeps what it was born with. A guard that stands
-- at its tower for its whole life does not, because a guard whose tower has
-- changed and whose numbers have not is a visible lie: the player can see the
-- upgrade sitting in the slot and the body standing under it, not benefiting.

local M = {}

-- {{{ function M.build_deck()
-- The one shared upgrade sequence, generated once at match start.
--
-- Shared, so that what the enemy holds is knowable in aggregate -- the fog in
-- this game is not about *what* they have, it is about *where they put it*, and
-- you learn that by looking at what walks at you. There is no fog-of-war system
-- to build; there is only something not to accidentally reveal.
function M.build_deck(world)
  local kinds = world.parameters.upgrade.kind
  local copies = world.parameters.upgrade.deck.copies_per_kind

  local deck = {}
  for kind = 1, #kinds do
    for _ = 1, copies do
      deck[#deck + 1] = kind
    end
  end
  world.stream.deck:shuffle(deck)
  world.deck = deck
end
-- }}}

-- {{{ function M.draw()
-- Takes `count` upgrades off the deck into a team's chest.
--
-- Each team keeps its own index into the shared sequence, so both teams see the
-- same order of cards but at their own pace. A team that is killing more is
-- further down the deck, not drawing from a different one.
function M.draw(world, team_id, count)
  local team = world.team[team_id]
  local deck = world.deck

  for _ = 1, count do
    team.deck_index = team.deck_index + 1
    -- Wrapping rather than running out. A long match can draw more cards than
    -- the deck holds, and the alternative -- refusing to pay a team that earned
    -- a draw -- would silently switch the economy off in exactly the matches
    -- where it matters most.
    local position = ((team.deck_index - 1) % #deck) + 1
    local kind = deck[position]
    team.chest[kind] = team.chest[kind] + 1
    team.draws_taken = team.draws_taken + 1

    world.raise(world, "drew", {team = team_id, kind = kind})
  end
end
-- }}}

-- {{{ local function reaches()
-- Whether an upgrade kind touches a body of this reach.
--
-- A lane's upgrades only reach the half of a wave they match, which is what makes
-- placing into a lane a decision about *composition* and not only about quantity.
local function reaches(kind_row, body_reach)
  return kind_row.reaches == 3 or kind_row.reaches == body_reach
end
-- }}}

-- {{{ function M.apply_counts()
-- Folds a count vector into a body's fields. Additive terms first, then
-- multiplicative -- fixed across the whole game, so that two teams holding the
-- same upgrades in a different order arrive at the same numbers.
--
-- Called on a body whose fields have just been reset to its archetype row, never
-- on one that already carries a stamp. Applying twice would compound, and the
-- symptom would be a body that got stronger every time somebody touched a slot.
function M.apply_counts(world, id, counts)
  local soldier = world.soldier
  local kinds = world.parameters.upgrade.kind
  local body_reach = soldier.reach[id]

  for kind = 1, #kinds do
    local held = counts[kind]
    if held > 0 then
      local row = kinds[kind]
      if reaches(row, body_reach) then
        soldier.upgrade_count[kind][id] = held

        local add = row.add
        if add.health        then soldier.health_max[id] = soldier.health_max[id] + add.health * held end
        if add.damage        then soldier.damage[id]     = soldier.damage[id]     + add.damage * held end
        if add.armour        then soldier.armour[id]     = soldier.armour[id]     + add.armour * held end
        if add.range         then soldier.range[id]      = soldier.range[id]      + add.range * held end
        if add.acquire_range then soldier.acquire_range[id] = soldier.acquire_range[id] + add.acquire_range * held end
        if add.speed         then soldier.speed[id]      = soldier.speed[id]      + add.speed * held end
      end
    end
  end

  -- The multiplicative half, in its own loop so the ordering is structural rather
  -- than a convention somebody has to remember.
  for kind = 1, #kinds do
    local held = counts[kind]
    if held > 0 then
      local row = kinds[kind]
      if reaches(row, body_reach) then
        local mul = row.mul
        if mul.health then soldier.health_max[id] = soldier.health_max[id] * mul.health ^ held end
        if mul.damage then soldier.damage[id]     = soldier.damage[id]     * mul.damage ^ held end
        if mul.cooldown_max then
          soldier.cooldown_max[id] = soldier.cooldown_max[id] * mul.cooldown_max ^ held
          -- A cooldown is a whole number of ticks, always. Rounding here rather
          -- than letting a fractional cooldown exist keeps every duration in the
          -- game an integer, which is the property two machines have to agree on.
          soldier.cooldown_max[id] = math.floor(soldier.cooldown_max[id] + 0.5)
          if soldier.cooldown_max[id] < 1 then
            soldier.cooldown_max[id] = 1
          end
        end
      end
    end
  end
end
-- }}}

-- {{{ function M.stamp_from_lane()
-- A wave body takes its lane's upgrades at birth, and keeps them until it dies.
function M.stamp_from_lane(world, id, team_id, lane_id)
  local soldier = world.soldier
  M.apply_counts(world, id, world.team[team_id].lane_slot[lane_id])
  soldier.health[id] = soldier.health_max[id]
  soldier.cooldown[id] = soldier.cooldown_max[id]
end
-- }}}

-- {{{ function M.stone_counts()
-- What a given piece of stone currently holds.
--
-- A lane tower holds its own lane's slot. A base tower holds **every lane's**
-- slot plus the library's -- which is what makes a stone investment survive
-- losing the lane it was made in. A team that invested in stone and then lost all
-- six lane towers still has three fully upgraded base towers, because the base
-- was inheriting those upgrades the whole time.
--
-- That is not a comeback mechanic and does not reward losing. It means an
-- investment made while winning is still working while losing, which is what
-- makes defending a base something other than a formality.
function M.stone_counts(world, structure)
  local team = world.team[structure.team]
  local kind_count = #world.parameters.upgrade.kind
  local counts = {}
  for kind = 1, kind_count do
    counts[kind] = 0
  end

  if structure.kind == 1 then
    -- A lane tower: only its own lane's stone.
    for kind = 1, kind_count do
      counts[kind] = team.tower_slot[structure.lane][kind]
    end
  elseif structure.kind == 2 then
    -- A base tower: every lane's stone, and the library slot on top.
    for lane = 1, world.parameters.lane_count do
      for kind = 1, kind_count do
        counts[kind] = counts[kind] + team.tower_slot[lane][kind]
      end
    end
    for kind = 1, kind_count do
      counts[kind] = counts[kind] + team.library_slot[kind]
    end
  end

  return counts
end
-- }}}

-- {{{ function M.restamp_stone()
-- Rebuilds one lane's towers and every guard standing at them.
--
-- Called whenever a lane's stone slot changes, and whenever the library slot
-- does -- in which case every lane is rebuilt, because the base towers inherit
-- from all of them.
function M.restamp_stone(world, team_id, lane_id)
  local tower_row = world.parameters.structure.tower
  local kinds = world.parameters.upgrade.kind

  for _, structure in ipairs(world.structure) do
    -- Base towers are rebuilt on any lane's change, because they inherit every
    -- lane. Lane towers only care about their own.
    local mine = structure.team == team_id
                 and (structure.kind == 2 or structure.lane == lane_id)
    if mine and structure.kind ~= 3 then
      local counts = M.stone_counts(world, structure)

      -- The wound is kept while the numbers are rebuilt. "Cleared and re-stamped"
      -- is about the modifier vector, not about the damage a tower has already
      -- taken -- a tower that healed itself every time somebody moved an upgrade
      -- would make stone unkillable by fiddling.
      local fraction = structure.health / structure.health_max

      structure.damage       = tower_row.damage
      structure.range        = tower_row.range
      structure.cooldown_max = tower_row.cooldown_max
      structure.guard_cap    = tower_row.guard_cap
      structure.health_max   = tower_row.health

      for kind = 1, #kinds do
        local held = counts[kind]
        structure.upgrade_count[kind] = held
        if held > 0 then
          local effect = kinds[kind].tower
          if effect.damage       then structure.damage = structure.damage + effect.damage * held end
          if effect.range        then structure.range  = structure.range  + effect.range * held end
          if effect.health       then structure.health_max = structure.health_max + effect.health * held end
          if effect.guard_cap    then structure.guard_cap = structure.guard_cap + effect.guard_cap * held end
        end
      end
      for kind = 1, #kinds do
        local held = counts[kind]
        if held > 0 then
          local effect = kinds[kind].tower
          if effect.damage_mul   then structure.damage = structure.damage * effect.damage_mul ^ held end
          if effect.cooldown_max then
            structure.cooldown_max = math.floor(structure.cooldown_max * effect.cooldown_max ^ held + 0.5)
            if structure.cooldown_max < 1 then structure.cooldown_max = 1 end
          end
        end
      end

      structure.health = structure.health_max * fraction
    end
  end

  -- Then the bodies standing under them.
  local soldier = world.soldier
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 and soldier.flavour[id] == 3
       and soldier.team[id] == team_id then
      local tower = world.structure[soldier.guard_of[id]]
      if tower ~= nil and (tower.kind == 2 or tower.lane == lane_id) then
        M.restamp_guard(world, id, tower)
      end
    end
  end
end
-- }}}

-- {{{ function M.restamp_guard()
-- Clears one guard's vector and rebuilds it from what its tower currently holds.
--
-- Note the split the documents insist on: a guard is swept and a wave unit is
-- not. From either side the other looks like a bug, so it is worth saying why
-- once more here -- a wave unit walks away from its lane and dies somewhere else,
-- so what it was born with is a fact about its birth; a guard stands at the thing
-- it copied from for its entire life.
function M.restamp_guard(world, id, tower)
  local soldier = world.soldier
  local row = world.parameters.unit.archetype[soldier.archetype[id]]
  local fraction = soldier.health[id] / soldier.health_max[id]

  -- Cleared. Every modifier is dropped and the body goes back to its catalogue
  -- values before anything is applied, so no stamp can ever compound on itself.
  for kind = 1, #soldier.upgrade_count do
    soldier.upgrade_count[kind][id] = 0
  end
  local keep_state = soldier.state[id]
  world.give_body(world, id, row)
  soldier.state[id] = keep_state

  M.apply_counts(world, id, M.stone_counts(world, tower))
  soldier.health[id] = soldier.health_max[id] * fraction
end
-- }}}

-- {{{ function M.stamp_from_stone()
-- A guard takes its tower's upgrades at birth, the same way a wave unit takes its
-- lane's.
function M.stamp_from_stone(world, id, tower)
  local soldier = world.soldier
  M.apply_counts(world, id, M.stone_counts(world, tower))
  soldier.health[id] = soldier.health_max[id]
  soldier.cooldown[id] = soldier.cooldown_max[id]
end
-- }}}

-- {{{ function M.total_held()
-- How many upgrades a team owns in total, wherever they are sitting. Read by the
-- panel and by the post-match report; nothing in the simulation consults it.
function M.total_held(world, team_id)
  local team = world.team[team_id]
  local kind_count = #world.parameters.upgrade.kind
  local in_chest, in_lanes, in_stone = 0, 0, 0
  for kind = 1, kind_count do
    in_chest = in_chest + team.chest[kind]
    in_stone = in_stone + team.library_slot[kind]
    for lane = 1, world.parameters.lane_count do
      in_lanes = in_lanes + team.lane_slot[lane][kind]
      in_stone = in_stone + team.tower_slot[lane][kind]
    end
  end
  return in_chest, in_lanes, in_stone
end
-- }}}

return M
