-- 018-input-and-goodbye.lua
--
-- The first and last things a run does.
--
-- First, it reads input/: every *.lua file there, in name order, returns a
-- table of run options, so a run can be set up by dropping a file into a
-- folder. Options given on the command line are laid over the files.
--
-- Last, it writes output/goodbye: the receipt. Its presence and fresh time
-- prove the run reached a clean ending (a crash never says goodbye); its
-- numbers say what happened without anyone watching. One writer serves the
-- window and the headless runner alike, so neither can forget it.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")
local rs = require("003-random-streams")
local battle_m = require("014-the-battle")

local M = {}

-- Every option a run understands, with its default. An option in an input
-- file that is not here stops the run.
M.DEFAULTS = {
	seed = 1,
	mode = "match",          -- "match", "battle" or "duel"
	region = "meadow",       -- the region kind for a lone battle
	first_person = false,    -- begin a battle in the front rank
	script = {},             -- scripted events, as 019-the-script.lua makes them
	quit = false,            -- seconds of simulated time after which to quit
	report = false,          -- headless: print a summary at the end
	receipt = false,         -- a path to write the receipt to, instead of output/goodbye
	perks = {},              -- perk names team 1 starts a lone battle with
	mods = {},               -- mod folders laid over the catalogue, after config.mods
}

-- Returns the options from input/*.lua laid over the defaults.
-- {{{ function M.read_input()
function M.read_input(dir)
	local opts = util.deep_copy(M.DEFAULTS)
	for _, name in ipairs(util.list_files(dir .. "/input", ".lua")) do
		local path = dir .. "/input/" .. name
		local t = util.load_data_file(path)
		for _, k in ipairs(util.sorted_keys(t)) do
			if M.DEFAULTS[k] == nil then util.die("%s: unknown run option %s", path, k) end
			opts[k] = t[k]
		end
	end
	return opts
end
-- }}}

-- {{{ local function line()
local function line(out, name, value)
	out[#out + 1] = string.format("%-16s %s", name .. ":", tostring(value))
end
-- }}}

-- run: { seed, mode, ticks, seconds, frames, counters, rounds, result,
-- draws (stream name -> count, from 003's add_draws), screenshots }.
-- {{{ function M.receipt_lines()
function M.receipt_lines(run)
	local out = { "# goodbye - the receipt of one run of sword-fighting-game,",
		"# written by src/018-input-and-goodbye.lua as the run's last act." }
	line(out, "ended", os.date("%Y-%m-%d %H:%M:%S"))
	line(out, "seed", run.seed)
	line(out, "mode", run.mode)
	line(out, "ticks", run.ticks)
	line(out, "seconds", string.format("%.2f", run.seconds))
	line(out, "frames", run.frames)
	line(out, "rounds", run.rounds)
	line(out, "result", run.result)
	for _, name in ipairs(battle_m.COUNTERS) do line(out, name, run.counters[name] or 0) end
	for _, name in ipairs(rs.NAMES) do
		line(out, "draws " .. name, run.draws[name] or 0)
	end
	line(out, "screenshots", run.screenshots)
	return out
end
-- }}}

-- Writes the receipt, making output/ when it is missing.
-- {{{ function M.write_goodbye()
function M.write_goodbye(dir, run, path)
	path = path or (dir .. "/output/goodbye")
	os.execute('mkdir -p "' .. path:match("^(.*)/[^/]*$") .. '"')
	local f = io.open(path, "w")
	if not f then util.die("cannot write the receipt to %s", path) end
	f:write(table.concat(M.receipt_lines(run), "\n"), "\n")
	f:close()
	return path
end
-- }}}

-- Reads a receipt back into name -> value strings, for the batch gatherer
-- and the tests.
-- {{{ function M.read_receipt()
function M.read_receipt(path)
	local f = io.open(path, "r")
	if not f then util.die("no receipt at %s", path) end
	local t = {}
	for l in f:lines() do
		local k, v = l:match("^([^#][^:]*):%s+(.*)$")
		if k then t[k] = v end
	end
	f:close()
	return t
end
-- }}}

return M
