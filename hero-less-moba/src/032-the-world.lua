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

-- 032-the-world.lua
--
-- The world is one table of flat arrays, not an array of tables. Every soldier's
-- health lives in one contiguous array, every soldier's lane in another.
--
-- Two reasons, and the second is the one people forget. The usual one: the move
-- pass touches four fields out of thirty and should not drag the other
-- twenty-six through the cache. The specific one: slicing a flat array across a
-- pool of workers is a pair of integer bounds, and slicing an array of tables is
-- a pointer chase.
--
-- The map is the exception and is an array of structs, because it is built once,
-- never written to again, and read by name rather than swept in bulk.
--
-- **Nil is not an option anywhere in here.** Every array is filled to capacity at
-- creation with the integer zero. A field that might be empty holds zero, which
-- is a sentinel with a meaning; nil would be a question about whether some
-- earlier code did its job, and that question belongs to the map validator at
-- load time, not to a loop running a thousand times a tick.


local M = {}

-- Soldier states. The state field indexes a dispatch table of behaviour
-- functions; these names exist so that no other file writes the bare integer.
M.STATE_WALKING    = 1
M.STATE_CLOSING    = 2
M.STATE_FIGHTING   = 3
M.STATE_LEASHING   = 4
M.STATE_DYING      = 5
M.STATE_WAITING    = 6
M.STATE_RECOVERING = 7

-- Flavours. One body record, four kinds of thing in it.
M.FLAVOUR_WAVE    = 1
M.FLAVOUR_HERO    = 2
M.FLAVOUR_GUARD   = 3
M.FLAVOUR_MONSTER = 4

-- Match phases.
M.PHASE_NORMAL = 1
M.PHASE_SURGE  = 2
M.PHASE_CHALLENGE = 3
M.PHASE_CALM   = 4
M.PHASE_OVER   = 5

-- How many soldier slots are allocated. A hard ceiling rather than a growing
-- array, because a reallocation mid-match would move every array and any worker
-- holding a slice of one would be reading freed memory. Running out is an error
-- that names itself, not a silent stall.
M.SOLDIER_CAPACITY = 2048

-- {{{ local function zeroed()
-- An array of `count` zeros. Written once here so that every array in the world
-- is born the same way and there is no chance of one being left sparse.
local function zeroed(count)
  local array = {}
  for index = 1, count do
    array[index] = 0
  end
  return array
end
-- }}}

-- {{{ local function empty_counts()
-- One integer per upgrade kind, all zero. This is the shape of a chest, a slot,
-- and the per-kind stamp on a body -- all three are the same thing counted in
-- different places, which is why they share a constructor.
local function empty_counts(kind_count)
  local counts = {}
  for kind = 1, kind_count do
    counts[kind] = 0
  end
  return counts
end
-- }}}

M.empty_counts = empty_counts

-- {{{ local function make_soldier_arrays()
-- Every per-soldier field, as its own flat array of capacity length.
--
-- The grouping below is how the fields cluster in the tick, which is also how
-- they cluster in memory: identity, then place, then body, then mind.
local function make_soldier_arrays(capacity, kind_count)
  local soldier = {}

  -- Identity
  soldier.alive         = zeroed(capacity)
  -- Bumped each time a slot is reused, so a stale id can be detected instead of
  -- silently pointing at a stranger who moved in after the original died.
  soldier.generation    = zeroed(capacity)
  soldier.team          = zeroed(capacity)
  soldier.flavour       = zeroed(capacity)
  soldier.owner         = zeroed(capacity)
  soldier.archetype     = zeroed(capacity)
  soldier.wave          = zeroed(capacity)
  soldier.assigned_team = zeroed(capacity)

  -- Place
  soldier.lane      = zeroed(capacity)
  soldier.node_from = zeroed(capacity)
  soldier.node_to   = zeroed(capacity)
  -- Where node_from sits in this lane's path array. Carried on the body rather
  -- than searched for, because the alternative is scanning the lane's path every
  -- time a body crosses a node -- which is a linear scan per arrival, per body,
  -- forever. A body walking free of a lane (a guard on patrol) holds zero here
  -- and is moved by its neighbour list instead.
  soldier.path_index = zeroed(capacity)
  soldier.progress  = zeroed(capacity)
  soldier.x         = zeroed(capacity)
  soldier.y         = zeroed(capacity)
  soldier.facing    = zeroed(capacity)
  soldier.milestone = zeroed(capacity)

  -- Body
  soldier.health        = zeroed(capacity)
  soldier.health_max    = zeroed(capacity)
  soldier.damage        = zeroed(capacity)
  soldier.armour        = zeroed(capacity)
  soldier.range         = zeroed(capacity)
  soldier.acquire_range = zeroed(capacity)
  soldier.speed         = zeroed(capacity)
  soldier.cooldown      = zeroed(capacity)
  soldier.cooldown_max  = zeroed(capacity)
  -- 1 melee, 2 ranged. Read by the frontline queue and nowhere else, but read
  -- there every tick for every body, so it lives on the body rather than being
  -- looked up through the archetype row.
  soldier.reach         = zeroed(capacity)

  -- Mind
  soldier.state             = zeroed(capacity)
  soldier.incoming_dps      = zeroed(capacity)
  soldier.target            = zeroed(capacity)
  soldier.target_generation = zeroed(capacity)
  soldier.target_structure  = zeroed(capacity)
  soldier.leash_node        = zeroed(capacity)
  -- Where a guard has decided to wander to, as a node id. Zero means it has not
  -- picked anywhere and will pick this tick.
  soldier.wander_node       = zeroed(capacity)
  -- Which tower this body is a guard of. Zero for everything that is not a
  -- guard. Read by the re-stamp sweep, which has to find every body standing
  -- under a tower whose slot just changed.
  soldier.guard_of          = zeroed(capacity)
  -- **Where a body on a lane actually is**, in lane coordinates: how far along the
  -- lane it has got, and how far to one side of the lane's centre it stands.
  --
  -- These two are authoritative and x, y are derived from them. That is what makes
  -- a rank stay a rank around a corner -- every body in it shares one distance
  -- along, and the lane's own curve carries the whole line round together. Holding
  -- the formation in world coordinates instead would make a turning rank either
  -- break apart or scythe through the inside of the bend.
  --
  -- A guard has no lane and does not use these; it walks the graph directly.
  soldier.lane_along        = zeroed(capacity)
  soldier.lane_across       = zeroed(capacity)
  -- This body's place in its wave's formation, as offsets from the wave's anchor.
  -- Assigned once, at birth, and kept for life -- a body's place in the line is not
  -- something that gets reshuffled while it marches.
  soldier.slot_along        = zeroed(capacity)
  soldier.slot_across       = zeroed(capacity)
  -- This tick's cohesion multiplier on speed. Bodies behind their place hurry and
  -- bodies ahead of it wait, and the two are the same budget moved around.
  soldier.speed_scale       = zeroed(capacity)
  -- Which colour this body pays out when it dies, decided by the commander that
  -- fielded it. **You farm what the enemy fields**, so their commander selection
  -- decides what you can afford.
  soldier.bounty_colour     = zeroed(capacity)
  -- How many sign-posts this body will still obey. One for a hero, zero for
  -- everything else -- and once a hero has turned, it goes straight on at every
  -- junction for the rest of its life, whatever the next sign says.
  soldier.turns_left        = zeroed(capacity)
  -- Ticks until this body's ability may fire again.
  soldier.ability_cooldown  = zeroed(capacity)
  -- Ticks of fear remaining. Fear is the enemy's actual weapon and it is not
  -- damage: a frightened body hits softer. **Fear is evil. It is inflicted** --
  -- it is not an environmental hazard and not a resource, it is something one
  -- thing does to another on purpose, and it has an author.
  soldier.fear              = zeroed(capacity)
  -- Which connector this body is crossing, and how far along it. Zero for anything
  -- walking a lane, which is nearly everything -- only a hero that has obeyed a
  -- sign-post is ever out here.
  soldier.crossing          = zeroed(capacity)
  soldier.crossing_step     = zeroed(capacity)
  soldier.crossing_dir      = zeroed(capacity)

  -- Modifiers. One flat array per upgrade kind rather than one table per
  -- soldier: the sweep that re-stamps a lane's guards touches one kind across
  -- many bodies, which is a walk down one array.
  soldier.upgrade_count = {}
  for kind = 1, kind_count do
    soldier.upgrade_count[kind] = zeroed(capacity)
  end

  return soldier
end
-- }}}

-- {{{ local function make_team()
-- One team's record: what it owns, where it has pushed, and where its upgrades
-- are sitting.
--
-- The chest and the three kinds of slot are all "counts per kind" and are
-- deliberately the same shape, because placing an upgrade is moving one from a
-- count to a count and nothing else -- there is no upgrade object to lose track
-- of.
local function make_team(id, lane_count, kind_count)
  local team = {
    id         = id,
    chest      = empty_counts(kind_count),
    lane_slot  = {},
    tower_slot = {},
    library_slot = empty_counts(kind_count),
    push_depth = {},
    -- Where this team has read to in the shared deck. Both teams draw from one
    -- sequence, so what the enemy holds is knowable in aggregate; what you learn
    -- by looking is where they put it.
    deck_index = 0,
    -- Counted for the post-match report, which is the number that says whether
    -- the upgrade economy is balanced.
    waves_lost = {},
    draws_taken = 0,
  }
  for lane = 1, lane_count do
    team.lane_slot[lane]  = empty_counts(kind_count)
    team.tower_slot[lane] = empty_counts(kind_count)
    team.push_depth[lane] = 0
    team.waves_lost[lane] = 0
  end
  return team
end
-- }}}

-- {{{ function M.create()
-- Builds the whole world from the match parameters, the map, and the random
-- streams. Everything is allocated here and nothing allocates again during a
-- match.
function M.create(parameters, map, stream)
  local kind_count = #parameters.upgrade.kind
  local capacity   = M.SOLDIER_CAPACITY

  local world = {
    tick            = 0,
    phase           = M.PHASE_NORMAL,
    challenge_index = 0,
    -- Zero while the match runs; the winning team's number once it is over, or
    -- 3 for the draw that happens when both libraries fall in the same buffered
    -- damage pass.
    winner          = 0,

    parameters = parameters,
    map        = map,
    stream     = stream,

    soldier = make_soldier_arrays(capacity, kind_count),
    -- One slot per soldier, cleared at the top of every tick. Attacks write here
    -- and a separate pass adds it into health, which is what makes two soldiers
    -- who would kill each other on the same tick both die.
    pending_damage = zeroed(capacity),

    -- The free list. Popping from the end is O(1) and, more importantly, is
    -- deterministic: the same match always reuses the same slots in the same
    -- order, which is a precondition for the reproducibility test.
    free_slot = {},
    live_count = 0,
    high_water = 0,

    structure = {},
    wave      = {},
    team      = {},
    event     = {},
  }

  for slot = capacity, 1, -1 do
    world.free_slot[#world.free_slot + 1] = slot
  end

  for id = 1, 2 do
    world.team[id] = make_team(id, parameters.lane_count, kind_count)
  end

  -- The structures, from the map's sites. A structure is an array of records
  -- rather than a struct of arrays because there are twenty of them and they are
  -- addressed by name constantly; the argument for flat arrays is about sweeping
  -- thousands of things, and twenty is not thousands.
  local tower_row   = parameters.structure.tower
  local library_row = parameters.structure.library
  for _, site in ipairs(map.site) do
    local id = #world.structure + 1
    local is_library = (site.kind == 3)
    local health = tower_row.health
    if is_library then
      health = tower_row.health * library_row.health_in_towers
    end
    world.structure[id] = {
      id            = id,
      team          = site.team,
      kind          = site.kind,
      lane          = site.lane,
      milestone     = site.milestone,
      node          = site.node,
      health        = health,
      health_max    = health,
      damage        = is_library and library_row.damage or tower_row.damage,
      range         = is_library and library_row.range or tower_row.range,
      cooldown      = 0,
      cooldown_max  = is_library and library_row.cooldown_max or tower_row.cooldown_max,
      target        = 0,
      target_generation = 0,
      command_radius = is_library and 0 or tower_row.command_radius,
      guard_cap     = is_library and 0 or tower_row.guard_cap,
      guard_slot    = {},
      guard_timer   = 0,
      alive         = 1,
      -- What this tower is currently shooting with, rebuilt whenever its lane's
      -- stone slot changes. A copy, like everything else -- the swing path never
      -- dereferences a team record.
      upgrade_count = empty_counts(kind_count),
    }
    map.node[site.node].structure = id
  end

  -- One slot per structure for buffered damage, kept in its own array rather
  -- than sharing the soldier array, so that neither can index into the other by
  -- an arithmetic mistake.
  world.pending_structure_damage = zeroed(#world.structure)

  return world
end
-- }}}

-- {{{ function M.allocate()
-- Takes a free soldier slot, bumps its generation, and returns the id.
--
-- Refuses rather than growing. Running out of slots means something is spawning
-- without bound, and the honest failure is a message naming the capacity -- a
-- silent reallocation would move every array out from under any worker holding a
-- slice of one.
function M.allocate(world)
  local count = #world.free_slot
  if count == 0 then
    error("the world is out of soldier slots (" .. M.SOLDIER_CAPACITY ..
          ") -- something is spawning without bound")
  end
  local id = world.free_slot[count]
  world.free_slot[count] = nil

  local soldier = world.soldier
  soldier.generation[id] = soldier.generation[id] + 1
  soldier.alive[id] = 1
  world.live_count = world.live_count + 1
  if id > world.high_water then
    world.high_water = id
  end
  return id
end
-- }}}

-- {{{ function M.release()
-- Returns a slot to the free list and clears every field on it.
--
-- The clearing is not tidiness. A slot that keeps its old target id, its old
-- upgrade counts, or its old leash would hand them to the next body that moves
-- in, and that body would behave like a ghost of the last one -- which is the
-- single most confusing class of bug this design can produce.
function M.release(world, id)
  local soldier = world.soldier
  soldier.alive[id] = 0
  soldier.team[id] = 0
  soldier.flavour[id] = 0
  soldier.owner[id] = 0
  soldier.archetype[id] = 0
  soldier.wave[id] = 0
  soldier.assigned_team[id] = 0
  soldier.lane[id] = 0
  soldier.node_from[id] = 0
  soldier.node_to[id] = 0
  soldier.path_index[id] = 0
  soldier.progress[id] = 0
  soldier.x[id] = 0
  soldier.y[id] = 0
  soldier.facing[id] = 0
  soldier.milestone[id] = 0
  soldier.health[id] = 0
  soldier.health_max[id] = 0
  soldier.damage[id] = 0
  soldier.armour[id] = 0
  soldier.range[id] = 0
  soldier.acquire_range[id] = 0
  soldier.speed[id] = 0
  soldier.cooldown[id] = 0
  soldier.cooldown_max[id] = 0
  soldier.reach[id] = 0
  soldier.state[id] = 0
  soldier.incoming_dps[id] = 0
  soldier.target[id] = 0
  soldier.target_generation[id] = 0
  soldier.target_structure[id] = 0
  soldier.leash_node[id] = 0
  soldier.wander_node[id] = 0
  soldier.guard_of[id] = 0
  soldier.lane_along[id] = 0
  soldier.lane_across[id] = 0
  soldier.slot_along[id] = 0
  soldier.slot_across[id] = 0
  soldier.speed_scale[id] = 0
  soldier.bounty_colour[id] = 0
  soldier.turns_left[id] = 0
  soldier.ability_cooldown[id] = 0
  soldier.fear[id] = 0
  soldier.crossing[id] = 0
  soldier.crossing_step[id] = 0
  soldier.crossing_dir[id] = 0
  for kind = 1, #soldier.upgrade_count do
    soldier.upgrade_count[kind][id] = 0
  end
  world.pending_damage[id] = 0

  world.free_slot[#world.free_slot + 1] = id
  world.live_count = world.live_count - 1
end
-- }}}

-- {{{ function M.give_body()
-- Copies an archetype row's values into a body's slot.
--
-- A *copy*, not a reference, and that is the whole rule the project keeps
-- repeating: nothing in the swing path dereferences a catalogue, a lane, a
-- tower, or a team record to find out how strong a body is. The numbers are
-- right there in the body's own slot.
--
-- The price is that copies have to be corrected when the source changes, and
-- that is done by an explicit sweep that clears and rebuilds -- never patches. A
-- rebuild from the current truth cannot drift; an incremental adjustment can,
-- and will, in the direction nobody tests.
function M.give_body(world, id, row)
  local soldier = world.soldier
  soldier.flavour[id]       = row.flavour
  soldier.reach[id]         = row.reach
  soldier.health[id]        = row.health
  soldier.health_max[id]    = row.health
  soldier.damage[id]        = row.damage
  soldier.armour[id]        = row.armour
  soldier.range[id]         = row.range
  soldier.acquire_range[id] = row.acquire_range
  soldier.speed[id]         = row.speed
  soldier.cooldown[id]      = row.cooldown_max
  soldier.cooldown_max[id]  = row.cooldown_max
  soldier.state[id]         = M.STATE_WALKING
  soldier.target[id]        = 0
  soldier.target_generation[id] = 0
  soldier.target_structure[id]  = 0
  soldier.incoming_dps[id]  = 0
end
-- }}}

-- {{{ function M.raise()
-- Records an event for this tick. The viewer reads these and fires its popups;
-- the simulation never reads them back.
--
-- Every event here must be legible at the default camera framing. That is the
-- camera's one rule read from this side: if a thing is worth raising an event
-- about, a player must not have to be zoomed in to find out about it.
function M.raise(world, name, detail)
  detail = detail or {}
  detail.name = name
  detail.tick = world.tick
  world.event[#world.event + 1] = detail
end
-- }}}

return M
