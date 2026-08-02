-- 057-emit-sampler.lua
--
-- The sampler, in assembly: scores in, one chosen token out, with the chance
-- drawn from the carried stream. The assembly twin of 040, required to agree
-- with it choice for choice and bit for bit -- because a chosen token is
-- discrete, and a hair of difference at one boundary sends two
-- implementations down different lives from that moment on.
--
-- For a general: the model hands over a number for every word it might say
-- next. This picks one, by weighted chance, using randomness the image
-- carries -- and it picks the very same one the readable version picks,
-- always, which is what lets a machine on bare metal be reproduced exactly
-- on a development machine.
--
-- THE SHAPE. Like the conductor (056), the routine takes plans rather than
-- names: a stream structure holding the carried numbers and the generator's
-- state, and a plan holding scratch space, the settings, and the address of
-- the specified exponential. Layouts are declared once as data; the FFI view
-- is checked against the assembly's offsets slot by slot.
--
-- NO SORT. The reference orders every token by likelihood and cuts the tail.
-- Repeatedly extracting the first strict maximum reaches the same order
-- lazily, stops as soon as the cutters say stop, and needs no sorting at
-- all -- the tie rule (equal chances go to the lower token) is what makes
-- the two walks provably identical.

local ffi = require("ffi")

local M = {}

-- {{{ M.STREAM_SLOTS -- the carried stream, one slot per row, eight bytes each
M.STREAM_SLOTS = {
  { name = "numbers",    declaration = "const uint32_t *numbers" },
  { name = "count",      declaration = "int64_t count" },
  { name = "position",   declaration = "int64_t position" },   -- next to consume, from zero
  { name = "state",      declaration = "int64_t state" },
  { name = "drawn",      declaration = "int64_t drawn" },
  { name = "per_number", declaration = "int64_t per_number" },
  { name = "wrapped",    declaration = "int64_t wrapped" },
}
-- }}}

-- {{{ M.PLAN_SLOTS -- everything a choice needs, eight bytes each
M.PLAN_SLOTS = {
  { name = "k_exp_one",     declaration = "float (*k_exp_one)(float)" },
  { name = "probabilities", declaration = "float *probabilities" },   -- count floats
  { name = "kept_chances",  declaration = "float *kept_chances" },    -- count floats
  { name = "kept_tokens",   declaration = "int64_t *kept_tokens" },   -- count numbers
  { name = "stream",        declaration = "SamplerStream *stream" },
  { name = "temperature",   declaration = "float temperature; float temperature_pad" },
  { name = "top_p",         declaration = "float top_p; float top_p_pad" },
  { name = "top_k",         declaration = "int64_t top_k" },
}
-- }}}

-- {{{ offsets, computed
local function offsets_of(slots)
  local at, offsets = 0, {}
  for _, slot in ipairs(slots) do
    offsets[slot.name] = at
    at = at + 8
  end
  return offsets
end

function M.stream_offsets() return offsets_of(M.STREAM_SLOTS) end
function M.plan_offsets() return offsets_of(M.PLAN_SLOTS) end
-- }}}

-- {{{ M.declare() -- the structures as the host's FFI sees them, checked
function M.declare()
  local function declare_struct(name, slots)
    local lines = { "typedef struct {" }
    for _, slot in ipairs(slots) do
      lines[#lines + 1] = "  " .. slot.declaration .. ";"
    end
    lines[#lines + 1] = "} " .. name .. ";"
    ffi.cdef(table.concat(lines, "\n"))

    local offsets = offsets_of(slots)
    for _, slot in ipairs(slots) do
      if ffi.offsetof(name, slot.name) ~= offsets[slot.name] then
        error("057-emit-sampler: slot '" .. slot.name .. "' of " .. name
          .. " sits at " .. tostring(ffi.offsetof(name, slot.name))
          .. " for the FFI and " .. offsets[slot.name] .. " for the assembly.")
      end
    end
  end

  declare_struct("SamplerStream", M.STREAM_SLOTS)
  declare_struct("SamplerPlan", M.PLAN_SLOTS)

  ffi.cdef[[
    float exp_one(float x);
    int64_t sampler_choose(const SamplerPlan *plan, const float *scores,
                           int64_t count, float *chance_out);
  ]]
end
-- }}}

-- {{{ M.new_stream(numbers)
-- The carried file as the assembly sees it. `numbers` is the Lua array 040
-- generates; the position starts at the beginning and the drawn count starts
-- exhausted, so the first draw seeds from the file exactly as the reference
-- does when its state is still empty.
function M.new_stream(numbers)
  local carried = ffi.new("uint32_t[?]", #numbers)
  for index = 1, #numbers do carried[index - 1] = numbers[index] end
  local stream = ffi.new("SamplerStream")
  stream.numbers = carried
  stream.count = #numbers
  stream.position = 0
  stream.state = 0
  stream.per_number = 4096
  stream.drawn = stream.per_number
  stream.wrapped = 0
  return { stream = stream, keep = { carried } }
end
-- }}}

-- {{{ M.new_plan(kernels, count, settings, stream_holder)
function M.new_plan(kernels, count, settings, stream_holder)
  local plan = ffi.new("SamplerPlan")
  plan.k_exp_one = kernels.exp_one
  local scratch = {
    probabilities = ffi.new("float[?]", count),
    kept_chances = ffi.new("float[?]", count),
    kept_tokens = ffi.new("int64_t[?]", count),
  }
  plan.probabilities = scratch.probabilities
  plan.kept_chances = scratch.kept_chances
  plan.kept_tokens = scratch.kept_tokens
  plan.stream = stream_holder.stream
  plan.temperature = settings.temperature or 1.0
  plan.top_p = settings.top_p or 1.0
  plan.top_k = settings.top_k or count
  return { plan = plan, keep = { scratch, stream_holder, kernels } }
end
-- }}}

-- {{{ M.x86_64()
--
-- int64_t sampler_choose(const SamplerPlan *plan, const float *scores,
--                        int64_t count, float *chance_out)
--
-- plan rdi, scores rsi, count rdx, chance_out rcx. The token comes back in
-- rax; the chance it was chosen with lands in chance_out.
--
-- Registers that survive the exponential's calls: r15 the plan, r14 the
-- scores, r13 the count, r12 where the chance goes, rbx the loop the call
-- sits inside, rbp the keep limit. Floating accumulators live on the stack,
-- because every vector register belongs to whoever was called last.
function M.x86_64()
  local plan = M.plan_offsets()
  local stream = M.stream_offsets()
  local out = {}
  local function line(text) out[#out + 1] = text end
  local function slot(name) return plan[name] .. "(%r15)" end

  line("  .globl sampler_choose")
  line("  .type sampler_choose, @function")
  line("sampler_choose:")
  line("  pushq %rbp")
  line("  pushq %rbx")
  line("  pushq %r12")
  line("  pushq %r13")
  line("  pushq %r14")
  line("  pushq %r15")
  -- three floats of loop state and the padding that keeps calls aligned:
  --   0(%rsp) the running total   4(%rsp) the largest score
  --   8(%rsp) the kept total
  line("  subq $24, %rsp")
  line("  movq %rdi, %r15")
  line("  movq %rsi, %r14")
  line("  movq %rdx, %r13")
  line("  movq %rcx, %r12")

  -- {{{ a temperature of zero is a different instruction: take the highest
  line("  movss " .. slot("temperature") .. ", %xmm0")
  line("  xorps %xmm1, %xmm1")
  line("  comiss %xmm1, %xmm0")
  line("  ja warm")

  line("  movss (%r14), %xmm2")            -- the first, until beaten
  line("  xorl %eax, %eax")
  line("  movl $1, %r9d")
  line("cold_scan:")
  line("  cmpq %r13, %r9")
  line("  jge cold_done")
  line("  movss (%r14,%r9,4), %xmm3")
  line("  comiss %xmm2, %xmm3")
  line("  jbe cold_next")                  -- only strictly greater replaces,
  line("  movaps %xmm3, %xmm2")            -- so the first of equals wins
  line("  movq %r9, %rax")
  line("cold_next:")
  line("  incq %r9")
  line("  jmp cold_scan")
  line("cold_done:")
  line("  movl $0x3f800000, %edx")         -- chosen with certainty: one
  line("  movl %edx, (%r12)")
  line("  jmp done")
  line("warm:")
  -- }}}

  -- {{{ scores into probabilities, every step at single precision
  line("  movss (%r14), %xmm2")            -- the largest, found first
  line("  movl $1, %r9d")
  line("largest_scan:")
  line("  cmpq %r13, %r9")
  line("  jge largest_done")
  line("  movss (%r14,%r9,4), %xmm3")
  line("  comiss %xmm2, %xmm3")
  line("  jbe largest_next")
  line("  movaps %xmm3, %xmm2")
  line("largest_next:")
  line("  incq %r9")
  line("  jmp largest_scan")
  line("largest_done:")
  line("  movss %xmm2, 4(%rsp)")

  line("  movl $0, 0(%rsp)")               -- the total starts at nothing
  line("  xorl %ebx, %ebx")
  line("prob_loop:")
  line("  movss (%r14,%rbx,4), %xmm0")
  line("  subss 4(%rsp), %xmm0")           -- the largest off first
  line("  divss " .. slot("temperature") .. ", %xmm0")
  line("  callq *" .. slot("k_exp_one"))
  line("  movq " .. slot("probabilities") .. ", %rax")
  line("  movss %xmm0, (%rax,%rbx,4)")
  line("  addss 0(%rsp), %xmm0")           -- accumulated in ascending order
  line("  movss %xmm0, 0(%rsp)")
  line("  incq %rbx")
  line("  cmpq %r13, %rbx")
  line("  jl prob_loop")

  line("  xorl %ebx, %ebx")
  line("divide_loop:")
  line("  movq " .. slot("probabilities") .. ", %rax")
  line("  movss (%rax,%rbx,4), %xmm0")
  line("  divss 0(%rsp), %xmm0")
  line("  movss %xmm0, (%rax,%rbx,4)")
  line("  incq %rbx")
  line("  cmpq %r13, %rbx")
  line("  jl divide_loop")
  -- }}}

  -- {{{ keep the likeliest, in order, until a cutter says stop
  --
  -- Each round takes the first strict maximum still standing, records it,
  -- and fells it. The felled value is minus one, which no probability can
  -- be, so a consumed slot never wins again.
  line("  movq " .. slot("top_k") .. ", %rbp")
  line("  cmpq %r13, %rbp")
  line("  jle limit_known")
  line("  movq %r13, %rbp")
  line("limit_known:")
  line("  movl $0, 8(%rsp)")               -- the kept total starts at nothing
  line("  xorl %ebx, %ebx")
  line("select_loop:")
  line("  cmpq %rbp, %rbx")
  line("  jge select_done")

  line("  movq " .. slot("probabilities") .. ", %rax")
  line("  movss (%rax), %xmm2")
  line("  xorl %r8d, %r8d")
  line("  movl $1, %r9d")
  line("best_scan:")
  line("  cmpq %r13, %r9")
  line("  jge best_done")
  line("  movss (%rax,%r9,4), %xmm3")
  line("  comiss %xmm2, %xmm3")
  line("  jbe best_next")
  line("  movaps %xmm3, %xmm2")
  line("  movq %r9, %r8")
  line("best_next:")
  line("  incq %r9")
  line("  jmp best_scan")
  line("best_done:")

  line("  movq " .. slot("kept_tokens") .. ", %rdx")
  line("  movq %r8, (%rdx,%rbx,8)")
  line("  movq " .. slot("kept_chances") .. ", %rdx")
  line("  movss %xmm2, (%rdx,%rbx,4)")
  line("  movl $0xbf800000, (%rax,%r8,4)") -- felled: minus one
  line("  movss 8(%rsp), %xmm1")
  line("  addss %xmm2, %xmm1")
  line("  movss %xmm1, 8(%rsp)")
  line("  incq %rbx")
  line("  comiss " .. slot("top_p") .. ", %xmm1")
  line("  jae select_done")                -- enough of the chance is covered
  line("  jmp select_loop")
  line("select_done:")
  -- }}}

  -- {{{ one draw from the stream
  --
  -- The reference's next(), instruction for instruction: reseed from the
  -- carried file when this number is spent, step the generator in exact
  -- sixty-four bit integers, and hand back the state as a single divided by
  -- two to the thirty-first -- an exponent move that rounds nothing.
  line("  movq " .. slot("stream") .. ", %r10")
  line("  movq " .. stream.drawn .. "(%r10), %rax")
  line("  cmpq " .. stream.per_number .. "(%r10), %rax")
  line("  jl seeded")
  line("  movq " .. stream.numbers .. "(%r10), %rdx")
  line("  movq " .. stream.position .. "(%r10), %rax")
  line("  movl (%rdx,%rax,4), %ecx")
  line("  movq %rcx, " .. stream.state .. "(%r10)")
  line("  movq $0, " .. stream.drawn .. "(%r10)")
  line("  incq %rax")
  line("  cmpq " .. stream.count .. "(%r10), %rax")
  line("  jl position_kept")
  line("  xorl %eax, %eax")                -- back to the start, and noticed
  line("  movq $1, " .. stream.wrapped .. "(%r10)")
  line("position_kept:")
  line("  movq %rax, " .. stream.position .. "(%r10)")
  line("seeded:")
  line("  movq " .. stream.state .. "(%r10), %rax")
  line("  imulq $1103515245, %rax, %rax")
  line("  addq $12345, %rax")
  line("  andq $0x7fffffff, %rax")
  line("  movq %rax, " .. stream.state .. "(%r10)")
  line("  incq " .. stream.drawn .. "(%r10)")
  line("  cvtsi2ssq %rax, %xmm0")
  line("  movl $0x4f000000, %edx")         -- two to the thirty-first, as bits
  line("  movd %edx, %xmm1")
  line("  divss %xmm1, %xmm0")
  line("  mulss 8(%rsp), %xmm0")           -- scaled to what was kept
  -- }}}

  -- {{{ walk the kept until the draw is spent
  line("  xorps %xmm1, %xmm1")
  line("  xorl %r9d, %r9d")
  line("walk:")
  line("  cmpq %rbx, %r9")
  line("  jge walk_past_end")
  line("  movq " .. slot("kept_chances") .. ", %rdx")
  line("  movss (%rdx,%r9,4), %xmm2")
  line("  addss %xmm2, %xmm1")
  line("  comiss %xmm1, %xmm0")
  line("  jbe chosen")                     -- the draw landed inside this one
  line("  incq %r9")
  line("  jmp walk")
  line("walk_past_end:")
  -- rounding can leave the draw a hair past the end; the last kept is the
  -- right answer there, and taking it is arithmetic rather than a fallback.
  line("  leaq -1(%rbx), %r9")
  line("chosen:")
  line("  movq " .. slot("kept_chances") .. ", %rdx")
  line("  movss (%rdx,%r9,4), %xmm2")
  line("  movss %xmm2, (%r12)")
  line("  movq " .. slot("kept_tokens") .. ", %rdx")
  line("  movq (%rdx,%r9,8), %rax")
  -- }}}

  line("done:")
  line("  addq $24, %rsp")
  line("  popq %r15")
  line("  popq %r14")
  line("  popq %r13")
  line("  popq %r12")
  line("  popq %rbx")
  line("  popq %rbp")
  line("  retq")
  line("")

  return table.concat(out, "\n")
end
-- }}}

return M
