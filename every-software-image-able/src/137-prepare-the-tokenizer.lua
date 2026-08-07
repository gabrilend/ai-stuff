-- 137-prepare-the-tokenizer.lua
--
-- Building the tokenizer's prepared table on a bare machine, from the tables
-- the model carries. The fourth piece of the driver (issue 107a).
--
-- For a general: the engine works in numbers and people work in text, and
-- something has to hold the mapping between them in a form the arithmetic can
-- use. Hosted, a page of host code builds that mapping with hash lookups and
-- string comparison. Neither exists here. This walks the model's own token
-- and merge tables and builds the same four arrays out of a run of memory,
-- with nothing underneath it.
--
-- WHY THIS EXISTS AT ALL, and it is a cost the engine chose deliberately.
-- `059` split the tokenizer the way `056` split the conducting: the
-- think-time halves never touch a string, so all the string work happens once
-- at startup. That decision is right -- encoding is run per token forever and
-- preparing is run once -- but it does not make the string work disappear. It
-- moves it here, where it must be paid in assembly.
--
-- THE EXPENSIVE PART IS THE MERGE RULES, and it is worth knowing where it
-- stops working rather than discovering it. A rule names two tokens and
-- produces a third: the one whose text is those two texts joined. Finding it
-- means a walk over the whole vocabulary, per rule, comparing bytes -- there
-- is no hash and nothing to build one with. That is the merge count times the
-- vocabulary size times the length of a token: nothing on a fixture, and on
-- the order of tens of billions of byte comparisons for a real model with
-- thirty thousand of each.
--
-- It is paid once, at startup, and never again. If it turns out to be too
-- slow to sit through, the answer is to pay it at build time and carry the
-- prepared table on the image -- which is a different design with a different
-- seam, and belongs to whoever first boots a real model rather than being
-- guessed at now. `024` says the token table is read once at startup to build
-- whatever lookup the engine wants, and that is what this does.
--
-- REFUSALS ARE A CODE AND A NUMBER, WHICH IS NOT WHAT `133` DOES. That
-- routine has one way to fail -- not enough room -- so it can return minus
-- the shortfall and let the number be the whole diagnosis. This one has two,
-- and they want different numbers: how many bytes short, or which merge rule
-- makes something the vocabulary does not hold. A single negative return
-- cannot carry both without a reader having to know which kind it is looking
-- at, so the return says WHICH failure and the caller's number says HOW MUCH.

local M = {}

-- {{{ M.header_offsets(format) and M.room_for(shape_counts)
--
-- Asked rather than transcribed, for the reason `131` gives: a hand-copied
-- offset that drifts by four produces a machine that reads noise confidently.
function M.header_offsets(format)
  local at, offsets = 0, {}
  for _, field in ipairs(format.HEADER) do
    offsets[field.name] = at
    at = at + field.size
  end
  return offsets
end
-- }}}

-- {{{ M.expected(token_count, merge_count, text_bytes)
--
-- Where each of the four arrays lands in the run of memory, and how much the
-- lot needs. This is the host's answer, and it is what the assembly is held
-- to -- one description, asked by both, so the two cannot drift.
--
-- ORDER IS LAYOUT, and the order is by decreasing certainty of size. The
-- byte map is always the same thousand and twenty-four bytes; the rules and
-- the fenceposts are counts the header carries; the text is the only one that
-- has to be measured by walking. Putting the measured one last means the
-- walk that measures it does not have to happen before anything can be
-- placed.
function M.expected(token_count, merge_count, text_bytes)
  local at, places = 0, {}
  local function place(name, bytes)
    places[name] = at
    at = at + bytes
    -- onto a sixteen-byte boundary, for the reason `133` gives: some
    -- processors fault rather than slow down on an unaligned wide load, and
    -- satisfying it everywhere is cheaper than remembering where it matters.
    if at % 16 ~= 0 then at = at + (16 - at % 16) end
  end
  place("byte_token", 256 * 4)
  place("merge_rules", merge_count * 3 * 4)
  place("token_offsets", (token_count + 1) * 4)
  place("token_bytes", text_bytes)
  return places, at
end
-- }}}

-- {{{ M.x86_64(format, tokenizer)
--
-- int64_t tokenizer_prepare(const uint8_t *blob, void *room, int64_t bytes,
--                           TokenizerPlan *plan, int64_t *detail)
--
-- blob rdi, room rsi, bytes rdx, plan rcx, detail r8.
--
-- Returns how many bytes of `room` were used, or:
--   -1  the room is too small; `detail` receives how many bytes short
--   -2  a merge rule makes a text the vocabulary does not hold; `detail`
--       receives which rule, counting from zero
--   -3  a merge rule names a token that does not exist; `detail` the same
--
-- The last two are separated because they are different broken models. A rule
-- making a text nothing holds is a merge table and a vocabulary from different
-- places; a rule naming a token past the end is a merge table from a larger
-- model entirely, and the second is the one that would read past an array.
--
-- `room` must begin on a sixteen-byte boundary. Everything inside it is
-- placed relative to that, so an unaligned start makes every array unaligned
-- and there is nothing here that could notice.
--
-- `detail` may be null, in which case the code comes back alone. It is
-- allowed because the first caller to meet a refusal is a test that already
-- knows what it handed in; a machine on a serial port always wants the
-- number.
function M.x86_64(format, tokenizer)
  local header = M.header_offsets(format)
  local slot = tokenizer.plan_offsets()
  local out = {}
  local function line(text) out[#out + 1] = text end

  -- the stack frame, named rather than numbered. Six of these are addresses
  -- computed once and read many times, and a frame of bare offsets is the
  -- single easiest place in a routine like this to write one field and read
  -- another.
  local frame = {
    plan = 0, detail = 8, byte_token = 16, merge_rules = 24,
    token_offsets = 32, token_bytes = 40, text_bytes = 48,
    room_bytes = 56, used = 64, off_left = 72, len_left = 80,
    off_right = 88, len_right = 96, rule = 104,
  }
  local FRAME_BYTES = 120
  local function at(name) return frame[name] .. "(%rsp)" end

  line("  .globl tokenizer_prepare")
  line("  .type tokenizer_prepare, @function")
  line("tokenizer_prepare:")
  line("  pushq %rbx")
  line("  pushq %rbp")
  line("  pushq %r12")
  line("  pushq %r13")
  line("  pushq %r14")
  line("  pushq %r15")
  line("  subq $" .. FRAME_BYTES .. ", %rsp")

  -- {{{ the arguments, put somewhere that survives
  line("  movq %rdi, %rbx")                   -- the model
  line("  movq %rsi, %rbp")                   -- the room
  line("  movq %rcx, " .. at("plan"))
  line("  movq %r8, " .. at("detail"))
  line("  movq %rdx, " .. at("room_bytes"))

  line("  movl " .. header.token_count .. "(%rbx), %r12d")
  line("  movl " .. header.merge_count .. "(%rbx), %r13d")
  line("  movq " .. header.token_table .. "(%rbx), %r14")
  line("  addq %rbx, %r14")                   -- where the token table begins
  line("  movq " .. header.merge_table .. "(%rbx), %r15")
  line("  addq %rbx, %r15")                   -- and the merge table
  -- }}}

  -- {{{ how many bytes all the token texts come to
  --
  -- A walk that writes nothing. It has to happen before anything is placed,
  -- because the token table is variable-length -- a length byte then that
  -- many bytes, `024` -- and there is no count of the total anywhere in the
  -- header. Measuring first is also what lets the room be refused before a
  -- single byte of it has been written, which is the difference between a
  -- machine that says it is short and one that scribbles past the end and
  -- says nothing.
  line("  xorl %eax, %eax")                   -- the total so far
  line("  movq %r14, %r9")                    -- the walker
  line("  xorl %r10d, %r10d")                 -- which token
  line("tp_sum:")
  line("  cmpq %r12, %r10")
  line("  jge tp_sum_done")
  line("  movzbl (%r9), %ecx")                -- the length byte
  line("  addq %rcx, %rax")
  line("  leaq 1(%r9,%rcx), %r9")
  line("  incq %r10")
  line("  jmp tp_sum")
  line("tp_sum_done:")
  line("  movq %rax, " .. at("text_bytes"))
  -- }}}

  -- {{{ where the four arrays go, in the order M.expected names them
  line("  movq %rbp, " .. at("byte_token"))
  line("  movl $1024, %r11d")                 -- how far in, so far

  local function place(name, size_lines)
    line("  movq %rbp, %rax")
    line("  addq %r11, %rax")
    line("  movq %rax, " .. at(name))
    for _, one in ipairs(size_lines) do line(one) end
    line("  addq %rax, %r11")
    line("  addq $15, %r11")
    line("  andq $-16, %r11")
  end

  place("merge_rules", { "  movq %r13, %rax", "  imulq $12, %rax" })
  place("token_offsets", { "  movq %r12, %rax", "  incq %rax",
                           "  shlq $2, %rax" })
  place("token_bytes", { "  movq " .. at("text_bytes") .. ", %rax" })
  -- }}}

  -- {{{ does it fit, said as the shortfall
  line("  cmpq " .. at("room_bytes") .. ", %r11")
  line("  jle tp_fits")
  line("  movq %r11, %rax")
  line("  subq " .. at("room_bytes") .. ", %rax")
  line("  movq " .. at("detail") .. ", %rcx")
  line("  testq %rcx, %rcx")
  line("  jz tp_short_quiet")
  line("  movq %rax, (%rcx)")
  line("tp_short_quiet:")
  line("  movq $-1, %rax")
  line("  jmp tp_return")
  line("tp_fits:")
  line("  movq %r11, " .. at("used"))
  -- }}}

  -- {{{ every byte unsayable until a token claims it
  -- Minus one rather than zero, because zero is a real token number and a map
  -- left zeroed would silently say that every byte in the alphabet is
  -- whatever token nought happens to be.
  line("  movq " .. at("byte_token") .. ", %rdi")
  line("  movl $256, %ecx")
  line("  movq $-1, %rax")
  line("tp_unsayable:")
  line("  movl %eax, (%rdi)")
  line("  addq $4, %rdi")
  line("  decq %rcx")
  line("  jnz tp_unsayable")
  -- }}}

  -- {{{ one walk that fills three of the four arrays
  --
  -- The byte map, the fenceposts and the packed text all come from the same
  -- traversal of the token table, so they are built together rather than in
  -- three passes. FIRST CLAIM WINS on the byte map, which is the reference's
  -- rule and not an accident of ordering: when two tokens say the same text
  -- the lower number is the trained one (`059`), and a later token silently
  -- overwriting an earlier one would encode text into numbers the model
  -- weights barely know.
  line("  movq %r14, %r9")                    -- the walker
  line("  xorl %r10d, %r10d")                 -- which token
  line("  xorl %r8d, %r8d")                   -- how far into the packed text
  line("tp_walk:")
  line("  cmpq %r12, %r10")
  line("  jge tp_walk_done")
  line("  movq " .. at("token_offsets") .. ", %rdi")
  line("  movl %r8d, (%rdi,%r10,4)")
  line("  movzbl (%r9), %ecx")                -- the length byte

  line("  cmpq $1, %rcx")
  line("  jne tp_not_one_byte")
  line("  movzbl 1(%r9), %edx")               -- the byte it says
  line("  movq " .. at("byte_token") .. ", %rdi")
  line("  cmpl $-1, (%rdi,%rdx,4)")
  line("  jne tp_not_one_byte")               -- already claimed, first wins
  line("  movl %r10d, (%rdi,%rdx,4)")
  line("tp_not_one_byte:")

  line("  movq " .. at("token_bytes") .. ", %rdi")
  line("  addq %r8, %rdi")
  line("  leaq 1(%r9), %rsi")
  line("  movq %rcx, %rax")                   -- the length, kept
  line("tp_copy:")
  line("  testq %rcx, %rcx")
  line("  jz tp_copy_done")
  line("  movzbl (%rsi), %edx")
  line("  movb %dl, (%rdi)")
  line("  incq %rsi")
  line("  incq %rdi")
  line("  decq %rcx")
  line("  jmp tp_copy")
  line("tp_copy_done:")
  line("  addq %rax, %r8")
  line("  leaq 1(%r9,%rax), %r9")
  line("  incq %r10")
  line("  jmp tp_walk")
  line("tp_walk_done:")
  -- the closing fencepost: decoding reads a token's length as the difference
  -- between its offset and the next one, so the last token needs a next one.
  line("  movq " .. at("token_offsets") .. ", %rdi")
  line("  movl %r8d, (%rdi,%r12,4)")
  -- }}}

  -- {{{ the merge rules, each resolved to what it produces
  line("  movq $0, " .. at("rule"))
  line("tp_rules:")
  line("  movq " .. at("rule") .. ", %r10")
  line("  cmpq %r13, %r10")
  line("  jge tp_rules_done")

  -- where the two named tokens' texts lie
  line("  movq %r10, %rax")
  line("  shlq $3, %rax")                     -- two numbers a rule
  line("  movl (%r15,%rax), %ecx")            -- the left token
  line("  movl 4(%r15,%rax), %edx")           -- the right token

  -- A RULE MAY NAME A TOKEN THAT DOES NOT EXIST, and it is checked here
  -- because everything after this point would read past the fenceposts. That
  -- does not fault: it produces an offset and a length made of whatever
  -- follows the array, and the comparison then walks that far into memory
  -- looking for a match it might even find. The host meets the same model and
  -- refuses it while joining two texts, one of which is missing.
  line("  cmpq %r12, %rcx")
  line("  jge tp_no_such_number")
  line("  cmpq %r12, %rdx")
  line("  jge tp_no_such_number")

  line("  movq " .. at("token_offsets") .. ", %rdi")
  line("  movl (%rdi,%rcx,4), %eax")
  line("  movq %rax, " .. at("off_left"))
  line("  movl 4(%rdi,%rcx,4), %eax")
  line("  subq " .. at("off_left") .. ", %rax")
  line("  movq %rax, " .. at("len_left"))
  line("  movl (%rdi,%rdx,4), %eax")
  line("  movq %rax, " .. at("off_right"))
  line("  movl 4(%rdi,%rdx,4), %eax")
  line("  subq " .. at("off_right") .. ", %rax")
  line("  movq %rax, " .. at("len_right"))

  -- and the walk that looks for the token saying both of them, in order, so
  -- that the first match is the lowest-numbered one -- the same tie the host
  -- takes by keeping the first entry it saw for a text.
  line("  xorl %r11d, %r11d")                 -- which token
  line("tp_search:")
  line("  cmpq %r12, %r11")
  line("  jge tp_no_such_token")
  line("  movq " .. at("token_offsets") .. ", %rdi")
  line("  movl (%rdi,%r11,4), %r8d")
  line("  movl 4(%rdi,%r11,4), %r9d")
  line("  subq %r8, %r9")                     -- how long this one is
  -- the length is checked before a single byte is, because it rejects almost
  -- every candidate and costs one comparison to do it
  line("  movq " .. at("len_left") .. ", %rax")
  line("  addq " .. at("len_right") .. ", %rax")
  line("  cmpq %rax, %r9")
  line("  jne tp_search_next")

  line("  movq " .. at("token_bytes") .. ", %rsi")
  line("  leaq (%rsi,%r8), %rdi")             -- the candidate's text
  line("  movq %rsi, %rax")
  line("  addq " .. at("off_left") .. ", %rax")
  line("  movq " .. at("len_left") .. ", %rcx")
  line("tp_match_left:")
  line("  testq %rcx, %rcx")
  line("  jz tp_match_left_done")
  line("  movzbl (%rdi), %edx")
  line("  cmpb %dl, (%rax)")
  line("  jne tp_search_next")
  line("  incq %rdi")
  line("  incq %rax")
  line("  decq %rcx")
  line("  jmp tp_match_left")
  line("tp_match_left_done:")
  line("  movq " .. at("token_bytes") .. ", %rax")
  line("  addq " .. at("off_right") .. ", %rax")
  line("  movq " .. at("len_right") .. ", %rcx")
  line("tp_match_right:")
  line("  testq %rcx, %rcx")
  line("  jz tp_found")
  line("  movzbl (%rdi), %edx")
  line("  cmpb %dl, (%rax)")
  line("  jne tp_search_next")
  line("  incq %rdi")
  line("  incq %rax")
  line("  decq %rcx")
  line("  jmp tp_match_right")

  line("tp_search_next:")
  line("  incq %r11")
  line("  jmp tp_search")

  line("tp_found:")
  line("  movq " .. at("rule") .. ", %r10")
  line("  movq %r10, %rax")
  line("  imulq $3, %rax")                    -- three numbers a prepared rule
  line("  movq " .. at("merge_rules") .. ", %rdi")
  line("  movq %r10, %rdx")
  line("  shlq $3, %rdx")
  line("  movl (%r15,%rdx), %ecx")
  line("  movl %ecx, (%rdi,%rax,4)")
  line("  movl 4(%r15,%rdx), %ecx")
  line("  movl %ecx, 4(%rdi,%rax,4)")
  line("  movl %r11d, 8(%rdi,%rax,4)")
  line("  incq %r10")
  line("  movq %r10, " .. at("rule"))
  line("  jmp tp_rules")

  -- A rule making a text no token holds is refused HERE rather than passed
  -- on, and it is worth being clear about what such a model is: not one that
  -- tokenizes slightly oddly, but one whose merge table and vocabulary came
  -- from different places. Encoding would apply the rule, produce a number no
  -- embedding row answers to, and the machine would think about nothing.
  line("tp_no_such_token:")
  line("  movq $-2, %r11")
  line("  jmp tp_blame_the_rule")
  line("tp_no_such_number:")
  line("  movq $-3, %r11")
  line("tp_blame_the_rule:")
  line("  movq " .. at("detail") .. ", %rcx")
  line("  testq %rcx, %rcx")
  line("  jz tp_no_such_quiet")
  line("  movq " .. at("rule") .. ", %rax")
  line("  movq %rax, (%rcx)")
  line("tp_no_such_quiet:")
  line("  movq %r11, %rax")
  line("  jmp tp_return")
  line("tp_rules_done:")
  -- }}}

  -- {{{ and the prepared table itself
  line("  movq " .. at("plan") .. ", %rdi")
  line("  movq " .. at("byte_token") .. ", %rax")
  line("  movq %rax, " .. slot.byte_token .. "(%rdi)")
  line("  movq " .. at("merge_rules") .. ", %rax")
  line("  movq %rax, " .. slot.merge_rules .. "(%rdi)")
  line("  movq %r13, " .. slot.merge_count .. "(%rdi)")
  line("  movq " .. at("token_offsets") .. ", %rax")
  line("  movq %rax, " .. slot.token_offsets .. "(%rdi)")
  line("  movq " .. at("token_bytes") .. ", %rax")
  line("  movq %rax, " .. slot.token_bytes .. "(%rdi)")
  line("  movq %r12, " .. slot.token_count .. "(%rdi)")
  line("  movq " .. at("used") .. ", %rax")
  -- }}}

  line("tp_return:")
  line("  addq $" .. FRAME_BYTES .. ", %rsp")
  line("  popq %r15")
  line("  popq %r14")
  line("  popq %r13")
  line("  popq %r12")
  line("  popq %rbp")
  line("  popq %rbx")
  line("  retq")
  line("")

  return table.concat(out, "\n")
end
-- }}}

return M
