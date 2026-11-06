--[[
Chooser: Which Model to Draw for a Model Path (Issue 516's stand-in, reading 504's overrides)

Issue 516 decides the order, for every model a map asks for:

  1. the player's own override for that path (assets/overrides.lua), its
     file read from the player's store (assets/dedup.lua);
  2. the model the map requests: imported into the map, or a stock model
     from the player's own install (the caller's `requested` function, such
     as assets.open's A:model);
  3. a placeholder shape, when neither can be found or read.

Every choice is counted by where it came from, and every path that ended
on a placeholder is kept with the reason, so it can be reported. Each path
is chosen once and remembered until clear(). This is the small stand-in 516
asks for until W03's resolver exists; it is kept behind choose() so that
resolver can replace it without the renderer noticing.

    local chooser = require("assets.chooser")
    local c = chooser.new({
        overrides = overrides.load(overrides.file_for(ROOT)),
        store = dedup.open(player_data.blobs(ROOT)),   -- anything with path(hash)
        map = map_hash,                                -- nil: only overrides for every map apply
        requested = function(path) return A:model(path) end,
        read = function(bytes, path) return mdx.parse(bytes) end,   -- the default
    })
    local model, source, look = c:choose("Units\\Human\\Footman\\Footman")
    -- source: "override", "requested" or "placeholder"; look: { scale, tint, team_colour, file } for an override
    c:counts()        -- { override = n, requested = n, placeholder = n, override_failed = n } (uses, not paths)
    c:placeholders()  -- { { path, reason }, ... } one per path, in the order first met
]]

local chooser = {}

local Chooser = {}
Chooser.__index = Chooser

-- {{{ local function default_read
local function default_read(bytes)
    return require("parsers.mdx").parse(bytes)
end
-- }}}

-- {{{ function chooser.new
function chooser.new(opts)
    opts = opts or {}
    if type(opts.requested) ~= "function" then
        error("chooser.new needs requested, a function from a model path to a model or nil", 2)
    end
    if opts.overrides and opts.overrides:count() > 0 and not opts.store then
        error("chooser.new: overrides name files by hash, so a store is needed to read them", 2)
    end
    return setmetatable({
        overrides = opts.overrides,
        store = opts.store,
        map = opts.map,
        requested = opts.requested,
        read = opts.read or default_read,
        chosen = {},
        uses = { override = 0, requested = 0, placeholder = 0, override_failed = 0 },
        missing = {},
        failed = {},
    }, Chooser)
end
-- }}}

-- {{{ local function read_override
-- The override's model, or nil and why it couldn't be had.
local function read_override(self, entry)
    local ok_path, path = pcall(self.store.path, self.store, entry.file)
    if not ok_path or not path then
        return nil, "the store can't name " .. entry.file
    end
    local f = io.open(path, "rb")
    if not f then
        return nil, "the store has no " .. entry.file
    end
    local bytes = f:read("*a")
    f:close()
    local ok, model = pcall(self.read, bytes, entry.path)
    if not ok or not model then
        return nil, entry.file .. " doesn't read as a model: " .. tostring(model)
    end
    return model
end
-- }}}

-- {{{ local function decide
-- The first choice for a path: { model, source, look, failed_override }.
local function decide(self, path)
    local entry = self.overrides and self.overrides:lookup(path, self.map)
    local failed_override
    if entry then
        local model, why = read_override(self, entry)
        if model then
            return { model = model, source = "override",
                look = { scale = entry.scale, tint = entry.tint, team_colour = entry.team_colour, file = entry.file } }
        end
        failed_override = why
    end
    local ok, model = pcall(self.requested, path)
    if ok and model then
        return { model = model, source = "requested", failed_override = failed_override }
    end
    local reason = ok and "neither the map nor the install has it" or ("it didn't read: " .. tostring(model))
    if failed_override then
        reason = "its override failed (" .. failed_override .. "), and " .. reason
    end
    return { source = "placeholder", reason = reason, failed_override = failed_override }
end
-- }}}

-- {{{ function Chooser:choose
-- The model to draw for a path, where it came from, and an override's look
-- (nil otherwise). A placeholder gives nil for the model.
function Chooser:choose(path)
    local key = require("assets.overrides").key(path)
    local c = self.chosen[key]
    if not c then
        c = decide(self, path)
        self.chosen[key] = c
        if c.source == "placeholder" then
            self.missing[#self.missing + 1] = { path = path, reason = c.reason }
        end
        if c.failed_override then
            self.failed[#self.failed + 1] = { path = path, reason = c.failed_override }
        end
    end
    self.uses[c.source] = self.uses[c.source] + 1
    if c.failed_override then
        self.uses.override_failed = self.uses.override_failed + 1
    end
    return c.model, c.source, c.look
end
-- }}}

-- {{{ function Chooser:counts
function Chooser:counts()
    local u = self.uses
    return { override = u.override, requested = u.requested, placeholder = u.placeholder,
        override_failed = u.override_failed }
end
-- }}}

-- {{{ function Chooser:placeholders
-- Every path that ended on a placeholder, once each, with the reason.
function Chooser:placeholders()
    local out = {}
    for i, m in ipairs(self.missing) do out[i] = { path = m.path, reason = m.reason } end
    return out
end
-- }}}

-- {{{ function Chooser:failed_overrides
-- Every path whose override couldn't be read, once each, with the reason.
function Chooser:failed_overrides()
    local out = {}
    for i, m in ipairs(self.failed) do out[i] = { path = m.path, reason = m.reason } end
    return out
end
-- }}}

-- {{{ function Chooser:report
-- The counts and the placeholders, as lines of text.
function Chooser:report()
    local u = self.uses
    local lines = { string.format("models: %d from overrides, %d as the map asks, %d placeholders",
        u.override, u.requested, u.placeholder) }
    for _, m in ipairs(self.failed) do
        lines[#lines + 1] = "  override failed: " .. m.path .. ": " .. m.reason
    end
    for _, m in ipairs(self.missing) do
        lines[#lines + 1] = "  placeholder: " .. m.path .. ": " .. m.reason
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ function Chooser:clear
-- Forgets every choice (the overrides or the store changed). Counts stay.
function Chooser:clear()
    self.chosen = {}
    self.missing = {}
    self.failed = {}
end
-- }}}

return chooser
