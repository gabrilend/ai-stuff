-- 003-stl.lua - reads and writes STL, the triangle list every CAD program
-- and 3D printer speaks.
--
-- In plain terms: an STL file is nothing but triangles, written either as
-- words ("vertex 1 0 0") or as raw 4-byte numbers. This file turns either
-- kind into a shape record (001) and writes a shape back out as either kind.
--
-- The two kinds, byte by byte:
--   text:   solid NAME
--             facet normal nx ny nz
--               outer loop
--                 vertex x y z      (three times)
--               endloop
--             endfacet              (repeated)
--           endsolid NAME           (a file may hold several solids: parts)
--   binary: 80 bytes of header (free text, often starting "solid" too)
--           4 bytes: triangle count, unsigned, little-endian
--           50 bytes per triangle: 12 little-endian 32-bit floats (normal,
--           then three corners) and a 2-byte attribute word (ignored)
-- Telling them apart: by SIZE. A binary file is exactly 84 + 50 × count
-- bytes. Testing the first word for "solid" is the classic mistake, because
-- many exporters put "solid" in the binary header.
--
-- Stored normals are thrown away: many exporters write zeros, and the shape
-- record recomputes flat ones from the corners, which are always right.
-- STL's convention is z up (3D printing: the bed is the floor).

local ffi = require("ffi")
local record = require("001-the-shape-record")

local M = {}

-- {{{ function M.is_binary()
-- True when the bytes' size matches the binary layout's own count.
function M.is_binary(bytes)
    if #bytes < 84 then return false end
    local count = ffi.cast("const uint32_t *", ffi.cast("const char *", bytes) + 80)[0]
    return #bytes == 84 + 50 * count
end
-- }}}

-- {{{ local function read_binary()
-- Each 50-byte record is read through a float view of the bytes. Records are
-- 50 bytes, not a multiple of 4, so the view is re-aimed at every record
-- rather than walked as one long array.
local function read_binary(bytes, name)
    local shape = record.new(name, "stl", "z")
    local part = record.add_part(shape, name)
    local start = ffi.cast("const char *", bytes)
    local count = ffi.cast("const uint32_t *", start + 80)[0]
    -- LuaJIT on x86 and ARM reads unaligned floats correctly; the format is
    -- little-endian, and so is every machine this runs on
    for index = 0, count - 1 do
        local f = ffi.cast("const float *", start + 84 + index * 50)
        record.add_triangle(part, f[3], f[4], f[5], f[6], f[7], f[8], f[9], f[10], f[11])
    end
    return record.finish(shape)
end
-- }}}

-- {{{ local function read_text()
-- A small machine walking the lines: each keyword has a handler (a dispatch
-- table), and the handler checks the keyword came in its proper place, so a
-- broken file stops at the line where it broke.
local function read_text(bytes, name)
    local shape = record.new(name, "stl", "z")
    local state = { part = nil, corners = {}, line = 0 }
    local function fail(message)
        error(name .. ": line " .. state.line .. ": " .. message, 0)
    end
    local handlers = {
        solid = function(rest)
            if state.part ~= nil then fail("'solid' inside another solid") end
            local solid_name = rest:match("^%s*(.-)%s*$")
            state.part = record.add_part(shape, solid_name ~= "" and solid_name or name)
        end,
        facet = function()
            if state.part == nil then fail("'facet' outside a solid") end
            state.corners = {}
        end,
        outer = function() end,
        vertex = function(rest)
            if state.part == nil then fail("'vertex' outside a solid") end
            local x, y, z = rest:match("^%s*(%S+)%s+(%S+)%s+(%S+)")
            x, y, z = tonumber(x), tonumber(y), tonumber(z)
            if z == nil then fail("a vertex needs three numbers") end
            local c = state.corners
            c[#c + 1], c[#c + 2], c[#c + 3] = x, y, z
        end,
        endloop = function()
            local c = state.corners
            if #c ~= 9 then fail("a facet has " .. (#c / 3) .. " corners, not 3") end
            record.add_triangle(state.part, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9])
        end,
        endfacet = function() end,
        endsolid = function()
            if state.part == nil then fail("'endsolid' with no solid open") end
            state.part = nil
        end,
    }
    for text in (bytes .. "\n"):gmatch("([^\n]*)\n") do
        state.line = state.line + 1
        local word, rest = text:match("^%s*(%a+)(.*)$")
        -- a blank line: nothing to do. Any other unknown word: the file is
        -- not STL text, and guessing past it would draw something wrong
        if word ~= nil then
            local handler = handlers[word]
            if handler == nil then fail("unknown word '" .. word .. "'") end
            handler(rest)
        elseif text:match("%S") then
            fail("expected a keyword")
        end
    end
    if state.part ~= nil then fail("file ended inside solid '" .. state.part.name .. "'") end
    return record.finish(shape)
end
-- }}}

-- {{{ function M.read()
-- bytes: the whole file as a string. name: used for the shape and in errors.
function M.read(bytes, name)
    if M.is_binary(bytes) then return read_binary(bytes, name) end
    return read_text(bytes, name)
end
-- }}}

-- {{{ local function to_stl_axes()
-- STL means z is up. A shape whose own up is y (the made shapes, OBJ,
-- glTF) is turned a quarter about x on the way out -- (x, y, z) becomes
-- (x, -z, y) -- so it stands the same way when read back. A turn, not a
-- mirror, so triangles keep facing out. Found when the crown sketch, written
-- as STL without this, came back lying on its side.
-- Returns three numbers from list at position k (k is x's place).
local function to_stl_axes(shape, list, k)
    if shape.up_axis == "y" then return list[k], -list[k + 2], list[k + 1] end
    return list[k], list[k + 1], list[k + 2]
end
-- }}}

-- {{{ function M.write_text()
-- One solid per part, so parts survive a round trip through text STL.
-- `made_by` goes on the first line, after the first solid's name: STL has no
-- comment syntax, so the note rides in that name (and reads back as part of
-- the first part's name; the cost of saying who made the file).
function M.write_text(shape, made_by)
    local out = {}
    for part_index, part in ipairs(shape.parts) do
        local solid_name = part.name
        if part_index == 1 and made_by then solid_name = solid_name .. " -- " .. made_by end
        -- names keep to one line: a newline inside would end the keyword line
        solid_name = solid_name:gsub("\n", " ")
        out[#out + 1] = "solid " .. solid_name
        local p, n = part.positions, part.normals
        for base = 0, #p - 9, 9 do
            out[#out + 1] = string.format("  facet normal %.7g %.7g %.7g", to_stl_axes(shape, n, base + 1))
            out[#out + 1] = "    outer loop"
            for corner = 0, 6, 3 do
                out[#out + 1] = string.format("      vertex %.9g %.9g %.9g", to_stl_axes(shape, p, base + corner + 1))
            end
            out[#out + 1] = "    endloop"
            out[#out + 1] = "  endfacet"
        end
        out[#out + 1] = "endsolid " .. part.name
    end
    return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ function M.write_binary()
-- All parts flatten into one list: binary STL has no parts. The header holds
-- `made_by` (cut to 80 bytes), never starting with "solid", so this file's
-- own output can never be mistaken for text by an older reader.
function M.write_binary(shape, made_by)
    local count = shape.triangle_count
    local size = 84 + 50 * count
    local buffer = ffi.new("uint8_t[?]", size)
    local header = ("binary STL -- " .. (made_by or "")):sub(1, 80)
    ffi.copy(buffer, header, #header)
    ffi.cast("uint32_t *", buffer + 80)[0] = count
    local index = 0
    for _, part in ipairs(shape.parts) do
        local p, n = part.positions, part.normals
        for base = 0, #p - 9, 9 do
            local f = ffi.cast("float *", buffer + 84 + index * 50)
            f[0], f[1], f[2] = to_stl_axes(shape, n, base + 1)
            for corner = 0, 2 do
                f[3 + corner * 3], f[4 + corner * 3], f[5 + corner * 3] = to_stl_axes(shape, p, base + corner * 3 + 1)
            end
            index = index + 1
        end
    end
    return ffi.string(buffer, size)
end
-- }}}

return M
