-- test-render.lua — the boxes build_pdf draws and the art regions laid
-- around them (issue 035).  draw_boxed_poem runs against a stand-in for
-- the libharu binding that records where each line of text and each
-- filled rectangle goes, so the checks compare the art layout
-- (compute_poem_layout, compute_tier2_art_spaces, calculate_art_spaces)
-- with the page as it is actually drawn.  Nothing is written to a PDF.
--
-- Usage: <lua5.2 | luajit | lua5.4> test-render.lua [DIR]
--   DIR  the words-pdf project folder (default below)
-- Prints PASS or FAIL per check and "counts <passed> <failed>".

local DIR = arg[1] or "/home/ritz/programming/ai-stuff/words-pdf"
package.path = DIR .. "/tests/?.lua;" .. package.path
local kit = require("kit")

-- compile-pdf-ai.lua is run with lua5.2 (see ./run) and calls
-- table.unpack, which LuaJIT names unpack.
table.unpack = table.unpack or unpack

kit.load_compiler(DIR)

-- The poem's Tier 3 theme needs the embedding server; every box here is
-- drawn as "neutral", which only picks the fill color.
analyze_individual_poem_theme = function() return "neutral" end

-- {{{ local function recorder
-- A stand-in for hpdf that keeps every text line (where it starts and
-- how wide it is in Courier) and every rectangle passed to Page_Rectangle.
local function recorder()
    local drawn = { text = {}, rects = {} }
    local at = { x = 0, y = 0 }
    local binding = setmetatable({
        Page_MoveTextPos = function(_, x, y) at = { x = x, y = y } end,
        Page_ShowText = function(_, text)
            table.insert(drawn.text, { x = at.x, y = at.y,
                width = #text * FONT_SIZE * 0.6, text = text })
        end,
        Page_Rectangle = function(_, x, y, w, h)
            table.insert(drawn.rects, { x = x, y = y, width = w, height = h })
        end,
    }, { __index = function() return function() end end })
    return binding, drawn
end
-- }}}

-- A4 and the layout constants build_pdf uses.
local PAGE_W, PAGE_H = 595, 842
local MARGINS = { left = LEFT_MARGIN, right = RIGHT_MARGIN, top = TOP_MARGIN, bottom = BOTTOM_MARGIN }
local COLUMN_W = (PAGE_W - LEFT_MARGIN - RIGHT_MARGIN - COLUMN_GAP) / 2
local SHIFT = PAGE_W * 0.15
local LINE_H = FONT_SIZE + LINE_SPACING
local COLUMN_X = { left = LEFT_MARGIN - SHIFT, right = LEFT_MARGIN + COLUMN_W + COLUMN_GAP - SHIFT }

-- {{{ local function poem
-- A poem of `lines` lines whose longest line has `width` characters.
local function poem(lines, width)
    local p = {}
    for l = 1, lines do
        p[l] = string.rep("w", l == 1 and width or math.max(1, width - l % 7))
    end
    return p
end
-- }}}

-- {{{ local function draw_page
-- Draws a page's two columns the way build_pdf's steps 3 and 4 do, and
-- returns what was drawn, poem by poem, with the layout's boxes.
local function draw_page(page)
    local layout = compute_poem_layout(page, PAGE_H, MARGINS, COLUMN_W, COLUMN_GAP, SHIFT, LINE_H)
    local per_poem = {}
    local saved = hpdf
    for _, side in ipairs({ "left", "right" }) do
        local y = PAGE_H - MARGINS.top
        for i, p in ipairs(page[side]) do
            local binding, drawn = recorder()
            hpdf = binding
            y = draw_boxed_poem(nil, nil, p, COLUMN_X[side], y, COLUMN_W, LINE_H, MARGINS.bottom, "center")
            y = y - LINE_H
            table.insert(per_poem, { side = side, box = layout[side][i], drawn = drawn })
        end
    end
    hpdf = saved
    return per_poem, layout
end
-- }}}

-- {{{ local function overlap
-- Whether two rectangles share area (touching edges do not count).
local function overlap(a, b)
    local eps = 1e-9
    return a.x + eps < b.x + b.width and b.x + eps < a.x + a.width
       and a.y + eps < b.y + b.height and b.y + eps < a.y + a.height
end
-- }}}

local function where(r)
    return string.format("(x %.2f y %.2f w %.2f h %.2f)", r.x, r.y, r.width, r.height)
end

-- A page with short, medium and full-width poems in both columns.
local PAGE = {
    left = { poem(4, 12), poem(10, MAX_CHAR_PER_LINE), poem(6, 40) },
    right = { poem(8, 60), poem(3, 5), poem(12, MAX_CHAR_PER_LINE) },
}

print("the layout's boxes are the boxes drawn")
-- {{{ boxes
kit.check("each box is exactly the rectangle draw_boxed_poem fills", function()
    for _, entry in ipairs(draw_page(PAGE)) do
        kit.same(#entry.drawn.rects, 1, "rectangles per poem")
        local rect, box = entry.drawn.rects[1], entry.box
        for _, field in ipairs({ "x", "y", "width", "height" }) do
            kit.near(box[field], rect[field], entry.side .. " box " .. field)
        end
    end
end)
kit.check("every line of text lies inside its poem's box", function()
    for _, entry in ipairs(draw_page(PAGE)) do
        local box = entry.box
        kit.same(#entry.drawn.text, #entry.box.poem + 4, "lines drawn")
        for _, line in ipairs(entry.drawn.text) do
            local inside = line.x >= box.x - 1e-9 and line.x + line.width <= box.x + box.width + 1e-9
                and line.y >= box.y and line.y <= box.y + box.height
            kit.truthy(inside, entry.side .. " line at x " .. line.x .. " y " .. line.y
                .. " inside " .. where(box))
        end
    end
end)
kit.check("every box lies on the page", function()
    for _, entry in ipairs(draw_page(PAGE)) do
        local b = entry.box
        kit.truthy(b.x >= 0 and b.x + b.width <= PAGE_W, entry.side .. " box " .. where(b) .. " on the page")
    end
end)
kit.check("boxes in a column are one blank line apart", function()
    local _, layout = draw_page(PAGE)
    for _, side in ipairs({ "left", "right" }) do
        local column = layout[side]
        for i = 2, #column do
            kit.near(column[i - 1].y - (column[i].y + column[i].height), LINE_H, side .. " gap above poem " .. i)
        end
    end
end)
-- }}}

print("Tier 2 strips around each box")
-- {{{ tier 2
local tier2 = kit.sandbox({
    kit.extract_function(DIR .. "/compile-pdf-ai.lua", "compute_tier2_art_spaces"),
})

kit.check("no strip covers its own box, and strips do not cover each other", function()
    for _, entry in ipairs(draw_page(PAGE)) do
        local strips = tier2.compute_tier2_art_spaces(entry.box, entry.side == "left",
            COLUMN_GAP, LINE_H, PAGE_W)
        kit.truthy(#strips >= 3, entry.side .. " has at least three strips")
        for i, s in ipairs(strips) do
            kit.truthy(not overlap(s, entry.box), entry.side .. " strip " .. i .. " " .. where(s)
                .. " clear of box " .. where(entry.box))
            for j = i + 1, #strips do
                kit.truthy(not overlap(s, strips[j]), entry.side .. " strips " .. i .. " and " .. j .. " apart")
            end
        end
    end
end)
kit.check("left-column boxes get an outer strip now that their margin is real", function()
    for _, entry in ipairs(draw_page(PAGE)) do
        if entry.side == "left" then
            local strips = tier2.compute_tier2_art_spaces(entry.box, true, COLUMN_GAP, LINE_H, PAGE_W)
            kit.same(#strips, 4, "strips around a left box " .. where(entry.box))
            kit.near(strips[4].x, 0, "outer strip starts at the page edge")
            kit.near(strips[4].width, entry.box.x, "outer strip reaches the box")
        end
    end
end)
-- }}}

print("Tier 1 regions around the page's boxes")
-- {{{ tier 1
kit.check("no Tier 1 region the gate can draw covers a box", function()
    local per_poem = draw_page(PAGE)
    local spaces = calculate_art_spaces(PAGE, PAGE_W, PAGE_H, MARGINS, COLUMN_W, COLUMN_GAP, SHIFT)
    for _, name in ipairs({ "bottom_space", "left_outer", "right_outer", "center" }) do
        for _, region in ipairs(spaces[name]) do
            for _, entry in ipairs(per_poem) do
                kit.truthy(not overlap(region, entry.box), name .. " " .. where(region)
                    .. " clear of " .. entry.side .. " box " .. where(entry.box))
            end
        end
    end
end)
kit.check("a column's bottom region sits under that column's boxes", function()
    -- A short page: both columns leave a bottom region.
    local page = { left = { poem(5, MAX_CHAR_PER_LINE) }, right = { poem(5, 30) } }
    local per_poem = draw_page(page)
    local spaces = calculate_art_spaces(page, PAGE_W, PAGE_H, MARGINS, COLUMN_W, COLUMN_GAP, SHIFT)
    kit.same(#spaces.bottom_space, 2, "bottom regions")
    for _, region in ipairs(spaces.bottom_space) do
        for _, entry in ipairs(per_poem) do
            if entry.side == region.column then
                local b = entry.box
                kit.truthy(region.x <= b.x + 1e-9 and region.x + region.width >= b.x + b.width - 1e-9,
                    region.column .. " bottom " .. where(region) .. " spans box " .. where(b))
                kit.truthy(region.y + region.height <= b.y, region.column .. " bottom is below the box")
            end
        end
        kit.truthy(region.x >= 0 and region.x + region.width <= PAGE_W, region.column .. " bottom on the page")
    end
end)
-- }}}

kit.finish()
