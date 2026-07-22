-- 002-cassette-tone-decoder.lua
--
-- Story index 002 of the experimental cassette branch (issue 905, Phase 9).
-- WHAT it does: the INVERSE of the encoder (001). Reads a stream of audio samples
-- back into the bytes that made them. This is the other half of the round-trip
-- issue 905 asks us to prove in software before any tape or Game Boy exists.
--
-- HOW it recovers a bit (recorded here because it is the subtle part): each bit is
-- one bit-window of samples holding a whole number of tone cycles. We count the
-- zero-crossings in the window; a mark window holds twice as many as a space
-- window (16 vs 8 for the default scheme). We classify the window by whichever
-- symbol's expected crossing-count the measurement is nearest to. No filtering, no
-- FFT — the signal is clean because we synthesised it, and the descriptor's
-- "whole cycles per bit" invariant keeps the counts exact.
--
-- Failure policy: framing violations ERROR loudly. A tape that will not read is a
-- fact the caller must face, not a half-guess to paper over. (no silent fallback)

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

-- {{{ local function count_zero_crossings(samples, from, count)
-- Count sign changes across `count` samples starting at index `from`. One sign
-- change == one zero-crossing of the underlying tone.
local function count_zero_crossings(samples, from, count)
   local crossings = 0
   local prev = samples[from]
   for k = 1, count - 1 do
      local cur = samples[from + k]
      -- A crossing is a change of sign between adjacent samples. Zero counts as
      -- non-negative so a sample landing exactly on 0 does not double-count.
      local prev_neg = prev < 0
      local cur_neg  = cur < 0
      if prev_neg ~= cur_neg then
         crossings = crossings + 1
      end
      prev = cur
   end
   return crossings
end
-- }}}

-- {{{ local function classify_window(D, crossings)
-- Turn a crossing count into a bit symbol by nearest expected count. Loops over
-- the two symbols (a tiny dispatch over the symbol set) rather than hardcoding an
-- if mark-else-space, so a future third symbol would just be another entry.
local function classify_window(D, crossings)
   local descM = descriptor_module()
   local best_symbol, best_distance
   for _, symbol in ipairs({ descM.SPACE, descM.MARK }) do
      local expected = descM.expected_crossings(D, symbol)
      local distance = math.abs(crossings - expected)
      if best_distance == nil or distance < best_distance then
         best_distance = distance
         best_symbol   = symbol
      end
   end
   return best_symbol
end
-- }}}

-- {{{ local function samples_to_symbols(D, samples)
-- Chop the audio into bit-windows and classify each into a 0/1 symbol.
local function samples_to_symbols(D, samples)
   local descM = descriptor_module()
   local spb   = descM.samples_per_bit(D)
   -- A length that is not a whole number of windows means the audio is truncated
   -- or corrupt — an error, because our encoder always emits whole windows.
   if #samples % spb ~= 0 then
      error("cassette decoder: sample count " .. #samples
            .. " is not a whole number of bit-windows of " .. spb)
   end
   local symbols = {}
   local w = 0
   local pos = 1
   while pos <= #samples do
      w = w + 1
      symbols[w] = classify_window(D, count_zero_crossings(samples, pos, spb))
      pos = pos + spb
   end
   return symbols
end
-- }}}

-- {{{ local function all_marks_from(symbols, i, MARK)
-- True if every remaining symbol from i onward is a mark. Used to tell "we hit the
-- trailing/idle marks and are cleanly done" from "the framing is actually broken."
local function all_marks_from(symbols, i, MARK)
   for k = i, #symbols do
      if symbols[k] ~= MARK then
         return false
      end
   end
   return true
end
-- }}}

-- {{{ local function symbols_to_bytes(D, symbols)
-- Walk the symbol stream frame by frame back into bytes. Each control-flow branch
-- is commented with what it means, per project policy.
local function symbols_to_bytes(D, symbols)
   local bit  = require("bit")
   local descM = descriptor_module()
   local out = {}
   local i = 1

   -- Skip the mark leader: idle marks before the first start bit are sync, not data.
   while i <= #symbols and symbols[i] == descM.MARK do
      i = i + 1
   end

   while i <= #symbols do
      if symbols[i] ~= descM.START then
         -- Not a start bit here. Two meanings:
         if all_marks_from(symbols, i, descM.MARK) then
            break                     -- ...trailing idle marks: a clean end of data.
         else
            error("cassette decoder: framing error at symbol " .. i
                  .. " (expected a start bit)")   -- ...real corruption: refuse loudly.
         end
      end
      i = i + 1                        -- consume the start bit

      -- Read 8 data bits, LSB first, back into a byte.
      if i + 7 > #symbols then
         error("cassette decoder: truncated frame near symbol " .. i)
      end
      local byte = 0
      for b = 0, 7 do
         byte = bit.bor(byte, bit.lshift(symbols[i + b], b))
      end
      i = i + 8

      -- The stop bit must be a mark; anything else means the frame was misaligned.
      if i > #symbols or symbols[i] ~= descM.STOP then
         error("cassette decoder: bad or missing stop bit near symbol " .. i)
      end
      i = i + 1

      out[#out + 1] = string.char(byte)
   end

   return table.concat(out)
end
-- }}}

-- {{{ function M.symbols_to_bytes(desc, symbols)
-- Exposed for tests that want to inject symbol-level corruption without synthesising
-- audio. Validates the descriptor first.
function M.symbols_to_bytes(desc, symbols)
   descriptor_module().validate(desc)
   return symbols_to_bytes(desc, symbols)
end
-- }}}

-- {{{ function M.decode(desc, samples)
-- The one door of this module: audio samples in, the original byte string out.
function M.decode(desc, samples)
   descriptor_module().validate(desc)
   local symbols = samples_to_symbols(desc, samples)
   return symbols_to_bytes(desc, symbols)
end
-- }}}

return M
