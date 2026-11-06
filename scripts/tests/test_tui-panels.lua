#!/usr/bin/env luajit
-- test_tui-panels.lua
-- Checks the panel layer in libs/tui.lua (issue 048, from delta-version
-- issue 070): a panel is a rectangle of the screen with its own row 1,
-- column 1, and nothing written through it lands outside it.
--
-- No terminal is needed.  tui.init_buffers sets up a small screen in memory,
-- tui.get_cell reads cells back, and tui.set_output catches what present()
-- would send, so a check can count exactly which cells a redraw sends.
--
-- Run: `luajit test_tui-panels.lua [SCRIPTS_DIR]`. Exits 1 on any failure.

-- {{{ DIR + library
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
package.path = DIR .. "/libs/?.lua;" .. package.path
local tui = require("tui")
-- }}}

local failures = 0

-- {{{ local function check
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print("FAIL " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(want))
    else
        print("ok   " .. label)
    end
end
-- }}}

-- {{{ local function screen_row
-- The characters of one back-buffer row, joined.
local function screen_row(y)
    local out = {}
    for x = 1, tui.cols() do
        out[#out + 1] = tui.get_cell(y, x).char
    end
    return table.concat(out)
end
-- }}}

-- {{{ local function present
-- Runs present() and returns what it sent: the characters drawn (escape
-- codes taken out) and the list of cursor moves as "row;col".
local function present()
    local sent = {}
    tui.set_output(function(s) sent[#sent + 1] = s end)
    tui.present()
    tui.set_output(nil)
    local text = table.concat(sent)
    local moves = {}
    for m in text:gmatch("\027%[(%d+;%d+)H") do moves[#moves + 1] = m end
    local drawn = text:gsub("\027%[[%d;]*[A-Za-z]", "")
    -- Where each character landed: present() sends single dirty cells in no
    -- set order, each after its own cursor move, so the order of `drawn`
    -- means nothing for them but the positions do.
    local at, y, x = {}, 0, 0
    local i = 1
    while i <= #text do
        local move_y, move_x, stop = text:match("^\027%[(%d+);(%d+)H()", i)
        local other = text:match("^\027%[[%d;]*[A-Za-z]()", i)
        if move_y then
            y, x, i = tonumber(move_y), tonumber(move_x), stop
        elseif other then
            i = other
        else
            local c = text:match("^[%z\1-\127\194-\244][\128-\191]*", i)
            at[y .. ";" .. x] = c
            x, i = x + 1, i + #c
        end
    end
    return drawn, moves, at
end
-- }}}

-- {{{ local function fresh
-- A blank 6x20 screen with nothing waiting to be sent.
local function fresh()
    tui.init_buffers(6, 20)
    tui.reset_style()
    present()
end
-- }}}

-- bad sizes are refused when the panel is made, not later
do
    check("width 0 refused", (pcall(tui.create_panel, 1, 1, 0, 3)), false)
    check("height -1 refused", (pcall(tui.create_panel, 1, 1, 3, -1)), false)
    check("fractional row refused", (pcall(tui.create_panel, 1.5, 1, 3, 3)), false)
    check("string width refused", (pcall(tui.create_panel, 1, 1, "3", 3)), false)
    local ok, err = pcall(tui.create_panel, 1, 1, 0, 3)
    check("error names the field", tostring(err):find("width must be a whole number", 1, true) ~= nil, true)
    check("off-screen corner allowed", (pcall(tui.create_panel, -2, 30, 3, 3)), true)
end

-- fields and coordinate conversion
do
    local p = tui.create_panel(4, 5, 10, 2)
    check("fields", p.row .. "," .. p.col .. "," .. p.width .. "," .. p.height, "4,5,10,2")
    local r, c = p:to_screen(1, 1)
    check("to_screen corner", r .. "," .. c, "4,5")
    r, c = p:to_screen(2, 10)
    check("to_screen far corner", r .. "," .. c, "5,14")
    local pr, pc, inside = p:from_screen(5, 14)
    check("from_screen far corner", pr .. "," .. pc .. "," .. tostring(inside), "2,10,true")
    pr, pc, inside = p:from_screen(6, 5)
    check("from_screen below", pr .. "," .. pc .. "," .. tostring(inside), "3,1,false")
    pr, pc, inside = p:from_screen(4, 4)
    check("from_screen left of it", tostring(inside), "false")
end

-- writes use panel coordinates and stop at the panel's edges
do
    fresh()
    local p = tui.create_panel(2, 4, 5, 2)
    local after = p:write_str(1, 1, "hello world")
    check("write_str stops at the right edge", screen_row(2), "   hello            ")
    check("write_str returns the column after", after, 6)
    p:write_str(2, 3, "ab")
    check("second panel row is screen row 3", screen_row(3), "     ab             ")
    p:write_str(3, 1, "zzz")
    p:write_str(0, 1, "zzz")
    check("row below the panel ignored", screen_row(4), string.rep(" ", 20))
    check("row above the panel ignored", screen_row(1), string.rep(" ", 20))
    p:set_cell(1, 0, "L")
    p:set_cell(1, 6, "R")
    check("columns either side ignored", screen_row(2), "   hello            ")
    p:write_str(1, 4, "\226\148\128\226\148\128\226\148\128")
    check("a three-byte character is one cell", screen_row(2), "   hel\226\148\128\226\148\128            ")
end

-- a panel hanging off the screen draws only what fits
do
    fresh()
    local p = tui.create_panel(5, 17, 8, 4)  -- rows 5-8, cols 17-24 on 6x20
    p:write_str(1, 1, "abcdefgh")
    p:write_str(2, 1, "ijkl")
    p:write_str(3, 1, "mnop")
    check("cut at the screen's right edge", screen_row(5), string.rep(" ", 16) .. "abcd")
    check("last screen row", screen_row(6), string.rep(" ", 16) .. "ijkl")
    present()
    p:invalidate()
    local drawn = present()
    check("off-screen panel redraws only visible cells", #drawn, 8)
    local gone = tui.create_panel(10, 1, 5, 2)
    gone:invalidate()
    gone:invalidate_row(1)
    gone:clear()
    drawn = present()
    check("a panel wholly off the screen sends nothing", drawn, "")
end

-- clearing blanks the panel and nothing else, and keeps the style
do
    fresh()
    for y = 1, 6 do tui.write_str(y, 1, string.rep("#", 20)) end
    local p = tui.create_panel(2, 3, 4, 3)
    tui.set_fg(tui.FG_RED)
    p:clear()
    check("clear blanks the panel", screen_row(3), "##    ##############")
    check("clear leaves the row above", screen_row(1), string.rep("#", 20))
    check("clear leaves the row below", screen_row(5), string.rep("#", 20))
    check("cleared cells are plain", tui.get_cell(2, 3).fg, tui.FG_DEFAULT)
    p:write_str(1, 1, "x")
    check("clear keeps the drawing style", tui.get_cell(2, 3).fg, tui.FG_RED)
    tui.reset_style()
    for y = 1, 6 do tui.write_str(y, 1, string.rep("#", 20)) end
    p:clear_row(2)
    check("clear_row blanks one panel row", screen_row(3), "##    ##############")
    check("clear_row leaves the panel's other rows", screen_row(2), string.rep("#", 20))
    p:clear_row(4)
    check("clear_row past the panel does nothing", screen_row(5), string.rep("#", 20))
end

-- invalidation marks the panel's own cells, through the dirty tracking
do
    fresh()
    local narrow = tui.create_panel(3, 6, 4, 2)
    narrow:invalidate()
    local drawn, moves = present()
    check("narrow panel sends its own cells", #drawn, 8)
    check("narrow panel starts at its corner", moves[1], "3;6")
    narrow:invalidate_row(2)
    drawn, moves = present()
    check("narrow panel row sends one row of it", #drawn, 4)
    check("panel row 2 is screen row 4", moves[1], "4;6")
    narrow:invalidate_row(3)
    drawn = present()
    check("row past the panel sends nothing", drawn, "")

    local full = tui.create_panel(1, 1, 20, 2)
    full:invalidate_row(2)
    drawn, moves = present()
    check("full-width panel sends the whole row", #drawn, 20)
    check("full-width row starts at column 1", moves[1], "2;1")

    narrow:write_str(1, 1, "ok")
    local at
    drawn, moves, at = present()
    check("panel writes are sent by present", #drawn, 2)
    check("first character lands at the panel corner", at["3;6"], "o")
    check("second character lands beside it", at["3;7"], "k")

    narrow:invalidate()
    tui.invalidate()
    drawn = present()
    check("full-screen invalidate still sends everything", #drawn, 120)
end

-- style is global: a panel's style call is tui's
do
    fresh()
    local p = tui.create_panel(1, 1, 5, 1)
    p:set_fg(tui.FG_GREEN)
    p:set_bg(tui.BG_BLUE)
    p:set_attrs(tui.ATTR_BOLD)
    tui.write_str(2, 1, "x")
    local cell = tui.get_cell(2, 1)
    check("panel style reaches tui writes", cell.fg .. "," .. cell.bg .. "," .. cell.attrs,
        tui.FG_GREEN .. "," .. tui.BG_BLUE .. "," .. tui.ATTR_BOLD)
    p:reset_style()
    p:write_str(1, 1, "y")
    cell = tui.get_cell(1, 1)
    check("panel reset_style resets", cell.fg .. "," .. cell.bg .. "," .. cell.attrs, "0,0,0")
end

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
