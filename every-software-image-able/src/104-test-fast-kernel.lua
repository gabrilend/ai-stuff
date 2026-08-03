#!/usr/bin/env luajit
-- 104-test-fast-kernel.lua
--
-- Holds the fast matrix product to its own readable twin, bit for bit, and
-- measures both what it buys and what it costs.
--
-- For a general: the project has two specifications for the same operation
-- now. The exact one adds in a fixed order and gives the same answer on
-- every machine; the fast one keeps four totals at once and gives a slightly
-- different answer, in exchange for the processor being able to do four
-- additions instead of waiting between each one.
--
-- This does three things. It requires the fast assembly to match the fast
-- reference exactly -- the discipline does not relax just because the
-- specification changed. It measures how far the two specifications land
-- from each other, so the price is a number. And it times them, so the
-- purchase is a number too.
--
-- usage:
--   luajit 104-test-fast-kernel.lua [--dir ROOT] [--seconds N]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local ffi = require("ffi")

ffi.cdef[[
  typedef long time_t;
  struct timespec { time_t tv_sec; long tv_nsec; };
  int clock_gettime(int clock, struct timespec *spec);
]]

-- {{{ local function now()
local spec = ffi.new("struct timespec[1]")
local function now()
  ffi.C.clock_gettime(1, spec)
  return tonumber(spec[0].tv_sec) + tonumber(spec[0].tv_nsec) / 1e9
end
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

-- {{{ local function host_architecture()
local function host_architecture()
  local pipe = io.popen("uname -m")
  local name = pipe and pipe:read("*l") or "unknown"
  if pipe then pipe:close() end
  return name
end
-- }}}

-- {{{ main
local budget = 1.0
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--seconds" then
    index = index + 1 ; budget = tonumber(arg[index]) or 1.0
  end
  index = index + 1
end

local arch = host_architecture()

say("")
say("  the fast arithmetic, against its own twin")
say("  " .. string.rep("-", 62))
say("")

local emit = dofile(DIR .. "/src/043-emit-kernels.lua")
if not emit[arch] then
  say("  no kernels for " .. arch .. "; nothing was tested")
  os.exit(1)
end

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/kernels")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

local specification = dofile(DIR .. "/src/047-reference-exp.lua")
local source = DIR .. "/tmp/shared-memory/kernels/kernels-" .. arch .. ".s"
local library = DIR .. "/tmp/kernels/fast-" .. arch .. ".so"
local handle = io.open(source, "w")
handle:write(emit.source(arch, specification))
handle:close()
if not run_one("clang -shared -O2 -o " .. library .. " " .. source) then
  say("  the kernels would not assemble")
  os.exit(1)
end

ffi.cdef[[
  void matrix_vector_plain(float *out, const float *matrix, const float *input,
                           int rows, int columns);
  void matrix_vector_wide(float *out, const float *matrix, const float *input,
                          int rows, int columns);
  void matrix_vector_fast(float *out, const float *matrix, const float *input,
                          int rows, int columns);
]]
local kernels = ffi.load(library)
local fast = dofile(DIR .. "/src/103-reference-fast.lua")

local passed, failed = 0, 0
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

-- {{{ the shapes, chosen so the remainder path is exercised rather than assumed
local SHAPES = {
  { rows = 1, columns = 1 },
  { rows = 3, columns = 3 },
  { rows = 4, columns = 4 },
  { rows = 5, columns = 7 },
  { rows = 8, columns = 32 },
  { rows = 7, columns = 65 },
  { rows = 32, columns = 176 },
}

local function numbers_for(shape, salt)
  local matrix = ffi.new("float[?]", shape.rows * shape.columns)
  local input = ffi.new("float[?]", shape.columns)
  for index = 0, shape.rows * shape.columns - 1 do
    matrix[index] = ((index * 2654435761 + salt) % 1000003) / 500000.0 - 1.0
  end
  for index = 0, shape.columns - 1 do
    input[index] = ((index * 40503 + salt) % 1000003) / 500000.0 - 1.0
  end
  return matrix, input
end
-- }}}

-- {{{ the assembly matches its own twin, bit for bit
local all_exact, where = true, nil
for salt, shape in ipairs(SHAPES) do
  local matrix, input = numbers_for(shape, salt * 13)
  local from_assembly = ffi.new("float[?]", shape.rows)
  local from_reference = ffi.new("float[?]", shape.rows)

  kernels.matrix_vector_fast(from_assembly, matrix, input, shape.rows, shape.columns)
  fast.matrix_vector_fast(from_reference, matrix, input, shape.rows, shape.columns)

  for row = 0, shape.rows - 1 do
    if from_assembly[row] ~= from_reference[row] then
      all_exact = false
      where = where or string.format("%d rows of %d, row %d: %.9g against %.9g",
                                     shape.rows, shape.columns, row,
                                     from_assembly[row], from_reference[row])
    end
  end
end
check("the fast assembly matches its own reference exactly", all_exact, where)
say("")
say("  The discipline did not relax. A second specification still has a")
say("  readable twin and is still compared by bits -- what changed is which")
say("  question is being answered, not how carefully.")
say("")
-- }}}

-- {{{ what the divergence actually costs
say("  how far the two specifications land from each other:")
say("")
-- {{{ the bound is DERIVED, not chosen
--
-- A tolerance somebody picked is exactly what this project refuses, because
-- it turns every future disagreement into an argument about whether the
-- number is small enough. A tolerance computed from the arithmetic is a
-- different thing: it says what reordering CAN do, so anything past it is
-- not reordering.
--
-- One rounding of a single-precision number is about 1.19 parts in ten
-- million. Summing N terms in two different orders can differ by about N of
-- those in the worst case, and more where the products cancel and the
-- result is small compared to the terms that made it. So the bound scales
-- with the number of columns, and the first check to fail here was the
-- test's guess rather than the kernel: a hand-picked one-part-in-a-hundred-
-- thousand refused a 176-term sum that was behaving exactly as it should.
local EPSILON = 1.1920929e-7
-- }}}

local all_within, too_far = true, nil
for salt, shape in ipairs(SHAPES) do
  local matrix, input = numbers_for(shape, salt * 13)
  local exact = ffi.new("float[?]", shape.rows)
  local quick = ffi.new("float[?]", shape.rows)
  kernels.matrix_vector_plain(exact, matrix, input, shape.rows, shape.columns)
  kernels.matrix_vector_fast(quick, matrix, input, shape.rows, shape.columns)

  local difference = fast.differs_from_exact(quick, exact, shape.rows)
  local allowed = shape.columns * EPSILON
  if difference.worst > allowed then
    all_within = false
    too_far = too_far or string.format(
      "%d rows of %d: %.3e apart, and reordering %d terms allows %.3e",
      shape.rows, shape.columns, difference.worst, shape.columns, allowed)
  end

  say(string.format("    %3d rows of %3d   %d of %d identical   "
                    .. "worst apart %.3e   reordering allows %.3e",
                    shape.rows, shape.columns, difference.identical,
                    difference.of, difference.worst, allowed))
end
say("")

check("the two differ by no more than reordering can explain",
      all_within, too_far)
-- }}}

-- {{{ and what it buys
say("")
say("  and what that buys:")
say("")

local shape = { rows = 32, columns = 176 }
local matrix, input = numbers_for(shape, 7)
local out = ffi.new("float[?]", shape.rows)

local function time_it(name, call)
  call()
  local started, count = now(), 0
  repeat
    call()
    count = count + 1
  until now() - started >= budget
  local elapsed = now() - started
  local rate = count / elapsed
  say(string.format("    %-34s %12.0f a second", name, rate))
  return rate
end

local plain = time_it("one at a time", function()
  kernels.matrix_vector_plain(out, matrix, input, shape.rows, shape.columns)
end)
local exact_wide = time_it("four at a time, one total", function()
  kernels.matrix_vector_wide(out, matrix, input, shape.rows, shape.columns)
end)
local quick = time_it("four at a time, four totals", function()
  kernels.matrix_vector_fast(out, matrix, input, shape.rows, shape.columns)
end)

say("")
say(string.format("    keeping the order costs   %.2fx over one at a time",
                  exact_wide / plain))
say(string.format("    letting it go gives       %.2fx over one at a time",
                  quick / plain))
say(string.format("    so the exactness was worth %.2fx",
                  quick / exact_wide))
say("")

check("the fast one is faster than the exact one", quick > exact_wide,
      string.format("%.0f against %.0f", quick, exact_wide))
-- }}}

say("")
say("  " .. string.rep("-", 62))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this changes, and what it does not:")
say("    - two machines of different kinds will now produce slightly")
say("      different numbers, so a thought from one cannot be reproduced on")
say("      the other. That was decided rather than discovered.")
say("    - one machine remains exactly reproducible: same image, same")
say("      carried numbers, same input, same words, every time.")
say("    - the exact kernel stays, and is what proves a port to a new")
save = nil
say("      architecture is honest before the fast one is trusted there.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("fast kernel: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
