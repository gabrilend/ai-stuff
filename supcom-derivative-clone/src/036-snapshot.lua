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

-- 036-snapshot.lua
--
-- Fingerprints, copies, and records the world.
--
-- Three things, all reading the world's own layout and nothing else.
--
-- **The hash** folds every number of every group, in layout order, into one
-- thirty-two-bit fingerprint, so two machines compare one number and know whether
-- they agree. Arrays are folded as the thirty-two-bit words of their memory: an
-- integer is one word and a double is the two words of its bit pattern, so two
-- doubles that print the same but differ in the last bit hash differently --
-- which is exactly the disagreement lockstep has to catch. Both machines this
-- game runs on are little-endian, so the words are the same on both.
--
-- **The copy** is a snapshot: every array copied whole, in the same layout. A
-- viewer reads snapshots and never the live world.
--
-- **The replay** is a plain-text log: a header (the seed, a stamp of everything
-- the match was made from, the tick rate), every command the door accepts as it
-- accepts it, and the hash of every tick the snapshot row fingerprints. Text, so
-- two logs can be diffed.

local ffi = require("ffi")
local bit = require("bit")

local M = {}

local FORMAT = "supcom-derivative-clone replay 1"

-- {{{ local function fold()
-- One step of the fold: a word in, the running hash out. The body of MurmurHash3
-- without its multiplications by large constants, which a double cannot hold
-- exactly; a rotation, a times-five and an add keep every product below 2^35.
local function fold(hash, word)
  return bit.tobit(bit.rol(bit.bxor(hash, word), 13) * 5 + 0xe6546b64)
end
-- }}}

-- {{{ local function fold_number()
-- A Lua number that is a whole number, folded as a thirty-two-bit word.
local function fold_number(hash, value)
  return fold(hash, bit.tobit(value % 4294967296))
end
-- }}}

-- {{{ local function fold_text()
-- A string folded as its length and then its bytes.
local function fold_text(hash, text)
  hash = fold(hash, #text)
  for index = 1, #text do
    hash = fold(hash, text:byte(index))
  end
  return hash
end
-- }}}

-- {{{ local function fold_array()
-- Slots zero to `last` of a foreign array, as the words of their memory.
local function fold_array(hash, array, last, words_per_slot)
  local words = ffi.cast("uint32_t *", array)
  for index = 0, (last + 1) * words_per_slot - 1 do
    hash = fold(hash, words[index])
  end
  return hash
end
-- }}}

-- {{{ local function rows_in_use()
-- The last slot of a group that can hold anything: a pool's highest claimed
-- row, a queue's count, every row of anything else. Folding a pool's unused
-- tail would cost time and tell nothing, since it is all zero.
local function rows_in_use(row, group)
  if row.kind == "pool" then
    return group.top
  end
  if row.kind == "queue" then
    return group.count
  end
  return group.capacity
end
-- }}}

-- {{{ function M.hash()
-- The world's fingerprint: the tick, then every group in layout order (its
-- bookkeeping, then each field's rows in use), then every counter.
function M.hash(world)
  local layout = world.layout
  local hash = fold_number(0x5eed5eed, world.tick)
  for _, row in ipairs(layout.groups) do
    local group = world[row.group]
    for _, scalar in ipairs(layout.scalars[row.kind]) do
      hash = fold_number(hash, group[scalar])
    end
    local last = rows_in_use(row, group)
    if row.kind == "pool" then
      hash = fold_array(hash, group.free, group.released, 1)
    end
    for _, field in ipairs(row.fields) do
      local array = group[field[1]]
      if field[2] == "text" then
        for slot = 0, last do
          hash = fold_text(hash, array[slot])
        end
      else
        hash = fold_array(hash, array, last, field[2] == "double" and 2 or 1)
      end
    end
  end
  for _, row in ipairs(layout.counters) do
    local counter = world
    for _, key in ipairs(row.path) do
      counter = counter[key]
    end
    hash = fold_number(fold_number(fold_number(hash, counter.period), counter.increment), counter.next)
  end
  return hash % 4294967296
end
-- }}}

-- {{{ local function copy_table()
-- A plain table copied one level deep: counters and their extra integers.
local function copy_table(source)
  local copy = {}
  for key, value in pairs(source) do
    copy[key] = value
  end
  return copy
end
-- }}}

-- {{{ function M.copy()
-- A snapshot of the world: every group's bookkeeping and arrays copied, every
-- counter copied, the tick and the fingerprint carried. The field, the rules,
-- the parameters and the layout are never written during a match and are shared,
-- not copied. A snapshot records nothing, so its replay path is empty.
function M.copy(world)
  local layout = world.layout
  local copy = {tick = world.tick, seed = world.seed, field = world.field, rule = world.rule,
                parameters = world.parameters, layout = layout, fingerprint = world.fingerprint,
                fingerprint_tick = world.fingerprint_tick, record_path = ""}
  for _, row in ipairs(layout.groups) do
    local source = world[row.group]
    local group = {capacity = source.capacity}
    for _, scalar in ipairs(layout.scalars[row.kind]) do
      group[scalar] = source[scalar]
    end
    local arrays = {}
    for _, field in ipairs(row.fields) do
      arrays[#arrays + 1] = field[1]
    end
    if row.kind == "pool" then
      arrays[#arrays + 1] = "free"
    end
    for _, name in ipairs(arrays) do
      local array = source[name]
      if type(array) == "table" then
        -- Text: a Lua array from slot zero.
        local text = {}
        for slot = 0, source.capacity do
          text[slot] = array[slot]
        end
        group[name] = text
      else
        local fresh = ffi.new(ffi.typeof(array), source.capacity + 1)
        ffi.copy(fresh, array, ffi.sizeof(array))
        group[name] = fresh
      end
    end
    copy[row.group] = group
  end
  for _, row in ipairs(layout.counters) do
    local from, into = world, copy
    for index = 1, #row.path - 1 do
      from = from[row.path[index]]
      into[row.path[index]] = into[row.path[index]] or {}
      into = into[row.path[index]]
    end
    into[row.path[#row.path]] = copy_table(from[row.path[#row.path]])
  end
  return copy
end
-- }}}

-- {{{ local function stamp_lines()
-- Every leaf of a table as a "path=value" line, the keys at every level sorted,
-- so the order a table happens to iterate in can never change the stamp.
local function stamp_lines(value, path, lines)
  if type(value) ~= "table" then
    lines[#lines + 1] = path .. "=" .. (type(value) == "number" and string.format("%.17g", value)
                                         or tostring(value))
    return lines
  end
  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = tostring(key)
  end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local inner = value[key]
    if inner == nil then
      inner = value[tonumber(key)]
    end
    stamp_lines(inner, path .. "." .. key, lines)
  end
  return lines
end
-- }}}

-- {{{ function M.stamp()
-- A fingerprint of everything the match was made from: the allocation
-- parameters (the field's shape, the sizes, the seed) and every rule. A replay
-- whose stamp differs from the world it is fed to was recorded under other
-- rules, and is refused rather than played wrong.
function M.stamp(world)
  local hash = 0x57a3b5ed
  for _, line in ipairs(stamp_lines({parameters = world.parameters, rule = world.rule}, "match", {})) do
    hash = fold_text(hash, line)
  end
  return hash % 4294967296
end
-- }}}

-- {{{ local function append()
-- One line onto the end of the replay log.
local function append(path, line)
  local handle, problem = io.open(path, "a")
  if handle == nil then
    error("snapshot: cannot append to the replay log " .. path .. ": " .. tostring(problem), 3)
  end
  handle:write(line, "\n")
  handle:close()
end
-- }}}

-- {{{ local function command_line()
-- A command as one line of the log: the word "command", then name=value pairs
-- with the tick, verb, team and player first and the arguments after them in
-- sorted order. Numbers are written so they read back to the same bits.
local function command_line(command)
  local parts = {"command", "tick=" .. command.tick, "verb=" .. command.verb,
                 "team=" .. command.team, "player=" .. (command.player or 0)}
  local rest = {}
  for key in pairs(command) do
    if key ~= "tick" and key ~= "verb" and key ~= "team" and key ~= "player" then
      rest[#rest + 1] = key
    end
  end
  table.sort(rest)
  for _, key in ipairs(rest) do
    parts[#parts + 1] = key .. "=" .. string.format("%.17g", command[key])
  end
  return table.concat(parts, " ")
end
-- }}}

-- {{{ function M.record()
-- Starts a replay log at `path`, replacing whatever was there: the header, then
-- every command already waiting in the queue. From then on the door writes each
-- command it accepts, and the snapshot row writes every fingerprint it takes.
function M.record(world, path, commands)
  local handle, problem = io.open(path, "w")
  if handle == nil then
    error("snapshot: cannot write the replay log " .. path .. ": " .. tostring(problem), 2)
  end
  handle:write(FORMAT, "\n")
  handle:write("seed ", string.format("%.17g", world.seed), "\n")
  handle:write("stamp ", string.format("%08x", M.stamp(world)), "\n")
  handle:write("rate ", world.rule.ticks_per_second, "\n")
  handle:write("every ", world.rule.fingerprint_every, "\n")
  handle:close()
  world.record_path = path
  if commands ~= nil then
    for row = 1, world.command.count do
      append(path, command_line(commands.unpack(world, row)))
    end
  end
end
-- }}}

-- {{{ function M.note_command()
-- The door's hook: one accepted command onto the log being written.
function M.note_command(world, command)
  append(world.record_path, command_line(command))
end
-- }}}

-- {{{ function M.snapshot_pass()
-- The tick's last row. Every `fingerprint_every` ticks the world is
-- fingerprinted: the hash is kept as `world.fingerprint`, with the tick it was
-- taken in as `world.fingerprint_tick`, and when a log is being written it goes
-- into it as "hash <tick> <hex>". On other ticks the row does nothing, because a
-- fingerprint folds every cell and its cost grows with the field.
function M.snapshot_pass(world)
  if world.tick % world.rule.fingerprint_every ~= 0 then
    return
  end
  local hash = M.hash(world)
  world.fingerprint = hash
  world.fingerprint_tick = world.tick
  if world.record_path ~= "" then
    append(world.record_path, string.format("hash %d %08x", world.tick, hash))
  end
end
-- }}}

-- {{{ local function parse_command()
-- A "command ..." line back into a command table.
local function parse_command(line, number, path)
  local command = {}
  for key, value in line:gmatch("(%S+)=(%S+)") do
    if key == "verb" then
      command.verb = value
    else
      local parsed = tonumber(value)
      if parsed == nil then
        error(string.format("snapshot: %s line %d: '%s' is not a number for %s", path, number,
                            value, key), 3)
      end
      command[key] = parsed
    end
  end
  for _, key in ipairs({"tick", "verb", "team", "player"}) do
    if command[key] == nil then
      error(string.format("snapshot: %s line %d: a command without %s", path, number, key), 3)
    end
  end
  return command
end
-- }}}

-- {{{ function M.replay()
-- A replay log read back: the seed, the stamp, the rate, how often hashes were
-- written, the commands in the order they were accepted, and the hashes as
-- {tick, hash} pairs in order. A line that is none of these is refused, naming
-- the file and the line.
function M.replay(path)
  local handle, problem = io.open(path, "r")
  if handle == nil then
    error("snapshot: cannot read the replay log " .. path .. ": " .. tostring(problem), 2)
  end
  local log = {commands = {}, hashes = {}}
  local number = 0
  for line in handle:lines() do
    number = number + 1
    local word, rest = line:match("^(%S+)%s*(.*)$")
    if number == 1 then
      -- The first line names the format, so a log from some other program, or
      -- from a later version of this one, is refused before anything is read.
      if line ~= FORMAT then
        handle:close()
        error("snapshot: " .. path .. " is not a replay log this version reads: '" .. line .. "'", 2)
      end
    elseif word == "seed" or word == "rate" or word == "every" then
      log[word] = tonumber(rest)
    elseif word == "stamp" then
      log.stamp = tonumber(rest, 16)
    elseif word == "command" then
      log.commands[#log.commands + 1] = parse_command(line, number, path)
    elseif word == "hash" then
      local tick, hex = rest:match("^(%d+) (%x+)$")
      if tick == nil then
        handle:close()
        error(string.format("snapshot: %s line %d: a hash line without a tick and a hash", path, number), 2)
      end
      log.hashes[#log.hashes + 1] = {tick = tonumber(tick), hash = tonumber(hex, 16)}
    else
      handle:close()
      error(string.format("snapshot: %s line %d is not part of a replay: '%s'", path, number, line), 2)
    end
  end
  handle:close()
  for _, key in ipairs({"seed", "stamp", "rate", "every"}) do
    if log[key] == nil then
      error("snapshot: " .. path .. " has no " .. key .. " line", 2)
    end
  end
  return log
end
-- }}}

return M
