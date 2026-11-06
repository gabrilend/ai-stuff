-- 011-hit-resolution.lua
--
-- What happens when a swing strikes. The steps run in one fixed order, and
-- each either ends the resolution or passes it on:
--
--   reach -> parry -> flank -> critical -> damage -> effect
--
-- A volley's dart (013-ranged.lua) joins the same order at the parry step,
-- with its own parry bonus, so a thrown weapon and a sword obey one set of
-- rules about armor, criticals and falling.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")
local field_m = require("005-battlefield")
local stamina = require("007-stamina")

local M = {}

-- {{{ local function emit()
local function emit(battle, event)
	battle.events[#battle.events + 1] = event
end
-- }}}

-- How far, in radians, a point lies off a soldier's facing: 0 dead ahead,
-- pi directly behind.
-- {{{ local function off_facing()
local function off_facing(of, from_x, from_y)
	local b = util.bearing(of.x, of.y, from_x, from_y)
	return math.abs(util.wrap_angle(b - of.facing))
end
-- }}}

M.off_facing = off_facing

-- Whether t turns the blow aside. Only a soldier standing, guarding, not
-- open after an overhead, and not struck from behind may try.
-- {{{ function M.parry_roll()
function M.parry_roll(battle, t, bonus, from_x, from_y, stream)
	local c = battle.config
	if not t.guard or t.tripped > 0 or t.open > 0 then return false end
	if off_facing(t, from_x, from_y) > c.hits.behind_angle then return false end
	battle.counters.parry_attempts = battle.counters.parry_attempts + 1
	local chance = stamina.parry_chance(t.stamina, c, t.traits.bushido) + bonus
	return stream:chance(chance)
end
-- }}}

-- The effect step, shared with volleys: health falls, the target reels, a
-- windup in progress is lost, and at zero the soldier falls and frees its cell.
-- {{{ function M.apply_damage()
function M.apply_damage(battle, t, damage, attacker)
	local c = battle.config
	t.health = t.health - damage
	t.stagger = c.hits.stagger_hit
	t.hurt_flash = 1
	if t.swing and not t.swing.struck then t.swing = false end
	if t.health > 0 then return end
	t.alive = false
	t.guard, t.swing, t.yield, t.dodge = false, false, false, false
	field_m.release(battle.field, t)
	battle.counters.falls = battle.counters.falls + 1
	emit(battle, { kind = "fall", who = t, by = attacker })
end
-- }}}

-- The share of damage armor lets through.
-- {{{ function M.armor_share()
function M.armor_share(battle, t)
	local h = battle.config.hits
	return 1 - math.min(h.armor_cap, t.armor * h.armor_per_point)
end
-- }}}

-- The steps. Each takes the context and returns true to carry on.
local STEPS = {}

-- The target must be alive, within reach, and in front of the attacker.
-- {{{ function STEPS.reach()
function STEPS.reach(battle, ctx)
	local a, t, c = ctx.a, ctx.t, battle.config
	if not t or not t.alive then return false end
	local reach = a.weapon.reach + c.swings[ctx.swing.kind].reach + c.body.radius
	if util.distance(a.x, a.y, t.x, t.y) > reach then return false end
	return off_facing(a, t.x, t.y) <= c.sword.strike_arc
end
-- }}}

-- A successful parry costs both soldiers stamina and staggers the attacker.
-- A riposte answers it at once with a quick stab.
-- {{{ function STEPS.parry()
function STEPS.parry(battle, ctx)
	local a, t, c = ctx.a, ctx.t, battle.config
	local bonus = 0
	if t.traits.shield then bonus = bonus + c.hits.shield_parry end
	if battle.shields[t.team] then bonus = bonus + c.hits.shield_parry end
	if not M.parry_roll(battle, t, bonus, a.x, a.y, battle.streams.hits) then
		return true
	end
	stamina.spend(t, c.stamina.parry_cost)
	stamina.spend(a, c.stamina.parried_cost)
	a.stagger = c.hits.stagger_parried
	battle.counters.parries = battle.counters.parries + 1
	emit(battle, { kind = "parry", who = t, by = a })
	if t.traits.riposte then
		t.guard = false
		battle.ripostes[#battle.ripostes + 1] = t
	end
	return false
end
-- }}}

-- {{{ function STEPS.flank()
function STEPS.flank(battle, ctx)
	ctx.flank = off_facing(ctx.t, ctx.a.x, ctx.a.y) > battle.config.hits.flank_angle
	return true
end
-- }}}

-- The causes of a critical hit, in the order they are credited: the first
-- that holds is the one the statistics count.
local CAUSES = {
	{ "momentum", function(battle, ctx)
		return ctx.swing.momentum >= battle.config.hits.critical_momentum end },
	{ "flank", function(_, ctx) return ctx.flank end },
	{ "trait", function(_, ctx) return ctx.a.traits.always_critical end },
	{ "chance", function(_, ctx) return ctx.rolled end },
}

-- The chance roll is always drawn, so the hits stream advances the same way
-- whatever the other causes were.
-- {{{ function STEPS.critical()
function STEPS.critical(battle, ctx)
	ctx.rolled = battle.streams.hits:chance(ctx.a.crit_chance)
	for _, row in ipairs(CAUSES) do
		if row[2](battle, ctx) then
			ctx.cause = row[1]
			return true
		end
	end
	return true
end
-- }}}

-- {{{ function STEPS.damage()
function STEPS.damage(battle, ctx)
	local a, t, c = ctx.a, ctx.t, battle.config
	local kind = ctx.swing.kind
	local d = a.weapon.damage[kind] * c.swings[kind].damage
	if ctx.cause then d = d * c.hits.critical_mult end
	ctx.damage = d * M.armor_share(battle, t)
	return true
end
-- }}}

-- {{{ function STEPS.effect()
function STEPS.effect(battle, ctx)
	local counters = battle.counters
	counters.hits = counters.hits + 1
	if ctx.cause then
		counters.criticals = counters.criticals + 1
		local key = "crit_" .. ctx.cause
		counters[key] = counters[key] + 1
	end
	emit(battle, { kind = "hit", who = ctx.t, by = ctx.a, damage = ctx.damage,
		critical = ctx.cause or false, swing = ctx.swing.kind })
	M.apply_damage(battle, ctx.t, ctx.damage, ctx.a)
	return true
end
-- }}}

local ORDER = { "reach", "parry", "flank", "critical", "damage", "effect" }
M.ORDER = ORDER

-- Resolves a's swing on the tick it strikes. Returns the context, whose
-- fields say how far it got (for tests).
-- {{{ function M.resolve()
function M.resolve(battle, a, swing)
	-- the swing as it was when it struck: a striker felled earlier on the
	-- same tick has had its swing cleared, but its blow is already falling
	swing = swing or a.swing
	local ctx = { a = a, t = swing.target, swing = swing }
	for _, name in ipairs(ORDER) do
		if not STEPS[name](battle, ctx) then
			ctx.stopped = name
			break
		end
	end
	-- stopped at reach: the blade met air
	if ctx.stopped == "reach" then
		battle.counters.misses = battle.counters.misses + 1
		emit(battle, { kind = "miss", who = a })
	end
	return ctx
end
-- }}}

return M
