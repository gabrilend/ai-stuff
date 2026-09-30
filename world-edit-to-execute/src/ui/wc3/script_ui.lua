--[[
What a Map's Script Shows (Issue 520)

The parts of WC3's interface a running map script drives (jass/vm.lua,
reached as game.script), drawn over ui/wc3/hud.lua:

  messages       the script's text in the message area, with WC3's
                 |cAARRGGBB ... |r colours and line breaks, for as long as
                 the script asked; also kept in the Log (F12)
  chat           Enter opens a chat line, Enter again sends it to the
                 script (its chat triggers), Esc drops it
  dialogs        the script's dialogs, one at a time in the middle of the
                 screen; they hold the mouse until a button is pressed
  timer windows  countdowns the script shows, under the resources
  multiboards    its scoreboards, at the top right
  quests         the Quests panel (F9) lists the script's quests
  Esc            also tells the script the player skipped a cinematic

    local script_ui = require("ui.wc3.script_ui")
    script_ui.update(hud, input)    -- before the hud handles the input
    script_ui.draw(hud, ui)         -- after the hud has drawn
]]

local layout = require("ui.wc3.layout")

local script_ui = {}

local C = {
    frame = { 22, 24, 32 }, panel = { 40, 44, 56 }, trim = { 176, 140, 64 },
    text = { 236, 232, 220 }, gold = { 250, 206, 70 }, dim = { 150, 150, 160 },
    hover = { 90, 96, 120 },
}

-- {{{ Coloured text
-- Pieces of a WC3 string: { {text, colour}, ... } (|cAARRGGBB sets the
-- colour, |r resets it; |n is a line break, handled by lines())
function script_ui.pieces(s, default)
    local out, colour = {}, default
    local pos = 1
    while pos <= #s do
        local a, b, hex = s:find("|[cC](%x%x%x%x%x%x%x%x)", pos)
        local r0, r1 = s:find("|[rR]", pos)
        local nxt = math.min(a or math.huge, r0 or math.huge)
        if nxt == math.huge then
            out[#out + 1] = { s:sub(pos), colour }
            break
        end
        if nxt > pos then out[#out + 1] = { s:sub(pos, nxt - 1), colour } end
        if a and a == nxt then
            colour = { tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), tonumber(hex:sub(7, 8), 16) }
            pos = b + 1
        else
            colour = default
            pos = r1 + 1
        end
    end
    return out
end

-- The text with its colour codes taken out
function script_ui.plain(s)
    return (s:gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rR]", ""))
end

-- Screen lines of a message: its own breaks, then wrapped to `width`
-- pixels. Each line keeps its codes (a colour carried over a wrap is
-- re-opened on the next line).
function script_ui.lines(ui, s, size, width)
    s = s:gsub("|[nN]", "\n"):gsub("\r", "")
    local out = {}
    for line in (s .. "\n"):gmatch("([^\n]*)\n") do
        while ui.ui_text_width(script_ui.plain(line), size) > width do
            -- the longest head that fits, cut at a space
            local cut = #line
            while cut > 1 and ui.ui_text_width(script_ui.plain(line:sub(1, cut)), size) > width do
                local sp = line:sub(1, cut - 1):match(".*() ")
                cut = sp and sp > 1 and sp or cut - 1
            end
            local head = line:sub(1, cut)
            local open = head:match(".*(|[cC]%x%x%x%x%x%x%x%x)[^|]*$")
            out[#out + 1] = head
            line = (open or "") .. line:sub(cut + 1):gsub("^ ", "")
        end
        out[#out + 1] = line
    end
    return out
end

function script_ui.text(ui, s, x, y, size, default, alpha)
    for _, p in ipairs(script_ui.pieces(s, default)) do
        local c = p[2]
        ui.ui_text(p[1], x, y, size, c[1], c[2], c[3], alpha or 255)
        x = x + ui.ui_text_width(p[1], size)
    end
end
-- }}}

-- {{{ Boxes the mouse can hit
local function dialog_boxes(hud, ui, d, V)
    local sw, sh = hud.r.w, hud.r.h
    local w = 420
    local msg = script_ui.lines(ui, V:text(d.message), 20, w - 40)
    local h = 40 + #msg * 24 + #d.buttons * 44 + 10
    local box = { x = sw / 2 - w / 2, y = math.max(40, sh / 2 - h / 2 - 60), w = w, h = h, msg = msg }
    box.buttons = {}
    for i, b in ipairs(d.buttons) do
        box.buttons[i] = { x = box.x + 30, y = box.y + 30 + #msg * 24 + (i - 1) * 44, w = w - 60, h = 36, button = b }
    end
    return box
end
-- }}}

-- {{{ script_ui.update
-- Chat typing, dialog clicks, Esc; takes what it uses out of input
function script_ui.update(hud, input)
    local game = hud.game
    local V = game.script
    if not V then return end

    -- the script's messages join the log
    hud.log = hud.log or {}
    local seen = hud.script_logged or 0
    for i = seen + 1, #(V.log or {}) do
        local m = V.log[i]
        local line = script_ui.plain(m.text):gsub("|[nN]", " "):gsub("%s*\n%s*", " ")
        table.insert(hud.log, string.format("[%d:%02d] %s", math.floor(m.time / 60), math.floor(m.time % 60), line))
    end
    hud.script_logged = #(V.log or {})

    -- quests for the Quests panel
    local main, optional = {}, {}
    for _, q in ipairs(V.quests) do
        if not q.destroyed and q.enabled ~= false and q.discovered ~= false then
            local title = script_ui.plain(V:text(q.title))
            if q.completed then title = title .. " (Completed)" elseif q.failed then title = title .. " (Failed)" end
            table.insert(q.required and main or optional, title)
        end
    end
    game.quests = { main = main, optional = optional }

    local keys = input.keys or {}
    -- chat: Enter opens, Enter sends, Esc drops; typing takes the keys
    if hud.chat then
        hud.chat = hud.chat .. (input.chars or "")
        local rest = {}
        for _, k in ipairs(keys) do
            if k == "ENTER" then
                local said = hud.chat
                hud.chat = nil
                if said ~= "" then
                    local p = V:player(game.player)
                    hud:message(p.name .. ": " .. said)
                    V:chat(game.player, said)
                end
            elseif k == "BACKSPACE" then
                hud.chat = hud.chat:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
            elseif k == "ESCAPE" then
                hud.chat = nil
            end
        end
        input.keys = rest
        return
    end
    local rest = {}
    for _, k in ipairs(keys) do
        if k == "ENTER" then
            hud.chat = ""
        else
            if k == "ESCAPE" then V:player_event("EVENT_PLAYER_END_CINEMATIC", game.player) end
            rest[#rest + 1] = k
        end
    end
    input.keys = rest

    -- a dialog holds the mouse
    local d = V:shown_dialogs()[1]
    if d and hud.ui then
        local box = dialog_boxes(hud, hud.ui, d, V)
        hud.dialog_hover = nil
        for _, b in ipairs(box.buttons) do
            if layout.inside(b, input.mx or 0, input.my or 0) then hud.dialog_hover = b.button end
        end
        if input.lp and hud.dialog_hover then V:click(hud.dialog_hover, game.player) end
        input.lp, input.rp, input.ld, input.lr = nil, nil, nil, nil
    end
end
-- }}}

-- {{{ script_ui.messages
-- The script's messages on screen now, oldest first: { {text, at}, ... }
function script_ui.messages(hud)
    local V = hud.game.script
    local out = {}
    if V then
        for _, m in ipairs(V.messages) do out[#out + 1] = { text = m.text, at = m.at, script = true } end
    end
    return out
end
-- }}}

-- {{{ script_ui.draw
function script_ui.draw(hud, ui)
    hud.ui = ui
    local V = hud.game.script
    local r = hud.r

    -- the chat line
    if hud.chat then
        local y = r.console.y - 34
        ui.ui_rect(r.messages.x - 6, y - 4, r.messages.w, 28, 0, 0, 0, 170)
        local cursor = (math.floor(hud.time * 2) % 2 == 0) and "_" or ""
        ui.ui_text("Say: " .. hud.chat .. cursor, r.messages.x, y, 18, C.gold[1], C.gold[2], C.gold[3], 255)
    end
    if not V then return end

    -- timer windows, stacked under the resources
    local y = r.top.h + 8
    for _, td in ipairs(V.timer_dialogs) do
        if td.shown and not td.destroyed and td.timer then
            local left = math.max(0, math.ceil(td.timer.remaining or 0))
            local clock = left >= 3600 and string.format("%d:%02d:%02d", math.floor(left / 3600), math.floor(left / 60) % 60, left % 60)
                or string.format("%d:%02d", math.floor(left / 60), left % 60)
            local title = V:text(td.title)
            local w = 230
            local x = r.w - w - 10
            ui.ui_rect(x, y, w, 30, C.frame[1], C.frame[2], C.frame[3], 225)
            ui.ui_frame(x, y, w, 30, 2, C.trim[1], C.trim[2], C.trim[3], 255)
            script_ui.text(ui, title, x + 10, y + 7, 16, C.text)
            ui.ui_text(clock, x + w - 10 - ui.ui_text_width(clock, 18), y + 6, 18, C.gold[1], C.gold[2], C.gold[3], 255)
            y = y + 36
        end
    end

    -- multiboards (the first shown one), below the timer windows
    for _, mb in ipairs(V.multiboards) do
        if mb.shown and not mb.destroyed then
            local cols, rows = math.max(1, mb.cols or 1), math.min(mb.rows or 0, 16)
            -- each column as wide as its widest cell
            local widths, left = {}, {}
            local w = 20
            for col = 0, cols - 1 do
                local cw = 24
                for row = 0, rows - 1 do
                    local v = mb.cells[row * 64 + col]
                    if v then cw = math.max(cw, ui.ui_text_width(script_ui.plain(V:text(v)), 14) + 16) end
                end
                widths[col], left[col] = cw, w - 10
                w = w + cw
            end
            w = math.max(200, w, ui.ui_text_width(script_ui.plain(V:text(mb.title)), 16) + 24)
            local h = 34 + (mb.minimized and 0 or rows * 20)
            local x = r.w - w - 10
            ui.ui_rect(x, y, w, h, C.frame[1], C.frame[2], C.frame[3], 215)
            ui.ui_frame(x, y, w, h, 2, C.trim[1], C.trim[2], C.trim[3], 255)
            script_ui.text(ui, V:text(mb.title), x + 10, y + 8, 16, C.gold)
            if not mb.minimized then
                for row = 0, rows - 1 do
                    for col = 0, cols - 1 do
                        local v = mb.cells[row * 64 + col]
                        if v then script_ui.text(ui, V:text(v), x + 10 + left[col], y + 32 + row * 20, 14, C.text) end
                    end
                end
            end
            break
        end
    end

    -- the dialog in front
    local d = V:shown_dialogs()[1]
    if d then
        local box = dialog_boxes(hud, ui, d, V)
        ui.ui_rect(0, 0, r.w, r.h, 0, 0, 0, 90)
        ui.ui_rect(box.x, box.y, box.w, box.h, C.frame[1], C.frame[2], C.frame[3], 245)
        ui.ui_frame(box.x, box.y, box.w, box.h, 3, C.trim[1], C.trim[2], C.trim[3], 255)
        for i, line in ipairs(box.msg) do
            local wpx = ui.ui_text_width(script_ui.plain(line), 20)
            script_ui.text(ui, line, box.x + box.w / 2 - wpx / 2, box.y + 14 + (i - 1) * 24, 20, C.gold)
        end
        for _, b in ipairs(box.buttons) do
            local fill = hud.dialog_hover == b.button and C.hover or C.panel
            ui.ui_rect(b.x, b.y, b.w, b.h, fill[1], fill[2], fill[3], 255)
            ui.ui_frame(b.x, b.y, b.w, b.h, 2, C.trim[1], C.trim[2], C.trim[3], 255)
            local label = V:text(b.button.text)
            local wpx = ui.ui_text_width(script_ui.plain(label), 18)
            script_ui.text(ui, label, b.x + b.w / 2 - wpx / 2, b.y + 9, 18, C.text)
        end
    end
end
-- }}}

return script_ui
