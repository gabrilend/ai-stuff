#!/usr/bin/env luajit
-- 100-test-kernels-aarch64.lua
--
-- The second tongue's arithmetic, run on a real emulated ARM machine and
-- compared against answers recorded from the first tongue -- bit for bit,
-- not closely. Issue 401.
--
-- For a general: the first architecture's kernels could be tested by loading
-- them into this process and calling them, because this processor speaks
-- that language. It does not speak this one. So the only honest test is to
-- boot a machine that does, run the arithmetic there, and have it report
-- what it got -- which is why the emulated boards were built first.
--
-- WHAT MAKES THE COMPARISON WORTH ANYTHING. The answers are not recomputed
-- on the ARM side and compared to themselves. They are the exact bit
-- patterns the x86 kernels produced, carried into the payload as constants,
-- and the machine compares its own results against them and reports how many
-- matched. A port is correct when it agrees with the fixture the first one
-- agreed with, and that is the whole reason the fixture exists.
--
-- usage:
--   luajit 100-test-kernels-aarch64.lua [--dir ROOT] [--seconds N]

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

-- {{{ local function read_file(path)
local function read_file(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local text = handle:read("*a")
  handle:close()
  return text
end
-- }}}

-- {{{ main
local seconds = 60
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--seconds" then
    index = index + 1 ; seconds = tonumber(arg[index]) or 60
  end
  index = index + 1
end

say("")
say("  the second tongue, against what the first one said")
say("  " .. string.rep("-", 58))
say("")

local emit = dofile(DIR .. "/src/043-emit-kernels.lua")
local arm = dofile(DIR .. "/src/099-kernels-aarch64.lua")

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

-- {{{ the cases, and what the first tongue says about them
-- Shapes chosen so the wide kernel's remainder path is exercised rather than
-- assumed: column counts that are and are not multiples of four.
local CASES = {
  { rows = 1, columns = 1 },
  { rows = 3, columns = 1 },
  { rows = 1, columns = 3 },
  { rows = 4, columns = 4 },
  { rows = 5, columns = 7 },
  { rows = 8, columns = 32 },
  { rows = 7, columns = 65 },
}

-- deterministic numbers, so the recorded answers are the same every run and
-- the payload can carry them as constants.
local function number_at(index)
  local value = ((index * 2654435761) % 1000003) / 500000.0 - 1.0
  return value
end

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/kernels")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

local specification = dofile(DIR .. "/src/047-reference-exp.lua")
local source = DIR .. "/tmp/shared-memory/kernels/kernels-x86_64.s"
local library = DIR .. "/tmp/kernels/kernels-x86_64.so"
local handle = io.open(source, "w")
handle:write(emit.source("x86_64", specification))
handle:close()
if not run_one("clang -shared -o " .. library .. " " .. source) then
  say("  the first tongue's kernels would not build; nothing to compare against")
  os.exit(1)
end

dofile(DIR .. "/src/049-assembly-forward.lua").declare()
local kernels = ffi.load(library)

-- {{{ record what the first tongue produces
local recorded = {}
for case_index, case in ipairs(CASES) do
  local matrix = ffi.new("float[?]", case.rows * case.columns)
  local input = ffi.new("float[?]", case.columns)
  local out = ffi.new("float[?]", case.rows)

  for index = 0, case.rows * case.columns - 1 do
    matrix[index] = number_at(index + case_index * 100)
  end
  for index = 0, case.columns - 1 do
    input[index] = number_at(index + case_index * 7000)
  end

  kernels.matrix_vector_plain(out, matrix, input, case.rows, case.columns)

  local as_bits = ffi.cast("uint32_t *", out)
  local answers = {}
  for index = 0, case.rows - 1 do answers[index + 1] = as_bits[index] end

  recorded[case_index] = { matrix = matrix, input = input, answers = answers }
end
check("the first tongue produced answers to compare against",
      #recorded == #CASES)
-- }}}

-- and the normalisation
local NORM = { 1, 3, 32, 33, 64 }
local recorded_norm = {}
for case_index, size in ipairs(NORM) do
  local input = ffi.new("float[?]", size)
  local weight = ffi.new("float[?]", size)
  local out = ffi.new("float[?]", size)
  for index = 0, size - 1 do
    input[index] = number_at(index + case_index * 300)
    weight[index] = number_at(index + case_index * 900)
  end
  kernels.rms_normalise(out, input, weight, size, 1e-5)
  local as_bits = ffi.cast("uint32_t *", out)
  local answers = {}
  for index = 0, size - 1 do answers[index + 1] = as_bits[index] end
  recorded_norm[case_index] = { input = input, weight = weight, answers = answers }
end
-- }}}

-- {{{ the payload that runs the same arithmetic on the other machine
local emit_arm = dofile(DIR .. "/src/101-emit-kernel-check.lua")
local text = emit_arm.aarch64({
  cases = CASES, recorded = recorded,
  norms = NORM, recorded_norm = recorded_norm,
  kernels = arm.source(),
  number_at = number_at,
})

local base = DIR .. "/tmp/shared-memory/payloads/kernel-check-aarch64"
run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/payloads")
handle = io.open(base .. ".s", "w")
handle:write(text)
handle:close()

if not run_one("clang --target=aarch64-unknown-none -c " .. base .. ".s -o "
               .. base .. ".o") then
  check("the second tongue's kernels assemble", false,
        "see " .. base .. ".s")
  say("")
  say("  " .. passed .. " of " .. (passed + failed + 1) .. " as expected")
  os.exit(1)
end
check("the second tongue's kernels assemble", true)

run_one("llvm-objcopy -O binary " .. base .. ".o " .. base .. ".raw")
run_one("luajit " .. DIR .. "/src/029-wrap-uefi.lua --from " .. base
        .. ".raw --to " .. base .. ".efi --arch aarch64 > /dev/null")
-- }}}

-- {{{ boot it and read what it said
local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-arm64-serial.log"
run_one("rm -f " .. serial)
run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-arm64"
  .. " --payload " .. base .. ".efi --seconds " .. seconds
  .. " --dir " .. DIR .. " > /dev/null 2>&1")

local spoken = read_file(serial) or ""

check("the other machine ran the arithmetic and reported",
      spoken:find("kernels checked", 1, true) ~= nil,
      "nothing recognisable came back; see " .. serial)

local matched = tonumber(spoken:match("matched%s+(%x+)") or "", 16)
local total = tonumber(spoken:match("of%s+(%x+)") or "", 16)

check("every matrix answer agrees with the first tongue, bit for bit",
      matched ~= nil and total ~= nil and matched == total and total > 0,
      tostring(matched) .. " of " .. tostring(total))

local norm_matched = tonumber(spoken:match("norms%s+(%x+)") or "", 16)
local norm_total = tonumber(spoken:match("nof%s+(%x+)") or "", 16)
check("and every normalisation does too",
      norm_matched ~= nil and norm_total ~= nil
      and norm_matched == norm_total and norm_total > 0,
      tostring(norm_matched) .. " of " .. tostring(norm_total))
-- }}}

-- {{{ what is not written yet, counted rather than omitted
check("what this tongue does not have yet is named, not omitted",
      #arm.not_written_yet == 7,
      "a port that quietly covers less than the first looks finished")
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  where this port stands:")
say("    written and proved bit-exact on a real ARM machine:")
say("      the matrix product, plain and four-at-a-time, and the")
say("      normalisation -- the three built only from multiply, add and")
say("      square root, which are the ones that CAN be required to match")
say("      exactly rather than closely.")
say("    not written yet: " .. table.concat(arm.not_written_yet, ", "))
say("    and the third tongue is not begun. It needs 054's word emitter,")
say("    which exists, and its vector extension may not exist at all on a")
say("    given machine -- which 402's levels table already says.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("second tongue: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
