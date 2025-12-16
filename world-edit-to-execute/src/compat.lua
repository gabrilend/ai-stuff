-- Lua/LuaJIT Compatibility Layer
-- Provides unified bitwise operations and binary unpacking for both
-- Lua 5.3+ (native operators) and LuaJIT (bit library + manual unpacking).

local compat = {}

-- {{{ Detect environment
local is_luajit = type(jit) == "table"
local has_bit = pcall(require, "bit")
local has_unpack = string.unpack ~= nil
-- }}}

-- {{{ Bitwise operations
if has_bit then
    -- LuaJIT or Lua with bit library
    local bit = require("bit")
    compat.band = bit.band
    compat.bor = bit.bor
    compat.bnot = bit.bnot
    compat.bxor = bit.bxor
    compat.lshift = bit.lshift
    compat.rshift = bit.rshift
else
    -- Lua 5.3+ native operators
    -- Use load() to avoid parse errors on LuaJIT
    local code = [[
        return {
            band = function(a, b) return a & b end,
            bor = function(a, b) return a | b end,
            bnot = function(a) return ~a end,
            bxor = function(a, b) return a ~ b end,
            lshift = function(a, n) return a << n end,
            rshift = function(a, n) return a >> n end,
        }
    ]]
    local fn, err = load(code)
    if fn then
        local ops = fn()
        compat.band = ops.band
        compat.bor = ops.bor
        compat.bnot = ops.bnot
        compat.bxor = ops.bxor
        compat.lshift = ops.lshift
        compat.rshift = ops.rshift
    else
        error("No bitwise operations available (need Lua 5.3+ or LuaJIT): " .. tostring(err))
    end
end
-- }}}

-- {{{ Binary unpacking
if has_unpack then
    -- Lua 5.3+ string.unpack
    compat.unpack_int32 = function(data, pos)
        return string.unpack("<i4", data, pos)
    end
    compat.unpack_uint32 = function(data, pos)
        return string.unpack("<I4", data, pos)
    end
    compat.unpack_int16 = function(data, pos)
        return string.unpack("<i2", data, pos)
    end
    compat.unpack_uint16 = function(data, pos)
        return string.unpack("<I2", data, pos)
    end
    compat.unpack_float = function(data, pos)
        return string.unpack("<f", data, pos)
    end
    compat.unpack_double = function(data, pos)
        return string.unpack("<d", data, pos)
    end
else
    -- LuaJIT: use ffi or manual byte manipulation
    local ffi_ok, ffi = pcall(require, "ffi")

    if ffi_ok then
        -- Use FFI for efficient unpacking
        ffi.cdef[[
            typedef struct { int32_t v; } int32_s;
            typedef struct { uint32_t v; } uint32_s;
            typedef struct { int16_t v; } int16_s;
            typedef struct { uint16_t v; } uint16_s;
            typedef struct { float v; } float_s;
            typedef struct { double v; } double_s;
        ]]

        compat.unpack_int32 = function(data, pos)
            pos = pos or 1
            local bytes = data:sub(pos, pos + 3)
            local ptr = ffi.cast("int32_s*", bytes)
            return ptr.v, pos + 4
        end

        compat.unpack_uint32 = function(data, pos)
            pos = pos or 1
            local bytes = data:sub(pos, pos + 3)
            local ptr = ffi.cast("uint32_s*", bytes)
            return ptr.v, pos + 4
        end

        compat.unpack_int16 = function(data, pos)
            pos = pos or 1
            local bytes = data:sub(pos, pos + 1)
            local ptr = ffi.cast("int16_s*", bytes)
            return ptr.v, pos + 2
        end

        compat.unpack_uint16 = function(data, pos)
            pos = pos or 1
            local bytes = data:sub(pos, pos + 1)
            local ptr = ffi.cast("uint16_s*", bytes)
            return ptr.v, pos + 2
        end

        compat.unpack_float = function(data, pos)
            pos = pos or 1
            local bytes = data:sub(pos, pos + 3)
            local ptr = ffi.cast("float_s*", bytes)
            return ptr.v, pos + 4
        end

        compat.unpack_double = function(data, pos)
            pos = pos or 1
            local bytes = data:sub(pos, pos + 7)
            local ptr = ffi.cast("double_s*", bytes)
            return ptr.v, pos + 8
        end
    else
        -- Manual byte manipulation fallback
        local band = compat.band

        local function bytes_to_uint32(b1, b2, b3, b4)
            return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
        end

        local function bytes_to_int32(b1, b2, b3, b4)
            local val = bytes_to_uint32(b1, b2, b3, b4)
            if val >= 2147483648 then
                val = val - 4294967296
            end
            return val
        end

        compat.unpack_uint32 = function(data, pos)
            pos = pos or 1
            local b1, b2, b3, b4 = data:byte(pos, pos + 3)
            return bytes_to_uint32(b1, b2, b3, b4), pos + 4
        end

        compat.unpack_int32 = function(data, pos)
            pos = pos or 1
            local b1, b2, b3, b4 = data:byte(pos, pos + 3)
            return bytes_to_int32(b1, b2, b3, b4), pos + 4
        end

        compat.unpack_uint16 = function(data, pos)
            pos = pos or 1
            local b1, b2 = data:byte(pos, pos + 1)
            return b1 + b2 * 256, pos + 2
        end

        compat.unpack_int16 = function(data, pos)
            pos = pos or 1
            local b1, b2 = data:byte(pos, pos + 1)
            local val = b1 + b2 * 256
            if val >= 32768 then
                val = val - 65536
            end
            return val, pos + 2
        end

        -- Float unpacking - IEEE 754 single-precision decoder
        compat.unpack_float = function(data, pos)
            pos = pos or 1
            local b1, b2, b3, b4 = data:byte(pos, pos + 3)

            -- Little-endian: b4 is MSB
            local sign = (b4 >= 128) and -1 or 1
            local exp = band(b4, 127) * 2 + math.floor(b3 / 128)
            local mantissa = band(b3, 127) * 65536 + b2 * 256 + b1

            if exp == 0 then
                if mantissa == 0 then
                    return sign * 0, pos + 4
                else
                    -- Denormalized
                    return sign * math.ldexp(mantissa / 8388608, -126), pos + 4
                end
            elseif exp == 255 then
                if mantissa == 0 then
                    return sign * math.huge, pos + 4
                else
                    return 0/0, pos + 4  -- NaN
                end
            end

            return sign * math.ldexp(1 + mantissa / 8388608, exp - 127), pos + 4
        end

        -- Double unpacking
        compat.unpack_double = function(data, pos)
            pos = pos or 1
            local b1, b2, b3, b4, b5, b6, b7, b8 = data:byte(pos, pos + 7)

            local sign = (b8 >= 128) and -1 or 1
            local exp = band(b8, 127) * 16 + math.floor(b7 / 16)
            local mantissa = band(b7, 15) * 281474976710656 +
                            b6 * 1099511627776 + b5 * 4294967296 +
                            b4 * 16777216 + b3 * 65536 + b2 * 256 + b1

            if exp == 0 then
                if mantissa == 0 then
                    return sign * 0, pos + 8
                else
                    return sign * math.ldexp(mantissa / 4503599627370496, -1022), pos + 8
                end
            elseif exp == 2047 then
                if mantissa == 0 then
                    return sign * math.huge, pos + 8
                else
                    return 0/0, pos + 8
                end
            end

            return sign * math.ldexp(1 + mantissa / 4503599627370496, exp - 1023), pos + 8
        end
    end
end
-- }}}

-- {{{ Info
compat.info = {
    is_luajit = is_luajit,
    has_bit = has_bit,
    has_unpack = has_unpack,
    lua_version = _VERSION,
}
-- }}}

return compat
