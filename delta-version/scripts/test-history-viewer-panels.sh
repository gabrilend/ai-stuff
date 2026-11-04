#!/bin/bash
# test-history-viewer-panels.sh - proves history-viewer.lua lays its screen
# out as three tui panels (header, content, footer) and that nothing it
# writes lands outside the panel it belongs to.
#
# In general terms: the viewer is loaded as a library and drawn into tui's
# in-memory screen (tui.init_buffers, tui.get_cell, tui.set_output from
# scripts/libs/tui.lua), so no terminal is needed. Exercises issue 070,
# step 9.
#
# Usage: test-history-viewer-panels.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"

HISTORY_VIEWER_AS_LIBRARY=1 luajit - "$DIR" <<'EOF'
local DIR = arg[1]
package.path = DIR .. "/scripts/libs/?.lua;" .. package.path
local tui = require("tui")
local viewer = dofile(DIR .. "/delta-version/scripts/history-viewer.lua")
local state = viewer.state

local pass, fail = 0, 0

-- {{{ local function check
local function check(label, ok)
    if ok then
        pass = pass + 1
        print("  ok   - " .. label)
    else
        fail = fail + 1
        print("  FAIL - " .. label)
    end
end
-- }}}

-- {{{ local function row_text
local function row_text(y)
    local out = {}
    for x = 1, tui.cols() do out[#out + 1] = tui.get_cell(y, x).char end
    return table.concat(out)
end
-- }}}

-- {{{ local function starts
local function starts(text, prefix)
    return text:sub(1, #prefix) == prefix
end
-- }}}

-- {{{ local function screen
local function screen(rows, cols)
    tui.init_buffers(rows, cols)
    state.rows, state.cols = rows, cols
    viewer.layout()
end
-- }}}

local sent = {}
tui.set_output(function(text) sent[#sent + 1] = text end)

state.project_name, state.current_idx, state.commit_count = "widget", 2, 5
state.content_lines = {}
for i = 1, 20 do state.content_lines[i] = "line " .. i end
state.content_lines[3] = "§ NOTES"
state.content_lines[5] = string.rep("x", 60)
state.line_count = 20
state.scroll_offset = 0

print("history-viewer.lua on tui panels, in memory")
screen(10, 40)
viewer.render_full()
check("the header is screen row 1", starts(row_text(1), " widget │ Commit 2 of 5 "))
check("... its bar spans the width", tui.get_cell(1, 40).bg == tui.BG_BLUE)
check("the content panel is the rows between", viewer.visible_rows() == 8)
check("... its row 1 is screen row 2", row_text(2):match("^line 1 *$") ~= nil)
check("... and its last row is screen row 9, line 8", row_text(9):match("^line 8 *$") ~= nil)
check("a section header keeps its colour", tui.get_cell(4, 1).fg == tui.FG_YELLOW)
check("a long line stops at the panel's edge, marked", tui.get_cell(6, 39).char == "x"
    and tui.get_cell(6, 40).char == "…")
check("the footer is the last row", starts(row_text(10), " [←] Prev"))
check("... its percentage ends at the right edge", row_text(10):match("│ 0%% $") ~= nil)
check("present() sent the screen", #sent > 0)

viewer.scroll_by(5)
viewer.render_content()
viewer.render_footer()
check("scrolling: content row 1 shows line 6", row_text(2):match("^line 6 *$") ~= nil)
check("... the footer shows how far", row_text(10):match("│ 25%% $") ~= nil)

viewer.scroll_to(1000)
viewer.render_content()
check("scrolling to the end stops with the last line on the last content row",
    state.scroll_offset == 12 and row_text(9):match("^line 20 *$") ~= nil)
check("... and content never writes into the footer row", starts(row_text(10), " [←] Prev"))

state.content_lines = { "only line" }
state.line_count, state.scroll_offset = 1, 0
viewer.render_content()
check("a short commit: the rows below are cleared", row_text(3):match("^ *$") ~= nil)

screen(6, 30)
viewer.render_full()
check("after a resize the panels are laid out again: content is 4 rows", viewer.visible_rows() == 4)
check("... the footer moves to the new last row", starts(row_text(6), " [←] Prev"))
check("... and the header fits the new width", tui.get_cell(1, 30).bg == tui.BG_BLUE)

print()
print(pass .. " passed, " .. fail .. " failed")
os.exit(fail == 0 and 0 or 1)
EOF
