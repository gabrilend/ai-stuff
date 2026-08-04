#!/usr/bin/env luajit
-- 113-test-kernels-riscv64.lua
--
-- The third tongue's arithmetic, run on a real emulated RISC-V machine and
-- compared against answers recorded from the first tongue -- bit for bit,
-- not closely. Issue 401.
--
-- For a general: the first architecture's routines can be tested by loading
-- them into this process and calling them, because this processor speaks
-- that language. It does not speak this one. So the only honest test is to
-- boot a machine that does, run the arithmetic there, and have it report
-- what it got -- which is why the emulated boards were built first.
--
-- WHAT MAKES THE COMPARISON WORTH ANYTHING. The answers are not recomputed
-- on the RISC-V side and compared to themselves. They are the exact bit
-- patterns the x86 routines produced, carried into the payload as
-- constants, and the machine compares its own results against them as
-- integers.
--
-- usage:
--   luajit 113-test-kernels-riscv64.lua [--dir ROOT] [--seconds N]

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
local seconds = 90
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--seconds" then
    index = index + 1 ; seconds = tonumber(arg[index]) or 90
  end
  index = index + 1
end

say("")
say("  the third tongue, against what the first one said")
say("  " .. string.rep("-", 58))
say("")

local emit = dofile(DIR .. "/src/043-emit-kernels.lua")
local riscv = dofile(DIR .. "/src/111-kernels-riscv64.lua")
local payload = dofile(DIR .. "/src/112-emit-kernel-check-riscv.lua")
local specification = dofile(DIR .. "/src/047-reference-exp.lua")
local float_bits = dofile(DIR .. "/src/107-float-bits.lua")

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

-- {{{ the tool that makes the test data, checked before the test uses it
-- Not ceremony. The conversion from a number to its exact bits was once
-- silently returning the same answer after its loop went hot, which built a
-- payload carrying 256 numbers of which 3 were distinct -- and then reported
-- the machine that ran them as a broken port. It was the tool that was
-- broken. A test that cannot vouch for its own inputs is not testing what it
-- claims to.
local bits_sound, bits_why = float_bits.self_check()
check("the tool that makes the test data still works", bits_sound, bits_why)
-- }}}

-- {{{ the cases, and what the first tongue says about them
-- Shapes chosen so the wide routine's remainder path is exercised rather
-- than assumed: column counts that are and are not multiples of four.
local CASES = {
  { rows = 1, columns = 1 },
  { rows = 3, columns = 1 },
  { rows = 1, columns = 3 },
  { rows = 4, columns = 4 },
  { rows = 5, columns = 7 },
  { rows = 8, columns = 32 },
  { rows = 7, columns = 65 },
}

-- the same deterministic numbers the second tongue's check uses, so a
-- disagreement between the two ports is a disagreement about arithmetic
-- rather than about which numbers they were given.
local function number_at(index)
  local value = ((index * 2654435761) % 1000003) / 500000.0 - 1.0
  return value
end

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/kernels")
run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/payloads")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

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
ffi.cdef[[
  void matrix_vector_fast(float *out, const float *matrix, const float *input,
                          int rows, int columns);
]]
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

  -- The fast product's answers are recorded SEPARATELY. It keeps four totals
  -- instead of one, so it is a second specification rather than a faster
  -- version of the first, and holding it to the exact one's answer would be
  -- requiring it to stop being what it is.
  local quick = ffi.new("float[?]", case.rows)
  kernels.matrix_vector_fast(quick, matrix, input, case.rows, case.columns)
  local quick_bits = ffi.cast("uint32_t *", quick)
  local fast_answers = {}
  for index = 0, case.rows - 1 do fast_answers[index + 1] = quick_bits[index] end

  recorded[case_index] = { answers = answers, fast_answers = fast_answers }
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
  recorded_norm[case_index] = { answers = answers }
end
-- }}}

-- {{{ the other seven routines, run on the first architecture and recorded
ffi.cdef[[
  float exp_one_shim(float x);
]]

local jobs = {}

-- {{{ local function record(job)
-- Runs a routine here, keeps the answer as bit patterns, and leaves the
-- calling sequence to 112, which is where the per-architecture part lives.
local function record(job)
  -- big enough for whichever is larger: what goes in, or what comes out. The
  -- attention routines write more than their first input holds, and a buffer
  -- sized only for the input would be written past its end here -- on the
  -- host, where it would be a crash, rather than on the board where it would
  -- be a wrong answer.
  local room = math.max(job.words, job.compare)
  local scratch = ffi.new("float[?]", room)
  for index = 0, job.words - 1 do scratch[index] = job.input[index + 1] end

  local second = nil
  if job.extra then
    second = ffi.new("float[?]", #job.extra)
    for index = 0, #job.extra - 1 do second[index] = job.extra[index + 1] end
  end

  job.run(scratch, second)

  local as_bits = ffi.cast("uint32_t *", scratch)
  job.want = {}
  for index = 0, job.compare - 1 do job.want[index + 1] = as_bits[index] end

  jobs[#jobs + 1] = job
  return job
end
-- }}}

local function spread(count, salt)
  local out = {}
  for index = 1, count do out[index] = number_at(index + salt) end
  return out
end

-- carrying a value forward
record({
  name = "add_into", words = 48, compare = 48,
  input = spread(48, 11000), extra = spread(48, 12000),
  run = function(a, b) kernels.add_into(a, b, 48) end,
})

-- turning pairs by a carried angle: 4 heads of 8, so 4 pairs per head
record({
  name = "rotate", words = 32, compare = 32,
  input = spread(32, 13000), extra = spread(8, 14000),
  run = function(a, b) kernels.rotate(a, b, 4, 8) end,
})

-- the exponential, over the range a softmax actually produces
record({
  name = "exp_one", words = 40, compare = 40,
  input = (function()
    local out = {}
    for index = 1, 40 do out[index] = -30 + (index - 1) * 0.75 end
    return out
  end)(),
  run = function(a)
    for index = 0, 39 do a[index] = kernels.exp_one(a[index]) end
  end,
})

-- scores into weights, which calls the exponential
record({
  name = "softmax", words = 24, compare = 24,
  input = spread(24, 15000),
  run = function(a) kernels.softmax(a, 24) end,
})

-- the gate, which also calls it
record({
  name = "swiglu", words = 24, compare = 24,
  input = spread(24, 16000), extra = spread(24, 17000),
  run = function(a, b) kernels.swiglu(a, b, 24) end,
})

-- {{{ the two that read a second array at a stride
--
-- These write a fresh output rather than changing what they were given, and
-- they read two arrays, so they take their inputs where they lie instead of
-- being copied into scratch first. Eight past positions, sixteen numbers
-- each, laid one after another -- which is the arrangement the real cache
-- has, where every layer and every key head shares one array.
local SCALE = 0.3535533905932738      -- one over the square root of eight
local scale_bits = float_bits.of(SCALE)

record({
  name = "attention_scores", words = 16, compare = 8, no_copy = true,
  input = spread(16, 18000),          -- the question
  extra = spread(128, 19000),         -- eight positions of sixteen
  scale_bits = scale_bits,
  run = function(out, keys)
    local query = ffi.new("float[?]", 16)
    for index = 0, 15 do query[index] = number_at(index + 1 + 18000) end
    kernels.attention_scores(out, query, keys, 8, 16, 16, SCALE)
  end,
})

record({
  name = "attention_mix", words = 8, compare = 16, no_copy = true,
  input = spread(8, 20000),           -- how well each position matched
  extra = spread(128, 21000),         -- what each position held
  run = function(out, values)
    local weights = ffi.new("float[?]", 8)
    for index = 0, 7 do weights[index] = number_at(index + 1 + 20000) end
    kernels.attention_mix(out, weights, values, 8, 16, 16)
  end,
})
-- }}}
-- }}}

-- {{{ the payload that runs the same arithmetic on the other machine
local text = payload.riscv64({
  cases = CASES, recorded = recorded,
  norms = NORM, recorded_norm = recorded_norm,
  jobs = jobs,
  number_at = number_at,
  epsilon_bits = float_bits.of(1e-5),
  kernels = riscv,
  specification = specification,
  float_bits = float_bits,
  dir = DIR,
})

local base = DIR .. "/tmp/shared-memory/payloads/kernel-check-riscv64"
handle = io.open(base .. ".s", "w")
handle:write(text)
handle:close()

if not run_one("clang --target=riscv64-unknown-none -march=rv64imafd -c "
               .. base .. ".s -o " .. base .. ".o") then
  check("the third tongue's kernels assemble", false, "see " .. base .. ".s")
  say("")
  say("  " .. passed .. " of " .. (passed + failed + 1) .. " as expected")
  os.exit(1)
end
check("the third tongue's kernels assemble", true)

-- THE WHOLE REASON 054 EXISTS, checked rather than trusted. If any branch or
-- jump had been written as a branch to a label, the assembler would have
-- left a relocation, extraction would have dropped it, and the offset would
-- have stayed zero -- which is a branch to itself, and a machine that spins
-- forever saying nothing. A payload with any relocation in it is a payload
-- that will not run, so this is checked before the machine is booted rather
-- than diagnosed afterwards.
local relocations = io.popen("llvm-readelf -r " .. base .. ".o 2>&1")
local relocation_text = relocations and relocations:read("*a") or ""
if relocations then relocations:close() end
local none_left = relocation_text:find("There are no relocations", 1, true) ~= nil
  or relocation_text:match("^%s*$") ~= nil
check("nothing in it is waiting on a linker", none_left,
      "a relocation left behind becomes a branch to itself, silently")

run_one("llvm-objcopy -O binary " .. base .. ".o " .. base .. ".raw")
run_one("luajit " .. DIR .. "/src/029-wrap-uefi.lua --from " .. base
        .. ".raw --to " .. base .. ".efi --arch riscv64 > /dev/null")
-- }}}

-- {{{ boot it and read what it said
local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-riscv64-serial.log"
run_one("rm -f " .. serial)
run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-riscv64"
  .. " --payload " .. base .. ".efi --seconds " .. seconds
  .. " --dir " .. DIR .. " > /dev/null 2>&1")

local spoken = read_file(serial) or ""

check("the other machine ran the arithmetic and reported",
      spoken:find("kernels checked", 1, true) ~= nil,
      "nothing recognisable came back; see " .. serial)

-- {{{ reading only what the payload said, and only at the start of a line
--
-- THE FIRMWARE TALKS TOO, and it talks first. This board is the one with
-- USB storage attached -- deliberately, as the most demanding of the three
-- -- and while enumerating it the firmware prints "device is of 3 speed".
-- A search for "of" followed by a number found that, eleven hundred lines
-- before the payload said anything, and reported the machine as having
-- compared three values when it had compared two hundred and seventy-nine.
-- Every answer was right and the test said the port was broken.
--
-- So the search starts after the payload's own header and every mark must
-- begin a line. This project has now been misled twice by a tool reading a
-- log rather than by anything the log said, which is worth more than the
-- defect: a tool that answers confidently is worth checking before the
-- thing it is reporting on.
local report = spoken:match("kernels checked(.*)$") or ""
local function number_after(mark)
  return tonumber(report:match("[\r\n]%s*" .. mark .. "%s+(%x+)") or "", 16)
end

local matched = number_after("matched")
local total = number_after("of")

check("every matrix answer agrees with the first tongue, bit for bit",
      matched ~= nil and total ~= nil and matched == total and total > 0,
      tostring(matched) .. " of " .. tostring(total))

local norm_matched = number_after("norms")
local norm_total = number_after("nof")
check("and every normalisation does too",
      norm_matched ~= nil and norm_total ~= nil
      and norm_matched == norm_total and norm_total > 0,
      tostring(norm_matched) .. " of " .. tostring(norm_total))

-- {{{ how far apart, when they are apart at all
local got = number_after("got")
local want = number_after("want")
if got and want and got ~= want then
  local pair = ffi.new("uint32_t[2]")
  pair[0], pair[1] = got, want
  local viewed = ffi.cast("float *", pair)
  say("")
  say(string.format("  the first disagreement: %.9g against %.9g",
                    viewed[0], viewed[1]))
  say(string.format("  which is %d in the last place",
                    math.abs(tonumber(got) - tonumber(want))))
end
-- }}}
-- }}}

-- {{{ what is not written yet, worked out rather than remembered
local missing = riscv.missing_from(emit.names)
check("every kernel the first architecture has, this one has too",
      #missing == 0,
      #riscv.written .. " written against the first tongue's " .. #emit.names
      .. "; missing: " .. table.concat(missing, ", "))
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  where this port stands:")
say("    all " .. #riscv.written .. " routines written, the same "
    .. #emit.names .. " the first architecture has, every one")
say("    laid out by the word emitter rather than written as text -- because")
say("    this assembler leaves a relocation on a branch to a label in its")
say("    own file, and with no linker that becomes a branch to itself.")
say("")
say("    the fast matrix product keeps its four totals in ORDINARY floating")
say("    registers here. The vector hardware is absent on the processor this")
say("    board names -- measured, not assumed -- and where it exists it stays")
say("    switched off until something with machine-mode privilege enables it.")
say("    Same lane assignment and same combining order, so it still agrees")
say("    with the first architecture's fast kernel bit for bit.")
say("")
say("    what is NOT covered: a whole forward pass on this architecture.")
say("    Each routine agrees alone; nothing yet conducts them together here,")
say("    and the other two architectures both learned that a piece can be")
say("    right by itself and be handed the wrong thing by the piece before it.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("third tongue: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
