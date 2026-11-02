-- 072-the-txt-canvas.lua
--
-- The .txt end's `table` word (docs/067, issue 807a): rows and columns of
-- text, each column padded to its widest cell, measured in characters, not
-- bytes, so a multi-byte glyph still counts as one column's width. `list`
-- and `tree` (issue 807b) join it here, and `box-diagram` (807c): boxes in
-- ASCII lines, arrows between them with a label at either end. `prose`
-- (807d) is a later piece of the same end.

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

-- {{{ local function chars_of
-- A UTF-8 string as an array of its characters, one per grid cell.
local function chars_of(s)
    local out = {}
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        out[#out + 1] = ch
    end
    return out
end
-- }}}

-- The box diagram's fixed measures, in characters. A box is three rows:
-- its top edge, its one line of text, its bottom edge.
local BOX_PAD = 1          -- spaces between a box's side and its text
local MIN_GAP = 4          -- columns between two boxes, before arrows widen it
local ENDPOINT_STEP = 2    -- columns between two arrow ends on one box's edge

-- {{{ local function check_diagram
-- Refuses a diagram the drawing could only get wrong: a box without a
-- name, two boxes of one name, an arrow to or from a box not drawn, or an
-- arrow from a box to itself. Every name a refusal could need is given.
local function check_diagram(diagram)
    local names, order = {}, {}
    for i, box in ipairs(diagram.boxes or {}) do
        if type(box.name) ~= "string" or box.name == "" then
            error("txt_canvas.box_diagram: box " .. i .. " has no name")
        end
        if names[box.name] then
            error("txt_canvas.box_diagram: two boxes are named '" .. box.name .. "'")
        end
        names[box.name] = i
        order[#order + 1] = box.name
    end
    if #order == 0 then
        error("txt_canvas.box_diagram: a diagram needs at least one box")
    end
    for i, arrow in ipairs(diagram.arrows or {}) do
        for _, end_name in ipairs({ "from", "to" }) do
            if not names[arrow[end_name]] then
                error("txt_canvas.box_diagram: arrow " .. i .. "'s " .. end_name .. " names no box ('"
                    .. tostring(arrow[end_name]) .. "'; boxes are " .. table.concat(order, ", ") .. ")")
            end
        end
        if arrow.from == arrow.to then
            error("txt_canvas.box_diagram: arrow " .. i .. " goes from '" .. arrow.from
                .. "' to itself; a box diagram draws arrows between two boxes")
        end
    end
    return names
end
-- }}}

-- {{{ function txt_canvas.box_diagram
-- Canvas word `box-diagram` (docs/067, issue 807c): `diagram.boxes` (array
-- of `{name, text}`, `text` defaulting to the name) drawn left to right in
-- ASCII lines, and `diagram.arrows` (array of `{from, to, there, here}`,
-- box names and two labels) drawn beneath them, one lane each in the order
-- given. An arrow leaves its source box's bottom edge, runs along its own
-- lane, and rises to an arrowhead `^` under its target; `there` is written
-- on the lane at the source end and `here` at the target end -- the
-- look's `there-here` arrow. Each arrow end has its own column on its
-- box's edge, so no two arrows share a line. The gap between boxes widens,
-- one column at a time, until every lane holds both its labels. Measured
-- in characters, so a multi-byte glyph is one column; the same diagram
-- always gives the same text.
function txt_canvas.box_diagram(diagram)
    local names = check_diagram(diagram)
    local boxes, arrows = diagram.boxes, diagram.arrows or {}
    -- Which arrow ends sit on each box's edge, in arrow order.
    local ends = {}
    for i = 1, #boxes do
        ends[i] = {}
    end
    for k, arrow in ipairs(arrows) do
        table.insert(ends[names[arrow.from]], { arrow = k, side = "from" })
        table.insert(ends[names[arrow.to]], { arrow = k, side = "to" })
    end
    -- Each box's inner width: its text, or room for its arrow ends.
    local widths = {}
    for i, box in ipairs(boxes) do
        local text_width = char_width(box.text or box.name) + 2 * BOX_PAD
        local ends_width = (#ends[i] - 1) * ENDPOINT_STEP + 3
        widths[i] = math.max(text_width, ends_width)
    end
    -- {{{ local function layout
    -- Box left columns, and each arrow's two end columns, for a given gap.
    local function layout(gap)
        local lefts, column = {}, 0
        for i = 1, #boxes do
            lefts[i] = column
            column = column + widths[i] + 2 + gap
        end
        local at = {}
        for i = 1, #boxes do
            for j, e in ipairs(ends[i]) do
                at[e.arrow] = at[e.arrow] or {}
                at[e.arrow][e.side] = lefts[i] + 2 + (j - 1) * ENDPOINT_STEP
            end
        end
        return lefts, at
    end
    -- }}}
    -- {{{ local function place_labels
    -- Where arrow k's two labels sit on its lane, or nil when they do not
    -- fit: each at its own end, a dash from the corner, clear of every
    -- vertical crossing the lane (the arrows drawn below it), and two dashes
    -- apart from each other. Returns {start, chars} for the low end and the high end.
    local function place_labels(k, at)
        local arrow = arrows[k]
        local from_col, to_col = at[k].from, at[k].to
        local low, high = math.min(from_col, to_col), math.max(from_col, to_col)
        local crossing = {}
        for j = k + 1, #arrows do
            crossing[at[j].from] = true
            crossing[at[j].to] = true
        end
        local function clear(start, n)
            for c = start, start + n - 1 do
                if crossing[c] then return false end
            end
            return true
        end
        local low_text = (from_col < to_col) and arrow.there or arrow.here
        local high_text = (from_col < to_col) and arrow.here or arrow.there
        local placed = {}
        local low_end = low + 1
        if low_text and low_text ~= "" then
            local chars = chars_of(" " .. low_text .. " ")
            local start = low + 2
            while not clear(start, #chars) do start = start + 1 end
            placed.low = { start = start, chars = chars }
            low_end = start + #chars - 1
        end
        if high_text and high_text ~= "" then
            local chars = chars_of(" " .. high_text .. " ")
            local start = high - 1 - #chars
            -- Two dashes at least between the labels, so they read as two.
            while start > low_end + 2 and not clear(start, #chars) do start = start - 1 end
            if start <= low_end + 2 then return nil end
            placed.high = { start = start, chars = chars }
        elseif low_end > high - 2 then
            return nil
        end
        return placed
    end
    -- }}}
    local gap = MIN_GAP
    local lefts, at, labels
    while true do
        lefts, at = layout(gap)
        labels = {}
        local fits = true
        for k = 1, #arrows do
            labels[k] = place_labels(k, at)
            if not labels[k] then fits = false end
        end
        if fits then
            break
        end
        gap = gap + 1
    end
    -- The grid: three box rows, one row where arrows meet the boxes, then
    -- one lane per arrow.
    local grid = {}
    local total_rows = 4 + #arrows
    local function put(row, col, ch)
        grid[row] = grid[row] or {}
        grid[row][col] = ch
    end
    for i, box in ipairs(boxes) do
        local left, w = lefts[i], widths[i]
        put(0, left, "+")
        put(2, left, "+")
        put(0, left + w + 1, "+")
        put(2, left + w + 1, "+")
        put(1, left, "|")
        put(1, left + w + 1, "|")
        for c = left + 1, left + w do
            put(0, c, "-")
            put(2, c, "-")
            put(1, c, " ")
        end
        for n, ch in ipairs(chars_of(box.text or box.name)) do
            put(1, left + BOX_PAD + n, ch)
        end
    end
    for k, arrow in ipairs(arrows) do
        local lane = 3 + k
        local from_col, to_col = at[k].from, at[k].to
        local low, high = math.min(from_col, to_col), math.max(from_col, to_col)
        for c = low + 1, high - 1 do
            -- A lane passes under the verticals of the lanes above it.
            if not (grid[lane] and grid[lane][c] == "|") then
                put(lane, c, "-")
            end
        end
        put(lane, low, "+")
        put(lane, high, "+")
        -- Labels on the lane: `there` by the source end, `here` by the
        -- target, where place_labels found room for them.
        for _, label in pairs(labels[k]) do
            for n, ch in ipairs(label.chars) do
                put(lane, label.start + n - 1, ch)
            end
        end
        -- The two verticals, crossing the lanes above this one.
        for row = 3, lane - 1 do
            put(row, from_col, "|")
            put(row, to_col, "|")
        end
        put(3, to_col, "^")
    end
    local lines = {}
    for row = 0, total_rows - 1 do
        local cells = grid[row] or {}
        local last = -1
        for c in pairs(cells) do
            if c > last then last = c end
        end
        local out = {}
        for c = 0, last do
            out[#out + 1] = cells[c] or " "
        end
        lines[#lines + 1] = (table.concat(out):gsub("%s+$", ""))
    end
    return table.concat(lines, "\n")
end
-- }}}

txt_canvas.char_width = char_width

return txt_canvas
