-- 019-the-script.lua
--
-- Run options, and input scripted on a timeline. A scripted event is handed,
-- on the tick its moment arrives, to the same handler a real key, click or
-- mouse motion goes to, so a scripted run exercises exactly the code a
-- person's run does. Times are simulated seconds, so a script means the same
-- thing at any frame rate and with no window at all.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")

local M = {}

-- {{{ local function number()
local function number(s, option)
	local n = tonumber(s)
	if not n then util.die("%s expects a number, got %s", option, tostring(s)) end
	return n
end
-- }}}

-- Each option: how many arguments it takes, and what it does with them.
-- `opts` is the run-options table (018); `events` the scripted timeline.
local OPTIONS = {
	["--seed"] = { 1, function(opts, _, a) opts.seed = number(a[1], "--seed") end },
	["--mode"] = { 1, function(opts, _, a) opts.mode = a[1] end },
	["--region"] = { 1, function(opts, _, a) opts.region = a[1] end },
	["--first-person"] = { 0, function(opts) opts.first_person = true end },
	["--report"] = { 0, function(opts) opts.report = true end },
	["--receipt"] = { 1, function(opts, _, a) opts.receipt = a[1] end },
	["--perk"] = { 1, function(opts, _, a) opts.perks[#opts.perks + 1] = a[1] end },
	["--mod"] = { 1, function(opts, _, a) opts.mods[#opts.mods + 1] = a[1] end },
	["--quit"] = { 1, function(opts, ev, a)
		ev[#ev + 1] = { t = number(a[1], "--quit"), kind = "quit" } end },
	["--key"] = { 2, function(_, ev, a)
		ev[#ev + 1] = { t = number(a[1], "--key"), kind = "key_down", key = a[2] } end },
	["--release"] = { 2, function(_, ev, a)
		ev[#ev + 1] = { t = number(a[1], "--release"), kind = "key_up", key = a[2] } end },
	["--hold"] = { 3, function(_, ev, a)
		local t = number(a[1], "--hold")
		ev[#ev + 1] = { t = t, kind = "key_down", key = a[2] }
		ev[#ev + 1] = { t = t + number(a[3], "--hold"), kind = "key_up", key = a[2] } end },
	["--click"] = { 3, function(_, ev, a)
		local t = number(a[1], "--click")
		local x, y = number(a[2], "--click"), number(a[3], "--click")
		ev[#ev + 1] = { t = t, kind = "mouse_down", x = x, y = y, button = 1 }
		ev[#ev + 1] = { t = t + 0.05, kind = "mouse_up", x = x, y = y, button = 1 } end },
	["--right-hold"] = { 2, function(_, ev, a)
		local t = number(a[1], "--right-hold")
		ev[#ev + 1] = { t = t, kind = "mouse_down", x = 0, y = 0, button = 2 }
		ev[#ev + 1] = { t = t + number(a[2], "--right-hold"), kind = "mouse_up",
			x = 0, y = 0, button = 2 } end },
	["--mouse"] = { 3, function(_, ev, a)
		ev[#ev + 1] = { t = number(a[1], "--mouse"), kind = "mouse_move",
			dx = number(a[2], "--mouse"), dy = number(a[3], "--mouse") } end },
	["--screenshot"] = { 2, function(_, ev, a)
		ev[#ev + 1] = { t = number(a[1], "--screenshot"), kind = "screenshot", name = a[2] } end },
}

M.OPTIONS = OPTIONS

-- Lays the command line over `opts` (from 018's read_input) and returns
-- the script. An unknown option or a missing argument stops the run.
-- {{{ function M.parse()
function M.parse(argv, opts)
	local events = {}
	for _, e in ipairs(opts.script or {}) do events[#events + 1] = e end
	local i = 1
	while i <= #argv do
		local name = argv[i]
		local row = OPTIONS[name]
		if not row then util.die("unknown option %s (see --help)", tostring(name)) end
		local args = {}
		for k = 1, row[1] do
			args[k] = argv[i + k]
			if args[k] == nil then util.die("%s expects %d arguments", name, row[1]) end
		end
		row[2](opts, events, args)
		i = i + 1 + row[1]
	end
	-- a stable sort: events at one moment keep the order they were given in
	for k, e in ipairs(events) do e.order = k end
	table.sort(events, function(a, b)
		if a.t ~= b.t then return a.t < b.t end
		return a.order < b.order
	end)
	return { events = events, cursor = 1 }
end
-- }}}

-- Appends to `out` every event whose moment has come, each once.
-- {{{ function M.due()
function M.due(script, now, out)
	local ev = script.events
	while script.cursor <= #ev and ev[script.cursor].t <= now do
		out[#out + 1] = ev[script.cursor]
		script.cursor = script.cursor + 1
	end
	return out
end
-- }}}

-- {{{ function M.help()
function M.help()
	return [[
sword-fighting-game options (run-game and run-headless take the same ones):

  --seed N                    the run's seed
  --mode NAME                 match (default), battle or duel
  --region NAME               the ground for a lone battle (meadow, swamp_park, prairie, hills)
  --first-person              begin the battle in the front rank
  --key SECONDS NAME          press a key at that moment of simulated time
  --release SECONDS NAME      release it
  --hold SECONDS NAME LENGTH  press, then release LENGTH seconds later
  --click SECONDS X Y         left click at a screen point
  --right-hold SECONDS LENGTH hold the right mouse button
  --mouse SECONDS DX DY       move the mouse by DX, DY pixels
  --screenshot SECONDS NAME   capture the screen to tmp/shared-memory/screenshots/
  --quit SECONDS              end the run cleanly, writing output/goodbye
  --report                    headless: print a summary at the end
  --receipt PATH              write the receipt here instead of output/goodbye
  --perk NAME                 team 1 begins a lone battle with this perk (repeatable)
  --mod NAME                  lay mods/NAME over the catalogue (repeatable)

Run options can also be given as tables in input/*.lua files; flags win.]]
end
-- }}}

return M
