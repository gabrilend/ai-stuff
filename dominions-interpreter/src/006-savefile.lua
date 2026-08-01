-- 006-savefile.lua
--
-- Reading a Dominions savegame, in two entrances.
--
-- A header read opens the file, takes sixteen bytes, and closes it. A full
-- read is separate, explicit and expensive. The difference is not tidiness:
-- the turn number lives in the first handful of bytes, the files it lives in
-- run to millions of bytes each, and there are over a hundred savegames in the
-- collection this is tested against. One entrance answers "what turn is each
-- of these games on" in a moment; the other would read gigabytes to print a
-- column of small integers.
--
-- Every offset in this file is commented with how it was established. None of
-- them came from documentation - the publisher's format notes ship with the
-- game, describe the map format thoroughly, and say nothing about savegames.

local obfuscation = require("004-obfuscation")

local savefile = {}

-- Offsets are zero-based, matching a hex dump, because that is what they get
-- compared against. Add one when indexing a Lua string.
--
-- Established by reading every savegame in the local collection at once and
-- checking that the answers are all plausible: every version recovered is a
-- real published Dominions version, older saves report older versions, and
-- every turn lands in a sensible range with new games low and long-running
-- games high.
local SIGNATURE_AT = 0x03      -- three characters, "DOM", stored plainly
local VERSION_AT   = 0x0A      -- two bytes, little-endian, version times 100
local TURN_AT      = 0x0E      -- two bytes, little-endian, the displayed turn
local HEADER_BYTES = 16

-- Where the string run starts. Anywhere past the header will do, because the
-- walk is structural - it finds string boundaries rather than counting to them
-- - but it must be past the plaintext signature, which is not obfuscated and
-- would otherwise be revealed into noise.
local TEXT_FROM = 16

-- {{{ local function little_endian_16()
local function little_endian_16(bytes, zero_based_offset)
   local low = string.byte(bytes, zero_based_offset + 1)
   local high = string.byte(bytes, zero_based_offset + 2)
   if not low or not high then
      return nil
   end
   return low + high * 256
end
-- }}}

-- {{{ function savefile.kind_of()
-- Which kind of file this is, from its name. The nation is identified by the
-- filename and by nothing found so far inside the file, which is worth
-- knowing before somebody goes looking for it.
function savefile.kind_of(filename)
   local base = string.match(filename, "([^/]+)$") or filename
   if base == "ftherlnd" then
      return "world", nil
   end
   local nation = string.match(base, "^(.+)%.trn$")
   if nation then
      return "turn", nation
   end
   nation = string.match(base, "^(.+)%.2h$")
   if nation then
      return "orders", nation
   end
   return nil, nil
end
-- }}}

-- {{{ function savefile.header()
-- The first sixteen bytes, and nothing else.
--
-- Returns a table, or nil and a reason. The reasons are kept distinct on
-- purpose: a savegame awaiting pretender submissions has no world state file
-- at all, which is a legitimate condition and not the same thing as a damaged
-- one, and neither is the same as turn zero - which is not a thing that
-- exists.
function savefile.header(path)
   local handle = io.open(path, "rb")
   if not handle then
      return nil, "cannot open " .. path
   end
   local bytes = handle:read(HEADER_BYTES)
   handle:close()

   if not bytes or #bytes < HEADER_BYTES then
      return nil, path .. " is shorter than a Dominions header"
   end

   -- The signature is checked before any other offset is trusted. Every field
   -- below is read from a fixed position, and fixed positions in a file of the
   -- wrong kind produce numbers that look entirely real.
   local signature = string.sub(bytes, SIGNATURE_AT + 1, SIGNATURE_AT + 3)
   if signature ~= "DOM" then
      return nil, path .. " is not a Dominions file"
   end

   local hundredths = little_endian_16(bytes, VERSION_AT)
   local turn = little_endian_16(bytes, TURN_AT)
   local kind, nation = savefile.kind_of(path)

   return {
      path = path,
      kind = kind,
      nation = nation,
      -- The version that last *wrote* this file, not the one that created the
      -- game. An old game opened by a new build reports the new build.
      version = {
         major = math.floor(hundredths / 100),
         minor = hundredths % 100,
      },
      version_number = hundredths,
      turn = turn,
   }
end
-- }}}

-- {{{ local function classify_strings()
-- Turns the string run into facts by shape rather than by position.
--
-- The entries appear in a known order - game name, then mods, then a version
-- string, then map layers - but reading by position breaks the moment a game
-- version adds a field, and reading by shape does not. Mod entries end in .dm
-- and are followed by the folder that contains them; a map layer's title is
-- the entry sitting in front of its .map.
--
-- Anything that fits no shape is returned as `other` rather than dropped,
-- because a string nobody expected is the first sign of a format change and
-- silently discarding it is how that sign gets missed.
local function classify_strings(strings, game_name_expected)
   local found = {
      game = nil,
      mods = {},
      layers = {},
      version_text = nil,
      other = {},
      region_end = 0,
   }

   local index = 1
   -- The first entry is the game name, which should match the folder. The
   -- comparison is the standing check on the padding ambiguity in the string
   -- walk: if that rule ever clips a name, this is where it announces itself.
   if strings[1] then
      found.game = strings[1].text
      found.game_matches_folder =
         (game_name_expected == nil) or (strings[1].text == game_name_expected)
      found.region_end = strings[1].offset + #strings[1].text
      index = 2
   end

   while index <= #strings do
      local entry = strings[index]
      local text = entry.text

      if string.match(text, "%.dm$") then
         -- A mod: its file, then the folder Dominions looks it up by. The
         -- folder is the half that matters - rename it and the save can no
         -- longer load.
         local folder = strings[index + 1]
         found.mods[#found.mods + 1] = {
            file = text,
            folder = folder and folder.text or nil,
         }
         index = index + (folder and 2 or 1)

      elseif string.match(text, "^version%s") then
         found.version_text = text
         index = index + 1

      elseif string.match(text, "%.map$") then
         -- A map file. The entry before it is the layer's readable title,
         -- unless that entry was itself a file - which happens in the preamble
         -- before the layer list proper.
         local previous = strings[index - 1]
         local title = nil
         if previous and not string.match(previous.text, "%.%a+$") then
            title = previous.text
            -- It was counted as `other` a moment ago; take it back.
            if found.other[#found.other]
               and found.other[#found.other].text == previous.text then
               found.other[#found.other] = nil
            end
         end
         found.layers[#found.layers + 1] = { title = title, map = text }
         index = index + 1

      elseif string.match(text, "%.d6m$") or string.match(text, "%.tga$") then
         -- Rendered map data and images. Named here, never opened: tens of
         -- megabytes of graphics holding nothing this program wants.
         index = index + 1

      else
         found.other[#found.other + 1] = entry
         index = index + 1
      end

      found.region_end = entry.offset + #text
   end

   return found
end
-- }}}

-- {{{ function savefile.describe()
-- Header plus string run. Reads only the front of the file - enough for the
-- game name, the mod list and the map layers, and not the millions of bytes
-- of records behind them.
--
-- `game_name_expected` is the folder name, passed in so the game name found
-- inside can be checked against it. Disagreements are reported, never
-- corrected.
function savefile.describe(path, game_name_expected, front_bytes)
   local header, reason = savefile.header(path)
   if not header then
      return nil, reason
   end

   local handle = io.open(path, "rb")
   if not handle then
      return nil, "cannot open " .. path
   end
   local bytes = handle:read(front_bytes or 8192)
   handle:close()

   -- Minimum two characters, not three. A savegame in the local collection is
   -- called "H2", and a three-character floor dropped its name entirely - so
   -- the first string found became the first mod's filename and the game name
   -- check reported a disagreement that was this reader's fault rather than
   -- the file's. Two is as low as it can go: single characters are never names
   -- and are frequently coincidence.
   local strings = obfuscation.strings(bytes, TEXT_FROM, 2)
   local classified = classify_strings(strings, game_name_expected)

   header.game = classified.game
   header.game_matches_folder = classified.game_matches_folder
   header.mods = classified.mods
   header.layers = classified.layers
   header.version_text = classified.version_text
   header.unclassified = classified.other
   header.records_from = classified.region_end

   return header
end
-- }}}

-- {{{ function savefile.record_array()
-- Finds a fixed-stride record array by measuring, and refuses to interpret
-- what it has not established.
--
-- The method: find every name-shaped string terminated by a separator, and for
-- each neighbouring pair compute the gap between them once the earlier name's
-- own length and terminator are subtracted. A fixed-stride array whose only
-- text field is a name shows up as one gap occurring many times; noise shows
-- up as a scatter of gaps occurring once each.
--
-- The stride is measured per file, every time, and is never written into this
-- source as a number. A file whose stride disagrees with the collection's
-- usual one is interesting rather than broken - that is exactly how a format
-- change in a new game version would announce itself, and a hard-coded stride
-- is how it would instead announce itself as silent corruption.
--
-- The whole tally comes back, not only the winner. A file with two competing
-- strides has two arrays, and flattening that to one number loses one of them.
function savefile.record_array(bytes, minimum_run)
   minimum_run = minimum_run or 4

   local names = obfuscation.names(bytes, 3)
   if #names < 2 then
      return nil, "no name-shaped strings to measure"
   end

   local tally = {}
   for index = 1, #names - 1 do
      local gap = names[index + 1].offset
         - names[index].offset
         - names[index].length
         - 1
      tally[gap] = (tally[gap] or 0) + 1
   end

   local ranked = {}
   for gap, count in pairs(tally) do
      ranked[#ranked + 1] = { gap = gap, count = count }
   end
   table.sort(ranked, function(left, right)
      if left.count == right.count then
         return left.gap > right.gap
      end
      return left.count > right.count
   end)

   -- The longest unbroken run at each candidate gap, best first. Taking the
   -- most frequent gap is not enough on its own: a gap of zero occurs often in
   -- files full of padding and never forms a run.
   local best = nil
   for rank = 1, math.min(#ranked, 6) do
      local gap = ranked[rank].gap
      local run, longest = {}, {}
      for index = 1, #names - 1 do
         local measured = names[index + 1].offset
            - names[index].offset
            - names[index].length
            - 1
         if measured == gap then
            if #run == 0 then
               run[1] = names[index]
            end
            run[#run + 1] = names[index + 1]
         else
            if #run > #longest then longest = run end
            run = {}
         end
      end
      if #run > #longest then longest = run end

      if #longest >= minimum_run and (not best or #longest > #best.records) then
         best = { stride = gap, records = longest }
      end
   end

   if not best then
      return nil, "no run of at least " .. minimum_run .. " records at any gap"
   end

   -- Each record: where it starts, how long it is, its name, and its raw
   -- bytes. The raw bytes are kept deliberately - phase seven changes fields
   -- inside these records without disturbing what surrounds them, and the
   -- experiments that establish where those fields live need the originals to
   -- compare against.
   local records = {}
   for index = 1, #best.records do
      local name = best.records[index]
      local record_length = best.stride + name.length + 1
      records[#records + 1] = {
         name = name.text,
         name_offset = name.offset,
         offset = name.offset - best.stride,
         length = record_length,
         raw = string.sub(bytes,
            name.offset - best.stride + 1,
            name.offset + name.length + 1),
      }
   end

   return {
      stride = best.stride,
      count = #records,
      records = records,
      tally = ranked,
      first_offset = records[1] and records[1].offset or nil,
      last_offset = records[#records] and
         (records[#records].offset + records[#records].length) or nil,
   }
end
-- }}}

-- {{{ function savefile.read_all()
-- The expensive entrance. Reads the whole file, which for a world state is
-- millions of bytes. Separate from describe() so it is never called by
-- accident.
function savefile.read_all(path)
   local handle = io.open(path, "rb")
   if not handle then
      return nil, "cannot open " .. path
   end
   local bytes = handle:read("*a")
   handle:close()
   return bytes
end
-- }}}

-- {{{ function savefile.placed_fraction()
-- How much of a file has been accounted for by a recognised record array.
--
-- This will start small and embarrassing, and it should. A number saying
-- eleven percent of this file has been placed is worth more than a document
-- implying the format is solved because the solved parts are the parts that
-- got written about. It is the only honest measure of progress here.
function savefile.placed_fraction(bytes, array)
   if not array or not array.first_offset then
      return 0
   end
   local placed = 0
   for index = 1, #array.records do
      placed = placed + array.records[index].length
   end
   return placed / #bytes
end
-- }}}

return savefile
