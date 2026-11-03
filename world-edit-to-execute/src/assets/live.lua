--[[
Hot-Reload in the Map Viewer and the Editor (Issue 606a, step 8)

Turns hot-reload on for a running viewer: a hot-reloader over its loader,
polled once a frame, handing each saved texture to the model cache and the
ground, and keeping a few short lines for the corner of the screen (step
6) saying what was reloaded and what failed.

It is off unless asked for. The scene viewer takes one argument (the
map), so, like its other switches (WC3_MODELS, WC3_TILES ...), it is
asked for in the environment: WC3_HOT_RELOAD=1 (or "inotify" / "poll" to
pick the watcher).

    local live = require("assets.live")
    local R = live.from_env(L, { models = cache, ground = { render, ids, terrain, report } })
    -- R is nil when WC3_HOT_RELOAD isn't set
    R:tick()                     -- once a frame
    for _, line in ipairs(R:lines()) do ... end   -- the corner's lines, newest last
    live.draw(R, render)         -- from scene_ui: those lines, bottom left
    R:close()

A texture is swapped only once render.tex_update exists (render/models.c
doesn't have it yet); until then each reload says it was read but not
shown, so the corner says why nothing changed.
]]

local hotreload = require("assets.hotreload")
local gpu = require("assets.gpu")
local ground = require("assets.ground")

local live = {}

live.SHOW_FOR = 6        -- seconds a corner line stays
live.MAX_LINES = 5

local R = {}
R.__index = R

-- {{{ function live.new
-- L: the loader. opts: models (a gpu cache), ground ({render, ids,
-- terrain, report}, as ground.textures took and gave), backend, clock,
-- poll_interval, quiet, print (where each line also goes; default print).
function live.new(L, opts)
    opts = opts or {}
    local self = setmetatable({ lines_ = {}, swapped = 0, unshown = 0,
                                clock = opts.clock or hotreload.now,
                                print = opts.print or print }, R)
    local handlers = {}
    if opts.models then handlers[#handlers + 1] = gpu.on_reload(opts.models) end
    if opts.ground then
        local g = opts.ground
        handlers[#handlers + 1] = ground.on_reload(g[1], g[2], g[3], g[4])
    end
    self.H = hotreload.new(L, {
        backend = opts.backend, clock = self.clock,
        poll_interval = opts.poll_interval, quiet = opts.quiet,
        on_reload = function(path, value, source)
            local shown = false
            for _, h in ipairs(handlers) do
                if h(path, value, source) then shown = true end
            end
            if shown then
                self.swapped = self.swapped + 1
                self:say("reloaded " .. path)
            elseif type(value) == "table" and value.rgba then
                self.unshown = self.unshown + 1
                self:say("read " .. path .. ", not shown: the renderer can't replace a texture yet")
            else
                self.unshown = self.unshown + 1
                self:say("read " .. path .. ", not shown: only textures are swapped so far")
            end
        end,
        on_error = function(path, err, kept)
            self:say("can't reload " .. path .. (kept and " (the old one stays)" or "") .. ": " .. tostring(err))
        end,
    })
    return self
end

-- The same, when WC3_HOT_RELOAD (or ENV.WC3_HOT_RELOAD) asks for it: "1"
-- or "on" for the default watcher, "inotify" or "poll" for that one. Nil
-- otherwise.
function live.from_env(L, opts, env)
    local v = env and env.WC3_HOT_RELOAD or os.getenv("WC3_HOT_RELOAD")
    if not v or v == "" or v == "0" or v == "off" then return nil end
    opts = opts or {}
    if v == "inotify" or v == "poll" then opts.backend = v end
    return live.new(L, opts)
end
-- }}}

-- {{{ R:say / R:lines / R:tick / R:status / R:close
function R:say(line)
    self.lines_[#self.lines_ + 1] = { text = "[hot-reload] " .. line, at = self.clock() }
    while #self.lines_ > live.MAX_LINES do table.remove(self.lines_, 1) end
    pcall(self.print, self.lines_[#self.lines_].text)
end

-- The corner's lines: those said in the last SHOW_FOR seconds, newest last.
function R:lines()
    local now, out = self.clock(), {}
    for _, l in ipairs(self.lines_) do
        if now - l.at <= live.SHOW_FOR then out[#out + 1] = l.text end
    end
    return out
end

-- Once a frame. Gives how many files were read.
function R:tick()
    return self.H:poll()
end

function R:status()
    local s = self.H:status()
    s.swapped, s.unshown = self.swapped, self.unshown
    return s
end

function R:close()
    self.H:close()
end
-- }}}

-- {{{ function live.draw
-- The corner's lines, bottom left, newest lowest (render.ui_text). Gives
-- how many were drawn; none when the renderer has no text.
function live.draw(self, render, height)
    if type(render.ui_text) ~= "function" then return 0 end
    local lines = self:lines()
    local h = height or (render.ui_screen and select(2, render.ui_screen())) or 720
    for i, line in ipairs(lines) do
        local y = h - 24 - (#lines - i) * 20
        local red = line:find("can't reload", 1, true) ~= nil
        render.ui_text(line, 12, y, 16, 255, red and 120 or 230, red and 110 or 140, 230)
    end
    return #lines
end
-- }}}

return live
