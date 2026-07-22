-- 001-cassette-tone-encoder.lua
--
-- Story index 001 of the experimental cassette branch (issue 905, Phase 9).
-- WHAT it does: DATA GENERATION. Turns a slice of bytes into a stream of audio
-- samples — the "binary sounds" a cassette would carry. It reads the format from
-- the descriptor (000); it never decides the format itself, and it never views or
-- decodes. Pure: same bytes + same descriptor -> same samples, every time.
--
-- This is the "generate" side of the project's generate/view wall. The decoder
-- (002) is the inverse; the viewer/exporter (003) is how a human sees or hears
-- what this produced. Keeping them apart is what lets a bug stay in one small room.

local bit  = require("bit")   -- LuaJIT BitOp; native 5.3 bit operators are banned
local desc_mod                -- filled by set_descriptor_module / lazy require below

local M = {}

-- The encoder needs the descriptor module's symbol constants. We resolve it once,
-- relative to this file, so the module works no matter which directory launched it.
-- WHY lazy + path-relative: honours the project's "runnable from any directory"
-- rule without forcing every caller to pre-configure package.path.
-- {{{ local function descriptor_module()
local function descriptor_module()
   if not desc_mod then
      desc_mod = require("000-cassette-encoding-descriptor")
   end
   return desc_mod
end
-- }}}

-- {{{ local function frame_bits(D, message)
-- Turn a byte string into the full flat bit stream: leader, then one UART-style
-- frame per byte. WHY LSB-first with start/stop bits: it mirrors a real serial
-- character, so this is a documented format a decoder can trust, not an ad-hoc one.
local function frame_bits(D, message)
   -- Symbol constants (MARK/START/STOP) live on the descriptor MODULE, the single
   -- source of truth — not on the descriptor table D. Fetch them here so the
   -- leader and framing bits are real symbols, never nil. (bug fix: an earlier
   -- draft read D.MARK/D.START/D.STOP, which are nil, and the round-trip test in
   -- 004 caught it — the reason that test exists.)
   local descM = descriptor_module()
   local bits = {}
   local n = 0
   -- Leader: a run of mark bits so the decoder can lock on before real data.
   for _ = 1, D.leader_bits do
      n = n + 1
      bits[n] = descM.MARK
   end
   for i = 1, #message do
      local byte = string.byte(message, i)
      n = n + 1; bits[n] = descM.START           -- start bit (space)
      for b = 0, 7 do                            -- 8 data bits, least-significant first
         n = n + 1
         bits[n] = bit.band(bit.rshift(byte, b), 1)
      end
      n = n + 1; bits[n] = descM.STOP            -- stop bit (mark)
   end
   return bits
end
-- }}}

-- {{{ local function bits_to_samples(D, bits)
-- Synthesise the audio: each bit becomes one bit-window of a pure sine at that
-- symbol's frequency. WHY each burst starts at phase 0: the frequency is a whole
-- multiple of the baud rate, so a burst is a whole number of cycles and the next
-- bit also begins cleanly at zero — no phase drift, so zero-crossing decoding is
-- exact later.
local function bits_to_samples(D, bits)
   local descM        = descriptor_module()
   local spb          = descM.samples_per_bit(D)   -- integer by the invariant
   local two_pi_over  = 2 * math.pi / D.sample_rate
   local amp          = D.amplitude
   local samples      = {}
   local s            = 0
   for i = 1, #bits do
      -- Index the tone by the bit symbol (dispatch table), never branch on it.
      local freq = D.symbol_freq[bits[i]]
      for k = 0, spb - 1 do
         s = s + 1
         samples[s] = amp * math.sin(two_pi_over * freq * k)
      end
   end
   return samples
end
-- }}}

-- {{{ function M.frame_bits(desc, message)
-- Exposed for the viewer and tests: the bit stream without the audio, so a reader
-- can inspect framing directly. Validates the descriptor first (errors, no fallback).
function M.frame_bits(desc, message)
   if type(message) ~= "string" then
      error("cassette encoder: message must be a byte string (got " .. type(message) .. ")")
   end
   local descM = descriptor_module()
   descM.validate(desc)
   return frame_bits(desc, message)
end
-- }}}

-- {{{ function M.encode(desc, message)
-- The one door of this module: bytes in, audio samples out (floats in [-amp, amp]).
-- Returns the sample array. Pure and side-effect-free.
function M.encode(desc, message)
   if type(message) ~= "string" then
      error("cassette encoder: message must be a byte string (got " .. type(message) .. ")")
   end
   local descM = descriptor_module()
   descM.validate(desc)
   local bits = frame_bits(desc, message)
   return bits_to_samples(desc, bits)
end
-- }}}

return M
