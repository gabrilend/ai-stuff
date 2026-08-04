-- 114-conductor-riscv64.lua
--
-- The conducting, in the third tongue. The layer loop, the head loop, and
-- the pointer arithmetic that hands each routine exactly the memory it is
-- owed -- written a third time, in RISC-V's instructions. Issue 401.
--
-- For a general: the third architecture already has all eleven pieces of
-- arithmetic, every one proved to produce the same bits as the first. What
-- it did not have was anything to run them in order. This is that.
--
-- WHY IT IS A SEPARATE FILE. Same reason 099 and 108 are separate from their
-- first-tongue counterparts: a reader of one should not have to wade through
-- the others. The plan is NOT duplicated here -- it is asked for, so there
-- stays exactly one description of where every slot sits, and the same
-- description the other two conductings read.
--
-- WHY IT EMITS RATHER THAN RETURNS TEXT. This assembler leaves a relocation
-- on a branch to a label in its own file, and there is no linker to answer
-- it, so the branch keeps pointing at itself and the loop spins forever
-- saying nothing. Every distance is counted by the word emitter (054), which
-- has to see every instruction to count -- so this lays itself into a
-- program being built rather than handing back a string.
--
-- WHAT IS EASIER HERE THAN ANYWHERE. This architecture has twelve registers
-- that survive a call, where x86 has six and ARM has ten. Every piece of
-- loop state fits, so unlike the first tongue nothing spills to the stack
-- and unlike the second nothing needs a slot beside the frame. That is a
-- difference of convenience and not of specification: the order of
-- operations is identical on all three, and the order of operations is the
-- only thing the answer depends on.
--
-- There is no floating point in here at all. Every number this file touches
-- is a count or an address, which is why a disagreement after this change
-- cannot be an arithmetic disagreement.

local M = {}

-- {{{ M.emit(p, plan, options)
--
-- void forward_conduct(const ForwardPlan *plan, int64_t token,
--                      int64_t position, float *logits)
--
-- plan a0, token a1, position a2, logits a3.
--
-- `plan` is the module that describes the plan's layout (056), passed in so
-- this file has no opinion about where the project lives and no second copy
-- of the layout.
--
-- options.name renames the routine and every label inside it, so more than
-- one conducting can sit in one program.
--
-- options.miswire EMITS A DELIBERATELY WRONG ONE -- the feedforward's two
-- projections handed to each other's routines. Both tensors are exactly the
-- same shape, so nothing reads outside anything and nothing faults; every
-- routine still computes precisely what it is asked; and the answer is
-- wrong, because the gate goes through a curve the other half does not.
-- A test that proves the pieces agree and cannot show itself failing has
-- proved only that nothing crashed.
--
-- Where the state lives, all of it in registers that survive a call:
--
--   s0   the plan
--   s1   the position
--   s2   the row of turns for this position
--   s3   the cursor into the layer table
--   s4   the layer
--   s5   this position's slot in the cache, in numbers
--   s6   where the caller wants the scores written
--   s7   this layer's base slot in the cache, in numbers
--   s8   the head
--   s9   the key head
--   s10  how far through its group the head is
--
-- t0 and t1 are the scratch pair. Nothing that must survive a call is put in
-- either: the convention says a called routine may destroy them, and the
-- routines that raise e to a power do.
function M.emit(p, plan, options)
  options = options or {}
  local name = options.name or "forward_conduct"
  local at = plan.offsets()
  local layer_stride = #plan.LAYER_ORDER * 8

  local function label(what) return name .. "_" .. what end

  local function slot(name_of)
    if at[name_of] == nil then
      error("114-conductor-riscv64: the plan has no slot called '"
            .. tostring(name_of) .. "'. The layout is 056's to describe, and "
            .. "this file must not invent one.")
    end
    return at[name_of] .. "(s0)"
  end

  p:label(name)
  -- Thirteen things to give back: the return address and twelve registers.
  -- A hundred and four rounded up to a hundred and twelve, because the
  -- convention wants the stack pointer on a sixteen-byte boundary at every
  -- call and this routine makes many.
  p:op("addi sp, sp, -112")
  p:op("sd ra, 0(sp)")
  for index = 0, 11 do
    p:op("sd s" .. index .. ", " .. (8 + index * 8) .. "(sp)")
  end

  p:op("mv s0, a0")                           -- the plan
  p:op("mv s6, a3")                           -- the scores go here at the end
  p:op("mv s1, a2")                           -- the position
  -- the token is still in a1 and is consumed immediately below, before
  -- anything else is allowed to want that register.

  -- {{{ state <- what this token means, before anything has been done with it
  p:op("ld t0, " .. slot("hidden"))
  p:op("mul a1, a1, t0")                      -- token * hidden
  p:op("ld t1, " .. slot("token_embedding"))
  p:op("slli a1, a1, 2")
  p:op("add t1, t1, a1")                      -- that token's row
  p:op("ld t2, " .. slot("state"))
  p:op("mv t3, zero")
  p:label(label("copy_embedding"))
  p:op("slli t4, t3, 2")
  p:op("add t5, t1, t4")
  p:op("lw t6, 0(t5)")
  p:op("add t5, t2, t4")
  p:op("sw t6, 0(t5)")
  p:op("addi t3, t3, 1")
  p:branch("blt", "t3", "t0", label("copy_embedding"))
  -- }}}

  -- the row of turns for this position, computed once rather than per head
  p:op("ld t0, " .. slot("head_width"))
  p:op("mul t0, t0, s1")
  p:op("ld s2, " .. slot("rotation"))
  p:op("slli t0, t0, 2")
  p:op("add s2, s2, t0")

  p:op("ld s3, " .. slot("layer_table"))
  p:op("mv s4, zero")                         -- layer = 0
  p:label(label("layer_loop"))
  p:op("ld t0, " .. slot("layers"))
  p:branch("bge", "s4", "t0", label("layers_done"))

  -- {{{ a small vocabulary of call-site helpers
  --
  -- Each call names its arguments and nothing else. The registers are the
  -- convention's, loaded fresh every time, because nothing that a called
  -- routine may destroy survives a call and pretending otherwise is how a
  -- port acquires a defect that shows up in one routine's tail only.
  local argument_registers = { "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7" }

  -- one loader per shape of argument, dispatched by prefix -- the same five
  -- kinds the other two tongues have, so all three call sites read alike:
  --   ptr:NAME     the pointer in that slot
  --   ptrx:NAME    the pointer in that slot, plus s5 numbers of four bytes
  --   layer:N      the Nth tensor of this layer's row
  --   count:NAME   the low thirty-two bits of that slot
  --   reg:...      already-prepared value, taken as written
  local function arguments(list)
    local used = 0
    for _, entry in ipairs(list) do
      used = used + 1
      local register = argument_registers[used]
      if register == nil then
        error("114-conductor-riscv64: a routine is being handed more than "
              .. "eight arguments, and the ninth would go on the stack. No "
              .. "routine in this engine takes that many, so this is a "
              .. "mistake at the call site rather than a limit to raise.")
      end
      local kind, which = entry:match("^(%w+):(.+)$")
      if kind == "ptr" then
        p:op("ld " .. register .. ", " .. slot(which))
      elseif kind == "ptrx" then
        p:op("ld " .. register .. ", " .. slot(which))
        p:op("slli t0, s5, 2")
        p:op("add " .. register .. ", " .. register .. ", t0")
      elseif kind == "layer" then
        p:op("ld " .. register .. ", " .. (tonumber(which) * 8) .. "(s3)")
      elseif kind == "count" then
        -- the low half only, because the routine takes an int, and this
        -- machine stores the low half first exactly as the other two do
        p:op("lw " .. register .. ", " .. slot(which))
      elseif kind == "reg" then
        if which ~= register then
          p:op("mv " .. register .. ", " .. which)
        end
      else
        error("114: no argument kind called '" .. tostring(kind) .. "'")
      end
    end
  end

  -- The routine arrives as an address out of the plan, never as a name. On
  -- bare metal there are no names, and on this architecture a reference to
  -- one is a note for a linker that nothing reads -- which is the trap the
  -- whole word emitter exists to avoid.
  local function call(kernel)
    p:op("ld t0, " .. slot(kernel))
    p:op("jalr ra, 0(t0)")
  end

  -- The two floating constants are read straight out of the plan into the
  -- register the convention passes them in. This file computes neither.
  local function load_scale(which)
    p:op("flw fa0, " .. slot(which))
  end
  -- }}}

  -- {{{ attention
  load_scale("epsilon")
  arguments({ "ptr:normalised", "ptr:state", "layer:0", "count:hidden" })
  call("k_rms_normalise")

  -- this position's slot in the cache: (layer * context + position) * kv_width
  p:op("ld t0, " .. slot("context"))
  p:op("mul s5, s4, t0")
  p:op("add s5, s5, s1")
  p:op("ld t0, " .. slot("kv_width"))
  p:op("mul s5, s5, t0")

  arguments({ "ptr:query", "layer:1", "ptr:normalised",
              "count:query_width", "count:hidden" })
  call("multiply")
  arguments({ "ptrx:cache_keys", "layer:2", "ptr:normalised",
              "count:kv_width", "count:hidden" })
  call("multiply")
  arguments({ "ptrx:cache_values", "layer:3", "ptr:normalised",
              "count:kv_width", "count:hidden" })
  call("multiply")

  arguments({ "ptr:query", "reg:s2", "count:heads", "count:head_width" })
  call("k_rotate")
  arguments({ "ptrx:cache_keys", "reg:s2", "count:kv_heads", "count:head_width" })
  call("k_rotate")

  -- {{{ the heads, each asking its own question of the past
  --
  -- Query heads outnumber key heads, so the walk is two counters advancing
  -- together: the head, and how far through its key head's group it is. When
  -- the group completes, the key head advances -- no division anywhere,
  -- which matters because a division here would be the one piece of
  -- arithmetic in a routine that is supposed to have none.
  p:op("ld t0, " .. slot("context"))
  p:op("mul s7, s4, t0")
  p:op("ld t0, " .. slot("kv_width"))
  p:op("mul s7, s7, t0")
  p:op("mv s8, zero")                         -- head
  p:op("mv s9, zero")                         -- key head
  p:op("mv s10, zero")                        -- where in its group the head is

  p:label(label("head_loop"))

  -- attention_scores(scores, query + head * head_width,
  --                  keys + (layer_base + kv_head * head_width),
  --                  position + 1, head_width, kv_width, scale)
  load_scale("scale")
  p:op("ld a1, " .. slot("query"))
  p:op("ld t0, " .. slot("head_width"))
  p:op("mul t1, s8, t0")
  p:op("slli t1, t1, 2")
  p:op("add a1, a1, t1")
  p:op("mul t1, s9, t0")
  p:op("add t1, t1, s7")
  p:op("ld a2, " .. slot("cache_keys"))
  p:op("slli t1, t1, 2")
  p:op("add a2, a2, t1")
  p:op("ld a0, " .. slot("scores"))
  p:op("addiw a3, s1, 1")
  p:op("lw a4, " .. slot("head_width"))
  p:op("lw a5, " .. slot("kv_width"))
  call("k_attention_scores")

  p:op("ld a0, " .. slot("scores"))
  p:op("addiw a1, s1, 1")
  call("k_softmax")

  -- attention_mix(attended + head * head_width, scores,
  --               values + the same cache base, position + 1, ...)
  p:op("ld a0, " .. slot("attended"))
  p:op("ld t0, " .. slot("head_width"))
  p:op("mul t1, s8, t0")
  p:op("slli t1, t1, 2")
  p:op("add a0, a0, t1")
  p:op("mul t1, s9, t0")
  p:op("add t1, t1, s7")
  p:op("ld a2, " .. slot("cache_values"))
  p:op("slli t1, t1, 2")
  p:op("add a2, a2, t1")
  p:op("ld a1, " .. slot("scores"))
  p:op("addiw a3, s1, 1")
  p:op("lw a4, " .. slot("head_width"))
  p:op("lw a5, " .. slot("kv_width"))
  call("k_attention_mix")

  -- head advances always; the key head advances when the group completes
  p:op("addi s8, s8, 1")
  p:op("addi s10, s10, 1")
  p:op("ld t0, " .. slot("heads_per_kv"))
  p:branch("blt", "s10", "t0", label("same_group"))
  p:op("addi s9, s9, 1")
  p:op("mv s10, zero")
  p:label(label("same_group"))
  p:op("ld t0, " .. slot("heads"))
  p:branch("blt", "s8", "t0", label("head_loop"))
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

  -- THE ONE PLACE A WRONG CONDUCTING IS DELIBERATELY BUILT. Which of the two
  -- feedforward tensors feeds which projection. Swapping them keeps every
  -- shape identical, faults nothing, and leaves every routine computing what
  -- it is asked -- and changes the answer.
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

  p:op("addi s3, s3, " .. layer_stride)
  p:op("addi s4, s4, 1")
  p:jump(label("layer_loop"))
  p:label(label("layers_done"))

  -- {{{ the projection to a score per token
  load_scale("epsilon")
  arguments({ "ptr:normalised", "ptr:state", "ptr:output_norm", "count:hidden" })
  call("k_rms_normalise")
  p:op("mv a0, s6")                           -- the logits the caller wants
  p:op("ld a1, " .. slot("output"))
  p:op("ld a2, " .. slot("normalised"))
  p:op("lw a3, " .. slot("vocabulary"))
  p:op("lw a4, " .. slot("hidden"))
  call("multiply")
  -- }}}

  p:op("ld ra, 0(sp)")
  for index = 0, 11 do
    p:op("ld s" .. index .. ", " .. (8 + index * 8) .. "(sp)")
  end
  p:op("addi sp, sp, 112")
  p:op("jalr zero, 0(ra)")
end
-- }}}

return M
