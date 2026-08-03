#!/usr/bin/env luajit
-- 093-test-devices-that-die.lua
--
-- Checks the devices that can be destroyed, and -- more importantly -- checks
-- that a machine cannot tell a destroyed part from a busy one or an
-- unpowered one. Issues 702 and 702b.
--
-- For a general: the point of these devices is not that they die. It is that
-- they die the way real ones do, which is silently, ambiguously, and
-- sometimes long after the mistake. A test that proved the machine can always
-- tell what happened would be testing a machine nobody will ever have.
--
-- usage:
--   luajit 093-test-devices-that-die.lua [--dir ROOT]

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
say("  devices that die, and the confusion that leaves behind")
say("  " .. string.rep("-", 58))
say("")

local bench_module = dofile(DIR .. "/src/092-devices-that-die.lua")
local hazards = dofile(DIR .. "/src/020-forbidden-registers.lua")
local touch = dofile(DIR .. "/src/077-touch-the-hardware.lua")

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

-- {{{ a bench with the three-way confusion on it, all at once
local bench = bench_module.new({ hazards = hazards })

bench_module.attach(bench, {
  name = "healthy", base = 0x1000, length = 0x100,
  registers = { [0] = 0x1234 },
})
bench_module.attach(bench, {
  name = "busy", base = 0x2000, length = 0x100, condition = "busy",
  busy_until = 50, registers = { [0] = 0x2345 },
})
bench_module.attach(bench, {
  name = "unpowered", base = 0x3000, length = 0x100, condition = "unpowered",
  registers = { [0] = 0x3456 },
})
bench_module.attach(bench, {
  name = "fragile", base = 0x4000, length = 0x100,
  registers = { [0] = 0x4567 },
  fatal = {
    [0x40] = { kind = "voltage", any_value = true },
    [0x10] = { kind = "thermal", any_value = true, slowly = true, after = 500 },
  },
})
-- }}}

-- {{{ a live part answers, and the others do not
check("a part that is alive answers",
      bench_module.read(bench, "healthy", 0) == 0x1234)

check("a busy one does not", bench_module.read(bench, "busy", 0) == 0xffffffff)
check("an unpowered one does not either",
      bench_module.read(bench, "unpowered", 0) == 0xffffffff)
-- }}}

-- {{{ the write that ends it says nothing
local before = bench_module.read(bench, "fragile", 0)
bench_module.write(bench, "fragile", 0x40, 0xdeadbeef)
check("the write that destroys a part succeeds like any other",
      before == 0x4567,
      "the model warned the machine, which hardware does not do")

check("and afterwards the part is simply not there",
      bench_module.read(bench, "fragile", 0) == 0xffffffff)

-- THE CHECK THIS WHOLE FILE IS FOR: from inside, these are the same.
local dead = bench_module.what_the_machine_can_tell(bench, "fragile")
local busy = bench_module.what_the_machine_can_tell(bench, "busy")
local off = bench_module.what_the_machine_can_tell(bench, "unpowered")
check("a destroyed part is indistinguishable from a busy one",
      dead.answering == busy.answering,
      "the machine could tell them apart, which no real machine can")
check("and from an unpowered one", dead.answering == off.answering)
-- }}}

-- {{{ the read that never comes back
-- The one condition that is not like the others: every state above returns
-- something when asked. This one does not return at all.
bench_module.attach(bench, {
  name = "silent-bus", base = 0x6000, length = 0x100, condition = "hangs",
  registers = { [0] = 0x6789 },
})

local value, why = bench_module.read(bench, "silent-bus", 0)
check("a read that never comes back returns no value at all",
      value == nil and why == "never came back",
      "it handed back a value, which a stalled processor cannot do")

check("and it is not the same thing as reading all-ones",
      bench_module.read(bench, "unpowered", 0) == 0xffffffff
      and bench_module.read(bench, "silent-bus", 0) == nil,
      "a device holding all-ones and a bus that never answers were confused")

check("and the bench counts them, since nothing inside the machine could",
      bench.hung == 2, tostring(bench.hung))
-- }}}

-- {{{ death survives a power cycle, and the others do not
local came_back, still_gone = bench_module.power_cycle(bench)
check("switching it off and on brings back what was merely busy",
      #came_back == 3, table.concat(came_back, ", "))
-- The destroyed part AND the address nothing answers at both stay gone, for
-- different reasons that look identical from inside: one part was killed,
-- and the other was never there.
check("and does not bring back what cannot come back",
      #still_gone == 2 and still_gone[1] == "fragile"
      and still_gone[2] == "silent-bus",
      table.concat(still_gone, ", "))
check("which is what makes it a test rather than a forgiveness",
      bench_module.read(bench, "fragile", 0) == 0xffffffff)

-- and the busy one, having been cycled, now answers
check("and the busy one answers once it is no longer busy",
      bench_module.read(bench, "busy", 0) == 0x2345)
-- }}}

-- {{{ the slow death, which is the one that gets blamed on the wrong thing
local slow = bench_module.new({ hazards = hazards })
bench_module.attach(slow, {
  name = "cooking", base = 0x5000, length = 0x100,
  registers = { [0] = 0x5678 },
  fatal = { [0x10] = { kind = "thermal", any_value = true, slowly = true,
                       after = 500 } },
})

bench_module.write(slow, "cooking", 0x10, 0)
check("a part with its thermal protection switched off keeps working",
      bench_module.read(slow, "cooking", 0) == 0x5678,
      "it died at the moment of the mistake, which thermal damage does not")

bench_module.tick(slow, 100)
check("and is still working a while later",
      bench_module.read(slow, "cooking", 0) == 0x5678)

local presented = bench_module.tick(slow, 500)
check("and then stops, long after the thing that killed it",
      #presented == 1 and presented[1] == "cooking"
      and bench_module.read(slow, "cooking", 0) == 0xffffffff,
      "the damage never presented")

-- and by then the machine is doing something else, so nothing about the
-- moment of failure points at the write that caused it
local truth = bench_module.what_really_happened(slow)
check("and the truth records what killed it, where only a test can see",
      truth[1].killed_by ~= nil and truth[1].killed_by.kind == "thermal"
      and truth[1].killed_by.at < truth[1].died_at,
      "the record does not separate the mistake from the failure")
-- }}}

-- {{{ the hands of 205 are what a machine would actually touch it through
-- Which means the discipline and the dying are testable together: a machine
-- that follows the rules never reaches the fatal register, and one that does
-- not, does.
local notes = {}
local pretend_store = {
  devices = { { name = "disk", blocks = 64, block_bytes = 512, writable = true,
                read = function() return string.rep("\0", 512) end,
                write = function(block, text)
                  notes[#notes + 1] = text return true
                end } },
}
local keep = dofile(DIR .. "/src/076-keep-something.lua")
local store = keep.new(pretend_store)

local bench_two = bench_module.new({ hazards = hazards })
bench_module.attach(bench_two, {
  name = "fragile", base = 0x4000, length = 0x100,
  registers = { [0] = 0x4567 },
  fatal = { [0x40] = { kind = "voltage", any_value = true } },
})

local hardware = touch.new({
  enumerate = function()
    return { { name = "fragile", slot = 1, vendor = 0x1111, part = 0x2222,
               class = "something fragile",
               registers = { { base = 0x4000, length = 0x100 } },
               interrupt = -1,
               destroying = { [0x40] = "voltage" } } }
  end,
  read = function(device, offset) return bench_module.read(bench_two, device.name, offset) end,
  write = function(device, offset, width, value)
    bench_module.write(bench_two, device.name, offset, value)
  end,
  store = store, keep = keep, note_on = "disk", note_at = 1,
})
touch.look(hardware)

-- a machine that follows the discipline never gets there
local refused = select(2, touch.poke(hardware, "fragile", 0x40, 4, 0xffff,
                                     { expecting = "more speed" }))
check("a machine following the discipline never reaches the fatal register",
      refused ~= nil and bench_module.read(bench_two, "fragile", 0) == 0x4567,
      "the part died despite the refusal")

-- and one that opens it, and is wrong about what the register does, kills it
touch.confirm(hardware, "voltage", "a description that was read and confirmed")
touch.poke(hardware, "fragile", 0x40, 4, 0xffff,
           { expecting = "the regulator changes and the part keeps working" })
check("and one that opens it and is wrong about it kills the part",
      bench_module.read(bench_two, "fragile", 0) == 0xffffffff)

check("but the note it wrote first is still there to be read",
      #notes > 0 and notes[#notes]:find("fragile") ~= nil,
      "nothing was written down before the write that ended it")
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this proves, and what it deliberately does not:")
say("    - it proves the discipline is testable: a machine that follows the")
say("      rules survives a bench full of things that end permanently, and")
say("      one that does not, does not.")
say("    - it does NOT prove a machine can work out what happened. It")
say("      cannot, and no version of this can be built where it can --")
say("      docs/003a names that as honestly hard, and the three-way")
say("      confusion here is that hardness made testable rather than")
say("      argued about.")
say("    - and these are still described devices. A real board is full of")
say("      parts nobody wrote down, and a machine exploring one of those")
say("      passes everything here while destroying hardware.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("devices that die: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
