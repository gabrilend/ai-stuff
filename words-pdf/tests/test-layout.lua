-- test-layout.lua — laying poems out into pages and columns (build_book,
-- append_long_poem, calculate_poem_height) and choosing where Tier 1 page
-- art may go (calculate_art_spaces and issue 028's select_tier1_regions).
-- The book is made of synthetic poems from a fixed-seed generator, so
-- every interpreter lays out the same book.
--
-- Usage: <lua5.2 | luajit | lua5.4> test-layout.lua [DIR]
--   DIR  the words-pdf project folder (default below)
-- Prints PASS or FAIL per check and "counts <passed> <failed>".

local DIR = arg[1] or "/home/ritz/programming/ai-stuff/words-pdf"
package.path = DIR .. "/tests/?.lua;" .. package.path
local kit = require("kit")
kit.load_compiler(DIR)

-- {{{ function make_book
-- A book of `count` poems whose lengths come from a small linear
-- congruential generator (same numbers on every interpreter, unlike
-- math.random). Lengths run 1..max_len, so with max_len above
-- MAX_LINES_PER_PAGE some poems must be split across columns.
local function make_book(count, max_len, seed)
    local state = seed
    local function next_len()
        state = (state * 1103515245 + 12345) % 2147483648
        return 1 + (state % max_len)
    end
    local book = { pages = {}, poems = {} }
    for p = 1, count do
        local poem = {}
        for l = 1, next_len() do
            table.insert(poem, "p" .. p .. " l" .. l)
        end
        table.insert(book.poems, poem)
    end
    return book
end
-- }}}

-- {{{ function columns_of
-- Every column of a laid-out book, in reading order: page 1 left, page 1
-- right, page 2 left, ...
local function columns_of(book)
    local columns = {}
    for page_num, page in ipairs(book.pages) do
        table.insert(columns, { items = page.left, page = page_num, side = "left" })
        table.insert(columns, { items = page.right, page = page_num, side = "right" })
    end
    return columns
end
-- }}}

-- {{{ function check_layout
-- The invariants every laid-out book must keep.
local function check_layout(book, label)
    local columns = columns_of(build_book(book))

    -- Every line of every poem appears exactly once, in the original order.
    local want, got = {}, {}
    for _, poem in ipairs(book.poems) do
        for _, line in ipairs(poem) do table.insert(want, line) end
    end
    for _, column in ipairs(columns) do
        for _, item in ipairs(column.items) do
            for _, line in ipairs(item) do table.insert(got, line) end
        end
    end
    kit.same(#got, #want, label .. " line count")
    for i = 1, #want do
        if got[i] ~= want[i] then
            error(label .. ": line " .. i .. " is '" .. tostring(got[i]) .. "', want '" .. want[i] .. "'")
        end
    end

    for c, column in ipairs(columns) do
        local where = label .. " page " .. column.page .. " " .. column.side
        -- A column's boxes fit: heights summed, minus the spacing line
        -- after the last box, never exceed the column.
        local used = 0
        for _, item in ipairs(column.items) do used = used + calculate_poem_height(item) end
        if #column.items > 0 then
            kit.truthy(used - 1 <= MAX_LINES_PER_PAGE,
                where .. " uses " .. (used - 1) .. " of " .. MAX_LINES_PER_PAGE .. " lines")
        end
        -- No empty column before the last one (the last page's right
        -- column may be empty when the book ends on a left column).
        if c < #columns - 1 then
            kit.truthy(#column.items > 0, where .. " is not empty")
        end
        for _, item in ipairs(column.items) do
            kit.truthy(#item > 0, where .. " holds no empty segment")
            kit.truthy(type(item._index) == "number", where .. " item carries _index")
            kit.truthy(item._full_text == table.concat(book.poems[item._index], " "),
                where .. " item carries its whole poem's text")
        end
    end
    return columns
end
-- }}}

print("calculate_poem_height")
-- {{{ heights
kit.check("a poem takes its lines plus box, padding and one spacing line", function()
    kit.same(calculate_poem_height({}), 5)
    kit.same(calculate_poem_height({ "a", "b", "c" }), 8)
end)
-- }}}

print("build_book")
-- {{{ layout
kit.check("short poems only: every line once, in order, columns fit", function()
    check_layout(make_book(200, 40, 7), "short")
end)
kit.check("mixed with poems longer than a column: same guarantees", function()
    check_layout(make_book(120, 400, 11), "mixed")
end)
kit.check("a book of only very long poems", function()
    check_layout(make_book(6, 900, 3), "long")
end)
kit.check("a poem exactly one column tall stays whole", function()
    local book = { pages = {}, poems = {} }
    local poem = {}
    for l = 1, MAX_LINES_PER_PAGE - 5 do table.insert(poem, "x" .. l) end
    book.poems[1] = poem
    local columns = check_layout(book, "exact")
    kit.same(#columns[1].items, 1, "one item in the first column")
    kit.same(#columns[1].items[1], MAX_LINES_PER_PAGE - 5, "unsplit")
end)
kit.check("a long poem starts at the top of a fresh column", function()
    local book = make_book(1, 10, 1)            -- one short poem first
    local long = {}
    for l = 1, MAX_LINES_PER_PAGE * 2 do table.insert(long, "long " .. l) end
    table.insert(book.poems, long)
    local columns = check_layout(book, "fresh")
    kit.same(#columns[1].items, 1, "short poem alone in column 1")
    kit.same(columns[2].items[1][1], "long 1", "long poem opens column 2")
end)
kit.check("segments of one poem share its _index", function()
    local book = { pages = {}, poems = {} }
    local long = {}
    for l = 1, MAX_LINES_PER_PAGE * 3 do table.insert(long, "s" .. l) end
    book.poems[1] = long
    local columns = check_layout(book, "segments")
    local pieces = 0
    for _, column in ipairs(columns) do
        for _, item in ipairs(column.items) do
            pieces = pieces + 1
            kit.same(item._index, 1, "segment index")
        end
    end
    kit.truthy(pieces >= 3, "poem split into at least three segments")
end)
-- }}}

print("select_tier1_regions")
-- {{{ the issue 028 gate, on regions made up for the purpose
-- A 100 x 100 page: 8% of it is 800 square points.
local function region(w, h) return { x = 0, y = 0, width = w, height = h } end

kit.check("a column bottom at 8% opens the gate; big margins join it, slivers do not", function()
    local spaces = {
        bottom_space = { region(40, 20) },      -- 800: exactly 8%, opens the gate
        left_outer   = { region(5, 100) },      -- 500: sliver, not drawn
        right_outer  = { region(10, 100) },     -- 1000: drawn once the gate is open
        center       = { region(7.99, 100) },   -- 799: sliver, not drawn
        left_inner   = {}, right_inner = {}, gaps = {},
    }
    local qualifying, measured, largest = select_tier1_regions(spaces, 100, 100)
    kit.same(#measured, 1, "measured regions (column bottoms only)")
    kit.same(#qualifying, 2, "regions drawn")
    kit.same(qualifying[1], spaces.bottom_space[1], "bottom strip first")
    kit.same(qualifying[2], spaces.right_outer[1], "then right margin")
    kit.near(largest, 800, "largest measured area")
end)
kit.check("a margin alone, however big, does not open the gate (issue 033)", function()
    local spaces = {
        bottom_space = { region(50, 15) },      -- 750: under 8%
        left_outer   = { region(30, 100) },     -- 3000
        right_outer  = { region(30, 100) },     -- 3000
        center       = { region(30, 100) },     -- 3000
        left_inner   = {}, right_inner = {}, gaps = {},
    }
    local qualifying, measured, largest = select_tier1_regions(spaces, 100, 100)
    kit.same(#qualifying, 0, "regions drawn")
    kit.same(#measured, 1, "measured regions")
    kit.near(largest, 750, "largest measured area is the bottom strip's")
end)
kit.check("inner gutters and gaps never count, however big", function()
    local spaces = {
        bottom_space = {}, left_outer = {}, right_outer = {}, center = {},
        left_inner = { region(100, 100) }, right_inner = { region(100, 100) },
        gaps = { region(100, 100) },
    }
    local qualifying, measured, largest = select_tier1_regions(spaces, 100, 100)
    kit.same(#qualifying, 0, "qualifying")
    kit.same(#measured, 0, "measured")
    kit.same(largest, 0, "largest")
end)
kit.check("raising the threshold drops regions below it", function()
    local saved = TIER1_MIN_REGION_AREA_FRACTION
    TIER1_MIN_REGION_AREA_FRACTION = 0.5
    local spaces = {
        bottom_space = { region(100, 60) }, left_outer = {}, center = {},
        right_outer = { region(100, 40) },
    }
    local qualifying = select_tier1_regions(spaces, 100, 100)
    TIER1_MIN_REGION_AREA_FRACTION = saved
    kit.same(#qualifying, 1, "qualifying")
    kit.same(qualifying[1], spaces.bottom_space[1], "only the 60% region")
end)
-- }}}

print("calculate_art_spaces")
-- {{{ outside regions on the real page (the geometry build_pdf uses)
local PAGE_W, PAGE_H = 595, 842
local MARGINS = { left = LEFT_MARGIN, right = RIGHT_MARGIN, top = TOP_MARGIN, bottom = BOTTOM_MARGIN }
local COLUMN_W = (PAGE_W - LEFT_MARGIN - RIGHT_MARGIN - COLUMN_GAP) / 2
local SHIFT = PAGE_W * 0.15

-- {{{ local function spaces_for
local function spaces_for(left_lines, right_lines)
    local function poems(n)
        if n == 0 then return {} end
        local poem = {}
        for l = 1, n do poem[l] = "x" end
        return { poem }
    end
    return calculate_art_spaces({ left = poems(left_lines), right = poems(right_lines) },
        PAGE_W, PAGE_H, MARGINS, COLUMN_W, COLUMN_GAP, SHIFT)
end
-- }}}

kit.check("an empty page has a bottom region under each column", function()
    local spaces = spaces_for(0, 0)
    kit.same(#spaces.bottom_space, 2, "bottom regions")
    kit.same(spaces.bottom_space[1].column, "left")
    kit.same(spaces.bottom_space[2].column, "right")
end)
kit.check("a full column has no bottom region; the other column keeps its own", function()
    local spaces = spaces_for(MAX_LINES_PER_PAGE - 5, 10)
    kit.same(#spaces.bottom_space, 1, "bottom regions")
    kit.same(spaces.bottom_space[1].column, "right")
end)
kit.check("the bottom region shrinks as its column fills", function()
    local short = spaces_for(10, 0).bottom_space[1].height
    local longer = spaces_for(60, 0).bottom_space[1].height
    kit.truthy(longer < short, "60 lines leave less room than 10")
end)
kit.check("every region lies within the page width", function()
    local spaces = spaces_for(30, 90)
    for name, list in pairs(spaces) do
        for _, r in ipairs(list) do
            kit.truthy(r.width > 0, name .. " has width")
            kit.truthy(r.x + r.width <= PAGE_W + 1e-9, name .. " ends inside the page")
        end
    end
end)
kit.check("a full page gets no Tier 1 art, though its right margin is 16% (issue 033)", function()
    -- The 15% page shift leaves the right margin 94.25 x 842, about 16% of
    -- the page.  Before issue 033 that alone passed the gate on every
    -- themed page; now only an empty column bottom can.
    local spaces = spaces_for(MAX_LINES_PER_PAGE - 1, MAX_LINES_PER_PAGE - 1)
    kit.same(#spaces.bottom_space, 0, "bottom regions")
    kit.truthy(spaces.right_outer[1].width * spaces.right_outer[1].height
        >= PAGE_W * PAGE_H * TIER1_MIN_REGION_AREA_FRACTION, "right margin is above the threshold")
    local qualifying = select_tier1_regions(spaces, PAGE_W, PAGE_H)
    kit.same(#qualifying, 0, "regions drawn")
end)
kit.check("a half-empty column opens the gate and the right margin joins it", function()
    local half = math.floor(MAX_LINES_PER_PAGE / 2)
    local spaces = spaces_for(MAX_LINES_PER_PAGE - 1, half)
    kit.same(#spaces.bottom_space, 1, "bottom regions")
    local qualifying = select_tier1_regions(spaces, PAGE_W, PAGE_H)
    kit.same(#qualifying, 2, "regions drawn")
    kit.same(qualifying[1], spaces.bottom_space[1], "the right column's bottom")
    kit.same(qualifying[2], spaces.right_outer[1], "the right margin")
end)
kit.check("with one column full, the page opens exactly when the other's bottom reaches 8%", function()
    -- Fill the right column a line at a time.  The page must pass exactly
    -- on the fills whose empty bottom is at least 8% of the page, and both
    -- outcomes must occur (on A4 the turn comes near 36 empty lines).
    local min_area = PAGE_W * PAGE_H * TIER1_MIN_REGION_AREA_FRACTION
    local opened, closed = 0, 0
    for lines = 1, MAX_LINES_PER_PAGE - 1 do
        local spaces = spaces_for(MAX_LINES_PER_PAGE - 1, lines)
        local bottom = spaces.bottom_space[1]
        local roomy = bottom ~= nil and bottom.width * bottom.height >= min_area
        local open = #select_tier1_regions(spaces, PAGE_W, PAGE_H) > 0
        kit.same(open, roomy, lines .. " lines in the right column: page passes")
        if open then opened = opened + 1 else closed = closed + 1 end
    end
    kit.truthy(opened > 0 and closed > 0, "some fills pass and some do not")
end)
-- }}}

kit.finish()
