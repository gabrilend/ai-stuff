#!/usr/bin/env luajit
-- 075-test-run-what-it-wrote.lua
--
-- Checks the hand the whole project rests on: assembly the machine wrote,
-- turned into instructions, placed, and run -- and most of all, a program
-- that would never return being noticed and stopped.
--
-- For a general: a small program is written the way the machine would write
-- it, assembled, put in real memory and executed on this processor. Then a
-- program that loops forever is run, and the count the assembler hid at the
-- bottom of its loop is what takes control back.
--
-- usage:
--   luajit 075-test-run-what-it-wrote.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local ffi = require("ffi")

ffi.cdef[[
  void *mmap(void *addr, size_t length, int prot, int flags, int fd, size_t offset);
  int munmap(void *addr, size_t length);
]]

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
say("  running what it wrote, and stopping what will not stop")
say("  " .. string.rep("-", 58))
say("")

local assembler = dofile(DIR .. "/src/073-the-assembler.lua")
local runner_module = dofile(DIR .. "/src/074-run-what-it-wrote.lua")
local touch = dofile(DIR .. "/src/071-touch-memory.lua")
local hands = dofile(DIR .. "/src/064-the-hands.lua")

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

-- {{{ real memory this processor will execute from
-- Not a pretend region this time: the instructions have to actually run, so
-- the memory has to actually be executable. On a bare machine every page is;
-- here it must be asked for.
local SIZE = 0x10000
local page = ffi.C.mmap(nil, SIZE, 7, 0x22, -1, 0)   -- read, write, execute
if page == nil or tonumber(ffi.cast("intptr_t", page)) == -1 then
  say("  this host would not give out executable memory; nothing was tested,")
  say("  which is not the same as nothing being wrong.")
  os.exit(1)
end
local BASE = tonumber(ffi.cast("intptr_t", page))
local bytes = ffi.cast("uint8_t *", page)

local function read(address, width)
  local value = 0
  for offset = width - 1, 0, -1 do
    value = value * 256 + bytes[address - BASE + offset]
  end
  return value
end

local function write(address, width, value)
  for offset = 0, width - 1 do
    bytes[address - BASE + offset] = math.floor(value / 256 ^ offset) % 256
  end
end

local memory = touch.new({
  usable = { { base = BASE, length = SIZE } },
  ours = { { base = BASE, length = 0x100, what = "engine" } },
  read = read, write = write,
})

-- the machine-wide magnitude, and the room programs go in
local MAGNITUDE = BASE + 0x200
local PROGRAMS = BASE + 0x1000
-- }}}

-- {{{ how this machine transfers control
-- A stepped call rather than a plain one. The written program is not called
-- directly -- it is called, and between its loop iterations the magnitude is
-- looked at, which is the whole escape.
--
-- On this host that means running it in short bursts: the emission the
-- assembler inserted increments the magnitude, and a small watcher
-- instruction sequence is what actually stops it. Here the watching is done
-- by patching the program's own emission target, which stands in for the
-- interrupt this machine does not have.
ffi.cdef[[ typedef int64_t (*written_program)(int64_t, int64_t); ]]

local function transfer(at, arguments, runner)
  local first = arguments[1] or 0
  local second = arguments[2] or 0

  -- The escape: the emission writes the magnitude, and the program is only
  -- allowed to run while it stays near ordinary. A processor with an
  -- interrupt would check between instructions; here the emission itself is
  -- made to stop the program, by having the assembler count up to a value
  -- the program's own loop condition cannot pass.
  --
  -- Rather than pretend to interrupt, the count is checked afterwards: a
  -- program that ran away is one whose magnitude crossed the threshold, and
  -- crossing it is what the stopping would have acted on. What this cannot
  -- show on a host is the taking of control itself, which needs the bare
  -- machine -- and that is said in the summary rather than glossed.
  local callable = ffi.cast("written_program", ffi.cast("void *", at))
  local ok, value = pcall(callable, first, second)
  if not ok then return nil, "it came apart: " .. tostring(value) end

  local still_fine = runner_module.watch(runner)
  if not still_fine then return nil, "ran away" end
  return tonumber(value)
end

local runner = runner_module.new({
  memory = memory,
  somewhere = PROGRAMS,
  room = SIZE - 0x1000,
  magnitude_at = MAGNITUDE,
  run = transfer,
  threshold = 15,
})
-- }}}

-- {{{ something small and verifiable, end to end
-- A function that adds two numbers, before anything depends on this working.
local adder = assembler.new({ emit_at = MAGNITUDE })
adder:instruct("move", "a", "di")       -- the first argument
adder:instruct("add", "a", "si")        -- plus the second
adder:instruct("return")

local adder_bytes, _, adder_report = assembler.assemble(adder)
local at, refusal = runner_module.place(runner, "add two numbers", adder_bytes,
                                        "move a di\nadd a si\nreturn")
check("a written program can be placed", at ~= nil, refusal)

local sum = runner_module.call(runner, at, { 20, 22 })
check("and it runs, and gives the right answer", sum == 42, tostring(sum))

local other = runner_module.call(runner, at, { -5, 5 })
check("and again, with different arguments", other == 0, tostring(other))

check("a program with no loop is watched nowhere",
      adder_report.back_edges == 0 and adder_report.emissions == 0)
-- }}}

-- {{{ a loop that ends
-- Counts down from a number and returns zero. A real loop, so a real
-- back-edge, so a real emission -- and it must still return.
local counter = assembler.new({ emit_at = MAGNITUDE })
counter:instruct("move", "a", "di")
counter:label("again")
counter:instruct("add_number", "a", -1)
counter:instruct("compare_number", "a", 0)
counter:jump("if_greater", "again")
counter:instruct("return")

local counter_bytes, _, counter_report = assembler.assemble(counter)
check("a loop is noticed and watched",
      counter_report.back_edges == 1 and counter_report.emissions == 1,
      counter_report.back_edges .. " back-edges, " .. counter_report.emissions
      .. " emissions")

local counter_at = runner_module.place(runner, "count down", counter_bytes,
                                       "a loop that ends")
local counted, count_trouble, how = runner_module.call(runner, counter_at, { 5 })
check("a loop that ends still ends", counted == 0, count_trouble)
check("and the magnitude moved while it ran, by one per turn",
      how ~= nil and how.magnitude == runner_module.ORDINARY + 5,
      how and tostring(how.magnitude))
-- }}}

-- {{{ the one that matters: a loop that does not end
-- The magnitude crosses the threshold, and that crossing is what a machine
-- with somewhere to take control back to would act on.
-- Bounded rather than truly endless, because a host cannot be rescued from
-- a genuine infinite loop and a test that hangs proves nothing. The bound is
-- far past the threshold, so the magnitude crosses long before the loop's
-- own condition would end it -- which is exactly the situation the escape
-- exists for.
local runaway = assembler.new({ emit_at = MAGNITUDE })
runaway:instruct("set", "a", 0)
runaway:label("forever")
runaway:instruct("add_number", "a", 1)
runaway:instruct("compare_number", "a", 100000)
runaway:jump("if_less", "forever")
runaway:instruct("return")

local runaway_bytes = assembler.assemble(runaway)
local runaway_at = runner_module.place(runner, "far too long", runaway_bytes,
                                       "a loop that goes on and on")
local ran, why = runner_module.call(runner, runaway_at, {})
check("a program that runs away is caught",
      ran == nil and why:find("did not come back") ~= nil, why)
check("and the machine says how far from ordinary it got",
      why ~= nil and why:find("from ordinary") ~= nil, why)
check("and counts that it had to stop one", runner.stopped == 1)
-- }}}

-- {{{ what escapes the emission, and is said rather than hidden
local unwatched = assembler.new({})       -- no magnitude to write to
unwatched:instruct("set", "a", 1)
unwatched:label("spin")
unwatched:jump("always", "spin")
local _, _, unwatched_report = assembler.assemble(unwatched)
check("a program assembled without a watch says it has none",
      unwatched_report.back_edges == 1 and unwatched_report.emissions == 0
      and unwatched_report.watched == false)
-- }}}

-- {{{ the rules of 203 still hold underneath
local onto_the_engine = runner_module.new({
  memory = memory, somewhere = BASE + 0x40, room = 0x100,
  magnitude_at = MAGNITUDE, run = transfer,
})
local blocked, blocked_why = runner_module.place(onto_the_engine, "over itself",
                                                 adder_bytes, "")
check("placing a program on top of the engine is refused",
      blocked == nil and blocked_why:find("goes quiet") ~= nil, blocked_why)

local too_big = runner_module.new({
  memory = memory, somewhere = PROGRAMS, room = 4,
  magnitude_at = MAGNITUDE, run = transfer,
})
local no_room = select(2, runner_module.place(too_big, "big", adder_bytes, ""))
check("and a program with nowhere to go says how much room there was",
      no_room ~= nil and no_room:find("bytes left") ~= nil, no_room)
-- }}}

-- {{{ as hands, from written text
local catalogue = hands.new()
hands.offer_the_catalogue(catalogue)
runner_module.offer(catalogue, hands, runner, assembler)

local written = "<call assemble double move a di\nadd a di\nreturn>"
-- the grammar takes whitespace-separated arguments, so a multi-line program
-- arrives as one argument only if it has no spaces; the hand is exercised
-- directly instead, which is what a real grammar for a real model would do.
local made = hands.answer(catalogue, {
  name = "assemble",
  arguments = { "double", "move a di\nadd a di\nreturn" },
})
check("the machine can ask for its writing to be assembled",
      made.ok and made.text:find("placed 'double'") ~= nil, made.text)

local placed_at = tonumber(made.text:match("0x%x+"))
local ran_it = hands.answer(catalogue, {
  name = "run", arguments = { string.format("0x%x", placed_at) },
})
check("and can ask for it to be run", ran_it.ok, ran_it.text)

local nonsense = hands.answer(catalogue, {
  name = "assemble", arguments = { "bad", "fly a di" },
})
check("a line it cannot read is refused, by line number",
      not nonsense.ok and nonsense.text:find("line 1") ~= nil, nonsense.text)

local asked_why = hands.answer(catalogue, {
  name = "why", arguments = { string.format("0x%x", placed_at) },
})
check("and the text a program came from is kept with it",
      asked_why.ok and asked_why.text:find("add a di", 1, true) ~= nil,
      asked_why.text)

local listing = hands.answer(catalogue, { name = "built", arguments = {} })
check("and the machine can ask what it has built",
      listing.ok and listing.text:find("count down", 1, true) ~= nil)
-- }}}

ffi.C.munmap(page, SIZE)

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not show:")
say("    - the taking of control itself. On this host a runaway is noticed")
say("      after it finishes rather than interrupted mid-loop, because a")
say("      hosted process cannot be stopped from inside itself. On the bare")
say("      machine the emission is what the stopping acts on, and 601 is")
say("      where that is proven rather than arranged.")
say("    - code that never came through this assembler. It carries no")
say("      emissions and escapes the watch entirely; an instruction budget")
say("      stepped one at a time is the fallback, and it needs a machine")
say("      that can single-step.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("running what it wrote: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
