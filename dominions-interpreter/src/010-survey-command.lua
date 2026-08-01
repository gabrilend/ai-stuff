-- 010-survey-command.lua
--
-- The survey, as something a person runs.
--
-- Written for reading aloud: linear, one save per line, one figure per line,
-- no columns that only line up in a fixed-width font, no information carried
-- by position or colour, no box drawing. That is the accessibility rule
-- applied to a developer tool, on purpose - the first surface anybody builds
-- is the one whose habits spread.

local input = require("000-input")
local narrator = require("002-narrator")
local survey = require("008-survey")

local command = {}

-- {{{ local function plural()
-- "1 save" rather than "1 saves". Small, and worth the four lines: this output
-- is meant to be read aloud, and a screen reader pronounces every stray s.
local function plural(count, singular, many)
   return string.format("%d %s", count, count == 1 and singular or (many or (singular .. "s")))
end
-- }}}

-- {{{ local function say_row()
local function say_row(row)
   if not row.started then
      print(string.format("%s has not started%s",
         row.game,
         #row.nations > 0
            and (", " .. #row.nations .. " nations waiting")
            or ""))
      return
   end

   if row.trouble then
      print(string.format("%s could not be read: %s", row.game, row.trouble))
      return
   end

   local nations = #row.nations > 0
      and table.concat(row.nations, ", ")
      or "no turn files"

   print(string.format("%s is on turn %d, written by %d.%d, played as %s",
      row.game, row.turn, row.version.major, row.version.minor, nations))

   if #row.mods > 0 then
      local named = {}
      for index = 1, #row.mods do
         named[#named + 1] = row.mods[index].folder or row.mods[index].file
      end
      print(string.format("   with %s: %s", plural(#row.mods, "mod"),
         table.concat(named, ", ")))
   end

   if row.game_matches_folder == false then
      -- The standing check on the string walk's padding rule. If the rule ever
      -- clips a name, this is where it says so, and it says so rather than
      -- quietly correcting itself.
      print(string.format("   the file calls itself %q, the folder is %q",
         tostring(row.game_in_file), row.game))
   end
end
-- }}}

-- {{{ local function say_summary()
local function say_summary(summary, seconds)
   print("")
   print(string.format("%s, %d of them started, read in %s",
      plural(summary.saves, "savegame"), summary.started,
      plural(seconds, "second")))

   if summary.turn_low then
      print(string.format("turns run from %d to %d",
         summary.turn_low, summary.turn_high))
   end

   local versions = {}
   for version, count in pairs(summary.versions) do
      versions[#versions + 1] = { version = version, count = count }
   end
   table.sort(versions, function(left, right)
      return left.version < right.version
   end)
   for index = 1, #versions do
      print(string.format("%s last written by version %s",
         plural(versions[index].count, "save was", "saves were"),
         versions[index].version))
   end

   if #summary.name_disagreements > 0 then
      print(string.format(
         "%d saves disagree with their folder about their own name",
         #summary.name_disagreements))
      for index = 1, #summary.name_disagreements do
         local case = summary.name_disagreements[index]
         print(string.format("   folder %q, file %q",
            case.folder, tostring(case.in_file)))
      end
   end

   if #summary.troubled > 0 then
      print(string.format("%d saves could not be read", #summary.troubled))
      for index = 1, #summary.troubled do
         print(string.format("   %s: %s",
            summary.troubled[index].game, summary.troubled[index].reason))
      end
   end
end
-- }}}

-- {{{ local function say_deep()
-- The measurements that need whole files opened. Announced before it starts,
-- because it is the expensive half and somebody watching deserves to know why
-- the program went quiet.
local function say_deep(home, rows)
   print("")
   print("opening orders files in full to measure record arrays - this reads"
      .. " every byte of them")

   local strides = {}
   local measured, failed = 0, 0

   for index = 1, #rows do
      local row = rows[index]
      if row.started and row.orders and #row.orders > 0 then
         local deep = survey.deep(row)
         if deep and deep.stride then
            measured = measured + 1
            strides[deep.stride] = (strides[deep.stride] or 0) + 1
            print(string.format(
               "%s: %d records at stride %d plus name, %.1f%% of %d bytes placed,"
               .. " first is %s",
               row.game, deep.count, deep.stride, deep.placed * 100, deep.size,
               deep.first or "unnamed"))
         else
            failed = failed + 1
         end
      end
   end

   print("")
   print(string.format("%s measured, %d had no measurable array",
      plural(measured, "orders file"), failed))

   local ranked = {}
   for stride, count in pairs(strides) do
      ranked[#ranked + 1] = { stride = stride, count = count }
   end
   table.sort(ranked, function(left, right) return left.count > right.count end)
   for index = 1, #ranked do
      print(string.format("stride %d appeared in %s",
         ranked[index].stride, plural(ranked[index].count, "file")))
   end

   if #ranked > 1 then
      print("more than one stride was found across the collection, which is"
         .. " worth understanding before anything relies on a single number")
   end
end
-- }}}

-- {{{ function command.run()
function command.run(project_directory, arguments)
   input.configure(project_directory)
   local scratch = input.ensure_scratch()
   narrator.open(scratch, "survey")
   narrator.quiet(true)

   local deep = false
   local home = nil
   for index = 1, #arguments do
      if arguments[index] == "--deep" then
         deep = true
      else
         home = arguments[index]
      end
   end

   if not home then
      local game, reason = input.game()
      if not game then
         print("cannot read input/game: " .. reason)
         print("either fill it in, or give this command a Dominions folder"
            .. " as an argument")
         return 1
      end
      home = game.home
   end

   narrator.say("surveying " .. home)
   print(string.format("surveying %s", home))
   print("")

   local rows, seconds = survey.collection(home, say_row)
   local summary = survey.summarise(rows)
   say_summary(summary, seconds)

   if deep then
      say_deep(home, rows)
   else
      print("")
      print("pass --deep to also open orders files and measure their record"
         .. " arrays")
   end

   narrator.close()
   return 0
end
-- }}}

return command
