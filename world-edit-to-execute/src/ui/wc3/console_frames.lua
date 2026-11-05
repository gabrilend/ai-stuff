--[[
console_frames.lua - WC3's console as anchored frames: its 4:3 layout as data (issue 506b)

In plain terms: the same parts as layout.lua (518b) places by pixels, given
instead as frames for ui/anchor.lua, in the 4:3 area's units (960 x 720).
The top bar and the console's bar stretch across the whole window; every
part on them (menu buttons, clock, resources, minimap and its buttons,
portrait, information, inventory, command card, hero buttons) keeps its
place in the 4:3 area, as WC3 keeps them on a wide screen. At 4:3 the
whole layout scales with the window.

The sizes are layout.lua's, fitted into 960 across (layout.lua's are for
1280): the menu buttons are 96 wide, the resources 410, the information
236. They are this project's, not measured from the game: the game's own
FDF files (on the owner's install) would give the real ones, in
`anchor.WC3` units.

    local console = require("ui.wc3.console_frames")
    local r = console.compute(1920, 1080)   -- layout.compute's shape
    r.card[1]                               -- { x, y, w, h }
    local c = console.cache()               -- worked out on resize only
    local r2 = c:get(w, h)

`console.FRAMES` is the data; `console.compute(w, h)` returns the table
layout.compute(w, h) returns (top, menu, clock, resources, console,
minimap_buttons, minimap, portrait, vitals, info, inventory, card,
card_area, tooltip, heroes, idle, messages, panel), with `scale` and the
two roots (`screen`, `ui`) added, so the hud can take either.
]]

local anchor = require("ui.anchor")

local console = {}

-- {{{ the frames
local F = {}
local function add(f) F[#F + 1] = f return f end
local function stretch(id, edge, h)            -- across the whole window, along one edge
    local l, r = edge .. "LEFT", edge .. "RIGHT"
    return add({ id = id, to = "screen", h = h, points = { { l, l }, { r, r } } })
end
local function at(id, point, rel, x, y, w, h, extra)
    local f = { id = id, w = w, h = h, points = { { point, rel, x, y } } }
    for k, v in pairs(extra or {}) do f[k] = v end
    return add(f)
end

stretch("top", "TOP", 30)
stretch("console", "BOTTOM", 192)

local MENU = { { "Quests", "F9", "quests" }, { "Menu", "F10", "menu" },
               { "Allies", "F11", "allies" }, { "Log", "F12", "log" } }
for i, m in ipairs(MENU) do
    at("menu" .. i, "TOPLEFT", "TOPLEFT", 6 + (i - 1) * 100, 3, 96, 24, { label = m[1], key = m[2], panel = m[3] })
end
at("clock", "TOP", "TOP", 0, 0, 120, 40)
at("resources", "TOPRIGHT", "TOPRIGHT", 0, 0, 410, 30)

-- the console's parts: from the 4:3 area's bottom; its top is 192 up, they start 8 below that
local MB = { { "signal", "G", "Signal" }, { "terrain", "T", "Terrain" },
             { "ally_colors", "A", "Ally Colours" }, { "creeps", "R", "Creeps" },
             { "formation", "F", "Formation Movement" } }
for i, b in ipairs(MB) do
    at("minimap_button" .. i, "TOPLEFT", "BOTTOMLEFT", 6, -184 + (i - 1) * 35, 26, 31, { mid = b[1], alt = b[2], label = b[3] })
end
at("minimap", "TOPLEFT", "BOTTOMLEFT", 38, -184, 176, 176)
at("portrait", "TOPLEFT", "BOTTOMLEFT", 222, -184, 124, 124)
at("vitals", "TOPLEFT", "BOTTOMLEFT", 222, -56, 124, 44)
at("info", "TOPLEFT", "BOTTOMLEFT", 354, -184, 236, 176)
local KP = { "KP_7", "KP_8", "KP_4", "KP_5", "KP_1", "KP_2" }
for i = 0, 5 do
    at("inventory" .. (i + 1), "TOPLEFT", "BOTTOMLEFT", 598 + (i % 2) * 52, -174 + math.floor(i / 2) * 54, 48, 48,
       { key = KP[i + 1] })
end
for row = 0, 2 do
    for col = 0, 3 do
        at("card" .. (row * 4 + col + 1), "TOPLEFT", "BOTTOMRIGHT", -252 + col * 62, -184 + row * 62, 58, 58)
    end
end
at("card_area", "TOPLEFT", "BOTTOMRIGHT", -252, -184, 244, 182)
at("tooltip", "BOTTOMRIGHT", "BOTTOMRIGHT", -8, -198, 380, 0)

-- above the console
for i = 1, 3 do
    at("hero" .. i, "TOPLEFT", "TOPLEFT", 8, 40 + (i - 1) * 86, 64, 64, { key = "F" .. i })
end
at("idle", "TOPLEFT", "BOTTOMLEFT", 8, -254, 52, 52, { key = "F8" })
at("messages", "TOPLEFT", "BOTTOMLEFT", 232, -322, 720, 0)
at("panel", "TOP", "TOP", 0, 70, 480, 420)

console.FRAMES = F
-- }}}

-- {{{ console.compute
local KEEP = { "label", "key", "panel", "alt" }

local function shape(rects, s, roots, w, h)
    local function r(id, f)
        local x = rects[id]
        local out = { x = x.x, y = x.y, w = x.w, h = x.h }
        for _, k in ipairs(KEEP) do if f and f[k] ~= nil then out[k] = f[k] end end
        if f and f.mid then out.id = f.mid end
        return out
    end
    local by = {}
    for _, f in ipairs(F) do by[f.id] = f end
    local o = { w = w, h = h, scale = s, screen = roots.screen, ui = roots.ui }
    for _, k in ipairs({ "top", "clock", "resources", "console", "minimap", "portrait", "vitals", "info",
                         "card_area", "idle", "panel" }) do
        o[k] = r(k, by[k])
    end
    local function list(prefix, n)
        local l = {}
        for i = 1, n do l[i] = r(prefix .. i, by[prefix .. i]) end
        return l
    end
    o.menu, o.minimap_buttons, o.inventory = list("menu", 4), list("minimap_button", 5), list("inventory", 6)
    o.card, o.heroes = list("card", 12), list("hero", 3)
    local t = rects.tooltip
    o.tooltip = { x = t.x, bottom = t.y + t.h, w = t.w }
    local m = rects.messages
    o.messages = { x = m.x, y = m.y, w = m.w, line = math.floor(20 * s + 0.5) }
    return o
end

-- The console for a window of w x h, in layout.compute's shape.
function console.compute(w, h)
    local rects, s, roots = anchor.resolve(F, w, h)
    if not rects then error("console_frames: " .. tostring(s), 0) end
    return shape(rects, s, roots, w, h)
end

-- The same, worked out only when the size changes: `:get(w, h)`; `.computed`.
function console.cache()
    local c = anchor.cache(F)
    local wrap = { inner = c }
    function wrap:get(w, h)
        local before = c.computed
        local rects, s, roots = c:get(w, h)
        if c.computed ~= before or not self.shaped then self.shaped = shape(rects, s, roots, w, h) end
        self.computed = c.computed
        return self.shaped
    end
    wrap.computed = 0
    return wrap
end
-- }}}

return console
