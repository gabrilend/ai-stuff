#!/usr/bin/env luajit
-- 072-test-touch-memory.lua
--
-- Checks the memory hands. It used to check one refusal above all -- that a
-- machine could not overwrite itself. That refusal is gone; what is checked
-- now is that the write happens AND that the machine is told, which is what
-- lets it reload itself from disk. Formerly: that a machine
-- cannot write over its own mind. Everything else here is recoverable by
-- writing more software; that one is not.
--
-- The memory is pretend -- a region on the host with the same rules applied
-- to it -- because what is being tested is the rules, not the three
-- instructions underneath them.
--
-- usage:
--   luajit 072-test-touch-memory.lua [--dir ROOT]

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
say("  touching memory, and the one thing it will not touch")
say("  " .. string.rep("-", 58))
say("")

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

-- {{{ a pretend machine
-- A megabyte at a pretend physical base, with the engine and weights sitting
-- inside it exactly as they would on a real board.
local BASE = 0x100000
local SIZE = 0x100000
local region = ffi.new("uint8_t[?]", SIZE)

-- a device register: an address that does not hold what was written to it,
-- because a real bus is full of them and pretending otherwise would test a
-- machine that does not exist.
local DEVICE = BASE + 0x80000
local device_value = 0

local function read(address, width)
  if address >= DEVICE and address < DEVICE + 4 then
    -- reads back a fixed pattern regardless of what was poked at it
    return 0xd0d0d0d0
  end
  local value = 0
  for offset = width - 1, 0, -1 do
    value = value * 256 + region[address - BASE + offset]
  end
  return value
end

local function write(address, width, value)
  if address >= DEVICE and address < DEVICE + 4 then
    device_value = value
    return
  end
  for offset = 0, width - 1 do
    region[address - BASE + offset] = math.floor(value / 256 ^ offset) % 256
  end
end

local ENGINE = { base = BASE + 0x1000, length = 0x11000, what = "engine" }
local WEIGHTS = { base = BASE + 0x12000, length = 0x6480, what = "weights" }

local memory = touch.new({
  usable = { { base = BASE, length = SIZE } },
  ours = { ENGINE, WEIGHTS },
  read = read, write = write,
})

local SCRATCH = BASE + 0x40000
-- }}}

-- {{{ reading and writing ordinary memory
local written = touch.poke(memory, SCRATCH, 4, 0x12345678)
check("a write comes back when it is read", written == 0x12345678,
      written and string.format("0x%x", written))

check("and reading it again agrees",
      touch.peek(memory, SCRATCH, 4) == 0x12345678)

-- every width, at its own alignment
local widths_work = true
for _, width in ipairs({ 1, 2, 4, 8 }) do
  local at = SCRATCH + 0x100 * width
  local value = 0x11 * width
  if touch.poke(memory, at, width, value) ~= value then widths_work = false end
end
check("every width a processor supports works", widths_work)

local wrong_width = select(2, touch.peek(memory, SCRATCH, 3))
check("a width no processor has is refused",
      wrong_width ~= nil and wrong_width:find("1, 2, 4 or 8") ~= nil, wrong_width)

local unaligned = select(2, touch.peek(memory, SCRATCH + 1, 4))
check("an unaligned touch is refused, saying why it matters",
      unaligned ~= nil and unaligned:find("different things on different") ~= nil,
      unaligned)
-- }}}

-- {{{ the write that is not refused, and says so
--
-- Rewritten 2026-08-21. These four checks used to require that a write into
-- the engine or the weights be REFUSED. It is not refused any more -- the
-- only things worth restricting are the ones that damage hardware, and a
-- machine is entitled to do something stupid to itself. What is required
-- instead is that the write LANDS and that the hand SAYS SO, because a
-- damaged mind cannot notice it is damaged, and a machine that cannot notice
-- cannot decide to read itself back from the copy on disk.
--
-- So the test that matters is the third return, and the fact that the bytes
-- actually changed. A silent write here would be the failure now.
local wrote, refusal, warned =
  touch.poke(memory, ENGINE.base + 0x40, 4, 0)
check("writing into the engine is allowed",
      wrote ~= nil and refusal == nil, refusal)
check("and the machine is told, in a sentence it can act on",
      warned ~= nil and warned:find("your own mind") ~= nil
      and warned:find("copy on disk") ~= nil, warned)

local _, _, weights_warned = touch.poke(memory, WEIGHTS.base, 8, 0)
check("writing into the weights is allowed, and named as the weights",
      weights_warned ~= nil and weights_warned:find("weights") ~= nil,
      weights_warned)

-- A write that begins outside and ends inside is still a write inside, and
-- still worth saying so about. This has to be a bulk form: a single touch is
-- aligned to its own width and the engine begins on an aligned boundary, so
-- no single touch can straddle it. The old version of this check used an
-- unaligned eight-byte poke and was passing on the ALIGNMENT refusal rather
-- than on the overlap -- it never tested what its name said.
local _, _, straddling = touch.copy(memory, BASE + 0x200, ENGINE.base - 16, 32)
check("a write that only clips the engine is called out too",
      straddling ~= nil, "a straddling write said nothing")

-- and a bulk write that crosses into it goes through, whole, and warns once
local before = region[ENGINE.base - BASE - 4]
local filled, _, bulk_warned = touch.fill(memory, ENGINE.base - 0x40, 4, 64, 0xff)
check("a bulk write that reaches it is written whole, and reported",
      filled == 64 and bulk_warned ~= nil
      and region[ENGINE.base - BASE - 4] ~= before,
      "the bulk write did not land, or landed without saying anything")

check("and the machine keeps a count of how often it has done this",
      memory.warnings >= 4 and memory.last_warning ~= nil,
      tostring(memory.warnings) .. " warnings recorded")

-- reading its own mind is allowed, and is how 204 checks what it placed
local read_own = touch.peek(memory, ENGINE.base, 4)
check("reading its own mind is allowed", read_own ~= nil)
-- }}}

-- {{{ outside the map
local outside = select(2, touch.peek(memory, BASE + SIZE, 4))
check("a read outside the usable ranges is refused",
      outside ~= nil and outside:find("hangs the bus") ~= nil, outside)

local below = select(2, touch.peek(memory, BASE - 8, 4))
check("and so is one below them", below ~= nil)
-- }}}

-- {{{ what is returned is what is there
local device_answer = touch.poke(memory, DEVICE, 4, 0x11111111)
check("a device that answers differently says so",
      device_answer == 0xd0d0d0d0 and device_value == 0x11111111,
      device_answer and string.format("0x%x", device_answer))
-- }}}

-- {{{ the bulk forms
touch.fill(memory, SCRATCH + 0x1000, 4, 16, 0xabcdabcd)
check("fill writes every one of them",
      touch.peek(memory, SCRATCH + 0x1000, 4) == 0xabcdabcd
      and touch.peek(memory, SCRATCH + 0x103c, 4) == 0xabcdabcd)

local moved, move_trouble = touch.copy(memory, SCRATCH + 0x1000, SCRATCH + 0x2000, 64)
-- false means identical; nil would mean the comparison never happened, and
-- an earlier version of this check could not tell those apart -- so it passed
-- while every comparison in it was being refused.
check("copy moves the bytes",
      moved == 64
      and touch.compare(memory, SCRATCH + 0x1000, SCRATCH + 0x2000, 64) == false,
      move_trouble)

touch.poke(memory, SCRATCH + 0x2020, 4, 0)
local differ_at, compare_trouble =
  touch.compare(memory, SCRATCH + 0x1000, SCRATCH + 0x2000, 64)
check("compare says where they differ, not merely that they do",
      differ_at == 0x20, compare_trouble or tostring(differ_at))

local unlookable = select(2,
  touch.compare(memory, BASE + SIZE, SCRATCH, 64))
check("and a comparison it could not make is not 'the same'",
      unlookable ~= nil and unlookable:find("outside") ~= nil, unlookable)

-- an overlapping copy forward must not eat its own source
touch.fill(memory, SCRATCH + 0x3000, 1, 16, 0)
for offset = 0, 15 do write(SCRATCH + 0x3000 + offset, 1, offset) end
touch.copy(memory, SCRATCH + 0x3000, SCRATCH + 0x3004, 12)
local overlapped_right = true
for offset = 0, 11 do
  if read(SCRATCH + 0x3004 + offset, 1) ~= offset then overlapped_right = false end
end
check("an overlapping copy does not eat its own source", overlapped_right,
      "the destination repeats rather than copies")
-- }}}

-- {{{ as hands
local catalogue = hands.new()
hands.offer_the_catalogue(catalogue)
touch.offer(catalogue, hands, memory)

local asked = hands.answer(catalogue, hands.find(catalogue,
  "<call poke 0x140000 4 0x99>"))
check("the machine can ask to write", asked.ok and asked.text == "0x99",
      asked.text)

local asked_over_itself = hands.answer(catalogue, hands.find(catalogue,
  string.format("<call poke 0x%x 4 0>", ENGINE.base)))
check("and asking to write over itself works, and comes back with a warning",
      asked_over_itself.ok
      and asked_over_itself.text:find("your own mind") ~= nil,
      asked_over_itself.text)

local not_a_number = hands.answer(catalogue, hands.find(catalogue,
  "<call peek somewhere 4>"))
check("an address that is not a number is refused, with an example",
      not not_a_number.ok and not_a_number.text:find("0x1234") ~= nil,
      not_a_number.text)

local map = hands.answer(catalogue, hands.find(catalogue, "<call memory>"))
check("and it can ask what it may touch",
      map.ok and map.text:find("never writable") ~= nil
      and map.text:find("engine") ~= nil)
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not cover:")
say("    - a read that never returns. Some real buses hang on an address")
say("      nothing answers, and no rule here can prevent that -- only the")
say("      map can, and the map is the firmware's word rather than a fact.")
say("    - the ranges themselves. They come from 102 on a real machine and")
say("      are invented here, so this tests the rules and not the numbers.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("touching memory: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
