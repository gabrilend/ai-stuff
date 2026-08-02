#!/usr/bin/env luajit
-- 044-test-kernels.lua
--
-- Runs the assembly kernels and the reference over the same numbers and
-- compares them **bit for bit**. Not approximately. Not within a tolerance.
-- Identical, or a failure.
--
-- For a general: the fast version written in the processor's own instructions
-- must produce exactly the same answer as the slow readable version. Anything
-- less than exactly is a judgement call about whether a difference is small
-- enough, and judgement calls are what this comparison exists to remove.
--
-- WHY THIS CAN BE TESTED WITHOUT BOOTING ANYTHING. A kernel that touches only
-- the memory handed to it needs no operating system to run. The same bytes
-- that will run on a bare machine can be loaded here and called directly,
-- which turns a several-minute boot into a fraction of a second. It is the
-- only part of the engine that gets this, and it is the part that most needs
-- it, because it is the part that will be written three times.
--
-- WHERE THE LINE IS. These two kernels are built from multiplication,
-- addition and square root, all of which are exactly specified. Anything
-- downstream of an exponential, a sine or a cosine cannot be compared this way,
-- because those differ between implementations -- so those parts are checked
-- by the fixture in 037 with a stated tolerance instead.
--
-- usage:
--   luajit 044-test-kernels.lua [--dir ROOT]

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

-- {{{ local function host_architecture()
local function host_architecture()
  local pipe = io.popen("uname -m")
  local name = pipe and pipe:read("*l") or "unknown"
  if pipe then pipe:close() end
  return name
end
-- }}}

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

local arch = host_architecture()

say("")
say("  the arithmetic, fast and slow, compared exactly")
say("  " .. string.rep("-", 58))
say("")

local emit = dofile(DIR .. "/src/043-emit-kernels.lua")

-- Only the architecture this machine is can be run here. The other two are
-- checked by running them on emulated machines, which is slower and is why
-- this exists at all.
if not emit[arch] then
  say("  no kernels written for " .. arch .. " yet.")
  say("  Nothing was tested, which is not the same as nothing being wrong.")
  say("")
  os.exit(1)
end

run_one("mkdir -p /tmp/every-software-image-able")
run_one("mkdir -p /dev/shm/every-software-image-able")
run_one("ln -sfn /tmp/every-software-image-able " .. DIR .. "/tmp")
run_one("ln -sfn /dev/shm/every-software-image-able /tmp/every-software-image-able/shared-memory")
-- Two RAM tiers, and this needs both of them.
--
-- The artifact tier is mounted so that nothing on it may be executed, which is
-- the right arrangement and which this test ran into: a shared library placed
-- there refuses to load with "failed to map segment". So the source, which is
-- an artifact to read, goes on the artifact tier, and the built library, which
-- must run, goes on the executable one.
local artifacts = DIR .. "/tmp/shared-memory/kernels"
local runnable = DIR .. "/tmp/kernels"
run_one("mkdir -p " .. artifacts)
run_one("mkdir -p " .. runnable)

-- {{{ build them into something callable
local source = artifacts .. "/kernels-" .. arch .. ".s"
local library = runnable .. "/kernels-" .. arch .. ".so"

local exponential = dofile(DIR .. "/src/047-reference-exp.lua")

local handle = io.open(source, "w")
handle:write(emit.source(arch, exponential))
handle:close()

-- Built as a shared library only so this test can call it. The same
-- instructions go into the bare-metal engine unchanged, because a kernel that
-- touches nothing but its arguments does not care what is underneath it.
local built = run_one("clang -shared -o " .. library .. " " .. source)
if not built then
  say("  the kernels would not assemble. See " .. source)
  os.exit(1)
end

ffi.cdef[[
  void matrix_vector_plain(float *out, const float *matrix, const float *input,
                           int rows, int columns);
  void matrix_vector_wide(float *out, const float *matrix, const float *input,
                          int rows, int columns);
  void rms_normalise(float *out, const float *input, const float *weight,
                     int size, float epsilon);
  float exp_one(float x);
  void softmax(float *values, int count);
  void swiglu(float *gate, const float *up, int count);
]]
local kernels = ffi.load(library)
-- }}}

local reference = dofile(DIR .. "/src/035-reference-forward.lua")

local passed, failed = 0, 0

-- {{{ local function check(what, ok, detail)
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
-- }}}

-- {{{ local function drawn(count, seed)
-- Numbers spread across several magnitudes, because a dot product of numbers
-- that are all the same size hides exactly the rounding differences this test
-- exists to catch.
local function drawn(count, seed)
  local numbers = ffi.new("float[?]", count)
  local state = seed
  for slot = 0, count - 1 do
    state = (state * 1103515245 + 12345) % 2147483648
    local magnitude = 10 ^ ((state % 7) - 3)
    numbers[slot] = ((state / 2147483648) * 2 - 1) * magnitude
  end
  return numbers
end
-- }}}

-- {{{ local function identical(a, b, count)
-- Compared through their bits rather than as numbers, so that two values which
-- print the same but differ in the last place are still caught -- and so that
-- a NaN, which is never equal to itself, is compared honestly.
local function identical(a, b, count)
  local left = ffi.cast("const uint32_t *", a)
  local right = ffi.cast("const uint32_t *", b)
  for slot = 0, count - 1 do
    if left[slot] ~= right[slot] then
      return false, string.format("position %d: %.9g and %.9g (bits %08x and %08x)",
                                  slot, a[slot], b[slot], left[slot], right[slot])
    end
  end
  return true
end
-- }}}

-- {{{ matrix by vector
--
-- Shapes chosen so nothing is a multiple of four except where that is the
-- point: the wide version handles whole groups of four and then a remainder,
-- and a test using only multiples of four never exercises the remainder.
local shapes = {
  { rows = 1,  columns = 1 },
  { rows = 3,  columns = 1 },
  { rows = 1,  columns = 3 },
  { rows = 4,  columns = 4 },
  { rows = 5,  columns = 7 },
  { rows = 8,  columns = 32 },
  { rows = 48, columns = 32 },
  { rows = 32, columns = 176 },
  { rows = 7,  columns = 65 },
}

for _, shape in ipairs(shapes) do
  local rows, columns = shape.rows, shape.columns
  local matrix = drawn(rows * columns, 11 + rows * 31 + columns)
  local input = drawn(columns, 97 + columns)

  local expected = ffi.new("float[?]", rows)
  reference.kernels.matrix_vector(expected, matrix, input, rows, columns)

  local plain = ffi.new("float[?]", rows)
  kernels.matrix_vector_plain(plain, matrix, input, rows, columns)
  local same, where = identical(expected, plain, rows)
  check(string.format("plain, %d rows of %d", rows, columns), same, where)

  local wide = ffi.new("float[?]", rows)
  kernels.matrix_vector_wide(wide, matrix, input, rows, columns)
  same, where = identical(expected, wide, rows)
  check(string.format("four at a time, %d rows of %d", rows, columns), same, where)
end
-- }}}

-- {{{ normalisation
for _, size in ipairs({ 1, 3, 32, 33, 64 }) do
  local input = drawn(size, 5 + size)
  local weight = drawn(size, 500 + size)

  local expected = ffi.new("float[?]", size)
  reference.kernels.rms_normalise(expected, input, weight, size)

  local got = ffi.new("float[?]", size)
  kernels.rms_normalise(got, input, weight, size, 1e-5)

  local same, where = identical(expected, got, size)
  check(string.format("normalising %d numbers", size), same, where)
end
-- }}}

-- {{{ the exponential, and the two things built on it
--
-- These are the parts that used to force a tolerance. The exponential is now
-- specified rather than borrowed (047) and the turns that carry position are
-- carried rather than computed (034), so every function in a forward pass is
-- one that agrees across implementations -- and this comparison can be exact
-- like the others.
local exp_bits = ffi.new("float[1]")
local exp_check = ffi.new("float[1]")
local exact_exp = true
local exp_detail = nil
for step = -880, 880 do
  local x = step / 10
  exp_bits[0] = exponential.exp(x)
  exp_check[0] = kernels.exp_one(x)
  if not identical(exp_bits, exp_check, 1) then
    exact_exp = false
    exp_detail = string.format("at %.1f: %.9g and %.9g", x, exp_bits[0], exp_check[0])
    break
  end
end
check("the exponential agrees exactly across its whole range", exact_exp, exp_detail)

-- past both clamps, where the answer is exact rather than approximated
exp_bits[0] = exponential.exp(200)
exp_check[0] = kernels.exp_one(200)
check("and past the top of its range", identical(exp_bits, exp_check, 1))
exp_bits[0] = exponential.exp(-200)
exp_check[0] = kernels.exp_one(-200)
check("and past the bottom", identical(exp_bits, exp_check, 1))

-- Softmax over lengths that are and are not multiples of anything, including
-- one, because a single score must come out as certainty rather than as a
-- division by itself going wrong.
for _, count in ipairs({ 1, 2, 5, 16, 48 }) do
  local scores = drawn(count, 300 + count)
  local mine = ffi.new("float[?]", count)
  ffi.copy(mine, scores, count * 4)

  -- the reference's softmax is not exposed on its own, so it is applied here
  -- exactly as the forward pass applies it: largest removed, then the
  -- specified exponential, then divided by the total.
  local largest = mine[0]
  for slot = 1, count - 1 do if mine[slot] > largest then largest = mine[slot] end end
  local box = ffi.new("float[1]")
  local total = 0
  for slot = 0, count - 1 do
    box[0] = mine[slot] - largest
    mine[slot] = exponential.exp(box[0])
    box[0] = total + mine[slot]
    total = box[0]
  end
  for slot = 0, count - 1 do
    box[0] = mine[slot] / total
    mine[slot] = box[0]
  end

  local theirs = ffi.new("float[?]", count)
  ffi.copy(theirs, scores, count * 4)
  kernels.softmax(theirs, count)

  local same, where = identical(mine, theirs, count)
  check(string.format("softmax over %d scores", count), same, where)
end

-- The gate, which raises e to minus each value and divides by one plus it.
for _, count in ipairs({ 1, 7, 64 }) do
  local gate = drawn(count, 700 + count)
  local up = drawn(count, 800 + count)

  local mine = ffi.new("float[?]", count)
  local box = ffi.new("float[1]")
  for slot = 0, count - 1 do
    local value = gate[slot]
    box[0] = -value
    box[0] = 1 + exponential.exp(box[0])
    local divisor = box[0]
    box[0] = value / divisor
    box[0] = box[0] * up[slot]
    mine[slot] = box[0]
  end

  local theirs = ffi.new("float[?]", count)
  ffi.copy(theirs, gate, count * 4)
  kernels.swiglu(theirs, up, count)

  local same, where = identical(mine, theirs, count)
  check(string.format("the gate over %d numbers", count), same, where)
end
-- }}}

-- {{{ the edges
-- A row of no columns totals zero rather than whatever was in the register.
local empty_out = ffi.new("float[2]")
empty_out[0], empty_out[1] = 7, 7
local nothing = ffi.new("float[1]")
kernels.matrix_vector_plain(empty_out, nothing, nothing, 2, 0)
check("a row of no columns totals zero", empty_out[0] == 0 and empty_out[1] == 0,
      string.format("got %g and %g", empty_out[0], empty_out[1]))

-- No rows means no writing at all, not writing zeros.
local untouched = ffi.new("float[2]")
untouched[0], untouched[1] = 3, 4
kernels.matrix_vector_plain(untouched, nothing, nothing, 0, 8)
check("no rows writes nothing", untouched[0] == 3 and untouched[1] == 4)

-- A vector of zeros must not divide by zero. This is what the small constant
-- is for, and it is why it is part of the specification rather than a guard.
local zeros = ffi.new("float[8]")
local ones = ffi.new("float[8]")
for slot = 0, 7 do ones[slot] = 1 end
local normalised = ffi.new("float[8]")
kernels.rms_normalise(normalised, zeros, ones, 8, 1e-5)
local finite = true
for slot = 0, 7 do
  local value = normalised[slot]
  if value ~= value or value == math.huge or value == -math.huge then finite = false end
end
check("a vector of zeros normalises to something finite", finite)
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not cover:")
say("    - the other two architectures. Their kernels are not written, and")
say("      this test can only run the one it is standing on.")
say("    - anything downstream of an exponential, a sine or a cosine, which")
say("      differ between implementations and cannot be compared this way.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("kernels: " .. passed .. " of " .. (passed + failed)
                .. " as expected on " .. arch .. "\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
