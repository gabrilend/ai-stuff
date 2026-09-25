#!/usr/bin/env luajit
-- pose-types.lua - writes the benchmark's value types as named fields
--
-- In plain terms: the ceramic engine's value types can't hold arrays of
-- numbers (only text), so a 4x4 matrix has to be sixteen named floats, a
-- pose thirty named matrices, a chunk sixty-four named poses. Nobody should
-- type that by hand; this prints it, and the build splices it into the box
-- file where the marker stands.
--
-- Usage: luajit pose-types.lua > types.c   (bone and chunk counts below)

local BONES, CHUNK = 30, 64

-- {{{ local function fields
-- A typedef of `n` fields of one type, named prefix0 .. prefix(n-1).
local function fields(name, field_type, prefix, n, comment)
    local out = { "/* " .. comment .. " */", "typedef struct {" }
    for i = 0, n - 1 do out[#out + 1] = string.format("    %s %s%d;", field_type, prefix, i) end
    out[#out + 1] = "} " .. name .. ";"
    return table.concat(out, "\n")
end
-- }}}

print(fields("mat4", "float", "m", 16, "One 4x4 matrix, column-major: 16 floats, 64 bytes."))
print()
print(fields("pose", "mat4", "b", BONES, "One unit's pose: " .. BONES .. " bone matrices, root first, " .. BONES * 64 .. " bytes."))
print()
print(fields("chunk_pose", "pose", "u", CHUNK, CHUNK .. " units' poses, " .. CHUNK * BONES * 64 .. " bytes."))
