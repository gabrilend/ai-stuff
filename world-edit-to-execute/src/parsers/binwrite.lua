--[[
Little-Endian Writing (Issue 911a)

The other side of compat's unpack_*: a buffer that collects values in
the byte order WC3's files use, for the editor to write maps back.

    local bw = require("parsers.binwrite")
    local b = bw.new()
    b:str("W3E!"); b:i32(11); b:f32(-3.5); b:u16(8192); b:i16(-2); b:u8(4)
    local bytes = b:done()
]]

local ffi = require("ffi")

local bw = {}

local B = {}
B.__index = B

local cell = ffi.new("union { int32_t i; uint32_t u; float f; int16_t s; uint16_t us; uint8_t b[4]; }")

function bw.new()
    return setmetatable({ parts = {} }, B)
end

function B:str(s) self.parts[#self.parts + 1] = s return self end
function B:u8(v) self.parts[#self.parts + 1] = string.char(v % 256) return self end
local function four(self)
    self.parts[#self.parts + 1] = string.char(cell.b[0], cell.b[1], cell.b[2], cell.b[3])
    return self
end
local function two(self)
    self.parts[#self.parts + 1] = string.char(cell.b[0], cell.b[1])
    return self
end
function B:i32(v) cell.i = v return four(self) end
function B:u32(v) cell.u = v return four(self) end
function B:f32(v) cell.f = v return four(self) end
function B:i16(v) cell.s = v return two(self) end
function B:u16(v) cell.us = v return two(self) end
-- a zero-terminated string
function B:cstr(s) self.parts[#self.parts + 1] = (s or "") .. "\0" return self end
function B:done() return table.concat(self.parts) end

return bw
