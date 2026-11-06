-- 020-headless.lua
--
-- Runs a match, a battle or a duel with no window, as fast as the processor
-- allows, and ends the way every run ends: with the receipt. The player's
-- soldier is driven by its own mind, so a headless battle is a whole battle.
--
-- Scripted key and mouse events need the window's handlers; a headless run
-- given one stops and says so rather than silently ignoring it.
--
-- Run as a program (luajit src/020-headless.lua DIR [options]) it finds its
-- neighbours by its own path; required as a module, the caller has already
-- set the module path.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local AS_PROGRAM = arg and arg[0] and arg[0]:match("020%-headless%.lua$")
if AS_PROGRAM then package.path = arg[0]:gsub("[^/]*$", "") .. "?.lua;" .. package.path end

local util = require("002-util")
local rs = require("003-random-streams")
local catalogue_m = require("004-catalogue")
local battle_m = require("014-the-battle")
local match_m = require("017-the-match")
local io_m = require("018-input-and-goodbye")
local script_m = require("019-the-script")

local M = {}

-- A match that has not ended after this many rounds is reported unfinished.
M.MAX_ROUNDS = 40

-- A duel is a battle of one battalion of one soldier a side.
-- {{{ local function duel_config()
local function duel_config(config)
	local c = util.deep_copy(config)
	c.field.battalions, c.field.battalion_wide, c.field.battalion_deep = 1, 1, 1
	return c
end
-- }}}

-- Each mode: how to make it, tick it, tell when it is over, and read it.
local MODES = {}

MODES.match = {}

-- {{{ function MODES.match.make()
function MODES.match.make(config, catalogue, opts)
	return match_m.new(config, catalogue, opts.seed, { person = false })
end
-- }}}

-- {{{ function MODES.match.tick()
function MODES.match.tick(m) match_m.tick(m, nil) end
-- }}}

-- {{{ function MODES.match.done()
function MODES.match.done(m)
	return m.result or (m.act == "result" and m.round >= M.MAX_ROUNDS)
end
-- }}}

-- {{{ function MODES.match.read()
function MODES.match.read(m)
	return match_m.summary(m)
end
-- }}}

-- {{{ local function battle_make()
local function battle_make(config, catalogue, opts)
	return battle_m.new({ config = config, catalogue = catalogue,
		streams = rs.make_set(opts.seed), region = opts.region,
		perks = { M.perk_choices(opts.perks), {} } })
end
-- }}}

-- Outcome 0 is a draw at the time limit; false is a battle stopped early.
-- {{{ local function battle_read()
local function battle_read(b)
	local names = { [0] = "draw", [1] = "team 1", [2] = "team 2" }
	return { counters = b.counters, ticks = b.ticks, rounds = 1,
		result = b.outcome and names[b.outcome] or "unfinished",
		draws = rs.add_draws({}, b.streams),
		standing = b.standing }
end
-- }}}

MODES.battle = {
	make = battle_make,
	tick = function(b) battle_m.tick(b, nil) end,
	done = function(b) return b.outcome end,
	read = battle_read,
}

MODES.duel = {
	make = function(config, catalogue, opts)
		return battle_make(duel_config(config), catalogue, opts)
	end,
	tick = MODES.battle.tick,
	done = MODES.battle.done,
	read = battle_read,
}

-- The perks of --perk, as the battle takes them: the player chooses to be
-- affected, so a converting perk given on the command line shows on the
-- player's own soldier.
-- {{{ function M.perk_choices()
function M.perk_choices(names)
	local list = {}
	for _, name in ipairs(names or {}) do
		list[#list + 1] = { name = name, be_affected = true }
	end
	return list
end
-- }}}

-- The mods a run lays over the catalogue: the configuration's, then --mod.
-- {{{ function M.mods()
function M.mods(config, opts)
	local list = {}
	for _, m in ipairs(config.mods) do list[#list + 1] = m end
	for _, m in ipairs(opts.mods or {}) do list[#list + 1] = m end
	return list
end
-- }}}

-- {{{ local function check_script()
local function check_script(script)
	for _, e in ipairs(script.events) do
		if e.kind ~= "quit" then
			util.die("a scripted %s needs the window: use run-game, not run-headless", e.kind)
		end
	end
end
-- }}}

-- Returns the run summary it wrote into the receipt.
-- {{{ function M.run()
function M.run(dir, argv)
	local opts = io_m.read_input(dir)
	local script = script_m.parse(argv, opts)
	check_script(script)
	local mode = MODES[opts.mode]
	if not mode then util.die("no mode named %s (match, battle or duel)", tostring(opts.mode)) end
	local config = util.load_config(dir)
	local catalogue = catalogue_m.load(dir, M.mods(config, opts))
	local state = mode.make(config, catalogue, opts)
	local dt = config.tick.seconds
	local quit_at = math.huge
	if script.events[1] then quit_at = script.events[1].t end
	local ticks = 0
	while not mode.done(state) and ticks * dt < quit_at do
		mode.tick(state)
		ticks = ticks + 1
	end
	local run = mode.read(state)
	run.seed, run.mode, run.frames, run.screenshots = opts.seed, opts.mode, 0, 0
	run.seconds = ticks * dt
	io_m.write_goodbye(dir, run, opts.receipt or nil)
	if opts.report then M.report(run) end
	return run
end
-- }}}

-- {{{ function M.report()
function M.report(run)
	local c = run.counters
	print(string.format("seed %s, %s: %s after %.1f s (%d rounds)", tostring(run.seed),
		run.mode, run.result, run.seconds, run.rounds))
	print(string.format("  swings %d  hits %d  criticals %d  parries %d of %d tried",
		c.swings or 0, c.hits or 0, c.criticals or 0, c.parries or 0, c.parry_attempts or 0))
	print(string.format("  trips %d  falls %d  volleys %d  darts %d (hit %d, blocked %d)",
		c.trips or 0, c.falls or 0, c.volleys or 0, c.darts or 0, c.dart_hits or 0,
		c.dart_blocks or 0))
	for _, h in ipairs(run.history or {}) do
		print(string.format("  round %2d  push %-2s  %-11s  winner %s  %.0f s  standing %d/%d",
			h.round, h.push, h.region, tostring(h.winner), h.seconds,
			h.standing[1], h.standing[2]))
	end
end
-- }}}

-- run as a program: the first argument is the project directory, the rest
-- are run options; an error is printed plainly and the exit code is 1
if AS_PROGRAM then
	local dir = arg[1]
	local rest = {}
	for k = 2, #arg do rest[#rest + 1] = arg[k] end
	if rest[1] == "--help" then
		print(script_m.help())
		os.exit(0)
	end
	local ok, err = pcall(M.run, dir, rest)
	if not ok then
		io.stderr:write(tostring(err), "\n")
		os.exit(1)
	end
end

return M
