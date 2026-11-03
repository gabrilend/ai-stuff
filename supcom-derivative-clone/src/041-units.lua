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

-- 041-units.lua
--
-- A unit is one row across the world's flat arrays.
--
-- Every unit on the field -- tank, anti-air gun, helicopter, frigate, command
-- truck, enforcer -- is one row of the world's `unit` group: no class, no
-- per-kind record. A frigate is a tank with another domain and another row in
-- the catalogue. This module owns the two things that make a row: the unit
-- catalogue, loaded once, validated, and with every time it gives in seconds
-- turned into ticks; and `spawn`, which copies what a unit will read constantly
-- out of the catalogue into its own row at birth, so nothing it does later
-- reaches back to the catalogue, its factory, or its team.
--
-- Zero is the sentinel: a tank's shield is zero, a unit with nothing to shoot
-- has a target of zero. Rows are never compacted mid-tick; death (issue 208)
-- releases a row and nothing moves.

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
    error("units: wants exactly one NNN-the-world.lua beside it, and found " .. #found, 2)
  end
  if package.loaded[found[1]] == nil then
    package.loaded[found[1]] = dofile(found[1])
  end
  return package.loaded[found[1]]
end
-- }}}

local world_module = the_world()
local timers = world_module.load("timers")
local domains = world_module.load("domains")

-- The domains, by integer and by name, and a weapon's reach as bits over them
-- (1 land, 2 air, 4 sea): the domains module's, so the catalogue and the row
-- share one meaning.
M.DOMAINS = domains.DOMAINS
M.DOMAIN_NAMES = domains.NAMES
M.REACH = domains.REACH

-- Every field a catalogue row carries, its type, and for a time in seconds the
-- name of the field in ticks the loader adds beside it. A row with a field
-- missing, a field of another type, or a field not listed here is refused.
M.FIELDS = {
  {"index", "integer"}, {"name", "name"}, {"domain", "integer"}, {"reaches", "integer"},
  {"tier", "integer"}, {"health", "integer"}, {"damage", "integer"},
  {"falloff_full", "double"}, {"falloff_floor", "double"}, {"falloff_end", "double"},
  {"shell_speed", "double"},
  {"reload_seconds", "double", "reload_ticks"}, {"heal_period", "double", "heal_ticks"},
  {"speed", "double"}, {"climb", "double"}, {"eye", "double"}, {"profile", "double"}, {"altitude", "double"},
  {"claim_radius", "integer"}, {"shield", "integer"},
  {"shield_seconds", "double", "shield_ticks"}, {"cost_mass", "integer"},
  {"cost_energy", "integer"}, {"build_seconds", "double", "build_ticks"},
}

-- {{{ local function refuse()
-- A catalogue refusal, naming the row and the field.
local function refuse(kind, field, problem)
  error("the unit catalogue: " .. tostring(kind) .. "." .. field .. " " .. problem, 0)
end
-- }}}

-- {{{ local function ticks()
-- A time in seconds as whole ticks at the rate. Zero stays zero -- a kind with no
-- weapon has no reload -- and anything else must come to at least one tick.
local function ticks(kind, field, seconds, rate)
  if seconds == 0 then
    return 0
  end
  local ok, result = pcall(timers.ticks_of, seconds, rate)
  if not ok then
    refuse(kind, field, "is " .. seconds .. " seconds, which is not a whole tick at "
           .. rate .. " ticks a second")
  end
  return result
end
-- }}}

-- {{{ local function check_row()
-- One row: every field present and of its type, nothing extra, and every value
-- in range. Returns a converted copy with the tick fields beside the seconds.
local function check_row(name, row, rate)
  if type(row) ~= "table" then
    refuse(name, "row", "is a " .. type(row) .. ", not a table")
  end
  local known = {}
  local copy = {}
  for _, field in ipairs(M.FIELDS) do
    local key, kind = field[1], field[2]
    known[key] = true
    local value = row[key]
    if kind == "name" then
      if type(value) ~= "string" or value == "" then
        refuse(name, key, "is " .. tostring(value) .. ", not a name")
      end
    else
      if type(value) ~= "number" or value ~= value or value < 0 then
        refuse(name, key, "is " .. tostring(value) .. ", not a number from zero")
      end
      if kind == "integer" and value ~= math.floor(value) then
        refuse(name, key, "is " .. value .. ", not a whole number")
      end
    end
    copy[key] = value
  end
  for key in pairs(row) do
    if not known[key] then
      refuse(name, tostring(key), "is not a field the catalogue knows")
    end
  end
  if row.name ~= name then
    refuse(name, "name", "is '" .. row.name .. "', but the row is filed under '" .. name .. "'")
  end
  if M.DOMAIN_NAMES[row.domain] == nil then
    refuse(name, "domain", "is " .. row.domain .. ", not 1 (land), 2 (air) or 3 (sea)")
  end
  if row.tier < 1 or row.tier > 3 then
    refuse(name, "tier", "is " .. row.tier .. ", not 1, 2, or 3 (experimental)")
  end
  if row.health < 1 then
    refuse(name, "health", "is zero; a unit that is born dead is not a unit")
  end
  if row.reaches > 7 then
    refuse(name, "reaches", "is " .. row.reaches .. ", which names a domain past sea (4)")
  end
  -- A weapon is all of a piece: damage, somewhere to reach, a shell that moves,
  -- a reload. A kind with no weapon (the truck) has none of them.
  if row.damage > 0 then
    if row.reaches == 0 then
      refuse(name, "reaches", "is empty, but the kind has a weapon")
    end
    if row.shell_speed <= 0 then
      refuse(name, "shell_speed", "is zero, but the kind has a weapon")
    end
    if row.reload_seconds <= 0 then
      refuse(name, "reload_seconds", "is zero, but the kind has a weapon")
    end
    if row.falloff_end < row.falloff_full then
      refuse(name, "falloff_end", "is " .. row.falloff_end .. ", nearer than falloff_full "
             .. row.falloff_full .. "; the decline cannot end before it begins")
    end
  elseif row.reaches ~= 0 then
    refuse(name, "reaches", "is " .. row.reaches .. ", but the kind has no damage")
  end
  if row.falloff_floor > 1 then
    refuse(name, "falloff_floor", "is " .. row.falloff_floor .. ", not a fraction from zero to one")
  end
  if row.heal_period <= 0 then
    refuse(name, "heal_period", "is zero; every kind heals on its own counter")
  end
  if (row.shield > 0) ~= (row.shield_seconds > 0) then
    refuse(name, "shield_seconds", "is " .. row.shield_seconds .. " with a shield of " .. row.shield
           .. "; a shield and its recharge come together")
  end
  if (row.domain == M.DOMAINS.air) ~= (row.altitude > 0) then
    refuse(name, "altitude", "is " .. row.altitude .. "; a plane flies above the ground and"
           .. " nothing else does")
  end
  for _, field in ipairs(M.FIELDS) do
    if field[3] ~= nil then
      copy[field[3]] = ticks(name, field[1], row[field[1]], rate)
    end
  end
  return copy
end
-- }}}

-- {{{ function M.validate_catalogue()
-- A raw catalogue table, as the asset returns it, checked and converted at the
-- rate: refuses, naming the row and the field, anything that is not what the
-- catalogue's fields say, and indices that are not one to the number of kinds,
-- each once. Returns {by name = converted row, kinds = rows by index}.
function M.validate_catalogue(raw, rate)
  if type(raw) ~= "table" then
    error("the unit catalogue: is a " .. type(raw) .. ", not a table of rows", 0)
  end
  local names = {}
  for name in pairs(raw) do
    if type(name) ~= "string" then
      error("the unit catalogue: a row is filed under " .. tostring(name) .. ", not a name", 0)
    end
    names[#names + 1] = name
  end
  table.sort(names)
  local catalogue = {kinds = {}}
  for _, name in ipairs(names) do
    local row = check_row(name, raw[name], rate)
    if catalogue.kinds[row.index] ~= nil then
      refuse(name, "index", "is " .. row.index .. ", which " .. catalogue.kinds[row.index].name
             .. " already has")
    end
    catalogue.kinds[row.index] = row
    catalogue[name] = row
  end
  for index = 1, #names do
    if catalogue.kinds[index] == nil then
      error("the unit catalogue: no kind has the index " .. index .. "; indices run from one to "
            .. #names .. " with no gaps", 0)
    end
  end
  if catalogue.kinds[0] ~= nil then
    refuse(catalogue.kinds[0].name, "index", "is zero, which means no kind")
  end
  return catalogue
end
-- }}}

local loaded = nil

-- {{{ function M.catalogue()
-- The match's catalogue, loaded and validated once, at the rules' tick rate.
function M.catalogue()
  if loaded == nil then
    local rules = world_module.load_asset("the-rules")
    loaded = M.validate_catalogue(world_module.load_asset("unit-catalogue"), rules.ticks_per_second)
  end
  return loaded
end
-- }}}

-- {{{ function M.kind()
-- A kind's converted row, by name or by index; refuses an unknown one by name.
function M.kind(kind)
  local catalogue = M.catalogue()
  local row
  if type(kind) == "number" then
    row = catalogue.kinds[kind]
  elseif type(kind) == "string" then
    row = catalogue[kind]
    if kind == "kinds" then row = nil end
  end
  if row == nil then
    error("units: the catalogue has no kind '" .. tostring(kind) .. "'", 2)
  end
  return row
end
-- }}}

-- {{{ function M.index_of()
function M.index_of(name)
  return M.kind(name).index
end
-- }}}

-- {{{ function M.name_of()
function M.name_of(index)
  return M.kind(index).name
end
-- }}}

-- {{{ function M.counters()
-- The periodic effects the catalogue asks for, as rows the world adds to its
-- counter table at allocation: one heal counter per kind under `heal.<name>`,
-- one reload counter per kind with a weapon under `reload.<name>`, and one
-- recharge counter per kind with a shield under `recharge.<name>`. In index
-- order, so every world lays its counters out the same way.
function M.counters()
  local rows = {}
  local kinds = M.catalogue().kinds
  for index = 1, #kinds do
    local row = kinds[index]
    rows[#rows + 1] = {path = {"heal", row.name}, ticks = row.heal_ticks, extra = {}}
  end
  for index = 1, #kinds do
    local row = kinds[index]
    if row.damage > 0 then
      rows[#rows + 1] = {path = {"reload", row.name}, ticks = row.reload_ticks, extra = {}}
    end
  end
  for index = 1, #kinds do
    local row = kinds[index]
    if row.shield > 0 then
      rows[#rows + 1] = {path = {"recharge", row.name}, ticks = row.shield_ticks, extra = {}}
    end
  end
  return rows
end
-- }}}

-- {{{ function M.spawn()
-- A new unit of a kind, for a team, at a position, as its row's id. Everything
-- the unit reads constantly is copied out of the catalogue now; its health is
-- the cap, written at the increment of now on its kind's heal counter, and an
-- enforcer's shield the same on its recharge counter. Refuses, by name, a kind
-- the catalogue does not have, a team the world does not have, and a full
-- world.
function M.spawn(world, kind, team, x, y)
  local catalogue = M.catalogue()
  local row = (type(kind) == "string" and kind ~= "kinds") and catalogue[kind] or nil
  if row == nil then
    error("units: cannot spawn '" .. tostring(kind) .. "': the catalogue has no such kind", 2)
  end
  if type(team) ~= "number" or team ~= math.floor(team) or team < 1 or team > world.team.capacity then
    error("units: cannot spawn a " .. kind .. " for team " .. tostring(team) .. "; this world has teams 1 to "
          .. world.team.capacity, 2)
  end
  if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y then
    error("units: cannot spawn a " .. kind .. " at (" .. tostring(x) .. ", " .. tostring(y) .. ")", 2)
  end
  local stands, fine = pcall(domains.can_stand, world.field, row.domain, x, y)
  if not stands then
    error("units: cannot spawn a " .. kind .. ": " .. tostring(fine), 2)
  end
  if not fine then
    error(string.format("units: cannot spawn a %s at (%g, %g): a %s unit may not stand there",
                        kind, x, y, M.DOMAIN_NAMES[row.domain]), 2)
  end
  local ok, id = pcall(world_module.claim, world, "unit")
  if not ok then
    error("units: cannot spawn a " .. kind .. ": " .. tostring(id), 2)
  end
  local unit = world.unit
  unit.kind[id] = row.index
  unit.team[id] = team
  unit.x[id] = x
  unit.y[id] = y
  unit.domain[id] = row.domain
  unit.altitude[id] = domains.altitude_at(world.field, row.index, x, y)
  unit.health[id] = row.health
  local heal = world.heal[row.name]
  timers.advance(heal, world.tick)
  unit.health_at[id] = heal.increment
  unit.damage[id] = row.damage
  unit.falloff[id] = row.index
  unit.eye[id] = row.eye
  unit.profile[id] = row.profile
  unit.claim_radius[id] = row.claim_radius
  if row.shield > 0 then
    local recharge = world.recharge[row.name]
    timers.advance(recharge, world.tick)
    unit.shield[id] = row.shield
    unit.shield_at[id] = recharge.increment
  end
  return id
end
-- }}}

-- {{{ function M.alive()
-- How many units are alive: the pool's live count, kept, never re-counted.
function M.alive(world)
  return world.unit.count
end
-- }}}

-- {{{ function M.validate()
-- The unit rows' own check, called from the world's validator: every live row's
-- kind is a catalogue row, its domain is that row's, and its team is a team of
-- the world; every released row is zero in `alive`. The world's validator has
-- already refused anything that is not a number. A live row of kind zero is a
-- row claimed from the world and not yet filled -- zero is nothing -- which only
-- `spawn` and the world's own tests make; it is let through.
function M.validate(world)
  local unit = world.unit
  local kinds = M.catalogue().kinds
  for id = 1, unit.top do
    if unit.alive[id] == 1 and unit.kind[id] ~= 0 then
      local row = kinds[unit.kind[id]]
      if row == nil then
        error("units: row " .. id .. " is alive with kind " .. unit.kind[id]
              .. ", which the catalogue does not have", 2)
      end
      if unit.domain[id] ~= row.domain then
        error("units: row " .. id .. " is a " .. row.name .. " in domain " .. unit.domain[id]
              .. ", not its catalogue's " .. row.domain, 2)
      end
      if unit.team[id] < 1 or unit.team[id] > world.team.capacity then
        error("units: row " .. id .. " belongs to team " .. unit.team[id] .. ", not a team of this world", 2)
      end
    elseif unit.alive[id] ~= 0 and unit.alive[id] ~= 1 then
      error("units: row " .. id .. " has alive " .. unit.alive[id] .. ", not one or zero", 2)
    end
    -- A pattern is named by its number and walked by its leg, the point the
    -- unit is heading for; one past the last point means it holds.
    local pattern = unit.pattern[id]
    if unit.alive[id] == 1 and pattern ~= 0 then
      local points = world.pattern.points[pattern]
      if pattern < 0 or pattern > world.pattern.count or points == nil then
        error("units: row " .. id .. " follows pattern " .. pattern .. ", which the world does not have", 2)
      end
      if unit.leg[id] < 1 or unit.leg[id] > #points + 1 then
        error("units: row " .. id .. " is on leg " .. unit.leg[id] .. " of a pattern of "
              .. #points .. " points", 2)
      end
    end
  end
  domains.validate(world)
end
-- }}}

-- {{{ function M.dump()
-- One row as text, every field in layout order, for a viewer or a failed test.
function M.dump(world, id)
  local unit = world.unit
  local parts = {}
  for _, row in ipairs(world.layout.groups) do
    if row.group == "unit" then
      for _, field in ipairs(row.fields) do
        parts[#parts + 1] = field[1] .. "=" .. tostring(unit[field[1]][id])
      end
    end
  end
  local kind = M.catalogue().kinds[unit.kind[id]]
  return "unit " .. id .. " (" .. (kind and kind.name or "no kind") .. "): " .. table.concat(parts, " ")
end
-- }}}

-- {{{ function M.report()
-- The catalogue as text: every kind's row in index order, then the relations
-- the vision states, in tank shells, then each kind's heal rhythm in ticks and
-- seconds (issue 207). The tool a document points at instead of
-- quoting a number.
function M.report()
  local kinds = M.catalogue().kinds
  local lines = {}
  local shell = M.catalogue().tank.damage
  for index = 1, #kinds do
    local row = kinds[index]
    local fields = {}
    for _, field in ipairs(M.FIELDS) do
      fields[#fields + 1] = field[1] .. "=" .. tostring(row[field[1]])
      if field[3] ~= nil then
        fields[#fields + 1] = field[3] .. "=" .. tostring(row[field[3]])
      end
    end
    lines[#lines + 1] = table.concat(fields, " ")
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "hits to kill, in tank shells of " .. shell .. ":"
  for index = 1, #kinds do
    local row = kinds[index]
    local text = string.format("  %-14s %d", row.name, math.ceil(row.health / shell))
    if row.shield > 0 then
      text = text .. string.format(", and %d more for its shield", math.ceil(row.shield / shell))
    end
    lines[#lines + 1] = text
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "heal rhythm, one point back per period of the kind's own counter:"
  for index = 1, #kinds do
    local row = kinds[index]
    lines[#lines + 1] = string.format("  %-14s every %d ticks (%g s), %d ticks from nothing to %d",
                                      row.name, row.heal_ticks, row.heal_period,
                                      row.heal_ticks * row.health, row.health)
  end
  return table.concat(lines, "\n") .. "\n"
end
-- }}}

return M
