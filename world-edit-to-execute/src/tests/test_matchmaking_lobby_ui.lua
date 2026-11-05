-- test_matchmaking_lobby_ui.lua - the countdown, kicks and the multiplayer screens (issue 801e)
--
-- In plain terms: a host and players, each a client library wired by hand
-- to the matchmaking server's core, on a clock the test moves. Checks the
-- server's countdown before a start (and what stops it) and the host's
-- kick, as the client library reports them; then drives the game browser,
-- the create dialog and the lobby screen of ui/multiplayer/lobby_ui.lua
-- with clicks and keys, drawing into a recorder in place of the renderer.
--
-- Run with: luajit src/tests/test_matchmaking_lobby_ui.lua [DIR]
-- (DIR defaults to the project this file is in.)

-- The project: the argument, or the folder this test sits in (run-tests.sh
-- runs each test by its full path, from the project), or the owner's.
local DIR = arg[1] or arg[0]:match("^(.+)/src/tests/[^/]+%.lua$") or (arg[0]:match("^src/tests/") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local server = require("matchmaking.server")
local client = require("matchmaking.client")
local lobby_ui = require("ui.multiplayer.lobby_ui")

-- {{{ Test utilities
local test_count, pass_count = 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. tostring(msg) or ""))
    end
end

local function refused(f, want)
    local ok, err = pcall(f)
    return not ok and tostring(err):find(want, 1, true) ~= nil, tostring(err)
end

local now = 1000
local function clock() return now end
local srv, wires, lines

local function pump()
    local moved = true
    while moved do
        moved = false
        for _, w in ipairs(wires) do
            if w.c.state == "connected" then
                if not srv.conns[w.id] then w.c:lost("the server closed the connection") moved = true
                else
                    local up = w.c:output()
                    if #up > 0 then srv:receive(w.id, up) moved = true end
                    local down = srv:output(w.id)
                    if #down > 0 then w.c:feed(down) moved = true end
                end
            end
        end
    end
end

local function fresh(config)
    lines = {}
    config = config or {}
    config.clock = clock
    config.log = function(l) lines[#lines + 1] = l end
    srv = server.new(config)
    wires = {}
end

local function wire(name)
    local c = client.new({ name = name, clock = clock, pump = pump, log = function() end })
    wires[#wires + 1] = { c = c, id = srv:accept("10.0.0." .. (#wires + 1), 40000 + #wires) }
    return c
end

-- Moves the clock on in steps, sweeping the server and moving bytes.
local function wait(seconds)
    local t = now + seconds
    while now < t do
        now = now + 0.25
        srv:sweep()
        pump()
    end
end

local function recorder(lobby, events)
    local got = {}
    for _, e in ipairs(events) do lobby:on(e, function(...) got[#got + 1] = { e, ... } end) end
    return got
end
local function seen(got, name)
    for _, e in ipairs(got) do if e[1] == name then return e end end
end

local game = { map_name = "Castle Defense v1.3", map_hash = "h", asset_packs = { { id = "medieval", hash = "x" } },
    max_players = 4, game_mode = "co-op", region = "us-west" }
-- }}}

-- {{{ the countdown
print("the countdown")
fresh({ countdown_seconds = 5 })
local hc, pc, qc = wire("Host"), wire("Ann"), wire("Bo")
local lobby = hc:create_lobby(game)
local games = pc:list_games({})
local pl = pc:join_game(games[1], "Ann")
local ql = qc:join_game(games[1], "Bo")
test("the host is the first player, as every member sees", lobby.host_id == lobby.player_id and pl.host_id == lobby.player_id and ql.host_id == lobby.player_id)
test("a lobby keeps the game it was opened for", lobby.game.map_name == game.map_name and pl.game.max_players == 4)
local hev = recorder(lobby, { "countdown", "countdown_cancel", "game_start", "player_leave", "player_ready" })
local pev = recorder(pl, { "countdown", "countdown_cancel", "game_start", "player_leave", "closed" })
lobby:start_game()
pump()
test("a start with a countdown tells everyone how long", seen(hev, "countdown") and seen(hev, "countdown")[2] == 5 and seen(pev, "countdown")[2] == 5)
test("and the game hasn't started yet", not seen(pev, "game_start") and pl:starting_in() == 5)
local others = wire("Cy")
local late, why = others:join_game(lobby.game_id, "Cy")
test("nobody joins during a countdown", late == nil and why == "the game is starting", why)
test("nor is it listed", #others:list_games({}) == 0)
wait(2)
test("starting_in counts down", math.abs(pl:starting_in() - 3) < 0.01, pl:starting_in())
ql:set_ready(false)
pump()
test("a player not ready stops it, and everyone hears", seen(hev, "countdown_cancel") and seen(pev, "countdown_cancel") and pl:starting_in() == nil)
test("the stop names who", seen(pev, "countdown_cancel")[2].player_id == ql.player_id)
wait(4)
test("no start after a stop", not seen(pev, "game_start") and srv.lobbies[lobby.game_id].state == "waiting")
test("a stopped lobby is listed again", #others:list_games({}) == 1)
lobby:start_game()
pump()
wait(1)
lobby:cancel_start()
pump()
test("the host can stop it", #pev == 4 and pev[4][1] == "countdown_cancel" and seen(hev, "countdown_cancel"))
test("a player can't", refused(function() pl:cancel_start() end, "only the host stops"))
local protocol = require("matchmaking.protocol")
local function raw(i, name, m) srv:receive(wires[i].id, protocol.encode(name, m)) pump() end
lobby:start_game()
pump()
raw(2, "LOBBY_UPDATE", { game_id = lobby.game_id, event = "cancel", player_id = 0, players = {} })
test("nor by sending one itself", pl:starting_in() ~= nil and lines[#lines]:find("a cancel from a player", 1, true), lines[#lines])
lobby:start_game()
pump()
test("a second start during a countdown is ignored", lines[#lines]:find("START_GAME twice", 1, true))
ql:set_ready(true)
pump()
test("ready during a countdown is taken and doesn't stop it", pl:starting_in() ~= nil and ql.players[3].ready)
wait(4.5)
test("not a moment early", not seen(pev, "game_start"))
wait(0.5)
test("when the seconds are up, the game starts for everyone", seen(hev, "game_start") and seen(pev, "game_start")
    and seen(pev, "game_start")[2].ip == "10.0.0.1")
test("and the countdown is over", pl:starting_in() == nil and srv.lobbies[lobby.game_id].state == "in_progress")
raw(1, "LOBBY_UPDATE", { game_id = lobby.game_id, event = "cancel", player_id = 0, players = {} })
test("nothing to stop after the start", lines[#lines]:find("a cancel with no countdown", 1, true), lines[#lines])

fresh({ countdown_seconds = 3 })
hc, pc = wire("Host"), wire("Ann")
lobby = hc:create_lobby(game)
pl = pc:join_game(pc:list_games({})[1], "Ann")
hev = recorder(lobby, { "countdown_cancel", "player_leave", "game_start" })
lobby:start_game()
pump()
pl:leave()
pump()
test("a player leaving stops it", seen(hev, "player_leave") and seen(hev, "countdown_cancel") and srv.lobbies[lobby.game_id].state == "waiting")
wait(4)
test("and no start follows", not seen(hev, "game_start"))
fresh()
hc, pc = wire("Host"), wire("Ann")
lobby = hc:create_lobby(game)
pl = pc:join_game(pc:list_games({})[1], "Ann")
pev = recorder(pl, { "countdown", "game_start" })
lobby:start_game()
pump()
test("with no countdown set, the start is at once, as before", seen(pev, "game_start") and not seen(pev, "countdown"))
-- }}}

-- {{{ kicks
print("kicks")
fresh({ countdown_seconds = 10 })
hc, pc, qc = wire("Host"), wire("Ann"), wire("Bo")
lobby = hc:create_lobby(game)
pl = pc:join_game(pc:list_games({})[1], "Ann")
ql = qc:join_game(lobby.game_id, "Bo")
hev = recorder(lobby, { "player_leave", "countdown_cancel" })
local qev = recorder(ql, { "player_leave" })
pev = recorder(pl, { "closed" })
lobby:start_game()
pump()
lobby:kick(pl.player_id)
pump()
test("the kicked player's lobby closes, saying so", pev[1] and pev[1][1] == "closed" and pev[1][2] == "kicked by the host" and pl.state == "closed")
test("the others hear a kick, not a leave", seen(hev, "player_leave") and seen(hev, "player_leave")[3] == "kicked"
    and seen(qev, "player_leave")[2].name == "Ann" and seen(qev, "player_leave")[3] == "kicked")
test("a kick stops the countdown", seen(hev, "countdown_cancel"))
test("the kicked one is out of the lobby on the server", #srv.lobbies[lobby.game_id].members == 2 and srv.conns[wires[2].id].lobby == nil)
local listed = #pc:list_games({})
pl = pc:join_game(lobby.game_id, "Ann")
test("and may list and join again", listed == 1 and pl ~= nil)
test("the host can't kick itself", refused(function() lobby:kick(lobby.player_id) end, "can't kick itself"))
test("a player can't kick", refused(function() ql:kick(lobby.player_id) end, "only the host kicks"))
raw(3, "LEAVE_GAME", { game_id = lobby.game_id, player_id = lobby.player_id })
test("nor by sending one itself", lines[#lines]:find("a kick from a player", 1, true) and lobby.state == "waiting", lines[#lines])
raw(1, "LEAVE_GAME", { game_id = lobby.game_id, player_id = lobby.player_id })
test("the host kicking itself is ignored", lobby.state == "waiting" and srv.lobbies[lobby.game_id] ~= nil, lines[#lines])
lobby:kick(999)
pump()
test("a kick of someone not there is ignored", lines[#lines]:find("a kick of player 999", 1, true), lines[#lines])
pl:leave()
pump()
test("leaving is still a leave", seen(hev, "player_leave") and hev[#hev][1] == "player_leave" and hev[#hev][3] == "left")
fresh()
hc, pc = wire("Host"), wire("Ann")
lobby = hc:create_lobby(game)
pl = pc:join_game(lobby.game_id, "Ann")
lobby:start_game()
pump()
lobby:kick(pl.player_id)
pump()
test("no kicks once the game started", lines[#lines]:find("a kick after the game started", 1, true) and pl.state == "in_progress")
-- }}}

-- {{{ the screens
print("the screens")
local texts, calls
local backend = setmetatable({
    ui_text = function(t) texts[#texts + 1] = t calls.ui_text = (calls.ui_text or 0) + 1 end,
    ui_text_width = function(t, size) return #t * size / 2 end,
}, { __index = function(_, name) return function() calls[name] = (calls[name] or 0) + 1 end end })
local function draw(s) texts, calls = {}, {} s:draw(backend) return table.concat(texts, "|") end
local function button(s, id)
    for _, b in ipairs(s:layout().buttons) do if b.id == id then return b end end
end
local function click(s, id)
    local b = button(s, id)
    if not b then return false end
    s:update({ mx = b.x + 1, my = b.y + 1, lp = true })
    pump()
    return true
end
local function keys(s, list, extra)
    local i = { keys = list }
    for k, v in pairs(extra or {}) do i[k] = v end
    s:update(i)
    pump()
end

test("latency colours: green under 50 ms", lobby_ui.latency_colour(49) == "green" and lobby_ui.latency_colour(50) == "yellow")
test("yellow under 100, red from 100, grey unknown", lobby_ui.latency_colour(99.9) == "yellow" and lobby_ui.latency_colour(100) == "red"
    and lobby_ui.latency_colour(nil) == "dim")

fresh({ countdown_seconds = 3 })
hc, pc = wire("Host"), wire("Ann")
local full_host = wire("Full")
full_host:create_lobby({ map_name = "Full House", map_hash = "h", max_players = 1, game_mode = "melee", region = "eu" })
local back_pressed = false
local hs = lobby_ui.new(hc, { name = "Host", clock = clock, maps = { { map_name = "Castle Defense" }, { map_name = "Tower Rush" } },
    on_back = function() back_pressed = true end })
local ps = lobby_ui.new(pc, { name = "Ann", clock = clock })
test("the screens start at the browser", hs.screen == "browser" and ps.screen == "browser")
ps:refresh()
test("looking for games shows it is waiting", ps.busy == "Finding games")
ps:refresh()
test("one look at a time", #pc.lists == 1)
pump()
test("the answer fills the list", ps.busy == nil and #ps.games == 1 and ps.games[1].map_name == "Full House")
local rows = ps:rows()
test("a row: map, players, a ping not yet measured", rows[1].map == "Full House" and rows[1].players == "1/1" and rows[1].ping == "-")
test("a full game can't be joined", button(ps, "join_1") and not button(ps, "join_1").enabled)

click(hs, "create")
test("Create Game opens the dialog", hs.screen == "create")
click(hs, "map")
click(hs, "players")
click(hs, "mode")
test("its buttons change map, players and mode", hs.create_form.map == 2 and hs.create_form.players == 5 and hs.create_form.mode == 2)
for _ = 1, 8 do click(hs, "players") end
test("the player count wraps from 12 to 2", hs.create_form.players == 2, hs.create_form.players)
hs.create_form.players = 4
click(hs, "ok")
test("Create makes the lobby, and the host is in it", hs.screen == "lobby" and hs.lobby.is_host and hs.lobby.game.map_name == "Tower Rush"
    and hs.lobby.game.max_players == 4 and hs.lobby.game.game_mode == "co-op")

click(ps, "filter_region")
test("a filter button sets the filter and looks again", ps.filter.region == "us-west" and #ps.games == 1 and ps.games[1].map_name == "Tower Rush")
for _ = 1, 4 do click(ps, "filter_region") end
test("cycling past the last region is any region again", ps.filter.region == nil and #ps.games == 2)
click(ps, "filter_game_mode")
test("the mode filter", ps.filter.game_mode == "melee" and #ps.games == 1)
ps:set_filter("game_mode", nil)
pump()
ps:set_ping(ps.games[2].game_id, 120)
test("a measured ping shows, red over 100 ms", ps:rows()[2].ping == "120ms" and ps:rows()[2].tone == "red")
keys(ps, { "DOWN", "DOWN", "UP", "DOWN" })
test("Up and Down pick a game, within the list", ps.selected == 2)
local seen_browser = draw(ps)
test("the browser draws its title, columns and games", seen_browser:find("MULTIPLAYER", 1, true) and seen_browser:find("PING", 1, true)
    and seen_browser:find("Tower Rush", 1, true) and seen_browser:find("120ms", 1, true))
keys(ps, { "ENTER" })
test("Enter joins the picked game", ps.screen == "lobby" and ps.lobby.game_id == hs.lobby.game_id)
test("the host sees the player join in its chat", hs.chat[#hs.chat].text == "Ann joined")

local prow = ps:player_rows()
test("the player list: [H] for the host, seats, empty seats", prow[1].label == "[H] Host" and prow[2].label == "[2] Ann"
    and prow[2].you and prow[4].label == "[4] ..." and prow[4].empty)
test("Start is off while a player isn't ready", not hs:can_start() and not button(hs, "start").enabled)
test("only the host has Start and Kick", button(ps, "start") == nil and button(ps, "kick_" .. hs.lobby.player_id) == nil
    and button(hs, "kick_" .. ps.lobby.player_id) ~= nil)
keys(ps, { "R" }, { ctrl = true })
test("Ctrl+R: ready, with a tick, on both screens", ps:me().ready and ps:player_rows()[2].label == "[2] Ann \226\156\147"
    and hs:player_rows()[2].label:find("\226\156\147", 1, true))
test("now the host may start", hs:can_start() and button(hs, "start").enabled)

ps:update({ chars = "hello there" })
test("typing in the lobby goes to the chat line", ps.chat_input == "hello there")
keys(ps, { "BACKSPACE" })
keys(ps, { "ENTER" })
test("Enter sends it, to everyone", ps.chat_input == "" and hs.chat[#hs.chat].name == "Ann" and hs.chat[#hs.chat].text == "hello ther")
ps:update({ chars = "r", ctrl = true, keys = {} })
test("Ctrl with a key types nothing", ps.chat_input == "")
local lobby_text = draw(hs)
test("the lobby draws players, map info and chat", lobby_text:find("PLAYERS (2/4)", 1, true) and lobby_text:find("Name: Tower Rush", 1, true)
    and lobby_text:find("Ann: hello ther", 1, true) and lobby_text:find("LOBBY: Tower Rush", 1, true))

click(hs, "start")
test("Start begins the countdown, shown on both", hs.lobby:starting_in() == 3 and ps.chat[#ps.chat].text == "The game starts in 3 seconds"
    and draw(ps):find("Starting in 3", 1, true))
test("while it runs the host has Stop, not Start", button(hs, "start") == nil and button(hs, "cancel_start") ~= nil)
test("and can't start again", not hs:can_start() and hs:start() == false)
click(hs, "cancel_start")
test("Stop stops it", hs.lobby:starting_in() == nil and ps.chat[#ps.chat].text == "The start was stopped")
click(hs, "start")
wait(3.5)
test("when it runs out, both screens show the start", hs.screen == "started" and ps.screen == "started" and ps.started.ip == "10.0.0.1")
test("the started screen says where the host is", draw(ps):find("10.0.0.1", 1, true))

-- a second lobby for kicks, leaving and keys
fresh()
hc, pc = wire("Host"), wire("Ann")
hs = lobby_ui.new(hc, { name = "Host", clock = clock })
ps = lobby_ui.new(pc, { name = "Ann", clock = clock, toast_seconds = 2 })
hs:create({ map_name = "Kick Arena", map_hash = "h", max_players = 3, game_mode = "melee", region = "eu" })
pump()
ps:refresh() pump()
ps:join(1) pump()
ps.games = {}
click(hs, "kick_" .. ps.lobby.player_id)
test("Kick sends the player back to the browser, told why", ps.screen == "browser" and ps.toasts[1].text == "You were kicked from the lobby")
test("and its browser looks for games again", #ps.games == 1)
test("the host's chat says so", hs.chat[#hs.chat].text == "Ann was kicked")
test("a toast is drawn", draw(ps):find("You were kicked from the lobby", 1, true))
now = now + 2
ps:update({})
test("and goes after its seconds", #ps.toasts == 0)
ps:join(1) pump()
keys(ps, { "ESCAPE" })
test("Escape leaves the lobby for the browser", ps.screen == "browser" and ps.lobby == nil and hs.chat[#hs.chat].text == "Ann left")
test("leaving by choice is no toast", #ps.toasts == 0)
ps:join(1) pump()
ps.lobby:leave()
pump()
test("the game leaving the lobby itself: back to the browser, no toast", ps.screen == "browser" and #ps.toasts == 0)
ps:join(1) pump()
keys(ps, { "R" })
test("R without Ctrl doesn't touch ready", not ps:me().ready)
click(ps, "leave")
test("so does the Leave button", ps.screen == "browser")
ps:join(1) pump()
click(ps, "back")
test("and the back arrow", ps.screen == "browser")
ps:join(1) pump()
click(hs, "leave")
test("the host leaving closes the lobby; the player is told", ps.screen == "browser" and ps.toasts[#ps.toasts].text == "The lobby closed")

-- keyboard navigation
local L = ps:layout()
ps.focus = nil
keys(ps, { "TAB" })
test("Tab goes to the first button that works", ps.focus == 2 and ps:layout().buttons[2].id == "find", ps.focus)
keys(ps, { "TAB", "TAB" })
test("and on", ps:layout().buttons[ps.focus].id == "filter_region")
keys(ps, { "TAB" }, { shift = true })
test("Shift+Tab goes back", ps:layout().buttons[ps.focus].id == "create")
keys(ps, { "SPACE" })
test("Space presses the button in focus", ps.screen == "create")
keys(ps, { "ESCAPE" })
test("Escape leaves the dialog", ps.screen == "browser")
ps.focus = nil
keys(ps, { "ESCAPE" })
keys(hs, { "ESCAPE" })
test("Escape in the browser goes back when the game gave a way back", not back_pressed)
local bs = lobby_ui.new(pc, { clock = clock, on_back = function() back_pressed = true end })
keys(bs, { "ESCAPE" })
test("(it did here)", back_pressed)

-- refusals and a lost connection
ps:refresh() pump()
hs:create({ map_name = "Second", map_hash = "h", max_players = 2, game_mode = "melee", region = "eu" })
pump()
ps.games = { { game_id = 999, map_name = "Gone", game_mode = "x", region = "x", players = 0, max_players = 2 } }
ps:join(1) pump()
test("a refused join is a toast, and the browser stays", ps.screen == "browser" and ps.toasts[#ps.toasts].text == "Couldn't join: no such game")
hs:create({ map_name = "Third", map_hash = "h", max_players = 2, game_mode = "melee", region = "eu" })
test("a call the library refuses is a toast too", hs.toasts[#hs.toasts].text:find("Couldn't create the game", 1, true) ~= nil, hs.toasts[#hs.toasts] and hs.toasts[#hs.toasts].text)
srv:close(wires[1].id, "test")
pump()
test("a lost connection: a toast and back to the browser", hs.screen == "browser" and hs.toasts[#hs.toasts].text:find("Connection lost", 1, true))
local cs = lobby_ui.new(pc, { clock = clock })
cs:open_create()
srv:close(wires[2].id, "test")
pump()
test("a connection lost on any screen goes back to the browser", cs.screen == "browser" and cs.toasts[1].text:find("Connection lost", 1, true))
hs:refresh()
test("asking while disconnected is a toast, not an error", hs.busy == nil and hs.toasts[#hs.toasts].text:find("not connected", 1, true))

-- chat that runs long, and the window's size
ps:join(1)
fresh()
pc = wire("Ann") hc = wire("Host")
ps = lobby_ui.new(pc, { name = "Ann", clock = clock, chat_keep = 30 })
hs = lobby_ui.new(hc, { name = "Host", clock = clock })
hs:create({ map_name = "Chatty", map_hash = "h", max_players = 2, game_mode = "melee", region = "eu" }) pump()
ps:refresh() pump() ps:join(1) pump()
for i = 1, 40 do hs.lobby:send_chat("line " .. i) end
pump()
test("chat keeps its last lines", #ps.chat == 30 and ps.chat[30].text == "line 40")
keys(ps, { "PAGEUP" })
local scrolled = ps.chat_scroll
test("Page Up scrolls back", scrolled > 0 and not draw(ps):find("line 40", 1, true))
hs.lobby:send_chat("new")
pump()
test("a new line scrolls to the bottom", ps.chat_scroll == 0 and draw(ps):find("Host: new", 1, true))
keys(ps, { "PAGEUP" })
hs.lobby:set_ready(true)
pump()
test("so does a line of the lobby's own", ps.chat_scroll == 0 and ps.chat[#ps.chat].text == "Host is ready")
ps:update({ wheel = 1000 })
test("the wheel scrolls, no further than the first line", ps.chat_scroll == 30 - ps:layout().chat_lines)
keys(ps, { "PAGEDOWN", "PAGEDOWN", "PAGEDOWN", "PAGEDOWN", "PAGEDOWN" })
test("Page Down back to the bottom, no further", ps.chat_scroll == 0)
ps:update({ chars = string.rep("x", 400) })
test("a long chat line shows its end", draw(ps):find(string.rep("x", 10), 1, true) ~= nil)

local function fits(s, w, h)
    s:update({ w = w, h = h })
    local L = s:layout()
    for i, a in ipairs(L.buttons) do
        if a.x < 0 or a.y < 0 or a.x + a.w > w or a.y + a.h > h then return false, a.id .. " outside" end
        for j = i + 1, #L.buttons do
            local b = L.buttons[j]
            if a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then return false, a.id .. " over " .. b.id end
        end
    end
    return true
end
for _, size in ipairs({ { 800, 600 }, { 1280, 720 }, { 1920, 1080 }, { 640, 480 } }) do
    for _, s in ipairs({ hs, ps }) do
        local ok, err = fits(s, size[1], size[2])
        test("at " .. size[1] .. "x" .. size[2] .. ", the " .. (s.lobby.is_host and "host's" or "player's") .. " lobby fits, no button over another", ok, err)
    end
end
local bsz = lobby_ui.new(pc, { clock = clock })
bsz.games = {}
for i = 1, 50 do bsz.games[i] = { game_id = i, map_name = "Map " .. i, game_mode = "m", region = "r", players = 1, max_players = 2 } end
local ok, err = fits(bsz, 800, 600)
test("the browser with 50 games fits too", ok, err)
local L6 = bsz:layout()
test("only the rows that fit are laid out", #L6.rows == L6.visible and L6.visible < 50)
test("the last of them inside the list", L6.rows[#L6.rows].y + L6.rows[#L6.rows].h <= L6.list.y + L6.list.h)
bsz.selected = 40
bsz:update({})
test("the picked game is scrolled into view", bsz:layout().rows[#bsz:layout().rows].index == 40)
keys(bsz, { "UP" })
bsz.selected = 1
bsz:update({})
test("and back to the top", bsz:layout().rows[1].index == 1)
test("text too long for its place is cut with ...", lobby_ui.fit(backend, "a very long map name indeed", 14, 70) == "a very ..."
    and lobby_ui.fit(backend, "short", 14, 70) == "short")
-- }}}

print(string.format("\nTests: %d passed, %d failed", pass_count, test_count - pass_count))
print(string.format("matchmaking lobby screens: %d of %d passed", pass_count, test_count))
os.exit(pass_count == test_count and 0 or 1)
