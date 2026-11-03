-- supcom-derivative-clone — a factory war on dunes where nothing is out of range
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

-- 031-the-tick.lua
--
-- The heartbeat: an ordered table of systems.
--
-- One tick is one pass over `SYSTEMS`, a table of rows in the order the tick
-- document gives, and then the tick count goes up by one. The order is data, so it
-- can be read, printed, and tested, and a system that is not a row does not run --
-- there is no other way to run one.
--
-- A row is a name, the function that runs it over the whole world, whether the
-- thread pool may slice it by unit range, and the function that runs one slice.
-- A row whose system has not been built yet says which issue builds it in
-- `waiting_for` and runs nothing; the issue that builds the system wires the row
-- to its module, and from then on a missing module is a refusal at load, by
-- name, never a silent skip.

local M = {}

-- {{{ local function the_world()
-- The world module, which holds the loader every module uses to find another by
-- its stem. It is found here by that same rule -- exactly one NNN-the-world.lua
-- beside this file -- because a file cannot use the loader to find the loader.
local function the_world()
  local path = debug.getinfo(1, "S").source:sub(2)
  if path:sub(1, 1) ~= "/" then
    path = os.getenv("PWD") .. "/" .. path
  end
  local here = path:match("^(.*)/[^/]+$")
  local found = {}
  local handle = io.popen("ls -1 '" .. here .. "' 2>/dev/null")
  for name in handle:lines() do
    if name:match("^%d%d%d%-the%-world%.lua$") then
      found[#found + 1] = here .. "/" .. name
    end
  end
  handle:close()
  if #found ~= 1 then
    error("the tick: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
  end
  if package.loaded[found[1]] == nil then
    package.loaded[found[1]] = dofile(found[1])
  end
  return package.loaded[found[1]]
end
-- }}}

local world_module = the_world()
local timers = world_module.load("timers")
local rules = world_module.load_asset("the-rules")

-- {{{ local function nothing_yet()
-- What a row runs before its system is built: nothing. The row exists so the
-- order is whole from the first tick, and `waiting_for` says who fills it.
local function nothing_yet()
end
-- }}}

-- {{{ local function row()
-- One row of the table. `built` is either the issue that will build the system,
-- as a string, or a pair {stem, function name} naming the module and export
-- that run it. A built row's module is loaded now, so a missing one is refused
-- when the tick is loaded, by name. A sliceable system exports `<name>_slice`
-- beside its whole-world function, taking the world and the first and last unit.
local function row(name, sliceable, built)
  if type(built) == "string" then
    return {name = name, sliceable = sliceable, waiting_for = built,
            run = nothing_yet, run_slice = nothing_yet}
  end
  local module = world_module.load(built[1])
  local run = module[built[2]]
  if type(run) ~= "function" then
    error("the tick: row '" .. name .. "' wants " .. built[1] .. "." .. built[2]
          .. ", which is not a function", 2)
  end
  local run_slice = nothing_yet
  if sliceable then
    run_slice = module[built[2] .. "_slice"]
    if type(run_slice) ~= "function" then
      error("the tick: row '" .. name .. "' is sliceable but " .. built[1] .. " has no "
            .. built[2] .. "_slice", 2)
    end
  end
  return {name = name, sliceable = sliceable, run = run, run_slice = run_slice}
end
-- }}}

-- {{{ SYSTEMS
-- The documented order, from the tick document. Move, sight-and-aim and fire read
-- the world and write only their own unit's row, so they slice by unit range;
-- everything else writes shared state and runs on one worker in this order.
M.SYSTEMS = {
  row("commands", false, "108"),
  row("income", false, "301"),
  row("construction", false, "305"),
  row("emit", false, "307"),
  row("move", true, "204"),
  row("claim", false, "112"),
  row("sight-and-aim", true, "205"),
  row("fire", true, "206"),
  row("land", false, "206"),
  row("die", false, "208"),
  row("the-cloud", false, "401"),
  row("consequences", false, "309"),
  row("snapshot", false, "109"),
}
-- }}}

-- {{{ function M.advance()
-- One tick. Every counter is brought up to this tick first, so the increment of
-- now is settled before any system reads it; then every row runs in order; then
-- the tick count rises. Returns whether the match continues, which in this phase
-- is always: the rule that ends a match arrives with the command truck.
function M.advance(world)
  local tick = world.tick
  for _, counter_row in ipairs(world.layout.counters) do
    timers.advance(world_module.counter_at(world, counter_row), tick)
  end
  local systems = M.SYSTEMS
  for index = 1, #systems do
    systems[index].run(world)
  end
  world.tick = tick + 1
  return true
end
-- }}}

-- {{{ function M.assemble()
-- The one place a match's world is put together: the world's arrays allocated,
-- the field raised, the streams opened (all inside the world's allocate), then
-- every module the caller names loaded and handed back keyed by stem, refusing
-- by name any that is absent. `modules` is a list of stems; the modules the
-- tick's own rows run are already loaded and need not be named.
function M.assemble(modules, parameters)
  local cast = {}
  for _, stem in ipairs(modules) do
    cast[stem] = world_module.load(stem)
  end
  local world = world_module.allocate(parameters)
  world_module.validate(world)
  return world, cast
end
-- }}}

-- {{{ function M.ticks_of()
-- Seconds, as the catalogue writes them, into whole ticks at the match's rate.
function M.ticks_of(seconds)
  return timers.ticks_of(seconds, rules.ticks_per_second)
end
-- }}}

-- {{{ function M.load()
-- The loader, passed through, so a program that has the tick can reach any
-- module by stem without finding the world first.
M.load = world_module.load
M.load_asset = world_module.load_asset
-- }}}

return M
