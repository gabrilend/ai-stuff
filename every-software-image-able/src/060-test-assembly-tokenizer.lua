#!/usr/bin/env luajit
-- 060-test-assembly-tokenizer.lua
--
-- Runs the readable tokenizer (038) and the assembly tokenizer (059) over
-- the same awkward corpus and requires the same numbers, the same text back,
-- and refusals at the same places.
--
-- For a general: a subtly wrong tokenizer is the worst failure available --
-- the machine just seems mildly stupid, and nobody suspects the right thing.
-- So the assembly half is not tested for reasonableness; it is tested for
-- exact agreement with the readable half, on the cases where tokenizers
-- actually disagree with each other.
--
-- usage:
--   luajit 060-test-assembly-tokenizer.lua [--dir ROOT]

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

-- {{{ local function host_architecture()
local function host_architecture()
  local pipe = io.popen("uname -m")
  local name = pipe and pipe:read("*l") or "unknown"
  if pipe then pipe:close() end
  return name
end
-- }}}

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

local arch = host_architecture()

say("")
say("  the same words into the same numbers, twice over")
say("  " .. string.rep("-", 58))
say("")

local emit = dofile(DIR .. "/src/059-emit-tokenizer.lua")
if not emit[arch] then
  say("  no tokenizer assembly for " .. arch .. ". Nothing was tested, which")
  say("  is not the same as nothing being wrong.")
  os.exit(1)
end

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/kernels")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

local source = DIR .. "/tmp/shared-memory/kernels/tokenizer-" .. arch .. ".s"
local library = DIR .. "/tmp/kernels/tokenizer-" .. arch .. ".so"
local handle = io.open(source, "w")
handle:write(emit[arch]())
handle:write('  .section .note.GNU-stack,"",@progbits\n')
handle:close()
if not run_one("clang -shared -o " .. library .. " " .. source) then
  say("  the tokenizer would not assemble")
  os.exit(1)
end

emit.declare()
local assembly = ffi.load(library)
local reference = dofile(DIR .. "/src/038-reference-tokenizer.lua")

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

-- {{{ the vocabulary both sides read
-- Byte-complete, with pieces that overlap so rule order matters: "the"
-- can only form if "th" formed first, and a wrong rule order forms "he"
-- instead. The same construction 039 leans on.
local extra = { "th", "the", "he", " t", "ab", "abc", "  ", "    ", "ing", "in" }
local tokens, merges = reference.byte_vocabulary(extra)
local vocabulary = reference.load(tokens, merges)
local prepared = emit.prepare(tokens, merges)
-- }}}

-- {{{ local function both_encode(text)
local function both_encode(text)
  local ref_tokens, ref_refusal = reference.encode(vocabulary, text)

  local capacity = math.max(#text, 1)
  local text_bytes = ffi.new("uint8_t[?]", capacity)
  ffi.copy(text_bytes, text, #text)
  local tokens_out = ffi.new("int32_t[?]", capacity)
  local answer = tonumber(assembly.tokenizer_encode(prepared.plan, text_bytes,
                                                    #text, tokens_out))
  return ref_tokens, ref_refusal, answer, tokens_out
end
-- }}}

-- {{{ the corpus of awkward cases, encoded identically
local corpus = {
  { name = "plain english",              text = "the cat sat on the mat" },
  { name = "repeated merges",            text = "the theatre thereabouts" },
  { name = "runs of spaces",             text = "one  two    three     four" },
  { name = "a leading space",            text = " the" },
  { name = "a trailing space",           text = "the " },
  { name = "only spaces",                text = "        " },
  { name = "a newline and a tab",        text = "line one\n\tline two" },
  { name = "a carriage return pair",     text = "line one\r\nline two" },
  { name = "a null byte in the middle",  text = "before\0after" },
  { name = "bytes above 127",            text = "caf\195\169 \226\152\131" },
  { name = "one character",              text = "x" },
  { name = "an empty string",            text = "" },
  { name = "text that is all one token", text = "abc" },
}

local all_bytes = {}
for byte = 0, 255 do all_bytes[#all_bytes + 1] = string.char(byte) end
corpus[#corpus + 1] = { name = "every byte from 0 to 255",
                        text = table.concat(all_bytes) }

local long_parts = {}
for _ = 1, 64 do long_parts[#long_parts + 1] = "the theatre is abc thing " end
corpus[#corpus + 1] = { name = "a long stretch of prose",
                        text = table.concat(long_parts) }

for _, case in ipairs(corpus) do
  local ref_tokens, refusal, answer, tokens_out = both_encode(case.text)
  local agree = ref_tokens ~= nil and answer == #ref_tokens
  if agree then
    for position = 1, #ref_tokens do
      if ref_tokens[position] ~= tokens_out[position - 1] then agree = false end
    end
  end

  -- and the assembly's own way back must give the bytes that went in.
  local round_trip = false
  if agree then
    local text_back = ffi.new("uint8_t[?]", math.max(#case.text, 1))
    local wrote = tonumber(assembly.tokenizer_decode(prepared.plan, tokens_out,
                                                     answer, text_back))
    round_trip = wrote == #case.text
      and ffi.string(text_back, math.max(wrote, 0)) == case.text
  end

  check("agrees on " .. case.name, agree and round_trip,
        refusal or (not agree and "the numbers differ")
        or "the numbers match but the way back does not")
end
-- }}}

-- {{{ refusals land in the same place
local short_tokens = {}
for byte = 0, 255 do
  if byte ~= 200 then short_tokens[#short_tokens + 1] = string.char(byte) end
end
local short_vocabulary = reference.load(short_tokens, {})
local short_prepared = emit.prepare(short_tokens, {})

local refused_text = "fine until \200 arrives"
local ref_refused, ref_reason = reference.encode(short_vocabulary, refused_text)
local refused_bytes = ffi.new("uint8_t[?]", #refused_text)
ffi.copy(refused_bytes, refused_text, #refused_text)
local refused_out = ffi.new("int32_t[?]", #refused_text)
local refused_answer = tonumber(assembly.tokenizer_encode(short_prepared.plan,
                                refused_bytes, #refused_text, refused_out))
-- the readable side names a one-based position; the assembly says minus the
-- zero-based position, minus one. Both must point at the same byte.
local ref_position = ref_reason and tonumber(ref_reason:match("position (%d+)"))
check("an unsayable byte is refused at the same place",
      ref_refused == nil and refused_answer < 0
      and ref_position == -refused_answer,
      string.format("readable says %s, assembly says %s",
                    tostring(ref_position), tostring(refused_answer)))

local bad_numbers = ffi.new("int32_t[3]", { 1, 2, 100000 })
local scratch = ffi.new("uint8_t[64]")
local bad_answer = tonumber(assembly.tokenizer_decode(prepared.plan,
                            bad_numbers, 3, scratch))
check("an unknown token number is refused, by position",
      bad_answer == -3,
      "expected minus three, got " .. tostring(bad_answer))
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not prove:")
say("    - the other two architectures (401).")
say("    - speed. The merge walk is deliberately the naive one -- correct")
say("      first -- and 106 is where its cost gets measured.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("assembly tokenizer: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
