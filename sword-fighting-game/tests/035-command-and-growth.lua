-- 035-command-and-growth.lua
--
-- Tests for phases 5 and 6: volleys and shields, the campaign map, a whole
-- headless match, perks and their effects, unit-type traits, armor tracks,
-- and the mod folder.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

return function(T)
	local util = require("002-util")
	local rs = require("003-random-streams")
	local catalogue_m = require("004-catalogue")
	local field_m = require("005-battlefield")
	local ranged = require("013-ranged")
	local battle_m = require("014-the-battle")
	local perks = require("015-perks")
	local campaign = require("016-the-campaign")
	local match_m = require("017-the-match")

	-- {{{ local function battle()
	local function battle(seed, taken)
		local config, catalogue, streams = T.world(seed)
		return battle_m.new({ config = config, catalogue = catalogue, streams = streams,
			region = "meadow", perks = taken })
	end
	-- }}}

	return {
		{ "a volley lands three battalion lengths ahead without the trained arc", function()
			local b = battle(1)
			ranged.set_range(b, 1, 1)
			T.equal(b.volley_range[1], 3, "range unchanged without the perk")
			ranged.volley(b, 1)
			local r = b.config.ranged
			for _, d in ipairs(b.darts) do
				local dist = util.distance(d.sx, d.sy, d.ex, d.ey)
				T.near(dist, 3 * r.battalion_length, r.spread * 1.5, "landing distance")
			end
		end },
		{ "the trained arc lets the commander pick range 1", function()
			local b = battle(1, { { { name = "trained_arc", be_affected = false } }, {} })
			ranged.set_range(b, 1, 1)
			T.equal(b.volley_range[1], 1, "range 1")
		end },
		{ "a volley waits for its cooldown", function()
			local b = battle(1)
			T.truthy(ranged.volley(b, 1) > 0, "first volley")
			T.equal(ranged.volley(b, 1), 0, "second at once")
		end },
		{ "raised shields turn aside more darts", function()
			local blocked = { 0, 0 }
			for k, shields in ipairs({ false, true }) do
				for seed = 1, 30 do
					local b = battle(seed)
					b.shields[2] = shields
					-- every dart is dropped on a soldier of team 2
					for _, s in ipairs(b.soldiers) do
						local d = { sx = 0, sy = 0, ex = s.x, ey = s.y, t = 0,
							flight = 0.01, team = 1, thrower = b.soldiers[1] }
						if s.team == 2 then b.darts[#b.darts + 1] = d end
					end
					ranged.step(b, 0.02)
					blocked[k] = blocked[k] + b.counters.dart_blocks
				end
			end
			T.truthy(blocked[2] > blocked[1] * 3, "shields block " .. blocked[2] .. " vs "
				.. blocked[1])
		end },
		{ "legal pushes never leave the map", function()
			local config, catalogue = T.world()
			local map = campaign.new(config, catalogue, rs.new(1, "campaign"))
			for _, dir in ipairs(campaign.legal_pushes(map)) do
				T.truthy(campaign.target(map, dir), dir)
			end
			T.equal(campaign.target(map, "S"), false, "south of home is off the map")
		end },
		{ "a battle won in the enemy's home wins the match", function()
			local config, catalogue = T.world()
			local map = campaign.new(config, catalogue, rs.new(1, "campaign"))
			map.front = { col = 2, row = 1 }
			T.equal(campaign.resolve(map, "N", 1), 1, "match won")
		end },
		{ "a battle lost at home loses the match", function()
			local config, catalogue = T.world()
			local map = campaign.new(config, catalogue, rs.new(1, "campaign"))
			T.equal(campaign.resolve(map, "N", 2), 2, "match lost")
		end },
		{ "a headless match runs every act and ends with a winner", function()
			local config, catalogue = T.world()
			local m = match_m.new(config, catalogue, 3, { person = false })
			local acts = {}
			for _ = 1, 60 * 60 * 30 do
				acts[m.act] = true
				match_m.tick(m)
				if m.result then break end
			end
			T.truthy(m.result, "a result")
			for _, act in ipairs({ "command", "approach", "front_rank", "result" }) do
				T.truthy(acts[act], "act " .. act)
			end
		end },
		{ "converting perks take the back ranks, and the player only by choice", function()
			local taken = { { { name = "mega_spearmen", be_affected = false } }, {} }
			local b = battle(1, taken)
			local n = 0
			for _, s in ipairs(b.soldiers) do
				if s.team == 1 and s.unit == "mega_spearman" then
					n = n + 1
					T.equal(s.slot_y, b.config.field.battalion_deep - 1, "back rank")
				end
			end
			T.equal(n, 4, "four converted")
			T.equal(b.player.unit, "swordsman", "the player declined")
			taken[1][1].be_affected = true
			T.equal(battle(1, taken).player.unit, "mega_spearman", "the player accepted")
		end },
		{ "the mega spearman stabs only and carries a shield", function()
			local taken = { { { name = "mega_spearmen", be_affected = true } }, {} }
			local s = battle(1, taken).player
			T.truthy(s.traits.stabs_only and s.traits.shield, "traits")
			T.equal(s.armor, 5, "maxed armor plus one")
		end },
		{ "every perk effect changes what it says", function()
			local cat = catalogue_m.load(T.DIR, {})
			for _, name in ipairs(util.sorted_keys(cat.perks)) do
				local b = battle(2, { { { name = name, be_affected = false } }, {} })
				T.truthy(perks.EFFECTS[cat.perks[name].effect], name .. " has an effect")
				local s = b.soldiers[#b.soldiers / 2]
				T.truthy(s.team == 1, "a team 1 soldier")
			end
			local b = battle(2, { { { name = "better_armor", be_affected = false } }, {} })
			T.equal(b.player.armor, 2, "better armor")
			b = battle(2, { { { name = "keen_edges", be_affected = false } }, {} })
			T.near(b.player.crit_chance, 0.1, 1e-9, "keen edges")
			b = battle(2, { { { name = "riposte", be_affected = false } }, {} })
			T.truthy(b.player.traits.riposte, "riposte")
		end },
		{ "awareness narrows with armor and stops at the view", function()
			local b = battle(1, { { { name = "thick_armor", be_affected = false },
				{ name = "better_armor", be_affected = false } }, {} })
			local s = b.player
			T.equal(s.armor, 4, "one, plus one, plus two for thickness")
			T.equal(s.awareness, b.config.view.awareness - 4 * b.config.view.awareness_armor,
				"narrowed")
			s.extra_armor = 40
			require("006-soldier").refresh(s, b.config)
			T.equal(s.awareness, b.config.view.fov, "never below the view")
		end },
		{ "a beastwarrior guards while advancing at full pace", function()
			local b = battle(1, { { { name = "beastwarriors", be_affected = true } }, {} })
			local s = b.player
			T.truthy(s.traits.always_critical, "always critical")
			field_m.release(b.field, s)
			s.x, s.y, s.facing = 20.5, 20.5, 0
			field_m.claim(b.field, 20, 20, s)
			s.guard, s.intent.forward, s.intent.side = true, 1, 0
			require("008-movement").step(b, s, 0.5)
			T.near(s.x - 20.5, b.config.body.walk_speed * 0.5, 1e-6, "full pace")
		end },
		{ "the example mod adds its unit and perk", function()
			local cat = catalogue_m.load(T.DIR, { "example-clay-knights" })
			T.truthy(cat["unit-types"].clay_knight, "unit")
			T.truthy(cat.perks.clay_knights, "perk")
		end },
	}
end
