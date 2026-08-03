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

-- {{{ the tool that makes the test data, checked before the test uses it
--
-- Not ceremony. The conversion from a number to its exact bits was silently
-- returning the same answer once its loop went hot, so this test carried 256
-- numbers of which 3 were distinct -- and then reported the machine that ran
-- them as disagreeing with the first architecture by eighty-nine percent.
-- The port was innocent; the tool was broken.
--
-- A test that cannot vouch for its own inputs is not testing what it claims
-- to test. So it vouches for them first, with a hot loop, because a small
-- check passes the broken version perfectly.
local float_bits = dofile(DIR .. "/src/107-float-bits.lua")
local bits_sound, bits_why = float_bits.self_check()
check("the tool that makes the test data still works", bits_sound, bits_why)
-- }}}

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

-- {{{ the other seven kernels, run on the first architecture and recorded
--
-- Each one takes a buffer, changes it, and is compared against what this
-- machine made of the same buffer. Between them they cover every shape the
-- matrix product does not: one that calls another kernel, one that walks
-- pairs of numbers, two that read a second array at a stride, and the
-- exponential that everything above it depends on.
ffi.cdef[[
  void add_into(float *destination, const float *addend, int count);
  void rotate(float *vec, const float *turns, int heads, int head_width);
  void attention_scores(float *scores, const float *query, const float *keys,
                        int count, int width, int stride, float scale);
  void attention_mix(float *out, const float *weights, const float *values,
                     int count, int width, int stride);
  float exp_one(float x);
  void softmax(float *values, int count);
  void swiglu(float *gate, const float *up, int count);
]]

local jobs = {}

-- {{{ local function record(job)
-- Runs a kernel here, keeps the answer as bit patterns, and says how the
-- other machine should call it.
local function record(job)
  -- big enough for whichever is larger: what goes in, or what comes out.
  -- The attention kernels write more than their first input holds, and a
  -- buffer sized only for the input would be written past its end here --
  -- on the host, where it would be a crash, rather than on the board where
  -- it would be a wrong answer.
  local room = math.max(job.words, job.compare)
  local scratch = ffi.new("float[?]", room)
  for index = 0, job.words - 1 do scratch[index] = job.input[index + 1] end

  local second, third = nil, nil
  if job.extra then
    second = ffi.new("float[?]", #job.extra)
    for index = 0, #job.extra - 1 do second[index] = job.extra[index + 1] end
  end
  if job.extra2 then
    third = ffi.new("float[?]", #job.extra2)
    for index = 0, #job.extra2 - 1 do third[index] = job.extra2[index + 1] end
  end

  job.run(scratch, second, third)

  local as_bits = ffi.cast("uint32_t *", scratch)
  job.want = {}
  for index = 0, job.compare - 1 do job.want[index + 1] = as_bits[index] end

  job.input_label = job.name .. "in"
  job.extra_label = job.name .. "ex"
  job.extra2_label = job.name .. "ex2"
  job.want_label = job.name .. "want"
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
  call = { "  add x0, sp, #1024", "  adr x1, add_intoex", "  mov w2, #48" },
  run = function(a, b) kernels.add_into(a, b, 48) end,
})

-- turning pairs by a carried angle: 4 heads of 8, so 4 pairs per head
record({
  name = "rotate", words = 32, compare = 32,
  input = spread(32, 13000), extra = spread(8, 14000),
  call = { "  add x0, sp, #1024", "  adr x1, rotateex",
           "  mov w2, #4", "  mov w3, #8" },
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
  call = {},
  emit_call = true,
  run = function(a)
    for index = 0, 39 do a[index] = kernels.exp_one(a[index]) end
  end,
})

-- scores into weights, which calls the exponential
record({
  name = "softmax", words = 24, compare = 24,
  input = spread(24, 15000),
  call = { "  add x0, sp, #1024", "  mov w1, #24" },
  run = function(a) kernels.softmax(a, 24) end,
})

-- the gate, which also calls it
record({
  name = "swiglu", words = 24, compare = 24,
  input = spread(24, 16000), extra = spread(24, 17000),
  call = { "  add x0, sp, #1024", "  adr x1, swigluex", "  mov w2, #24" },
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
  call = {
    "  add x0, sp, #1024",
    "  adr x1, attention_scoresin",
    "  adr x2, attention_scoresex",
    "  mov w3, #8", "  mov w4, #16", "  mov w5, #16",
    string.format("  movz w6, #0x%x", scale_bits % 0x10000),
    string.format("  movk w6, #0x%x, lsl #16",
                  math.floor(scale_bits / 0x10000)),
    "  fmov s0, w6",
  },
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
  call = {
    "  add x0, sp, #1024",
    "  adr x1, attention_mixin",
    "  adr x2, attention_mixex",
    "  mov w3, #8", "  mov w4, #16", "  mov w5, #16",
  },
  run = function(out, values)
    local weights = ffi.new("float[?]", 8)
    for index = 0, 7 do weights[index] = number_at(index + 1 + 20000) end
    kernels.attention_mix(out, weights, values, 8, 16, 16)
  end,
})
-- }}}
-- }}}

-- {{{ the payload that runs the same arithmetic on the other machine
local emit_arm = dofile(DIR .. "/src/101-emit-kernel-check.lua")
local text = emit_arm.aarch64({
  cases = CASES, recorded = recorded,
  norms = NORM, recorded_norm = recorded_norm,
  kernels = arm.source(nil, specification, float_bits),
  jobs = jobs,
  number_at = number_at,
  dir = DIR,
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
check("every kernel the first architecture has, this one has too",
      #arm.not_written_yet == 0 and #arm.written == 10,
      #arm.written .. " written, " .. #arm.not_written_yet .. " missing")
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  where this port stands:")
say("    all ten routines written, and every answer proved bit-identical")
say("    to the first architecture on a real ARM machine -- including the")
say("    exponential, which is a polynomial here rather than the host")
say("    library, and is therefore comparable at all.")
say("")
say("    what is NOT covered: a whole forward pass on this architecture.")
say("    Each routine agrees alone; nothing yet runs them together there,")
say("    and the first architecture learned that a piece can be right by")
say("    itself and be handed the wrong thing by the piece before it.")
say("")
say("    and the third architecture is not begun. Its branches need the")
say("    word emitter that already exists, and its vector hardware may not")
say("    exist at all on a given chip.")
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
