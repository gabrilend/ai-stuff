-- test-menu-screen-replay.lua -- replays a recorded terminal session onto a
-- grid of cells (cursor moves, text, screen clears; colour codes ignored) and
-- prints the final screen as plain text, so a test can read what was drawn.
-- A character cut in two by a colour code shows up here as a broken byte.
-- Used by test-menu-screen.sh.  (neocities-modernization issue 10-070.)
--
-- It behaves as a terminal does at the edges (scripts issue 004): a line feed
-- on the bottom row scrolls the whole screen up one row, a character written
-- past the last column wraps to the next row (scrolling at the bottom), and
-- "erase in line" (ESC [ K) clears from the cursor to the end of the row.
-- Other control characters (tput's shift-in after a colour reset, a bell)
-- take no cell, and a character-set choice (ESC ( B) is skipped whole.
-- Without the scroll, a menu that drew one row too many looked right here
-- and wrong on a real terminal.
--
-- Usage: luajit test-menu-screen-replay.lua SESSION_LOG [ROWS] [COLS] [numbered]
--   numbered: print every row, as "NN|text", so a test can check positions.

local log = assert(io.open(arg[1], "rb"), "cannot open " .. tostring(arg[1])):read("*a")
local MAX_ROWS = tonumber(arg[2]) or 60
local MAX_COLS = tonumber(arg[3]) or 140
local NUMBERED = arg[4] == "numbered"

local grid, row, col = {}, 1, 1

-- {{{ local function scroll_up
-- The top row leaves the screen, every other row moves up one, and the
-- bottom row starts empty.
local function scroll_up()
    for r = 1, MAX_ROWS - 1 do grid[r] = grid[r + 1] end
    grid[MAX_ROWS] = nil
end
-- }}}

-- {{{ local function line_feed
local function line_feed()
    if row >= MAX_ROWS then
        scroll_up()
        row = MAX_ROWS
    else
        row = row + 1
    end
end
-- }}}

local i, n = 1, #log
while i <= n do
    local c = log:sub(i, i)
    if c == "\27" then
        -- ESC [ params final-letter; "go to row;col" (H), "clear" (J) and
        -- "erase in line" (K) change the grid, every other sequence is
        -- skipped whole.
        local params, final = log:match("^%[([%d;?]*)(%a)", i + 1)
        if params then
            if final == "H" then
                local r, cc = params:match("(%d+);(%d+)")
                row, col = tonumber(r or 1), tonumber(cc or 1)
            elseif final == "J" then
                grid = {}
            elseif final == "K" and (params == "" or params == "0") then
                if grid[row] then
                    for cc = col, MAX_COLS do grid[row][cc] = nil end
                end
            end
            i = i + 3 + #params   -- ESC, "[", params, final letter
        elseif log:match("^[()][%w]", i + 1) then
            i = i + 3             -- ESC, "(" or ")", the character set
        else
            i = i + 1
        end
    elseif c == "\r" then
        col, i = 1, i + 1
    elseif c == "\n" then
        line_feed()
        i = i + 1
    elseif c == "\b" then
        col, i = math.max(1, col - 1), i + 1
    elseif c:byte() < 32 or c:byte() == 127 then
        i = i + 1                 -- a control character takes no cell
    else
        -- One UTF-8 character (lead byte plus continuation bytes).
        local char = log:match("^[%z\1-\127\194-\244][\128-\191]*", i) or c
        if col > MAX_COLS then
            -- the previous character filled the row: wrap
            line_feed()
            col = 1
        end
        grid[row] = grid[row] or {}
        grid[row][col] = char
        col, i = col + 1, i + #char
    end
end

for r = 1, MAX_ROWS do
    local cells = {}
    for cc = 1, MAX_COLS do cells[cc] = (grid[r] or {})[cc] or " " end
    local line = table.concat(cells):gsub("%s+$", "")
    if NUMBERED then
        print(string.format("%02d|%s", r, line))
    elseif line ~= "" then
        print(line)
    end
end
