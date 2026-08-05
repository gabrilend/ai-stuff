-- 126-tokenizer-elsewhere.lua
--
-- Text into the model's numbers and back, in the second and third tongues.
-- Issue 403.
--
-- For a general: the machine is told things in text and thinks in numbers.
-- This is the piece between. Without it an engine can think and cannot be
-- told anything, because what it was told is text -- including the
-- instruction it wakes up holding.
--
-- WHY BOTH IN ONE FILE. They are one piece of work, written together rather
-- than one and then the other. Every previous piece of assembly here was
-- written for one architecture and ported later, and every time something
-- went missing or drifted between them without anything saying so. Two
-- implementations side by side check each other continuously; two written in
-- sequence check the first one twice, and late.
--
-- WHAT MAKES THIS ONE DANGEROUS. There is no floating point in it at all --
-- it walks bytes, looks pairs up in a table, and joins the best-ranked pair
-- over and over. So it ports mechanically. But its failure mode is a WRONG
-- ANSWER THAT LOOKS FINE: a tokenizer that joins in a slightly different
-- order still produces numbers, and the machine then reads a subtly
-- different instruction and never knows. Nothing faults, nothing is
-- reported, and the machine is simply told something else.
--
-- That is why it is held to the same awkward corpus the first architecture
-- is held to, rather than to a handful of easy words. The cases where
-- tokenizers actually disagree with each other are the whole test.
--
-- THE ORDER OF JOINING IS THE SPECIFICATION. The strongest rule is tried
-- first against every position, and a join sends the walk back to the
-- strongest rule again, because a join can enable one that did not apply
-- before. Trying every rule once in order would be faster and would be a
-- different tokenizer.

local M = {}

-- {{{ M.aarch64(tokenizer)
--
-- int64_t tokenizer_encode(const TokenizerPlan *plan, const uint8_t *text,
--                          int64_t text_length, int32_t *tokens_out)
--
-- plan x0, text x1, length x2, out x3. Returns how many tokens, or minus the
-- position of the first unsayable byte, minus one -- so minus one means the
-- very first byte, and zero stays an honest count for empty text.
--
-- int64_t tokenizer_decode(const TokenizerPlan *plan, const int32_t *tokens,
--                          int64_t count, uint8_t *text_out)
--
-- Neither routine calls anything, so both live entirely in the registers the
-- convention calls scratch -- x4 through x17, of which this architecture has
-- enough that nothing needs saving. The first tongue has to push two.
--
-- `tokenizer` is the module that describes the prepared table (059), passed
-- in so there stays one description of where every slot sits.
function M.aarch64(tokenizer)
  local at = tokenizer.plan_offsets()
  local out = {}
  local function line(text) out[#out + 1] = text end
  local function slot(name) return "[x0, #" .. at[name] .. "]" end

  -- {{{ encode
  line("  .globl tokenizer_encode")
  line("  .type tokenizer_encode, @function")
  line("tokenizer_encode:")

  -- every byte becomes its own token first, or the text is refused
  line("  ldr x4, " .. slot("byte_token"))
  line("  mov x5, xzr")
  line("enc_byte_loop:")
  line("  cmp x5, x2")
  line("  b.ge enc_bytes_done")
  line("  ldrb w6, [x1, x5]")
  line("  ldr w7, [x4, x6, lsl #2]")
  line("  tbnz w7, #31, enc_unsayable")     -- minus one in the table
  line("  str w7, [x3, x5, lsl #2]")
  line("  add x5, x5, #1")
  line("  b enc_byte_loop")
  line("enc_unsayable:")
  line("  mvn x0, x5")                      -- minus position, minus one
  line("  ret")
  line("enc_bytes_done:")

  -- The merge walk. x2 is how many pieces remain; after this point the text
  -- itself is never read again, so x1 could be scratch -- and is left alone
  -- anyway, because there are registers to spare here and a reader
  -- comparing the three tongues should not have to work out why one of them
  -- reuses an argument.
  line("enc_restart:")
  line("  cmp x2, #2")
  line("  b.lt enc_merges_done")            -- one piece cannot pair
  line("  ldr x9, " .. slot("merge_rules"))
  line("  mov x8, xzr")                     -- the strongest rule first
  line("enc_rule_loop:")
  line("  ldr x14, " .. slot("merge_count"))
  line("  cmp x8, x14")
  line("  b.ge enc_merges_done")            -- no rule applies to what is left
  line("  ldr w10, [x9]")                   -- the pair this rule joins
  line("  ldr w11, [x9, #4]")
  line("  mov x6, xzr")                     -- and where it first applies
  line("enc_position_loop:")
  line("  add x7, x6, #1")
  line("  cmp x7, x2")
  line("  b.ge enc_rule_next")              -- ran out of adjacent pairs
  line("  ldr w12, [x3, x6, lsl #2]")
  line("  cmp w12, w10")
  line("  b.ne enc_position_next")
  line("  add x13, x3, x6, lsl #2")
  line("  ldr w12, [x13, #4]")
  line("  cmp w12, w11")
  line("  b.eq enc_joined")
  line("enc_position_next:")
  line("  add x6, x6, #1")
  line("  b enc_position_loop")
  line("enc_rule_next:")
  line("  add x9, x9, #12")                 -- three numbers per rule
  line("  add x8, x8, #1")
  line("  b enc_rule_loop")

  line("enc_joined:")
  line("  ldr w10, [x9, #8]")               -- what the rule produces
  line("  str w10, [x3, x6, lsl #2]")
  -- close the gap: everything after the joined pair moves down one
  line("enc_close_gap:")
  line("  add x7, x6, #2")
  line("  cmp x7, x2")
  line("  b.ge enc_gap_closed")
  line("  ldr w10, [x3, x7, lsl #2]")
  line("  add x13, x3, x6, lsl #2")
  line("  str w10, [x13, #4]")
  line("  add x6, x6, #1")
  line("  b enc_close_gap")
  line("enc_gap_closed:")
  line("  sub x2, x2, #1")
  line("  b enc_restart")                   -- a join can enable a stronger rule

  line("enc_merges_done:")
  line("  mov x0, x2")
  line("  ret")
  line("")
  -- }}}

  -- {{{ decode
  -- A lookup and a concatenation.
  line("  .globl tokenizer_decode")
  line("  .type tokenizer_decode, @function")
  line("tokenizer_decode:")
  line("  ldr x4, " .. slot("token_offsets"))
  line("  ldr x5, " .. slot("token_bytes"))
  line("  mov x6, xzr")                     -- which number
  line("  mov x7, xzr")                     -- how many bytes written
  line("dec_loop:")
  line("  cmp x6, x2")
  line("  b.ge dec_done")
  line("  ldrsw x8, [x1, x6, lsl #2]")
  line("  tbnz x8, #63, dec_unknown")
  line("  ldr x9, " .. slot("token_count"))
  line("  cmp x8, x9")
  line("  b.ge dec_unknown")
  -- this token's text: from one fencepost to the next. The end is read
  -- first, because the beginning lands on top of the number on the first
  -- tongue -- and is read first here too, so the three read alike.
  line("  add x10, x4, x8, lsl #2")
  line("  ldr w11, [x10, #4]")
  line("  ldr w9, [x10]")
  line("dec_copy_loop:")
  line("  cmp w9, w11")
  line("  b.ge dec_copied")
  line("  ldrb w12, [x5, w9, sxtw]")
  line("  strb w12, [x3, x7]")
  line("  add x7, x7, #1")
  line("  add w9, w9, #1")
  line("  b dec_copy_loop")
  line("dec_copied:")
  line("  add x6, x6, #1")
  line("  b dec_loop")
  line("dec_unknown:")
  line("  mvn x7, x6")
  line("dec_done:")
  line("  mov x0, x7")
  line("  ret")
  line("")
  -- }}}

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.riscv64(p, tokenizer)
--
-- int64_t tokenizer_encode(const TokenizerPlan *plan, const uint8_t *text,
--                          int64_t text_length, int32_t *tokens_out)
--
-- plan a0, text a1, length a2, out a3. Same returns as above.
--
-- Emitted into a counted program rather than returned as text, because this
-- assembler leaves a relocation on a branch to a label in its own file and
-- there is no linker to answer it -- so every loop here would be a silent
-- infinite one (054).
--
-- THE RETURN VALUE COMES BACK IN a0, WHICH IS ALSO THE PLAN. That matters
-- more here than on the other two: the plan is read on every pass through
-- the rule loop, so it cannot be overwritten until the routine is finished
-- with it. The other two tongues have the same overlap and more registers to
-- hide it in.
function M.riscv64(p, tokenizer)
  local at = tokenizer.plan_offsets()
  local function slot(name) return at[name] .. "(a0)" end

  -- {{{ encode
  p:label("tokenizer_encode")
  p:op("ld t0, " .. slot("byte_token"))
  p:op("mv t1, zero")                       -- which byte
  p:label("enc_byte_loop")
  p:branch("bge", "t1", "a2", "enc_bytes_done")
  p:op("add t2, a1, t1")
  p:op("lbu t2, 0(t2)")
  p:op("slli t2, t2, 2")
  p:op("add t2, t0, t2")
  p:op("lw t3, 0(t2)")                      -- sign-extended, so a minus one
  p:branch("blt", "t3", "zero", "enc_unsayable")  -- really is negative
  p:op("slli t4, t1, 2")
  p:op("add t4, a3, t4")
  p:op("sw t3, 0(t4)")
  p:op("addi t1, t1, 1")
  p:jump("enc_byte_loop")
  p:label("enc_unsayable")
  p:op("not a0, t1")                        -- minus position, minus one
  p:op("jalr zero, 0(ra)")
  p:label("enc_bytes_done")

  -- the merge walk. a2 is how many pieces remain.
  p:label("enc_restart")
  p:op("addi t0, zero, 2")
  p:branch("blt", "a2", "t0", "enc_merges_done")   -- one piece cannot pair
  p:op("ld t0, " .. slot("merge_rules"))
  p:op("mv t1, zero")                       -- the strongest rule first
  p:label("enc_rule_loop")
  p:op("ld t2, " .. slot("merge_count"))
  p:branch("bge", "t1", "t2", "enc_merges_done")
  p:op("lw t3, 0(t0)")                      -- the pair this rule joins
  p:op("lw t4, 4(t0)")
  p:op("mv t5, zero")                       -- and where it first applies
  p:label("enc_position_loop")
  p:op("addi t6, t5, 1")
  p:branch("bge", "t6", "a2", "enc_rule_next")
  p:op("slli t6, t5, 2")
  p:op("add t6, a3, t6")
  p:op("lw a4, 0(t6)")
  p:branch("bne", "a4", "t3", "enc_position_next")
  p:op("lw a4, 4(t6)")
  p:branch("beq", "a4", "t4", "enc_joined")
  p:label("enc_position_next")
  p:op("addi t5, t5, 1")
  p:jump("enc_position_loop")
  p:label("enc_rule_next")
  p:op("addi t0, t0, 12")                   -- three numbers per rule
  p:op("addi t1, t1, 1")
  p:jump("enc_rule_loop")

  p:label("enc_joined")
  p:op("lw a4, 8(t0)")                      -- what the rule produces
  p:op("slli t6, t5, 2")
  p:op("add t6, a3, t6")
  p:op("sw a4, 0(t6)")
  -- close the gap: everything after the joined pair moves down one
  p:label("enc_close_gap")
  p:op("addi a5, t5, 2")
  p:branch("bge", "a5", "a2", "enc_gap_closed")
  p:op("slli a5, a5, 2")
  p:op("add a5, a3, a5")
  p:op("lw a4, 0(a5)")
  p:op("slli t6, t5, 2")
  p:op("add t6, a3, t6")
  p:op("sw a4, 4(t6)")
  p:op("addi t5, t5, 1")
  p:jump("enc_close_gap")
  p:label("enc_gap_closed")
  p:op("addi a2, a2, -1")
  p:jump("enc_restart")                     -- a join can enable a stronger rule

  p:label("enc_merges_done")
  p:op("mv a0, a2")
  p:op("jalr zero, 0(ra)")
  -- }}}

  -- {{{ decode
  p:label("tokenizer_decode")
  p:op("ld t0, " .. slot("token_offsets"))
  p:op("ld t1, " .. slot("token_bytes"))
  p:op("mv t2, zero")                       -- which number
  p:op("mv t3, zero")                       -- how many bytes written
  p:label("dec_loop")
  p:branch("bge", "t2", "a2", "dec_done")
  p:op("slli t4, t2, 2")
  p:op("add t4, a1, t4")
  p:op("lw t4, 0(t4)")                      -- sign-extended
  p:branch("blt", "t4", "zero", "dec_unknown")
  p:op("ld t5, " .. slot("token_count"))
  p:branch("bge", "t4", "t5", "dec_unknown")
  -- this token's text: from one fencepost to the next
  p:op("slli t5, t4, 2")
  p:op("add t5, t0, t5")
  p:op("lw t6, 4(t5)")                      -- the end, read first
  p:op("lw t5, 0(t5)")                      -- and then the beginning
  p:label("dec_copy_loop")
  p:branch("bge", "t5", "t6", "dec_copied")
  p:op("add a4, t1, t5")
  p:op("lbu a4, 0(a4)")
  p:op("add a5, a3, t3")
  p:op("sb a4, 0(a5)")
  p:op("addi t3, t3, 1")
  p:op("addi t5, t5, 1")
  p:jump("dec_copy_loop")
  p:label("dec_copied")
  p:op("addi t2, t2, 1")
  p:jump("dec_loop")
  p:label("dec_unknown")
  p:op("not t3, t2")
  p:label("dec_done")
  p:op("mv a0, t3")
  p:op("jalr zero, 0(ra)")
  -- }}}
end
-- }}}

return M
