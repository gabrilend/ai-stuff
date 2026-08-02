#!/usr/bin/env luajit
-- 080-test-emit-a-status.lua
--
-- Checks the status emission: three numbers, shown as colour and shape
-- together, on whichever display the board actually has -- and never
-- silently nowhere.
--
-- usage:
--   luajit 080-test-emit-a-status.lua [--dir ROOT]

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
say("  saying how it is, on a machine that cannot spell")
say("  " .. string.rep("-", 58))
say("")

local emit = dofile(DIR .. "/src/079-emit-a-status.lua")
local touch = dofile(DIR .. "/src/071-touch-memory.lua")
local hands = dofile(DIR .. "/src/064-the-hands.lua")
local assembler = dofile(DIR .. "/src/073-the-assembler.lua")

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

-- {{{ a machine with somewhere to keep the reading
local BASE, SIZE = 0x200000, 0x1000
local region = ffi.new("uint8_t[?]", SIZE)
local memory = touch.new({
  usable = { { base = BASE, length = SIZE } },
  ours = {},
  read = function(address, width)
    local value = 0
    for offset = width - 1, 0, -1 do value = value * 256 + region[address - BASE + offset] end
    return value
  end,
  write = function(address, width, value)
    for offset = 0, width - 1 do
      region[address - BASE + offset] = math.floor(value / 256 ^ offset) % 256
    end
  end,
})
local MAGNITUDE = BASE + 0x10
-- }}}

-- {{{ every display, and which one takes it
local seen = { lamps = {}, screen = {}, wire = {} }

local full = emit.new({
  memory = memory, magnitude_at = MAGNITUDE,
  lamps = function(shape, reading) seen.lamps[#seen.lamps + 1] = reading return true end,
  draw = function(shape, reading) seen.screen[#seen.screen + 1] = reading return true end,
  wire = function(text) seen.wire[#seen.wire + 1] = text return true end,
})

local reading = emit.emit(full, 1, 7, 50, "waking up")
check("a status is emitted", reading ~= nil and reading.code == 7)
check("and lamps take it before anything else",
      reading.shown_on == "lamps" and #seen.lamps == 1 and #seen.screen == 0,
      reading and reading.shown_on)

-- a board with no lamps draws it instead
local drawing = emit.new({
  memory = memory, magnitude_at = MAGNITUDE,
  draw = function(shape, r) seen.screen[#seen.screen + 1] = r return true end,
  wire = function(text) seen.wire[#seen.wire + 1] = text return true end,
})
local drawn = emit.emit(drawing, 2, 12, 50, "finding memory")
check("a board with no lamps draws it, and says so",
      drawn.shown_on == "the screen", drawn.shown_on)

-- and one with neither says it on the wire
local wired = emit.new({
  memory = memory, magnitude_at = MAGNITUDE,
  wire = function(text) seen.wire[#seen.wire + 1] = text return true end,
})
local said = emit.emit(wired, 3, 3, 50, "finding storage")
check("and one with neither says it on the wire",
      said.shown_on == "the wire" and seen.wire[#seen.wire]:find("yellow") ~= nil,
      seen.wire[#seen.wire])

-- and a machine with nowhere is told, rather than believing it spoke
local nowhere = emit.new({ memory = memory, magnitude_at = MAGNITUDE })
local unshown, why = emit.emit(nowhere, 1, 1, 50, "")
check("a status shown nowhere is a refusal, not a silence",
      unshown == nil and why:find("looks like nothing happened") ~= nil, why)
-- }}}

-- {{{ colour and shape both, so either alone is enough
local both = emit.emit(full, 4, 22, 50, "probing")
check("every aspect carries a colour and a shape",
      both.colour == "red" and both.shape == "cross")

local all_distinct = true
local colours, shapes = {}, {}
for _, entry in ipairs(emit.COLOURSHAPES) do
  if colours[entry.colour] or shapes[entry.shape] then all_distinct = false end
  colours[entry.colour], shapes[entry.shape] = true, true
end
check("no two aspects share a colour or a shape", all_distinct,
      "one encoding failing would then make two aspects the same")

local text = emit.as_text(both)
check("and the text says both, for anywhere that can spell",
      text:find("red") ~= nil and text:find("cross") ~= nil, text)
-- }}}

-- {{{ the numbers, and what they are allowed to be
local too_big = select(2, emit.emit(full, 1, 100, 50, ""))
check("a code that will not fit on the lamps is refused",
      too_big ~= nil and too_big:find("two digits") ~= nil, too_big)

local no_aspect = select(2, emit.emit(full, 99, 1, 50, ""))
check("an aspect that does not exist is refused, saying how to add one",
      no_aspect ~= nil and no_aspect:find("adds them") ~= nil, no_aspect)
-- }}}

-- {{{ the magnitude: fifty is ordinary, and distance means look
local ordinary = emit.emit(full, 1, 5, 50, "")
check("fifty crosses nothing", ordinary.crossed == nil)

local high = emit.emit(full, 1, 5, 70, "looping")
check("far above ordinary is a crossing", high.crossed == true)

local low = emit.emit(full, 1, 5, 30, "starved")
check("and so is far below -- the axis has two ends", low.crossed == true)

check("crossings are counted", full.crossings == 2, tostring(full.crossings))

check("and the machine-wide reading is what was last emitted",
      emit.reading(full) == 30, tostring(emit.reading(full)))

emit.settle(full)
check("settling returns it to ordinary", emit.reading(full) == emit.ORDINARY)
check("but the crossings on the way are kept", full.crossings == 2,
      "the record of how close it came must survive the settling")
-- }}}

-- {{{ the same dial the written code pushes on
-- The assembler's loop emissions (073) write the machine-wide magnitude, so
-- a runaway program and a worried machine show up on one reading rather than
-- two -- which is what makes the picture comparable at all.
local loop = assembler.new({ emit_at = MAGNITUDE })
loop:instruct("set", "a", 3)
loop:label("again")
loop:instruct("add_number", "a", -1)
loop:instruct("compare_number", "a", 0)
loop:jump("if_greater", "again")
loop:instruct("return")
local _, _, report = assembler.assemble(loop)

check("what the assembler watches writes the same reading",
      report.emissions == 1 and report.watched == true)

-- and the address it writes is the one the status mechanism reads
memory.write(MAGNITUDE, 8, 57)
check("so a program's own count is visible to the machine",
      emit.reading(full) == 57)
-- }}}

-- {{{ the meanings are not here, and that is said out loud
local catalogue = hands.new()
hands.offer_the_catalogue(catalogue)
emit.offer(catalogue, hands, full)

local aspects = hands.answer(catalogue, hands.find(catalogue, "<call aspects>"))
check("the machine can ask what the colourshapes mean",
      aspects.ok and aspects.text:find("triangle") ~= nil)
check("and is told that the codes' meanings are its own to build",
      aspects.ok and aspects.text:find("nothing here says what") ~= nil)
check("and that the magnitude carries no opinion",
      aspects.ok and aspects.text:find("no opinion") ~= nil)

local asked = hands.answer(catalogue, hands.find(catalogue,
  "<call emit 5 42 66 running_what_it_wrote>"))
check("the machine can emit for itself",
      asked.ok and asked.text:find("white bar") ~= nil
      and asked.text:find("high") ~= nil, asked.text)

local how = hands.answer(catalogue, hands.find(catalogue, "<call how_it_is>"))
check("and can ask how it is",
      how.ok and how.text:find("from ordinary") ~= nil
      and how.text:find("thresholds") ~= nil, how.text)
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what the seed deliberately does not decide:")
say("    - what any code means. Two machines emitting seventeen mean")
say("      unrelated things, and the aspect is what keeps them apart. The")
say("      lookup that answers 'what is this one' is the first thing worth")
say("      building once anything is emitting at all -- and it is the grown")
say("      machine's to build, not the seed's to carry.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("emitting a status: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
