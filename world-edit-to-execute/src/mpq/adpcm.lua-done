--[[
adpcm.lua - MPQ ADPCM decompression (compression bytes 0x40 mono, 0x80 stereo)

Blizzard compresses WAVE sound with a lossy IMA-ADPCM variant: each 16-bit
sample is stored as a small code saying how far to step from the previous
sample, with a step size that grows and shrinks as the sound gets louder or
quieter. Two codes are special: 0x80 repeats the previous sample and shrinks
the step, 0x81 grows the step by 8 without producing a sample. Warcraft III
usually applies Huffman on top (see huffman.lua); decompression undoes
Huffman first, then this.

Ported to Lua from StormLib's adpcm.cpp (decompression only):
  Copyright (c) Ladislav Zezula 2003, after sources released by Tom Amigo.
  StormLib is released under the MIT licence; its licence text is kept in
  deps/licenses/stormlib/LICENSE when built by scripts/build-dependencies.sh.

Usage:
  local adpcm = require("mpq.adpcm")
  local bytes, err = adpcm.decompress(data, expected_length, channel_count)  -- 1 or 2

Issue: issues/completed/113-remaining-mpq-compressions.md
]]

local compat = require("compat")
local band, rshift = compat.band, compat.rshift

local M = {}

local INITIAL_STEP_INDEX = 0x2C
local MAX_STEP_INDEX = 88

-- {{{ tables
-- Indexed from 0, as in the C source.
local NEXT_STEP = {}
do
    local values = {
        -1, 0, -1, 4, -1, 2, -1, 6,
        -1, 1, -1, 5, -1, 3, -1, 7,
        -1, 1, -1, 5, -1, 3, -1, 7,
        -1, 2, -1, 4, -1, 6, -1, 8,
    }
    for i = 1, #values do NEXT_STEP[i - 1] = values[i] end
end

local STEP_SIZE = {}
do
    local values = {
            7,     8,     9,    10,     11,    12,    13,    14,
           16,    17,    19,    21,     23,    25,    28,    31,
           34,    37,    41,    45,     50,    55,    60,    66,
           73,    80,    88,    97,    107,   118,   130,   143,
          157,   173,   190,   209,    230,   253,   279,   307,
          337,   371,   408,   449,    494,   544,   598,   658,
          724,   796,   876,   963,   1060,  1166,  1282,  1411,
         1552,  1707,  1878,  2066,   2272,  2499,  2749,  3024,
         3327,  3660,  4026,  4428,   4871,  5358,  5894,  6484,
         7132,  7845,  8630,  9493,  10442, 11487, 12635, 13899,
        15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794,
        32767,
    }
    for i = 1, #values do STEP_SIZE[i - 1] = values[i] end
end
M.STEP_SIZE = STEP_SIZE  -- exposed so the tables can be checked against the reference source
M.NEXT_STEP = NEXT_STEP
-- }}}

-- {{{ local function next_step_index
local function next_step_index(step_index, code)
    step_index = step_index + NEXT_STEP[band(code, 0x1F)]
    if step_index < 0 then
        return 0
    elseif step_index > MAX_STEP_INDEX then
        return MAX_STEP_INDEX
    end
    return step_index
end
-- }}}

-- {{{ local function decode_sample
-- Adds up the step-size fractions the code's low six bits select, then moves
-- the predicted sample up or down (bit 0x40 is the sign), clamped to 16 bits.
local function decode_sample(predicted, code, step_size, difference)
    if band(code, 0x01) ~= 0 then difference = difference + step_size end
    if band(code, 0x02) ~= 0 then difference = difference + rshift(step_size, 1) end
    if band(code, 0x04) ~= 0 then difference = difference + rshift(step_size, 2) end
    if band(code, 0x08) ~= 0 then difference = difference + rshift(step_size, 3) end
    if band(code, 0x10) ~= 0 then difference = difference + rshift(step_size, 4) end
    if band(code, 0x20) ~= 0 then difference = difference + rshift(step_size, 5) end

    if band(code, 0x40) ~= 0 then
        predicted = predicted - difference
        if predicted <= -32768 then predicted = -32768 end
    else
        predicted = predicted + difference
        if predicted >= 32767 then predicted = 32767 end
    end
    return predicted
end
-- }}}

-- {{{ function M.decompress
-- data: the compressed bytes (after the MPQ compression byte, and after any
-- Huffman layer has been undone). expected_length: the most bytes to produce.
-- channel_count: 1 (mono) or 2 (stereo).
-- Returns 16-bit little-endian samples as a string, or nil and an error.
function M.decompress(data, expected_length, channel_count)
    if channel_count ~= 1 and channel_count ~= 2 then
        return nil, "ADPCM: channel count must be 1 or 2"
    end
    if #data < 2 then
        return nil, "ADPCM: input shorter than its 2-byte header"
    end
    -- Byte 1 is always zero; byte 2 is the bit shift (compression level - 1).
    local bit_shift = data:byte(2)
    local pos = 3

    local out, n = {}, 0
    -- {{{ local function write_sample
    local function write_sample(sample)
        if n + 2 > expected_length then
            return false
        end
        local u = sample % 65536
        out[n + 1] = u % 256
        out[n + 2] = (u - u % 256) / 256
        n = n + 2
        return true
    end
    -- }}}

    local predicted = { [0] = 0, [1] = 0 }
    local step_index = { [0] = INITIAL_STEP_INDEX, [1] = INITIAL_STEP_INDEX }

    local finished = false
    for channel = 0, channel_count - 1 do
        if pos + 1 > #data then
            finished = true
            break
        end
        local sample = data:byte(pos) + data:byte(pos + 1) * 256
        if sample >= 32768 then sample = sample - 65536 end
        pos = pos + 2
        predicted[channel] = sample
        if not write_sample(sample) then
            finished = true
            break
        end
    end

    local channel = channel_count - 1
    while not finished and pos <= #data do
        local code = data:byte(pos)
        pos = pos + 1
        channel = (channel + 1) % channel_count

        if code == 0x80 then
            if step_index[channel] ~= 0 then
                step_index[channel] = step_index[channel] - 1
            end
            if not write_sample(predicted[channel]) then
                break
            end
        elseif code == 0x81 then
            step_index[channel] = step_index[channel] + 8
            if step_index[channel] > MAX_STEP_INDEX then
                step_index[channel] = MAX_STEP_INDEX
            end
            -- The next code applies to the same channel again.
            channel = (channel + 1) % channel_count
        else
            local index = step_index[channel]
            local step_size = STEP_SIZE[index]
            predicted[channel] = decode_sample(predicted[channel], code, step_size,
                rshift(step_size, bit_shift))
            if not write_sample(predicted[channel]) then
                break
            end
            step_index[channel] = next_step_index(index, code)
        end
    end

    if n == 0 then
        return nil, "ADPCM: produced no data"
    end
    local unpack = unpack or table.unpack
    local parts = {}
    for i = 1, n, 4096 do
        parts[#parts + 1] = string.char(unpack(out, i, math.min(i + 4095, n)))
    end
    return table.concat(parts)
end
-- }}}

return M
