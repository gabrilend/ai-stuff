-- 004-cassette-roundtrip-and-demo.lua
--
-- Story index 004 of the experimental cassette branch (issue 905, Phase 9).
-- WHAT it does: proves the software round-trip issue 905 asks for — bytes -> tones
-- -> bytes — and, when handed an output directory, also emits the listenable
-- artifact (a .wav "cassette") plus a text report. Tests are cheap; this file makes
-- several, and it is the thing the run script executes to show the branch works.
--
-- Run:  luajit 004-cassette-roundtrip-and-demo.lua [output_dir]
--   with no argument  -> run the assertions only (exit 0 pass, non-zero fail).
--   with an output dir -> also write <dir>/cassette-demo.wav and .../report.txt.

-- Make the sibling modules importable no matter which directory launched us — the
-- project's "runnable from any directory" rule. WHY derive from arg[0]: the run
-- script may invoke this by absolute path from anywhere.
local here = (arg[0]:match("(.*/)")) or "./"
package.path = here .. "?.lua;" .. package.path

local descriptor = require("000-cassette-encoding-descriptor")
local encoder    = require("001-cassette-tone-encoder")
local decoder    = require("002-cassette-tone-decoder")
local viewer     = require("003-cassette-tone-viewer")
local wav_reader = require("005-cassette-wav-reader")

local passed, failed = 0, 0

-- {{{ local function check(name, ok, detail)
local function check(name, ok, detail)
   if ok then
      passed = passed + 1
      print("  PASS  " .. name)
   else
      failed = failed + 1
      print("  FAIL  " .. name .. (detail and ("  -- " .. detail) or ""))
   end
end
-- }}}

-- {{{ local function roundtrip_equals(desc, message)
-- The core property: decode(encode(m)) == m. Returns ok, detail.
local function roundtrip_equals(desc, message)
   local samples = encoder.encode(desc, message)
   local back    = decoder.decode(desc, samples)
   if back == message then
      return true
   end
   return false, "got " .. #back .. " bytes, wanted " .. #message
end
-- }}}

-- {{{ local function all_bytes_message()
-- A 256-byte message containing every possible byte value 0..255, so the round-trip
-- is exercised against every bit pattern a byte can hold.
local function all_bytes_message()
   local t = {}
   for b = 0, 255 do t[#t + 1] = string.char(b) end
   return table.concat(t)
end
-- }}}

print("cassette round-trip assertions (issue 905, software-only)")

local desc = descriptor.default_descriptor()

-- 1) Round-trip a spread of real messages.
for _, message in ipairs({
   "A",
   "hello, wand",
   "First Person Spellcraft :: cassette demake",
   all_bytes_message(),
}) do
   local label = (#message <= 24) and ("round-trip '" .. message .. "'")
                                   or ("round-trip " .. #message .. "-byte message")
   local ok, detail = roundtrip_equals(desc, message)
   check(label, ok, detail)
end

-- 2) A malformed descriptor must be rejected, not silently patched.
do
   local bad = descriptor.default_descriptor()
   bad.baud = 301   -- 44100 % 301 ~= 0 breaks the exact-decoding invariant
   local ok = pcall(descriptor.validate, bad)
   check("malformed descriptor (bad baud) is rejected", not ok)
end

-- 3) Symbol-level corruption (a flipped stop bit) must error, not mis-decode.
do
   local bits = encoder.frame_bits(desc, "Z")   -- leader + one frame
   -- The frame's stop bit is the last symbol; flip it from mark to space.
   bits[#bits] = descriptor.SPACE
   local ok = pcall(decoder.symbols_to_bytes, desc, bits)
   check("flipped stop bit is caught as a framing error", not ok)
end

-- 4) A truncated tape (not a whole number of bit-windows) must error.
do
   local samples = encoder.encode(desc, "trunc")
   samples[#samples] = nil   -- drop one sample so the length is no longer exact
   local ok = pcall(decoder.decode, desc, samples)
   check("truncated sample stream is caught", not ok)
end

-- 5) The FULL loop through a real file on disk: encode -> write WAV -> read WAV
--    back off disk -> decode -> same bytes. This is what closes the "no WAV
--    reader" gap FINDINGS flagged; the in-memory tests above never touch a file.
do
   local message = "tape to disk and home again"
   local samples = encoder.encode(desc, message)
   local tmp = os.tmpname()
   viewer.write_wav(desc, samples, tmp)
   local read_back = wav_reader.read(desc, tmp)
   local decoded = decoder.decode(desc, read_back)
   os.remove(tmp)
   check("file round-trip (WAV on disk -> bytes)", decoded == message,
         decoded == message and nil or ("got " .. #decoded .. " bytes"))
end

print(string.format("\nresult: %d passed, %d failed", passed, failed))

-- Optional demo artifact: only when an output directory is given AND tests pass,
-- so we never ship a "cassette" that did not round-trip.
local out_dir = arg[1]
if out_dir and failed == 0 then
   local message = "First Person Spellcraft :: a pico-8-sized hello from the tape"
   local samples = encoder.encode(desc, message)
   local wav_path = out_dir .. "/cassette-demo.wav"
   viewer.write_wav(desc, samples, wav_path)

   -- Read the file we just wrote back off disk and decode it, so the report proves
   -- the loop through an actual .wav, not just the in-memory samples.
   local from_file = wav_reader.read(desc, wav_path)

   local report = table.concat({
      viewer.summarise(desc, message, samples),
      "",
      "symbol strip (first 120 bit-windows; '.' space, '#' mark):",
      "  " .. viewer.render_symbols(desc, samples):sub(1, 120),
      "",
      "round-trip check: decode(encode(message)) == message      -> "
         .. tostring(decoder.decode(desc, samples) == message),
      "file round-trip : decode(read_wav(cassette-demo.wav)) == m -> "
         .. tostring(decoder.decode(desc, from_file) == message),
   }, "\n")

   local report_path = out_dir .. "/cassette-report.txt"
   local f = io.open(report_path, "w")
   if not f then
      error("cassette demo: cannot write report to " .. report_path)
   end
   f:write(report .. "\n")
   f:close()

   print("\nwrote listenable cassette : " .. wav_path)
   print("wrote report              : " .. report_path)
end

-- Exit non-zero on any failure so a run script / CI notices. (errors over silence)
if failed > 0 then
   os.exit(1)
end
