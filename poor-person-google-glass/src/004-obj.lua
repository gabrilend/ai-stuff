-- 004-obj.lua - reads and writes OBJ, the plain-text model format.
--
-- In plain terms: an OBJ file is a list of lines, each starting with a short
-- word saying what it is: "v" a corner, "vn" a direction, "f" a face made of
-- corner numbers, "o" or "g" the start of a named part, "usemtl" a colour by
-- name, looked up in a separate ".mtl" file. This file turns those lines into
-- a shape record (001) and writes one back.
--
-- Corner numbers in a face count from 1 in the order corners appeared in the
-- whole file (not per part), or from -1 counting back from the latest. A face
-- token is "v", "v/vt", "v//vn" or "v/vt/vn"; texture coordinates (vt) are
-- not used here. A face of more than three corners is cut into a fan of
-- triangles from its first corner, which is right for the flat convex faces
-- CAD exporters write.
--
-- Parts: one per (group name, material) pair, made the first time a face
-- lands in it, so "o" lines with no faces do not leave empty parts behind.
-- OBJ's convention is y up.

local record = require("001-the-shape-record")

local M = {}

-- {{{ function M.read_materials()
-- The .mtl text into { name = {r,g,b} }. Only "newmtl" and "Kd" (diffuse
-- colour) matter for drawing; other lines are skipped.
function M.read_materials(bytes, name)
    local materials, current, line = {}, nil, 0
    for text in (bytes .. "\n"):gmatch("([^\n]*)\n") do
        line = line + 1
        local word, rest = text:match("^%s*(%S+)%s*(.-)%s*$")
        if word == "newmtl" then
            current = rest
            materials[current] = { 0.72, 0.74, 0.78 }
        elseif word == "Kd" then
            -- a colour before any "newmtl" belongs to nothing: a broken file
            if current == nil then error(name .. ": line " .. line .. ": Kd before newmtl", 0) end
            local r, g, b = rest:match("^(%S+)%s+(%S+)%s+(%S+)")
            r, g, b = tonumber(r), tonumber(g), tonumber(b)
            if b == nil then error(name .. ": line " .. line .. ": Kd needs three numbers", 0) end
            materials[current] = { r, g, b }
        end
        -- any other word (Ka, Ks, Ns, map_Kd, comments): not used for drawing
    end
    return materials
end
-- }}}

-- {{{ function M.read()
-- bytes: the .obj text. name: for the shape and errors. read_neighbour: a
-- function(file_name) returning the bytes of a file beside this one (for
-- mtllib); it raises if the file is missing. Kept as a function passed in so
-- this reader never touches a filesystem (LÖVE and plain Lua differ there).
function M.read(bytes, name, read_neighbour)
    local shape = record.new(name, "obj", "y")
    shape.skipped = {}
    local corners, directions = {}, {}
    local materials = {}
    local group, material = name, nil
    local parts_by_key = {}
    local line = 0
    local function fail(message) error(name .. ": line " .. line .. ": " .. message, 0) end

    -- {{{ local function current_part()
    local function current_part()
        local key = group .. "\0" .. (material or "")
        local part = parts_by_key[key]
        if part == nil then
            local colour = nil
            if material ~= nil then
                colour = materials[material]
                -- a face uses a material no library defined: the colour the
                -- author chose is unknown, and a guessed grey would hide that
                if colour == nil then fail("material '" .. material .. "' is not in any loaded library") end
            end
            local part_name = material and (group .. " (" .. material .. ")") or group
            part = record.add_part(shape, part_name, colour)
            part.every_face_had_normals = true
            parts_by_key[key] = part
        end
        return part
    end
    -- }}}

    -- {{{ local function resolve()
    -- A corner number in a face to a list position, counting back for
    -- negatives; out of range is an error naming the number.
    local function resolve(text, count, what)
        local number = tonumber(text)
        if number == nil then fail("'" .. text .. "' is not a " .. what .. " number") end
        if number < 0 then number = count + 1 + number end
        if number < 1 or number > count then fail(what .. " " .. text .. " does not exist (" .. count .. " so far)") end
        return number
    end
    -- }}}

    local handlers = {
        v = function(rest)
            local x, y, z = rest:match("^(%S+)%s+(%S+)%s+(%S+)")
            x, y, z = tonumber(x), tonumber(y), tonumber(z)
            if z == nil then fail("a corner needs three numbers") end
            corners[#corners + 1] = { x, y, z }
        end,
        vn = function(rest)
            local x, y, z = rest:match("^(%S+)%s+(%S+)%s+(%S+)")
            x, y, z = tonumber(x), tonumber(y), tonumber(z)
            if z == nil then fail("a direction needs three numbers") end
            directions[#directions + 1] = { x, y, z }
        end,
        f = function(rest)
            local face, face_directions = {}, {}
            for token in rest:gmatch("%S+") do
                local v, n = token:match("^([^/]+)/?[^/]*/?(.*)$")
                face[#face + 1] = corners[resolve(v, #corners, "corner")]
                face_directions[#face_directions + 1] = (n ~= nil and n ~= "") and directions[resolve(n, #directions, "direction")] or false
            end
            if #face < 3 then fail("a face needs at least three corners") end
            local part = current_part()
            for k = 2, #face - 1 do
                local a, b, c = face[1], face[k], face[k + 1]
                local na, nb, nc = face_directions[1], face_directions[k], face_directions[k + 1]
                -- directions are kept only while every corner of every face
                -- in the part had one; one face without them and the whole
                -- part falls back to computed flat facets (finish(), below)
                if na and nb and nc and part.every_face_had_normals then
                    record.add_triangle(part, a[1], a[2], a[3], b[1], b[2], b[3], c[1], c[2], c[3],
                        { na[1], na[2], na[3], nb[1], nb[2], nb[3], nc[1], nc[2], nc[3] })
                else
                    part.every_face_had_normals = false
                    record.add_triangle(part, a[1], a[2], a[3], b[1], b[2], b[3], c[1], c[2], c[3])
                end
            end
        end,
        o = function(rest) group = (rest ~= "") and rest or name end,
        g = function(rest) group = (rest ~= "") and rest or name end,
        usemtl = function(rest) material = rest end,
        mtllib = function(rest)
            for file_name in rest:gmatch("%S+") do
                for key, colour in pairs(M.read_materials(read_neighbour(file_name), file_name)) do
                    materials[key] = colour
                end
            end
        end,
    }

    for text in (bytes .. "\n"):gmatch("([^\n]*)\n") do
        line = line + 1
        local word, rest = text:match("^%s*([^%s#]+)%s*(.-)%s*$")
        -- blank lines and comments: word is nil
        if word ~= nil then
            local handler = handlers[word]
            -- words this viewer has no use for (vt, s, l, cstype...) are
            -- counted, so a file made mostly of unread statements shows it
            if handler == nil then
                shape.skipped[word] = (shape.skipped[word] or 0) + 1
            else
                handler(rest)
            end
        end
    end

    -- a part that lost some directions loses them all: flat facets throughout
    for _, part in ipairs(shape.parts) do
        if not part.every_face_had_normals then part.normals = {} end
        part.every_face_had_normals = nil
    end
    return record.finish(shape)
end
-- }}}

-- {{{ function M.write()
-- Returns the .obj text and the .mtl text. Each part gets its own "o" and
-- material, named after it, so names and colours survive a round trip.
function M.write(shape, made_by, mtl_file_name)
    local obj = { "# " .. (made_by or "written by 004-obj.lua"), "mtllib " .. mtl_file_name }
    local mtl = { "# " .. (made_by or "written by 004-obj.lua") }
    local written = 0
    for index, part in ipairs(shape.parts) do
        local material = "material-" .. index
        mtl[#mtl + 1] = "newmtl " .. material
        mtl[#mtl + 1] = string.format("Kd %.4f %.4f %.4f", part.colour[1], part.colour[2], part.colour[3])
        obj[#obj + 1] = "o " .. part.name
        obj[#obj + 1] = "usemtl " .. material
        local p, n = part.positions, part.normals
        for k = 1, #p, 3 do obj[#obj + 1] = string.format("v %.9g %.9g %.9g", p[k], p[k + 1], p[k + 2]) end
        for k = 1, #n, 3 do obj[#obj + 1] = string.format("vn %.7g %.7g %.7g", n[k], n[k + 1], n[k + 2]) end
        for t = 1, #p / 9 do
            local a, b, c = written + 3 * t - 2, written + 3 * t - 1, written + 3 * t
            obj[#obj + 1] = string.format("f %d//%d %d//%d %d//%d", a, a, b, b, c, c)
        end
        written = written + #p / 3
    end
    return table.concat(obj, "\n") .. "\n", table.concat(mtl, "\n") .. "\n"
end
-- }}}

return M
