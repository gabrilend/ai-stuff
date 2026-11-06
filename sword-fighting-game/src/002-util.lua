-- 002-util.lua
--
-- The handful of small things every other file needs: stopping loudly, the
-- arithmetic of angles and plain-number vectors, copying tables, and laying
-- the person's config.lua over the defaults.
--
-- Vectors are passed as two numbers, never as tables, so the simulation's
-- tick allocates nothing it does not have to.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

local TAU = math.pi * 2
M.TAU = TAU

-- Stops the program with a message that says which program is speaking.
-- Used wherever the project prefers an error to a guess.
-- {{{ function M.die()
function M.die(fmt, ...)
	error("sword-fighting-game: " .. string.format(fmt, ...), 2)
end
-- }}}

-- {{{ function M.clamp()
function M.clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end
-- }}}

-- {{{ function M.lerp()
function M.lerp(a, b, t)
	return a + (b - a) * t
end
-- }}}

-- {{{ function M.sign()
function M.sign(v)
	if v > 0 then return 1 end
	if v < 0 then return -1 end
	return 0
end
-- }}}

-- Brings an angle into (-pi, pi], so the difference of two facings is the
-- short way round.
-- {{{ function M.wrap_angle()
function M.wrap_angle(a)
	a = a % TAU
	if a > math.pi then a = a - TAU end
	return a
end
-- }}}

-- {{{ function M.length()
function M.length(x, y)
	return math.sqrt(x * x + y * y)
end
-- }}}

-- {{{ function M.distance()
function M.distance(ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	return math.sqrt(dx * dx + dy * dy)
end
-- }}}

-- A zero vector stays zero: "no direction" is a real answer for a soldier
-- that wishes to stand still, not an error.
-- {{{ function M.normalize()
function M.normalize(x, y)
	local l = math.sqrt(x * x + y * y)
	if l == 0 then return 0, 0 end
	return x / l, y / l
end
-- }}}

-- The angle from a to b on the map: 0 is east, and angles grow clockwise on
-- screen because map y grows southward.
-- {{{ function M.bearing()
function M.bearing(ax, ay, bx, by)
	return math.atan2(by - ay, bx - ax)
end
-- }}}

-- {{{ function M.deep_copy()
function M.deep_copy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = M.deep_copy(v) end
	return out
end
-- }}}

-- Keys in a stable order, because iteration order of a hash part is not
-- something a deterministic simulation may depend on.
-- {{{ function M.sorted_keys()
function M.sorted_keys(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	return keys
end
-- }}}

-- {{{ local function is_list()
local function is_list(t)
	return #t > 0 or next(t) == nil
end
-- }}}

-- Lays `over` onto `base` in place. A key in `over` that `base` does not have
-- is an error naming its dotted path: a typo in config.lua must never quietly
-- do nothing. Lists (the key tables) are replaced whole rather than merged,
-- because a person rebinding keys means "these keys", not "these as well".
-- {{{ function M.merge_strict()
function M.merge_strict(base, over, where)
	for _, k in ipairs(M.sorted_keys(over)) do
		local path = where .. "." .. tostring(k)
		local v = over[k]
		if base[k] == nil then
			M.die("%s is not a knob the defaults have", path)
		end
		if type(v) ~= type(base[k]) then
			M.die("%s should be a %s, not a %s", path, type(base[k]), type(v))
		end
		-- a nested section merges knob by knob; a list or a plain value replaces
		if type(v) == "table" and not is_list(base[k]) then
			M.merge_strict(base[k], v, path)
		else
			base[k] = v
		end
	end
	return base
end
-- }}}

-- Runs a data file in an empty environment and returns what it returns. The
-- file can compute (it is Lua) but can touch nothing outside itself.
-- {{{ function M.load_data_file()
function M.load_data_file(path)
	local chunk, err = loadfile(path)
	if not chunk then M.die("cannot read %s: %s", path, err) end
	setfenv(chunk, { math = math, string = string, table = table, ipairs = ipairs,
		pairs = pairs })
	local ok, result = pcall(chunk)
	if not ok then M.die("%s failed while loading: %s", path, result) end
	if type(result) ~= "table" then
		M.die("%s must return a table, it returned a %s", path, type(result))
	end
	return result
end
-- }}}

-- {{{ function M.file_exists()
function M.file_exists(path)
	local f = io.open(path, "r")
	if f then f:close() return true end
	return false
end
-- }}}

-- The defaults, with config.lua at the project root laid over them when it
-- exists. No config.lua is the ordinary case: the defaults are the design.
-- {{{ function M.load_config()
function M.load_config(dir)
	local config = M.load_data_file(dir .. "/src/001-config.def.lua")
	local person = dir .. "/config.lua"
	if M.file_exists(person) then
		M.merge_strict(config, M.load_data_file(person), "config")
	end
	return config
end
-- }}}

-- The names in a folder that end with a suffix, sorted. Uses ls because plain
-- Lua cannot list a folder; a missing folder lists as empty, since every
-- caller treats "no files" as "nothing to add".
-- {{{ function M.list_files()
function M.list_files(dir, suffix)
	local names = {}
	local p = io.popen('[ -d "' .. dir .. '" ] && ls -1 "' .. dir .. '"')
	for line in p:lines() do
		if suffix == nil or line:sub(-#suffix) == suffix then
			names[#names + 1] = line
		end
	end
	p:close()
	table.sort(names)
	return names
end
-- }}}

return M
