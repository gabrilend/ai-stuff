--[[
The Sound Editor's Panel (Issue 907)

Opened from the toolbar ("Sounds"), over the whole view:

  Sounds   left: the script's sounds and the editor's own (+ Sound),
           paged; right: the chosen one's file (typed), where the file
           is (the map, the install, or missing), looping, 3D, stop when
           out of range, fades, EAX, label, duration, channel, volume,
           pitch, how often the script plays it; Play and Stop (the
           window's audio, when it has any); Delete for the editor's own
  Music    each music call of the script with its file (typed)

    local sui = require("editor.sounds_ui").new(E, w, h, { play = fn(bytes, ext), stop = fn() })
    sui:update(input); sui:draw(render)
]]

local sounds = require("editor.sounds")

local sounds_ui = {}
sounds_ui.LEFT = 360

local SUI = {}
SUI.__index = SUI

local C = {
    panel = { 22, 24, 30 }, edge = { 70, 74, 86 }, button = { 44, 48, 58 }, active = { 90, 120, 60 },
    text = { 225, 225, 215 }, dim = { 140, 140, 130 }, gold = { 240, 200, 90 }, head = { 130, 170, 230 },
    warn = { 240, 120, 90 }, ok = { 140, 210, 120 }, new = { 150, 200, 255 },
}

function sounds_ui.new(E, w, h, opts)
    local self = setmetatable({ E = E, w = w, h = h, opts = opts or {}, tab = "Sounds", page = 0 }, SUI)
    self:layout()
    return self
end

local function short(s, n)
    s = tostring(s)
    return #s > n and (".." .. s:sub(-(n - 2))) or s
end

-- {{{ layout
function SUI:layout()
    local E = self.E
    local b = {}
    self.buttons, self.labels = b, {}
    local function add(x, y, w, label, action, arg, active, colour)
        b[#b + 1] = { x = x, y = y, w = w, h = 22, label = label, action = action, arg = arg, active = active, colour = colour }
    end
    local function label(x, y, s, c) self.labels[#self.labels + 1] = { x = x, y = y, s = s, c = c or C.text } end
    self.add, self.label = add, label
    add(8, 46, 110, "Sounds", "tab", "Sounds", self.tab == "Sounds")
    add(124, 46, 110, "Music", "tab", "Music", self.tab == "Music")
    if self.tab == "Music" then self:layout_music() return b end
    add(240, 46, 110, "+ Sound", "new_sound")
    local list = E:sounds()
    self.rows = math.max(4, math.floor((self.h - 28 - 104 - 8) / 24))
    local pages = math.max(1, math.ceil(#list / self.rows))
    self.page = math.max(0, math.min(self.page, pages - 1))
    label(8, 80, string.format("%d sounds  page %d/%d", #list, self.page + 1, pages), C.head)
    add(sounds_ui.LEFT - 84, 76, 36, "<", "page", -1)
    add(sounds_ui.LEFT - 44, 76, 36, ">", "page", 1)
    local y = 104
    for k = 1, self.rows do
        local s = list[self.page * self.rows + k]
        if not s then break end
        local file = type(s.file) == "string" and (s.file:match("([^\\/]+)$") or s.file) or "?"
        add(8, y, sounds_ui.LEFT - 16, short(s.name .. "  " .. file, 40), "pick", s, s == self.sel,
            s.kind == "editor" and C.new or nil)
        y = y + 24
    end
    if self.sel then self:layout_sound(self.sel) end
    return b
end

function SUI:field(x, y, w, key, text)
    local f = self.field_now
    local editing = f and f.key == key
    self.add(x, y, w, editing and (short(f.buf, math.floor(w / 8) - 1) .. "_") or short(text, math.floor(w / 8)),
        "field", { key = key, text = text }, editing)
end

function SUI:layout_sound(s)
    local X = sounds_ui.LEFT + 8
    local y = 46
    self.label(X, y + 4, s.name .. (s.kind == "editor" and "  (made in the editor)" or ("  (" .. s.var .. ")")), C.gold)
    y = y + 28
    self.label(X, y + 4, "File", C.dim)
    self:field(X + 120, y, self.w - X - 128, "file", tostring(s.file or ""))
    y = y + 26
    local where = self.where
    self.label(X + 120, y + 2, where and ("found in the " .. where) or "not found (the install has the game's own)",
        where and C.ok or C.warn)
    y = y + 26
    self.add(X, y, 150, "Looping", "toggle", "looping", s.looping == true)
    self.add(X + 156, y, 150, "3D", "toggle", "is3d", s.is3d == true)
    self.add(X + 312, y, 220, "Stop when out of range", "toggle", "stop_out", s.stop_out == true)
    y = y + 32
    local function number(key, text, step, lo, hi)
        self.label(X, y + 4, text, C.dim)
        local v = s[key]
        self.add(X + 160, y, 100, v == nil and "(not set)" or (type(v) == "number" and (v == math.floor(v)
            and tostring(v) or string.format("%.2f", v)) or tostring(v)), "none")
        self.add(X + 264, y, 28, "-", "step", { key, -step, lo, hi })
        self.add(X + 296, y, 28, "+", "step", { key, step, lo, hi })
        y = y + 26
    end
    number("fade_in", "Fade in rate", 1, 0, 127)
    number("fade_out", "Fade out rate", 1, 0, 127)
    number("volume", "Volume (0-127)", 8, 0, 127)
    number("pitch", "Pitch", 0.1, 0.1, 4)
    number("channel", "Channel", 1, 0, 11)
    number("duration", "Duration (ms)", 100, 0, 3600000)
    self.label(X, y + 4, "EAX", C.dim)
    self.add(X + 160, y, 200, tostring(s.eax), "cycle_eax")
    y = y + 26
    self.label(X, y + 4, "Label", C.dim)
    self:field(X + 160, y, 300, "label", tostring(s.label or ""))
    y = y + 32
    if s.kind == "script" then self.label(X, y, string.format("the script plays it %d times", s.plays or 0), C.text) end
    y = y + 26
    self.add(X, y, 100, "Play", "play")
    self.add(X + 106, y, 100, "Stop", "stop")
    if s.kind == "editor" then self.add(X + 212, y, 100, "Delete", "delete") end
    if self.said then self.label(X + 330, y + 4, self.said, C.dim) end
end

function SUI:layout_music()
    local X = 8
    local y = 80
    for i, m in ipairs(self.E:music()) do
        if y > self.h - 60 then break end
        self.label(X, y + 4, m.call, C.dim)
        self:field(X + 180, y, self.w - X - 188, "music" .. i, m.file)
        y = y + 26
    end
end
-- }}}

-- {{{ actions
function SUI:choose(s)
    self.sel, self.said = s, nil
    self.where = nil
    if s then
        local ok, d, where = pcall(self.E.sound_file, self.E, s.file)
        if ok and d then self.where = where end
    end
end

function SUI:commit()
    local f = self.field_now
    self.field_now = nil
    if not f then return end
    local E, s = self.E, self.sel
    if f.key == "file" and s then E:set_sound(s, "file", f.buf); self:choose(s)
    elseif f.key == "label" and s then E:set_sound(s, "label", f.buf ~= "" and f.buf or nil)
    else
        local i = tonumber(f.key:match("^music(%d+)$"))
        local m = i and E:music()[i]
        if m and f.buf ~= "" then E:set_music(m, f.buf) end
    end
end

function SUI:press(b)
    local E, s = self.E, self.sel
    local a, arg = b.action, b.arg
    if self.field_now and a ~= "field" then self:commit() end
    if a == "tab" then self.tab = arg
    elseif a == "page" then self.page = self.page + arg
    elseif a == "pick" then self:choose(arg)
    elseif a == "new_sound" then self:choose(E:new_sound("Sound", ""))
    elseif a == "field" then
        if self.field_now then self:commit() end
        self.field_now = { key = arg.key, buf = arg.text, fresh = true }
    elseif a == "toggle" and s then E:set_sound(s, arg, not s[arg])
    elseif a == "step" and s then
        local key, step, lo, hi = arg[1], arg[2], arg[3], arg[4]
        local v = math.max(lo, math.min(hi, (tonumber(s[key]) or (key == "pitch" and 1 or 0)) + step))
        E:set_sound(s, key, math.floor(v * 100 + 0.5) / 100)
    elseif a == "cycle_eax" and s then
        local at = 0
        for i, e in ipairs(sounds.EAX) do if e == s.eax then at = i end end
        E:set_sound(s, "eax", sounds.EAX[at % #sounds.EAX + 1])
    elseif a == "play" and s then
        local d = E:sound_file(s.file)
        if not d then self.said = "no file to play"
        elseif not self.opts.play then self.said = "no audio here"
        else
            local ok, why = self.opts.play(d, "." .. ((s.file:match("%.(%w+)$") or "wav"):lower()))
            self.said = ok and "playing" or tostring(why)
        end
    elseif a == "stop" then
        if self.opts.stop then self.opts.stop() end
        self.said = nil
    elseif a == "delete" and s then
        E:delete_sound(s)
        self:choose(nil)
    end
    self:layout()
end

local function inside(b, x, y) return x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h end

function SUI:update(input)
    local used = false
    if self.field_now then
        used = true
        local f = self.field_now
        if (input.chars or "") ~= "" then f.buf = (f.fresh and "" or f.buf) .. input.chars; f.fresh = false end
        for _, k in ipairs(input.keys or {}) do
            if k == "BACKSPACE" then f.buf = f.fresh and "" or f.buf:sub(1, -2); f.fresh = false
            elseif k == "ENTER" then self:commit()
            elseif k == "ESCAPE" then self.field_now = nil end
        end
        self:layout()
    elseif input.wheel and input.wheel ~= 0 then
        self.page = self.page - (input.wheel > 0 and 1 or -1)
        self:layout()
    end
    if input.lp then
        for _, b in ipairs(self.buttons) do
            if inside(b, input.mx or 0, input.my or 0) and b.action ~= "none" then self:press(b); return true end
        end
    end
    return used
end

function SUI:button(label)
    for _, b in ipairs(self.buttons) do if b.label == label then return b end end
end
-- }}}

function SUI:draw(render)
    local function rect(x, y, w, h, c, a) render.ui_rect(x, y, w, h, c[1], c[2], c[3], a or 255) end
    rect(0, 38, self.w, self.h - 66, C.panel, 250)
    if self.tab == "Sounds" then rect(sounds_ui.LEFT, 38, 1, self.h - 66, C.edge) end
    for _, l in ipairs(self.labels) do render.ui_text(l.s, l.x, l.y, 14, l.c[1], l.c[2], l.c[3], 255) end
    for _, b in ipairs(self.buttons) do
        rect(b.x, b.y, b.w, b.h, b.active and C.active or C.button)
        render.ui_frame(b.x, b.y, b.w, b.h, 1, C.edge[1], C.edge[2], C.edge[3], 255)
        local c = b.colour or C.text
        render.ui_text(b.label, b.x + 6, b.y + 5, 13, c[1], c[2], c[3], 255)
    end
end

return sounds_ui
