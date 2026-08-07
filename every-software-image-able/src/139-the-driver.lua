-- 139-the-driver.lua
--
-- The loop, in the processor's own instructions: read what the machine was
-- told, turn it into numbers, run the engine, draw a word, say it, put it
-- back, and go round again. Issue 107a -- steps five through eight of `107`.
--
-- For a general: everything under this file has been provable alone for a
-- while. The arithmetic agrees with a readable twin, so does the sampler, so
-- does the tokenizer, and the setup that finds the weights and divides the
-- memory agrees too. None of that is a machine that thinks. This is the piece
-- that makes them one, and it is the piece that turns a card which boots and
-- halts into a card which boots and talks.
--
-- EVERYTHING IT CALLS, IT CALLS THROUGH A POINTER, and that is not a style
-- choice. There is no linker. A call written by name needs somebody to fill
-- in the offset afterwards, and the thing that would have done it does not
-- exist -- which is exactly the defect that cost this project two of the four
-- silences in `107`'s table: an offset that stayed zero, and a call with
-- offset zero is a call to itself. So the routines' addresses arrive in a
-- plan, the same way the conducting takes its kernels (`056`), and whoever
-- fills that plan is the only thing that has to know where anything is.
--
-- THE ORDER OF THE LOOP IS THE READABLE LOOP'S ORDER, EXACTLY (`061`).
-- Length checked before drawing; the finish token checked after drawing and
-- the drawn token not kept; the room checked after keeping and before
-- conducting. That ordering is not arbitrary and it is not cosmetic -- each
-- of those three decides whether one more token is drawn, a drawn token is
-- discrete, and one different token means the two machines are having
-- different conversations from that moment on. This is the one place in the
-- project where matching the reference means matching its control flow rather
-- than its arithmetic.
--
-- THE CACHE IS APPENDED TO, NOT REBUILT. The readable loop reuses the longest
-- common prefix of what the cache already holds, because between turns it can
-- be handed a whole new context. This one only ever appends, so it keeps a
-- position and advances it -- the same arithmetic with none of the
-- comparison. That is correct ONLY while nothing rewrites the context
-- underneath it, which is true today and stops being true the moment the
-- machine can drop or reorder what it is holding.
--
-- WHAT IT IS NOT. It is not the machine's whole life. It does one turn and
-- returns why it stopped, and the forever-loop that ought to sit around it is
-- deliberately absent, because with no hands and no channel there is nothing
-- for the machine to think about next -- it would draw from the same scores
-- forever. The outer loop arrives with the hands (step nine of `107`), which
-- is what gives a finished turn something to have been about.

local M = {}

-- {{{ M.PLAN_SLOTS -- everything a turn needs, eight bytes each
--
-- One structure rather than fifteen arguments, for the reason `056` and `057`
-- give: a routine that takes plans takes the same three registers forever, and
-- adding something it needs does not change every place that calls it.
--
-- The first nine are addresses of code, the next seven are addresses of
-- memory, then the counts, then the four the routine writes back. Grouped that
-- way because the groups are filled by different things -- the code addresses
-- by whoever laid the engine down, the memory by whoever divided it, the
-- counts by the model's header -- and a slot in the wrong group is a slot
-- somebody filled from the wrong source.
M.PLAN_SLOTS = {
  -- what to call
  { name = "k_encode",     declaration = "int64_t (*k_encode)(const void *, const uint8_t *, int64_t, int32_t *)" },
  { name = "k_decode",     declaration = "int64_t (*k_decode)(const void *, const int32_t *, int64_t, uint8_t *)" },
  { name = "k_forward",    declaration = "void (*k_forward)(const void *, int64_t, int64_t, float *)" },
  { name = "k_choose",     declaration = "int64_t (*k_choose)(const void *, const float *, int64_t, float *)" },
  { name = "k_say",        declaration = "void (*k_say)(const uint8_t *, int64_t, void *)" },

  -- what to call it with
  { name = "conductor",    declaration = "void *conductor" },
  { name = "tokenizer",    declaration = "void *tokenizer" },
  { name = "sampler",      declaration = "void *sampler" },
  { name = "say_context",  declaration = "void *say_context" },

  -- where the memory is
  { name = "text",         declaration = "const uint8_t *text" },      -- what it was told
  { name = "text_bytes",   declaration = "int64_t text_bytes" },
  { name = "tokens",       declaration = "int32_t *tokens" },          -- room for `context`
  { name = "spoken",       declaration = "int32_t *spoken" },          -- room for `max_tokens`
  { name = "scores",       declaration = "float *scores" },            -- room for `vocabulary`
  { name = "chance",       declaration = "float *chance" },            -- one number the sampler writes
  { name = "say_room",     declaration = "uint8_t *say_room" },        -- one token's text at a time

  -- what the model is
  { name = "vocabulary",   declaration = "int64_t vocabulary" },
  { name = "context",      declaration = "int64_t context" },
  { name = "finish_token", declaration = "int64_t finish_token" },
  { name = "max_tokens",   declaration = "int64_t max_tokens" },

  -- what came of it
  { name = "position",     declaration = "int64_t position" },
  { name = "said",         declaration = "int64_t said" },
  { name = "reason",       declaration = "int64_t reason" },
  { name = "detail",       declaration = "int64_t detail" },
}
-- }}}

-- {{{ M.REASONS -- why a turn stopped, as numbers
--
-- Numbers rather than text, because the only thing that reads them on a bare
-- machine is a person looking at a serial port and a test parsing one. The
-- three that are not failures are positive and the four that are come back
-- negative, so a caller that only wants to know whether anything went wrong
-- looks at the sign.
--
-- A FINISHED TURN AND AN EXHAUSTED ONE ARE DIFFERENT and are kept different.
-- "It said what it had to say" and "it ran out of room to think in" look
-- identical from outside -- both are a machine that stopped talking -- and
-- they call for completely different responses from whoever is watching.
M.REASONS = {
  finished     =  1,   -- the token that means finished, drawn and swallowed
  length       =  2,   -- as many words as it was allowed
  room_ran_out =  3,   -- the context is full; what to let go of is not this
                       -- routine's decision and never was (`052`)
  unsayable    = -1,   -- a byte of the text no token says; `detail` says where
  too_long     = -2,   -- more tokens than the machine can hold; `detail` says
                       -- how many were asked of it
  nothing      = -3,   -- it was told nothing at all
  unknown      = -4,   -- a drawn token the vocabulary cannot say back
}
-- }}}

-- {{{ M.plan_offsets() and M.declare()
function M.plan_offsets()
  local at, offsets = 0, {}
  for _, entry in ipairs(M.PLAN_SLOTS) do
    offsets[entry.name] = at
    at = at + 8
  end
  return offsets
end

function M.plan_bytes() return #M.PLAN_SLOTS * 8 end

-- The host's view of the structure, checked slot by slot against the
-- assembly's offsets -- the same guard `056` and `057` carry, and for the same
-- reason: a compiler that pads differently than the emitter assumed produces a
-- routine reading one field and writing another, with nothing to notice.
function M.declare()
  local ffi = require("ffi")
  local lines = { "typedef struct {" }
  for _, entry in ipairs(M.PLAN_SLOTS) do
    lines[#lines + 1] = "  " .. entry.declaration .. ";"
  end
  lines[#lines + 1] = "} DriverPlan;"
  ffi.cdef(table.concat(lines, "\n"))

  local offsets = M.plan_offsets()
  for _, entry in ipairs(M.PLAN_SLOTS) do
    if ffi.offsetof("DriverPlan", entry.name) ~= offsets[entry.name] then
      error("139-the-driver: slot '" .. entry.name .. "' sits at "
        .. tostring(ffi.offsetof("DriverPlan", entry.name))
        .. " for the FFI and " .. offsets[entry.name] .. " for the assembly.")
    end
  end

  ffi.cdef[[
    int64_t drive(DriverPlan *plan);
    int64_t sampler_setup(void *plan, void *stream, void *room, int64_t bytes,
                          const void *wishes);
  ]]
end
-- }}}

-- {{{ M.WISH_SLOTS -- what a sampler needs to be told, eight bytes each
--
-- A structure rather than nine arguments, for the plainer reason that there
-- are only six registers to put arguments in and this needs more than six.
--
-- THE TWO SETTINGS THAT ARE FLOATS SIT IN EIGHT-BYTE SLOTS with the top half
-- unused, matching how `057` declares them. Packing them tighter would save
-- eight bytes on a machine that has megabytes and would make every offset
-- below them depend on the packing.
M.WISH_SLOTS = {
  { name = "numbers",     declaration = "const uint32_t *numbers" },  -- the carried file
  { name = "count",       declaration = "int64_t count" },
  { name = "k_exp_one",   declaration = "float (*k_exp_one)(float)" },
  { name = "vocabulary",  declaration = "int64_t vocabulary" },
  { name = "temperature", declaration = "float temperature; float temperature_pad" },
  { name = "top_p",       declaration = "float top_p; float top_p_pad" },
  { name = "top_k",       declaration = "int64_t top_k" },
}

function M.wish_offsets()
  local at, offsets = 0, {}
  for _, entry in ipairs(M.WISH_SLOTS) do
    offsets[entry.name] = at
    at = at + 8
  end
  return offsets
end

function M.wish_bytes() return #M.WISH_SLOTS * 8 end

function M.declare_wishes()
  local ffi = require("ffi")
  local lines = { "typedef struct {" }
  for _, entry in ipairs(M.WISH_SLOTS) do
    lines[#lines + 1] = "  " .. entry.declaration .. ";"
  end
  lines[#lines + 1] = "} SamplerWishes;"
  ffi.cdef(table.concat(lines, "\n"))

  local offsets = M.wish_offsets()
  for _, entry in ipairs(M.WISH_SLOTS) do
    if ffi.offsetof("SamplerWishes", entry.name) ~= offsets[entry.name] then
      error("139-the-driver: wish '" .. entry.name .. "' sits at "
        .. tostring(ffi.offsetof("SamplerWishes", entry.name))
        .. " for the FFI and " .. offsets[entry.name] .. " for the assembly.")
    end
  end
end
-- }}}

-- {{{ M.sampler_room(vocabulary) -- what the three scratch arrays come to
--
-- The host's answer, which the assembly is held to. `057.new_plan` asks the
-- host for three arrays of one entry per token; this says how much room that
-- is when there is nobody to ask.
function M.sampler_room(vocabulary)
  local at, places = 0, {}
  local function place(name, bytes)
    places[name] = at
    at = at + bytes
    if at % 16 ~= 0 then at = at + (16 - at % 16) end
  end
  place("probabilities", vocabulary * 4)
  place("kept_chances", vocabulary * 4)
  place("kept_tokens", vocabulary * 8)
  return places, at
end
-- }}}

-- {{{ M.sampler_x86_64(sampler)
--
-- int64_t sampler_setup(SamplerPlan *plan, SamplerStream *stream,
--                       void *room, int64_t bytes, const SamplerWishes *wishes)
--
-- plan rdi, stream rsi, room rdx, bytes rcx, wishes r8.
--
-- Returns how many bytes of `room` were used, or minus the shortfall -- the
-- convention `133` uses, and it can be used here because there is only one way
-- for this to fail.
--
-- WHAT THE STREAM STARTS AT is copied from `057.new_stream` rather than
-- invented, and the one that matters is `drawn`: it starts EQUAL to
-- `per_number`, which means "the current number is used up, fetch the next
-- one" -- so the very first draw consumes the carried file's first number
-- rather than four thousand bits of a state nobody set. Starting it at zero
-- gives a machine that samples from uninitialised randomness for its first
-- four thousand draws and looks, from outside, merely unlucky.
function M.sampler_x86_64(sampler)
  local stream_at = sampler.stream_offsets()
  local plan_at = sampler.plan_offsets()
  local wish = M.wish_offsets()
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .globl sampler_setup")
  line("  .type sampler_setup, @function")
  line("sampler_setup:")
  line("  pushq %rbx")
  line("  pushq %r12")

  line("  movq %r8, %r12")                    -- the wishes
  line("  movq %rdi, %r11")                   -- the plan
  line("  movq %rsi, %r10")                   -- the stream

  -- {{{ the carried file, and a generator that has not drawn yet
  line("  movq " .. wish.numbers .. "(%r12), %rax")
  line("  movq %rax, " .. stream_at.numbers .. "(%r10)")
  line("  movq " .. wish.count .. "(%r12), %rax")
  line("  movq %rax, " .. stream_at.count .. "(%r10)")
  line("  movq $0, " .. stream_at.position .. "(%r10)")
  line("  movq $0, " .. stream_at.state .. "(%r10)")
  line("  movq $4096, " .. stream_at.per_number .. "(%r10)")
  line("  movq $4096, " .. stream_at.drawn .. "(%r10)")
  line("  movq $0, " .. stream_at.wrapped .. "(%r10)")
  -- }}}

  -- {{{ how much room the three scratch arrays want, before any is placed
  --
  -- MEASURED FIRST AND CHECKED BEFORE ANYTHING IS WRITTEN, which is `137`'s
  -- discipline and worth keeping even though nothing here would scribble past
  -- the end of the room -- these are pointers into a caller's structure rather
  -- than bytes of the run. A routine that half-fills a plan and then reports a
  -- shortfall leaves behind something that looks filled, and the next person
  -- to read it is reading three addresses that point into a room too small to
  -- hold what they claim.
  line("  movq " .. wish.vocabulary .. "(%r12), %rbx")
  line("  xorl %r9d, %r9d")                   -- how far in

  local SIZES = {
    { name = "probabilities", shift = 2 },    -- one float a token
    { name = "kept_chances",  shift = 2 },
    { name = "kept_tokens",   shift = 3 },    -- one whole number a token
  }
  for _, one in ipairs(SIZES) do
    line("  movq %rbx, %rax")
    line("  shlq $" .. one.shift .. ", %rax")
    line("  addq %rax, %r9")
    line("  addq $15, %r9")
    line("  andq $-16, %r9")
  end

  line("  cmpq %rcx, %r9")
  line("  jle ss_fits")
  line("  movq %r9, %rax")
  line("  subq %rcx, %rax")
  line("  negq %rax")
  line("  jmp ss_return")
  line("ss_fits:")
  -- }}}

  -- {{{ and then the three of them, in the order the plan holds them
  line("  xorl %r9d, %r9d")
  for _, one in ipairs(SIZES) do
    line("  movq %rdx, %rax")
    line("  addq %r9, %rax")
    line("  movq %rax, " .. plan_at[one.name] .. "(%r11)")
    line("  movq %rbx, %rax")
    line("  shlq $" .. one.shift .. ", %rax")
    line("  addq %rax, %r9")
    line("  addq $15, %r9")
    line("  andq $-16, %r9")
  end
  -- }}}

  -- {{{ the exponential, the stream, and the three settings
  line("  movq " .. wish.k_exp_one .. "(%r12), %rax")
  line("  movq %rax, " .. plan_at.k_exp_one .. "(%r11)")
  line("  movq %r10, " .. plan_at.stream .. "(%r11)")
  -- the settings are copied whole, both halves, because the top half of each
  -- float slot is padding that the sampler does not read and a half-copied
  -- eight bytes would leave whatever was in the room there.
  line("  movq " .. wish.temperature .. "(%r12), %rax")
  line("  movq %rax, " .. plan_at.temperature .. "(%r11)")
  line("  movq " .. wish.top_p .. "(%r12), %rax")
  line("  movq %rax, " .. plan_at.top_p .. "(%r11)")
  line("  movq " .. wish.top_k .. "(%r12), %rax")
  line("  movq %rax, " .. plan_at.top_k .. "(%r11)")
  line("  movq %r9, %rax")
  -- }}}

  line("ss_return:")
  line("  popq %r12")
  line("  popq %rbx")
  line("  retq")
  line("")

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.x86_64()
--
-- int64_t drive(DriverPlan *plan)
--
-- plan rdi. Returns the reason it stopped, which is also left in the plan
-- along with how far the cache reaches and how many words were said.
--
-- THE PLAN LIVES IN A REGISTER THAT SURVIVES CALLS, and so do the position
-- and the count of words said, because this routine is almost entirely calls.
-- Anything held in a scratch register across one of them is held until the
-- callee wants that register, which every callee eventually does.
function M.x86_64()
  local at = M.plan_offsets()
  local reason = M.REASONS
  local out = {}
  local function line(text) out[#out + 1] = text end
  local function slot(name) return at[name] .. "(%rbx)" end

  line("  .globl drive")
  line("  .type drive, @function")
  line("drive:")
  line("  pushq %rbx")
  line("  pushq %rbp")
  line("  pushq %r12")
  line("  pushq %r13")
  line("  pushq %r14")
  line("  pushq %r15")
  -- twenty-four bytes of room, of which eight are used to hold one token
  -- number where a routine that wants a pointer to one can reach it. The size
  -- is chosen so that the stack pointer is on a sixteen-byte boundary at every
  -- call below -- six saved registers and a return address leave it eight past
  -- one, and this is what puts it back.
  line("  subq $24, %rsp")
  line("  movq %rdi, %rbx")
  -- the two the routine reports are cleared before anything can fail, because
  -- three of the four refusals below happen before either has been worked out
  -- and a caller reading a position that was never set reads whatever the last
  -- routine on this machine left in that register.
  line("  xorl %r12d, %r12d")                 -- how far the cache reaches
  line("  xorl %r13d, %r13d")                 -- how many words said

  -- {{{ what the machine was told, turned into numbers
  line("  movq " .. slot("k_encode") .. ", %rax")
  line("  movq " .. slot("tokenizer") .. ", %rdi")
  line("  movq " .. slot("text") .. ", %rsi")
  line("  movq " .. slot("text_bytes") .. ", %rdx")
  line("  movq " .. slot("tokens") .. ", %rcx")
  line("  callq *%rax")

  -- a byte no token says comes back as minus its position minus one, and it
  -- is passed straight out rather than flattened to "failed": which byte of
  -- the carried text a machine cannot read is the whole of the diagnosis.
  line("  testq %rax, %rax")
  line("  jns dv_encoded")
  line("  movq %rax, " .. slot("detail"))
  line("  movq $" .. reason.unsayable .. ", %rax")
  line("  jmp dv_stop")
  line("dv_encoded:")
  line("  movq %rax, %r12")                   -- how many tokens: the position
  line("  testq %r12, %r12")
  line("  jnz dv_something")
  line("  movq $" .. reason.nothing .. ", %rax")
  line("  jmp dv_stop")
  line("dv_something:")
  line("  cmpq " .. slot("context") .. ", %r12")
  line("  jle dv_fits")
  line("  movq %r12, " .. slot("detail"))
  line("  movq $" .. reason.too_long .. ", %rax")
  line("  jmp dv_stop")
  line("dv_fits:")
  -- }}}

  -- {{{ laid into the cache, one position at a time
  --
  -- Every position of what the machine was told is run through the engine
  -- before it says anything, which is what fills the cache rows the attention
  -- will read. The scores left behind by the LAST of them are the ones the
  -- first word is drawn from -- so this loop is not preparation for the
  -- thinking, it is the first thought.
  line("  xorl %r13d, %r13d")
  line("dv_replay:")
  line("  cmpq %r12, %r13")
  line("  jge dv_replay_done")
  line("  movq " .. slot("tokens") .. ", %rax")
  line("  movslq (%rax,%r13,4), %rsi")
  line("  movq " .. slot("conductor") .. ", %rdi")
  line("  movq %r13, %rdx")
  line("  movq " .. slot("scores") .. ", %rcx")
  line("  movq " .. slot("k_forward") .. ", %rax")
  line("  callq *%rax")
  line("  incq %r13")
  line("  jmp dv_replay")
  line("dv_replay_done:")
  -- }}}

  -- {{{ and then it speaks
  line("  xorl %r13d, %r13d")                 -- how many words said
  line("dv_loop:")

  -- length first, before drawing. Checking it after would draw a word, throw
  -- it away, and advance the carried randomness by one number that nothing
  -- said -- which the readable loop does not do, and a stream out of step is
  -- a different conversation from the next word onwards.
  line("  cmpq " .. slot("max_tokens") .. ", %r13")
  line("  jl dv_draw")
  line("  movq $" .. reason.length .. ", %rax")
  line("  jmp dv_stop")

  line("dv_draw:")
  line("  movq " .. slot("sampler") .. ", %rdi")
  line("  movq " .. slot("scores") .. ", %rsi")
  line("  movq " .. slot("vocabulary") .. ", %rdx")
  line("  movq " .. slot("chance") .. ", %rcx")
  line("  movq " .. slot("k_choose") .. ", %rax")
  line("  callq *%rax")
  line("  movq %rax, %r14")                   -- the word

  -- the finish token is swallowed rather than said, which is what makes it a
  -- mark rather than a word
  line("  cmpq " .. slot("finish_token") .. ", %r14")
  line("  jne dv_keep")
  line("  movq $" .. reason.finished .. ", %rax")
  line("  jmp dv_stop")

  line("dv_keep:")
  line("  movq " .. slot("spoken") .. ", %rax")
  line("  movl %r14d, (%rax,%r13,4)")
  line("  incq %r13")

  -- {{{ said the moment it is drawn, not at the end of the turn
  --
  -- A machine that gathers a whole answer and then says it is a machine that
  -- says nothing at all when the thing that stops it is a fault. Every word
  -- that made it out is a word that was really drawn, and the last one before
  -- a silence is where to look.
  line("  movl %r14d, (%rsp)")
  line("  movq " .. slot("tokenizer") .. ", %rdi")
  line("  movq %rsp, %rsi")
  line("  movq $1, %rdx")
  line("  movq " .. slot("say_room") .. ", %rcx")
  line("  movq " .. slot("k_decode") .. ", %rax")
  line("  callq *%rax")
  line("  testq %rax, %rax")
  line("  jns dv_decoded")
  -- a drawn token the vocabulary cannot say back means the weights and the
  -- word-list disagree about how many words exist. It is the same broken
  -- image `061` refuses in words, met from the other side.
  line("  movq %r14, " .. slot("detail"))
  line("  movq $" .. reason.unknown .. ", %rax")
  line("  jmp dv_stop")
  line("dv_decoded:")
  line("  movq " .. slot("say_room") .. ", %rdi")
  line("  movq %rax, %rsi")
  line("  movq " .. slot("say_context") .. ", %rdx")
  line("  movq " .. slot("k_say") .. ", %rax")
  line("  callq *%rax")
  -- }}}

  -- the room, checked after the word is kept and before it is thought over.
  -- A word drawn from the last position the cache holds is a real word and is
  -- kept; there is simply nowhere to put what thinking about it would produce.
  line("  cmpq " .. slot("context") .. ", %r12")
  line("  jl dv_carry_on")
  line("  movq $" .. reason.room_ran_out .. ", %rax")
  line("  jmp dv_stop")

  line("dv_carry_on:")
  line("  movq " .. slot("conductor") .. ", %rdi")
  line("  movq %r14, %rsi")
  line("  movq %r12, %rdx")
  line("  movq " .. slot("scores") .. ", %rcx")
  line("  movq " .. slot("k_forward") .. ", %rax")
  line("  callq *%rax")
  line("  incq %r12")
  line("  jmp dv_loop")
  -- }}}

  -- {{{ what came of it, written where a caller with no return value can read
  line("dv_stop:")
  line("  movq %rax, " .. slot("reason"))
  line("  movq %r12, " .. slot("position"))
  line("  movq %r13, " .. slot("said"))
  line("  addq $24, %rsp")
  line("  popq %r15")
  line("  popq %r14")
  line("  popq %r13")
  line("  popq %r12")
  line("  popq %rbp")
  line("  popq %rbx")
  line("  retq")
  line("")
  -- }}}

  return table.concat(out, "\n")
end
-- }}}

return M
