-- 072-the-txt-canvas.lua
--
-- The .txt end's `table` word (docs/067, issue 807a): rows and columns of
-- text, each column padded to its widest cell, measured in characters, not
-- bytes, so a multi-byte glyph still counts as one column's width. The
-- other .txt words (list, tree, box-diagram, prose — 807b-d) are later
-- pieces of the same end and will join this file when they are built.

local txt_canvas = {}

-- {{{ local function char_width
-- The number of characters in a UTF-8 string: every byte that is not a
-- continuation byte (10xxxxxx) starts one character.
local function char_width(s)
    local n = 0
    for i = 1, #s do
        local b = s:byte(i)
        if b < 0x80 or b >= 0xC0 then
            n = n + 1
        end
    end
    return n
end
-- }}}

-- {{{ local function column_widths
-- The widest cell (in characters) of each column, across every row.
local function column_widths(rows)
    local widths = {}
    for _, row in ipairs(rows) do
        for c, cell in ipairs(row) do
            local w = char_width(cell)
            if not widths[c] or w > widths[c] then
                widths[c] = w
            end
        end
    end
    return widths
end
-- }}}

-- {{{ function txt_canvas.table
-- Canvas word `table`: rows (array of arrays of strings) rendered as
-- space-padded columns, two spaces between columns, one row per line.
function txt_canvas.table(rows)
    local widths = column_widths(rows)
    local lines = {}
    for r, row in ipairs(rows) do
        local cells = {}
        for c, cell in ipairs(row) do
            local pad = widths[c] - char_width(cell)
            cells[c] = cell .. string.rep(" ", pad)
        end
        lines[r] = (table.concat(cells, "  "):gsub("%s+$", ""))
    end
    return table.concat(lines, "\n")
end
-- }}}

txt_canvas.char_width = char_width

return txt_canvas
