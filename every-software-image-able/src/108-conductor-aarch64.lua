-- 108-conductor-aarch64.lua
--
-- The conducting, in the second tongue. The layer loop, the head loop, and
-- the pointer arithmetic that hands each kernel exactly the memory it is
-- owed -- written again in ARM's instructions. Issue 401.
--
-- For a general: the second architecture already has all ten pieces of
-- arithmetic, and every one of them was proved to produce the same bits as
-- the first architecture. What it did not have was anything to run them in
-- order. This is that. A piece can be right by itself and be handed the
-- wrong thing by the piece before it, and no amount of testing the pieces
-- alone would ever notice.
--
-- WHY IT IS A SEPARATE FILE FROM 056. Same reason 099 is separate from 043:
-- that file holds the first tongue's conducting and the description of the
-- plan, and a reader of either should not have to wade through both. The
-- plan itself is NOT duplicated here -- it is asked for, so there stays
-- exactly one description of where every slot sits.
--
-- WHAT IS A TRANSLATION AND WHAT IS NOT. Nearly all of it is a translation,
-- and it is the easy half by construction: there is no floating point in
-- here at all. Every number this file touches is a count or an address, so
-- a disagreement after this change cannot be an arithmetic disagreement.
-- That was the whole reason the first architecture moved its conducting
-- last, and the same reasoning is why this one is worth writing separately
-- rather than being assumed.
--
-- THE ONE PLACE THE ARCHITECTURES GENUINELY DIFFER. x86-64 has six
-- callee-saved registers and had to keep four pieces of loop state on the
-- stack. This architecture has ten, so all but one of them live in
-- registers. That is a difference of convenience, not of specification --
-- the order of operations is identical, which is the only thing the answer
-- depends on. The one that stays on the stack does so to keep the shape
-- recognisable beside the first tongue rather than because it must.

local M = {}

-- {{{ M.source(plan, options)
--
-- void forward_conduct(const ForwardPlan *plan, int64_t token,
--                      int64_t position, float *logits)
--
-- plan x0, token x1, position x2, logits x3.
--
-- `plan` is the module that describes the plan's layout (056). It is passed
-- in rather than read from a path, so this file has no opinion about where
-- the project lives and no second copy of the layout.
--
-- options.name renames the routine and every label inside it, so more than
-- one conducting can sit in one program.
--
-- options.miswire EMITS A DELIBERATELY WRONG ONE. It hands the feedforward's
-- two projections to each other's kernels: the gate is computed from the
-- tensor the up projection wants and the other way round. Both tensors are
-- exactly the same shape, so nothing reads outside anything and nothing
-- faults -- the arithmetic is all still correct, every kernel still does
-- precisely what it is asked, and the answer is wrong.
--
-- That is the entire point. It is this project's characteristic defect
-- wearing its plainest clothes: a piece that is right alone being handed the
-- wrong thing by the piece before it. A test that proves the pieces agree
-- and cannot show itself failing has not proved they are conducted
-- correctly, only that nothing crashed -- so the wrong one rides along in
-- the same payload and is required to disagree.
--
-- Registers that survive kernel calls hold what every call site needs:
--
--   x19  the plan
--   x20  the position
--   x21  the row of turns for this position
--   x22  the cursor into the layer table
--   x23  the layer
--   x24  this position's slot in the cache, in numbers
--   x25  where the caller wants the scores written
--   x26  this layer's base slot in the cache, in numbers
--   x27  the head
--   x28  the key head
--
-- and [sp, #96] holds how far through its group the head is, which is the
-- eleventh thing and the one there is no register left for.
--
-- x9 and x10 are the scratch pair. Nothing that must survive a call is ever
-- put in either, because the convention says a called kernel may use them
-- and several do.
function M.source(plan, options)
  options = options or {}
  local name = options.name or "forward_conduct"
  local at = plan.offsets()
  local layer_stride = #plan.LAYER_ORDER * 8
  local out = {}
  local function line(text) out[#out + 1] = text end

  -- every label carries the routine's name, so two conductings can sit in
  -- one program without one's layer loop being the other's
  local function label(what) return name .. "_" .. what end

  -- reading a slot of the plan. A count is read as a whole word when it is
  -- multiplied into an address and as its low half when a kernel takes an
  -- int, which is the same rule the first tongue follows -- and correct only
  -- because both machines store the low half first.
  local function slot(name)
    if at[name] == nil then
      error("108-conductor-aarch64: the plan has no slot called '"
            .. tostring(name) .. "'. The layout is 056's to describe, and "
            .. "this file must not invent one.")
    end
    return "[x19, #" .. at[name] .. "]"
  end

  line("  .globl " .. name)
  line("  .type " .. name .. ", @function")
  line(name .. ":")
  -- Ten callee-saved registers, the frame pair, and sixteen bytes of loop
  -- state. A hundred and twelve is already a multiple of sixteen, which the
  -- convention requires of the stack pointer at every call.
  line("  stp x29, x30, [sp, #-112]!")
  line("  mov x29, sp")
  line("  stp x19, x20, [sp, #16]")
  line("  stp x21, x22, [sp, #32]")
  line("  stp x23, x24, [sp, #48]")
  line("  stp x25, x26, [sp, #64]")
  line("  stp x27, x28, [sp, #80]")

  line("  mov x19, x0")                     -- the plan
  line("  mov x25, x3")                     -- the scores go here at the end
  line("  mov x20, x2")                     -- the position
  -- the token is still in x1 and is consumed immediately below, before
  -- anything else is allowed to want that register.

  -- {{{ state <- what this token means, before anything has been done with it
  line("  ldr x9, " .. slot("hidden"))
  line("  mul x1, x1, x9")                  -- token * hidden
  line("  ldr x10, " .. slot("token_embedding"))
  line("  add x10, x10, x1, lsl #2")        -- that token's row
  line("  ldr x11, " .. slot("state"))
  line("  mov x12, xzr")
  line(label("copy_embedding") .. ":")
  line("  ldr w13, [x10, x12, lsl #2]")
  line("  str w13, [x11, x12, lsl #2]")
  line("  add x12, x12, #1")
  line("  cmp x12, x9")
  line("  b.lt " .. label("copy_embedding"))
  -- }}}

  -- the row of turns for this position, computed once rather than per head
  line("  ldr x9, " .. slot("head_width"))
  line("  mul x9, x9, x20")
  line("  ldr x21, " .. slot("rotation"))
  line("  add x21, x21, x9, lsl #2")

  line("  ldr x22, " .. slot("layer_table"))
  line("  mov x23, xzr")                    -- layer = 0
  line(label("layer_loop") .. ":")
  line("  ldr x9, " .. slot("layers"))
  line("  cmp x23, x9")
  line("  b.ge " .. label("layers_done"))

  -- {{{ a small vocabulary of call-site helpers
  --
  -- Each kernel call names its arguments and nothing else. The registers are
  -- the convention's, loaded fresh every time, because nothing volatile
  -- survives a call and pretending otherwise is how a port acquires a defect
  -- that only shows up in one kernel's tail.
  local integer_registers = { "x0", "x1", "x2", "x3", "x4", "x5", "x6", "x7" }
  local half_registers    = { "w0", "w1", "w2", "w3", "w4", "w5", "w6", "w7" }

  -- one argument loader per shape of argument, dispatched by prefix -- the
  -- same five kinds the first tongue has, so the two call sites read alike:
  --   ptr:NAME     the pointer in that slot
  --   ptrx:NAME    the pointer in that slot, plus x24 numbers of four bytes
  --   layer:N      the Nth tensor of this layer's row
  --   count:NAME   the low thirty-two bits of that slot
  --   reg:...      already-prepared value, taken as written
  local function arguments(list)
    local used = 0
    for _, entry in ipairs(list) do
      used = used + 1
      local register, half = integer_registers[used], half_registers[used]
      if register == nil then
        error("108-conductor-aarch64: a kernel is being handed more than "
              .. "eight arguments, and the ninth would go on the stack. "
              .. "No kernel in this engine takes that many, so this is a "
              .. "mistake at the call site rather than a limit to raise.")
      end
      local kind, name = entry:match("^(%w+):(.+)$")
      if kind == "ptr" then
        line("  ldr " .. register .. ", " .. slot(name))
      elseif kind == "ptrx" then
        line("  ldr " .. register .. ", " .. slot(name))
        line("  add " .. register .. ", " .. register .. ", x24, lsl #2")
      elseif kind == "layer" then
        line("  ldr " .. register .. ", [x22, #" .. (tonumber(name) * 8) .. "]")
      elseif kind == "count" then
        line("  ldr " .. half .. ", " .. slot(name))
      elseif kind == "reg" then
        if name ~= register then
          line("  mov " .. register .. ", " .. name)
        end
      else
        error("108: no argument kind called '" .. tostring(kind) .. "'")
      end
    end
  end

  -- The kernel arrives as an address out of the plan, never as a name. On
  -- bare metal there are no names, and a call to an exported one is a note
  -- for a linker that nothing here reads -- which this project has now paid
  -- for three separate times.
  local function call(kernel)
    line("  ldr x9, " .. slot(kernel))
    line("  blr x9")
  end

  -- The two floating constants are read straight out of the plan into the
  -- register the convention passes them in. This file computes neither.
  local function load_scale(name)
    line("  ldr s0, " .. slot(name))
  end
  -- }}}

  -- {{{ attention
  load_scale("epsilon")
  arguments({ "ptr:normalised", "ptr:state", "layer:0", "count:hidden" })
  call("k_rms_normalise")

  -- this position's slot in the cache: (layer * context + position) * kv_width
  line("  ldr x9, " .. slot("context"))
  line("  mul x24, x23, x9")
  line("  add x24, x24, x20")
  line("  ldr x9, " .. slot("kv_width"))
  line("  mul x24, x24, x9")

  arguments({ "ptr:query", "layer:1", "ptr:normalised",
              "count:query_width", "count:hidden" })
  call("multiply")
  arguments({ "ptrx:cache_keys", "layer:2", "ptr:normalised",
              "count:kv_width", "count:hidden" })
  call("multiply")
  arguments({ "ptrx:cache_values", "layer:3", "ptr:normalised",
              "count:kv_width", "count:hidden" })
  call("multiply")

  arguments({ "ptr:query", "reg:x21", "count:heads", "count:head_width" })
  call("k_rotate")
  arguments({ "ptrx:cache_keys", "reg:x21", "count:kv_heads", "count:head_width" })
  call("k_rotate")

  -- {{{ the heads, each asking its own question of the past
  --
  -- Query heads outnumber key heads, so the walk is two counters advancing
  -- together: the head, and how far through its key head's group it is.
  -- When the group completes, the key head advances -- no division anywhere,
  -- which matters because a division here would be the one piece of
  -- arithmetic in a routine that is supposed to have none.
  line("  ldr x9, " .. slot("context"))
  line("  mul x26, x23, x9")
  line("  ldr x9, " .. slot("kv_width"))
  line("  mul x26, x26, x9")
  line("  mov x27, xzr")                    -- head
  line("  mov x28, xzr")                    -- key head
  line("  str xzr, [sp, #96]")              -- where in its group the head is

  line(label("head_loop") .. ":")

  -- attention_scores(scores, query + head * head_width,
  --                  keys + (layer_base + kv_head * head_width),
  --                  position + 1, head_width, kv_width, scale)
  load_scale("scale")
  line("  ldr x1, " .. slot("query"))
  line("  ldr x9, " .. slot("head_width"))
  line("  mul x10, x27, x9")
  line("  add x1, x1, x10, lsl #2")
  line("  mul x10, x28, x9")
  line("  add x10, x10, x26")
  line("  ldr x2, " .. slot("cache_keys"))
  line("  add x2, x2, x10, lsl #2")
  line("  ldr x0, " .. slot("scores"))
  line("  add w3, w20, #1")
  line("  ldr w4, " .. slot("head_width"))
  line("  ldr w5, " .. slot("kv_width"))
  call("k_attention_scores")

  line("  ldr x0, " .. slot("scores"))
  line("  add w1, w20, #1")
  call("k_softmax")

  -- attention_mix(attended + head * head_width, scores,
  --               values + the same cache base, position + 1, ...)
  line("  ldr x0, " .. slot("attended"))
  line("  ldr x9, " .. slot("head_width"))
  line("  mul x10, x27, x9")
  line("  add x0, x0, x10, lsl #2")
  line("  mul x10, x28, x9")
  line("  add x10, x10, x26")
  line("  ldr x2, " .. slot("cache_values"))
  line("  add x2, x2, x10, lsl #2")
  line("  ldr x1, " .. slot("scores"))
  line("  add w3, w20, #1")
  line("  ldr w4, " .. slot("head_width"))
  line("  ldr w5, " .. slot("kv_width"))
  call("k_attention_mix")

  -- head advances always; the key head advances when the group completes
  line("  add x27, x27, #1")
  line("  ldr x9, [sp, #96]")
  line("  add x9, x9, #1")
  line("  ldr x10, " .. slot("heads_per_kv"))
  line("  cmp x9, x10")
  line("  b.lt " .. label("same_group"))
  line("  add x28, x28, #1")
  line("  mov x9, xzr")
  line(label("same_group") .. ":")
  line("  str x9, [sp, #96]")
  line("  ldr x10, " .. slot("heads"))
  line("  cmp x27, x10")
  line("  b.lt " .. label("head_loop"))
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
  -- THE ONE PLACE A WRONG CONDUCTING IS DELIBERATELY BUILT. Which of the
  -- two feedforward tensors feeds which projection. Swapping them keeps
  -- every shape identical -- nothing reads outside anything, nothing faults,
  -- every kernel still computes exactly what it is asked -- and the answer
  -- changes, because the gate goes through a curve the other half does not.
  local gate_tensor, up_tensor = "layer:6", "layer:7"
  if options.miswire then
    gate_tensor, up_tensor = "layer:7", "layer:6"
  end
  arguments({ "ptr:gate", gate_tensor, "ptr:normalised",
              "count:feedforward", "count:hidden" })
  call("multiply")
  arguments({ "ptr:up", up_tensor, "ptr:normalised",
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

  line("  add x22, x22, #" .. layer_stride)
  line("  add x23, x23, #1")
  line("  b " .. label("layer_loop"))
  line(label("layers_done") .. ":")

  -- {{{ the projection to a score per token
  load_scale("epsilon")
  arguments({ "ptr:normalised", "ptr:state", "ptr:output_norm", "count:hidden" })
  call("k_rms_normalise")
  line("  mov x0, x25")                     -- the logits the caller wants
  line("  ldr x1, " .. slot("output"))
  line("  ldr x2, " .. slot("normalised"))
  line("  ldr w3, " .. slot("vocabulary"))
  line("  ldr w4, " .. slot("hidden"))
  call("multiply")
  -- }}}

  line("  ldp x19, x20, [sp, #16]")
  line("  ldp x21, x22, [sp, #32]")
  line("  ldp x23, x24, [sp, #48]")
  line("  ldp x25, x26, [sp, #64]")
  line("  ldp x27, x28, [sp, #80]")
  line("  ldp x29, x30, [sp], #112")
  line("  ret")
  line("")

  return table.concat(out, "\n")
end
-- }}}

return M
