-- 008-survey.lua
--
-- What the collection actually contains, read rather than remembered.
--
-- This exists so that no count, size, offset or stride is ever written as a
-- literal anywhere else in the project. The tool is the authority; the prose
-- is only ever a description of shape. When a document and this disagree, this
-- is right and the document is stale.
--
-- The cost discipline is the whole design. Reading a header is sixteen bytes;
-- reading a file is millions; there are over a hundred savegames. The shallow
-- pass reads headers only. The deep pass opens whole files, is a separate
-- request rather than the default, and says so while it runs - because a
-- survey that quietly reads gigabytes stops being run, and a tool nobody runs
-- is a document that lies.

local savefile = require("006-savefile")
local narrator = require("002-narrator")

local survey = {}

-- {{{ local function directory_entries()
local function directory_entries(path)
   local found = {}
   local listing = io.popen('ls -1 "' .. path .. '" 2>/dev/null')
   if not listing then
      return found
   end
   for name in listing:lines() do
      found[#found + 1] = name
   end
   listing:close()
   table.sort(found)
   return found
end
-- }}}

-- {{{ local function classify_folder()
-- What is in one savegame folder, from the filenames alone. A folder with no
-- world state file is either awaiting pretender submissions or an abandoned
-- shell, and the two look identical from outside - which is why this reports
-- "not started" rather than guessing which.
local function classify_folder(path)
   local contents = {
      world = nil,
      turns = {},
      orders = {},
      maps = {},
   }
   local entries = directory_entries(path)
   for index = 1, #entries do
      local name = entries[index]
      local kind, nation = savefile.kind_of(name)
      if kind == "world" then
         contents.world = path .. "/" .. name
      elseif kind == "turn" then
         contents.turns[#contents.turns + 1] = { nation = nation, path = path .. "/" .. name }
      elseif kind == "orders" then
         contents.orders[#contents.orders + 1] = { nation = nation, path = path .. "/" .. name }
      elseif string.match(name, "%.map$") then
         contents.maps[#contents.maps + 1] = name
      end
   end
   return contents
end
-- }}}

-- {{{ function survey.one()
-- One savegame, shallow. Header only.
function survey.one(home, game)
   local folder = home .. "/savedgames/" .. game
   local contents = classify_folder(folder)

   local row = {
      game = game,
      folder = folder,
      started = contents.world ~= nil,
      nations = {},
      turn = nil,
      version = nil,
      mods = {},
      trouble = nil,
   }

   for index = 1, #contents.turns do
      row.nations[#row.nations + 1] = contents.turns[index].nation
   end

   if not contents.world then
      -- Not an error. A game that has not started has no turn, and reporting
      -- zero here would destroy the difference between that and a broken file.
      return row
   end

   local described, reason = savefile.describe(contents.world, game)
   if not described then
      row.trouble = reason
      return row
   end

   row.turn = described.turn
   row.version = described.version
   row.version_text = described.version_text
   row.mods = described.mods
   row.layers = described.layers
   row.game_in_file = described.game
   row.game_matches_folder = described.game_matches_folder
   row.world_path = contents.world
   row.orders = contents.orders

   return row
end
-- }}}

-- {{{ function survey.mods_present()
-- Which declared mod folders actually exist under mods/. A savegame stores
-- both the mod's file and the folder Dominions looks it up by; rename the
-- folder and the save can no longer find its mod, so a missing one is worth
-- reporting rather than discovering when a game refuses to load.
function survey.mods_present(home, mods)
   local report = {}
   for index = 1, #mods do
      local folder = mods[index].folder
      local present = false
      if folder then
         local probe = io.open(home .. "/mods/" .. folder .. "/" .. mods[index].file, "r")
         if probe then
            probe:close()
            present = true
         else
            -- The folder may exist with the file named differently after a
            -- workshop update. Check the folder itself before calling it gone.
            local listing = io.popen('test -d "' .. home .. "/mods/" .. folder
               .. '" && echo yes')
            if listing then
               present = (listing:read("*l") == "yes")
               listing:close()
            end
         end
      end
      report[#report + 1] = {
         file = mods[index].file,
         folder = folder,
         present = present,
      }
   end
   return report
end
-- }}}

-- {{{ function survey.deep()
-- One savegame's orders file, opened in full, measured for record arrays.
--
-- Expensive on purpose and never called by the shallow pass. The orders file
-- is chosen over the world state because it is the smallest of the three and
-- because its tail is where the record array was first established.
function survey.deep(row)
   if not row.orders or #row.orders == 0 then
      return nil, "no orders file to measure"
   end

   local path = row.orders[1].path
   local bytes, reason = savefile.read_all(path)
   if not bytes then
      return nil, reason
   end

   local array, trouble = savefile.record_array(bytes, 4)
   if not array then
      return {
         path = path,
         size = #bytes,
         stride = nil,
         count = 0,
         placed = 0,
         trouble = trouble,
      }
   end

   return {
      path = path,
      size = #bytes,
      stride = array.stride,
      count = array.count,
      placed = savefile.placed_fraction(bytes, array),
      first = array.records[1] and array.records[1].name or nil,
      last = array.records[#array.records] and array.records[#array.records].name or nil,
      tally = array.tally,
   }
end
-- }}}

-- {{{ function survey.collection()
-- Every savegame under a Dominions home. Rows come back as they are computed
-- via the `each` callback, so a long run prints as it goes rather than after -
-- which is what stops somebody killing it because they assumed it had hung.
function survey.collection(home, each)
   local games = directory_entries(home .. "/savedgames")
   local rows = {}
   local elapsed = narrator.timer()

   for index = 1, #games do
      local row = survey.one(home, games[index])
      rows[#rows + 1] = row
      if each then
         each(row, index, #games)
      end
   end

   return rows, elapsed()
end
-- }}}

-- {{{ function survey.summarise()
-- The figures across the whole collection. Distributions rather than averages:
-- whether a format finding holds across versions is answered by seeing every
-- version, and an average version number is not a thing.
function survey.summarise(rows)
   local summary = {
      saves = #rows,
      started = 0,
      versions = {},
      turn_low = nil,
      turn_high = nil,
      name_disagreements = {},
      troubled = {},
   }

   for index = 1, #rows do
      local row = rows[index]
      if row.started then
         summary.started = summary.started + 1
      end
      if row.version then
         local key = row.version.major .. "." .. row.version.minor
         summary.versions[key] = (summary.versions[key] or 0) + 1
      end
      if row.turn then
         if not summary.turn_low or row.turn < summary.turn_low then
            summary.turn_low = row.turn
         end
         if not summary.turn_high or row.turn > summary.turn_high then
            summary.turn_high = row.turn
         end
      end
      if row.game_matches_folder == false then
         summary.name_disagreements[#summary.name_disagreements + 1] = {
            folder = row.game,
            in_file = row.game_in_file,
         }
      end
      if row.trouble then
         summary.troubled[#summary.troubled + 1] = {
            game = row.game,
            reason = row.trouble,
         }
      end
   end

   return summary
end
-- }}}

return survey
