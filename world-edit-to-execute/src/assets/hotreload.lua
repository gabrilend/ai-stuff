--[[
Hot-Reload: Change a Pack's File, See It Without a Restart (Issue 606)

A development tool: while an artist edits a texture or model in one of the
player's asset packs, the game reads the new file the moment it is saved
and hands it to whoever draws it. Nothing watches anything unless a tool
makes a hot-reloader; the game itself never does.

    local hotreload = require("assets.hotreload")
    local H = hotreload.new(L, {          -- L: an assets.loader
        poll_interval = 0.5,              -- seconds between looks (the "poll" watcher)
        quiet = 0.1,                      -- seconds a file must stay unchanged before it is read
        backend = "inotify",              -- or "poll"; default inotify where Linux allows it
        on_reload = function(path, value, source) ... end,  -- swap it in (GPU, sound, UI)
        on_error = function(path, err, kept_old) ... end,
    })
    -- once a frame, from the game loop:
    H:poll()
    H:pause()  H:resume()                 -- around a batch of saves: read once, after
    H:reload("Textures\\Footman.blp")     -- now, whether it changed or not
    H:reload_all("textures")              -- "textures", "models", "sounds", or all
    H:status()  -- { enabled, paused, backend, watching, reloads, errors, changes, pending }
    H:close()

What it watches: the loader's asset packs (the player's own folders, the
only sources an artist edits; the map is one archive and the install is
stock). A change to a file the loader has loaded, or looked for and not
found, is read again; a change to anything else only updates the pack's
file list, so the next get() finds it. A pack lower in the order than one
that has the same file changes nothing on screen, and is not read.

A broken file (a save half-written, a format the reader refuses) keeps
the old value: on_error is called with kept_old true, and the next save is
tried again. A file removed from a pack falls back to the next source
(another pack, the map, the install); with none left, the old value stays.

Swapping the new value into the GPU, a playing sound or the UI is the
caller's part (on_reload): the loader hands out values, and only the
renderer knows which of its textures came from which path.
]]


local hotreload = {}

hotreload.DEFAULT_INTERVAL = 0.5
hotreload.DEFAULT_QUIET = 0.1

hotreload.KINDS = {
    textures = { blp = true, tga = true, png = true },
    models = { mdx = true },
    sounds = { wav = true, mp3 = true, ogg = true, flac = true },
}

-- {{{ function hotreload.now
-- Seconds on the monotonic clock (never jumps when the wall clock is set).
function hotreload.now()
    return require("net.clock").now_ms() / 1000
end
-- }}}

-- {{{ local helpers
local function watcher(kind, dirs)
    if kind == "poll" then
        return require("assets.watch.poll").new(dirs)
    elseif kind == "inotify" then
        return require("assets.watch.inotify").new(dirs)
    end
    error("hotreload: no watcher named " .. tostring(kind) .. " (inotify or poll)", 3)
end

local function ext_of(key)
    return key:match("%.([%w]+)$")
end
-- }}}

local H = {}
H.__index = H

-- {{{ function hotreload.new
function hotreload.new(L, opts)
    if type(L) ~= "table" or type(L.reload) ~= "function" then
        error("hotreload: wants an assets.loader", 2)
    end
    opts = opts or {}
    local self = setmetatable({
        loader = L,
        interval = opts.poll_interval or hotreload.DEFAULT_INTERVAL,
        quiet = opts.quiet or hotreload.DEFAULT_QUIET,
        on_reload = opts.on_reload,
        on_error = opts.on_error,
        clock = opts.clock or hotreload.now,
        dirs = {},
        pending = {},
        paused = false,
        closed = false,
        reloads = 0, errors = 0, changes = 0,
    }, H)
    for _, pack in ipairs(L.packs) do self.dirs[#self.dirs + 1] = pack.dir end

    local kind = opts.backend
    if not kind then
        kind = require("assets.watch.inotify").available() and "inotify" or "poll"
    end
    self.backend = kind
    self.watch = watcher(kind, self.dirs)
    self.last_look = self.clock()
    return self
end
-- }}}

-- {{{ function H:tell / H:fail
-- The caller's code runs under pcall: a mistake in it is reported, not
-- carried into the game loop.
function H:fail(path, err, kept)
    self.errors = self.errors + 1
    if self.on_error then
        local ok, e = pcall(self.on_error, path, err, kept)
        if not ok then io.stderr:write("hotreload: on_error failed: " .. tostring(e) .. "\n") end
    end
end

function H:tell(path, value, source)
    self.reloads = self.reloads + 1
    if self.on_reload then
        local ok, e = pcall(self.on_reload, path, value, source)
        if not ok then self:fail(path, "on_reload failed: " .. tostring(e), true) end
    end
end
-- }}}

-- {{{ function H:reload
-- Reads PATH again now, whether or not it changed. Returns the new value
-- and its source; or nil and the message (on_error is called).
function H:reload(path)
    local value, source, kept = self.loader:reload(path)
    if value ~= nil then
        self:tell(path, value, source)
        return value, source
    end
    self:fail(path, source, kept or false)
    return nil, source
end
-- }}}

-- {{{ function H:reload_all
-- Reads again every asset of a kind ("textures", "models", "sounds"; a
-- table of extensions; nil or "all" for everything) the loader has loaded,
-- and every one it looked for and didn't find that a source now has.
-- Returns how many were read and how many failed.
function H:reload_all(kind)
    local exts
    if kind ~= nil and kind ~= "all" then
        exts = type(kind) == "table" and kind or hotreload.KINDS[kind]
        if not exts then error("hotreload: no kind named " .. tostring(kind), 2) end
    end
    local L = self.loader
    L:reindex()
    local keys = L.cache:keys()
    local missing = {}
    for key in pairs(L.missing) do missing[#missing + 1] = key end
    table.sort(missing)
    for _, key in ipairs(missing) do
        if not L.cache:has(key) and L:exists(key) then keys[#keys + 1] = key end
    end
    local ok, bad = 0, 0
    for _, key in ipairs(keys) do
        if not exts or exts[ext_of(key) or ""] then
            if self:reload(key) ~= nil then ok = ok + 1 else bad = bad + 1 end
        end
    end
    return ok, bad
end
-- }}}

-- {{{ function H:poll
-- Call once a frame. Takes what the watcher saw (the poll watcher looks
-- only once per poll_interval), and reads again each wanted file that has
-- stayed unchanged for `quiet` seconds. Returns how many were read.
function H:poll()
    if self.closed then return 0 end
    local now = self.clock()
    local seen
    if self.backend == "poll" then
        if now - self.last_look >= self.interval then
            seen = self.watch:changes()
            self.last_look = now
        end
    else
        seen = self.watch:changes()
    end
    local L = self.loader
    for _, c in ipairs(seen or {}) do
        self.changes = self.changes + 1
        local key, matters = L:file_changed(c.dir, c.rel)
        if matters then
            self.pending[key] = { path = c.rel, at = now }
        elseif self.pending[key] then
            self.pending[key].at = now
        end
    end
    if self.paused then return 0 end

    local due = {}
    for key, p in pairs(self.pending) do
        if now - p.at >= self.quiet then due[#due + 1] = key end
    end
    table.sort(due)
    local n = 0
    for _, key in ipairs(due) do
        local p = self.pending[key]
        self.pending[key] = nil
        if self:reload(p.path) ~= nil then n = n + 1 end
    end
    return n
end
-- }}}

-- {{{ function H:pause / H:resume
-- While paused, changes are noted but nothing is read; resume() lets the
-- next poll() read each changed file once.
function H:pause() self.paused = true end
function H:resume() self.paused = false end
-- }}}

-- {{{ function H:status
function H:status()
    local pending = 0
    for _ in pairs(self.pending) do pending = pending + 1 end
    return {
        enabled = not self.closed,
        paused = self.paused,
        backend = self.backend,
        watching = #self.dirs,
        reloads = self.reloads,
        errors = self.errors,
        changes = self.changes,
        pending = pending,
    }
end
-- }}}

-- {{{ function H:close
function H:close()
    if self.closed then return end
    self.watch:close()
    self.closed = true
    self.pending = {}
end
-- }}}

return hotreload
