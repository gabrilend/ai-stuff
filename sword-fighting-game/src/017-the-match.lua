-- 017-the-match.lua
--
-- A match is rounds, and a round has four acts, each a row in a table:
--
--   command     the push direction and the perk are chosen (third person)
--   approach    the battle begins; the commander throws volleys and raises
--               shields while the lines close (third person)
--   front_rank  the lines have touched: the player fights as one soldier
--               (first person), until the battle ends or the soldier falls
--   result      the winner is recorded, the campaign moves, and after a pause
--               the next command act begins or the match ends
--
-- The match holds no view. A window and a headless run drive the same acts;
-- the only thing a person adds is choices and intents.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local rs = require("003-random-streams")
local battle_m = require("014-the-battle")
local perks = require("015-perks")
local campaign = require("016-the-campaign")

local M = {}

-- opts.person: a person makes the choices and may drive the player's soldier.
-- {{{ function M.new()
function M.new(config, catalogue, seed, opts)
	local streams = rs.make_set(seed)
	local match = {
		config = config, catalogue = catalogue, seed = seed, streams = streams,
		person = opts.person or false,
		map = campaign.new(config, catalogue, streams.campaign),
		round = 0, act = "command", act_time = 0,
		taken = { {}, {} }, history = {},
		choice = { push = false, perk = false, be_affected = false },
		cards = {}, battle = false, result = false,
		player_in = false, totals = {}, draws = {},
	}
	M.begin_command(match)
	return match
end
-- }}}

-- Deals the perk cards and clears last round's choices.
-- {{{ function M.begin_command()
function M.begin_command(match)
	match.round = match.round + 1
	match.act, match.act_time = "command", 0
	match.cards = perks.offer(match.catalogue, match.taken[1], match.streams.perks,
		match.config.round.perk_cards)
	match.choice = { push = false, perk = false, be_affected = false }
end
-- }}}

-- What a commander with no person behind it picks: the straightest push
-- toward the enemy home that is legal, the first card, and to stay a
-- normal soldier.
-- {{{ function M.choose_for_mind()
function M.choose_for_mind(match)
	local legal = campaign.legal_pushes(match.map)
	local prefer = { "N", "NE", "NW", "E", "W" }
	for _, dir in ipairs(prefer) do
		for _, l in ipairs(legal) do
			if l == dir and not match.choice.push then match.choice.push = dir end
		end
	end
	match.choice.push = match.choice.push or legal[1]
	match.choice.perk = match.choice.perk or match.cards[1] or false
end
-- }}}

-- {{{ local function enemy_perk()
local function enemy_perk(match)
	local cards = perks.offer(match.catalogue, match.taken[2], match.streams.perks, 1)
	if cards[1] then match.taken[2][#match.taken[2] + 1] = { name = cards[1], be_affected = false } end
end
-- }}}

-- Ends the command act: records the choices, the enemy chooses, and the
-- battle is set up in the region pushed into, every soldier replenished.
-- {{{ function M.begin_round()
function M.begin_round(match)
	local ch = match.choice
	if not ch.push then error("the round cannot begin without a push direction") end
	if not campaign.target(match.map, ch.push) then
		error("push " .. ch.push .. " leads off the map")
	end
	if ch.perk then
		match.taken[1][#match.taken[1] + 1] = { name = ch.perk, be_affected = ch.be_affected }
	end
	enemy_perk(match)
	local c = match.config
	local enemy_dir = campaign.enemy_push(match.map, match.streams.campaign,
		c.campaign.straight_weight)
	local region = campaign.target(match.map, ch.push)
	-- each battle has its own streams, made from the match seed and the round,
	-- so a round can be replayed alone
	match.battle = battle_m.new({
		config = c, catalogue = match.catalogue,
		streams = rs.make_set(match.seed * 1000 + match.round),
		region = region.kind, enemy_wing = campaign.WING_OF[enemy_dir],
		perks = match.taken, person = match.person,
	})
	-- a person commands their own contingent's volleys and shields
	if match.person then match.battle.commanders[1] = "person" end
	match.enemy_push = enemy_dir
	match.player_in = false
	match.act, match.act_time = "approach", 0
end
-- }}}

local ACTS = {}

-- Headless, the mind chooses at once; with a person, the act waits.
-- {{{ function ACTS.command()
function ACTS.command(match, dt)
	if not match.person then
		M.choose_for_mind(match)
		M.begin_round(match)
	end
end
-- }}}

-- {{{ function ACTS.approach()
function ACTS.approach(match, dt, intent)
	battle_m.tick(match.battle, nil)
	if battle_m.lines_touched(match.battle) then
		match.act, match.act_time = "front_rank", 0
		match.player_in = match.person and match.battle.player.alive
	end
	if match.battle.outcome then M.end_battle(match) end
end
-- }}}

-- The player's soldier takes the person's intent while they are in it; if it
-- falls, the person is back in the commander's seat.
-- {{{ function ACTS.front_rank()
function ACTS.front_rank(match, dt, intent)
	local b = match.battle
	local drive = match.player_in and b.player.alive and intent or nil
	battle_m.tick(b, drive)
	if match.player_in and not b.player.alive then match.player_in = false end
	if b.outcome then M.end_battle(match) end
end
-- }}}

-- {{{ function ACTS.result()
function ACTS.result(match, dt)
	if match.result then return end
	if match.act_time >= match.config.round.result_pause then M.begin_command(match) end
end
-- }}}

-- {{{ local function add_totals()
local function add_totals(match, counters)
	for _, name in ipairs(battle_m.COUNTERS) do
		match.totals[name] = (match.totals[name] or 0) + counters[name]
	end
end
-- }}}

-- {{{ function M.end_battle()
function M.end_battle(match)
	local b = match.battle
	add_totals(match, b.counters)
	match.totals.ticks = (match.totals.ticks or 0) + b.ticks
	rs.add_draws(match.draws, b.streams)
	match.history[#match.history + 1] = { round = match.round, push = match.choice.push,
		region = b.region_name, winner = b.outcome, seconds = b.time,
		standing = { b.standing[1], b.standing[2] } }
	match.result = campaign.resolve(match.map, match.choice.push, b.outcome)
	match.player_in = false
	match.act, match.act_time = "result", 0
end
-- }}}

-- One fixed step of whatever act the match is in.
-- {{{ function M.tick()
function M.tick(match, intent)
	local dt = match.config.tick.seconds
	ACTS[match.act](match, dt, intent)
	match.act_time = match.act_time + dt
end
-- }}}

-- The person asks to stand in the line (tab). Only once the lines have
-- touched, and only while their soldier stands.
-- What the receipt reads from a match: every finished battle's counters
-- and draws, plus the battle in progress if the run stopped in one.
-- {{{ function M.summary()
function M.summary(match)
	local totals = {}
	for k, v in pairs(match.totals) do totals[k] = v end
	local draws = rs.add_draws({}, match.streams)
	for k, v in pairs(match.draws) do draws[k] = draws[k] + v end
	local b = match.battle
	if b and match.act ~= "result" then
		for _, name in ipairs(battle_m.COUNTERS) do
			totals[name] = (totals[name] or 0) + b.counters[name]
		end
		totals.ticks = (totals.ticks or 0) + b.ticks
		rs.add_draws(draws, b.streams)
	end
	local result = match.result and ("team " .. match.result) or "unfinished"
	return { counters = totals, ticks = totals.ticks or 0, rounds = match.round,
		result = result, draws = draws, history = match.history }
end
-- }}}

-- {{{ function M.drop_in()
function M.drop_in(match)
	if match.act == "front_rank" and match.battle.player.alive then match.player_in = true end
end
-- }}}

-- {{{ function M.step_out()
function M.step_out(match)
	match.player_in = false
end
-- }}}

return M
