-- 031-make-them-all.lua
--
-- Every character in a chosen set, made at once, with a report at the end that
-- says what happened to all of them.
--
-- For a general: this is the point of the project. Everything before it makes
-- one recipe. This makes all of them, and makes them without a person choosing
-- which -- which is the whole difference between a demonstration and a learning
-- material.
--
--   luajit src/031-make-them-all.lua --grade 1
--   luajit src/031-make-them-all.lua --jlpt 5 --workers 8
--   luajit src/031-make-them-all.lua --frequent 500
--   luajit src/031-make-them-all.lua --chars 木火水
--   luajit src/031-make-them-all.lua --all
--   luajit src/031-make-them-all.lua --phrase 時間=time,an hour
--   luajit src/031-make-them-all.lua --phrases
--
-- Add --out DIR to put the set somewhere other than the RAM scratch area.

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local records = project.load("019-the-kanji-record")
local one = project.load("030-make-one-kanji")
local workflow = project.load("029-the-workflow-for-one-kanji")
local heat = project.load("031a-when-the-machine-runs-hot")
local phrases = project.load("019a-a-phrase-is-a-record-too")

local M = {}

-- {{{ M.processors(settings)
-- How many workers this machine should run.
--
-- Not simply how many processors it has. Taking every core is what makes a
-- machine unresponsive while a batch runs and holds the processor at the top of
-- its thermal range for as long as the run takes -- and the last two cores buy
-- far more comfort than they buy speed. `031a` works out the number and
-- explains the reserve.
function M.processors(settings)
  return (heat.workers(settings))
end
-- }}}

-- {{{ M.shard(chosen, index, howmany)
-- One worker's share of the set.
--
-- Strided rather than blocked: taking every nth character means a worker that
-- happens to draw several very crowded characters does not become the one
-- everybody else waits for. Blocks would hand one worker a run of neighbouring
-- characters, and neighbouring characters are related, so their costs are
-- related too.
function M.shard(chosen, index, howmany)
  local mine = {}
  for position = index + 1, #chosen, howmany do
    mine[#mine + 1] = chosen[position]
  end
  return mine
end
-- }}}

-- {{{ shell_quote(text)
local function shell_quote(text)
  return "'" .. tostring(text):gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ M.work(chosen, store, settings, options)
-- One worker's actual job: make its characters, write down what happened.
--
-- A character that fails, fails alone. One malformed path must not end a run --
-- it is recorded with its reason and the batch goes on. A run that stops on
-- character four hundred of six thousand has wasted the four hundred.
function M.work(chosen, store, settings, options)
  local report = {
    asked = #chosen, made = 0, failed = {}, bytes = 0,
    worlds = {}, kinds = {}, unglossed = {}, crowded = 0, disputed = {},
    peak = 0, rested = 0,
  }
  -- Between characters, the worker looks at how hot the machine is getting and
  -- rests if it is climbing. Nil on a machine that will not say, in which case
  -- the run simply goes as fast as it can -- resting against a temperature
  -- nobody measured is a slower run bought for nothing (`307`).
  local governor = heat.governor(settings)
  for _, record in ipairs(chosen) do
    local ok, done, why = pcall(one.make, record, store, settings, options)
    if not ok then
      report.failed[#report.failed + 1] =
        { character = record.character, why = tostring(done) }
    elseif not done then
      report.failed[#report.failed + 1] =
        { character = record.character, why = tostring(why) }
    else
      report.made = report.made + 1
      report.bytes = report.bytes + done.bytes
      report.worlds[done.world] = (report.worlds[done.world] or 0) + 1
      report.kinds[done.kind] = (report.kinds[done.kind] or 0) + 1
      report.crowded = report.crowded + (done.crowded or 0)
      for _, element in ipairs(done.unglossed or {}) do
        report.unglossed[element] = (report.unglossed[element] or 0) + 1
      end
      if record.stroke_count_disputed then
        report.disputed[#report.disputed + 1] = record.character
      end
    end
    if governor then governor.consider() end
  end
  if governor then
    local watched = governor.report()
    report.peak = watched.peak
    report.rested = watched.rested
  end
  return report
end
-- }}}

-- {{{ M.write_shard_report(report, path)
-- A worker's findings, as flat lines for the parent to read.
--
-- Through a file rather than through what the worker prints, because several
-- workers printing at once interleave, and parsing that would mean writing a
-- parser for a format nobody designed. The file lives in the RAM tier.
function M.write_shard_report(report, path)
  local lines = {}
  local function line(...) lines[#lines + 1] = table.concat({ ... }, "\t") end
  line("asked", report.asked)
  line("made", report.made)
  line("bytes", report.bytes)
  line("crowded", report.crowded)
  line("peak", string.format("%.1f", report.peak or 0))
  line("rested", string.format("%.2f", report.rested or 0))
  for world, count in pairs(report.worlds) do line("world", world, count) end
  for kind, count in pairs(report.kinds) do line("kind", kind, count) end
  for element, count in pairs(report.unglossed) do line("nopicture", element, count) end
  for _, failure in ipairs(report.failed) do
    -- a reason can run to several lines and the format is one record per line
    line("failed", failure.character, (failure.why:gsub("[\r\n\t]+", " ")))
  end
  for _, character in ipairs(report.disputed) do line("disputed", character) end
  project.write_file(path, table.concat(lines, "\n") .. "\n")
end
-- }}}

-- {{{ M.read_shard_reports(paths)
-- Every worker's findings, added up.
function M.read_shard_reports(paths)
  local total = {
    asked = 0, made = 0, bytes = 0, crowded = 0, peak = 0, rested = 0,
    failed = {}, worlds = {}, kinds = {}, unglossed = {}, disputed = {},
  }
  local missing = {}
  for _, path in ipairs(paths) do
    local text = project.read_file(path)
    if not text then
      missing[#missing + 1] = path
    else
      for row in text:gmatch("([^\n]+)") do
        local fields = {}
        for field in (row .. "\t"):gmatch("([^\t]*)\t") do
          fields[#fields + 1] = field
        end
        local kind = fields[1]
        if kind == "asked" then total.asked = total.asked + tonumber(fields[2])
        elseif kind == "made" then total.made = total.made + tonumber(fields[2])
        elseif kind == "bytes" then total.bytes = total.bytes + tonumber(fields[2])
        elseif kind == "crowded" then total.crowded = total.crowded + tonumber(fields[2])
        elseif kind == "peak" then
          local degrees = tonumber(fields[2]) or 0
          if degrees > total.peak then total.peak = degrees end
        elseif kind == "rested" then
          total.rested = total.rested + (tonumber(fields[2]) or 0)
        elseif kind == "world" then
          total.worlds[fields[2]] = (total.worlds[fields[2]] or 0) + tonumber(fields[3])
        elseif kind == "kind" then
          total.kinds[fields[2]] = (total.kinds[fields[2]] or 0) + tonumber(fields[3])
        elseif kind == "nopicture" then
          total.unglossed[fields[2]] = (total.unglossed[fields[2]] or 0)
                                       + tonumber(fields[3])
        elseif kind == "failed" then
          total.failed[#total.failed + 1] = { character = fields[2], why = fields[3] }
        elseif kind == "disputed" then
          total.disputed[#total.disputed + 1] = fields[2]
        end
      end
    end
  end
  return total, missing
end
-- }}}

-- {{{ M.describe(total, elapsed, out_dir, settings)
-- The run, as lines of text.
--
-- Not decoration. This is the only view anybody has of what a run over six
-- thousand characters did, and every line of it is a gap being announced -- a
-- run that quietly produced five thousand images out of six thousand asked for
-- is a run that looks like a success.
function M.describe(total, elapsed, out_dir, settings)
  local lines = {}
  local function say(text) lines[#lines + 1] = text end

  say(string.format("%d asked for, %d made, %d could not be",
                    total.asked, total.made, #total.failed))
  say(string.format("%.1f MB written in %.1f seconds",
                    total.bytes / 1048576, elapsed))
  say("into " .. out_dir)
  if total.peak and total.peak > 0 then
    say(string.format("the processor peaked at %.1f degrees; the workers rested " ..
                      "%.0f seconds between them to let it cool",
                      total.peak, total.rested))
  end

  if #total.failed > 0 then
    say("")
    say("could not be made:")
    for index = 1, math.min(20, #total.failed) do
      say(string.format("  %s  %s", total.failed[index].character,
                        total.failed[index].why:sub(1, 96)))
    end
    if #total.failed > 20 then
      say(string.format("  and %d more", #total.failed - 20))
    end
  end

  local kinds = {}
  for name, count in pairs(total.kinds or {}) do
    kinds[#kinds + 1] = name .. " " .. count
  end
  table.sort(kinds)
  if #kinds > 0 then say("of which: " .. table.concat(kinds, ", ")) end

  local worlds = {}
  for name, count in pairs(total.worlds) do
    worlds[#worlds + 1] = { name = name, count = count }
  end
  table.sort(worlds, function(a, b) return a.count > b.count end)
  if #worlds > 0 then
    say("")
    say("which world each character landed in:")
    for _, row in ipairs(worlds) do
      say(string.format("  %-10s %5d  %5.1f%%", row.name, row.count,
                        row.count / math.max(total.made, 1) * 100))
    end
    -- A distribution nobody looks at is a trigger list nobody knows is thin.
    if #worlds > 0 and worlds[1].count > total.made * 0.6 then
      say("  NOTE: one world has taken most of the set. The trigger lists in")
      say("        src/024 are too narrow, and most of these pictures are")
      say("        going to look like each other.")
    end
  end

  local queue = {}
  for element, count in pairs(total.unglossed) do
    queue[#queue + 1] = { element = element, count = count }
  end
  table.sort(queue, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.element < b.element
  end)
  if #queue > 0 then
    say("")
    say("pieces that appeared and could not be pictured, commonest first --")
    say("this is the queue for the written half of src/023:")
    local shown = {}
    for index = 1, math.min(12, #queue) do
      shown[#shown + 1] = queue[index].element .. " (" .. queue[index].count .. ")"
    end
    say("  " .. table.concat(shown, "  "))
  end

  if total.crowded > 0 then
    say("")
    say(string.format("%d arrows had to be shortened because their character " ..
                      "had nowhere to put them", total.crowded))
  end

  if #total.disputed > 0 then
    say("")
    say(string.format("%d characters have a stroke count the two archives " ..
                      "disagree about", #total.disputed))
  end

  say("")
  say("this set assumes, and nothing here could check:")
  for _, note in ipairs(workflow.assumptions(settings)) do
    say("  - " .. note)
  end

  return lines
end
-- }}}

-- {{{ selection_arguments(options)
-- The part of this run's command line that says which characters.
--
-- Passed through to each worker unchanged, so that a worker selects from the
-- same set the parent did rather than being handed a list -- six thousand
-- characters on a command line is not a command line.
local function selection_arguments(options)
  local parts = {}
  for _, name in ipairs({ "phrase", "phrases" }) do
    if options[name] ~= nil then
      if options[name] == true then
        parts[#parts + 1] = "--" .. name
      else
        parts[#parts + 1] = "--" .. name .. " " .. shell_quote(options[name])
      end
    end
  end
  for _, name in ipairs(records.selector_names()) do
    if options[name] ~= nil then
      if options[name] == true then
        parts[#parts + 1] = "--" .. name
      else
        parts[#parts + 1] = "--" .. name .. " " .. shell_quote(options[name])
      end
    end
  end
  return table.concat(parts, " ")
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("031-make-them-all")
  local store = records.store()

  -- Words first, since asking for one is more specific than asking for a set
  -- of characters and nobody means both at once.
  local chosen, how = phrases.select(store, options), "phrases"
  if not chosen then
    chosen, how = records.select(store, options)
  end
  if not chosen then
    io.write("say which characters to make. one of:\n")
    for _, name in ipairs(records.selector_names()) do
      io.write("  --", name, "\n")
    end
    io.write("  --phrase 時間=time,an hour\n")
    io.write("  --phrases              (everything in input/phrases.lua)\n")
    os.exit(1)
  end

  local out_dir = options.out or project.path(settings.batch.out_dir)
  project.ensure_directory(out_dir)

  -- A worker run. Does its share, writes its findings, says nothing.
  if options.worker then
    local index = tonumber(options.worker)
    local howmany = tonumber(options.workers) or 1
    local mine = M.shard(chosen, index, howmany)
    local report = M.work(mine, store, settings, { out = out_dir })
    M.write_shard_report(report, options.report)
    return
  end

  local howmany = tonumber(options.workers) or settings.batch.workers
  if not howmany or howmany < 1 then howmany = M.processors(settings) end
  if howmany > #chosen then howmany = #chosen end
  if howmany < 1 then howmany = 1 end

  local now = heat.temperature()
  io.write(string.format("%s selected %d characters; %d workers%s\n",
                         how, #chosen, howmany,
                         now and string.format("; the processor is at %.0f degrees "
                           .. "and the run will rest above %d", now,
                           settings.heat.warm) or ""))
  io.flush()

  local started = os.time()
  local here = project.here()
  local shard_dir = project.scratch("shards")
  os.execute('rm -rf "' .. shard_dir .. '"')
  project.ensure_directory(shard_dir)

  -- Started by opening a pipe to each, which begins the process; waited for by
  -- reading each pipe to its end, which cannot finish until that process does.
  -- No shell backgrounding, no chained commands, and no polling.
  local handles, paths = {}, {}
  for index = 0, howmany - 1 do
    local path = string.format("%s/report-%d.tsv", shard_dir, index)
    paths[#paths + 1] = path
    -- At the back of the queue, so a run that is working the processor hard
    -- never also makes the machine feel broken to whoever is using it.
    local command = string.format(
      "%sluajit %s --dir %s %s --worker %d --workers %d --out %s --report %s 2>&1",
      heat.nice_prefix(settings),
      shell_quote(here .. "/031-make-them-all.lua"),
      shell_quote(project.root()), selection_arguments(options),
      index, howmany, shell_quote(out_dir), shell_quote(path))
    handles[#handles + 1] = { pipe = io.popen(command), index = index }
  end

  for _, handle in ipairs(handles) do
    local said = handle.pipe:read("*a")
    handle.pipe:close()
    if said and said:match("%S") then
      io.write("worker ", handle.index, " said:\n", said, "\n")
    end
  end

  local total, missing = M.read_shard_reports(paths)
  local elapsed = os.difftime(os.time(), started)

  -- A worker that died without writing its findings took its share of the set
  -- with it, and the totals below would be short by that share while looking
  -- perfectly consistent.
  if #missing > 0 then
    io.write(string.format("\n%d of %d workers left no report. Their share of " ..
             "the set is missing\nfrom everything below.\n", #missing, howmany))
  end

  -- The partition has to be exactly right: an off-by-one in the stride silently
  -- drops or duplicates characters, and with six thousand of them nobody sees.
  if total.asked ~= #chosen then
    io.write(string.format("\nWARNING: %d characters were asked for and the " ..
             "workers between them\naccounted for %d. The shards do not " ..
             "partition the set.\n", #chosen, total.asked))
  end

  io.write("\n")
  local lines = M.describe(total, elapsed, out_dir, settings)
  for _, line in ipairs(lines) do io.write(line, "\n") end
  project.write_file(out_dir .. "/report.txt", table.concat(lines, "\n") .. "\n")
  project.goodbye("031-make-them-all", lines)
end
-- }}}

if arg and arg[0] and arg[0]:find("031%-make%-them%-all") then
  main(arg)
end

return M
