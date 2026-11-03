--[[
The Shared-List Prompt (Issue 609c)

Draws share/lobby.lua's dialogs over the game, the way the map's own
dialogs are drawn (ui/wc3/script_ui.lua): one at a time in the middle of
the screen, holding the mouse until a button is pressed. It comes before
the map's dialogs, because a list should be answered before the game
leans on its models.

    hud.share = Lb                         -- share/lobby.lua
    share_prompt.update(hud, input)        -- before the map's dialogs take the input
    share_prompt.draw(hud, ui)             -- after the hud has drawn

Keys: Enter presses the first button of a notice or a "ready" dialog
(OK, or Keep), Esc presses OK. A question needs the mouse: no key answers
it, so a stray key never says yes or no.
]]

local layout = require("ui.wc3.layout")
local script_ui = require("ui.wc3.script_ui")

local share_prompt = {}

share_prompt.WIDTH = 560

local C = {
    frame = { 22, 24, 32 }, panel = { 40, 44, 56 }, trim = { 176, 140, 64 },
    text = { 236, 232, 220 }, gold = { 250, 206, 70 }, hover = { 90, 96, 120 },
}

-- {{{ share_prompt.layout
-- Where dialog D goes on a SW x SH screen: { x, y, w, h, title = {lines},
-- lines = {lines}, buttons = { {x, y, w, h, id, label} } }. UI gives the
-- text measure (ui_text_width). Lines that don't fit the screen are cut,
-- and the last line says how many.
function share_prompt.layout(ui, d, sw, sh)
    local w = math.min(share_prompt.WIDTH, sw - 40)
    local title = script_ui.lines(ui, d.title, 22, w - 40)
    local lines = {}
    for _, l in ipairs(d.lines or {}) do
        for _, piece in ipairs(script_ui.lines(ui, l, 16, w - 40)) do lines[#lines + 1] = piece end
    end
    local fixed = 24 + #title * 28 + 12 + #d.buttons * 44 + 16
    local room = math.max(1, math.floor((sh - 40 - fixed) / 20))
    if #lines > room then
        local cut = #lines - room + 1
        for _ = 1, cut do table.remove(lines) end
        lines[#lines + 1] = string.format("  (%d more lines)", cut)
    end
    local h = fixed + #lines * 20
    local box = { x = math.floor(sw / 2 - w / 2), y = math.max(20, math.floor(sh / 2 - h / 2 - 40)), w = w, h = h,
                  title = title, lines = lines, buttons = {} }
    local by = box.y + 24 + #title * 28 + 12 + #lines * 20
    for i, b in ipairs(d.buttons) do
        box.buttons[i] = { x = box.x + 30, y = by + (i - 1) * 44, w = w - 60, h = 36, id = b.id, label = b.label }
    end
    return box
end
-- }}}

-- {{{ share_prompt.update
-- Takes the mouse (and Enter and Esc) while a dialog shows; a click on a
-- button presses it. Gives what the lobby said, when a button was pressed.
function share_prompt.update(hud, input)
    local Lb = hud.share
    if not Lb then return nil end
    local d = Lb:dialog()
    hud.share_hover = nil
    if not d then return nil end
    local pressed
    if hud.ui then
        local box = share_prompt.layout(hud.ui, d, hud.r.w, hud.r.h)
        for _, b in ipairs(box.buttons) do
            if layout.inside(b, input.mx or 0, input.my or 0) then hud.share_hover = b.id end
        end
        if input.lp and hud.share_hover then pressed = hud.share_hover end
    end
    local rest = {}
    for _, k in ipairs(input.keys or {}) do
        if d.kind ~= "question" and k == "ENTER" then pressed = pressed or d.buttons[1].id
        elseif d.kind ~= "question" and k == "ESCAPE" then pressed = pressed or "ok"
        elseif k ~= "ENTER" and k ~= "ESCAPE" then rest[#rest + 1] = k end
    end
    input.keys = rest
    input.lp, input.rp, input.ld, input.lr = nil, nil, nil, nil
    if pressed then
        hud.share_hover = nil
        return Lb:press(d, pressed)
    end
    return nil
end
-- }}}

-- {{{ share_prompt.draw
function share_prompt.draw(hud, ui)
    hud.ui = ui
    local Lb = hud.share
    local d = Lb and Lb:dialog()
    if not d then return end
    local r = hud.r
    local box = share_prompt.layout(ui, d, r.w, r.h)
    ui.ui_rect(0, 0, r.w, r.h, 0, 0, 0, 110)
    ui.ui_rect(box.x, box.y, box.w, box.h, C.frame[1], C.frame[2], C.frame[3], 245)
    ui.ui_frame(box.x, box.y, box.w, box.h, 3, C.trim[1], C.trim[2], C.trim[3], 255)
    for i, line in ipairs(box.title) do
        local wpx = ui.ui_text_width(script_ui.plain(line), 22)
        script_ui.text(ui, line, box.x + box.w / 2 - wpx / 2, box.y + 18 + (i - 1) * 28, 22, C.gold)
    end
    local ty = box.y + 24 + #box.title * 28 + 8
    for i, line in ipairs(box.lines) do
        script_ui.text(ui, line, box.x + 20, ty + (i - 1) * 20, 16, C.text)
    end
    for _, b in ipairs(box.buttons) do
        local fill = hud.share_hover == b.id and C.hover or C.panel
        ui.ui_rect(b.x, b.y, b.w, b.h, fill[1], fill[2], fill[3], 255)
        ui.ui_frame(b.x, b.y, b.w, b.h, 2, C.trim[1], C.trim[2], C.trim[3], 255)
        local wpx = ui.ui_text_width(script_ui.plain(b.label), 18)
        script_ui.text(ui, b.label, b.x + b.w / 2 - wpx / 2, b.y + 9, 18, C.text)
    end
end
-- }}}

return share_prompt
