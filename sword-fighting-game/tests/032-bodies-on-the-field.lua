-- 032-bodies-on-the-field.lua
--
-- Tests for phase 2: the catalogue's checks, the grid, the soldier record,
-- stamina, the occupancy rules and tripping. Battles here are built small
-- and soldiers placed by hand, so each rule is seen alone.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

return function(T)
	local util = require("002-util")
	local field_m = require("005-battlefield")
	local soldier_m = require("006-soldier")
	local stamina = require("007-stamina")
	local movement = require("008-movement")
	local battle_m = require("014-the-battle")
	local catalogue_m = require("004-catalogue")

	-- One battalion of two by one a side: four soldiers, ids 1-2 team 1,
	-- 3-4 team 2.
	-- {{{ local function small_battle()
	local function small_battle(seed)
		local config, catalogue, streams = T.world(seed)
		config.field.battalions, config.field.battalion_wide = 1, 2
		config.field.battalion_deep = 1
		local b = battle_m.new({ config = config, catalogue = catalogue, streams = streams,
			region = "meadow" })
		return b
	end
	-- }}}

	-- {{{ local function place()
	local function place(b, s, x, y, facing)
		field_m.release(b.field, s)
		s.x, s.y = x, y
		field_m.claim(b.field, math.floor(x), math.floor(y), s)
		s.facing = facing or s.facing
	end
	-- }}}

	-- Ticks movement alone for a soldier with a fixed wish.
	-- {{{ local function walk()
	local function walk(b, s, forward, side, seconds)
		local dt = b.config.tick.seconds
		for _ = 1, math.floor(seconds / dt) do
			s.intent.forward, s.intent.side = forward, side
			movement.step(b, s, dt)
			for _, o in ipairs(b.soldiers) do
				if o ~= s and o.yield then movement.step(b, o, dt) end
			end
		end
	end
	-- }}}

	return {
		{ "the shipped catalogue loads and every entry is checked", function()
			local cat = catalogue_m.load(T.DIR, {})
			T.truthy(cat.weapons.zweihander, "the two-handed sword")
			T.truthy(cat["unit-types"].mega_spearman, "the mega spearman")
		end },
		{ "a broken mod stops the load naming the field", function()
			local dir = "/tmp/sword-fighting-game/tests/catalogue"
			os.execute('mkdir -p "' .. dir .. '/mods/broken" "' .. dir .. '/assets"')
			os.execute('cp -r "' .. T.DIR .. '/assets/catalogue" "' .. dir .. '/assets/"')
			local f = io.open(dir .. "/mods/broken/weapons.lua", "w")
			f:write("return { stick = { title = 'stick', reach = 'far' } }")
			f:close()
			T.raises(function() catalogue_m.load(dir, { "broken" }) end, "weapons.stick")
		end },
		{ "a held cell cannot be claimed twice", function()
			local field = field_m.new(4, 4)
			field_m.claim(field, 1, 1, { id = 1 })
			T.raises(function() field_m.claim(field, 1, 1, { id = 2 }) end, "already held")
		end },
		{ "outside the field is the edge, not empty", function()
			local field = field_m.new(4, 4)
			T.equal(field_m.holder(field, -1, 0), "edge", "west of the field")
			T.equal(field_m.holder(field, 0, 0), false, "an empty cell")
		end },
		{ "thick armor carries two more points and walks slower", function()
			local config, catalogue = T.world()
			local s = soldier_m.new(catalogue, config, "swordsman", { id = 1, team = 1,
				battalion = 1, slot_x = 0, slot_y = 0, x = 0, y = 0, facing = 0 })
			local thin = s.armor
			s.thick_override = true
			soldier_m.refresh(s, config)
			T.equal(s.armor, thin + 2, "armor")
			T.truthy(s.walk_mult < 1, "slower walk")
		end },
		{ "parry chance is the maximum when fresh and falls with fatigue", function()
			local config = T.world()
			T.near(stamina.parry_chance(1, config), config.stamina.parry_max, 1e-9, "fresh")
			local last = 2
			for k = 10, 0, -1 do
				local p = stamina.parry_chance(k / 10, config)
				T.truthy(p <= last, "monotone")
				T.truthy(p >= config.stamina.parry_min, "floor")
				local bushido = stamina.parry_chance(k / 10, config, true)
				T.truthy(bushido >= p, "bushido never worse")
				last = p
			end
		end },
		{ "an enemy's cell is a wall", function()
			local b = small_battle()
			local me, foe = b.soldiers[1], b.soldiers[3]
			place(b, me, 10.5, 10.5, 0)
			place(b, foe, 11.5, 10.5)
			walk(b, me, 1, 0, 2)
			T.equal(me.cell_x, 10, "still in its own cell")
			T.truthy(me.x < 11, "stopped at the boundary")
			T.truthy(b.counters.blocked_steps > 0, "counted")
		end },
		{ "an ally's cell is entered at half speed and the ally yields", function()
			local b = small_battle()
			local me, friend = b.soldiers[1], b.soldiers[2]
			place(b, me, 10.5, 10.5, 0)
			place(b, friend, 11.5, 10.5)
			walk(b, me, 1, 0, 0.6)
			T.equal(me.cell_x, 11, "the mover took the ally's cell")
			T.equal(friend.cell_x, 10, "the ally was given the mover's")
			walk(b, friend, 0, 0, 1)
			T.truthy(friend.x < 11, "the ally stepped the other way by itself")
			T.truthy(b.counters.yields == 1, "one yield")
		end },
		{ "a dodge into an occupied cell is refused", function()
			local b = small_battle()
			local me, friend = b.soldiers[1], b.soldiers[2]
			place(b, me, 10.5, 10.5, 0)
			place(b, friend, 11.5, 10.5)
			me.intent.dodge, me.intent.forward = true, 1
			movement.step(b, me, b.config.tick.seconds)
			T.equal(me.dodge, false, "no dodge")
			T.equal(b.counters.dodges_refused, 1, "refusal counted")
		end },
		{ "a fresh soldier backsteps safely; a fatigued one trips", function()
			local b = small_battle()
			local me = b.soldiers[1]
			place(b, me, 20.5, 20.5, 0)
			walk(b, me, -1, 0, 0.2)
			T.equal(me.tripped, 0, "fresh")
			walk(b, me, 0, 0, 0.1)
			me.stamina = 0.2
			walk(b, me, -1, 0, 0.1)
			T.truthy(me.tripped > 0, "fatigued")
		end },
		{ "guarded sidesteps trip about one in four; unguarded never", function()
			local b = small_battle(5)
			local me = b.soldiers[1]
			local trips, tries = 0, 4000
			for _ = 1, tries do
				me.guard, me.tripped, me.was_siding = true, 0, false
				me.intent.forward, me.intent.side = 0, 1
				movement.step(b, me, 0)
				if me.tripped > 0 then trips = trips + 1 end
			end
			T.near(trips / tries, b.config.stamina.side_trip, 0.03, "share tripped")
			for _ = 1, 200 do
				me.guard, me.tripped, me.was_siding = false, 0, false
				movement.step(b, me, 0)
				T.equal(me.tripped, 0, "unguarded")
			end
		end },
		{ "util: angles wrap the short way", function()
			T.near(util.wrap_angle(3 * math.pi / 2), -math.pi / 2, 1e-9, "wrap")
		end },
	}
end
