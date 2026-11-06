--[[
Multiplayer Screens (Issue 801e)

The game browser, the create-game dialog and the lobby screen, over a
connection of the matchmaking client library (matchmaking/client.lua).
Built like the in-game interface (ui/wc3/hud.lua): the screens keep their
own state, `update(input, dt)` takes a frame's input, and `draw(ui)` draws
through a 2D backend with the render.ui_* calls (the real render module,
or a recorder in tests), so it all runs headless.

    local lobby_ui = require("ui.multiplayer.lobby_ui")
    local s = lobby_ui.new(conn, { w = 1280, h = 720, name = "Ann" })
    s:refresh()                -- ask for the games
    -- each frame:
    conn:poll()
    s:update(input, dt)        -- input as the HUD takes it: mx, my, lp, keys, chars, ctrl
    s:draw(render)

Screens (`s.screen`): "browser", "create", "lobby", "started" (the game
began; `s.started` is the host's address). `s.busy` names what it waits
for ("Finding games", "Joining", "Creating game"), `s.toasts` the
messages shown for a few seconds (refusals, a lost connection, a kick).

Keys: in the browser Up/Down pick a game, Enter joins it, F5 looks
again; in the lobby typing goes to the chat line, Enter sends it,
Ctrl+R toggles ready, Escape leaves; everywhere Tab moves between the
buttons and Space presses the one in focus (in the lobby, where Space
types, Enter with nothing typed does).
]]

local lobby_ui = {}
local Screens = {}
Screens.__index = Screens

lobby_ui.DEFAULTS = {
    w = 1280, h = 720,
    name = "player",
    toast_seconds = 4,
    chat_keep = 200,                      -- lines of chat kept
    regions = { "us-west", "us-east", "eu", "asia" },
    modes = { "melee", "co-op", "custom" },
    maps = { { map_name = "Castle Defense", map_hash = "", asset_packs = {} } },
}

-- {{{ colours
local C = {
    back = { 18, 22, 30 }, panel = { 30, 36, 48 }, line = { 70, 80, 100 },
    text = { 225, 228, 235 }, dim = { 140, 148, 160 }, accent = { 240, 200, 70 },
    button = { 52, 62, 82 }, focus = { 240, 200, 70 }, off = { 40, 44, 52 },
    green = { 90, 200, 90 }, yellow = { 230, 200, 60 }, red = { 220, 70, 60 },
    toast = { 60, 30, 30 },
}
lobby_ui.COLOURS = C

-- Green under 50 ms, yellow under 100, red from 100 (the issue's colours).
function lobby_ui.latency_colour(ms)
    if not ms then return "dim", C.dim end
    if ms < 50 then return "green", C.green end
    if ms < 100 then return "yellow", C.yellow end
    return "red", C.red
end
-- }}}

-- {{{ lobby_ui.new
function lobby_ui.new(conn, options)
    local o = {}
    for k, v in pairs(lobby_ui.DEFAULTS) do o[k] = v end
    for k, v in pairs(options or {}) do o[k] = v end
    local self = setmetatable({ conn = conn, o = o, w = o.w, h = o.h, screen = "browser",
        clock = o.clock or conn.clock or os.time, games = {}, pings = {}, filter = {}, selected = 1, scroll = 0,
        toasts = {}, chat = {}, chat_input = "", chat_scroll = 0, focus = nil,
        create_form = { map = 1, players = 4, mode = 1 } }, Screens)
    conn:on("disconnect", function(why)
        self:toast("Connection lost: " .. tostring(why))
        self.busy = nil
        if self.screen ~= "started" then self:to_browser() end
    end)
    return self
end
-- }}}

-- {{{ messages and waiting
function Screens:toast(text)
    self.toasts[#self.toasts + 1] = { text = text, ["until"] = self.clock() + self.o.toast_seconds }
end

-- Runs a call of the client library that may raise (not connected, a
-- lobby already open): its error becomes a toast.
function Screens:try(what, f)
    local ok, err = pcall(f)
    if not ok then
        self.busy = nil
        self:toast(what .. ": " .. tostring(err))
    end
    return ok
end

local function say(self, text)
    self.chat[#self.chat + 1] = { text = text }
    while #self.chat > self.o.chat_keep do table.remove(self.chat, 1) end
    self.chat_scroll = 0                  -- new lines scroll to the bottom
end
-- }}}

-- {{{ the browser
function Screens:to_browser()
    self.screen, self.lobby, self.focus = "browser", nil, nil
end

function Screens:refresh()
    if self.busy then return end
    self.busy = "Finding games"
    self:try("Couldn't list the games", function()
        self.conn:list_games(self.filter, function(games, err)
            self.busy = nil
            if not games then return self:toast("Couldn't list the games: " .. tostring(err)) end
            self.games = games
            self.selected = math.min(math.max(self.selected, 1), math.max(#games, 1))
        end)
    end)
end

-- key: "region", "game_mode" or "free_slots"; nil value: any.
function Screens:set_filter(key, value)
    self.filter[key] = value
    self:refresh()
end

local function cycle(list, current)
    if current == nil then return list[1] end
    for i, v in ipairs(list) do
        if v == current then return list[i + 1] end      -- past the end: nil, "any"
    end
    return nil
end

function Screens:next_filter(key)
    local lists = { region = self.o.regions, game_mode = self.o.modes, free_slots = { 1, 2, 4 } }
    self:set_filter(key, cycle(lists[key], self.filter[key]))
end

-- A measured round trip to a game's host (nothing measures it yet; the
-- NAT punch of 801d is the place to).
function Screens:set_ping(game_id, ms) self.pings[game_id] = ms end

-- What a row of the browser shows.
function Screens:rows()
    local rows = {}
    for i, g in ipairs(self.games) do
        local ms = self.pings[g.game_id]
        local tone, colour = lobby_ui.latency_colour(ms)
        rows[i] = { game = g, map = g.map_name, mode = g.game_mode, region = g.region,
            players = g.players .. "/" .. g.max_players, full = g.players >= g.max_players,
            ping = ms and (math.floor(ms + 0.5) .. "ms") or "-", tone = tone, colour = colour }
    end
    return rows
end

local function open(self, lobby)
    self.lobby, self.screen, self.focus = lobby, "lobby", nil
    self.chat, self.chat_input, self.chat_scroll = {}, "", 0
    lobby:on("player_join", function(p) say(self, p.name .. " joined") end)
    lobby:on("player_leave", function(p, how) say(self, (p.name or ("player " .. p.player_id)) .. (how == "kicked" and " was kicked" or " left")) end)
    lobby:on("player_ready", function(p, ready) say(self, p.name .. (ready and " is ready" or " is not ready")) end)
    lobby:on("chat", function(p, text) self.chat[#self.chat + 1] = { name = p.name or ("player " .. p.player_id), text = text }
        while #self.chat > self.o.chat_keep do table.remove(self.chat, 1) end
        self.chat_scroll = 0 end)
    lobby:on("countdown", function(seconds) say(self, "The game starts in " .. seconds .. " seconds") end)
    lobby:on("countdown_cancel", function(p) say(self, "The start was stopped") end)
    lobby:on("game_start", function(where) self.screen, self.started = "started", where end)
    lobby:on("closed", function(why)
        if self.lobby ~= lobby then return end
        if why == "kicked by the host" then self:toast("You were kicked from the lobby")
        elseif why ~= "left" then self:toast("The lobby closed") end
        self:to_browser()
        if self.conn.state == "connected" then self:refresh() end
    end)
end

function Screens:join(i)
    local g = self.games[i or self.selected]
    if not g or self.busy then return end
    self.busy = "Joining"
    self:try("Couldn't join", function()
        self.conn:join_game(g, self.o.name, function(lobby, why)
            self.busy = nil
            if not lobby then return self:toast("Couldn't join: " .. tostring(why)) end
            open(self, lobby)
        end)
    end)
end
-- }}}

-- {{{ creating a game
function Screens:open_create() self.screen, self.focus = "create", nil end

function Screens:create(game)
    if self.busy then return end
    if not game then
        local f = self.create_form
        local map = self.o.maps[f.map]
        game = { map_name = map.map_name, map_hash = map.map_hash or "", asset_packs = map.asset_packs or {},
            max_players = f.players, game_mode = self.o.modes[f.mode], region = self.filter.region or self.o.regions[1],
            host_name = self.o.name }
    end
    self.busy = "Creating game"
    self:try("Couldn't create the game", function()
        self.conn:create_lobby(game, function(lobby, why)
            self.busy = nil
            if not lobby then return self:toast("Couldn't create the game: " .. tostring(why)) end
            open(self, lobby)
        end)
    end)
end
-- }}}

-- {{{ the lobby
function Screens:me()
    for _, p in ipairs(self.lobby and self.lobby.players or {}) do
        if p.player_id == self.lobby.player_id then return p end
    end
end

function Screens:is_host() return self.lobby and self.lobby.is_host end

-- What a row of the player list shows: [H] for the host, its seat number
-- otherwise, and a tick when ready.
function Screens:player_rows()
    local rows = {}
    local l = self.lobby
    if not l then return rows end
    for i, p in ipairs(l.players) do
        local host = p.player_id == l.host_id
        rows[i] = { player = p, host = host, you = p.player_id == l.player_id,
            label = (host and "[H] " or ("[" .. i .. "] ")) .. p.name .. (p.ready and " \226\156\147" or "") }
    end
    for i = #l.players + 1, (l.game and l.game.max_players) or #l.players do
        rows[i] = { label = "[" .. i .. "] ...", empty = true }
    end
    return rows
end

-- The host may start when every other player is ready.
function Screens:can_start()
    local l = self.lobby
    if not (l and l.is_host and l.state == "waiting" and not l.start_at) then return false end
    for _, p in ipairs(l.players) do
        if p.player_id ~= l.player_id and not p.ready then return false end
    end
    return true
end

function Screens:toggle_ready()
    local me = self:me()
    if not me then return end
    self:try("Couldn't change ready", function() self.lobby:set_ready(not me.ready) end)
end

function Screens:send_chat()
    local text = self.chat_input
    if text == "" or not self.lobby then return false end
    if self:try("Couldn't send", function() self.lobby:send_chat(text) end) then self.chat_input = "" end
    return true
end

function Screens:start()
    if not self:can_start() then return false end
    return self:try("Couldn't start", function() self.lobby:start_game() end)
end

function Screens:cancel_start()
    if not (self:is_host() and self.lobby.start_at) then return false end
    return self:try("Couldn't stop the start", function() self.lobby:cancel_start() end)
end

function Screens:kick(player_id)
    if not self:is_host() then return false end
    return self:try("Couldn't kick", function() self.lobby:kick(player_id) end)
end

function Screens:leave()
    if not self.lobby then return end
    local l = self.lobby
    self:to_browser()
    self:try("Couldn't leave", function() l:leave() end)
    self:refresh()
end
-- }}}

-- {{{ layout
-- Every rectangle of the screen shown, for a w x h window; `buttons` in
-- the order Tab goes through them, each { id, label, x, y, w, h,
-- enabled, act }.
local function rect(x, y, w, h) return { x = x, y = y, w = w, h = h } end

function Screens:resize(w, h) self.w, self.h = w, h end

function Screens:layout()
    local w, h = self.w, self.h
    local L = { buttons = {} }
    local function button(id, label, x, y, bw, bh, enabled, act)
        local b = rect(x, y, bw, bh)
        b.id, b.label, b.enabled, b.act = id, label, enabled ~= false and not self.busy, act
        L.buttons[#L.buttons + 1] = b
        return b
    end
    local pad, bar = 12, 44
    L.top = rect(0, 0, w, bar)
    if self.screen == "browser" then
        button("back", "<", pad, 8, 32, 28, self.o.on_back ~= nil, function() self.o.on_back() end)
        button("find", "Find Game", w - pad - 260, 8, 120, 28, true, function() self:refresh() end)
        button("create", "Create Game", w - pad - 130, 8, 130, 28, true, function() self:open_create() end)
        local fy = bar + 8
        local fw = math.min(220, (w - 2 * pad - 2 * 8) / 3)
        local labels = { region = "Region: " .. (self.filter.region or "Any"),
            free_slots = "Players: " .. (self.filter.free_slots and (self.filter.free_slots .. "+ free") or "Any"),
            game_mode = "Mode: " .. (self.filter.game_mode or "All") }
        for i, key in ipairs({ "region", "free_slots", "game_mode" }) do
            button("filter_" .. key, labels[key], pad + (i - 1) * (fw + 8), fy, fw, 28, true, function() self:next_filter(key) end)
        end
        L.list = rect(pad, fy + 40, w - 2 * pad, h - (fy + 40) - pad)
        L.row_h = 28
        L.visible = math.max(0, math.floor((L.list.h - L.row_h) / L.row_h))
        if self.selected > self.scroll + L.visible then self.scroll = self.selected - L.visible end
        if self.selected <= self.scroll then self.scroll = math.max(0, self.selected - 1) end
        L.rows = {}
        local rows = self:rows()
        for i = self.scroll + 1, math.min(#rows, self.scroll + L.visible) do
            local y = L.list.y + L.row_h * (i - self.scroll)
            local r = rect(L.list.x, y, L.list.w, L.row_h)
            r.index = i
            L.rows[#L.rows + 1] = r
            r.join = button("join_" .. i, "Join", L.list.x + L.list.w - 70, y + 2, 64, L.row_h - 4, not rows[i].full,
                function() self.selected = i self:join(i) end)
        end
    elseif self.screen == "create" then
        local pw, ph = math.min(420, w - 2 * pad), 220
        L.panel = rect((w - pw) / 2, (h - ph) / 2, pw, ph)
        local f = self.create_form
        local x, y, bw = L.panel.x + 16, L.panel.y + 44, L.panel.w - 32
        button("map", "Map: " .. self.o.maps[f.map].map_name, x, y, bw, 28, true,
            function() f.map = f.map % #self.o.maps + 1 end)
        button("players", "Players: " .. f.players, x, y + 36, bw, 28, true,
            function() f.players = f.players % 12 + 1 if f.players == 1 then f.players = 2 end end)
        button("mode", "Mode: " .. self.o.modes[f.mode], x, y + 72, bw, 28, true,
            function() f.mode = f.mode % #self.o.modes + 1 end)
        button("cancel", "Cancel", x, L.panel.y + ph - 44, 100, 28, true, function() self:to_browser() end)
        button("ok", "Create", L.panel.x + pw - 16 - 100, L.panel.y + ph - 44, 100, 28, true, function() self:create() end)
    elseif self.screen == "lobby" then
        local l = self.lobby
        button("back", "<", pad, 8, 32, 28, true, function() self:leave() end)
        local me = self:me()
        button("ready", (me and me.ready) and "\226\156\147 Ready" or "Ready", w - pad - 110, 8, 110, 28, true,
            function() self:toggle_ready() end)
        button("leave", "Leave", w - pad - 110 - 8 - 90, 8, 90, 28, true, function() self:leave() end)
        local split = math.floor(w * 0.38)
        L.players = rect(pad, bar + 8, split - pad - 6, h - bar - 8 - pad)
        L.chat = rect(split + 6, bar + 8, w - split - 6 - pad, h - bar - 8 - pad)
        L.row_h = 26
        L.player_rows = {}
        for i, row in ipairs(self:player_rows()) do
            local r = rect(L.players.x + 8, L.players.y + 32 + (i - 1) * L.row_h, L.players.w - 16, L.row_h)
            r.row = row
            L.player_rows[i] = r
            if l.is_host and row.player and not row.you then
                r.kick = button("kick_" .. row.player.player_id, "Kick", r.x + r.w - 54, r.y + 2, 52, L.row_h - 4, true,
                    function() self:kick(row.player.player_id) end)
            end
        end
        L.info = rect(L.players.x + 8, L.players.y + 40 + #L.player_rows * L.row_h, L.players.w - 16, 100)
        L.input = rect(L.chat.x + 8, L.chat.y + L.chat.h - 36, L.chat.w - 16 - 80, 28)
        button("send", "Send", L.input.x + L.input.w + 8, L.input.y, 72, 28, true, function() self:send_chat() end)
        L.log = rect(L.chat.x + 8, L.chat.y + 32, L.chat.w - 16, L.input.y - (L.chat.y + 32) - 8 - (l.is_host and 40 or 0))
        if l.is_host then
            local hy = L.input.y - 40
            if l.start_at then
                button("cancel_start", "Stop", L.chat.x + 8, hy, 120, 28, true, function() self:cancel_start() end)
            else
                button("start", "Start Game", L.chat.x + 8, hy, 120, 28, self:can_start(), function() self:start() end)
            end
        end
        L.chat_lines = math.max(1, math.floor(L.log.h / 20))
    end
    if self.focus and self.focus > #L.buttons then self.focus = nil end
    return L
end

function lobby_ui.inside(r, x, y)
    return x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h
end
-- }}}

-- {{{ update
local function press(self, b)
    if b and b.enabled then b.act() return true end
    return false
end

local function next_focus(self, L, step)
    local n = #L.buttons
    if n == 0 then return end
    local i = self.focus or (step > 0 and 0 or 1)
    for _ = 1, n do
        i = (i - 1 + step) % n + 1
        if L.buttons[i].enabled then self.focus = i return end
    end
end

function Screens:update(input, dt)
    input = input or {}
    local now = self.clock()
    for i = #self.toasts, 1, -1 do
        if now >= self.toasts[i]["until"] then table.remove(self.toasts, i) end
    end
    if input.w and input.h then self:resize(input.w, input.h) end
    local L = self:layout()
    if self.screen == "lobby" and input.chars and input.chars ~= "" and not input.ctrl then
        self.chat_input = self.chat_input .. input.chars
    end
    for _, k in ipairs(input.keys or {}) do
        self:key(k, input, L)
        L = self:layout()
    end
    if input.wheel and self.screen == "lobby" then
        self.chat_scroll = math.max(0, math.min(#self.chat - L.chat_lines, self.chat_scroll + input.wheel))
    end
    if input.lp then
        local mx, my = input.mx or 0, input.my or 0
        for i, b in ipairs(L.buttons) do
            if lobby_ui.inside(b, mx, my) then
                self.focus = nil              -- focus is the keyboard's; a click leaves Enter to its usual job
                press(self, b)
                return
            end
        end
        for _, r in ipairs(L.rows or {}) do
            if lobby_ui.inside(r, mx, my) then self.selected = r.index return end
        end
    end
end

function Screens:key(k, input, L)
    if k == "TAB" then return next_focus(self, L, input.shift and -1 or 1) end
    if k == "SPACE" and self.focus and self.screen ~= "lobby" then press(self, L.buttons[self.focus]) return end
    if self.screen == "browser" then
        if k == "UP" then self.selected = math.max(1, self.selected - 1)
        elseif k == "DOWN" then self.selected = math.min(math.max(#self.games, 1), self.selected + 1)
        elseif k == "F5" then self:refresh()
        elseif k == "ENTER" then
            if self.focus then press(self, L.buttons[self.focus]) else self:join(self.selected) end
        elseif k == "ESCAPE" and self.o.on_back then self.o.on_back() end
    elseif self.screen == "create" then
        if k == "ENTER" then
            if self.focus then press(self, L.buttons[self.focus]) else self:create() end
        elseif k == "ESCAPE" then self:to_browser() end
    elseif self.screen == "lobby" then
        if k == "ESCAPE" then self:leave()
        elseif k == "R" and input.ctrl then self:toggle_ready()
        elseif k == "BACKSPACE" then self.chat_input = self.chat_input:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
        elseif k == "ENTER" then
            if not self:send_chat() and self.focus then press(self, L.buttons[self.focus]) end
        elseif k == "PAGEUP" then self.chat_scroll = math.max(0, math.min(#self.chat - L.chat_lines, self.chat_scroll + L.chat_lines))
        elseif k == "PAGEDOWN" then self.chat_scroll = math.max(0, self.chat_scroll - L.chat_lines) end
    end
end
-- }}}

-- {{{ draw
local function fill(ui, r, c, a) ui.ui_rect(r.x, r.y, r.w, r.h, c[1], c[2], c[3], a or 255) end
local function text(ui, s, x, y, size, c) ui.ui_text(s, x, y, size, c[1], c[2], c[3], 255) end

-- `s` cut to fit `width` pixels, with "..." when cut.
function lobby_ui.fit(ui, s, size, width)
    if ui.ui_text_width(s, size) <= width then return s end
    local cut = s
    while #cut > 0 and ui.ui_text_width(cut .. "...", size) > width do
        cut = cut:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
    end
    return cut .. "..."
end
local fit = lobby_ui.fit

local function draw_button(self, ui, b, i)
    fill(ui, b, b.enabled and C.button or C.off)
    if self.focus == i then ui.ui_frame(b.x, b.y, b.w, b.h, 2, C.focus[1], C.focus[2], C.focus[3], 255) end
    local label = fit(ui, b.label, 14, b.w - 8)
    text(ui, label, b.x + (b.w - ui.ui_text_width(label, 14)) / 2, b.y + (b.h - 14) / 2, 14, b.enabled and C.text or C.dim)
end

function Screens:draw(ui)
    local L = self:layout()
    fill(ui, { x = 0, y = 0, w = self.w, h = self.h }, C.back)
    fill(ui, L.top, C.panel)
    local title = ({ browser = "MULTIPLAYER", create = "CREATE GAME", started = "STARTING",
        lobby = "LOBBY: " .. (self.lobby and self.lobby.game and self.lobby.game.map_name or "") })[self.screen] or ""
    text(ui, fit(ui, title, 18, self.w / 2 - 60), 56, 12, 18, C.accent)
    if self.conn.latency_ms then
        local _, c = lobby_ui.latency_colour(self.conn.latency_ms)
        local s = "Server " .. math.floor(self.conn.latency_ms + 0.5) .. "ms"
        text(ui, s, self.w / 2, 14, 14, c)
    end
    if self.screen == "browser" then
        fill(ui, L.list, C.panel)
        local cols = { 0.02, 0.48, 0.66, 0.80 }
        local x = L.list.x
        for i, head in ipairs({ "MAP NAME", "MODE", "PLAYERS", "PING" }) do
            text(ui, head, x + cols[i] * L.list.w, L.list.y + 6, 13, C.dim)
        end
        local rows = self:rows()
        for _, r in ipairs(L.rows) do
            local row = rows[r.index]
            if r.index == self.selected then fill(ui, r, C.button, 160) end
            text(ui, fit(ui, row.map, 14, (cols[2] - cols[1]) * L.list.w - 8), x + cols[1] * L.list.w, r.y + 7, 14, C.text)
            text(ui, fit(ui, row.mode, 14, (cols[3] - cols[2]) * L.list.w - 8), x + cols[2] * L.list.w, r.y + 7, 14, C.text)
            text(ui, row.players, x + cols[3] * L.list.w, r.y + 7, 14, row.full and C.dim or C.text)
            text(ui, row.ping, x + cols[4] * L.list.w, r.y + 7, 14, row.colour)
        end
        if #rows == 0 and not self.busy then text(ui, "No games found", L.list.x + 12, L.list.y + 40, 14, C.dim) end
    elseif self.screen == "create" then
        fill(ui, L.panel, C.panel)
        text(ui, "New game", L.panel.x + 16, L.panel.y + 14, 16, C.accent)
    elseif self.screen == "lobby" then
        local l = self.lobby
        local g = l.game or {}
        fill(ui, L.players, C.panel)
        fill(ui, L.chat, C.panel)
        text(ui, "PLAYERS (" .. #l.players .. "/" .. (g.max_players or #l.players) .. ")", L.players.x + 8, L.players.y + 8, 14, C.dim)
        for _, r in ipairs(L.player_rows) do
            local room = r.kick and (r.w - 60) or r.w
            text(ui, fit(ui, r.row.label, 14, room), r.x, r.y + 5, 14, r.row.empty and C.dim or (r.row.you and C.accent or C.text))
        end
        local info = { "MAP INFO", "Name: " .. (g.map_name or ""), "Mode: " .. (g.game_mode or ""),
            "Players: 1-" .. (g.max_players or #l.players) }
        for _, p in ipairs(g.asset_packs or {}) do info[#info + 1] = "Asset pack: " .. p.id end
        for i, s in ipairs(info) do
            text(ui, fit(ui, s, 13, L.info.w), L.info.x, L.info.y + (i - 1) * 18, 13, i == 1 and C.dim or C.text)
        end
        text(ui, "CHAT", L.chat.x + 8, L.chat.y + 8, 14, C.dim)
        local last = #self.chat - self.chat_scroll
        local first = math.max(1, last - L.chat_lines + 1)
        for i = first, last do
            local line = self.chat[i]
            local s = line.name and (line.name .. ": " .. line.text) or line.text
            text(ui, fit(ui, s, 14, L.log.w), L.log.x, L.log.y + (i - first) * 20, 14, line.name and C.text or C.dim)
        end
        local starting = l:starting_in()
        if starting then
            text(ui, "Starting in " .. math.ceil(starting), L.chat.x + L.chat.w - 160, L.chat.y + 8, 16, C.accent)
        end
        ui.ui_frame(L.input.x, L.input.y, L.input.w, L.input.h, 1, C.line[1], C.line[2], C.line[3], 255)
        local typed = self.chat_input == "" and "Type message..." or self.chat_input
        local shown = typed
        while #shown > 0 and ui.ui_text_width(shown, 14) > L.input.w - 12 do
            shown = shown:gsub("^[%z\1-\127\194-\244][\128-\191]*", "")        -- the end of a long line stays in view
        end
        text(ui, shown, L.input.x + 6, L.input.y + 7, 14, self.chat_input == "" and C.dim or C.text)
    elseif self.screen == "started" then
        local s = "The game is starting: host " .. tostring(self.started and self.started.ip) .. ":" .. tostring(self.started and self.started.port)
        text(ui, fit(ui, s, 16, self.w - 24), 12, self.h / 2, 16, C.text)
    end
    for i, b in ipairs(L.buttons) do draw_button(self, ui, b, i) end
    if self.busy then
        local dots = string.rep(".", math.floor(self.clock() * 3) % 4)
        text(ui, self.busy .. dots, self.w / 2 - 60, self.h - 30, 14, C.accent)
    end
    for i, t in ipairs(self.toasts) do
        local s = fit(ui, t.text, 14, self.w - 64)
        local tw = ui.ui_text_width(s, 14) + 24
        local r = { x = (self.w - tw) / 2, y = self.h - 70 - (i - 1) * 34, w = tw, h = 28 }
        fill(ui, r, C.toast, 230)
        text(ui, s, r.x + 12, r.y + 7, 14, C.text)
    end
end
-- }}}

return lobby_ui
