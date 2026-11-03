#!/usr/bin/env luajit
-- test_menu-layout.lua
-- Checks menu.layout in libs/menu.lua (issue 045): the menu's screen is
-- split into a header panel, a body panel and a footer panel, and the body
-- runs from under the header right down to the top of the footer.
--
-- No terminal is needed: menu.layout is arithmetic over the screen size.
-- What the menu actually draws inside those panels is checked by
-- test-menu-layout.sh, which runs a real menu in a pretend terminal.
--
-- Run: `luajit test_menu-layout.lua [SCRIPTS_DIR]`. Exits 1 on any failure.

-- {{{ DIR + library
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
package.path = DIR .. "/libs/?.lua;" .. package.path
local menu = require("menu")
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

-- {{{ local function rect
-- "row,col WxH" for a panel, so one check covers all four numbers.
local function rect(p)
    return string.format("%d,%d %dx%d", p.row, p.col, p.width, p.height)
end
-- }}}

-- {{{ a 30x100 screen without a shortcuts line
local l = menu.layout(30, 100)
check("header: rows 1-4, full width", rect(l.header), "1,1 100x4")
check("footer: the last 2 rows", rect(l.footer), "29,1 100x2")
check("body: row 5 down to row 28", rect(l.body), "5,1 100x24")
check("body ends right above the footer",
    l.body.row + l.body.height, l.footer.row)
check("footer ends on the screen's last row",
    l.footer.row + l.footer.height - 1, 30)
-- }}}

-- {{{ the same screen with a shortcuts line
l = menu.layout(30, 100, { has_shortcuts = true })
check("footer with shortcuts: the last 3 rows", rect(l.footer), "28,1 100x3")
check("body gives up one row to it", rect(l.body), "5,1 100x23")
check("body still ends right above the footer",
    l.body.row + l.body.height, l.footer.row)
-- }}}

-- {{{ panels place and clip like any tui panel
l = menu.layout(24, 80)
local r, c = l.footer:to_screen(2, 1)
check("footer row 2 is screen row 24", r .. "," .. c, "24,1")
local _, _, inside = l.body:from_screen(23, 10)
check("screen row 23 is not in the body", inside, false)
_, _, inside = l.body:from_screen(22, 10)
check("screen row 22 is the body's last", inside, true)
-- }}}

-- {{{ a screen too short for all three
-- The body keeps one row; the panels overlap rather than fail, and the tui
-- drops whatever lands off the screen.
l = menu.layout(6, 40)
check("6 rows: footer on rows 5-6", rect(l.footer), "5,1 40x2")
check("6 rows: body keeps one row", rect(l.body), "5,1 40x1")
l = menu.layout(3, 40, { has_shortcuts = true })
check("3 rows: footer starts at row 1", rect(l.footer), "1,1 40x3")
check("3 rows: body still one row", l.body.height, 1)
l = menu.layout(10, 0)
check("0 columns: panels are at least one column wide", l.body.width, 1)
-- }}}

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
