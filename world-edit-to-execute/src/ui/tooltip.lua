--[[
tooltip.lua - a button's tooltip: its text, colours, costs and a place on screen (issue 506f)

In plain terms: once the mouse has rested on a button for a moment, its
tooltip shows: the title with the hotkey, the text from object data
(`tip`, `ubertip`) with the map's TRIGSTR_ references looked up in its
string file (war3map.wts, parsers/wts.lua) and WC3's colour codes
(|cAARRGGBB ... |r, |n) drawn as colours, then what it costs and its
cooldown. The box sits above the button, right-aligned with it, and is
moved, then cut, so it never leaves the screen. Colour codes are read by
ui/wc3/script_ui.lua's, which the map's messages already use.

    local tooltip = require("ui.tooltip")
    local timer = tooltip.timer()                    -- the delay
    if timer:update(hovered_button, dt) then
        local t = tooltip.build(ui, hovered_button, button_rect, sw, sh, { resolve = resolve })
        tooltip.draw(ui, t)
    end

A button: `label` or `title` (the title), `ubertip` or `tip` (the text),
`hotkey`, and optionally `cost = { gold, lumber, food, mana }` and
`cooldown_seconds`. `resolve(token)` turns "TRIGSTR_012" into the
string (a StringTable's `resolve` works: `function(k) return
strings:resolve(k) end`).
]]

local script_ui = require("ui.wc3.script_ui")

local tooltip = {}

tooltip.DELAY = 0.25           -- seconds of rest before it shows
tooltip.MARGIN = 4             -- pixels kept clear of the screen's edges
tooltip.GAP = 6                -- between the button and the box
tooltip.PAD = 10
tooltip.COLOURS = { back = { 18, 20, 28 }, trim = { 140, 120, 70 }, title = { 250, 206, 70 },
                    text = { 236, 232, 220 }, cost = { 250, 206, 70 } }

-- {{{ tooltip.resolve
-- Text with its TRIGSTR_ references looked up; one not found stays as it is.
function tooltip.resolve(text, resolve)
    if type(text) ~= "string" then return text end
    if not resolve or not text:find("TRIGSTR_", 1, true) then return text end
    return (text:gsub("TRIGSTR_%-?%d+", function(k)
        local v = resolve(k)
        return type(v) == "string" and v or k
    end))
end
-- }}}

-- {{{ tooltip.content
local function key_name(k)
    if k == "ESCAPE" then return "Esc" end
    return k
end

-- What the tooltip says: { title, body, costs (a line or nil) }.
function tooltip.content(b, options)
    local resolve = options and options.resolve
    local title = tooltip.resolve(b.title or b.label or "", resolve)
    -- the hotkey after the title, unless the title already marks it in colour, as WC3's do
    if b.hotkey and not title:find("|[cC]%x%x%x%x%x%x%x%x") then
        title = title .. " (|cffffcc00" .. key_name(b.hotkey) .. "|r)"
    end
    local body = tooltip.resolve(b.ubertip or b.tip, resolve)
    local parts = {}
    local c = b.cost or {}
    for _, k in ipairs({ { "gold", "Gold" }, { "lumber", "Lumber" }, { "food", "Food" }, { "mana", "Mana" } }) do
        local v = c[k[1]]
        if v and v ~= 0 then parts[#parts + 1] = "|cffffcc00" .. k[2] .. "|r " .. v end
    end
    if b.cooldown_seconds and b.cooldown_seconds > 0 then
        parts[#parts + 1] = "|cffffcc00Cooldown|r " .. string.format("%g", b.cooldown_seconds) .. " s"
    end
    return { title = title, body = body, costs = #parts > 0 and table.concat(parts, "  ") or nil }
end
-- }}}

-- {{{ tooltip.place
-- Where a box of w x h goes for a button at `near` ({x, y, w, h}) on a
-- screen of sw x sh: above it, right edges together; below it when there
-- is no room above; then pushed back inside the screen.
function tooltip.place(w, h, near, sw, sh)
    local m, g = tooltip.MARGIN, tooltip.GAP
    local x = near.x + near.w - w
    local y = near.y - g - h
    if y < m then y = near.y + near.h + g end
    if x + w > sw - m then x = sw - m - w end
    if x < m then x = m end
    if y + h > sh - m then y = sh - m - h end
    if y < m then y = m end
    return x, y
end
-- }}}

-- {{{ tooltip.build
-- The laid-out tooltip: { x, y, w, h, title, lines, costs, size, line_h,
-- cut }. options: resolve, width (default 380, never wider than the
-- screen), size (text, default 15), title_size (18).
function tooltip.build(ui, b, near, sw, sh, options)
    options = options or {}
    local c = tooltip.content(b, options)
    local m, pad = tooltip.MARGIN, tooltip.PAD
    local w = math.min(options.width or 380, sw - 2 * m)
    local size, tsize = options.size or 15, options.title_size or 18
    local line_h, title_h = math.floor(size * 1.2 + 0.5), math.floor(tsize * 1.3 + 0.5)
    local inner = w - 2 * pad
    local title_lines = script_ui.lines(ui, c.title, tsize, inner)
    local lines = c.body and c.body ~= "" and script_ui.lines(ui, c.body, size, inner) or {}
    local cost_lines = c.costs and script_ui.lines(ui, c.costs, size, inner) or {}
    -- what fits on the screen: the text is cut, with a last line saying so
    local fixed = 2 * pad + #title_lines * title_h + #cost_lines * line_h + (#cost_lines > 0 and 4 or 0)
    local room = math.floor((sh - 2 * m - fixed) / line_h)
    local cut = false
    if #lines > room then
        cut = true
        local keep = {}
        for i = 1, math.max(0, room - 1) do keep[i] = lines[i] end
        if room >= 1 then keep[#keep + 1] = "..." end
        lines = keep
    end
    local h = fixed + #lines * line_h
    local x, y = tooltip.place(w, h, near, sw, sh)
    return { x = x, y = y, w = w, h = h, title = title_lines, lines = lines, costs = cost_lines,
             size = size, title_size = tsize, line_h = line_h, title_h = title_h, cut = cut }
end
-- }}}

-- {{{ tooltip.draw
function tooltip.draw(ui, t)
    local C, pad = tooltip.COLOURS, tooltip.PAD
    ui.ui_rect(t.x, t.y, t.w, t.h, C.back[1], C.back[2], C.back[3], 235)
    ui.ui_frame(t.x, t.y, t.w, t.h, 2, C.trim[1], C.trim[2], C.trim[3], 255)
    local y = t.y + pad
    for _, l in ipairs(t.title) do
        script_ui.text(ui, l, t.x + pad, y, t.title_size, C.title)
        y = y + t.title_h
    end
    for _, l in ipairs(t.lines) do
        script_ui.text(ui, l, t.x + pad, y, t.size, C.text)
        y = y + t.line_h
    end
    if #t.costs > 0 then y = y + 4 end
    for _, l in ipairs(t.costs) do
        script_ui.text(ui, l, t.x + pad, y, t.size, C.text)
        y = y + t.line_h
    end
end
-- }}}

-- {{{ tooltip.timer
-- The delay: `:update(button, dt)` is true once the same button has been
-- under the mouse for `delay` seconds (tooltip.DELAY); another button, or
-- none, starts it again.
function tooltip.timer(delay)
    local t = { delay = delay or tooltip.DELAY, on = nil, rest = 0 }
    function t:update(b, dt)
        if b ~= self.on then self.on, self.rest = b, 0 return false end
        if not b then return false end
        self.rest = self.rest + (dt or 0)
        return self.rest >= self.delay
    end
    return t
end
-- }}}

return tooltip
