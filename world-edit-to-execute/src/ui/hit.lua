--[[
hit.lua - which interface element the mouse is on, before the world gets it (issue 506c)

In plain terms: the interface is a list of elements, each a flat record
with a rectangle and a draw order (as 506a has them). A point is tested
against them from the top of the draw order down; only a miss belongs to
the world. A tracker, fed the input once a frame, keeps hover and pressed
states on the elements, tells when a button is clicked (pressed and let
go on the same element), sends hotkeys to the elements that have them,
and gives keyboard focus to a text entry (chat), during which keys are
typing, not hotkeys. Nothing here draws or knows the game.

    local hit = require("ui.hit")
    local e = hit.test(elements, mx, my)       -- the top element there, or nil
    local t = hit.tracker()
    local events = t:update(elements, input)   -- { {"click", e}, {"hotkey", e}, ... }
    if not t.ui_owns_mouse then ... world picking ... end

An element: `id`, `x`, `y`, `w`, `h` (pixels), `order` (higher is drawn
later, so on top; default 0), `visible` (default true), `disabled`,
`passthrough` (drawn but never hit, like a message line), `kind`
("panel", "button", "text_entry", ...) and `hotkey` ("A", "ESCAPE",
"F9", ...). The tracker sets `state` on each: "normal", "hovered",
"pressed" or "disabled". Panels block the world but give no clicks.

The input is the hud's (518b): mx, my, lp (left pressed this frame), ld
(held), lr (released), rp, keys (names, "ENTER", "ESCAPE", "A"...),
chars (typed text), ctrl, shift, alt.

Events: enter, leave, press, release, click, hotkey (each `{ name,
element }`), focus and blur (a text entry), and `text` (a typed piece,
for the focused entry) as `{ "text", element, chars }`.
]]

local hit = {}

-- {{{ hit.inside
function hit.inside(e, x, y)
    return x >= e.x and y >= e.y and x < e.x + e.w and y < e.y + e.h
end
-- }}}

-- {{{ hit.test
-- The element on top at (x, y), or nil (the world's). Of two at the same
-- order, the later in the list is on top, as it is drawn later.
function hit.test(elements, x, y)
    local best, best_order
    for _, e in ipairs(elements) do
        if e.visible ~= false and not e.passthrough and hit.inside(e, x, y) then
            local o = e.order or 0
            if not best or o >= best_order then best, best_order = e, o end
        end
    end
    return best
end
-- }}}

-- {{{ hit.hotkey
-- The visible, enabled element with this hotkey ("a" and "A" alike), the
-- top one if several have it; nil when none.
function hit.hotkey(elements, key)
    local want = tostring(key):upper()
    local best, best_order
    for _, e in ipairs(elements) do
        if e.hotkey and e.hotkey:upper() == want and e.visible ~= false and not e.disabled then
            local o = e.order or 0
            if not best or o >= best_order then best, best_order = e, o end
        end
    end
    return best
end
-- }}}

-- {{{ hit.tracker
local Tracker = {}
Tracker.__index = Tracker

function hit.tracker()
    return setmetatable({ hover = nil, pressed = nil, focus = nil, ui_owns_mouse = false }, Tracker)
end

function Tracker:update(elements, input)
    local ev = {}
    local function emit(name, e, extra) ev[#ev + 1] = { name, e, extra } end
    local mx, my = input.mx or 0, input.my or 0
    local over = hit.test(elements, mx, my)

    -- an element gone from the list (or hidden) lets go of what it held
    local present = {}
    for _, e in ipairs(elements) do if e.visible ~= false then present[e] = true end end
    if self.pressed and not present[self.pressed] then self.pressed = nil end
    if self.focus and not present[self.focus] then emit("blur", self.focus) self.focus = nil end

    if over ~= self.hover then
        if self.hover then emit("leave", self.hover) end
        if over then emit("enter", over) end
        self.hover = over
    end

    if input.lp then
        if over and not over.disabled then
            self.pressed = over
            emit("press", over)
        end
        -- focus: a text entry takes it; a click anywhere else drops it
        local takes = over and over.kind == "text_entry" and not over.disabled and over or nil
        if self.focus and self.focus ~= takes then emit("blur", self.focus) self.focus = nil end
        if takes and self.focus ~= takes then self.focus = takes emit("focus", takes) end
        self.press_on_ui = over ~= nil
    elseif not input.ld and not input.lr then
        self.press_on_ui = false
    end
    if input.lr then
        local was = self.pressed
        self.pressed = nil
        if was then
            emit("release", was)
            if was == over then emit("click", was) end
        end
    end
    -- the mouse is the interface's while over it; during a press, it is
    -- whoever's the press began on, wherever it is let go (a box drawn
    -- on the world stays the world's over the console)
    if input.lp or input.ld or input.lr then
        self.ui_owns_mouse = self.press_on_ui and true or false
    else
        self.ui_owns_mouse = over ~= nil
    end
    if input.lr then self.press_on_ui = false end

    -- keys: typing while a text entry has focus, else hotkeys
    if self.focus then
        if input.chars and input.chars ~= "" then emit("text", self.focus, input.chars) end
        for _, k in ipairs(input.keys or {}) do
            if k == "ESCAPE" or k == "ENTER" then
                emit(k == "ENTER" and "submit" or "blur", self.focus)
                self.focus = nil
                break
            end
        end
    else
        for _, k in ipairs(input.keys or {}) do
            local e = hit.hotkey(elements, k)
            if e then emit("hotkey", e) end
        end
    end

    -- states
    for _, e in ipairs(elements) do
        if e.disabled then e.state = "disabled"
        elseif e == self.pressed and e == over then e.state = "pressed"
        elseif e == over or e == self.focus then e.state = "hovered"
        else e.state = "normal" end
    end
    return ev
end
-- }}}

-- {{{ hit.from_layout
-- The console's parts as elements, from layout.compute's (or
-- console_frames.compute's) table `r`: the bars and panels block the
-- world; buttons (menu, minimap's, heroes, idle, inventory) can be clicked.
-- `extra` elements (the command card's, a dialog's) are added after.
-- `open_panel` true adds the Quests/Menu/Allies/Log panel on top.
function hit.from_layout(r, extra, open_panel)
    local out = {}
    local function add(id, rect, order, fields)
        local e = { id = id, x = rect.x, y = rect.y, w = rect.w, h = rect.h, order = order, kind = "panel" }
        for k, v in pairs(fields or {}) do e[k] = v end
        out[#out + 1] = e
        return e
    end
    add("top", r.top, 1)
    add("console", r.console, 1)
    for i, m in ipairs(r.menu) do add("menu" .. i, m, 2, { kind = "button", hotkey = m.key, panel = m.panel }) end
    add("minimap", r.minimap, 2, { kind = "minimap" })
    for i, b in ipairs(r.minimap_buttons) do add("minimap_button" .. i, b, 2, { kind = "button", toggle = b.id }) end
    add("portrait", r.portrait, 2)
    add("info", r.info, 2)
    for i, s in ipairs(r.inventory) do add("inventory" .. i, s, 2, { kind = "button", slot = i, hotkey = s.key }) end
    for i, h in ipairs(r.heroes) do add("hero" .. i, h, 2, { kind = "button", hotkey = h.key }) end
    add("idle", r.idle, 2, { kind = "button", hotkey = r.idle.key })
    for _, e in ipairs(extra or {}) do out[#out + 1] = e end
    if open_panel then add("panel", r.panel, 10) end
    return out
end
-- }}}

return hit
