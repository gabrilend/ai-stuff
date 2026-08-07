#!/usr/bin/env luajit
-- 138-test-prepare-the-tokenizer.lua
--
-- The tokenizer's prepared table, built by the machine itself, held to the
-- one the host builds. Issue 107a.
--
-- For a general: on a development machine a page of ordinary code turns the
-- model's carried word-lists into the lookup tables the engine uses. On a bare
-- machine that page has to be assembly. This runs both against the same model
-- and requires the four tables to come out identical, byte for byte -- and
-- then encodes and decodes text through the machine-built one, because two
-- tables that differ in a slot nothing reads are not a defect and two that
-- differ in a slot something reads are.
--
-- WHY BOTH KINDS OF CHECK. Comparing the tables says WHICH slot is wrong.
-- Encoding through them says whether the thing works at all. A setup routine
-- wants both, for the reason `136` gives: one answers "does it work" and the
-- other answers "what is broken".
--
-- usage:
--   luajit 138-test-prepare-the-tokenizer.lua [--dir ROOT]

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
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

say("")
say("  the tokenizer's tables, built by the machine")
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

local preparer = dofile(DIR .. "/src/137-prepare-the-tokenizer.lua")
local tokenizer = dofile(DIR .. "/src/059-emit-tokenizer.lua")
local format = dofile(DIR .. "/src/024-blob-format.lua")

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/payloads")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

-- {{{ the model, and its two carried tables read straight out of it
--
-- Read here rather than taken from the description that packed it. The point
-- of this test is that two implementations agree about the same bytes, so
-- both of them start from the bytes.
local blob_path = DIR .. "/tmp/shared-memory/fixture/fixture-model.blob"
local blob = read_file(blob_path)
if not blob then
  run_one("luajit " .. DIR .. "/src/036-make-fixture.lua --dir " .. DIR
          .. " > /dev/null")
  blob = read_file(blob_path)
end
if not blob then
  say("  no fixture model, and it would not build")
  os.exit(1)
end

local header_at = preparer.header_offsets(format)
local function u32(text, at)
  local a, b, c, d = text:byte(at + 1, at + 4)
  return a + b * 256 + c * 65536 + d * 16777216
end
local function u64(text, at)
  return u32(text, at) + u32(text, at + 4) * 4294967296
end

local token_count = u32(blob, header_at.token_count)
local token_table_at = u64(blob, header_at.token_table)
local merge_count = u32(blob, header_at.merge_count)
local merge_table_at = u64(blob, header_at.merge_table)

local tokens, walker = {}, token_table_at
for slot = 1, token_count do
  local length = blob:byte(walker + 1)
  tokens[slot] = blob:sub(walker + 2, walker + 1 + length)
  walker = walker + 1 + length
end

local merges = {}
for rule = 1, merge_count do
  local at = merge_table_at + (rule - 1) * format.MERGE_ENTRY_BYTES
  merges[rule] = { u32(blob, at), u32(blob, at + 4) }
end

local text_bytes = 0
for _, one in ipairs(tokens) do text_bytes = text_bytes + #one end
-- }}}

-- {{{ the host's answer, which is the standard
--
-- This is the call that used to fail on this very model: the fixture carried
-- placeholder names and merge rules joining texts no token held, so the whole
-- section was well-formed and unusable. It is a real check, not a setup step.
--
-- The structures are declared before anything is built, because preparing
-- makes one and the declaration is what says how wide its slots are.
tokenizer.declare()
local ok_prepared, host = pcall(tokenizer.prepare, tokens, merges)
check("the model's own tables can be prepared at all",
      ok_prepared, not ok_prepared and tostring(host) or nil)
if not ok_prepared then
  say("")
  say("  nothing below this can run. The model carries a tokenizer table")
  say("  that no implementation could turn into a lookup.")
  os.exit(1)
end
-- }}}

-- {{{ the machine's answer
local source = DIR .. "/tmp/shared-memory/payloads/prepare-x86_64.s"
local library = DIR .. "/tmp/kernels/prepare-x86_64.so"
local handle = io.open(source, "w")
handle:write("  .text\n")
handle:write(preparer.x86_64(format, tokenizer))
handle:write("  .text\n")
handle:write(tokenizer.x86_64())
handle:write('  .section .note.GNU-stack,"",@progbits\n')
handle:close()

if not run_one("clang -shared -o " .. library .. " " .. source) then
  say("  the preparation would not build; see " .. source)
  os.exit(1)
end

ffi.cdef[[
  int64_t tokenizer_prepare(const uint8_t *blob, void *room, int64_t bytes,
                            TokenizerPlan *plan, int64_t *detail);
]]
local built = ffi.load(library)

local blob_bytes = ffi.new("uint8_t[?]", #blob)
ffi.copy(blob_bytes, blob, #blob)

local places, needed = preparer.expected(token_count, merge_count, text_bytes)
-- sixteen spare bytes at the front so the run of memory can be pushed onto a
-- boundary, the way a driver walking a bump pointer would have to.
local raw = ffi.new("uint8_t[?]", needed + 16)
local room = ffi.cast("uint8_t *", raw)
local misalignment = tonumber(ffi.cast("uintptr_t", room)) % 16
if misalignment ~= 0 then room = room + (16 - misalignment) end

local plan = ffi.new("TokenizerPlan")
local detail = ffi.new("int64_t[1]")
local used = tonumber(built.tokenizer_prepare(blob_bytes, room, needed,
                                              plan, detail))
check("the machine builds its tables from the model alone",
      used == needed,
      "used " .. used .. " where the host expects " .. needed)
-- }}}

-- {{{ the four tables, slot by slot
local host_plan = host.plan

local function compare_numbers(what, kind, mine, theirs, count)
  local a = ffi.cast(kind .. " *", mine)
  local b = ffi.cast(kind .. " *", theirs)
  local trouble = nil
  for slot = 0, count - 1 do
    if a[slot] ~= b[slot] then
      trouble = trouble or string.format("slot %d is %s and should be %s",
                                         slot, tostring(a[slot]),
                                         tostring(b[slot]))
    end
  end
  check(what, trouble == nil, trouble)
end

compare_numbers("and which token says each byte, all 256",
                "int32_t", plan.byte_token, host_plan.byte_token, 256)
compare_numbers("and what each merge rule produces",
                "uint32_t", plan.merge_rules, host_plan.merge_rules,
                merge_count * 3)
compare_numbers("and where every token's text begins and ends",
                "uint32_t", plan.token_offsets, host_plan.token_offsets,
                token_count + 1)
compare_numbers("and the packed text of the whole vocabulary",
                "uint8_t", plan.token_bytes, host_plan.token_bytes, text_bytes)

check("and it counts the same tokens and rules the model does",
      tonumber(plan.token_count) == token_count
      and tonumber(plan.merge_count) == merge_count,
      tonumber(plan.token_count) .. " tokens, "
      .. tonumber(plan.merge_count) .. " rules")

-- the arrays must not overlap, for the same reason `133` checks it: two that
-- do would not fault, they would quietly hold each other's contents.
local function span(base, bytes)
  local start = tonumber(ffi.cast("uintptr_t", base))
  return start, start + bytes
end
local spans = {
  { "byte_token", span(plan.byte_token, 256 * 4) },
  { "merge_rules", span(plan.merge_rules, merge_count * 3 * 4) },
  { "token_offsets", span(plan.token_offsets, (token_count + 1) * 4) },
  { "token_bytes", span(plan.token_bytes, text_bytes) },
}
local overlap = nil
for one = 1, #spans do
  for two = one + 1, #spans do
    local a_start, a_end = spans[one][2], spans[one][3]
    local b_start, b_end = spans[two][2], spans[two][3]
    if a_start < b_end and b_start < a_end then
      overlap = overlap or (spans[one][1] .. " runs into " .. spans[two][1])
    end
  end
end
check("and no two of the four sit on top of each other", overlap == nil, overlap)
-- }}}

-- {{{ text through the machine's tables, against text through the host's
--
-- The claim the slot comparison only approaches. Both plans are handed the
-- same text and must produce the same numbers -- including the two that come
-- from merge rules, which is the whole reason the fixture's vocabulary was
-- given tokens the rules actually make.
local trials = {
  { name = "a stretch the merge rules bite on",
    text = string.char(1, 2, 3, 4, 5, 1, 2) },
  { name = "one of every byte the vocabulary can say", text = nil },
  { name = "nothing at all", text = "" },
  { name = "a byte no token says", text = string.char(200) },
}
local every = {}
for byte = 0, token_count - 3 do every[#every + 1] = string.char(byte) end
trials[2].text = table.concat(every)

local function encode_with(which, text)
  local room_for_text = ffi.new("uint8_t[?]", math.max(#text, 1))
  ffi.copy(room_for_text, text, #text)
  local numbers = ffi.new("int32_t[?]", math.max(#text, 1))
  local answer = tonumber(built.tokenizer_encode(which, room_for_text,
                                                 #text, numbers))
  if answer < 0 then return answer, nil end
  local out = {}
  for slot = 0, answer - 1 do out[slot + 1] = numbers[slot] end
  return answer, out
end

local mismatched, merges_bit = nil, false
for _, trial in ipairs(trials) do
  local mine_count, mine = encode_with(plan, trial.text)
  local theirs_count, theirs = encode_with(host_plan, trial.text)
  if mine_count ~= theirs_count then
    mismatched = mismatched or (trial.name .. ": " .. mine_count
                                .. " against " .. theirs_count)
  elseif mine then
    for slot = 1, #mine do
      if mine[slot] ~= theirs[slot] then
        mismatched = mismatched or string.format(
          "%s: token %d is %d and should be %d", trial.name, slot,
          mine[slot], theirs[slot])
      end
      if mine[slot] >= token_count - 2 then merges_bit = true end
    end
  end
end
check("and text encodes to the same numbers through both",
      mismatched == nil, mismatched)
check("and the merge rules were actually reached",
      merges_bit,
      "no encoding produced a token that only a merge can make")

local spoken = { 46, 47, 5, 3 }
local packed = ffi.new("int32_t[?]", #spoken)
for slot = 1, #spoken do packed[slot - 1] = spoken[slot] end
local function decode_with(which)
  local room_for_text = ffi.new("uint8_t[?]", 256)
  local wrote = tonumber(built.tokenizer_decode(which, packed, #spoken,
                                                room_for_text))
  if wrote < 0 then return nil, wrote end
  return ffi.string(room_for_text, wrote)
end
local mine_text, mine_trouble = decode_with(plan)
local their_text = decode_with(host_plan)
check("and numbers decode to the same text through both",
      mine_text ~= nil and mine_text == their_text,
      mine_trouble and tostring(mine_trouble)
      or (string.format("%q against %q", tostring(mine_text),
                        tostring(their_text))))
-- }}}

-- {{{ the two refusals, which are the whole reason this is not a copy
--
-- A routine that only ever works on good input is a routine nobody has tested
-- the interesting half of. Both of these are cheap here and impossible to
-- notice later.
local short_detail = ffi.new("int64_t[1]")
local short_plan = ffi.new("TokenizerPlan")
local short_answer = tonumber(built.tokenizer_prepare(blob_bytes, room,
                                                      needed - 64, short_plan,
                                                      short_detail))
check("a machine short of room is refused",
      short_answer == -1, "returned " .. short_answer)
check("and told how many bytes it was short by",
      tonumber(short_detail[0]) == 64,
      "said " .. tonumber(short_detail[0]) .. " rather than 64")

-- a model whose first merge rule joins two tokens into a text nothing holds.
-- Rewritten in a copy of the real blob rather than invented, so everything
-- else about it is genuinely a model.
local doctored = blob:sub(1, merge_table_at)
  .. string.char(0, 0, 0, 0)                  -- the left token: nought
  .. string.char(0, 0, 0, 0)                  -- and the right: nought again
  .. blob:sub(merge_table_at + 9)
check("and the doctored model is otherwise the same size",
      #doctored == #blob, #doctored .. " against " .. #blob)

local doctored_bytes = ffi.new("uint8_t[?]", #doctored)
ffi.copy(doctored_bytes, doctored, #doctored)
local broken_detail = ffi.new("int64_t[1]")
local broken_plan = ffi.new("TokenizerPlan")
local broken = tonumber(built.tokenizer_prepare(doctored_bytes, room, needed,
                                                broken_plan, broken_detail))
check("a merge rule that makes nothing is refused",
      broken == -2, "returned " .. broken)
check("and the rule that does it is named",
      tonumber(broken_detail[0]) == 0,
      "said rule " .. tonumber(broken_detail[0]) .. " rather than 0")

-- and the host refuses the same model, so the two agree about what is wrong
-- rather than only about what is right.
local host_refused = not pcall(tokenizer.prepare, tokens,
                               { { 0, 0 }, merges[2] })
check("and the host refuses that model too",
      host_refused,
      "the host prepared a table the machine would not")

-- a rule naming a token past the end of the vocabulary. Distinct from the
-- above because everything after the name is read is an array walked past its
-- fenceposts -- which does not fault, it produces a length made of whatever
-- follows, and then compares that many bytes of unrelated memory.
local beyond = token_count + 40
local past_the_end = blob:sub(1, merge_table_at)
  .. string.char(beyond % 256, math.floor(beyond / 256) % 256, 0, 0)
  .. string.char(0, 0, 0, 0)
  .. blob:sub(merge_table_at + 9)
local past_bytes = ffi.new("uint8_t[?]", #past_the_end)
ffi.copy(past_bytes, past_the_end, #past_the_end)
local past_detail = ffi.new("int64_t[1]")
local past_plan = ffi.new("TokenizerPlan")
local past = tonumber(built.tokenizer_prepare(past_bytes, room, needed,
                                              past_plan, past_detail))
check("a merge rule naming a token that does not exist is refused",
      past == -3, "returned " .. past)
check("and it is told apart from a rule that makes nothing",
      past ~= broken,
      "both models come back as " .. past)
check("and the host refuses that one as well",
      not pcall(tokenizer.prepare, tokens, { { beyond, 0 }, merges[2] }),
      "the host prepared a table naming a token it does not have")
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this completes:")
say("    the last piece of setup that only existed on a development machine.")
say("    A bare machine can now turn the word-lists its model carries into")
say("    the lookup tables the engine encodes with, using no hash, no strings")
say("    and no memory but a run it was handed.")
say("")

os.exit(failed == 0 and 0 or 1)
-- }}}
