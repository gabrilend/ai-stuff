#!/usr/bin/env luajit
-- 096-test-watching-and-power.lua
--
-- Checks the two tools that let a machine be inspected from outside while it
-- does things nobody can inspect from inside: naming code the model wrote
-- (703), and cutting the power at a chosen instant (704).
--
-- usage:
--   luajit 096-test-watching-and-power.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local ffi = require("ffi")

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
  io.flush()
end
-- }}}

-- {{{ local function run_one(command)
local function run_one(command)
  local ok, _, code = os.execute(command)
  return (ok == true or ok == 0), code
end
-- }}}

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

say("")
say("  watching what it wrote, and cutting the power on purpose")
say("  " .. string.rep("-", 58))
say("")

local watching = dofile(DIR .. "/src/094-watch-what-it-wrote.lua")
local power = dofile(DIR .. "/src/095-cut-the-power.lua")

local passed, failed = 0, 0
local function check(what, ok, detail)
  if ok then
    passed = passed + 1
    say(string.format("  %-50s ok", what))
  else
    failed = failed + 1
    say(string.format("  %-50s WRONG", what))
    if detail then say("      " .. detail) end
  end
end

-- {{{ the naming problem
-- Pretend guest memory, and a machine that has built three things.
local memory = {}
local strings = {}
local function write(at, value) memory[at] = value end
local function read(at) return memory[at] or 0 end
local function read_string(at, bytes)
  return strings[at] and strings[at]:sub(1, bytes) or ""
end

local runner = { placed = {
  { name = "allocator", at = 0x41000, bytes = 220,
    text = "move a di\nadd a si\nreturn" },
  { name = "the thing that finds disks", at = 0x41100, bytes = 400,
    text = "set a 0\nagain:\nadd_number a 1\njump always again" },
  { name = "a small experiment", at = 0x41300, bytes = 64,
    text = "return" },
} }

local laid = watching.lay_out(runner, 0x50000, write)
for _, entry in ipairs(laid.strings) do strings[entry.at] = entry.text end

check("the machine's bookkeeping is written where a tool outside can find it",
      laid.at == 0x50000 and laid.ends_at > laid.at)

-- a tool outside has nothing to ask, so it scans
local found = watching.find_ledger(read, 0x4f000, 0x51000)
check("and a tool outside finds it by scanning, having nothing to ask",
      found == 0x50000, tostring(found))

local nothing = select(2, watching.find_ledger(read, 0x60000, 0x61000))
check("and says so plainly when there is nothing there",
      nothing ~= nil and nothing:find("built nothing yet") ~= nil, nothing)

local ledger = watching.read_ledger(read, read_string, found)
check("what it reads back is what the machine built",
      #ledger == 3 and ledger[1].name == "allocator"
      and ledger[2].name == "the thing that finds disks",
      ledger[1] and ledger[1].name)

check("including the text each program was made from",
      ledger[1].text == "move a di\nadd a si\nreturn", ledger[1].text)

-- THE ANSWER THE TICKET EXISTS FOR
local where = watching.where_am_i(ledger, 0x41120)
check("an address becomes a place inside something the machine wrote",
      where ~= nil and where.name == "the thing that finds disks"
      and where.into == 0x20, where and where.name)

check("and it says how far in, of how long",
      where.into == 32 and where.of == 400)

check("and carries the text, so what it was meant to be is readable",
      where.text:find("again:") ~= nil)

-- and it does not pretend to know which line
check("and does not pretend to know which line it is on",
      where.line == nil,
      "it guessed a line, which the loop watches make wrong")

local outside = select(2, watching.where_am_i(ledger, 0x99999))
check("an address outside everything it built says so",
      outside ~= nil and outside:find("engine, the firmware, or nowhere") ~= nil,
      outside)

-- and the places worth stopping at are exactly what it built
local stops = watching.break_when_it_runs(ledger)
check("where to break is exactly what the machine built",
      #stops == 3 and stops[1].at == 0x41000)

-- the stride is read rather than assumed, so a machine that changed its own
-- bookkeeping can still be walked by a tool built before it changed
local _, record_bytes = watching.offsets(watching.RECORD_SLOTS)
check("the record size is written down, so a tool need not assume it",
      read(0x50000 + watching.offsets(watching.LEDGER_SLOTS).stride)
      == record_bytes)
-- }}}

-- {{{ cutting the power
-- A pretend machine whose move-in window has TWO unrecoverable stretches,
-- because a sweep that assumes one boundary would find the first and miss
-- the second -- and the missed one is exactly the sort of thing that only
-- ever happens to somebody else's machine.
local WINDOW = 100000
local state = { at = 0 }

local function outcome_at(instruction)
  -- recoverable up to 20000; confused from 20000 to 35000; recoverable
  -- again; gone from 70000 to 80000; recoverable after.
  if instruction >= 20000 and instruction < 35000 then return "partial" end
  if instruction >= 70000 and instruction < 80000 then return "gone" end
  return "recovered"
end

local sweep = power.new({
  snapshot = function() return { at = 0 } end,
  restore = function(from) state.at = from.at end,
  run_for = function(instructions) state.at = instructions end,
  kill = function() state.killed_at = state.at end,
  restart = function() return outcome_at(state.killed_at) end,
})

local result = power.sweep(sweep, { window = WINDOW, samples = 32 })

check("the sweep finds more than one band",
      #result.bands >= 4, #result.bands .. " bands")

local kinds = {}
for _, band in ipairs(result.bands) do kinds[band.outcome] = true end
check("and finds both kinds of failure, not only the first",
      kinds.partial and kinds.gone,
      "a sweep that assumed one boundary would have missed one of them")

-- the edges are found precisely, not approximately
local first_bad = nil
for _, band in ipairs(result.bands) do
  if band.outcome == "partial" and not first_bad then first_bad = band end
end
check("and narrows the edges to the instruction",
      first_bad ~= nil and math.abs(first_bad.from - 20000) <= 1,
      first_bad and ("starts at " .. first_bad.from))

check("in far fewer runs than the window is long",
      sweep.runs < WINDOW / 100, sweep.runs .. " runs over " .. WINDOW)

local said = power.say_the_shape(result)
check("and the shape is reported rather than a pass or a fail",
      said:find("to") ~= nil and said:find("came back") ~= nil)

check("and the confused band is called out on its own",
      said:find("WORTH SAYING TWICE") ~= nil
      and said:find("act on what it has") ~= nil,
      "coming back confused is worse than not coming back, and was not said")

check("and what the sampling could still be hiding is said",
      said:find("could sit entirely between two samples") ~= nil)
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not cover:")
say("    - a real emulator's snapshots. The sweep here runs against a")
save = nil
say("      pretend machine whose answers are known, which tests the sweeping")
say("      and not the snapshotting. Pointing it at a real one is")
say("      configuration and belongs with the move-in it exists to test,")
say("      which is 601's.")
say("    - which line of its own text a machine is on. The assembler inserts")
say("      loop watches, so the instruction count and the line count drift,")
say("      and the tool says nothing rather than guessing.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("watching and power: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
