#!/usr/bin/env luajit
-- 106-test-the-watchdog.lua
--
-- Checks that a read which never comes back takes one core down rather than
-- the machine, and that what the machine was doing survives the reset.
--
-- The bench of devices that can die already models a bus that never answers
-- (092), so the hang here is a real modelled hang rather than a value being
-- read as one.
--
-- usage:
--   luajit 106-test-the-watchdog.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

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
say("  the read that never answers, and the countdown that survives it")
say("  " .. string.rep("-", 62))
say("")

local watchdog_module = dofile(DIR .. "/src/105-the-watchdog.lua")
local bench_module = dofile(DIR .. "/src/092-devices-that-die.lua")
local hazards = dofile(DIR .. "/src/020-forbidden-registers.lua")
local hands = dofile(DIR .. "/src/064-the-hands.lua")

local passed, failed = 0, 0
local function check(what, ok, detail)
  if ok then
    passed = passed + 1
    say(string.format("  %-52s ok", what))
  else
    failed = failed + 1
    say(string.format("  %-52s WRONG", what))
    if detail then say("      " .. detail) end
  end
end

-- {{{ a machine with four cores, a timer, and somewhere to leave a note
local reset = { happened = 0, which = nil }
local notes = {}

local function make_machine(with_note)
  local armed = {}
  return watchdog_module.new({
    cores = 4, patience = 100,
    arm = function(core) armed[core] = true end,
    disarm = function(core) armed[core] = nil end,
    -- one slot per core, addressed by core number, because a core that is
    -- still running would otherwise overwrite the last words of the one
    -- that hung
    note = with_note and function(core, text)
      notes[core] = text
      return core
    end or nil,
  }), armed
end

local watchdog, armed = make_machine(true)

local bench = bench_module.new({ hazards = hazards })
bench_module.attach(bench, {
  name = "answers", base = 0x1000, length = 0x100, registers = { [0] = 0x4321 },
})
bench_module.attach(bench, {
  name = "never-answers", base = 0x2000, length = 0x100, condition = "hangs",
})
-- }}}

-- {{{ an ordinary read comes back, and the countdown stops
local value, why, how = watchdog_module.attempt(watchdog, 0,
  "reading the identity of the part at 0x1000, expecting a maker number",
  function() return bench_module.read(bench, "answers", 0) end)

check("a read that answers comes back with its value", value == 0x4321, why)
check("and the countdown was stopped afterwards", armed[0] == nil)
-- core zero's note slot is numbered zero, so this asks whether a slot was
-- reported rather than whether the number is truthy
check("and the note was written before it, not after",
      how ~= nil and how.note_at == 0, how and tostring(how.note_at))
-- }}}

-- {{{ the note goes first, and a machine with nowhere to write one may not read
local blind = make_machine(false)
local refused = select(2, watchdog_module.attempt(blind, 0, "anything",
  function() return 1 end))
check("a machine with nowhere to leave a note refuses the read",
      refused ~= nil and refused:find("next start learns nothing") ~= nil,
      refused)
check("and counts it, rather than letting it look like a read that failed",
      blind.unwitnessed == 1)
-- }}}

-- {{{ the read that never answers
-- The bench returns nothing at all for this one -- not all-ones, nothing --
-- which is what a stalled processor gives back.
local hung, hung_why = watchdog_module.attempt(watchdog, 1,
  "reading 0x2000, expecting a device identity",
  function() return bench_module.read(bench, "never-answers", 0) end)

check("a read that never answers hands back no value",
      hung == nil, "it produced a value, which a stalled core cannot")

check("and the note it left says what it was about to do",
      notes[#notes]:find("0x2000") ~= nil
      and notes[#notes]:find("expecting") ~= nil, notes[#notes])
-- }}}

-- {{{ one core, not the machine
-- The core that stalled is one worker. The others are untouched and can
-- still do the next read.
local other, other_why = watchdog_module.attempt(watchdog, 2,
  "reading the part that answers, from a different core",
  function() return bench_module.read(bench, "answers", 0) end)
check("another core is unaffected and keeps working", other == 0x4321, other_why)

local nonexistent = select(2, watchdog_module.attempt(watchdog, 9, "x",
  function() return 1 end))
check("a core this machine does not have is refused, by count",
      nonexistent ~= nil and nonexistent:find("has 4") ~= nil, nonexistent)
-- }}}

-- {{{ what the next start reads
local next_start = watchdog_module.what_was_it_doing(watchdog, function(core)
  return notes[core]
end)
check("the next start can read what every core was doing",
      next_start ~= nil and next_start.per_core[1] ~= nil
      and next_start.per_core[1]:find("0x2000") ~= nil,
      next_start and tostring(next_start.per_core[1]))

-- and the account of the core that hung is not overwritten by a core that
-- kept working, which is exactly what one note per machine would have done:
-- the survivor's account replacing the casualty's
check("and a working core does not overwrite the hung one's account",
      next_start.per_core[1]:find("0x2000") ~= nil
      and next_start.per_core[2]:find("different core") ~= nil,
      "the survivor's account replaced the casualty's")
check("and is told what that means rather than being left to infer",
      next_start.means:find("what it was doing when it went") ~= nil)

local nothing_written = select(2, watchdog_module.what_was_it_doing(watchdog,
  function() return "" end))
check("and a start with nothing written says so plainly",
      nothing_written ~= nil and nothing_written:find("nothing dangerous") ~= nil,
      nothing_written)
-- }}}

-- {{{ as a hand, so the machine can ask how it is protected
local catalogue = hands.new()
hands.offer_the_catalogue(catalogue)
watchdog_module.offer(catalogue, hands, watchdog)

local asked = hands.answer(catalogue, hands.find(catalogue, "<call countdowns>"))
check("the machine can ask how it is protected",
      asked.ok and asked.text:find("one per core") ~= nil)
check("and is told that recovery is a reset rather than an interrupt",
      asked.ok and asked.text:find("RESET rather than interrupted") ~= nil,
      "a machine expecting to be interrupted would wait to be resumed")
-- }}}

say("")
say("  " .. string.rep("-", 62))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this cannot show on a host:")
say("    - the reset itself. Here the hanging read returns nothing and the")
say("      caller carries on; on a bare machine the core stops inside the")
say("      instruction and nothing below the read ever runs, which is why")
say("      the note rather than the return value is what matters.")
say("    - that a real timer fires. Arming and disarming are handed in, and")
say("      on a real board they are a device that must itself be operated --")
say("      the one circle in this design that opens, because timers are")
say("      usually reachable through a standard interface.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("the watchdog: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
