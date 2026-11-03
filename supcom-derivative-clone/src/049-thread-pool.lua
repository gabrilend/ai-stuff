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

-- 049-thread-pool.lua
--
-- Slices the tick's sliceable rows into ranges of unit rows and runs each
-- range; serial by default, the same answer at any worker count.
--
-- The rule the pool stands on: a sliced system may read anything and write
-- only its own slice. A slice is a range of unit rows, and `slice` splits a
-- count of rows into as many contiguous ranges as there are workers, as even as
-- whole numbers allow. `run_sliced` runs one tick row over every range and
-- returns when all are done. Because each range writes only its own rows, the
-- answer is the same for one worker or eight -- and the tests hold it to that,
-- by fingerprint.
--
-- How the ranges are run is a backend behind one interface. The backend this
-- file ships, and the default, is `serial`: the ranges run one after another,
-- lowest first, on the calling thread. A backend that runs them on threads
-- needs a threading library (effil or lanes) vendored into libs/, which is an
-- open item for Ritz; it would register itself in `BACKENDS` and change nothing
-- else. (The fire pass appends to the shot queue in row order; a threaded
-- backend has to keep that order, for instance by giving each range its own
-- stretch of the queue and joining them lowest first.)

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
    error("thread-pool: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
  end
  if package.loaded[found[1]] == nil then
    package.loaded[found[1]] = dofile(found[1])
  end
  return package.loaded[found[1]]
end
-- }}}

local world_module = the_world()
local ffi = require("ffi")

-- {{{ BACKENDS
-- The ways the ranges can be run, by name. Each takes the slice function, the
-- world, and the ranges, and returns when every range has run.
M.BACKENDS = {
  serial = function(run_slice, world, ranges)
    for index = 1, #ranges do
      run_slice(world, ranges[index][1], ranges[index][2])
    end
  end,
}
-- }}}

-- The pool's settings: how many workers (ranges) a sliced row is split into,
-- and which backend runs them. Settings of the process, never of the world, so
-- they are not part of what the fingerprint folds.
local settings = {workers = 1, backend = "serial"}

-- {{{ function M.cores()
-- How many processors the machine has online, as the shell's getconf says; one
-- when it cannot say.
function M.cores()
  local handle = io.popen("getconf _NPROCESSORS_ONLN 2>/dev/null")
  local text = handle and handle:read("*l") or nil
  if handle then handle:close() end
  local count = tonumber(text)
  if count == nil or count < 1 or count ~= math.floor(count) then
    return 1
  end
  return count
end
-- }}}

-- {{{ function M.configure()
-- Sets the worker count, a whole number from one, and optionally the backend by
-- name. Refuses a backend nobody has built, naming what it would need.
function M.configure(workers, backend)
  if type(workers) ~= "number" or workers ~= math.floor(workers) or workers < 1 then
    error("thread-pool: a worker count is " .. tostring(workers) .. ", not a whole number from one", 2)
  end
  if backend ~= nil and M.BACKENDS[backend] == nil then
    error("thread-pool: there is no '" .. tostring(backend) .. "' backend; only 'serial' is built,"
          .. " and a threaded one needs a threading library vendored into libs/", 2)
  end
  settings.workers = workers
  settings.backend = backend or settings.backend
end
-- }}}

-- {{{ function M.workers()
-- The worker count and the backend's name now.
function M.workers()
  return settings.workers, settings.backend
end
-- }}}

-- {{{ function M.read_workers()
-- `input/workers` under `root`: comment lines, then one line, a whole number
-- from one or the word `cores`. An absent file is `cores`. Returns the count.
function M.read_workers(root)
  local path = root .. "/input/workers"
  local handle = io.open(path, "r")
  if handle == nil then
    return M.cores()
  end
  local value = nil
  for line in handle:lines() do
    local text = line:match("^%s*(.-)%s*$")
    if text ~= "" and text:sub(1, 1) ~= "#" then
      if value ~= nil then
        handle:close()
        error("thread-pool: " .. path .. " holds more than one line that is not a comment", 2)
      end
      value = text
    end
  end
  handle:close()
  if value == nil or value == "cores" then
    return M.cores()
  end
  local count = tonumber(value)
  if count == nil or count ~= math.floor(count) or count < 1 then
    error("thread-pool: " .. path .. " says '" .. value .. "', not a whole number from one or 'cores'", 2)
  end
  return count
end
-- }}}

-- {{{ function M.slice()
-- `count` rows split into at most `workers` contiguous ranges, each a pair
-- {first, last}, together covering one to `count` once. The first `count %
-- workers` ranges are one row longer, so no two differ by more than one. Fewer
-- rows than workers gives one range per row; no rows gives no ranges.
function M.slice(count, workers)
  if type(count) ~= "number" or count ~= math.floor(count) or count < 0 then
    error("thread-pool: a row count is " .. tostring(count) .. ", not a whole number from zero", 2)
  end
  if type(workers) ~= "number" or workers ~= math.floor(workers) or workers < 1 then
    error("thread-pool: a worker count is " .. tostring(workers) .. ", not a whole number from one", 2)
  end
  local ranges = {}
  if count == 0 then
    return ranges
  end
  if workers > count then
    workers = count
  end
  local base, extra = math.floor(count / workers), count % workers
  local first = 1
  for index = 1, workers do
    local length = base + (index <= extra and 1 or 0)
    ranges[index] = {first, first + length - 1}
    first = first + length
  end
  return ranges
end
-- }}}

-- {{{ function M.run_sliced()
-- One sliceable tick row over the whole world: its `before` step first, if it
-- has one (an unsliced pass the slices read, such as the move pass's
-- occupancy), then its `run_slice` over the ranges the unit rows split into at
-- the pool's worker count, through the pool's backend. Returns the ranges.
function M.run_sliced(system, world)
  if type(system) ~= "table" or type(system.run_slice) ~= "function" then
    error("thread-pool: run_sliced wants a tick row with a run_slice", 2)
  end
  if system.before ~= nil then
    system.before(world)
  end
  local ranges = M.slice(world.unit.top, settings.workers)
  M.BACKENDS[settings.backend](system.run_slice, world, ranges)
  return ranges
end
-- }}}

-- {{{ local function take()
-- Every slot of every group's every field, copied, so a later look can say
-- which slots changed.
local function take(world)
  local copy = {}
  for _, row in ipairs(world.layout.groups) do
    local group = world[row.group]
    local fields = {}
    for _, field in ipairs(row.fields) do
      local array = group[field[1]]
      local saved
      if field[2] == "text" then
        saved = {}
        for slot = 0, group.capacity do saved[slot] = array[slot] end
      else
        saved = ffi.new(ffi.typeof(array), group.capacity + 1)
        ffi.copy(saved, array, ffi.sizeof(array))
      end
      fields[field[1]] = saved
    end
    copy[row.group] = fields
  end
  return copy
end
-- }}}

-- {{{ function M.trace_writes()
-- Runs `body` and returns every slot of the world's groups it changed, in
-- layout order, as {array = group, field = field, index = slot}. A write that
-- left a slot's value as it was is not seen, which is the only way a write can
-- matter to another worker.
function M.trace_writes(body, world)
  local before = take(world)
  body()
  local writes = {}
  for _, row in ipairs(world.layout.groups) do
    local group = world[row.group]
    for _, field in ipairs(row.fields) do
      local array, saved = group[field[1]], before[row.group][field[1]]
      for slot = 0, group.capacity do
        local now, was = array[slot], saved[slot]
        if now ~= was and not (now ~= now and was ~= was) then
          writes[#writes + 1] = {array = row.group, field = field[1], index = slot}
        end
      end
    end
  end
  return writes
end
-- }}}

-- {{{ function M.outside()
-- The pool's rule checked on one row and one range: runs `run_slice(world,
-- first, last)` and names the first unit row outside the range it changed, as
-- "unit.<field>[<row>]", or returns nil when it kept to its slice.
function M.outside(world, run_slice, first, last)
  for _, write in ipairs(M.trace_writes(function() run_slice(world, first, last) end, world)) do
    if write.array == "unit" and (write.index < first or write.index > last) then
      return "unit." .. write.field .. "[" .. write.index .. "]"
    end
  end
  return nil
end
-- }}}

return M
