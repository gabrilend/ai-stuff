-- 033-the-sword.lua
--
-- Tests for phase 3: the U and the lock, swings and momentum, the order a
-- hit is resolved in, the minds, and the battle tick deciding a battle the
-- same way twice.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

return function(T)
	local field_m = require("005-battlefield")
	local the_u = require("009-the-u")
	local swings = require("010-swings")
	local hits = require("011-hit-resolution")
	local battle_m = require("014-the-battle")

	-- Two soldiers, placed facing each other one and a bit cells apart.
	-- {{{ local function duel()
	local function duel(seed)
		local config, catalogue, streams = T.world(seed)
		config.field.battalions, config.field.battalion_wide = 1, 1
		config.field.battalion_deep = 1
		local b = battle_m.new({ config = config, catalogue = catalogue, streams = streams,
			region = "meadow" })
		local a, t = b.soldiers[1], b.soldiers[2]
		for _, s in ipairs({ a, t }) do field_m.release(b.field, s) end
		a.x, a.y, a.facing = 10.5, 10.5, 0
		t.x, t.y, t.facing = 11.7, 10.5, math.pi
		field_m.claim(b.field, 10, 10, a)
		field_m.claim(b.field, 11, 10, t)
		a.lock, t.lock = t, a
		return b, a, t
	end
	-- }}}

	-- Starts a swing and runs it to its strike, resolving it there.
	-- {{{ local function strike()
	local function strike(b, a, request)
		swings.start(b, a, request or "swing")
		local dt = b.config.tick.seconds
		for _ = 1, 200 do
			b.time = b.time + dt
			if swings.advance(b, a, dt) then return hits.resolve(b, a) end
		end
		error("the swing never struck")
	end
	-- }}}

	-- {{{ local function ready()
	local function ready(s)
		s.swing, s.stagger, s.open, s.tripped = false, 0, 0, 0
	end
	-- }}}

	return {
		{ "the bend is a stab and the arms are slashes", function()
			local config = T.world()
			T.equal(the_u.side_of(0, config), "bend", "u 0")
			T.equal(the_u.side_of(-1, config), "left", "u -1")
			T.equal(the_u.side_of(1, config), "right", "u 1")
		end },
		{ "a nearer enemy takes the lock only after half a second", function()
			local b, a, t = duel()
			local config = b.config
			config.field.battalion_wide = 1
			local other = { id = 99, team = 2, alive = true, x = 10.9, y = 11.5 }
			field_m.claim(b.field, 10, 11, other)
			local dt = config.tick.seconds
			the_u.update_lock(b, a, dt)
			T.equal(a.lock, t, "still the old lock at once")
			local switched_at
			for k = 1, 60 do
				the_u.update_lock(b, a, dt)
				if a.lock == other and not switched_at then switched_at = (k + 1) * dt end
			end
			T.near(switched_at, config.sword.lock_switch, 2 * dt, "switch time")
		end },
		{ "alternating sides gather more momentum than repeating one", function()
			local b, a = duel()
			a.u = -1
			local w1 = swings.start(b, a, "swing")
			a.last_side, a.last_swing_time = "right", b.time
			local flowing = swings.momentum(b, a, w1)
			a.last_side = "left"
			local stalled = swings.momentum(b, a, w1)
			T.truthy(flowing > stalled, "flow beats stall")
		end },
		{ "walking into the target adds momentum", function()
			local b, a = duel()
			local w = swings.start(b, a, "swing")
			local still = swings.momentum(b, a, w)
			a.vx = 1.5
			T.truthy(swings.momentum(b, a, w) > still, "approach adds")
		end },
		{ "an overhead leaves its swinger open, and the open cannot parry", function()
			local b, a, t = duel()
			strike(b, a, "overhead")
			T.truthy(a.open > 0, "open after the overhead")
			a.guard = true
			T.equal(hits.parry_roll(b, a, 1, t.x, t.y, b.streams.hits), false, "no parry")
		end },
		{ "a fresh guarded target parries nearly always; a spent one rarely", function()
			local b, a, t = duel(3)
			local fresh, spent = 0, 0
			for _ = 1, 300 do
				ready(a) t.health, t.stamina, t.guard = 1000, 1, true
				if strike(b, a).stopped == "parry" then fresh = fresh + 1 end
			end
			for _ = 1, 300 do
				ready(a) t.health, t.stamina, t.guard = 1000, 0, true
				if strike(b, a).stopped == "parry" then spent = spent + 1 end
			end
			T.truthy(fresh / 300 > 0.85, "fresh parries " .. fresh)
			T.truthy(spent / 300 < 0.25, "spent parries " .. spent)
		end },
		{ "a hit from behind cannot be parried", function()
			local b, a, t = duel()
			t.facing, t.guard = 0, true
			T.equal(hits.parry_roll(b, t, 1, a.x, a.y, b.streams.hits), false, "from behind")
		end },
		{ "a flanked solid connect is always critical", function()
			local b, a, t = duel()
			for _ = 1, 50 do
				ready(a) t.health, t.guard, t.facing = 1000, false, 0.3
				a.last_side = "none"
				local ctx = strike(b, a)
				T.truthy(ctx.flank, "flanked")
				T.truthy(ctx.cause ~= nil, "critical")
			end
		end },
		{ "armor takes its percentage off", function()
			local b, a, t = duel()
			t.armor = 0
			local bare = hits.armor_share(b, t)
			t.armor = 3
			local want = bare - 3 * b.config.hits.armor_per_point
			T.near(hits.armor_share(b, t), want, 1e-9, "share")
			t.armor = 100
			T.near(hits.armor_share(b, t), 1 - b.config.hits.armor_cap, 1e-9, "capped")
		end },
		{ "a miss is counted when the target is out of reach", function()
			local b, a, t = duel()
			field_m.release(b.field, t)
			t.x = 15.5
			field_m.claim(b.field, 15, 10, t)
			T.equal(strike(b, a).stopped, "reach", "missed")
			T.equal(b.counters.misses, 1, "counted")
		end },
		{ "blows struck on one tick land together, whatever the ids", function()
			-- regression: strikes once resolved one at a time, so a lower id
			-- felling a higher one on the same tick cancelled the higher one's
			-- blow, and team 1 won about two battles in three
			local b, a, t = duel()
			a.health, t.health = 1, 1
			a.guard, t.guard = false, false
			swings.start(b, a, "swing")
			swings.start(b, t, "swing")
			t.swing.windup = a.swing.windup
			for _ = 1, 120 do
				battle_m.tick(b)
				if not a.alive or not t.alive then break end
			end
			T.equal(a.alive, false, "the lower id fell")
			T.equal(t.alive, false, "the higher id fell too")
		end },
		{ "two lone minds facing each other end up fighting", function()
			local b = duel(4)
			for _ = 1, 60 * 30 do
				battle_m.tick(b)
				if b.outcome then break end
			end
			T.truthy(b.counters.swings > 0, "swings")
			T.truthy(b.counters.hits > 0, "hits")
		end },
		{ "a battle is decided the same way twice and always ends", function()
			local results = {}
			for run = 1, 2 do
				local config, catalogue, streams = T.world(21)
				local b = battle_m.new({ config = config, catalogue = catalogue,
					streams = streams, region = "hills" })
				while not b.outcome do battle_m.tick(b) end
				results[run] = string.format("%s %d %d %d", tostring(b.outcome), b.ticks,
					b.counters.hits, b.counters.parries)
			end
			T.equal(results[1], results[2], "same battle")
		end },
	}
end
