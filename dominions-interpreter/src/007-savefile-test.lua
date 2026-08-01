-- 007-savefile-test.lua
--
-- Proves the savegame reader against the whole local collection.
--
-- The properties checked here are the ones that would catch a wrong offset:
-- every version recovered must be a real published Dominions version, every
-- turn must land in a plausible range, and every game must call itself what
-- its folder calls it. A single wrong byte in an offset breaks all three at
-- once, loudly, which is the point.

local savefile = require("006-savefile")

local test = {}

-- {{{ local function games_in()
local function games_in(home)
   local found = {}
   local listing = io.popen('ls -1 "' .. home .. '/savedgames" 2>/dev/null')
   if not listing then
      return found
   end
   for name in listing:lines() do
      found[#found + 1] = name
   end
   listing:close()
   return found
end
-- }}}

-- {{{ function test.run()
function test.run(check, home)
   -- File kinds are decided by name, because nothing found inside a turn file
   -- identifies its nation.
   local kind, nation = savefile.kind_of("ftherlnd")
   check("a world state file is recognised", kind == "world" and nation == nil)

   kind, nation = savefile.kind_of("/a/path/late_pangaea.trn")
   check("a turn file names its nation",
      kind == "turn" and nation == "late_pangaea")

   kind, nation = savefile.kind_of("late_pangaea.2h")
   check("an orders file names its nation",
      kind == "orders" and nation == "late_pangaea")

   check("a map file is not a savegame",
      savefile.kind_of("nexus.map") == nil)

   if not home then
      return
   end

   local games = games_in(home)
   local started, turns_seen, versions_seen = 0, 0, {}
   local highest_turn = 0

   for index = 1, #games do
      local game = games[index]
      local world = home .. "/savedgames/" .. game .. "/ftherlnd"
      local described = savefile.describe(world, game)

      if described then
         started = started + 1

         -- A real published Dominions 6 version. If an offset were wrong this
         -- would be a number like 13398 and the test would say so.
         check(game .. " reports a real Dominions version",
            described.version.major == 6
            and described.version.minor >= 0
            and described.version.minor <= 99)

         -- Turn numbers. Dominions games run long, but not arbitrarily long,
         -- and turn zero is not a thing a started game can be on.
         check(game .. " reports a plausible turn",
            described.turn ~= nil and described.turn >= 1
            and described.turn < 2000)

         check(game .. " calls itself by its folder name",
            described.game_matches_folder == true)

         check(game .. " reports where its records begin",
            described.records_from ~= nil and described.records_from > 16)

         turns_seen = turns_seen + 1
         if described.turn > highest_turn then
            highest_turn = described.turn
         end
         versions_seen[described.version.minor] = true
      end
   end

   check("most of the collection was read", started > 50)
   check("the collection contains a long game", highest_turn > 50)

   local distinct = 0
   for _ in pairs(versions_seen) do
      distinct = distinct + 1
   end
   check("the collection spans several game versions", distinct >= 5)

   -- A file that is not a Dominions file is refused, not misread. Every field
   -- above is read from a fixed position, and fixed positions in the wrong
   -- kind of file produce numbers that look entirely real.
   local refused = savefile.header(home .. "/dom6manual.pdf")
   check("a file that is not a Dominions file is refused", refused == nil)

   -- The record array, measured rather than assumed. The stride is not written
   -- into the source and this test does not name it either - what is asserted
   -- is that one stride dominates, because that is the actual claim.
   local strides = {}
   local measured = 0
   for index = 1, math.min(#games, 40) do
      local folder = home .. "/savedgames/" .. games[index]
      local orders = io.popen('ls -1 "' .. folder .. '"/*.2h 2>/dev/null')
      if orders then
         local path = orders:read("*l")
         orders:close()
         if path then
            local bytes = savefile.read_all(path)
            if bytes and #bytes > 4096 then
               local array = savefile.record_array(bytes, 4)
               if array then
                  strides[array.stride] = (strides[array.stride] or 0) + 1
                  measured = measured + 1
                  check(games[index] .. "'s records keep their raw bytes",
                     array.records[1].raw ~= nil
                     and #array.records[1].raw == array.records[1].length)
               end
            end
         end
      end
   end

   check("several orders files were measured", measured >= 10)

   local dominant, dominant_count = nil, 0
   for stride, count in pairs(strides) do
      if count > dominant_count then
         dominant, dominant_count = stride, count
      end
   end
   check("one stride dominates the collection",
      dominant ~= nil and dominant_count >= measured * 0.9)
end
-- }}}

return test
