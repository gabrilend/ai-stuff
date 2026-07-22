-- 003-cassette-tone-viewer.lua
--
-- Story index 003 of the experimental cassette branch (issue 905, Phase 9).
-- WHAT it does: DATA VIEWING. Shows a human what the encoder (001) produced —
-- either as a readable symbol strip, or as a real listenable .wav "cassette."
-- WHY it is its own module: the project separates generation from viewing so a
-- display tweak can never perturb the data. This file READS samples; it must never
-- decode them back to bytes (that is the decoder's job, 002) — the wall is the
-- whole point, and it is commented at the one place it could be crossed.

local bit = require("bit")   -- LuaJIT BitOp; used to emit little-endian WAV bytes
local desc_mod

local M = {}

-- {{{ local function descriptor_module()
local function descriptor_module()
   if not desc_mod then
      desc_mod = require("000-cassette-encoding-descriptor")
   end
   return desc_mod
end
-- }}}

-- {{{ local function le16(v)
-- Emit a 16-bit little-endian unsigned value as two bytes. Hand-rolled because
-- LuaJIT is Lua 5.1 and has no string.pack.
local function le16(v)
   v = bit.band(v, 0xFFFF)
   return string.char(bit.band(v, 0xFF), bit.band(bit.rshift(v, 8), 0xFF))
end
-- }}}

-- {{{ local function le32(v)
local function le32(v)
   return string.char(bit.band(v, 0xFF),
                      bit.band(bit.rshift(v, 8),  0xFF),
                      bit.band(bit.rshift(v, 16), 0xFF),
                      bit.band(bit.rshift(v, 24), 0xFF))
end
-- }}}

-- {{{ local function sample_to_int16(x)
-- Float in [-1,1] -> signed 16-bit, clamped. WHY clamp: a descriptor amplitude of
-- 1.0 plus rounding could nudge past the int16 range; clamping keeps the WAV legal
-- rather than wrapping a sample to a loud click.
local function sample_to_int16(x)
   local v = math.floor(x * 32767 + 0.5)
   if v > 32767 then v = 32767 end       -- ceiling: avoid positive overflow
   if v < -32768 then v = -32768 end     -- floor: avoid negative overflow
   return v
end
-- }}}

-- {{{ function M.render_symbols(desc, samples)
-- A readable strip of what the tones say, one glyph per bit-window: '.' for a
-- space bit, '#' for a mark bit. This is VIEWING, not decoding — it reports the
-- per-window tone, and deliberately does NOT reassemble bytes or check framing.
-- (If you find yourself wanting bytes here, call the decoder instead; do not cross
--  the wall.)
function M.render_symbols(desc, samples)
   local descM = descriptor_module()
   descM.validate(desc)
   local spb = descM.samples_per_bit(desc)
   if #samples % spb ~= 0 then
      error("cassette viewer: sample count is not a whole number of bit-windows")
   end
   local glyphs = {}
   local pos = 1
   while pos <= #samples do
      -- Reuse the same nearest-count idea the decoder uses, but only to draw a
      -- glyph — never to emit data.
      local crossings = 0
      local prev = samples[pos]
      for k = 1, spb - 1 do
         local cur = samples[pos + k]
         if (prev < 0) ~= (cur < 0) then crossings = crossings + 1 end
         prev = cur
      end
      local space_dist = math.abs(crossings - descM.expected_crossings(desc, descM.SPACE))
      local mark_dist  = math.abs(crossings - descM.expected_crossings(desc, descM.MARK))
      glyphs[#glyphs + 1] = (mark_dist < space_dist) and "#" or "."
      pos = pos + spb
   end
   return table.concat(glyphs)
end
-- }}}

-- {{{ function M.summarise(desc, message, samples)
-- A one-block human report: what went in, how long the tape got. Numbers are
-- computed live from the descriptor and the arrays, never hardcoded.
function M.summarise(desc, message, samples)
   local descM = descriptor_module()
   descM.validate(desc)
   local seconds = #samples / desc.sample_rate
   local lines = {
      "cassette experiment — encode summary",
      "  message bytes    : " .. #message,
      "  scheme           : " .. desc.mark_freq .. "Hz mark / "
                                .. desc.space_freq .. "Hz space @ " .. desc.baud .. " baud",
      "  sample rate      : " .. desc.sample_rate .. " Hz",
      "  samples produced : " .. #samples,
      "  tape length      : " .. string.format("%.3f", seconds) .. " s",
      "  slice budget     : " .. desc.slice_budget_bytes .. " bytes (pico-8-sized; honest scope)",
   }
   return table.concat(lines, "\n")
end
-- }}}

-- {{{ function M.write_wav(desc, samples, path)
-- Export the tones to a real 16-bit PCM mono WAV — the listenable "cassette."
-- Still VIEWING: it turns generated samples into a file a human can play; it does
-- not read meaning back out.
function M.write_wav(desc, samples, path)
   descriptor_module().validate(desc)
   local data_bytes = {}
   for i = 1, #samples do
      data_bytes[i] = le16(sample_to_int16(samples[i]))
   end
   local data = table.concat(data_bytes)
   local data_size = #data

   -- Canonical 44-byte PCM WAV header (fields are a hard format fact; kept here).
   local header = table.concat({
      "RIFF", le32(36 + data_size), "WAVE",
      "fmt ", le32(16), le16(1), le16(1),          -- PCM, mono
      le32(desc.sample_rate),                       -- sample rate
      le32(desc.sample_rate * 2),                   -- byte rate (mono, 2 bytes/sample)
      le16(2), le16(16),                            -- block align, bits per sample
      "data", le32(data_size),
   })

   local f, err = io.open(path, "wb")
   if not f then
      -- No fallback to a temp path or a swallowed failure — say exactly why.
      error("cassette viewer: cannot open '" .. path .. "' for writing: " .. tostring(err))
   end
   f:write(header)
   f:write(data)
   f:close()
   return path
end
-- }}}

return M
