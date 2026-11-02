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

-- 030-the-world.lua
--
-- Allocates the world once, as flat arrays.
--
-- Everything the simulation holds -- units, cells, teams, counters, streams --
-- is a group of parallel arrays, one array per field, sized once before the first
-- tick and never resized. The layout is data: `LAYOUT` lists every group, every
-- field and its type, and the allocator, the validator, the snapshot's hash and
-- the handheld port all read that one table. There is no second description of
-- the world anywhere.
--
-- Three rules, none negotiable:
--
--   * Zero is nothing. Slot zero of every array is never used, so an id of zero
--     means "no such thing" without a check, and every array is one longer for it.
--   * Nothing is nil. Every array is zero-filled at allocation; `validate` walks
--     every field of every group and refuses anything that is not a number.
--   * Capacity is a refusal, not a resize. Claiming past a group's capacity is an
--     error naming the group.
--
-- This file also holds the one loader every module uses to find another by its
-- stem, because the world is what every module already has to reach.

local ffi = require("ffi")

local M = {}

-- {{{ local function directory_of_this_file()
-- The absolute directory this file sits in. A file loaded by a relative path
-- knows only that path, so it is read against the shell's working directory.
local function directory_of_this_file()
  local path = debug.getinfo(1, "S").source:sub(2)
  if path:sub(1, 1) ~= "/" then
    path = os.getenv("PWD") .. "/" .. path
  end
  return path:match("^(.*)/[^/]+$")
end
-- }}}

-- The directory this file sits in, and the project root above it.
local HERE = directory_of_this_file()
local ROOT = HERE:match("^(.*)/[^/]+$")

-- {{{ the types
-- What a field's type name means: the foreign array it is allocated as, and the
-- check `validate` makes of it. Switching positions to fixed-point integers --
-- open question F2, if the two machines disagree on doubles -- is changing type
-- names in the layout below and nothing else.
--
-- `text` is the one type that is not a number: a Lua array of strings, the empty
-- string where there is nothing. It exists for the refusal ring, whose reasons
-- are sentences a viewer shows, and it is never read by a rule.
M.TYPES = {
  integer = {array = ffi.typeof("int32_t[?]")},
  double  = {array = ffi.typeof("double[?]")},
  text    = {lua = true},
}
-- }}}

-- {{{ the layout
-- Every group, its kind, where its capacity comes from, and its fields in order.
--
--   pool  -- rows are claimed and released; ids are stable for a row's life, a
--            released row is zeroed and its id is reused, last released first.
--            Carries `count` (live rows), `top` (the highest row ever claimed;
--            walkers go from one to it) and a stack of released ids.
--   fixed -- every row exists for the whole match: one per cell, one per team,
--            one per named stream.
--   queue -- rows one to `count` in the order they were pushed; removing a row
--            closes the gap, so the order never changes. The command queue.
--   ring  -- the last `capacity` rows written, oldest overwritten first; `last`
--            is the slot written most recently. The refusals a viewer shows.
--
-- Capacity comes from the allocation parameters (`units`, `teams`), from the
-- field (`cells`), from a module's own list (`streams`), or from the rules
-- (`commands`, `refusals`). An issue that builds
-- a system adds its group or its fields here; a field nobody has built yet still
-- holds zero, which is what "nothing" means.
M.LAYOUT = {
  {group = "unit", kind = "pool", capacity = "units", fields = {
    {"alive", "integer"},       -- one while the row is a unit, zero when released
    {"kind", "integer"},        -- index into the unit catalogue
    {"team", "integer"},        -- which side owns it
    {"x", "double"},            -- position, in cells, a cell's centre at its integers
    {"y", "double"},
    {"domain", "integer"},      -- land, air, or sea, copied from the catalogue at birth
    {"altitude", "double"},     -- height above the ground; zero for land and sea
    {"health", "integer"},      -- the heal pair: the value written ...
    {"health_at", "integer"},   -- ... and the increment it was written at
    {"reload_at", "integer"},   -- the increment the weapon last fired at
    {"pattern", "integer"},     -- which pattern it follows; zero for a plane
    {"leg", "integer"},         -- which segment of its pattern it is on
    {"mission", "integer"},     -- a plane's mission; zero for everything else
    {"target", "integer"},      -- the unit it is shooting at; zero for none
    {"damage", "integer"},      -- copied from the catalogue at birth
    {"falloff", "integer"},     -- which falloff curve, copied at birth
    {"eye", "double"},          -- how high it looks from
    {"profile", "double"},      -- how tall it looks
    {"shield", "integer"},      -- the enforcer's shield pair; zero for everything else
    {"shield_at", "integer"},
    {"eaten", "integer"},       -- mass an enforcer has consumed
    {"eat_share", "double"},    -- the share of what it eats that goes to the treasury
    {"strength", "double"},     -- a plane's strength in the cloud
    {"in_round", "integer"},    -- the cloud round a plane joined
    {"goal_x", "double"},       -- where a plane's mission takes it
    {"goal_y", "double"},
  }},
  {group = "cell", kind = "fixed", capacity = "cells", fields = {
    {"owner", "integer"},       -- zero, or the team that holds it
    {"claim_by", "integer"},    -- zero, or the team whose claim is in progress
    {"claim_began", "integer"}, -- the claim counter's increment the claim counts from
    {"claim_seen", "integer"},  -- the increment its claimant was last near it
    {"improvement", "integer"}, -- what has been spent raising what it pays (issue 311)
    {"mark", "integer"},        -- this tick's presence, one bit per team; zero between passes
  }},
  {group = "marked", kind = "queue", capacity = "cells", fields = {
    {"cell", "integer"},        -- a cell some unit marked this tick, in the order first marked
  }},
  {group = "team", kind = "fixed", capacity = "teams", fields = {
    {"mass", "double"},
    {"energy", "double"},
    {"thorns", "double"},
    {"energy_level", "integer"}, -- which of the four buttons is pressed; zero for none yet
  }},
  {group = "stream", kind = "fixed", capacity = "streams", fields = {
    {"state", "integer"},       -- one named stream's xorshift state, never zero
  }},
  {group = "command", kind = "queue", capacity = "commands", fields = {
    {"tick", "integer"},        -- the tick it takes effect at
    {"verb", "integer"},        -- the verb's place in the door's list of names
    {"team", "integer"},
    {"player", "integer"},      -- zero when the command does not name one
    {"argument1", "double"},    -- the verb's arguments, in the order it names them
    {"argument2", "double"},
    {"argument3", "double"},
    {"argument4", "double"},
  }},
  {group = "refusal", kind = "ring", capacity = "refusals", fields = {
    {"tick", "integer"},        -- the tick that was running when it was refused
    {"team", "integer"},
    {"verb", "integer"},        -- zero for a verb nobody knows
    {"reason", "text"},
  }},
}

-- The bookkeeping a group of each kind carries beside its fields, in the order
-- the hash folds it.
M.SCALARS = {pool = {"count", "top", "released"}, fixed = {}, queue = {"count"},
             ring = {"count", "last"}}

-- Every periodic effect's counter, as a place in the world and where its period
-- and any extra integers come from in the rules. Adding an effect is adding a
-- row. The tick brings every counter up to the tick before it walks its systems.
M.COUNTERS = {
  {path = {"claim"}, seconds = "claim_seconds",
   extra = {{"increments_to_claim", "claim_increments"}}},
}
-- }}}

-- {{{ local function list()
-- Every entry in a directory, sorted, read through the shell. Read-only.
local function list(directory)
  local found = {}
  local handle = io.popen("ls -1 '" .. directory .. "' 2>/dev/null")
  for name in handle:lines() do
    found[#found + 1] = name
  end
  handle:close()
  table.sort(found)
  return found
end
-- }}}

-- {{{ local function find()
-- The one file in a directory named NNN-<stem>.lua. Zero is an absence and two
-- is a naming bug, and both are refused by name -- the test harness's rule.
local function find(directory, stem)
  local wanted = "^%d%d%d%-" .. stem:gsub("%-", "%%-") .. "%.lua$"
  local matches = {}
  for _, name in ipairs(list(directory)) do
    if name:match(wanted) then
      matches[#matches + 1] = name
    end
  end
  if #matches == 0 then
    error("the world: no " .. directory .. "/NNN-" .. stem .. ".lua -- it has not been built", 3)
  end
  if #matches > 1 then
    error("the world: " .. directory .. " has " .. #matches .. " files named *-" .. stem
          .. ".lua, which is a naming bug: " .. table.concat(matches, ", "), 3)
  end
  return directory .. "/" .. matches[1]
end
-- }}}

-- {{{ local function load_path()
-- A file's module, loaded once and kept under its path, so every module asking
-- for a stem gets the same table.
local function load_path(path)
  if package.loaded[path] == nil then
    local chunk, problem = loadfile(path)
    if chunk == nil then
      error("the world: " .. path .. " does not load: " .. tostring(problem), 3)
    end
    package.loaded[path] = chunk()
  end
  return package.loaded[path]
end
-- }}}

-- {{{ function M.load()
-- The source module with a given stem, from beside this file.
function M.load(stem)
  return load_path(find(HERE, stem))
end
-- }}}

-- {{{ function M.load_asset()
-- The catalogue table with a given stem, from the project's assets/.
function M.load_asset(stem)
  return load_path(find(ROOT .. "/assets", stem))
end
-- }}}

-- {{{ local function whole()
-- A parameter that must be a whole number of at least one, refused by name.
local function whole(parameters, name)
  local value = parameters[name]
  if type(value) ~= "number" or value ~= math.floor(value) or value < 1 then
    error("the world: parameter '" .. name .. "' is " .. tostring(value)
          .. ", not a whole number of at least one", 3)
  end
  return value
end
-- }}}

-- {{{ local function capacities()
-- How many rows each capacity name means for this match.
local function capacities(parameters, field, streams, rules)
  return {
    units = whole(parameters, "units"),
    teams = whole(parameters, "teams"),
    cells = field.size * field.size,
    streams = #streams.STREAMS,
    commands = whole(rules, "commands"),
    refusals = whole(rules, "refusals"),
  }
end
-- }}}

-- {{{ local function allocate_group()
-- One group: its bookkeeping, and one zero-filled array per field, one longer
-- than the capacity so that slot zero is never a row.
local function allocate_group(row, capacity)
  local group = {capacity = capacity}
  for _, scalar in ipairs(M.SCALARS[row.kind]) do
    group[scalar] = 0
  end
  if row.kind == "pool" then
    -- The stack of released ids, deepest first; `released` is its height.
    group.free = M.TYPES.integer.array(capacity + 1)
  end
  for _, field in ipairs(row.fields) do
    local kind = M.TYPES[field[2]]
    if kind.lua then
      -- Text: a Lua array from slot zero, every slot the empty string.
      local array = {}
      for slot = 0, capacity do
        array[slot] = ""
      end
      group[field[1]] = array
    else
      group[field[1]] = kind.array(capacity + 1)
    end
  end
  return group
end
-- }}}

-- {{{ local function copy_tree()
-- A copy of a parameter table, so the world keeps what it was made from even if
-- the caller changes its table afterwards. Only numbers, strings, booleans and
-- tables of them are parameters.
local function copy_tree(value, where)
  if type(value) ~= "table" then
    if type(value) ~= "number" and type(value) ~= "string" and type(value) ~= "boolean" then
      error("the world: parameter " .. where .. " is a " .. type(value)
            .. ", which a match cannot be made from", 3)
    end
    return value
  end
  local copy = {}
  for key, inner in pairs(value) do
    copy[key] = copy_tree(inner, where .. "." .. tostring(key))
  end
  return copy
end
-- }}}

-- {{{ function M.counter_at()
-- The counter a COUNTERS row names, found by walking its path from the world.
function M.counter_at(world, row)
  local place = world
  for _, key in ipairs(row.path) do
    place = place[key]
  end
  return place
end
-- }}}

-- {{{ function M.allocate()
-- The whole world, once: the field raised from the parameters' shape and seed,
-- every group allocated and zeroed, every counter made, every stream seeded.
-- Nothing in a match allocates after this.
--
-- `parameters` holds `field` (the dunes' shape table), `units`, `teams`, and
-- `seed`. An absent seed is the seed zero, by the same rule as every other
-- empty thing in the world: zero is nothing, and nil is never stored.
function M.allocate(parameters)
  if type(parameters) ~= "table" or type(parameters.field) ~= "table" then
    error("the world: allocate wants a table with a 'field' shape table in it", 2)
  end
  local seed = parameters.seed or 0
  local dunes = M.load("the-dunes")
  local timers = M.load("timers")
  local streams = M.load("random-streams")
  local rules = M.load_asset("the-rules")

  local field = dunes.raise(parameters.field, seed)
  local sizes = capacities(parameters, field, streams, rules)
  -- `fingerprint` is the last hash the snapshot row took and `fingerprint_tick`
  -- the tick it took it in; `record_path` is where the replay log goes, empty
  -- when nothing is being recorded. None of them is part of what the hash folds.
  local world = {tick = 0, seed = seed, field = field, rule = {}, fingerprint = 0,
                 fingerprint_tick = 0, record_path = "",
                 parameters = copy_tree(parameters, "parameters"),
                 layout = {groups = M.LAYOUT, counters = M.COUNTERS, scalars = M.SCALARS}}
  world.parameters.seed = seed
  for name, value in pairs(rules) do
    world.rule[name] = value
  end
  for _, row in ipairs(M.LAYOUT) do
    world[row.group] = allocate_group(row, sizes[row.capacity])
  end
  for _, row in ipairs(M.COUNTERS) do
    local counter = timers.counter(timers.ticks_of(rules[row.seconds], rules.ticks_per_second))
    for _, extra in ipairs(row.extra) do
      counter[extra[1]] = rules[extra[2]]
    end
    local place = world
    for index = 1, #row.path - 1 do
      place[row.path[index]] = place[row.path[index]] or {}
      place = place[row.path[index]]
    end
    place[row.path[#row.path]] = counter
  end
  for row, name in ipairs(streams.STREAMS) do
    world.stream.state[row] = streams.seed_state(seed, name)
  end
  return world
end
-- }}}

-- {{{ local function check_array()
-- One field's array: the declared foreign type, the declared length, and a number
-- in every slot. A double that is not equal to itself is not a number.
local function check_array(group_name, field_name, type_name, array, capacity)
  local kind = M.TYPES[type_name]
  if kind == nil then
    error("the world: " .. group_name .. "." .. field_name .. " has an unknown type '"
          .. tostring(type_name) .. "'", 3)
  end
  if kind.lua then
    -- Text: a Lua array from slot zero to the capacity, a string in every slot.
    if type(array) ~= "table" or array[capacity + 1] ~= nil then
      error("the world: " .. group_name .. "." .. field_name .. " is not an array of "
            .. (capacity + 1) .. " strings", 3)
    end
    for slot = 0, capacity do
      if type(array[slot]) ~= "string" then
        error(string.format("the world: %s.%s[%d] is %s, not a string", group_name, field_name,
                            slot, tostring(array[slot])), 3)
      end
    end
    return
  end
  if type(array) ~= "cdata" or not ffi.istype(kind.array, array) then
    error("the world: " .. group_name .. "." .. field_name .. " is a " .. type(array)
          .. ", not an array of " .. type_name, 3)
  end
  local length = ffi.sizeof(array) / ffi.sizeof(kind.array, 1)
  if length ~= capacity + 1 then
    error(string.format("the world: %s.%s holds %d slots, not its capacity %d plus one",
                        group_name, field_name, length, capacity), 3)
  end
  for slot = 0, capacity do
    local value = array[slot]
    if value ~= value then
      error(string.format("the world: %s.%s[%d] is not a number", group_name, field_name, slot), 3)
    end
  end
end
-- }}}

-- {{{ function M.validate()
-- Refuses a world whose arrays are not what the layout says: a missing group, a
-- field of the wrong type or length, a slot that is not a number, a live count
-- outside the capacity, a counter that is not three whole numbers. Returns
-- nothing; a refusal is an error naming the group and field.
function M.validate(world)
  if type(world.tick) ~= "number" or world.tick ~= math.floor(world.tick) or world.tick < 0 then
    error("the world: tick is " .. tostring(world.tick) .. ", not a whole number from zero", 2)
  end
  if type(world.seed) ~= "number" then
    error("the world: seed is " .. tostring(world.seed) .. ", not a number", 2)
  end
  M.load("the-dunes").validate(world.field)
  for _, row in ipairs(M.LAYOUT) do
    local group = world[row.group]
    if type(group) ~= "table" then
      error("the world: group '" .. row.group .. "' is " .. type(group) .. ", not allocated", 2)
    end
    local capacity = group.capacity
    for _, field in ipairs(row.fields) do
      check_array(row.group, field[1], field[2], group[field[1]], capacity)
    end
    for _, scalar in ipairs(M.SCALARS[row.kind]) do
      local value = group[scalar]
      if type(value) ~= "number" or value ~= math.floor(value) or value < 0 or value > capacity then
        error("the world: " .. row.group .. "." .. scalar .. " is " .. tostring(value)
              .. ", not a whole number from zero to the capacity " .. capacity, 2)
      end
    end
    if row.kind == "pool" then
      check_array(row.group, "free", "integer", group.free, capacity)
      if group.count + group.released ~= group.top then
        error(string.format("the world: %s has %d live and %d released rows but has claimed %d",
                            row.group, group.count, group.released, group.top), 2)
      end
    end
  end
  for _, row in ipairs(M.COUNTERS) do
    local counter = M.counter_at(world, row)
    for _, name in ipairs({"period", "increment", "next"}) do
      local value = counter[name]
      if type(value) ~= "number" or value ~= math.floor(value) then
        error("the world: counter " .. table.concat(row.path, ".") .. "." .. name .. " is "
              .. tostring(value) .. ", not a whole number", 2)
      end
    end
  end
  for row = 1, world.stream.capacity do
    if world.stream.state[row] == 0 then
      error("the world: stream row " .. row .. " has a state of zero, which never leaves zero", 2)
    end
  end
end
-- }}}

-- {{{ local function layout_row()
-- A group's row in the layout, or a refusal naming the group.
local function layout_row(name)
  for _, row in ipairs(M.LAYOUT) do
    if row.group == name then
      return row
    end
  end
  error("the world: no group is named '" .. tostring(name) .. "'", 3)
end
-- }}}

-- {{{ function M.claim()
-- A free row in a pool, as an id: the last one released if there is one, the
-- next never-used row otherwise. The row is zero in every field and marked
-- alive. Past the capacity is a refusal naming the group: the arrays never grow.
function M.claim(world, name)
  local row = layout_row(name)
  if row.kind ~= "pool" then
    error("the world: '" .. name .. "' is a " .. row.kind .. " group; only a pool's rows are claimed", 2)
  end
  local group = world[name]
  local id
  if group.released > 0 then
    -- A released row: reused last-released first, which is the same order on
    -- every machine because releases happen in the same order.
    id = group.free[group.released]
    group.free[group.released] = 0
    group.released = group.released - 1
  elseif group.top < group.capacity then
    -- A row never used before.
    group.top = group.top + 1
    id = group.top
  else
    error("the world: the " .. name .. " group is full at its capacity of " .. group.capacity, 2)
  end
  group.count = group.count + 1
  group.alive[id] = 1
  return id
end
-- }}}

-- {{{ function M.push()
-- A new row at the end of a queue, as its index. Every field is already zero:
-- removal zeroes the row it vacates. Past the capacity is a refusal naming the
-- group.
function M.push(world, name)
  local row = layout_row(name)
  if row.kind ~= "queue" then
    error("the world: '" .. name .. "' is a " .. row.kind .. " group; only a queue is pushed", 2)
  end
  local group = world[name]
  if group.count >= group.capacity then
    error("the world: the " .. name .. " queue is full at its capacity of " .. group.capacity, 2)
  end
  group.count = group.count + 1
  return group.count
end
-- }}}

-- {{{ function M.remove()
-- Takes a row out of a queue and closes the gap: every later row moves down by
-- one, so the order of what remains never changes, and the last slot is zeroed.
function M.remove(world, name, index)
  local row = layout_row(name)
  local group = world[name]
  if row.kind ~= "queue" or index < 1 or index > group.count then
    error("the world: " .. name .. " row " .. tostring(index) .. " is not in the queue", 2)
  end
  for _, field in ipairs(row.fields) do
    local array = group[field[1]]
    for slot = index, group.count - 1 do
      array[slot] = array[slot + 1]
    end
    array[group.count] = M.TYPES[field[2]].lua and "" or 0
  end
  group.count = group.count - 1
end
-- }}}

-- {{{ function M.ring_next()
-- The slot a ring writes next: the one after the last written, wrapping to the
-- first, so the oldest row is the one overwritten. The caller fills it.
function M.ring_next(world, name)
  local row = layout_row(name)
  if row.kind ~= "ring" then
    error("the world: '" .. name .. "' is a " .. row.kind .. " group; only a ring is written round", 2)
  end
  local group = world[name]
  group.last = group.last % group.capacity + 1
  if group.count < group.capacity then
    group.count = group.count + 1
  end
  return group.last
end
-- }}}

-- {{{ function M.release()
-- Gives a pool's row back: every field zeroed, the id onto the stack of released
-- ids. Releasing a row that is not alive is refused -- it is a bug somewhere
-- upstream, and a second release would hand the same id out twice.
function M.release(world, name, id)
  local row = layout_row(name)
  local group = world[name]
  if row.kind ~= "pool" or id < 1 or id > group.top or group.alive[id] ~= 1 then
    error("the world: " .. name .. " row " .. tostring(id) .. " is not a live row to release", 2)
  end
  for _, field in ipairs(row.fields) do
    group[field[1]][id] = 0
  end
  group.released = group.released + 1
  group.free[group.released] = id
  group.count = group.count - 1
end
-- }}}

return M
