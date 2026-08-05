#!/usr/bin/env luajit
-- 127-test-tokenizer-elsewhere.lua
--
-- Text into the model's numbers and back, on the second and third machines,
-- held to the first over the corpus where tokenizers actually disagree.
-- Issue 403.
--
-- For a general: a machine that cannot turn text into numbers cannot read
-- the instruction it woke up holding. This checks that all three processors
-- turn the same text into the same numbers.
--
-- WHY THE AWKWARD CORPUS AND NOT A FEW WORDS. This routine has no floating
-- point in it and ports mechanically, which makes it look safe. Its failure
-- mode is a WRONG ANSWER THAT LOOKS FINE: a tokenizer that joins in a
-- slightly different order still produces numbers, and the machine then
-- reads a subtly different instruction and nothing faults. So the cases
-- carried are the ones where implementations genuinely differ -- runs of
-- spaces, a null byte in the middle, bytes above 127, text that is entirely
-- one token, and nothing at all.
--
-- usage:
--   luajit 127-test-tokenizer-elsewhere.lua [--dir ROOT] [--seconds N]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local ffi = require("ffi")

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

-- {{{ local function read_file(path)
local function read_file(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local text = handle:read("*a")
  handle:close()
  return text
end
-- }}}

-- {{{ main
local seconds = 90
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--seconds" then
    index = index + 1 ; seconds = tonumber(arg[index]) or 90
  end
  index = index + 1
end

say("")
say("  the same words into the same numbers, everywhere")
say("  " .. string.rep("-", 58))
say("")

local passed, failed = 0, 0
local function check(what, ok, detail)
  if ok then
    passed = passed + 1
    say(string.format("  %-50s ok", what))
  else
    failed = failed + 1
    say(string.format("  %-50s WRONG", what))
    if detail then say("      " .. detail) end
  end
end

local emit = dofile(DIR .. "/src/059-emit-tokenizer.lua")
local elsewhere = dofile(DIR .. "/src/126-tokenizer-elsewhere.lua")
local reference = dofile(DIR .. "/src/038-reference-tokenizer.lua")

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/payloads")

-- {{{ the vocabulary, and what the first architecture makes of the corpus
local extra = { "th", "the", "he", " t", "ab", "abc", "  ", "    ", "ing", "in" }
-- the structure has to be declared before one can be built, exactly as the
-- first architecture's own test does it
emit.declare()

local tokens, merges = reference.byte_vocabulary(extra)
local vocabulary = reference.load(tokens, merges)
local prepared = emit.prepare(tokens, merges)

-- The same corpus `060` uses, which is the point: three machines held to one
-- set of awkward cases rather than to three convenient ones.
local corpus = {
  { name = "plain english",              text = "the cat sat on the mat" },
  { name = "repeated merges",            text = "the theatre thereabouts" },
  { name = "runs of spaces",             text = "one  two    three     four" },
  { name = "a leading space",            text = " the" },
  { name = "only spaces",                text = "        " },
  { name = "a newline and a tab",        text = "line one\n\tline two" },
  { name = "a null byte in the middle",  text = "before\0after" },
  { name = "bytes above 127",            text = "caf\195\169 \226\152\131" },
  { name = "one character",              text = "x" },
  { name = "an empty string",            text = "" },
  { name = "text that is all one token", text = "abc" },
}

local expected = {}
local total_tokens = 0
for _, case in ipairs(corpus) do
  local numbers = reference.encode(vocabulary, case.text)
  if numbers == nil then
    say("  the reference refused '" .. case.name .. "', which it should not")
    os.exit(1)
  end
  expected[#expected + 1] = { name = case.name, text = case.text,
                              numbers = numbers }
  total_tokens = total_tokens + #numbers
end

check("the corpus encodes to something worth comparing",
      total_tokens > 100,
      total_tokens .. " numbers across " .. #corpus .. " cases")

-- a case where a join must enable a stronger rule, checked to be present
-- rather than hoped for: without one, the walk that restarts at the
-- strongest rule is never distinguished from one that does not.
local restarts = false
for _, case in ipairs(expected) do
  if #case.numbers < #case.text and #case.text > 3 then restarts = true end
end
check("and at least one case joins more than once", restarts,
      "a corpus where nothing merges twice would not tell a walk that "
      .. "restarts from one that does not")
-- }}}

-- {{{ what has to be carried: the prepared tables, as words
local at = emit.plan_offsets()
local plan = prepared.plan

local function words_from(pointer, count, width)
  local as_words = ffi.cast("const uint32_t *", pointer)
  local out = {}
  for place = 0, count - 1 do out[place + 1] = as_words[place] end
  return out
end

local byte_token_words = words_from(plan.byte_token, 256)
local merge_count = tonumber(plan.merge_count)
local merge_rule_words = words_from(plan.merge_rules, merge_count * 3)
local token_count = tonumber(plan.token_count)
local offset_words = words_from(plan.token_offsets, token_count + 1)

-- the token text, packed four bytes to a word, earliest byte lowest -- which
-- is the order both machines read memory in
local bytes_length = tonumber(
  ffi.cast("const uint32_t *", plan.token_offsets)[token_count])
local token_byte_pointer = ffi.cast("const uint8_t *", plan.token_bytes)
local token_byte_words = {}
for at_byte = 0, bytes_length - 1, 4 do
  local word = 0
  for step = 0, 3 do
    local byte = (at_byte + step < bytes_length)
      and token_byte_pointer[at_byte + step] or 0
    word = word + byte * (256 ^ step)
  end
  token_byte_words[#token_byte_words + 1] = word
end

-- the corpus itself, as bytes, one run after another
local text_words, text_at = {}, {}
local all_text = {}
for _, case in ipairs(expected) do
  text_at[#text_at + 1] = #table.concat(all_text)
  all_text[#all_text + 1] = case.text
end
local joined_text = table.concat(all_text)
for place = 0, #joined_text - 1, 4 do
  local word = 0
  for step = 0, 3 do
    local byte = joined_text:byte(place + step + 1) or 0
    word = word + byte * (256 ^ step)
  end
  text_words[#text_words + 1] = word
end
if #text_words == 0 then text_words = { 0 } end

-- and every expected number, laid end to end
local want_words, want_at = {}, {}
for _, case in ipairs(expected) do
  want_at[#want_at + 1] = #want_words
  for _, number in ipairs(case.numbers) do
    want_words[#want_words + 1] = number
  end
end
-- }}}

-- {{{ what both payloads do, described once
--
-- Build the plan on the stack with the real addresses of the five carried
-- tables, then for each case: encode its run of text, and compare the count
-- and every number against what the first architecture produced. Then decode
-- what was just encoded and require the original bytes back.
--
-- The decode half matters as much as the encode half and is easy to skip: a
-- tokenizer whose two halves are wrong in matching ways round-trips
-- perfectly and says something else entirely.
local WORK = {
  plan = 0, tokens_out = 64, text_out = 4096, hex = 8192,
  total = 12288,
}
-- }}}

-- {{{ the second architecture
local function aarch64_payload()
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .text")
  line("  .globl _start")
  line("_start:")
  line("  b start_here")
  line((elsewhere.aarch64(emit)
        :gsub("%s*%.globl%s+[%w_]+%s*\n", "\n")
        :gsub("%s*%.type%s+[%w_]+%s*,%s*@function%s*\n", "\n")))

  line("start_here:")
  line("  sub sp, sp, #" .. WORK.total)
  line("  mov x19, x1")
  line("  ldr x20, [x19, #64]")
  line("  mov x21, sp")
  line("  mov x22, xzr")                    -- numbers matched
  line("  mov x23, xzr")                    -- numbers compared
  line("  mov x24, xzr")                    -- bytes matched on the way back
  line("  mov x25, xzr")                    -- bytes compared

  local said = 0
  local function say_text(text)
    said = said + 1
    local skip, label = "tkskip" .. said, "tktext" .. said
    line("  b " .. skip)
    line(label .. ":")
    for at_char = 1, #text do line("  .short " .. text:byte(at_char)) end
    line("  .short 0")
    line("  .balign 4")
    line(skip .. ":")
    line("  adr x1, " .. label)
    line("  mov x0, x20")
    line("  ldr x8, [x20, #8]")
    line("  blr x8")
  end
  local function say_hex(register)
    said = said + 1
    local loop, digit, done = "tkh" .. said, "tkd" .. said, "tke" .. said
    line("  mov x9, " .. register)
    line("  add x10, x21, #" .. WORK.hex)
    line("  mov w11, #16")
    line(loop .. ":")
    line("  lsr x12, x9, #60")
    line("  lsl x9, x9, #4")
    line("  cmp w12, #10")
    line("  b.lt " .. digit)
    line("  add w12, w12, #87")
    line("  b " .. done)
    line(digit .. ":")
    line("  add w12, w12, #48")
    line(done .. ":")
    line("  strh w12, [x10], #2")
    line("  subs w11, w11, #1")
    line("  b.ne " .. loop)
    line("  strh wzr, [x10]")
    line("  add x1, x21, #" .. WORK.hex)
    line("  mov x0, x20")
    line("  ldr x8, [x20, #8]")
    line("  blr x8")
  end

  say_text("\r\ntokenizing, second tongue\r\n")

  line("  b tkdata_done")
  local function lay(label, words)
    line("  .balign 16")
    line(label .. ":")
    local row = {}
    for at_word, word in ipairs(words) do
      row[#row + 1] = string.format("0x%08x", word)
      if #row == 8 or at_word == #words then
        line("  .word " .. table.concat(row, ", "))
        row = {}
      end
    end
  end
  lay("tkbyte", byte_token_words)
  lay("tkrules", merge_rule_words)
  lay("tkoffsets", offset_words)
  lay("tkbytes", token_byte_words)
  lay("tktext", text_words)
  lay("tkwant", want_words)
  line("tkdata_done:")

  -- the plan, on the stack
  line("  mov x0, x21")
  line("  adr x9, tkbyte")
  line("  str x9, [x0, #" .. at.byte_token .. "]")
  line("  adr x9, tkrules")
  line("  str x9, [x0, #" .. at.merge_rules .. "]")
  line("  movz x9, #" .. merge_count)
  line("  str x9, [x0, #" .. at.merge_count .. "]")
  line("  adr x9, tkoffsets")
  line("  str x9, [x0, #" .. at.token_offsets .. "]")
  line("  adr x9, tkbytes")
  line("  str x9, [x0, #" .. at.token_bytes .. "]")
  line("  movz x9, #" .. token_count)
  line("  str x9, [x0, #" .. at.token_count .. "]")

  for case_index, case in ipairs(expected) do
    say_text(".")
    -- encode this case's run of text
    line("  mov x0, x21")
    line("  adr x1, tktext")
    line("  movz x9, #" .. text_at[case_index])
    line("  add x1, x1, x9")
    line("  movz x2, #" .. #case.text)
    line("  add x3, x21, #" .. WORK.tokens_out)
    line("  bl tokenizer_encode")
    line("  mov x26, x0")                   -- how many it said

    -- the count, then every number
    line("  movz x9, #" .. #case.numbers)
    line("  add x23, x23, #1")
    line("  cmp x26, x9")
    line("  b.ne tkcount" .. case_index)
    line("  add x22, x22, #1")
    line("tkcount" .. case_index .. ":")

    if #case.numbers > 0 then
      line("  add x5, x21, #" .. WORK.tokens_out)
      line("  adr x6, tkwant")
      line("  movz x9, #" .. (want_at[case_index] * 4))
      line("  add x6, x6, x9")
      line("  movz x7, #" .. #case.numbers)
      line("tknum" .. case_index .. ":")
      line("  ldr w8, [x5], #4")
      line("  ldr w9, [x6], #4")
      line("  add x23, x23, #1")
      line("  cmp w8, w9")
      line("  b.ne tknumno" .. case_index)
      line("  add x22, x22, #1")
      line("tknumno" .. case_index .. ":")
      line("  subs x7, x7, #1")
      line("  b.ne tknum" .. case_index)

      -- and back again: the numbers must decode to the original bytes
      line("  mov x0, x21")
      line("  add x1, x21, #" .. WORK.tokens_out)
      line("  mov x2, x26")
      line("  add x3, x21, #" .. WORK.text_out)
      line("  bl tokenizer_decode")
      line("  mov x27, x0")                 -- how many bytes came back

      line("  movz x9, #" .. #case.text)
      line("  add x25, x25, #1")
      line("  cmp x27, x9")
      line("  b.ne tkback" .. case_index)
      line("  add x24, x24, #1")
      line("tkback" .. case_index .. ":")

      line("  add x5, x21, #" .. WORK.text_out)
      line("  adr x6, tktext")
      line("  movz x9, #" .. text_at[case_index])
      line("  add x6, x6, x9")
      line("  movz x7, #" .. #case.text)
      line("tkbyte" .. case_index .. ":")
      line("  ldrb w8, [x5], #1")
      line("  ldrb w9, [x6], #1")
      line("  add x25, x25, #1")
      line("  cmp w8, w9")
      line("  b.ne tkbyteno" .. case_index)
      line("  add x24, x24, #1")
      line("tkbyteno" .. case_index .. ":")
      line("  subs x7, x7, #1")
      line("  b.ne tkbyte" .. case_index)
    end
  end

  say_text("tokenizer checked\r\n  numbers ")
  say_hex("x22")
  say_text("\r\n  of ")
  say_hex("x23")
  say_text("\r\n  bytes ")
  say_hex("x24")
  say_text("\r\n  bof ")
  say_hex("x25")
  say_text("\r\n")

  line("tkhalt:")
  line("  wfi")
  line("  b tkhalt")
  return table.concat(out, "\n")
end

local base = DIR .. "/tmp/shared-memory/payloads/tokenizer-aarch64"
local handle = io.open(base .. ".s", "w")
handle:write(aarch64_payload())
handle:close()

if not run_one("clang --target=aarch64-unknown-none -c " .. base .. ".s -o "
               .. base .. ".o") then
  check("the second architecture's tokenizer assembles", false,
        "see " .. base .. ".s")
else
  check("the second architecture's tokenizer assembles", true)
  run_one("llvm-objcopy -O binary " .. base .. ".o " .. base .. ".raw")
  run_one("luajit " .. DIR .. "/src/029-wrap-uefi.lua --from " .. base
          .. ".raw --to " .. base .. ".efi --arch aarch64 > /dev/null")

  local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-arm64-serial.log"
  run_one("rm -f " .. serial)
  run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-arm64"
    .. " --payload " .. base .. ".efi --seconds " .. seconds
    .. " --dir " .. DIR .. " > /dev/null 2>&1")

  local spoken = read_file(serial) or ""
  local report = spoken:match("tokenizer checked(.*)$") or ""
  local function after(mark)
    return tonumber(report:match("[\r\n]%s*" .. mark .. "%s+(%x+)") or "", 16)
  end
  local numbers, of = after("numbers"), after("of")
  local bytes_back, bof = after("bytes"), after("bof")

  check("and turns the corpus into the same numbers",
        numbers ~= nil and of ~= nil and numbers == of and of > 0,
        tostring(numbers) .. " of " .. tostring(of) .. "; see " .. serial)
  check("and turns them back into the same text",
        bytes_back ~= nil and bof ~= nil and bytes_back == bof and bof > 0,
        tostring(bytes_back) .. " of " .. tostring(bof))
end
-- }}}

-- {{{ the third architecture
local function riscv64_payload()
  local words = dofile(DIR .. "/src/054-riscv-words.lua")
  local p = words.new()

  local strings, string_order = {}, {}
  local function pooled(text)
    if not strings[text] then
      strings[text] = "tkstring" .. (#string_order + 1)
      string_order[#string_order + 1] = text
    end
    return strings[text]
  end
  local function say_text(text)
    p:address("a1", pooled(text), "s1")
    p:op("mv a0, s4")
    p:op("ld t1, 8(s4)")
    p:op("jalr ra, 0(t1)")
  end
  local converted = 0
  local function say_hex(register)
    converted = converted + 1
    local loop = "tkhex" .. converted
    p:op("mv t0, " .. register)
    p:load_constant("t1", WORK.hex)
    p:op("add t1, s2, t1")
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
    p:load_constant("a1", WORK.hex)
    p:op("add a1, s2, a1")
    p:op("mv a0, s4")
    p:op("ld t1, 8(s4)")
    p:op("jalr ra, 0(t1)")
  end

  p:op("auipc s1, 0")
  p:op("mv s3, a1")
  p:op("ld s4, 64(s3)")
  p:load_constant("t0", WORK.total)
  p:op("sub sp, sp, t0")
  p:op("mv s2, sp")                         -- everything writable, from here
  p:op("mv s5, zero")                       -- numbers matched
  p:op("mv s6, zero")                       -- numbers compared
  p:op("mv s7, zero")                       -- bytes matched on the way back
  p:op("mv s8, zero")                       -- bytes compared

  say_text("\r\ntokenizing, third tongue\r\n")

  -- the plan, on the stack
  p:op("mv a0, s2")
  p:address("t0", "tkbyte", "s1")
  p:op("sd t0, " .. at.byte_token .. "(a0)")
  p:address("t0", "tkrules", "s1")
  p:op("sd t0, " .. at.merge_rules .. "(a0)")
  p:load_constant("t0", merge_count)
  p:op("sd t0, " .. at.merge_count .. "(a0)")
  p:address("t0", "tkoffsets", "s1")
  p:op("sd t0, " .. at.token_offsets .. "(a0)")
  p:address("t0", "tkbytes", "s1")
  p:op("sd t0, " .. at.token_bytes .. "(a0)")
  p:load_constant("t0", token_count)
  p:op("sd t0, " .. at.token_count .. "(a0)")

  for case_index, case in ipairs(expected) do
    say_text(".")
    p:op("mv a0, s2")
    p:address("a1", "tktext", "s1")
    p:load_constant("t0", text_at[case_index])
    p:op("add a1, a1, t0")
    p:load_constant("a2", #case.text)
    p:load_constant("a3", WORK.tokens_out)
    p:op("add a3, s2, a3")
    p:call("tokenizer_encode")
    p:op("mv s9, a0")                       -- how many it said

    p:load_constant("t0", #case.numbers)
    p:op("addi s6, s6, 1")
    p:branch("bne", "s9", "t0", "tkcount" .. case_index)
    p:op("addi s5, s5, 1")
    p:label("tkcount" .. case_index)

    if #case.numbers > 0 then
      p:load_constant("t0", WORK.tokens_out)
      p:op("add t0, s2, t0")
      p:address("t1", "tkwant", "s1")
      p:load_constant("t2", want_at[case_index] * 4)
      p:op("add t1, t1, t2")
      p:load_constant("t2", #case.numbers)
      p:label("tknum" .. case_index)
      p:op("lwu t3, 0(t0)")
      p:op("lwu t4, 0(t1)")
      p:op("addi s6, s6, 1")
      p:branch("bne", "t3", "t4", "tknumno" .. case_index)
      p:op("addi s5, s5, 1")
      p:label("tknumno" .. case_index)
      p:op("addi t0, t0, 4")
      p:op("addi t1, t1, 4")
      p:op("addi t2, t2, -1")
      p:branch("bne", "t2", "zero", "tknum" .. case_index)

      -- and back again
      p:op("mv a0, s2")
      p:load_constant("a1", WORK.tokens_out)
      p:op("add a1, s2, a1")
      p:op("mv a2, s9")
      p:load_constant("a3", WORK.text_out)
      p:op("add a3, s2, a3")
      p:call("tokenizer_decode")
      p:op("mv s10, a0")

      p:load_constant("t0", #case.text)
      p:op("addi s8, s8, 1")
      p:branch("bne", "s10", "t0", "tkback" .. case_index)
      p:op("addi s7, s7, 1")
      p:label("tkback" .. case_index)

      p:load_constant("t0", WORK.text_out)
      p:op("add t0, s2, t0")
      p:address("t1", "tktext", "s1")
      p:load_constant("t2", text_at[case_index])
      p:op("add t1, t1, t2")
      p:load_constant("t2", #case.text)
      p:label("tkbyte" .. case_index)
      p:op("lbu t3, 0(t0)")
      p:op("lbu t4, 0(t1)")
      p:op("addi s8, s8, 1")
      p:branch("bne", "t3", "t4", "tkbyteno" .. case_index)
      p:op("addi s7, s7, 1")
      p:label("tkbyteno" .. case_index)
      p:op("addi t0, t0, 1")
      p:op("addi t1, t1, 1")
      p:op("addi t2, t2, -1")
      p:branch("bne", "t2", "zero", "tkbyte" .. case_index)
    end
  end

  say_text("tokenizer checked\r\n  numbers ")
  say_hex("s5")
  say_text("\r\n  of ")
  say_hex("s6")
  say_text("\r\n  bytes ")
  say_hex("s7")
  say_text("\r\n  bof ")
  say_hex("s8")
  say_text("\r\n")

  p:label("tkhalt")
  p:op("wfi")
  p:jump("tkhalt")

  elsewhere.riscv64(p, emit)

  for _, pair in ipairs({ { "tkbyte", byte_token_words },
                          { "tkrules", merge_rule_words },
                          { "tkoffsets", offset_words },
                          { "tkbytes", token_byte_words },
                          { "tktext", text_words },
                          { "tkwant", want_words } }) do
    p:align(16)
    p:label(pair[1])
    for _, word in ipairs(pair[2]) do p:word(word) end
  end
  for _, text in ipairs(string_order) do
    p:align(4)
    p:label(strings[text])
    p:shorts(text)
  end

  local text = p:resolve()
  return text
end

local rv_base = DIR .. "/tmp/shared-memory/payloads/tokenizer-riscv64"
handle = io.open(rv_base .. ".s", "w")
handle:write(riscv64_payload())
handle:close()

if not run_one("clang --target=riscv64-unknown-none -march=rv64imafd -c "
               .. rv_base .. ".s -o " .. rv_base .. ".o") then
  check("the third architecture's tokenizer assembles", false,
        "see " .. rv_base .. ".s")
else
  check("the third architecture's tokenizer assembles", true)

  local relocations = io.popen("llvm-readelf -r " .. rv_base .. ".o 2>&1")
  local relocation_text = relocations and relocations:read("*a") or ""
  if relocations then relocations:close() end
  check("and nothing in it is waiting on a linker",
        relocation_text:find("There are no relocations", 1, true) ~= nil,
        "a relocation left behind becomes a branch to itself, silently")

  run_one("llvm-objcopy -O binary " .. rv_base .. ".o " .. rv_base .. ".raw")
  run_one("luajit " .. DIR .. "/src/029-wrap-uefi.lua --from " .. rv_base
          .. ".raw --to " .. rv_base .. ".efi --arch riscv64 > /dev/null")

  local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-riscv64-serial.log"
  run_one("rm -f " .. serial)
  run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-riscv64"
    .. " --payload " .. rv_base .. ".efi --seconds " .. seconds
    .. " --dir " .. DIR .. " > /dev/null 2>&1")

  local spoken = read_file(serial) or ""
  local report = spoken:match("tokenizer checked(.*)$") or ""
  local function after(mark)
    return tonumber(report:match("[\r\n]%s*" .. mark .. "%s+(%x+)") or "", 16)
  end
  local numbers, of = after("numbers"), after("of")
  local bytes_back, bof = after("bytes"), after("bof")

  check("and turns the corpus into the same numbers",
        numbers ~= nil and of ~= nil and numbers == of and of > 0,
        tostring(numbers) .. " of " .. tostring(of) .. "; see " .. serial)
  check("and turns them back into the same text",
        bytes_back ~= nil and bof ~= nil and bytes_back == bof and bof > 0,
        tostring(bytes_back) .. " of " .. tostring(bof))
end
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this adds:")
say("    all three architectures can now be told something. Before this, two")
say("    of them could think and could not read the instruction they woke up")
say("    holding, because that instruction is text.")
say("")
say("    written for both at once rather than one and then the other, which")
say("    is what 403 asks for and what this routine most needed: it has no")
say("    floating point in it, so it looks safe to port later -- and its")
say("    failure is a wrong answer that looks fine, because a tokenizer that")
say("    joins in a different order still produces numbers.")
say("")
say("  what is still missing:")
say("    the console on both. That is what a failing machine uses to say why")
say("    it stopped, and until it exists a machine that stops on either of")
say("    these two says nothing at all.")
say("")

os.exit(failed == 0 and 0 or 1)
-- }}}
