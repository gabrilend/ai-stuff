-- 056-emit-conductor.lua
--
-- The conducting, in assembly. The last readable piece of a forward pass
-- (049) moves to the processor's own instructions: the layer loop, the head
-- loop, the pointer arithmetic that hands each kernel exactly the memory it
-- is owed. After this, a whole thought is assembly end to end.
--
-- For a general: the arithmetic was moved first and proven bit for bit; this
-- moves the part that decides what happens in which order. It contains no
-- floating point at all -- every number it touches is a count or an address --
-- which is why it was left for last and why a disagreement after this change
-- can only be in the conducting.
--
-- THE PLAN. The conductor takes one argument: a table describing everything
-- -- the model's counts, where every tensor sits, where the scratch vectors
-- live, and the address of every kernel it may call. It reaches nothing by
-- name; on bare metal there are no names, and a conductor that asks only
-- "what is at this offset of the plan" runs identically hosted and bare.
--
-- The plan's layout is declared once, below, as data. The assembly offsets
-- are computed from it, and the FFI structure the host builds is checked
-- against it slot by slot at build time -- the same rule as the blob header
-- (024): one description, and nothing counted by hand.
--
-- WHY KERNELS ARRIVE AS ADDRESSES. A call to an exported symbol is a note
-- for a linker. Hosted, a linker exists and would oblige; on the metal there
-- is none, and the engine will fill this table by measuring from where it
-- stands. Taking addresses through the plan keeps the conductor honest about
-- the machine it is really for.

local ffi = require("ffi")

local M = {}

-- {{{ M.SLOTS -- the plan, one slot per row, eight bytes each
--
-- Order is layout. `declaration` is how the host's FFI sees the slot; the
-- assembly only ever knows the offset. Floats sit in the low four bytes of
-- their slot with explicit padding, so every offset stays a multiple of
-- eight and the arithmetic below never meets an odd one.
M.SLOTS = {
  -- the counts, all sixty-four bit so the offsets stay uniform
  { name = "layers",          declaration = "int64_t layers" },
  { name = "hidden",          declaration = "int64_t hidden" },
  { name = "heads",           declaration = "int64_t heads" },
  { name = "head_width",      declaration = "int64_t head_width" },
  { name = "kv_heads",        declaration = "int64_t kv_heads" },
  { name = "heads_per_kv",    declaration = "int64_t heads_per_kv" },
  { name = "feedforward",     declaration = "int64_t feedforward" },
  { name = "vocabulary",      declaration = "int64_t vocabulary" },
  { name = "context",         declaration = "int64_t context" },
  { name = "kv_width",        declaration = "int64_t kv_width" },
  { name = "query_width",     declaration = "int64_t query_width" },

  -- the two floating constants, computed by the caller because the
  -- conductor does no floating point of its own
  { name = "scale",           declaration = "float scale; float scale_pad" },
  { name = "epsilon",         declaration = "float epsilon; float epsilon_pad" },

  -- the kernels, as addresses
  { name = "multiply",        declaration = "void (*multiply)(float *, const float *, const float *, int, int)" },
  { name = "k_rms_normalise", declaration = "void (*k_rms_normalise)(float *, const float *, const float *, int, float)" },
  { name = "k_rotate",        declaration = "void (*k_rotate)(float *, const float *, int, int)" },
  { name = "k_attention_scores", declaration = "void (*k_attention_scores)(float *, const float *, const float *, int, int, int, float)" },
  { name = "k_softmax",       declaration = "void (*k_softmax)(float *, int)" },
  { name = "k_attention_mix", declaration = "void (*k_attention_mix)(float *, const float *, const float *, int, int, int)" },
  { name = "k_swiglu",        declaration = "void (*k_swiglu)(float *, const float *, int)" },
  { name = "k_add_into",      declaration = "void (*k_add_into)(float *, const float *, int)" },

  -- the model's fixed tensors
  { name = "token_embedding", declaration = "const float *token_embedding" },
  { name = "rotation",        declaration = "const float *rotation" },
  { name = "output_norm",     declaration = "const float *output_norm" },
  { name = "output",          declaration = "const float *output" },

  -- the cache of everything thought so far
  { name = "cache_keys",      declaration = "float *cache_keys" },
  { name = "cache_values",    declaration = "float *cache_values" },

  -- the vectors one step holds while it happens
  { name = "state",           declaration = "float *state" },
  { name = "normalised",      declaration = "float *normalised" },
  { name = "query",           declaration = "float *query" },
  { name = "attended",        declaration = "float *attended" },
  { name = "projected",       declaration = "float *projected" },
  { name = "gate",            declaration = "float *gate" },
  { name = "up",              declaration = "float *up" },
  { name = "scores",          declaration = "float *scores" },

  -- per layer, nine tensors in a fixed order:
  -- attn_norm, wq, wk, wv, wo, ffn_norm, w_gate, w_up, w_down
  { name = "layer_table",     declaration = "const float **layer_table" },
}

-- where each of the nine sits within one layer's row of the table, so the
-- assembly and the host fill and read the same order.
M.LAYER_ORDER = {
  "attn_norm", "wq", "wk", "wv", "wo", "ffn_norm", "w_gate", "w_up", "w_down",
}
-- }}}

-- {{{ M.offsets() -- slot name to byte offset, computed
function M.offsets()
  local at, offsets = 0, {}
  for _, slot in ipairs(M.SLOTS) do
    offsets[slot.name] = at
    at = at + 8
  end
  return offsets
end
-- }}}

-- {{{ M.declare() -- the plan as the host's FFI sees it, checked slot by slot
function M.declare()
  local lines = { "typedef struct {" }
  for _, slot in ipairs(M.SLOTS) do
    lines[#lines + 1] = "  " .. slot.declaration .. ";"
  end
  lines[#lines + 1] = "} ForwardPlan;"
  ffi.cdef(table.concat(lines, "\n"))

  ffi.cdef[[
    void forward_conduct(const ForwardPlan *plan, int64_t token,
                         int64_t position, float *logits);
  ]]

  -- the check that keeps the two descriptions one: every slot the FFI knows
  -- must sit exactly where the assembly will look.
  local offsets = M.offsets()
  for _, slot in ipairs(M.SLOTS) do
    local ffi_offset = ffi.offsetof("ForwardPlan", slot.name)
    if ffi_offset ~= offsets[slot.name] then
      error("056-emit-conductor: slot '" .. slot.name .. "' sits at "
        .. tostring(ffi_offset) .. " for the FFI and " .. offsets[slot.name]
        .. " for the assembly. The two must never disagree.")
    end
  end
end
-- }}}

-- {{{ M.new_plan(kernels, model, cache, wide)
-- Builds a filled plan for a loaded model, with fresh scratch vectors. The
-- returned table carries the plan AND everything the plan points into,
-- because a plan whose buffers were collected points at reused memory.
function M.new_plan(kernels, model, cache, wide)
  local shape = model.shape
  local plan = ffi.new("ForwardPlan")

  plan.layers = shape.layers
  plan.hidden = shape.hidden
  plan.heads = shape.heads
  plan.head_width = shape.head_width
  plan.kv_heads = shape.kv_heads
  plan.heads_per_kv = shape.heads / shape.kv_heads
  plan.feedforward = shape.feedforward
  plan.vocabulary = shape.vocabulary
  plan.context = shape.context
  plan.kv_width = shape.kv_heads * shape.head_width
  plan.query_width = shape.heads * shape.head_width

  -- the scale is rounded through single precision by the caller of the
  -- arithmetic, not inside it -- same rule as the reference (035).
  local rounder = ffi.new("float[1]")
  rounder[0] = 1 / math.sqrt(shape.head_width)
  plan.scale = rounder[0]
  plan.epsilon = 1e-5

  plan.multiply = wide and kernels.matrix_vector_wide or kernels.matrix_vector_plain
  plan.k_rms_normalise = kernels.rms_normalise
  plan.k_rotate = kernels.rotate
  plan.k_attention_scores = kernels.attention_scores
  plan.k_softmax = kernels.softmax
  plan.k_attention_mix = kernels.attention_mix
  plan.k_swiglu = kernels.swiglu
  plan.k_add_into = kernels.add_into

  plan.token_embedding = model.tensors.token_embedding
  plan.rotation = model.tensors.rotation
  plan.output_norm = model.tensors.output_norm
  plan.output = model.tensors.output

  plan.cache_keys = cache.keys
  plan.cache_values = cache.values

  local scratch = {
    state = ffi.new("float[?]", shape.hidden),
    normalised = ffi.new("float[?]", shape.hidden),
    query = ffi.new("float[?]", shape.heads * shape.head_width),
    attended = ffi.new("float[?]", shape.heads * shape.head_width),
    projected = ffi.new("float[?]", shape.hidden),
    gate = ffi.new("float[?]", shape.feedforward),
    up = ffi.new("float[?]", shape.feedforward),
    scores = ffi.new("float[?]", shape.context),
  }
  for name, buffer in pairs(scratch) do plan[name] = buffer end

  local layer_table = ffi.new("const float *[?]", shape.layers * #M.LAYER_ORDER)
  for layer = 0, shape.layers - 1 do
    for which, tensor in ipairs(M.LAYER_ORDER) do
      layer_table[layer * #M.LAYER_ORDER + (which - 1)] =
        model.tensors["layer" .. layer .. "." .. tensor]
    end
  end
  plan.layer_table = layer_table

  -- what must stay alive as long as the plan does: the buffers, the layer
  -- table, and the model and kernels the pointers reach into.
  return { plan = plan, keep = { scratch, layer_table, model, cache, kernels } }
end
-- }}}

-- {{{ M.x86_64()
--
-- void forward_conduct(const ForwardPlan *plan, int64_t token,
--                      int64_t position, float *logits)
--
-- plan rdi, token rsi, position rdx, logits rcx.
--
-- Registers that survive kernel calls hold what every call site needs: r15
-- the plan, r14 the position, r13 the row of turns, r12 the cursor into the
-- layer table, rbx the layer, rbp the cache slot of this position. Loop
-- counters that outlive a call live on the stack.
function M.x86_64()
  local at = M.offsets()
  local out = {}
  local function line(text) out[#out + 1] = text end

  -- reading a slot: counts load their low thirty-two bits when a kernel
  -- takes an int, all sixty-four when they multiply addresses.
  local function slot(name) return at[name] .. "(%r15)" end
  local layer_stride = #M.LAYER_ORDER * 8

  line("  .globl forward_conduct")
  line("  .type forward_conduct, @function")
  line("forward_conduct:")
  line("  pushq %rbp")
  line("  pushq %rbx")
  line("  pushq %r12")
  line("  pushq %r13")
  line("  pushq %r14")
  line("  pushq %r15")
  -- five slots of loop state, and the arithmetic that keeps calls aligned:
  -- six pushes and this leave the pointer where the convention wants it.
  line("  subq $40, %rsp")
  line("  movq %rdi, %r15")                -- the plan
  line("  movq %rdx, %r14")                -- the position
  line("  movq %rcx, 0(%rsp)")             -- the scores go here at the end

  -- {{{ state <- what this token means, before anything has been done with it
  line("  movq " .. slot("hidden") .. ", %rax")
  line("  imulq %rax, %rsi")               -- token * hidden
  line("  movq " .. slot("token_embedding") .. ", %r8")
  line("  leaq (%r8,%rsi,4), %r8")         -- that token's row
  line("  movq " .. slot("state") .. ", %r9")
  line("  xorl %r10d, %r10d")
  line("copy_embedding:")
  line("  movl (%r8,%r10,4), %eax")
  line("  movl %eax, (%r9,%r10,4)")
  line("  incq %r10")
  line("  cmpq " .. slot("hidden") .. ", %r10")
  line("  jl copy_embedding")
  -- }}}

  -- the row of turns for this position, computed once rather than per head
  line("  movq " .. slot("head_width") .. ", %rax")
  line("  imulq %r14, %rax")
  line("  movq " .. slot("rotation") .. ", %r13")
  line("  leaq (%r13,%rax,4), %r13")

  line("  movq " .. slot("layer_table") .. ", %r12")
  line("  xorl %ebx, %ebx")                -- layer = 0
  line("layer_loop:")
  line("  cmpq " .. slot("layers") .. ", %rbx")
  line("  jge layers_done")

  -- {{{ a small vocabulary of call-site helpers
  --
  -- Each kernel call names its arguments and nothing else; the registers are
  -- the calling convention's, loaded fresh every time because nothing
  -- volatile survives a call.
  local function call(kernel)
    line("  callq *" .. slot(kernel))
  end

  -- one argument loader per shape of argument, dispatched by prefix:
  --   ptr:NAME     the pointer in that slot
  --   ptrx:NAME    the pointer in that slot, plus rbp slots of four bytes
  --   layer:N      the Nth tensor of this layer's row
  --   count:NAME   the low thirty-two bits of that slot
  --   reg:...      already-prepared value, taken as written
  local integer_registers = { "%rdi", "%rsi", "%rdx", "%rcx", "%r8", "%r9" }
  local function arguments(list)
    local used = 0
    for _, entry in ipairs(list) do
      used = used + 1
      local register = integer_registers[used]
      local half = ({ ["%rdi"] = "%edi", ["%rsi"] = "%esi", ["%rdx"] = "%edx",
                      ["%rcx"] = "%ecx", ["%r8"] = "%r8d", ["%r9"] = "%r9d" })[register]
      local kind, name = entry:match("^(%w+):(.+)$")
      if kind == "ptr" then
        line("  movq " .. slot(name) .. ", " .. register)
      elseif kind == "ptrx" then
        line("  movq " .. slot(name) .. ", " .. register)
        line("  leaq (" .. register .. ",%rbp,4), " .. register)
      elseif kind == "layer" then
        line("  movq " .. (tonumber(name) * 8) .. "(%r12), " .. register)
      elseif kind == "count" then
        line("  movl " .. slot(name) .. ", " .. half)
      elseif kind == "reg" then
        if name ~= register then
          line("  movq " .. name .. ", " .. register)
        end
      else
        error("056: no argument kind called '" .. tostring(kind) .. "'")
      end
    end
  end

  local function load_scale(name)
    line("  movss " .. slot(name) .. ", %xmm0")
  end
  -- }}}

  -- {{{ attention
  load_scale("epsilon")
  arguments({ "ptr:normalised", "ptr:state", "layer:0", "count:hidden" })
  call("k_rms_normalise")

  -- this position's slot in the cache: (layer * context + position) * kv_width
  line("  movq %rbx, %rbp")
  line("  imulq " .. slot("context") .. ", %rbp")
  line("  addq %r14, %rbp")
  line("  imulq " .. slot("kv_width") .. ", %rbp")

  arguments({ "ptr:query", "layer:1", "ptr:normalised",
              "count:query_width", "count:hidden" })
  call("multiply")
  arguments({ "ptrx:cache_keys", "layer:2", "ptr:normalised",
              "count:kv_width", "count:hidden" })
  call("multiply")
  arguments({ "ptrx:cache_values", "layer:3", "ptr:normalised",
              "count:kv_width", "count:hidden" })
  call("multiply")

  arguments({ "ptr:query", "reg:%r13", "count:heads", "count:head_width" })
  call("k_rotate")
  arguments({ "ptrx:cache_keys", "reg:%r13", "count:kv_heads", "count:head_width" })
  call("k_rotate")

  -- {{{ the heads, each asking its own question of the past
  --
  -- Query heads outnumber key heads, so the walk is two counters advancing
  -- together: the head, and how far through its key head's group it is.
  -- When the group completes, the key head advances -- no division anywhere.
  --
  -- The stack holds what must outlive the calls inside the loop:
  --   8(%rsp)   this layer's base slot in the cache
  --   16(%rsp)  the head
  --   24(%rsp)  the key head
  --   32(%rsp)  where in its group the head is
  line("  movq %rbx, %rax")
  line("  imulq " .. slot("context") .. ", %rax")
  line("  imulq " .. slot("kv_width") .. ", %rax")
  line("  movq %rax, 8(%rsp)")
  line("  movq $0, 16(%rsp)")
  line("  movq $0, 24(%rsp)")
  line("  movq $0, 32(%rsp)")

  line("head_loop:")

  -- attention_scores(scores, query + head * head_width,
  --                  keys + (layer_base + kv_head * head_width) * 4,
  --                  position + 1, head_width, kv_width, scale)
  load_scale("scale")
  line("  movq " .. slot("query") .. ", %rsi")
  line("  movq 16(%rsp), %rax")
  line("  imulq " .. slot("head_width") .. ", %rax")
  line("  leaq (%rsi,%rax,4), %rsi")
  line("  movq 24(%rsp), %rax")
  line("  imulq " .. slot("head_width") .. ", %rax")
  line("  addq 8(%rsp), %rax")
  line("  movq " .. slot("cache_keys") .. ", %rdx")
  line("  leaq (%rdx,%rax,4), %rdx")
  line("  movq " .. slot("scores") .. ", %rdi")
  line("  leal 1(%r14d), %ecx")
  line("  movl " .. slot("head_width") .. ", %r8d")
  line("  movl " .. slot("kv_width") .. ", %r9d")
  call("k_attention_scores")

  line("  movq " .. slot("scores") .. ", %rdi")
  line("  leal 1(%r14d), %esi")
  call("k_softmax")

  -- attention_mix(attended + head * head_width, scores,
  --               values + the same cache base, position + 1, ...)
  line("  movq " .. slot("attended") .. ", %rdi")
  line("  movq 16(%rsp), %rax")
  line("  imulq " .. slot("head_width") .. ", %rax")
  line("  leaq (%rdi,%rax,4), %rdi")
  line("  movq 24(%rsp), %rax")
  line("  imulq " .. slot("head_width") .. ", %rax")
  line("  addq 8(%rsp), %rax")
  line("  movq " .. slot("cache_values") .. ", %rdx")
  line("  leaq (%rdx,%rax,4), %rdx")
  line("  movq " .. slot("scores") .. ", %rsi")
  line("  leal 1(%r14d), %ecx")
  line("  movl " .. slot("head_width") .. ", %r8d")
  line("  movl " .. slot("kv_width") .. ", %r9d")
  call("k_attention_mix")

  -- head advances always; the key head advances when the group completes
  line("  incq 16(%rsp)")
  line("  movq 32(%rsp), %rax")
  line("  incq %rax")
  line("  cmpq " .. slot("heads_per_kv") .. ", %rax")
  line("  jl same_group")
  line("  incq 24(%rsp)")
  line("  xorl %eax, %eax")
  line("same_group:")
  line("  movq %rax, 32(%rsp)")
  line("  movq 16(%rsp), %rax")
  line("  cmpq " .. slot("heads") .. ", %rax")
  line("  jl head_loop")
  -- }}}

  arguments({ "ptr:projected", "layer:4", "ptr:attended",
              "count:hidden", "count:query_width" })
  call("multiply")
  arguments({ "ptr:state", "ptr:projected", "count:hidden" })
  call("k_add_into")
  -- }}}

  -- {{{ feedforward
  load_scale("epsilon")
  arguments({ "ptr:normalised", "ptr:state", "layer:5", "count:hidden" })
  call("k_rms_normalise")
  arguments({ "ptr:gate", "layer:6", "ptr:normalised",
              "count:feedforward", "count:hidden" })
  call("multiply")
  arguments({ "ptr:up", "layer:7", "ptr:normalised",
              "count:feedforward", "count:hidden" })
  call("multiply")
  arguments({ "ptr:gate", "ptr:up", "count:feedforward" })
  call("k_swiglu")
  arguments({ "ptr:projected", "layer:8", "ptr:gate",
              "count:hidden", "count:feedforward" })
  call("multiply")
  arguments({ "ptr:state", "ptr:projected", "count:hidden" })
  call("k_add_into")
  -- }}}

  line("  addq $" .. layer_stride .. ", %r12")
  line("  incq %rbx")
  line("  jmp layer_loop")
  line("layers_done:")

  -- {{{ the projection to a score per token
  load_scale("epsilon")
  arguments({ "ptr:normalised", "ptr:state", "ptr:output_norm", "count:hidden" })
  call("k_rms_normalise")
  line("  movq 0(%rsp), %rdi")             -- the logits the caller wants
  line("  movq " .. slot("output") .. ", %rsi")
  line("  movq " .. slot("normalised") .. ", %rdx")
  line("  movl " .. slot("vocabulary") .. ", %ecx")
  line("  movl " .. slot("hidden") .. ", %r8d")
  call("multiply")
  -- }}}

  line("  addq $40, %rsp")
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
