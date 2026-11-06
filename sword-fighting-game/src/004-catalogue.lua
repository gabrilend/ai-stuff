-- 004-catalogue.lua
--
-- Reads the data files the world is made of (assets/catalogue/), lays any
-- enabled mods over them (mods/<name>/), and checks every entry against its
-- schema before anything else runs, so a broken entry stops the program at
-- start-up with the file and field named, never in the middle of a round.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")

local M = {}

-- The four files, in the order they are checked: weapons first, because unit
-- types name weapons and perks name unit types and weapons.
M.FILES = { "weapons", "unit-types", "regions", "perks" }

local COLOR = { kind = "color" }
local SWING_KINDS = { stab = true, slash = true, overhead = true }

-- Field → what it must be. `ref` names another catalogue file the value must
-- be an entry of; `list` means a list whose items must each be that type.
M.SCHEMA = {
	weapons = {
		title = { type = "string" },
		reach = { type = "number" },
		swings = { type = "table", list = "swing" },
		damage = { type = "table", kind = "damage" },
		windup = { type = "number" },
		recovery = { type = "number" },
		brick_color = COLOR,
		length = { type = "number" },
	},
	["unit-types"] = {
		title = { type = "string" },
		weapon = { type = "string", ref = "weapons" },
		health = { type = "number" },
		armor = { type = "number" },
		thickness = { type = "number" },
		height = { type = "number" },
		traits = { type = "table", list = "string" },
	},
	regions = {
		title = { type = "string" },
		ground_color = COLOR,
		walk = { type = "number" },
		stones = { type = "number" },
		fences = { type = "number" },
		puddles = { type = "number" },
	},
	perks = {
		title = { type = "string" },
		text = { type = "string" },
		affects = { type = "any" },
		effect = { type = "string" },
		value = { type = "any" },
		limit = { type = "number" },
	},
}

-- {{{ local function check_color()
local function check_color(v, where)
	if type(v) ~= "table" or #v ~= 3 then
		util.die("catalogue: %s must be a list of three numbers 0..1", where)
	end
	for i = 1, 3 do
		if type(v[i]) ~= "number" then
			util.die("catalogue: %s[%d] must be a number", where, i)
		end
	end
end
-- }}}

-- {{{ local function check_damage()
local function check_damage(v, where)
	for kind in pairs(SWING_KINDS) do
		if type(v[kind]) ~= "number" then
			util.die("catalogue: %s.%s must be a number", where, kind)
		end
	end
end
-- }}}

-- {{{ local function check_list()
local function check_list(v, item, where)
	for i, x in ipairs(v) do
		-- a swing item must also be one of the three kinds the rules know
		if item == "swing" then
			if not SWING_KINDS[x] then
				util.die("catalogue: %s[%d] is not a swing kind: %s", where, i, tostring(x))
			end
		elseif type(x) ~= item then
			util.die("catalogue: %s[%d] must be a %s", where, i, item)
		end
	end
end
-- }}}

-- Special checks by kind of field, so a new kind is a new row.
local KIND_CHECKS = {
	color = check_color,
	damage = check_damage,
}

-- {{{ local function check_entry()
local function check_entry(file, name, entry, all)
	local schema = M.SCHEMA[file]
	local where = file .. "." .. name
	for field in pairs(entry) do
		if not schema[field] then
			util.die("catalogue: %s has a field the schema does not know: %s", where, field)
		end
	end
	for _, field in ipairs(util.sorted_keys(schema)) do
		local rule = schema[field]
		local v = entry[field]
		local path = where .. "." .. field
		if v == nil then util.die("catalogue: %s is missing", path) end
		if rule.kind then
			KIND_CHECKS[rule.kind](v, path)
		elseif rule.type ~= "any" and type(v) ~= rule.type then
			util.die("catalogue: %s must be a %s", path, rule.type)
		end
		if rule.list then check_list(v, rule.list, path) end
		if rule.ref and not all[rule.ref][v] then
			util.die("catalogue: %s names %s, which is not in %s", path, tostring(v), rule.ref)
		end
	end
end
-- }}}

-- Perks name unit types or weapons through their value, depending on the
-- effect, so they are checked once every file is known.
-- {{{ local function check_perk_refs()
local function check_perk_refs(cat)
	local refs = { convert_units = "unit-types", swap_weapon = "weapons" }
	for _, name in ipairs(util.sorted_keys(cat.perks)) do
		local perk = cat.perks[name]
		local file = refs[perk.effect]
		if file and not cat[file][perk.value] then
			util.die("catalogue: perks.%s.value names %s, which is not in %s",
				name, tostring(perk.value), file)
		end
		if perk.affects ~= "all" and type(perk.affects) ~= "number" then
			util.die("catalogue: perks.%s.affects must be \"all\" or a number", name)
		end
	end
end
-- }}}

-- Returns { weapons = {...}, ["unit-types"] = {...}, regions = {...},
-- perks = {...} }, each a table of entry name → entry.
-- {{{ function M.load()
function M.load(dir, mods)
	local cat = {}
	for _, file in ipairs(M.FILES) do
		cat[file] = util.load_data_file(dir .. "/assets/catalogue/" .. file .. ".lua")
	end
	-- mods lay their entries over the shipped ones, whole entry by whole entry
	for _, mod in ipairs(mods or {}) do
		local folder = dir .. "/mods/" .. mod
		local found = false
		for _, file in ipairs(M.FILES) do
			local path = folder .. "/" .. file .. ".lua"
			if util.file_exists(path) then
				found = true
				for name, entry in pairs(util.load_data_file(path)) do
					cat[file][name] = entry
				end
			end
		end
		if not found then
			util.die("catalogue: mod %s has no catalogue files in %s", mod, folder)
		end
	end
	for _, file in ipairs(M.FILES) do
		for _, name in ipairs(util.sorted_keys(cat[file])) do
			check_entry(file, name, cat[file][name], cat)
		end
	end
	check_perk_refs(cat)
	return cat
end
-- }}}

return M
