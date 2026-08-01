-- 004-obfuscation.lua
--
-- Seeing through the game's disguise.
--
-- Dominions hides the text in its save and configuration files by exclusive-or
-- ing every byte against a single constant. No key, no rotation, no
-- compression, no variation between files or versions. That is the whole
-- scheme, and undoing it hands over the game's name, its mods, its map, the
-- version that wrote it, the turn it sits on, the names of every province and
-- the names of every officer.
--
-- This module is the only place in the project that knows the constant. If the
-- game ever changes it, the fix is one line here and the phase one tests say
-- so on the next run.
--
-- How it was established: mod folder names visible on disk were matched
-- against the same bytes inside the savegames that declare them, and every
-- character differed by the same value. Confirmed afterwards against the whole
-- local collection, across several game versions, where it produces readable
-- game names, mod names, map titles, province names and event prose in every
-- file. The chronicler project found this first; this is a re-derivation, kept
-- separate because this project needs offsets and record walking that
-- chronicler deliberately never needed.

local bit = require("bit")

local obfuscation = {}

-- The whole of it.
local MASK = 0x4F

-- Revealing a byte is the same operation as hiding it, so one table serves
-- both directions. Built once at load rather than computed per byte, because
-- the survey runs this over a hundred files.
local REVEALED = {}
for value = 0, 255 do
   REVEALED[value] = string.char(bit.bxor(value, MASK))
end

-- {{{ function obfuscation.mask()
-- The constant, for tests that want to assert what it is rather than trust
-- that a round trip works by accident.
function obfuscation.mask()
   return MASK
end
-- }}}

-- {{{ function obfuscation.reveal()
-- Hidden bytes to readable ones. Also readable to hidden, since the operation
-- is its own inverse - which is why there is no separate hide function, and
-- why round-tripping is a meaningful test.
function obfuscation.reveal(bytes)
   local out = {}
   for index = 1, #bytes do
      out[index] = REVEALED[string.byte(bytes, index)]
   end
   return table.concat(out)
end
-- }}}

-- {{{ function obfuscation.is_printable()
-- Whether a revealed chunk is text a person would recognise. Deliberately
-- strict: printable ASCII only. A looser test admits fragments of binary that
-- happen to contain a few letters, and a fragment that looks like a name is
-- far worse than a name that was missed, because the caller cannot tell it is
-- wrong.
function obfuscation.is_printable(chunk)
   if #chunk == 0 then
      return false
   end
   for index = 1, #chunk do
      local byte = string.byte(chunk, index)
      if byte < 32 or byte > 126 then
         return false
      end
   end
   return true
end
-- }}}

-- {{{ local function string_within_chunk()
-- Given one raw chunk lying between two separators, returns the offset and the
-- part of it that is actually the string.
--
-- A chunk holds, in order, whatever binary field preceded the text, then some
-- alignment padding, then the string. So the string is the tail, and the job
-- is finding where it starts. It starts after the last byte that could not
-- belong to a name, and two kinds disqualify a byte:
--
--    it reveals to something unprintable, so it was binary, and
--    it is a raw zero, which is either padding or a capital O.
--
-- That second one is the ambiguity that runs through this entire format, and
-- it is worth stating rather than hiding. Zero is what the constant itself
-- reveals to, so the padding before a name and a capital O inside a name are
-- the same byte. This rule resolves towards padding, which is right
-- overwhelmingly often - the padding is always there and capital O's are not -
-- at the cost of clipping a name that genuinely contains one.
--
-- The cost is bounded and checked rather than hoped about: every game name
-- read out of a savegame is compared against the folder it was found in, and a
-- disagreement is reported rather than believed. The survey runs that check
-- across the whole collection, so if this rule ever bites, it says so.
--
-- Resolving the other way was tried in chronicler and is worse. Treating only
-- runs of two or more zeros as padding preserves capital O's, but lets
-- stretches of binary that happen to reveal as letters through, and those
-- arrive silently attached to the front of real names - corrupting every name
-- a little instead of one name a lot, and doing it invisibly.
local function string_within_chunk(chunk)
   local start = 1
   for index = 1, #chunk do
      local byte = string.byte(chunk, index)
      local revealed = string.byte(REVEALED[byte])
      if byte == 0 or revealed < 32 or revealed > 126 then
         start = index + 1
      end
   end
   if start > #chunk then
      return nil
   end
   return start, string.sub(chunk, start)
end
-- }}}

-- {{{ function obfuscation.strings()
-- Walks the null-terminated strings in a stretch of hidden bytes and returns
-- the readable ones with the offset each was found at, in the order they
-- appear.
--
-- The walk is structural rather than a search for readable-looking runs. The
-- bytes are split on the separator - which, remember, is the constant itself,
-- because a zero terminator reveals to it - each chunk has its leading binary
-- and padding removed, and what remains is revealed.
--
-- Offsets come back because the record arrays are located by measuring the
-- distance between the names inside them, and because the hand will one day
-- need to edit the bytes around one. Chronicler returned strings alone; it
-- only ever needed names.
--
-- `from` matters. The file's header holds numeric fields and a plaintext
-- signature which are not obfuscated, and running them through this produces
-- nonsense. Callers pass the offset where the text region starts.
--
-- Offsets are zero-based, matching what a hex dump shows, because these
-- numbers get compared against hex dumps constantly.
function obfuscation.strings(bytes, from, minimum_length)
   from = from or 1
   minimum_length = minimum_length or 2

   local found = {}
   local limit = #bytes
   local chunk_start = from

   -- {{{ local function take()
   local function take(chunk_end)
      if chunk_end < chunk_start then
         return
      end
      local chunk = string.sub(bytes, chunk_start, chunk_end)
      local offset_in_chunk, tail = string_within_chunk(chunk)
      if not tail then
         return
      end
      local text = obfuscation.reveal(tail)
      if #text >= minimum_length and obfuscation.is_printable(text) then
         found[#found + 1] = {
            offset = chunk_start + offset_in_chunk - 2,
            text = text,
         }
      end
   end
   -- }}}

   local index = from
   while index <= limit do
      if string.byte(bytes, index) == MASK then
         take(index - 1)
         chunk_start = index + 1
      end
      index = index + 1
   end

   -- Whatever trails the final separator. A bounded read can end mid-file, and
   -- the last complete string before the cut is still real - but only if the
   -- read reached a separator first, which take handles by finding nothing
   -- printable in a half-string.
   take(limit)

   return found
end
-- }}}

-- {{{ function obfuscation.names()
-- Every name-shaped run that ends at a separator, with its offset and length.
--
-- Different from strings() and deliberately so. strings() answers "what text
-- is in this region", which is what the header wants. This answers "where are
-- the names", which is what finding a record array wants, and the difference
-- that matters is the terminator requirement: a real name is always followed
-- by the null that ends its string, and requiring that keeps stretches of
-- binary that happen to reveal as letters out of the sample.
--
-- Name-shaped means letters, spaces, apostrophes and hyphens. Dominions names
-- include things like O'ngai and Two Spruce Forest, so neither the apostrophe
-- nor the space can be excluded.
--
-- The padding ambiguity bites here too, and harder. A run of raw zeros before
-- a name reveals as a run of capital O's, which are letters, which are
-- name-shaped - so the run found by a naive scan starts in the padding. That
-- is not a hypothetical: it happened during this project's own investigation
-- and produced a record stride three bytes short. The leading O's are stripped
-- here, and the stripping is why this function exists rather than a one-line
-- pattern match at the call site.
function obfuscation.names(bytes, minimum_length)
   minimum_length = minimum_length or 3

   local found = {}
   local run_start = nil

   -- {{{ local function nameish()
   local function nameish(shown)
      return (shown >= 65 and shown <= 90)
          or (shown >= 97 and shown <= 122)
          or shown == 32 or shown == 39 or shown == 45
   end
   -- }}}

   for index = 1, #bytes do
      local shown = string.byte(REVEALED[string.byte(bytes, index)])
      if nameish(shown) and not run_start then
         run_start = index
      elseif not nameish(shown) and run_start then
         -- shown == 0 means this byte was the separator, so the string ended
         -- here rather than merely running out of letters.
         if shown == 0 then
            -- Where the name really starts: after the last raw zero in the
            -- run. This is the same rule string_within_chunk uses, and it is
            -- the same rule for the same reason - the padding in front of a
            -- name is raw zeros, and raw zeros reveal to the capital letter O.
            --
            -- Stripping only the *leading* zeros is not enough, and the
            -- collection said so. A commander record holds a small binary
            -- field a few bytes before the name, and when that field holds 1
            -- it reveals to the letter N. The run then begins at the binary
            -- byte rather than at the padding, no leading zero is there to
            -- strip, and the name comes back as "NOOPaeon" instead of "Paeon".
            --
            -- The cost is the documented one: a name genuinely containing a
            -- capital O is clipped at it. Lower-case o is a different byte and
            -- is safe, so this bites only names like O'ngai. The check that
            -- catches it is the game name comparison in the survey, which runs
            -- over the whole collection.
            local real_start = run_start
            for scan = run_start, index - 1 do
               if string.byte(bytes, scan) == 0 then
                  real_start = scan + 1
               end
            end
            local length = index - real_start
            if length >= minimum_length then
               found[#found + 1] = {
                  offset = real_start - 1,
                  length = length,
                  text = obfuscation.reveal(
                     string.sub(bytes, real_start, index - 1)),
               }
            end
         end
         run_start = nil
      end
   end

   return found
end
-- }}}

return obfuscation
