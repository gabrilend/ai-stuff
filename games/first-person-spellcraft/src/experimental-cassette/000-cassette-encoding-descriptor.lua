-- 000-cassette-encoding-descriptor.lua
--
-- Story index 000 of the experimental cassette branch (issue 905, Phase 9).
-- WHAT it is: the data-at-rest description of how the bytes of a tiny game slice
-- become audio "tones" on a (software-modelled) cassette tape.
-- WHY it lives alone: a scheme is DATA. Keeping it apart from the encoder that
-- reads it (001) and the decoder that inverts it (002) is the project's
-- "generate here, view/consume there" separation — a bug in the encoder can never
-- corrupt the definition of the format itself.
--
-- This branch gates nothing. It is preserved whimsy: issue 905 asks us to prove
-- the encode/decode round-trip in SOFTWARE first, before any tape or Game Boy
-- hardware is involved. This file is the format that round-trip speaks.
--
-- DATA-FORMAT FACTS (recorded here because the encoder AND the decoder both need
-- them, and a reader refactoring either must not have to rediscover them):
--   * The scheme is Kansas-City-Standard-flavoured FSK (frequency-shift keying),
--     the way 1970s/80s home computers actually stored bytes as tape audio:
--       a '1' bit (MARK)  = mark_freq held for one bit-window of samples.
--       a '0' bit (SPACE) = space_freq held for one bit-window.
--   * A BYTE is framed like a UART character, least-significant bit FIRST:
--       [ start=0 ][ d0 d1 d2 d3 d4 d5 d6 d7 ][ stop=1 ]   -> 10 bits per byte.
--   * A LEADER of mark bits precedes the data so the decoder can find its feet
--     before the first real byte arrives.
--   * INVARIANT that makes software decoding exact: sample_rate must divide evenly
--     by baud, and each frequency must be an integer multiple of baud. Then every
--     bit-window holds a whole number of tone cycles, so counting zero-crossings
--     recovers the bit with no ambiguity (there is no noise in a synthesised
--     signal). The validate() below enforces this rather than hoping for it.

local M = {}

-- Symbol vocabulary. Named so the encoder/decoder read like prose, not magic 0/1.
M.SPACE = 0   -- a '0' bit
M.MARK  = 1   -- a '1' bit
M.START = 0   -- frame start bit is a space
M.STOP  = 1   -- frame stop bit is a mark

-- {{{ function M.default_descriptor()
-- The shipped default scheme. WHY these exact numbers: 44100/300 = 147 samples
-- per bit exactly; 2400/300 = 8 whole cycles per mark bit; 1200/300 = 4 whole
-- cycles per space bit. Whole cycles => exact zero-crossing counts (16 vs 8),
-- which is the whole reason the decoder can be simple and still correct. Change
-- any of these and validate() will tell you loudly if the invariant broke.
function M.default_descriptor()
   local mark_freq  = 2400
   local space_freq = 1200
   local baud       = 300
   return {
      sample_rate = 44100,      -- audio samples per second
      baud        = baud,       -- bits per second (KCS is 300 baud)
      mark_freq   = mark_freq,  -- tone for a '1' bit
      space_freq  = space_freq, -- tone for a '0' bit
      amplitude   = 0.7,        -- 0..1, headroom kept below clipping
      leader_bits = 32,         -- mark bits before data, so the decoder can sync

      -- Dispatch table symbol -> frequency, so the encoder never branches on the
      -- bit with an if/else; it indexes the tone. (project rule: index, don't branch)
      symbol_freq = { [M.SPACE] = space_freq, [M.MARK] = mark_freq },

      -- HONESTY per issue 905: the whole Phases 1-8 game does NOT fit an audio
      -- cassette read this way. The payload is a stated, tiny "pico-8-sized slice"
      -- demake, NOT the real game. This budget is the size ceiling that forces the
      -- slice; it is here as data so nobody mistakes the demo for the full game.
      slice_budget_bytes = 32 * 1024,  -- ~a pico-8 cart, order of magnitude
   }
end
-- }}}

-- {{{ function M.samples_per_bit(desc)
-- The bit-window width. Integer by the invariant validate() enforces.
function M.samples_per_bit(desc)
   return desc.sample_rate / desc.baud
end
-- }}}

-- {{{ function M.expected_crossings(desc, symbol)
-- How many zero-crossings one bit-window of the given symbol should contain.
-- Two crossings per cycle; cycles-per-bit = freq / baud. The decoder classifies a
-- window by whichever symbol's expected count its measured count is nearest to.
function M.expected_crossings(desc, symbol)
   local freq = desc.symbol_freq[symbol]
   if not freq then
      -- WHY error, not a default: a symbol outside {SPACE, MARK} means a caller
      -- bug. Guessing a frequency would hide it. (prefer errors over fallbacks)
      error("cassette descriptor: unknown symbol '" .. tostring(symbol) .. "'")
   end
   local cycles_per_bit = freq / desc.baud
   return 2 * cycles_per_bit
end
-- }}}

-- {{{ function M.validate(desc)
-- Prove a descriptor is well-formed and honours the exact-decoding invariant.
-- Errors LOUDLY on the first violation with the field named, because a malformed
-- scheme silently makes every tape unreadable — a warning we want as an error.
function M.validate(desc)
   local function require_positive(name, v)
      if type(v) ~= "number" or v <= 0 then
         error("cassette descriptor: '" .. name .. "' must be a positive number")
      end
   end
   require_positive("sample_rate", desc.sample_rate)
   require_positive("baud",        desc.baud)
   require_positive("mark_freq",   desc.mark_freq)
   require_positive("space_freq",  desc.space_freq)

   if desc.amplitude <= 0 or desc.amplitude > 1 then
      error("cassette descriptor: 'amplitude' must be in (0, 1]")
   end
   if desc.mark_freq == desc.space_freq then
      error("cassette descriptor: mark_freq and space_freq must differ (FSK needs two tones)")
   end
   -- The three "divides evenly" checks ARE the exact-decoding invariant.
   if desc.sample_rate % desc.baud ~= 0 then
      error("cassette descriptor: sample_rate must divide evenly by baud (got "
            .. desc.sample_rate .. " / " .. desc.baud .. ")")
   end
   if desc.mark_freq % desc.baud ~= 0 then
      error("cassette descriptor: mark_freq must be an integer multiple of baud")
   end
   if desc.space_freq % desc.baud ~= 0 then
      error("cassette descriptor: space_freq must be an integer multiple of baud")
   end
   if desc.leader_bits < 1 then
      error("cassette descriptor: leader_bits must be at least 1 (decoder needs sync)")
   end
   return desc  -- return it so callers can write `local d = M.validate(M.default_descriptor())`
end
-- }}}

return M
