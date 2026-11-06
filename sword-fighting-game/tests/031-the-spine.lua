-- 031-the-spine.lua
--
-- Tests for phase 1: configuration overrides, named streams, run options
-- from input/, the scripted timeline, the receipt, and headless runs being
-- decided entirely by their seed.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

return function(T)
	local util = require("002-util")
	local rs = require("003-random-streams")
	local io_m = require("018-input-and-goodbye")
	local script = require("019-the-script")
	local headless = require("020-headless")
	local scratch = "/tmp/sword-fighting-game/tests"
	os.execute('mkdir -p "' .. scratch .. '/input"')

	return {
		{ "an override changes one knob and leaves the rest", function()
			local base = { a = { b = 1, c = 2 }, keys = { 1, 2 } }
			util.merge_strict(base, { a = { b = 5 } }, "config")
			T.equal(base.a.b, 5, "a.b")
			T.equal(base.a.c, 2, "a.c")
		end },
		{ "an unknown knob stops the load with its dotted name", function()
			T.raises(function()
				util.merge_strict({ a = { b = 1 } }, { a = { bee = 2 } }, "config")
			end, "config.a.bee")
		end },
		{ "a knob of the wrong type is refused", function()
			T.raises(function()
				util.merge_strict({ a = 1 }, { a = "one" }, "config")
			end, "should be a number")
		end },
		{ "one stream from one seed repeats exactly", function()
			local a, b = rs.new(7, "hits"), rs.new(7, "hits")
			for _ = 1, 100 do T.equal(a:next_raw(), b:next_raw(), "draw") end
		end },
		{ "two streams from one seed differ", function()
			local a, b = rs.new(7, "hits"), rs.new(7, "minds")
			local same = 0
			for _ = 1, 50 do if a:next_raw() == b:next_raw() then same = same + 1 end end
			T.truthy(same < 2, "streams independent")
		end },
		{ "floats stay in [0, 1) and average a half", function()
			local s, sum = rs.new(3, "movement"), 0
			for _ = 1, 20000 do
				local f = s:float()
				T.truthy(f >= 0 and f < 1, "float in range")
				sum = sum + f
			end
			T.near(sum / 20000, 0.5, 0.01, "mean")
		end },
		{ "an input file sets run options; a bad one names itself", function()
			local f = io.open(scratch .. "/input/a.lua", "w")
			f:write("return { seed = 42, mode = 'duel' }")
			f:close()
			local opts = io_m.read_input(scratch)
			T.equal(opts.seed, 42, "seed")
			T.equal(opts.mode, "duel", "mode")
			f = io.open(scratch .. "/input/b.lua", "w")
			f:write("return { sead = 1 }")
			f:close()
			T.raises(function() io_m.read_input(scratch) end, "b.lua: unknown run option sead")
			os.remove(scratch .. "/input/a.lua")
			os.remove(scratch .. "/input/b.lua")
		end },
		{ "flags parse into options and a time-ordered script", function()
			local opts = util.deep_copy(io_m.DEFAULTS)
			local s = script.parse({ "--seed", "9", "--key", "2", "space",
				"--hold", "1", "w", "3",
				"--quit", "5" }, opts)
			T.equal(opts.seed, 9, "seed")
			local kinds = {}
			for _, e in ipairs(s.events) do kinds[#kinds + 1] = e.kind .. "@" .. e.t end
			T.equal(table.concat(kinds, " "), "key_down@1 key_down@2 key_up@4 quit@5", "order")
			local due = script.due(s, 2, {})
			T.equal(#due, 2, "two events due by second 2")
			T.equal(#script.due(s, 2, {}), 0, "each event is due once")
		end },
		{ "an unknown flag stops the run", function()
			T.raises(function() script.parse({ "--sede", "1" }, {}) end, "unknown option --sede")
		end },
		{ "the receipt names every counter and reads back", function()
			local run = { seed = 5, mode = "battle", ticks = 10, seconds = 0.5, frames = 0,
				rounds = 1, result = "team 1", counters = { hits = 3 }, draws = { hits = 4 },
				screenshots = 0 }
			local path = io_m.write_goodbye(scratch, run, scratch .. "/goodbye")
			local back = io_m.read_receipt(path)
			T.equal(back.seed, "5", "seed")
			T.equal(back.hits, "3", "hits")
			T.equal(back["draws hits"], "4", "draws")
			T.equal(back.trips, "0", "an uncounted counter reads zero")
		end },
		{ "the same seed gives the same headless battle", function()
			local a = headless.run(T.DIR, { "--mode", "battle", "--seed", "11",
				"--receipt", scratch .. "/a" })
			local b = headless.run(T.DIR, { "--mode", "battle", "--seed", "11",
				"--receipt", scratch .. "/b" })
			T.equal(a.ticks, b.ticks, "ticks")
			T.equal(a.counters.hits, b.counters.hits, "hits")
			T.equal(a.result, b.result, "result")
		end },
		{ "a headless run refuses scripted keys", function()
			T.raises(function()
				headless.run(T.DIR, { "--key", "1", "w", "--receipt", scratch .. "/c" })
			end, "needs the window")
		end },
	}
end
