-- 005-cassette-wav-reader.lua
--
-- Story index 005 of the experimental cassette branch (issue 905, Phase 9).
-- WHAT it does: reads a 16-bit PCM mono WAV file back into a float sample array,
-- so the round-trip can go all the way to a file on disk and home again:
--   bytes --001--> samples --003.write_wav--> a .wav FILE --005.read--> samples
--         --002.decode--> bytes.
-- WHY it exists: FINDINGS listed "no WAV reader — we export but decode from the
-- in-memory array" as the first gap. This closes it, so the listenable cassette a
-- human could actually hand around is provably the same bytes when read back.
--
-- It is the file-input inverse of the viewer's file-output (003.write_wav). It is
-- kept separate from the decoder (002): reading a container format is a different
-- job from demodulating tones, and mixing them would blur two concerns.

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

-- {{{ local function u16le(s, pos)
-- Read a 16-bit little-endian unsigned value at 1-based byte offset pos.
local function u16le(s, pos)
   local b0, b1 = s:byte(pos, pos + 1)
   return b0 + b1 * 256
end
-- }}}

-- {{{ local function u32le(s, pos)
local function u32le(s, pos)
   local b0, b1, b2, b3 = s:byte(pos, pos + 3)
   return b0 + b1 * 256 + b2 * 65536 + b3 * 16777216
end
-- }}}

-- {{{ local function read_whole_file(path)
local function read_whole_file(path)
   local f, err = io.open(path, "rb")
   if not f then
      -- No fallback to an empty stream — a missing/unreadable tape is a fact.
      error("cassette wav reader: cannot open '" .. path .. "': " .. tostring(err))
   end
   local bytes = f:read("*a")
   f:close()
   return bytes
end
-- }}}

-- {{{ function M.read(desc, path)
-- Read a WAV file into a float sample array in [-1, 1]. Validates that the file is
-- the exact shape this branch writes (RIFF/WAVE, PCM, mono, 16-bit, and the
-- descriptor's sample rate); every mismatch is a loud error, never a quiet coercion,
-- because a wrong-rate read would silently misalign every bit-window.
function M.read(desc, path)
   descriptor_module().validate(desc)
   local s = read_whole_file(path)
   if #s < 44 then
      error("cassette wav reader: '" .. path .. "' is too small to be a WAV")
   end
   if s:sub(1, 4) ~= "RIFF" or s:sub(9, 12) ~= "WAVE" then
      error("cassette wav reader: '" .. path .. "' is not a RIFF/WAVE file")
   end

   local have_fmt, have_data = false, false
   local samples = {}
   local pos = 13   -- first chunk id begins right after "WAVE"

   while pos + 8 <= #s + 1 do
      local chunk_id   = s:sub(pos, pos + 3)
      local chunk_size = u32le(s, pos + 4)
      local body       = pos + 8

      if chunk_id == "fmt " then
         -- The three checks below are why decoding stays exact: a stereo, 8-bit, or
         -- wrong-rate file would misread as noise, so we refuse it by name.
         local audio_format   = u16le(s, body)
         local channels       = u16le(s, body + 2)
         local sample_rate    = u32le(s, body + 4)
         local bits_per_sample = u16le(s, body + 14)
         if audio_format ~= 1 then
            error("cassette wav reader: not PCM (audio format " .. audio_format .. ")")
         end
         if channels ~= 1 then
            error("cassette wav reader: expected mono, got " .. channels .. " channels")
         end
         if bits_per_sample ~= 16 then
            error("cassette wav reader: expected 16-bit, got " .. bits_per_sample .. "-bit")
         end
         if sample_rate ~= desc.sample_rate then
            error("cassette wav reader: sample rate " .. sample_rate
                  .. " does not match descriptor " .. desc.sample_rate)
         end
         have_fmt = true

      elseif chunk_id == "data" then
         -- Each sample is a signed 16-bit little-endian value; invert the writer's
         -- v = round(x * 32767) by dividing back by 32767.
         local n = math.floor(chunk_size / 2)
         for i = 0, n - 1 do
            local raw = u16le(s, body + i * 2)
            if raw >= 32768 then raw = raw - 65536 end   -- two's-complement sign
            samples[i + 1] = raw / 32767
         end
         have_data = true
      end

      -- Advance past this chunk. WAV chunks are word-aligned: an odd size carries a
      -- pad byte the next chunk must skip.
      pos = body + chunk_size + (chunk_size % 2)
   end

   if not have_fmt then
      error("cassette wav reader: '" .. path .. "' has no fmt chunk")
   end
   if not have_data then
      error("cassette wav reader: '" .. path .. "' has no data chunk")
   end
   return samples
end
-- }}}

return M
