-- 029-the-front-desk.lua
--
-- Joins the game engine to the match. It holds which seat the person is in
-- (the command table, the commander's seat, the front rank, or the result),
-- turns keys and clicks into actions through the bindings table of the
-- configuration, runs the simulation in fixed ticks however fast frames
-- come, delivers scripted input to the very same handlers a person's input
-- reaches, and writes the receipt as the last thing the program does.
--
-- Seats, actions and script events are all tables of functions; the engine's
-- callbacks in main.lua call straight into this file.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local util = require("002-util")
local catalogue_m = require("004-catalogue")
local campaign = require("016-the-campaign")
local ranged = require("013-ranged")
local match_m = require("017-the-match")
local io_m = require("018-input-and-goodbye")
local script_m = require("019-the-script")
local renderer = require("023-the-renderer")
local scenery = require("025-the-scenery")
local fp = require("026-first-person-view")
local tp = require("027-third-person-view")
local command = require("028-command-screen")
local shots = require("030-screenshots")
local headless = require("020-headless")

local M = {}

-- The desk's whole state, in one record, so nothing hides in upvalues.
local D = {}

-- Which seat the person is in, from the match's act.
-- {{{ function M.seat()
function M.seat()
	local m = D.match
	if m.act == "command" then return "command" end
	if m.act == "result" then return "result" end
	if m.act == "front_rank" and m.player_in then return "first_person" end
	return "third_person"
end
-- }}}

-- A new battle gets its own ground, built from its own scenery stream.
-- {{{ local function new_scenery()
local function new_scenery()
	local b = D.match.battle
	D.view.scenery = scenery.build(b.config, b.region, b.streams.scenery)
	D.view.fx = {}
	D.view.slide_x, D.view.slide_z = 0, 0
	D.view_battle = b
end
-- }}}

-- Whether any held key is bound to this action and argument.
-- {{{ local function held_action()
local function held_action(action, arg)
	for key in pairs(D.held) do
		local row = D.keys[key]
		if row and row[2] == action and row[3] == arg then return true end
	end
	return false
end
-- }}}

-- {{{ local function begin_round()
local function begin_round()
	if D.match.act ~= "command" or not D.match.choice.push then return end
	match_m.begin_round(D.match)
	new_scenery()
end
-- }}}

-- The actions a key can be bound to. `pressed` is true on press.
local ACTIONS = {
	move = function() end,
	free_look = function() end,
	dodge = function() D.pending.dodge = true end,
	overhead = function() D.pending.swing = "overhead" end,
	switch_view = function()
		if D.match.player_in then match_m.step_out(D.match) else match_m.drop_in(D.match) end
	end,
	range = function(arg)
		if D.match.battle then ranged.set_range(D.match.battle, 1, arg) end
	end,
	be_affected = function(arg)
		if D.match.act == "command" then D.match.choice.be_affected = arg end
	end,
	push_key = function(arg)
		if D.match.act == "command" and campaign.target(D.match.map, arg) then
			D.match.choice.push = arg
		end
	end,
	begin_round = begin_round,
	screenshot = function(arg) M.screenshot(arg) end,
	quit = function() D.quitting = true end,
}

-- The actions a mouse button can be bound to, by seat.
local BUTTON_ACTIONS = {
	swing = function() D.pending.swing = "swing" end,
	guard = function() D.guard_held = true end,
	volley = function() ranged.volley(D.match.battle, 1) end,
	shields = function() D.match.battle.shields[1] = true end,
	pick = function(x, y)
		local a = command.hit(D.hits, x, y)
		if not a then return end
		if a.kind == "push" then D.match.choice.push = a.value end
		if a.kind == "perk" then D.match.choice.perk = a.value end
	end,
}

-- {{{ function M.screenshot()
function M.screenshot(name)
	shots.take(D.dir, name, { seed = D.opts.seed, tick = D.ticks, args = D.args })
end
-- }}}

-- {{{ function M.keypressed()
function M.keypressed(key)
	local row = D.keys[key]
	if not row then return end
	D.held[key] = true
	ACTIONS[row[2]](row[3], true)
end
-- }}}

-- {{{ function M.keyreleased()
function M.keyreleased(key)
	D.held[key] = nil
end
-- }}}

-- {{{ function M.mousepressed()
function M.mousepressed(x, y, button)
	local action = D.buttons[M.seat() .. ":" .. button]
	if action then BUTTON_ACTIONS[action](x, y) end
end
-- }}}

-- Releasing the right button lowers the guard and the shields, whichever
-- seat it was raised from.
-- {{{ function M.mousereleased()
function M.mousereleased(x, y, button)
	if button == 2 then
		D.guard_held = false
		if D.match.battle then D.match.battle.shields[1] = false end
	end
end
-- }}}

-- In the front rank the mouse moves the sword along its U, or, with the
-- look key held, the eyes.
-- {{{ function M.mousemoved()
function M.mousemoved(x, y, dx, dy)
	if M.seat() ~= "first_person" then return end
	local s = D.match.battle.player
	if held_action("free_look", true) then
		s.look_offset = util.clamp(s.look_offset + dx * 0.004, -1.3, 1.3)
	else
		D.pending.u = D.pending.u + dx * D.config.sword.u_sensitivity
	end
end
-- }}}

-- {{{ function M.wheelmoved()
function M.wheelmoved(dx, dy)
	D.view.zoom = util.clamp(D.view.zoom - dy * 0.08, 0.4, 2.0)
end
-- }}}

-- Script events, delivered to the same handlers a person's input reaches.
local SCRIPT = {
	key_down = function(e) M.keypressed(e.key) end,
	key_up = function(e) M.keyreleased(e.key) end,
	mouse_down = function(e) M.mousepressed(e.x, e.y, e.button) end,
	mouse_up = function(e) M.mousereleased(e.x, e.y, e.button) end,
	mouse_move = function(e) M.mousemoved(0, 0, e.dx, e.dy) end,
	screenshot = function(e) M.screenshot(e.name) end,
	quit = function() D.quitting = true end,
}

-- The player's intent for one tick, from what is held and what is pending.
-- {{{ local function intent()
local function intent()
	local p = D.pending
	local i = {
		forward = (held_action("move", "forward") and 1 or 0)
			- (held_action("move", "back") and 1 or 0),
		side = (held_action("move", "right") and 1 or 0) - (held_action("move", "left") and 1 or 0),
		guard = D.guard_held, swing = p.swing, u_delta = p.u, dodge = p.dodge,
	}
	p.swing, p.u, p.dodge = false, 0, false
	return i
end
-- }}}

-- {{{ local function index_bindings()
local function index_bindings(config)
	local keys, buttons = {}, {}
	for _, row in ipairs(config.keys) do
		if not ACTIONS[row[2]] then util.die("config.keys: no action named %s", tostring(row[2])) end
		keys[row[1]] = row
	end
	for _, row in ipairs(config.buttons) do
		if not BUTTON_ACTIONS[row[3]] then
			util.die("config.buttons: no action named %s", tostring(row[3]))
		end
		buttons[row[2] .. ":" .. row[1]] = row[3]
	end
	return keys, buttons
end
-- }}}

-- {{{ function M.load()
function M.load(dir, argv)
	D.dir, D.args = dir, table.concat(argv, " ")
	D.opts = io_m.read_input(dir)
	D.script = script_m.parse(argv, D.opts)
	D.config = util.load_config(dir)
	D.catalogue = catalogue_m.load(dir, headless.mods(D.config, D.opts))
	D.keys, D.buttons = index_bindings(D.config)
	D.match = match_m.new(D.config, D.catalogue, D.opts.seed, { person = true })
	D.held, D.pending, D.guard_held = {}, { swing = false, u = 0, dodge = false }, false
	D.ticks, D.frames, D.acc, D.quitting, D.done = 0, 0, 0, false, false
	D.view = { renderer = renderer.new(), scenery = {}, fx = {}, time = 0, slide_x = 0,
		slide_z = 0, zoom = 1 }
	local font = love.graphics.newFont
	D.fonts = { tiny = font(11), small = font(15), big = font(22), huge = font(48) }
	-- a lone battle skips the first command table; first person starts in the line
	if D.opts.mode == "battle" or D.opts.first_person then
		for _, c in ipairs(headless.perk_choices(D.opts.perks)) do
			D.match.taken[1][#D.match.taken[1] + 1] = c
		end
		match_m.choose_for_mind(D.match)
		D.match.choice.perk = false
		begin_round()
	end
	if D.opts.first_person then
		D.match.act, D.match.player_in = "front_rank", true
	end
end
-- }}}

-- {{{ local function one_tick()
local function one_tick()
	local dt = D.config.tick.seconds
	for _, e in ipairs(script_m.due(D.script, D.ticks * dt, {})) do SCRIPT[e.kind](e) end
	if D.quitting then return end
	match_m.tick(D.match, intent())
	if D.match.battle and D.match.battle ~= D.view_battle then new_scenery() end
	if D.match.battle then fp.add_effects(D.view.fx, D.match.battle) end
	D.ticks = D.ticks + 1
end
-- }}}

-- In the commander's seat the movement keys slide the camera.
-- {{{ local function slide_camera()
local function slide_camera(dt)
	local v = D.view
	local speed = D.config.view.camera_slide * dt
	v.slide_z = v.slide_z - ((held_action("move", "forward") and speed or 0)
		- (held_action("move", "back") and speed or 0))
	v.slide_x = v.slide_x + (held_action("move", "right") and speed or 0)
		- (held_action("move", "left") and speed or 0)
end
-- }}}

-- {{{ function M.update()
function M.update(dt)
	local c = D.config.tick
	D.view.time = D.view.time + dt
	D.acc = D.acc + math.min(dt, 0.25)
	local n = 0
	while D.acc >= c.seconds and n < c.max_per_frame and not D.quitting do
		one_tick()
		D.acc, n = D.acc - c.seconds, n + 1
	end
	-- a slow frame drops the time it could not catch up, rather than spiralling
	if n == c.max_per_frame then D.acc = 0 end
	fp.age_effects(D.view.fx, dt)
	local seat = M.seat()
	love.mouse.setRelativeMode(seat == "first_person")
	if seat == "third_person" or seat == "result" then slide_camera(dt) end
	-- letting go of the look key brings the eyes back to the lock
	local b = D.match.battle
	if b and not held_action("free_look", true) then
		b.player.look_offset = b.player.look_offset * math.max(0, 1 - dt * 6)
		if math.abs(b.player.look_offset) < 0.01 then b.player.look_offset = 0 end
	end
	if D.quitting and shots.pending == 0 and D.drawn_after_quit then M.finish() end
end
-- }}}

-- What each seat draws.
local DRAW = {
	command = function(w, h) D.hits = command.draw(D.match, w, h, D.fonts) end,
	third_person = function(w, h)
		tp.draw(D.match.battle, D.view, w, h, D.match.act == "approach")
	end,
	first_person = function(w, h) fp.draw(D.match.battle, D.view, w, h) end,
	result = function(w, h)
		tp.draw(D.match.battle, D.view, w, h, false)
		command.draw_result(D.match, w, h, D.fonts)
	end,
}

-- {{{ function M.draw()
function M.draw()
	local w, h = love.graphics.getDimensions()
	DRAW[M.seat()](w, h)
	D.frames = D.frames + 1
	-- one frame is drawn after a quit is asked, so a screenshot asked for at
	-- the same moment has a frame to capture
	if D.quitting then D.drawn_after_quit = true end
end
-- }}}

-- The last thing the program does: the receipt, then the engine is told to
-- stop. Called once, from a quit or from the window closing.
-- {{{ function M.finish()
function M.finish()
	if D.done then return end
	D.done = true
	local run = match_m.summary(D.match)
	run.seed, run.mode, run.frames, run.screenshots = D.opts.seed, D.opts.mode, D.frames, shots.taken
	run.seconds = D.ticks * D.config.tick.seconds
	io_m.write_goodbye(D.dir, run, D.opts.receipt or nil)
	love.event.quit()
end
-- }}}

return M
