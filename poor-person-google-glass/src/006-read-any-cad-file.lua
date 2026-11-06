-- 006-read-any-cad-file.lua - one door for every CAD format.
--
-- In plain terms: given a file's path, look at its ending, hand its bytes to
-- the reader for that format, and give back a shape record (001). Files the
-- format needs from beside it (an OBJ's colour library, a glTF's .bin) are
-- read from the same folder. An ending with no reader is an error that lists
-- the endings that do have one.

local stl = require("003-stl")
local obj = require("004-obj")
local gltf = require("005-gltf")

local M = {}

-- {{{ function M.read_bytes()
-- A whole file as a string; raises naming the path if it cannot be opened.
function M.read_bytes(path)
    local file, problem = io.open(path, "rb")
    if file == nil then error("cannot open " .. path .. ": " .. tostring(problem), 0) end
    local bytes = file:read("*a")
    file:close()
    return bytes
end
-- }}}

-- Each ending to the reader that takes it. Every reader takes (bytes, name,
-- read_neighbour); STL ignores the third, having no companion files.
M.READERS = {
    stl = stl.read,
    obj = obj.read,
    gltf = gltf.read,
    glb = gltf.read,
}

-- {{{ function M.endings()
-- The endings with a reader, sorted, for messages and for the viewer's help.
function M.endings()
    local list = {}
    for ending in pairs(M.READERS) do list[#list + 1] = ending end
    table.sort(list)
    return list
end
-- }}}

-- {{{ function M.read()
-- path (string) -> shape, seconds spent reading (number).
function M.read(path)
    local folder, file_name = path:match("^(.-)([^/]*)$")
    local ending = (file_name:match("%.([^.]+)$") or ""):lower()
    local reader = M.READERS[ending]
    if reader == nil then
        error(file_name .. ": no reader for '." .. ending .. "' files (readable: ."
            .. table.concat(M.endings(), ", .") .. ")", 0)
    end
    local started = os.clock()
    local bytes = M.read_bytes(path)
    local shape = reader(bytes, file_name, function(neighbour)
        return M.read_bytes(folder .. neighbour)
    end)
    shape.path = path
    shape.bytes_on_disk = #bytes
    return shape, os.clock() - started
end
-- }}}

return M
