#!/usr/bin/env luajit
-- 022-test-traps.lua
--
-- Runs every machine over every landmine and says whether the tripwires did
-- what they claim. Three architectures, two kinds of payload: one that
-- behaves and one that deliberately writes where it must not.
--
-- For a general: this is the proof that the safety net catches things. A
-- well-behaved computer must come back clean; a reckless one must be caught,
-- by name. If either answer comes out the other way, the net is decoration.
--
-- This doubles as the phase 7 demo: the same machine explored with the
-- discipline held and with it broken, side by side, with the difference
-- visible rather than described.
--
-- usage:
--   luajit 022-test-traps.lua [--dir ROOT] [--seconds N]

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

-- {{{ local function capture(command)
local function capture(command)
  local pipe = io.popen(command .. " 2>&1")
  if not pipe then return "" end
  local text = pipe:read("*a")
  pipe:close()
  return text
end
-- }}}

-- {{{ CASES -- what each run is expected to prove
--
-- expect is matched against the RESULT line. A run that produces a different
-- answer is a failure of the traps, not of the machine -- which is the whole
-- reason to keep both halves of the matrix rather than only the reckless one.
local BOARDS = {
  { board = "qemu-x86-64",  arch = "x86_64"  },
  { board = "qemu-arm64",   arch = "aarch64" },
  { board = "qemu-riscv64", arch = "riscv64" },
}

local CASES = {
  { payload = "first-light",
    expect = "clean",
    means = "a machine that behaves is not accused" },
  { payload = "hazard-clock",
    expect = "forbidden write",
    means = "a machine that misbehaves is caught, by name" },
}
-- }}}

-- {{{ main
local seconds = 20
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--seconds" then
    index = index + 1 ; seconds = tonumber(arg[index]) or 20
  end
  index = index + 1
end

say("")
say("  the discipline, held and broken")
say("  " .. string.rep("-", 58))
say("")

-- build every payload the matrix needs before running anything, so a build
-- failure is not mistaken for a machine misbehaving.
run_one("luajit " .. DIR .. "/src/019-build-payload.lua --dir " .. DIR .. " > /dev/null")

local passed, failed = 0, 0
local report = {}

for _, target in ipairs(BOARDS) do
  for _, case in ipairs(CASES) do
    local payload = DIR .. "/tmp/shared-memory/payloads/"
      .. case.payload .. "-" .. target.arch .. ".bin"

    local output = capture("luajit " .. DIR .. "/src/021-trap-run.lua "
      .. target.board .. " --payload " .. payload
      .. " --seconds " .. seconds .. " --dir " .. DIR)

    local result = output:match("RESULT:%s+([^\n]+)") or "no result reported"
    local ok = result:find(case.expect, 1, true) ~= nil

    if ok then passed = passed + 1 else failed = failed + 1 end

    report[#report + 1] = {
      arch = target.arch, payload = case.payload,
      ok = ok, result = result, means = case.means,
    }

    say(string.format("  %-9s %-14s %s", target.arch, case.payload,
                      ok and "as expected" or "WRONG"))
    say(string.format("  %-24s %s", "", result))
    say("")
  end
end

say("  " .. string.rep("-", 58))
say("")
for _, line in ipairs(report) do
  if not line.ok then
    say("  FAILED: " .. line.arch .. " / " .. line.payload)
    say("          expected: " .. line.means)
    say("          got:      " .. line.result)
    say("")
  end
end

say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")

-- what the traps still cannot do, said every run rather than buried in a
-- document, because a clean sweep invites the wrong conclusion.
say("  what this does not prove:")
say("    - traps cover only the addresses somebody wrote down. A real board")
say("      is full of devices nobody described, and a machine exploring one")
say("      of those passes this test while destroying hardware.")
say("    - a write that truly ends the machine cannot be reported by a")
say("      watchpoint, because the connection dies with the machine. The")
say("      console is the only witness, which is why probes speak first.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local handle = io.open(DIR .. "/output/goodbye", "w")
if handle then
  handle:write("trap matrix: " .. passed .. " of " .. (passed + failed)
               .. " as expected\ngoodbye\n")
  handle:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
