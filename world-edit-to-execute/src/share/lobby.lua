--[[
The Lobby's Side of Shared Lists (Issue 609c)

What the game does with shared map-and-model lists, without drawing
anything: it polls rmail now and then, turns what's waiting into one
dialog at a time, takes the player's answer, attaches an applied list to
the asset loader for this game, and takes it off again after the game,
unless the player asked to keep it. ui/wc3/share_prompt.lua draws the
dialogs; this file decides them.

    local lobby = require("share.lobby")
    local Lb = lobby.new({ data = folder, me = "ben", transport = t,   -- or connection = C (rmail)
                           loader = L })                               -- optional
    Lb:update(dt)              -- from the game's tick: polls rmail every poll_every seconds
    local d = Lb:dialog()      -- the dialog to show now, or nil
    Lb:press(d, "yes")         -- the player pressed one of d.buttons (its id)
    Lb:end_game()              -- revert what was applied, keep what the player kept

A dialog is { kind, id, title, lines = {...}, buttons = { {id, label}, ... } },
one of:

  question   a list arrived: Yes, No, "Always from <sender>", "Always for
             this map" (exchange.prompt gives the words)
  ready      a list was applied for this game: "Keep them after the game", OK
  notice     a problem, or rmail isn't set up yet: OK

There's no hook for a game that ends without saying so (the window
closed, the program stopped), so lobby.new first settles whatever an
earlier game left applied: reverted, or kept when the player had asked.
]]

local exchange = require("share.exchange")
local profile = require("share.profile")

local lobby = {}

lobby.POLL_EVERY = 5          -- seconds between rmail polls
lobby.MAX_LINES = 14          -- a question's provenance lines shown; the rest are counted

local Lb = {}
Lb.__index = Lb

-- {{{ local helpers
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local t = f:read("*a")
    f:close()
    return t
end

local function exists(path)
    return os.rename(path, path) ~= nil
end

local function keep_file(data, name)
    return data .. "/profiles/" .. name .. ".keep"
end

-- A pack name from free text: what a folder name can hold.
local function pack_name(text)
    local name = tostring(text):gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rRnN]", " ")
    name = name:gsub("[/%z\n\r\t\\]", " "):gsub("%s+", " "):gsub("^[%s%.]+", ""):gsub("%s+$", "")
    if name == "" then name = "shared models" end
    return name:sub(1, 80)
end
-- }}}

-- {{{ function lobby.settle
-- What an earlier game left applied: kept as an asset pack when the player
-- asked (a .keep file beside it, holding the pack's name), else reverted.
-- Gives { {name, kept = pack folder or nil}, ... }.
function lobby.settle(data, store)
    local out = {}
    for _, name in ipairs(profile.leftovers(data)) do
        local P = profile.open(data, name, store)
        if P then
            local wish = read_file(keep_file(data, name))
            local kept
            if wish then
                local ok, pack = pcall(P.keep, P, lobby.free_pack_name(data, wish))
                kept = ok and pack or nil
                if not ok then P:revert() end
            else
                P:revert()
            end
            os.remove(keep_file(data, name))
            out[#out + 1] = { name = name, kept = kept }
        end
    end
    return out
end

-- NAME, or NAME 2, NAME 3 ... the first that isn't an asset pack yet.
function lobby.free_pack_name(data, name)
    name = pack_name(name)
    local try, n = name, 2
    while exists(data .. "/asset-packs/" .. try) do
        try = name .. " " .. n
        n = n + 1
    end
    return try
end
-- }}}

-- {{{ function lobby.new
-- opts: data (the player data folder), me (this player's name, for message
-- ids; default the rmail config's name), connection (share/rmail_hook.lua's
-- C; its transport is used and it is polled), or transport (any; nothing
-- is polled then), pack (the folder this player's own shares come from),
-- loader (assets/loader.lua's L, for this game), poll_every (seconds).
function lobby.new(opts)
    assert(type(opts.data) == "string", "lobby: needs the player data folder")
    local C = opts.connection
    local self = setmetatable({
        data = opts.data,
        connection = C,
        loader = opts.loader,
        poll_every = opts.poll_every or lobby.POLL_EVERY,
        clock = 0,
        next_poll = 0,
        applied = {},       -- { P, q, keep = pack name or nil }, in the order applied
        notices = {},       -- { id, title, lines }
        seen_ready = {},    -- question id -> true once its ready dialog was answered
        count = 0,
    }, Lb)
    self.settled = lobby.settle(opts.data)
    for _, s in ipairs(self.settled) do
        if s.kept then self:notice("Kept from the last game", { "Kept as the asset pack " .. s.kept:match("([^/]+)$") .. "." }) end
    end
    local transport = opts.transport or (C and C:transport())
    assert(transport, "lobby: needs a connection or a transport")
    self.exchange = exchange.new({
        data = opts.data,
        me = opts.me or (C and C.cfg and C.cfg.name) or "me",
        transport = transport,
        pack = opts.pack,
        store = opts.store,
        on_ready = function(P, q) self:ready(P, q) end,
        on_problem = function(id, what) self:notice("A shared list was refused", { what }) end,
    })
    if C then
        local hooked, missing = C:hooked()
        if not hooked then
            local lines = { "rmail isn't set up for shared lists yet (no " .. table.concat(missing, " or ") .. " hook).",
                            "Add these lines to rmail's config, then restart rmail:" }
            for line in C:install():gmatch("[^\n]+") do lines[#lines + 1] = "  " .. line end
            self:notice("Shared lists need rmail", lines)
        end
    end
    return self
end
-- }}}

-- {{{ Lb:update / Lb:notice / Lb:ready
-- From the game's tick: polls rmail every poll_every seconds (the first
-- at once). Gives the poll's events when it polled.
function Lb:update(dt)
    self.clock = self.clock + (dt or 0)
    if not self.connection or self.clock < self.next_poll then return nil end
    self.next_poll = self.clock + self.poll_every
    local ok, events = pcall(self.connection.poll, self.connection, self.exchange)
    if not ok then
        self:notice("rmail couldn't be read", { tostring(events) })
        return nil
    end
    return events
end

function Lb:notice(title, lines)
    self.count = self.count + 1
    self.notices[#self.notices + 1] = { id = "notice-" .. self.count, title = title, lines = lines }
end

-- The exchange's on_ready: the list is on the loader for this game.
function Lb:ready(P, q)
    if self.loader then
        local ok, err = pcall(P.attach, P, self.loader)
        if not ok then self:notice("A shared list couldn't be used", { tostring(err) }) end
    end
    self.applied[#self.applied + 1] = { P = P, q = q }
end
-- }}}

-- {{{ Lb:dialog
-- The one dialog to show now, or nil: questions first (oldest first),
-- then lists applied and not yet seen, then notices.
function Lb:dialog()
    local q = self.exchange:pending()[1]
    if q then
        local words = exchange.prompt(q)
        local lines = { words[2], words[3] }
        local shown = math.min(#words - 3, lobby.MAX_LINES)
        for i = 4, 3 + shown do lines[#lines + 1] = words[i] end
        if #words - 3 > shown then lines[#lines + 1] = string.format("  and %d more", #words - 3 - shown) end
        return { kind = "question", id = q.id, question = q, title = words[1], lines = lines, buttons = {
            { id = "yes", label = "Yes" },
            { id = "no", label = "No" },
            { id = "always_player", label = "Always from " .. q.sender },
            { id = "always_map", label = "Always for this map" },
        } }
    end
    for _, a in ipairs(self.applied) do
        if not self.seen_ready[a.q.id] then
            local lines = { string.format("Map: %s", a.q.map.name or "unnamed"),
                            "They're used for this game only, unless you keep them." }
            if a.q.trusted then table.insert(lines, 1, "Applied without asking, as you chose.") end
            return { kind = "ready", id = a.q.id, title = a.q.sender .. "'s models are in use", lines = lines, buttons = {
                { id = "keep", label = "Keep them after the game" },
                { id = "ok", label = "OK" },
            } }
        end
    end
    local n = self.notices[1]
    if n then
        return { kind = "notice", id = n.id, title = n.title, lines = n.lines, buttons = { { id = "ok", label = "OK" } } }
    end
    return nil
end
-- }}}

-- {{{ Lb:press
-- The player pressed BUTTON (an id) on dialog D. Gives what came of it.
function Lb:press(d, button)
    if d.kind == "question" then
        local q = d.question
        if button == "always_player" then
            self.exchange.trust:always_from(q.sender, true)
        elseif button == "always_map" then
            self.exchange.trust:always_for_map(q.map.hash, true)
        elseif button ~= "yes" and button ~= "no" then
            return nil, "no such button: " .. tostring(button)
        end
        local ok, result, err = pcall(self.exchange.answer, self.exchange, q.id, button == "no" and "no" or "yes")
        if not ok then
            self:notice("The answer couldn't be sent", { tostring(result) })
            return nil, tostring(result)
        end
        return result, err
    elseif d.kind == "ready" then
        self.seen_ready[d.id] = true
        if button == "keep" then return self:keep(d.id) end
        return "ok"
    elseif d.kind == "notice" then
        for i, n in ipairs(self.notices) do
            if n.id == d.id then table.remove(self.notices, i) break end
        end
        return "ok"
    end
    return nil, "not a dialog"
end
-- }}}

-- {{{ Lb:keep / Lb:end_game
-- Keep the list applied for question ID as an asset pack after the game.
-- Written down at once (a .keep file beside the profile), so a game that
-- ends without saying so still keeps it. Gives the pack's name.
function Lb:keep(id, name)
    for _, a in ipairs(self.applied) do
        if a.q.id == id then
            a.keep = pack_name(name or (a.q.sender .. "'s models for " .. (a.q.map.name or "a map")))
            local f = assert(io.open(keep_file(self.data, a.P.name), "wb"))
            f:write(a.keep)
            f:close()
            return "kept", a.keep
        end
    end
    return nil, "no list applied for " .. tostring(id)
end

-- After the game: every list applied is taken off the loader; those the
-- player kept become asset packs. Gives { {id, kept = pack folder or nil} }.
function Lb:end_game()
    local out = {}
    for _, a in ipairs(self.applied) do
        local kept
        if a.keep then
            local ok, pack = pcall(a.P.keep, a.P, lobby.free_pack_name(self.data, a.keep), self.loader)
            if ok then kept = pack else a.P:revert(self.loader) end
        else
            a.P:revert(self.loader)
        end
        os.remove(keep_file(self.data, a.P.name))
        out[#out + 1] = { id = a.q.id, kept = kept }
    end
    self.applied = {}
    return out
end
-- }}}

lobby.pack_name = pack_name

return lobby
