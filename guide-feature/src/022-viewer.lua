-- 022-viewer.lua - the viewer-side canvas reader: what a viewer draws from.
--
-- In plain terms: a viewer is handed the canvas text (from a file or over
-- HTTP) and has to draw it. This reads it with the canvas reader (102) and
-- gives back what every viewer needs on top (docs/datapath-viewers.md): a
-- grid of cells, each a character and its mark if it has one; each mark's
-- age, which a viewer turns into faintness; and, given the version the viewer
-- drew before, the cells whose character changed, so it can draw the new
-- words arriving over the old ones. It never changes a character.
--
--   local viewer = dofile(DIR .. "/src/022-viewer.lua")
--   local view = viewer.read(text)            -- or viewer.read(text, "current")
--   view.version, view.width, view.height, view.voices, view.headers
--   view.cells[row][column].character         -- one code point, as a string
--   view.cells[row][column].mark              -- nil, or { voice, version, kind, age }
--   viewer.changed(view, previous_view)       -- { { row, column, was, now }, ... }
--   viewer.too_small(view, columns, rows)     -- the error to show, or nil
--   viewer.colour_of(view, "fg-sora-2")       -- 2: its place in the voices header
--
-- It follows only docs/canvas-protocol.md and the canvas reader, so the
-- other viewers (HTML, Android, watch) are checked against its answers on
-- the same test canvases (assets/test-canvases/). LuaJIT-compatible.

-- {{{ local DIR
-- Sibling files are found next to this one (as in 006).
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local utf8 = dofile(DIR .. "/src/005-utf8.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")

local M = {}

-- {{{ function M.read()
-- The canvas text for viewers in; a view out, or an error naming the line,
-- as the canvas reader gives it ("current:11: ..."). A mark from a version
-- newer than the canvas is refused too, naming its line: its age would be
-- below zero. Where mark lines overlap, the
-- later line wins on the cells they share.
function M.read(text, source)
    source = source or "canvas"
    local record = canvas.read(text, "for-viewers", source)
    local version = record.headers.canvas
    local cells = {}
    for row = 1, record.height do
        -- the canvas reader has padded every row to the width
        local characters = utf8.split(record.rows[row])
        local line = {}
        for column = 1, record.width do
            line[column] = { character = characters[column] }
        end
        cells[row] = line
    end
    -- the line of mark N: the headers, the blank line, the rows, `marks:`
    local before_marks = #canvas.SETS["for-viewers"] + 1 + record.height + 1
    for index, run in ipairs(record.marks) do
        if run.version > version then
            error(source .. ":" .. (before_marks + index) .. ": this mark is from version "
                .. run.version .. ", newer than the canvas's version " .. version, 0)
        end
        for column = run.column, run.column + run.length - 1 do
            cells[run.row][column].mark = { voice = run.voice, version = run.version,
                kind = run.kind, age = version - run.version }
        end
    end
    return { version = version, width = record.width, height = record.height,
             voices = record.headers.voices, headers = record.headers,
             cells = cells, record = record }
end
-- }}}

-- {{{ function M.changed()
-- The cells whose character differs from the version the viewer drew before,
-- in reading order: { row, column, was, now }. With no previous view, or one
-- of another size (205 makes a canvas per screen size), every cell that is
-- not a space is new, with `was` nil. A change of mark alone is not listed:
-- a viewer draws every mark afresh with each version.
function M.changed(view, previous)
    local list = {}
    local comparable = previous ~= nil and previous.width == view.width
        and previous.height == view.height
    for row = 1, view.height do
        for column = 1, view.width do
            local now = view.cells[row][column].character
            if comparable then
                local was = previous.cells[row][column].character
                if was ~= now then
                    list[#list + 1] = { row = row, column = column, was = was, now = now }
                end
            elseif now ~= " " then
                list[#list + 1] = { row = row, column = column, now = now }
            end
        end
    end
    return list
end
-- }}}

-- {{{ function M.too_small()
-- A screen smaller than the canvas shows an error naming both sizes; it never
-- squeezes or crops. Returns that error's text, or nil when the canvas fits.
function M.too_small(view, columns, rows)
    if columns < view.width or rows < view.height then
        return string.format("the canvas is %dx%d; this screen is %dx%d", view.width,
            view.height, columns, rows)
    end
    return nil
end
-- }}}

-- {{{ function M.colour_of()
-- A voice's place in the `voices:` header (1, 2, 3 ...), which is the order
-- viewers give them colours; nil for a voice not listed (`kuvalu`, the
-- distiller), which a viewer draws in its own colour.
function M.colour_of(view, voice)
    for index, name in ipairs(view.voices) do
        if name == voice then return index end
    end
    return nil
end
-- }}}

return M
