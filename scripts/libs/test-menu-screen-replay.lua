-- test-menu-screen-replay.lua -- replays a recorded terminal session onto a
-- grid of cells (cursor moves, text, screen clears; colour codes ignored) and
-- prints the final screen as plain text, so a test can read what was drawn.
-- A character cut in two by a colour code shows up here as a broken byte.
-- Used by test-menu-screen.sh.  (neocities-modernization issue 10-070.)
-- Usage: luajit test-menu-screen-replay.lua SESSION_LOG [ROWS] [COLS]

local log = assert(io.open(arg[1], "rb"), "cannot open " .. tostring(arg[1])):read("*a")
local MAX_ROWS = tonumber(arg[2]) or 60
local MAX_COLS = tonumber(arg[3]) or 140

local grid, row, col = {}, 1, 1
local i, n = 1, #log
while i <= n do
    local c = log:sub(i, i)
    if c == "\27" then
        -- ESC [ params final-letter; only "go to row;col" (H) and "clear" (J)
        -- change the grid, every other sequence is skipped whole.
        local params, final = log:match("^%[([%d;?]*)(%a)", i + 1)
        if params then
            if final == "H" then
                local r, cc = params:match("(%d+);(%d+)")
                row, col = tonumber(r or 1), tonumber(cc or 1)
            elseif final == "J" then
                grid = {}
            end
            i = i + 3 + #params   -- ESC, "[", params, final letter
        else
            i = i + 1
        end
    elseif c == "\r" then
        col, i = 1, i + 1
    elseif c == "\n" then
        row, i = row + 1, i + 1
    else
        -- One UTF-8 character (lead byte plus continuation bytes).
        local char = log:match("^[%z\1-\127\194-\244][\128-\191]*", i) or c
        grid[row] = grid[row] or {}
        grid[row][col] = char
        col, i = col + 1, i + #char
    end
end

for r = 1, MAX_ROWS do
    local cells = {}
    for cc = 1, MAX_COLS do cells[cc] = (grid[r] or {})[cc] or " " end
    local line = table.concat(cells):gsub("%s+$", "")
    if line ~= "" then print(line) end
end
