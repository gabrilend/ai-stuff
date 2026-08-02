-- 059-emit-tokenizer.lua
--
-- The tokenizer, in assembly: text into the numbers the model works in, and
-- back. The assembly twin of 038, required to agree with it byte for byte and
-- token for token -- because a subtly wrong tokenizer does not fail, it
-- produces a model that seems mildly stupid, which is the worst failure
-- available.
--
-- For a general: the model never sees letters. Something has to turn text
-- into its numbers and its numbers back into text, exactly the way the
-- model's training did. This is that, in the processor's own instructions.
--
-- THE PREPARED TABLE. Encoding by the book means looking strings up while
-- merging, and the metal has no hashes and no strings to spare. So the work
-- is split the way the conductor split it (056): once, at load time, the
-- carried tables are walked into a prepared form -- which token says each
-- byte, what token each merge rule produces, where each token's text lies --
-- and the think-time halves below never touch a string while encoding at
-- all. The preparation is done by the host here and belongs to the engine's
-- startup on the metal; a rule whose joined text is not in the vocabulary is
-- refused while preparing, which is earlier than the reference notices, and
-- earlier is the right direction for a refusal.
--
-- THE MERGE ORDER IS THE REFERENCE'S. The reference repeatedly finds the
-- lowest-ranked rule that applies anywhere. Walking the rules in rank order
-- and taking the first that applies IS that rule; applying it at its first
-- occurrence is the reference's tie among positions; and restarting from the
-- strongest rule after every join is the reference's full re-scan. The two
-- walks are the same walk, and the naive cost is accepted deliberately --
-- correct first, faster later, as the blueprint says.

local ffi = require("ffi")

local M = {}

-- {{{ M.PLAN_SLOTS -- the prepared table, one slot per row, eight bytes each
M.PLAN_SLOTS = {
  { name = "byte_token",    declaration = "const int32_t *byte_token" },     -- 256; minus one means unsayable
  { name = "merge_rules",   declaration = "const uint32_t *merge_rules" },   -- three per rule: left, right, result
  { name = "merge_count",   declaration = "int64_t merge_count" },
  { name = "token_offsets", declaration = "const uint32_t *token_offsets" }, -- count plus one fenceposts
  { name = "token_bytes",   declaration = "const uint8_t *token_bytes" },
  { name = "token_count",   declaration = "int64_t token_count" },
}
-- }}}

-- {{{ M.plan_offsets()
function M.plan_offsets()
  local at, offsets = 0, {}
  for _, slot in ipairs(M.PLAN_SLOTS) do
    offsets[slot.name] = at
    at = at + 8
  end
  return offsets
end
-- }}}

-- {{{ M.declare()
function M.declare()
  local lines = { "typedef struct {" }
  for _, slot in ipairs(M.PLAN_SLOTS) do
    lines[#lines + 1] = "  " .. slot.declaration .. ";"
  end
  lines[#lines + 1] = "} TokenizerPlan;"
  ffi.cdef(table.concat(lines, "\n"))

  local offsets = M.plan_offsets()
  for _, slot in ipairs(M.PLAN_SLOTS) do
    if ffi.offsetof("TokenizerPlan", slot.name) ~= offsets[slot.name] then
      error("059-emit-tokenizer: slot '" .. slot.name .. "' sits at "
        .. tostring(ffi.offsetof("TokenizerPlan", slot.name)) .. " for the FFI and "
        .. offsets[slot.name] .. " for the assembly.")
    end
  end

  ffi.cdef[[
    int64_t tokenizer_encode(const TokenizerPlan *plan, const uint8_t *text,
                             int64_t text_length, int32_t *tokens_out);
    int64_t tokenizer_decode(const TokenizerPlan *plan, const int32_t *tokens,
                             int64_t count, uint8_t *text_out);
  ]]
end
-- }}}

-- {{{ M.prepare(tokens, merges)
-- The load-time walk: the carried tables into the prepared form. Hosted this
-- is done here; on the metal it is the engine's startup, and it is all
-- table-walking with no floating point anywhere.
function M.prepare(tokens, merges)
  local count = #tokens

  -- which token says each byte, or minus one for a byte this vocabulary
  -- cannot say. First wins when a text appears twice, matching the
  -- reference's rule that the lower number is the trained one.
  local first_by_text = {}
  for index, text in ipairs(tokens) do
    if first_by_text[text] == nil then first_by_text[text] = index - 1 end
  end

  local byte_token = ffi.new("int32_t[256]")
  for byte = 0, 255 do
    byte_token[byte] = first_by_text[string.char(byte)] or -1
  end

  -- what each rule produces, found once by the string search the think-time
  -- half must never need. A rule that makes something outside the vocabulary
  -- is refused here, while there is still a person to read the refusal.
  local merge_rules = ffi.new("uint32_t[?]", #merges * 3)
  for index, pair in ipairs(merges) do
    local joined = tokens[pair[1] + 1] .. tokens[pair[2] + 1]
    local result = first_by_text[joined]
    if result == nil then
      error("059-emit-tokenizer: merge rule " .. index .. " makes '" .. joined
        .. "', which is not in the vocabulary")
    end
    merge_rules[(index - 1) * 3] = pair[1]
    merge_rules[(index - 1) * 3 + 1] = pair[2]
    merge_rules[(index - 1) * 3 + 2] = result
  end

  -- every token's text, packed end to end with fenceposts, for decoding.
  local total = 0
  for _, text in ipairs(tokens) do total = total + #text end
  local token_offsets = ffi.new("uint32_t[?]", count + 1)
  local token_bytes = ffi.new("uint8_t[?]", math.max(total, 1))
  local at = 0
  for index, text in ipairs(tokens) do
    token_offsets[index - 1] = at
    ffi.copy(token_bytes + at, text, #text)
    at = at + #text
  end
  token_offsets[count] = at

  local plan = ffi.new("TokenizerPlan")
  plan.byte_token = byte_token
  plan.merge_rules = merge_rules
  plan.merge_count = #merges
  plan.token_offsets = token_offsets
  plan.token_bytes = token_bytes
  plan.token_count = count

  return { plan = plan, longest = at,
           keep = { byte_token, merge_rules, token_offsets, token_bytes } }
end
-- }}}

-- {{{ M.x86_64()
--
-- int64_t tokenizer_encode(const TokenizerPlan *plan, const uint8_t *text,
--                          int64_t text_length, int32_t *tokens_out)
--
-- plan rdi, text rsi, length rdx, out rcx. Returns how many tokens, or minus
-- the position of the first unsayable byte, minus one -- so minus one means
-- the very first byte, and zero stays an honest count for empty text.
-- `tokens_out` must hold one number per byte of text, since that is where
-- the pieces start.
--
-- int64_t tokenizer_decode(const TokenizerPlan *plan, const int32_t *tokens,
--                          int64_t count, uint8_t *text_out)
--
-- Returns how many bytes were written, or minus the position of the first
-- unknown number, minus one. Neither routine calls anything, so both live
-- entirely in the registers the convention calls scratch.
function M.x86_64()
  local at = M.plan_offsets()
  local out = {}
  local function line(text) out[#out + 1] = text end
  local function slot(name) return at[name] .. "(%rdi)" end

  -- {{{ encode
  line("  .globl tokenizer_encode")
  line("  .type tokenizer_encode, @function")
  line("tokenizer_encode:")

  -- every byte becomes its own token first, or the text is refused.
  line("  movq " .. slot("byte_token") .. ", %r10")
  line("  xorl %r8d, %r8d")
  line("byte_loop:")
  line("  cmpq %rdx, %r8")
  line("  jge bytes_done")
  line("  movzbl (%rsi,%r8), %eax")
  line("  movl (%r10,%rax,4), %eax")
  line("  testl %eax, %eax")
  line("  js unsayable")                   -- minus one in the table: no token
  line("  movl %eax, (%rcx,%r8,4)")
  line("  incq %r8")
  line("  jmp byte_loop")
  line("unsayable:")
  line("  movq %r8, %rax")
  line("  notq %rax")                      -- minus position, minus one
  line("  retq")
  line("bytes_done:")

  -- the merge walk. rdx is how many pieces remain; after this point the text
  -- itself is never read again, so rsi becomes scratch.
  line("merge_restart:")
  line("  cmpq $2, %rdx")
  line("  jl merges_done")                 -- one piece cannot pair
  line("  movq " .. slot("merge_rules") .. ", %r9")
  line("  xorl %r8d, %r8d")                -- the strongest rule first
  line("rule_loop:")
  line("  cmpq " .. slot("merge_count") .. ", %r8")
  line("  jge merges_done")                -- no rule applies to anything left
  line("  movl (%r9), %r10d")              -- the pair this rule joins
  line("  movl 4(%r9), %r11d")
  line("  xorl %eax, %eax")                -- and where it first applies
  line("position_loop:")
  line("  leaq 1(%rax), %rsi")
  line("  cmpq %rdx, %rsi")
  line("  jge rule_next")                  -- ran out of adjacent pairs
  line("  cmpl %r10d, (%rcx,%rax,4)")
  line("  jne position_next")
  line("  cmpl %r11d, 4(%rcx,%rax,4)")
  line("  je joined")
  line("position_next:")
  line("  incq %rax")
  line("  jmp position_loop")
  line("rule_next:")
  line("  addq $12, %r9")                  -- three numbers per rule
  line("  incq %r8")
  line("  jmp rule_loop")

  line("joined:")
  line("  movl 8(%r9), %r10d")             -- what the rule produces
  line("  movl %r10d, (%rcx,%rax,4)")
  -- close the gap: everything after the joined pair moves down one.
  line("close_gap:")
  line("  leaq 2(%rax), %rsi")
  line("  cmpq %rdx, %rsi")
  line("  jge gap_closed")
  line("  movl (%rcx,%rsi,4), %r10d")
  line("  movl %r10d, 4(%rcx,%rax,4)")
  line("  incq %rax")
  line("  jmp close_gap")
  line("gap_closed:")
  line("  decq %rdx")
  line("  jmp merge_restart")              -- a join can enable a stronger rule

  line("merges_done:")
  line("  movq %rdx, %rax")
  line("  retq")
  line("")
  -- }}}

  -- {{{ decode
  -- A lookup and a concatenation. Every scratch register has a job, so the
  -- fencepost and the byte in flight ride in two saved ones -- there are no
  -- calls here, so saving them is the whole of the ceremony.
  line("  .globl tokenizer_decode")
  line("  .type tokenizer_decode, @function")
  line("tokenizer_decode:")
  line("  pushq %rbx")
  line("  pushq %rbp")
  line("  movq " .. slot("token_offsets") .. ", %r10")
  line("  movq " .. slot("token_bytes") .. ", %r11")
  line("  xorl %r8d, %r8d")                -- which number
  line("  xorl %eax, %eax")                -- how many bytes written
  line("decode_loop:")
  line("  cmpq %rdx, %r8")
  line("  jge decode_done")
  line("  movslq (%rsi,%r8,4), %r9")
  line("  testq %r9, %r9")
  line("  js unknown_number")
  line("  cmpq " .. slot("token_count") .. ", %r9")
  line("  jge unknown_number")
  -- this token's text: from one fencepost to the next. The end is read
  -- first, because the beginning lands on top of the number.
  line("  movl 4(%r10,%r9,4), %ebx")
  line("  movl (%r10,%r9,4), %r9d")
  line("copy_loop:")
  line("  cmpl %ebx, %r9d")
  line("  jge copied")
  line("  movzbl (%r11,%r9), %ebp")
  line("  movb %bpl, (%rcx,%rax)")
  line("  incq %rax")
  line("  incq %r9")
  line("  jmp copy_loop")
  line("copied:")
  line("  incq %r8")
  line("  jmp decode_loop")
  line("unknown_number:")
  line("  movq %r8, %rax")
  line("  notq %rax")
  line("decode_done:")
  line("  popq %rbp")
  line("  popq %rbx")
  line("  retq")
  line("")
  -- }}}

  return table.concat(out, "\n")
end
-- }}}

return M
