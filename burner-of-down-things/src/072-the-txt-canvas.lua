-- 072-the-txt-canvas.lua
--
-- The .txt end's `table` word (docs/067, issue 807a): rows and columns of
-- text, each column padded to its widest cell, measured in characters, not
-- bytes, so a multi-byte glyph still counts as one column's width. `list`
-- and `tree` (issue 807b) join it here. `box-diagram` and `prose` (807c-d)
-- are later pieces of the same end and will join this file when built.

local txt_canvas = {}

-- How many spaces a tree's nesting steps down per level of depth. One
-- fixed step, so a rendered tree's levels are always the same distance
-- apart no matter how deep they go.
local TREE_STEP = 2

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

-- {{{ function txt_canvas.list
-- Canvas word `list`: items (array of strings) rendered one per line, each
-- prefixed with a bullet. One level only, so the bullet is always the
-- first thing on the line and every line's bullet lands in the same
-- column.
function txt_canvas.list(items)
    local lines = {}
    for i, item in ipairs(items) do
        lines[i] = "- " .. item
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ local function tree_lines
-- Depth-first walk of a tree node: `node.text` at the current depth,
-- indented TREE_STEP spaces per level, then each of `node.children` one
-- level deeper. Appends each line onto `lines`; no bullets, since the
-- indentation alone carries the nesting (unlike `list`, which is flat).
local function tree_lines(node, depth, lines)
    lines[#lines + 1] = string.rep(" ", depth * TREE_STEP) .. node.text
    for _, child in ipairs(node.children or {}) do
        tree_lines(child, depth + 1, lines)
    end
end
-- }}}

-- {{{ function txt_canvas.tree
-- Canvas word `tree`: a node (`{ text = string, children = {node, ...} }`,
-- `children` optional at a leaf) rendered depth-first, one line per node,
-- each level indented a fixed step deeper than its parent.
function txt_canvas.tree(root)
    local lines = {}
    tree_lines(root, 0, lines)
    return table.concat(lines, "\n")
end
-- }}}

txt_canvas.char_width = char_width

return txt_canvas
