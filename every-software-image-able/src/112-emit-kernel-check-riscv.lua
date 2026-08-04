-- 112-emit-kernel-check-riscv.lua
--
-- A payload that runs the third tongue's arithmetic on a bare machine and
-- says how many of its answers matched what the first tongue produced. The
-- other half of issue 401's third architecture.
--
-- For a general: the routines for this architecture cannot be tested on the
-- machine that wrote them, because that machine does not speak this
-- language. So the test is carried to a machine that does: the inputs, the
-- routines, and the answers the first architecture gave, all baked into one
-- program that boots, computes, compares, and reports.
--
-- WHY THE ANSWERS ARE CARRIED RATHER THAN RECOMPUTED. A payload that
-- computed its own expected answers would be comparing an implementation
-- against itself, which passes whatever it does. The bit patterns here came
-- off the first architecture, and they are compared as INTEGERS -- not as
-- numbers, so nothing rounds and "close" is not a thing that can happen.
--
-- WHY THIS FILE LOOKS NOTHING LIKE 101. On the other two architectures a
-- payload is assembler text and the assembler finishes the branch
-- arithmetic. Here it does not: a branch to a label in the same file leaves
-- a relocation, there is no linker to satisfy it, and the extracted bytes
-- encode a branch to the instruction's own address. Every loop would be a
-- silent infinite one. So the whole program -- prologue, routines, data,
-- comparisons -- is laid into ONE counted program (054), which measures
-- every distance itself. That is also why the routines cannot be pasted in
-- as text: the emitter has to see every instruction to count.
--
-- WHERE THINGS LIVE. s1 the code base, s3 the firmware's table, s4 its
-- console, s5 matched, s6 compared, s7 and s8 the first disagreement, s9
-- whether one has been captured, s10 and s11 the normalisations. The
-- routines that call the exponential use s0 through s3 and give them back,
-- so nothing here is disturbed by a call.

local M = {}

-- {{{ M.STACK_BYTES -- what the payload takes for its own working room
--
-- Results at sp+512, per-routine scratch at sp+1024, the hexadecimal buffer
-- at sp+64. Nothing is written inside the payload itself: firmware that
-- honours section rights maps the code read-only, so a buffer in the
-- instructions faults on some machines and not others.
M.STACK_BYTES = 4096
-- }}}

-- {{{ JOB_CALLS -- how each of the seven other routines is called here
--
-- One entry per routine that is not the matrix product or the
-- normalisation. Each receives the program, the job, and a way to address a
-- label, and leaves the answer at sp+1024 for the comparison that follows.
--
-- Written here rather than beside the test data because a calling sequence
-- is the one part of a job that is genuinely per-architecture. The shapes
-- and the numbers are the same on all three.
local JOB_CALLS = {}

JOB_CALLS.add_into = function(p, job, address)
  p:op("addi a0, sp, 1024")
  address("a1", job.extra_label)
  p:load_constant("a2", job.words)
  p:call("add_into")
end

JOB_CALLS.rotate = function(p, job, address)
  p:op("addi a0, sp, 1024")
  address("a1", job.extra_label)
  p:load_constant("a2", 4)                    -- heads
  p:load_constant("a3", 8)                    -- head width
  p:call("rotate")
end

JOB_CALLS.softmax = function(p, job, _address)
  p:op("addi a0, sp, 1024")
  p:load_constant("a1", job.words)
  p:call("softmax")
end

JOB_CALLS.swiglu = function(p, job, address)
  p:op("addi a0, sp, 1024")
  address("a1", job.extra_label)
  p:load_constant("a2", job.words)
  p:call("swiglu")
end

JOB_CALLS.attention_scores = function(p, job, address)
  p:op("addi a0, sp, 1024")
  address("a1", job.input_label)
  address("a2", job.extra_label)
  p:load_constant("a3", 8)                    -- eight past positions
  p:load_constant("a4", 16)                   -- sixteen numbers each
  p:load_constant("a5", 16)                   -- laid one after another
  p:load_constant("t0", job.scale_bits)
  p:op("fmv.w.x fa0, t0")
  p:call("attention_scores")
end

JOB_CALLS.attention_mix = function(p, job, address)
  p:op("addi a0, sp, 1024")
  address("a1", job.input_label)
  address("a2", job.extra_label)
  p:load_constant("a3", 8)
  p:load_constant("a4", 16)
  p:load_constant("a5", 16)
  p:call("attention_mix")
end

-- The exponential takes one number and gives one back, so it is called once
-- per value rather than handed a buffer. Every other routine here transforms
-- in place; this one is the exception and is written out rather than forced
-- into the same shape.
JOB_CALLS.exp_one = function(p, job, _address)
  p:op("addi s0, zero, 0")
  p:label("exp_job_loop")
  p:load_constant("t0", job.words)
  p:branch("bge", "s0", "t0", "exp_job_done")
  p:op("slli t1, s0, 2")
  p:op("addi t2, sp, 1024")
  p:op("add t2, t2, t1")
  p:op("flw fa0, 0(t2)")
  p:call("exp_one")
  p:op("slli t1, s0, 2")
  p:op("addi t2, sp, 1024")
  p:op("add t2, t2, t1")
  p:op("fsw fa0, 0(t2)")
  p:op("addi s0, s0, 1")
  p:jump("exp_job_loop")
  p:label("exp_job_done")
end
-- }}}

-- {{{ M.riscv64(options)
--
-- options: cases, recorded, norms, recorded_norm, jobs, number_at,
-- epsilon_bits, kernels (the module), specification, float_bits, dir
function M.riscv64(options)
  local words = dofile((options.dir or ".") .. "/src/054-riscv-words.lua")
  local p = words.new()

  -- {{{ the data pool -- every block of numbers, placed after the code
  --
  -- Held back and emitted at the end rather than inline, because this
  -- emitter counts bytes and a block of data in the middle of a routine is
  -- a block of bytes the routine would run straight into.
  local pool_order = {}
  local function pooled_words(label, values, as_bits)
    pool_order[#pool_order + 1] = {
      kind = "words", label = label, values = values, as_bits = as_bits,
    }
    return label
  end

  local strings, string_order = {}, {}
  local function pooled_text(text)
    if not strings[text] then
      strings[text] = "string" .. (#string_order + 1)
      string_order[#string_order + 1] = text
    end
    return strings[text]
  end
  -- }}}

  local function address(register, label)
    p:address(register, label, "s1")
  end

  -- {{{ saying things
  local function say_text(text)
    address("a1", pooled_text(text))
    p:op("mv a0, s4")
    p:op("ld t1, 8(s4)")
    p:op("jalr t1")
  end

  -- Spells t0 as sixteen hexadecimal characters at sp+64 and prints it. The
  -- digit is converted without a branch: 39 is the distance from the
  -- character after '9' to 'a', paid only when the digit is ten or more.
  local converted = 0
  local function say_hex(register)
    converted = converted + 1
    local loop = "hex" .. converted
    p:op("mv t0, " .. register)
    p:op("addi t1, sp, 64")
    p:op("addi t2, zero, 16")
    p:op("addi a6, zero, 39")
    p:label(loop)
    p:op("srli t3, t0, 60")
    p:op("slli t0, t0, 4")
    p:op("sltiu t4, t3, 10")
    p:op("xori t4, t4, 1")
    p:op("mul t4, t4, a6")
    p:op("addi t5, t3, 48")
    p:op("add t5, t5, t4")
    p:op("sh t5, 0(t1)")
    p:op("addi t1, t1, 2")
    p:op("addi t2, t2, -1")
    p:branch("bne", "t2", "zero", loop)
    p:op("sh zero, 0(t1)")
    p:op("addi a1, sp, 64")
    p:op("mv a0, s4")
    p:op("ld t1, 8(s4)")
    p:op("jalr t1")
  end
  -- }}}

  -- {{{ the prologue -- the anchor must be the very first instruction
  -- Every address in the pool is measured from offset zero, so whatever
  -- stands at offset zero is what the anchor must record.
  p:op("auipc s1, 0")
  p:op("mv s3, a1")                           -- the firmware's table
  p:op("ld s4, 64(s3)")                       -- its console
  p:load_constant("t0", M.STACK_BYTES)
  p:op("sub sp, sp, t0")
  p:op("mv s5, zero")                         -- matched
  p:op("mv s6, zero")                         -- compared
  p:op("mv s7, zero")                         -- what this machine got
  p:op("mv s8, zero")                         -- what the first tongue said
  p:op("mv s9, zero")                         -- whether one has been captured
  p:op("mv s10, zero")                        -- normalisations matched
  p:op("mv s11, zero")                        -- normalisations compared
  -- }}}

  say_text("\r\nchecking the third tongue against the first\r\n")

  -- {{{ comparing a run of words against what the first tongue said
  --
  -- Compared as integers, loaded WITHOUT sign extension so that a pattern
  -- with its top bit set is reported as the thirty-two bits it is rather
  -- than as the sixty-four bit negative it would sign-extend to.
  local compared = 0
  local function compare_words(got_at, want_label, count, matched_register,
                               total_register, capture)
    compared = compared + 1
    local loop = "wcmp" .. compared
    p:op("addi t0, sp, " .. got_at)
    address("t1", want_label)
    p:load_constant("t2", count)
    p:label(loop)
    p:op("lwu t3, 0(t0)")                     -- what this machine got
    p:op("lwu t4, 0(t1)")                     -- what the first tongue said
    p:op("addi " .. total_register .. ", " .. total_register .. ", 1")
    p:branch("beq", "t3", "t4", loop .. "same")
    if capture then
      -- the first disagreement is kept whole, and only the first
      p:branch("bne", "s9", "zero", loop .. "no")
      p:op("mv s7, t3")
      p:op("mv s8, t4")
      p:op("addi s9, zero, 1")
    end
    p:jump(loop .. "no")
    p:label(loop .. "same")
    p:op("addi " .. matched_register .. ", " .. matched_register .. ", 1")
    p:label(loop .. "no")
    p:op("addi t0, t0, 4")
    p:op("addi t1, t1, 4")
    p:op("addi t2, t2, -1")
    p:branch("bne", "t2", "zero", loop)
  end
  -- }}}

  -- {{{ every matrix case, run three ways
  --
  -- The exact pair are held to the same answer; the fast one is held to its
  -- own, because it sums in a different order on purpose and matching the
  -- exact one would mean it had stopped doing that.
  for case_index, case in ipairs(options.cases) do
    local entry = options.recorded[case_index]
    local matrix_label = "matrix" .. case_index
    local input_label = "input" .. case_index
    local want_label = "want" .. case_index
    local want_fast_label = "wantfast" .. case_index

    local matrix_values = {}
    for index = 0, case.rows * case.columns - 1 do
      matrix_values[#matrix_values + 1] = options.number_at(index + case_index * 100)
    end
    pooled_words(matrix_label, matrix_values)

    local input_values = {}
    for index = 0, case.columns - 1 do
      input_values[#input_values + 1] = options.number_at(index + case_index * 7000)
    end
    pooled_words(input_label, input_values)
    pooled_words(want_label, entry.answers, true)
    pooled_words(want_fast_label, entry.fast_answers, true)

    -- A mark per case, said before the case runs. Everything else this
    -- payload says comes at the end, so a machine that stops partway says
    -- nothing at all and the last mark is the only thing that narrows it.
    say_text(".")

    for _, which in ipairs({ { "matrix_vector_plain", want_label },
                             { "matrix_vector_wide", want_label },
                             { "matrix_vector_fast", want_fast_label } }) do
      p:op("addi a0, sp, 512")
      address("a1", matrix_label)
      address("a2", input_label)
      p:load_constant("a3", case.rows)
      p:load_constant("a4", case.columns)
      p:call(which[1])
      compare_words(512, which[2], case.rows, "s5", "s6", true)
    end
  end
  -- }}}

  -- {{{ the normalisations
  for case_index, size in ipairs(options.norms) do
    local entry = options.recorded_norm[case_index]
    local input_label = "ninput" .. case_index
    local weight_label = "nweight" .. case_index
    local want_label = "nwant" .. case_index

    local norm_input = {}
    for index = 0, size - 1 do
      norm_input[#norm_input + 1] = options.number_at(index + case_index * 300)
    end
    pooled_words(input_label, norm_input)

    local norm_weight = {}
    for index = 0, size - 1 do
      norm_weight[#norm_weight + 1] = options.number_at(index + case_index * 900)
    end
    pooled_words(weight_label, norm_weight)
    pooled_words(want_label, entry.answers, true)

    p:op("addi a0, sp, 512")
    address("a1", input_label)
    address("a2", weight_label)
    p:load_constant("a3", size)
    -- the small constant, as the exact pattern the host used
    p:load_constant("t0", options.epsilon_bits)
    p:op("fmv.w.x fa0, t0")
    p:call("rms_normalise")
    compare_words(512, want_label, size, "s10", "s11", false)
  end
  -- }}}

  -- {{{ the seven that transform a buffer
  --
  -- Every one takes a buffer, changes it, and is compared against what the
  -- first architecture made of the same buffer. That covers the shapes the
  -- matrix product does not: one that calls another routine, one that walks
  -- pairs, two that read a second array at a stride, and the exponential,
  -- which everything above it depends on being exact.
  for _, job in ipairs(options.jobs or {}) do
    job.input_label = job.name .. "in"
    job.extra_label = job.name .. "ex"
    job.want_label = job.name .. "want"
    pooled_words(job.input_label, job.input)
    if job.extra then pooled_words(job.extra_label, job.extra) end
    pooled_words(job.want_label, job.want, true)

    say_text(",")

    -- Most of these change the buffer they are given, so it is copied into
    -- scratch first and the original stays intact. The two attention
    -- routines write a fresh output instead and read their inputs where they
    -- lie, so they say so and the copy is skipped.
    if not job.no_copy then
      p:op("addi t0, sp, 1024")
      address("t1", job.input_label)
      p:load_constant("t2", job.words)
      p:label("copy" .. job.name)
      p:op("lw t3, 0(t1)")
      p:op("sw t3, 0(t0)")
      p:op("addi t0, t0, 4")
      p:op("addi t1, t1, 4")
      p:op("addi t2, t2, -1")
      p:branch("bne", "t2", "zero", "copy" .. job.name)
    end

    local emit_call = JOB_CALLS[job.name]
      or error("112-emit-kernel-check-riscv: no calling sequence written for '"
               .. job.name .. "'. A routine with no way to call it is a "
               .. "routine this test silently does not cover.")
    emit_call(p, job, address)

    compare_words(1024, job.want_label, job.compare, "s5", "s6", true)
  end
  -- }}}

  say_text("kernels checked\r\n  matched ")
  say_hex("s5")
  say_text("\r\n  of ")
  say_hex("s6")
  say_text("\r\n  norms ")
  say_hex("s10")
  say_text("\r\n  nof ")
  say_hex("s11")
  say_text("\r\n  got ")
  say_hex("s7")
  say_text("\r\n  want ")
  say_hex("s8")
  say_text("\r\n")

  p:label("halted")
  p:op("wfi")
  p:jump("halted")

  -- {{{ the routines, after everything that runs straight through
  -- They are only ever reached by a call, so they sit past the halt where
  -- nothing can fall into them.
  options.kernels.emit(p, nil, {
    specification = options.specification,
    float_bits = options.float_bits,
  })
  -- }}}

  -- {{{ the pool -- numbers first, then the strings
  local float_bits = options.float_bits
  for _, block in ipairs(pool_order) do
    p:align(16)
    p:label(block.label)
    for _, value in ipairs(block.values) do
      p:word(block.as_bits and value or float_bits.of(value))
    end
    -- REFUSE A BLOCK THAT IS NOT VARIED. The same guard 101 carries: a
    -- payload was once built holding two hundred and fifty-six numbers of
    -- which three were distinct, and the machine that ran it did correct
    -- arithmetic over wrong data and was very nearly recorded as a broken
    -- port. Small blocks are exempt because a short run can legitimately
    -- repeat, and refusing that would be refusing arithmetic.
    local distinct, count = {}, 0
    for _, value in ipairs(block.values) do
      local pattern = block.as_bits and value or float_bits.of(value)
      if not distinct[pattern] then
        distinct[pattern] = true
        count = count + 1
      end
    end
    if #block.values > 8 and count < #block.values * 0.9 then
      error(string.format(
        "112-emit-kernel-check-riscv: '%s' would carry %d numbers of which "
        .. "only %d are distinct. That is not test data, it is one number "
        .. "repeated, and a machine given it will compute the right answer "
        .. "over the wrong inputs and look broken.",
        block.label, #block.values, count))
    end
  end

  for _, text in ipairs(string_order) do
    p:align(4)
    p:label(strings[text])
    p:shorts(text)
  end
  -- }}}

  return p:resolve()
end
-- }}}

return M
