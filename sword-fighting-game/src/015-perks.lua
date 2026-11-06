-- 015-perks.lua
--
-- Perks taken in the command phase, laid on a contingent when its battle is
-- set up. Each perk names an effect, and the effects are rows in a table;
-- a new kind of perk is a new row, plus a catalogue entry that names it.
--
-- A perk that affects "a certain amount of guys" converts soldiers from the
-- back ranks first. The player always chooses whether to be one of them; if
-- the perk converts nobody of the player's kind, the player is just a normal
-- soldier and is not asked.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local soldier_m = require("006-soldier")

local M = {}

-- The soldiers a conversion may take: base swordsmen of the team, back ranks
-- first, then by id, so the same perk always takes the same soldiers.
-- {{{ local function base_swordsmen()
local function base_swordsmen(battle, team)
	local list = {}
	for _, s in ipairs(battle.soldiers) do
		if s.team == team and s.unit == "swordsman" then list[#list + 1] = s end
	end
	table.sort(list, function(a, b)
		if a.slot_y ~= b.slot_y then return a.slot_y > b.slot_y end
		return a.id < b.id
	end)
	return list
end
-- }}}

-- {{{ local function each_soldier()
local function each_soldier(battle, team, fn)
	for _, s in ipairs(battle.soldiers) do
		if s.team == team then fn(s) end
	end
end
-- }}}

local EFFECTS = {}

-- The player first if they chose to be affected, then from the back ranks.
-- {{{ function EFFECTS.convert_units()
function EFFECTS.convert_units(battle, team, perk, choice)
	local pool = base_swordsmen(battle, team)
	local chosen = {}
	local player = battle.player
	if choice.be_affected and player and player.team == team and player.unit == "swordsman" then
		chosen[1] = player
	end
	for _, s in ipairs(pool) do
		if #chosen >= perk.affects then break end
		-- the player is taken only by their own choice
		if not s.is_player then chosen[#chosen + 1] = s end
	end
	for _, s in ipairs(chosen) do
		s.weapon_override = nil
		soldier_m.become(s, battle.catalogue, battle.config, perk.value)
		s.health = s.health_max
	end
	return #chosen
end
-- }}}

-- Only base swordsmen trade weapons; converted units keep their own.
-- {{{ function EFFECTS.swap_weapon()
function EFFECTS.swap_weapon(battle, team, perk)
	each_soldier(battle, team, function(s)
		if s.unit == "swordsman" then
			s.weapon_override = perk.value
			soldier_m.become(s, battle.catalogue, battle.config, s.unit)
		end
	end)
end
-- }}}

-- {{{ function EFFECTS.add_trait()
function EFFECTS.add_trait(battle, team, perk)
	each_soldier(battle, team, function(s)
		s.perk_traits[perk.value] = true
		soldier_m.refresh(s, battle.config)
	end)
end
-- }}}

-- {{{ function EFFECTS.add_armor()
function EFFECTS.add_armor(battle, team, perk)
	each_soldier(battle, team, function(s)
		s.extra_armor = s.extra_armor + perk.value
		soldier_m.refresh(s, battle.config)
	end)
end
-- }}}

-- {{{ function EFFECTS.thicken()
function EFFECTS.thicken(battle, team)
	each_soldier(battle, team, function(s)
		s.thick_override = true
		soldier_m.refresh(s, battle.config)
	end)
end
-- }}}

-- {{{ function EFFECTS.unlock_ranges()
function EFFECTS.unlock_ranges(battle, team)
	battle.trained_arc[team] = true
end
-- }}}

-- {{{ function EFFECTS.crit_chance()
function EFFECTS.crit_chance(battle, team, perk)
	each_soldier(battle, team, function(s)
		s.crit_chance = s.crit_chance + perk.value
	end)
end
-- }}}

M.EFFECTS = EFFECTS

-- `taken` is the list of { name = perk name, be_affected = boolean } in the
-- order the perks were picked. An unknown perk or effect is an error.
-- {{{ function M.apply()
function M.apply(battle, team, taken)
	for _, choice in ipairs(taken) do
		local perk = battle.catalogue.perks[choice.name]
		if not perk then error("no perk named " .. tostring(choice.name)) end
		local effect = EFFECTS[perk.effect]
		if not effect then
			error("perk " .. choice.name .. " names unknown effect " .. perk.effect)
		end
		effect(battle, team, perk, choice)
	end
end
-- }}}

-- {{{ function M.times_taken()
function M.times_taken(taken, name)
	local n = 0
	for _, choice in ipairs(taken) do
		if choice.name == name then n = n + 1 end
	end
	return n
end
-- }}}

-- The perk cards for a command phase: drawn without repeats from the perks
-- this side has not used up.
-- {{{ function M.offer()
function M.offer(catalogue, taken, stream, count)
	local open = {}
	local names = {}
	for name in pairs(catalogue.perks) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		if M.times_taken(taken, name) < catalogue.perks[name].limit then open[#open + 1] = name end
	end
	local cards = {}
	while #cards < count and #open > 0 do
		local k = stream:between(1, #open)
		cards[#cards + 1] = table.remove(open, k)
	end
	return cards
end
-- }}}

-- Whether a perk asks the player "be one of them?": only the ones that
-- convert a number of soldiers.
-- {{{ function M.asks_player()
function M.asks_player(catalogue, name)
	local perk = catalogue.perks[name]
	return perk.effect == "convert_units"
end
-- }}}

return M
