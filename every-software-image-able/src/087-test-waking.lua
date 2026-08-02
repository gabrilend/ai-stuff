#!/usr/bin/env luajit
-- 087-test-waking.lua
--
-- Checks the first thing that runs: that the machine finds out what
-- processor it is on, says so before handing over, and picks the engine that
-- matches what that processor actually has. Issue 402.
--
-- For a general: the computer is switched on and asked to describe itself.
-- What it says is compared against what the host knows about the same
-- processor, because a detection that agrees with nothing is a detection
-- nobody can trust.
--
-- usage:
--   luajit 087-test-waking.lua [--dir ROOT] [--seconds N]

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

-- {{{ local function read_file(path)
local function read_file(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local text = handle:read("*a")
  handle:close()
  return text
end
-- }}}

-- {{{ local function ask(command)
local function ask(command)
  local pipe = io.popen(command)
  if not pipe then return "" end
  local text = pipe:read("*a")
  pipe:close()
  return text
end
-- }}}

-- {{{ main
local seconds = 30
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--seconds" then
    index = index + 1 ; seconds = tonumber(arg[index]) or 30
  end
  index = index + 1
end

say("")
say("  waking up, and knowing what it woke up on")
say("  " .. string.rep("-", 58))
say("")

local waking = dofile(DIR .. "/src/086-emit-waking.lua")

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

-- {{{ the plan, before anything boots
-- What an image would do on each architecture, readable without booting --
-- which is what the image builder needs and what a person reading the
-- decision needs.
for _, architecture in ipairs({ "x86_64", "aarch64", "riscv64" }) do
  local plan = waking.plan(architecture, { "baseline" })
  check("there is a plan for " .. architecture, plan ~= nil and #plan >= 2)
end

local unknown = select(2, waking.plan("something-else"))
check("and an architecture nobody described is refused",
      unknown ~= nil and unknown:find("nothing is known") ~= nil, unknown)

-- the baseline is never a question on any of them: it is what the
-- architecture guarantees, and asking about a guarantee is how a detector
-- gets a wrong answer from a processor that answers oddly.
local baselines_are_free = true
for architecture in pairs(waking.LEVELS) do
  local plan = waking.plan(architecture, { "baseline" })
  if plan[1].name ~= "baseline" or plan[1].detected then
    baselines_are_free = false
  end
end
check("the baseline is guaranteed rather than detected", baselines_are_free)

-- and on RISC-V the baseline has no vectors at all, which is the whole
-- shape of that architecture's problem rather than a conservative choice.
check("and on RISC-V the baseline has no vectors at all",
      waking.LEVELS.riscv64[1].how_wide == 1
      and waking.LEVELS.riscv64[1].note:find("OPTIONAL") ~= nil)
-- }}}

-- {{{ the board says what it is
run_one("luajit " .. DIR .. "/src/019-build-payload.lua --dir " .. DIR
  .. " --payload waking --arch x86_64 > /dev/null")

local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-x86-64-serial.log"

-- {{{ local function wake_on(processor)
-- Boots the payload on a named processor and returns what it said. The
-- processor is a parameter because the only way to test that a machine
-- really detects what it is running on is to run it on more than one thing
-- and require the answers to differ.
local function wake_on(processor)
  run_one("rm -f " .. serial)
  local command = "luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-x86-64"
    .. " --payload " .. DIR .. "/tmp/shared-memory/payloads/waking-x86_64.efi"
    .. " --seconds " .. seconds .. " --dir " .. DIR
  if processor then command = command .. " --cpu " .. processor end
  run_one(command .. " > /dev/null 2>&1")
  return read_file(serial) or ""
end
-- }}}

local spoken = wake_on(nil)

check("the machine says something before handing over",
      spoken:find("waking up", 1, true) ~= nil)

local maker = spoken:match("made by%s+(%a+)")
check("and names the maker of the processor it woke up on",
      maker ~= nil and #maker > 6, tostring(maker))

check("and the part it is", spoken:match("part%s+%x+") ~= nil)

local vectors = spoken:match("vectors%s+([^\r\n]+)")
check("and which vector arrangement it found", vectors ~= nil, tostring(vectors))

check("and which engine that means starting",
      spoken:find("starting the engine") ~= nil)

check("and that it is handing over, so a silence afterwards is diagnosable",
      spoken:find("handing over", 1, true) ~= nil)
-- }}}

-- {{{ the detection is real, because a different processor answers differently
--
-- This is the check that matters, and it is the one that cannot be faked by
-- a payload that always says the same thing. The emulated processor is NOT
-- the host's -- the emulator presents its own, which is itself worth knowing
-- (notes/023) -- so comparing against the host would compare two unrelated
-- machines. Comparing two emulated processors against each other compares
-- what the detection is actually for.
local plain = wake_on("qemu64")
local plain_vectors = plain:match("vectors%s+([^\r\n]+)")

check("a plainer processor reports a plainer arrangement",
      plain_vectors ~= nil and plain_vectors:find("four at a time", 1, true) ~= nil,
      tostring(plain_vectors))

check("and the two processors did not give the same answer",
      vectors ~= nil and plain_vectors ~= nil and vectors ~= plain_vectors,
      tostring(vectors) .. " and " .. tostring(plain_vectors))

check("so the engine chosen changes with the machine",
      spoken:match("starting the engine[^\r\n]+")
      ~= plain:match("starting the engine[^\r\n]+"))
-- }}}

-- {{{ an unrecognised maker stops rather than guessing
-- Run rather than read: the refusal is emitted as character codes in the
-- instruction stream, so grepping the assembly for the sentence finds
-- nothing whether it is there or not. The emulator can be told to claim any
-- maker at all, which makes this testable properly.
-- Exactly twelve characters, because that is the size of the field the
-- processor answers in -- not a limitation of the emulator but the shape of
-- the hardware, and the reason the payload reads it as three registers.
local stranger = wake_on("qemu64,vendor=SomebodyElse")

check("a processor from a maker nobody described is noticed",
      stranger:find("SomebodyElse", 1, true) ~= nil,
      "the emulator would not present an unknown maker, so this went untested")

check("and the machine stops rather than handing over",
      stranger:find("waking up", 1, true) ~= nil
      and stranger:find("handing over", 1, true) == nil,
      "it handed over to an engine chosen from answers it cannot trust")

check("and says why the vector answers cannot be trusted either",
      stranger:find("convention") ~= nil,
      "it stopped without saying what was wrong")
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not cover:")
say("    - the other two architectures' detection. ARM's baseline is part of")
say("      the architecture and needs no asking; RISC-V's vector extension is")
say("      optional and the asking differs by machine. Both are described in")
say("      the levels table and neither is written in its own instructions")
say("      yet -- that is 401's work, and this is what it will plug into.")
say("    - handing over to an engine that exists. Nothing is handed to yet;")
say("      601 is where the sentence stops being the last thing said.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("waking: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
