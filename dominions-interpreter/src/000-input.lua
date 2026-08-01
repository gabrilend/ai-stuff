-- 000-input.lua
--
-- The first thing the program does.
--
-- A program learns how to start by reading input/. This module is that
-- reading: where Dominions lives, which of a hundred savegames is being
-- played, which nation belongs to the player, and where working copies go.
--
-- Nothing here searches the disk for a game to play. The local collection
-- holds over a hundred savegames and several of them contain more than one
-- turn file, because more than one nation has been played in them. A program
-- that guesses which one you meant will eventually guess wrong, and being
-- wrong means narrating somebody else's private view of the world - a failure
-- that is completely invisible when it happens.

local input = {}

-- Every path in the program hangs off one directory, resolved once. Set by
-- configure(); until then, nothing here will answer.
local project_directory = nil

-- {{{ local function trim()
local function trim(text)
   return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end
-- }}}

-- {{{ local function exists()
-- Whether a path can be opened. Directories cannot be opened for reading on
-- every platform, so a directory is probed by trying to list it instead.
local function exists(path)
   local handle = io.open(path, "r")
   if handle then
      handle:close()
      return true
   end
   -- A directory: opening fails but changing into it in a listing succeeds.
   local probe = io.popen('test -e "' .. path .. '" && echo yes')
   if not probe then
      return false
   end
   local answer = probe:read("*l")
   probe:close()
   return answer == "yes"
end
-- }}}

-- {{{ function input.configure()
-- Names the directory everything else is relative to. Called once, at start,
-- from the run script, which passes either its own hard-coded location or the
-- argument it was given.
function input.configure(directory)
   if not directory or directory == "" then
      error("input.configure needs a project directory")
   end
   project_directory = string.gsub(directory, "/$", "")
   return project_directory
end
-- }}}

-- {{{ function input.directory()
function input.directory()
   if not project_directory then
      error("input.configure has not been called; nothing knows where it is")
   end
   return project_directory
end
-- }}}

-- {{{ function input.path()
-- A path inside the project. Everything joins through here so that moving the
-- project moves one string.
function input.path(...)
   local parts = { input.directory() }
   for index = 1, select("#", ...) do
      parts[#parts + 1] = (select(index, ...))
   end
   return table.concat(parts, "/")
end
-- }}}

-- {{{ function input.read_pairs()
-- Parses a "key value" file. Blank lines and lines beginning with # are
-- ignored. The value is everything after the first run of whitespace, so a
-- path with spaces in it survives. A later line overrides an earlier one,
-- which means a settings file can be appended to rather than edited - and
-- appending is what a person does when they are unsure, so it should work.
--
-- Returns the table, or nil and a reason. A missing file is a reason, not an
-- empty table: an empty table would let the caller proceed with no settings
-- and discover the problem five steps later.
function input.read_pairs(path)
   local handle = io.open(path, "r")
   if not handle then
      return nil, "cannot open " .. path
   end

   local settings = {}
   local line_number = 0
   for line in handle:lines() do
      line_number = line_number + 1
      local text = trim(line)
      if text ~= "" and string.sub(text, 1, 1) ~= "#" then
         local key, value = string.match(text, "^(%S+)%s+(.*)$")
         if not key then
            handle:close()
            return nil, string.format("%s line %d: expected 'key value', got %q",
               path, line_number, text)
         end
         settings[key] = trim(value)
      end
   end
   handle:close()
   return settings
end
-- }}}

-- {{{ local function turn_files_in()
-- The turn files in a savegame folder. A folder may hold several, one per
-- nation that has been played in that game, which is exactly why the nation
-- is never guessed.
local function turn_files_in(folder)
   local found = {}
   local listing = io.popen('ls -1 "' .. folder .. '" 2>/dev/null')
   if not listing then
      return found
   end
   for name in listing:lines() do
      local nation = string.match(name, "^(.+)%.trn$")
      if nation then
         found[#found + 1] = nation
      end
   end
   listing:close()
   table.sort(found)
   return found
end
-- }}}

-- {{{ function input.game()
-- Reads input/game and returns everything the program needs to find a world.
--
-- Returns a settings table, or nil and a reason. Two failure shapes are worth
-- telling apart by the caller:
--
--   the file or a path it names is wrong  -> an error, naming the key
--   the nation was not stated             -> not an error; candidates come back
--
-- The second is a question for a person, not a fault. A savegame folder with
-- exactly one turn file is still not reason enough to choose silently.
function input.game()
   local path = input.path("input", "game")
   local settings, reason = input.read_pairs(path)
   if not settings then
      return nil, reason .. " - copy input/game.example to input/game and fill it in"
   end

   local required = { "dominions-home", "dominions-binary", "game" }
   for index = 1, #required do
      local key = required[index]
      if not settings[key] then
         return nil, string.format("%s does not set %s", path, key)
      end
   end

   -- Each path is checked here rather than where it is used, because a bad
   -- path discovered halfway through a conversation has already cost the
   -- conversation.
   local checked = {
      { key = "dominions-home", value = settings["dominions-home"] },
      { key = "dominions-binary", value = settings["dominions-binary"] },
   }
   for index = 1, #checked do
      if not exists(checked[index].value) then
         return nil, string.format("%s: %s names %s, which does not exist",
            path, checked[index].key, checked[index].value)
      end
   end

   local savegame = settings["dominions-home"] .. "/savedgames/" .. settings["game"]
   if not exists(savegame) then
      return nil, string.format("%s: game %s has no folder at %s",
         path, settings["game"], savegame)
   end

   local world = {
      home = settings["dominions-home"],
      binary = settings["dominions-binary"],
      game = settings["game"],
      savegame = savegame,
      work = settings["work"] or input.path("work"),
      chronicle = settings["chronicle"]
         or input.path("output", settings["game"] .. ".chronicle"),
      nations = turn_files_in(savegame),
   }

   -- The nation, or the candidates. Never a choice made here.
   if settings["nation"] then
      local wanted = settings["nation"]
      for index = 1, #world.nations do
         if world.nations[index] == wanted then
            world.nation = wanted
            return world
         end
      end
      return nil, string.format(
         "%s: nation %s has no turn file in %s (found: %s)",
         path, wanted, savegame,
         #world.nations > 0 and table.concat(world.nations, ", ") or "none")
   end

   -- No nation stated. This is a question, not a failure, so the table comes
   -- back whole with `nation` absent and `nations` listing what to ask about.
   return world
end
-- }}}

-- {{{ function input.cluster()
-- Reads input/cluster into an array of doors. Parses only - nothing is
-- contacted here. Reaching a door, and refusing to start when one is dark, is
-- phase five's business; this module's job is to say what was asked for.
--
-- A door with no stated kind is assumed to answer both completions and
-- embeddings, because one llama-server can.
function input.cluster()
   local path = input.path("input", "cluster")
   local handle = io.open(path, "r")
   if not handle then
      return nil, "cannot open " .. path
         .. " - copy input/cluster.example to input/cluster and name the doors"
   end

   local doors = {}
   local line_number = 0
   for line in handle:lines() do
      line_number = line_number + 1
      local text = trim(line)
      if text ~= "" and string.sub(text, 1, 1) ~= "#" then
         local name, host, port, kind =
            string.match(text, "^(%S+)%s+(%S+)%s+(%d+)%s*(%S*)$")
         if not name then
            handle:close()
            return nil, string.format(
               "%s line %d: expected 'name host port [kind]', got %q",
               path, line_number, text)
         end
         if kind == "" then
            kind = "both"
         end
         if kind ~= "completion" and kind ~= "embedding" and kind ~= "both" then
            handle:close()
            return nil, string.format(
               "%s line %d: kind must be completion, embedding or both, got %q",
               path, line_number, kind)
         end
         doors[#doors + 1] = {
            name = name,
            host = host,
            port = tonumber(port),
            kind = kind,
         }
      end
   end
   handle:close()

   if #doors == 0 then
      return nil, path .. " names no doors"
   end
   return doors
end
-- }}}

-- {{{ function input.ensure_scratch()
-- The two RAM tiers. /dev/shm does not survive a reboot, so this runs every
-- time rather than at install: a run script that assumes the directory is
-- still there fails on the first cold morning.
function input.ensure_scratch()
   os.execute('mkdir -p /tmp/dominions-interpreter')
   os.execute('mkdir -p /dev/shm/dominions-interpreter')
   os.execute('ln -sfn /dev/shm/dominions-interpreter /tmp/dominions-interpreter/shared-memory')
   return "/tmp/dominions-interpreter/shared-memory"
end
-- }}}

return input
