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

-- 042-the-tick.lua
--
-- The heartbeat, and the assembly.
--
-- The tick is an **ordered array of system functions**, each taking the world,
-- rather than a hand-written sequence of calls. Adding a system means adding a
-- row; reordering means moving a row. The order of the simulation becomes a piece
-- of readable data instead of something buried in a function body, which matters
-- more here than it looks: almost every subtle bug in a simulation like this one
-- is an ordering bug, and an ordering bug is much easier to find when the order
-- is a list you can read.
--
-- The world advances in fixed steps. The step length is a constant, not a
-- measured frame time, and every duration in the game is a whole number of ticks
-- rather than a number of seconds. A soldier's attack cooldown is twenty-two
-- ticks, not seven-tenths of a second. That removes an entire family of bugs
-- where two machines simulating the same game drift apart because one of them had
-- a longer frame.
--
-- This file is also where the pieces are wired together. Each system module is
-- hung on the world so that the modules can reach each other without any of them
-- requiring another directly -- the chest needs the world, the world needs the
-- chest, and a direct require in both directions is a loop. One assembly point,
-- named, beats a web of half-loaded modules.

local M = {}

-- {{{ local function clear_buffers()
local function clear_buffers(world)
  world.combat.clear_buffers(world)
  -- Events are the viewer's only channel and are cleared here, at the top, so
  -- that a viewer reading a snapshot sees exactly the events of that tick.
  for index = #world.event, 1, -1 do
    world.event[index] = nil
  end
end
-- }}}

-- {{{ local function apply_commands()
local function apply_commands(world)
  world.commands.apply_all(world)
end
-- }}}

-- {{{ local function spawn()
-- Everything that adds a body to the world does it here: wave timers and guard
-- replacement, and later the surge stream and the challenge monsters.
--
-- Runs on one thread because it allocates ids.
local function spawn(world)
  world.waves.spawn_pass(world)
  world.structures.guard_pass(world)
end
-- }}}

-- {{{ local function index_the_field()
-- Drops every living body into the spatial grid so the retarget pass can ask
-- "what is near me" without asking every other body.
local function index_the_field(world)
  world.targeting.rebuild_grid(world)
end
-- }}}

-- {{{ local function form_up()
-- Every host draws the line through the enemy in front of it and takes up its
-- ranks parallel to that line.
--
-- Before the brain runs, because a body's whole decision about where to walk this
-- tick depends on whether it has a place to walk to. After the grid is built,
-- because finding the enemy's mass is a query against it.
local function form_up(world)
  world.formations.plan(world)
end
-- }}}

-- {{{ local function retarget()
-- Every soldier without a living target looks for one.
--
-- A body that already has a living target is left alone, which is what makes a
-- fight a fight rather than a crowd of bodies re-deciding every tick. Only the
-- ones with nothing to hit pay for a search.
local function retarget(world)
  local soldier = world.soldier
  local targeting = world.targeting

  for id = 1, world.high_water do
    if soldier.alive[id] == 1 and soldier.state[id] ~= 4 and soldier.state[id] ~= 5 then
      local has_target = targeting.target_is_alive(world, id)
      if not has_target and soldier.target_structure[id] ~= 0 then
        has_target = world.structure[soldier.target_structure[id]].alive == 1
      end
      if not has_target then
        targeting.choose(world, id)
      end
    end
  end

  -- Then rebuild "who is swinging at me" from everybody's choice, for the next
  -- tick's rule 1 to read. A full rebuild rather than an incremental update,
  -- because a missed decrement leaves a body permanently believing it is under
  -- fire and nothing would ever correct it.
  targeting.sweep_attackers(world)
end
-- }}}

-- {{{ local function move()
-- The brain, once per living body. Junction decisions are resolved here.
local function move(world)
  world.brain.run(world)
end
-- }}}

-- {{{ local function attack()
-- Cooldowns come down; anything ready and in range writes into the pending
-- damage buffer rather than straight into health.
local function attack(world)
  world.combat.attack_pass(world)
  world.structures.tower_pass(world)
  -- Abilities fire here, through the same buffer an ordinary swing uses, on the
  -- same tick boundary, with the same armour arithmetic. There is no second damage
  -- system and this row is what says so.
  world.abilities.run(world)
end
-- }}}

-- {{{ local function resolve_damage()
local function resolve_damage(world)
  world.combat.resolve_pass(world)
end
-- }}}

-- {{{ local function reap()
local function reap(world)
  world.combat.reap_pass(world)
end
-- }}}

-- {{{ local function measure()
-- Push depth, recomputed from the living.
--
-- **Living**, not a high-water mark, so push depth can go down. It creeps up as
-- soldiers advance and collapses when they die. That is the number the whole game
-- runs on -- "which lane am I losing" is a comparison of these small integers and
-- never a distance -- so it is recomputed in full every tick rather than
-- maintained, because a maintained version that drifts would be a lie told in the
-- one place a player is looking.
local function measure(world)
  local soldier = world.soldier
  local lane_count = world.parameters.lane_count

  for team = 1, 2 do
    for lane = 1, lane_count do
      world.team[team].push_depth[lane] = 0
    end
  end

  for id = 1, world.high_water do
    -- Guards are excluded. A guard stands at its own tower for its whole life, so
    -- counting it would read a team's own stone back at it as though it were a
    -- push -- every lane would report a permanent depth of 2 or 3 with nobody
    -- having advanced anywhere.
    if soldier.alive[id] == 1 and soldier.flavour[id] ~= 3 and soldier.lane[id] ~= 0 then
      local team = soldier.team[id]
      local lane_id = soldier.lane[id]
      local lane = world.map.lane[lane_id]
      local index = soldier.path_index[id]

      -- The deepest milestone this body has got past, counted from its own team's
      -- end. Team 1 walks up the path array and team 2 walks down it, so the same
      -- loop reads both by flipping the comparison.
      local depth = 0
      for m = 0, 8 do
        local at = lane.milestone_index[m]
        if team == 1 then
          if index >= at and m > depth then depth = m end
        else
          if index <= at and (8 - m) > depth then depth = 8 - m end
        end
      end

      soldier.milestone[id] = depth
      if depth > world.team[team].push_depth[lane_id] then
        world.team[team].push_depth[lane_id] = depth
      end
    end
  end
end
-- }}}

-- {{{ local function phase()
-- The match clock. Surges start and end, challenges begin, and the game-over
-- condition is checked.
--
-- At prototype scale this only advances the clock and notices that the reap pass
-- already declared a winner. The surge and the challenge are phase 6 of the
-- roadmap and are not built; the row exists so that adding them is adding to a
-- function that already runs in the right place.
local function phase(world)
  world.commanders.climb_ladder(world)
  if world.winner ~= 0 then
    world.phase = 5
  end
end
-- }}}

-- {{{ local function stamp_snapshot()
local function stamp_snapshot(world)
  world.snapshot.stamp(world)
end
-- }}}

-- {{{ M.system
-- The order of the simulation, as data.
--
-- Two orderings in here are load-bearing and both were arrived at the hard way:
--
--   * **resolve after attack, reap after resolve.** Attacks write into a buffer;
--     resolve applies it; reap frees slots. Freeing a slot inside the resolve pass
--     would let a later body in the same pass be handed a slot the pass still
--     refers to.
--
--   * **measure after reap.** Push depth is a statement about the living, so it
--     has to be taken after the dead have been removed. Measured before, a lane
--     would report a depth held by a body that died this tick.
M.system = {
  {name = "clear",    run = clear_buffers},
  {name = "commands", run = apply_commands},
  {name = "spawn",    run = spawn},
  {name = "index",    run = index_the_field},
  {name = "form",     run = form_up},
  {name = "retarget", run = retarget},
  {name = "move",     run = move},
  {name = "attack",   run = attack},
  {name = "resolve",  run = resolve_damage},
  {name = "reap",     run = reap},
  {name = "measure",  run = measure},
  {name = "phase",    run = phase},
  {name = "snapshot", run = stamp_snapshot},
}
-- }}}

-- {{{ function M.advance()
-- One tick. The whole simulation, in the order above.
function M.advance(world)
  if world.phase == 5 then
    return false
  end
  world.tick = world.tick + 1
  for index = 1, #M.system do
    M.system[index].run(world)
  end
  return true
end
-- }}}

-- {{{ M.cast
-- Every module the simulation is built from, by the name it is hung on the world
-- under, and the file it lives in.
--
-- The file names carry their indices because the indices are a reading order --
-- the project is meant to be read from 024 upward as a story -- and a table that
-- said "walking" without saying "034" would hide where in that story the reader
-- is. Renaming a file means editing one row here, which is the price of the
-- numbers meaning something.
M.cast = {
  {name = "match_parameters", file = "028-match-parameters"},
  {name = "random_streams",   file = "029-random-streams"},
  {name = "map_builder",      file = "030-map-builder"},
  {name = "map_validator",    file = "031-map-validator"},
  {name = "world",            file = "032-the-world"},
  {name = "commands",         file = "033-commands"},
  {name = "walking",          file = "034-walking"},
  {name = "targeting",        file = "035-targeting"},
  {name = "frontline",        file = "036-the-frontline"},
  {name = "brain",            file = "037-the-brain"},
  {name = "combat",           file = "038-combat"},
  {name = "waves",            file = "039-waves"},
  {name = "structures",       file = "040-structures"},
  {name = "chest",            file = "041-the-chest"},
  {name = "snapshot",         file = "043-snapshot"},
  {name = "formations",       file = "052-formations"},
  {name = "commanders",       file = "054-commanders"},
  {name = "abilities",        file = "055-abilities"},
  {name = "signposts",        file = "056-signposts"},
}
-- }}}

-- {{{ function M.load_cast()
-- Loads every module by path rather than through Lua's module search path.
--
-- By path because this project's files are named with a leading index and a
-- dash, which is not an identifier -- `require "034-walking"` is not a thing a
-- reader would expect to work, and making it work would mean teaching the loader
-- about the numbering. Reading the file is simpler and says what it does.
function M.load_cast(root)
  local modules = {}
  for _, entry in ipairs(M.cast) do
    local path = root .. "/src/" .. entry.file .. ".lua"
    local chunk, message = loadfile(path)
    if chunk == nil then
      error("cannot load " .. path .. ": " .. tostring(message))
    end
    modules[entry.name] = chunk()
  end
  return modules
end
-- }}}

-- {{{ function M.assemble()
-- Builds a world with every system hung on it and every starting condition set.
--
-- This is the one place that knows the whole cast. Everything else reaches its
-- neighbours through the world, which is what keeps a project with a chest that
-- needs the world and a world that needs the chest from being a require loop.
function M.assemble(modules, parameters)
  local map = modules.map_validator.insist(modules.map_builder.build(parameters), parameters)
  local stream = modules.random_streams.make_set(parameters.seed)
  local world = modules.world.create(parameters, map, stream)

  world.walking    = modules.walking
  world.targeting  = modules.targeting
  world.frontline  = modules.frontline
  world.brain      = modules.brain
  world.combat     = modules.combat
  world.waves      = modules.waves
  world.structures = modules.structures
  world.chest      = modules.chest
  world.commands   = modules.commands
  world.snapshot   = modules.snapshot
  world.formations = modules.formations
  world.map_builder = modules.map_builder
  world.commanders = modules.commanders
  world.abilities  = modules.abilities
  world.signposts  = modules.signposts

  -- The three world-level helpers the systems call by name. Hung here rather than
  -- required, for the same reason as everything above.
  world.allocate  = modules.world.allocate
  world.release   = modules.world.release
  world.raise     = modules.world.raise
  world.give_body = modules.world.give_body
  world.restamp_stone = modules.chest.restamp_stone

  -- Who is swinging at me, rebuilt every tick.
  world.attacker_of = {}
  for id = 1, modules.world.SOLDIER_CAPACITY do
    world.attacker_of[id] = 0
  end

  world.grid = modules.targeting.make_grid(world)
  world.command_queue = {}

  modules.formations.begin(world)
  modules.commanders.begin(world)
  modules.signposts.begin(world)
  modules.chest.build_deck(world)
  modules.waves.begin(world)
  modules.structures.begin(world)
  modules.snapshot.begin(world)

  -- The first snapshot, so that a viewer attaching before tick 1 has something
  -- to draw rather than an empty screen it cannot distinguish from a bug.
  modules.snapshot.stamp(world)

  return world
end
-- }}}

return M
