#!/usr/bin/env luajit
-- 039-test-tokenizer.lua
--
-- Checks the tokenizer, mostly on the cases where implementations differ from
-- one another. That is deliberate: a tokenizer that is right about ordinary
-- English and wrong about a newline produces a model that seems mildly stupid
-- rather than one that visibly fails, and nobody suspects the right thing.
--
-- usage:
--   luajit 039-test-tokenizer.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

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

-- {{{ local function readable(text)
-- Show control characters and high bytes as escapes, so a failure report can
-- be read. A test whose output is invisible characters is a test nobody can
-- act on.
local function readable(text)
  return (text:gsub("[%c\128-\255]", function(character)
    return string.format("\\x%02x", character:byte())
  end))
end
-- }}}

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

local tokenizer = dofile(DIR .. "/src/038-reference-tokenizer.lua")

say("")
say("  text into numbers, and back")
say("  " .. string.rep("-", 58))
say("")

local passed, failed = 0, 0

-- {{{ local function check(what, ok, detail)
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
-- }}}

-- A vocabulary with the pieces that make merging happen, plus every byte
-- underneath so nothing is unsayable.
local tokens, merges = tokenizer.byte_vocabulary({
  "th", "he", "the", "in", "ing", "  ", "\r\n", "\xc3\xa9",
})
local vocabulary = tokenizer.load(tokens, merges)

check("every byte has a token of its own", vocabulary.count >= 256,
      "a vocabulary missing a byte has documents it cannot say")

-- {{{ the round trip, on awkward text
--
-- These are the cases implementations disagree about. Ordinary words are not
-- interesting; a tokenizer gets those right by accident.
local awkward = {
  ["plain english"] = "the thing in the box",
  ["an empty string"] = "",
  ["one character"] = "a",
  ["a newline"] = "line one\nline two",
  ["a carriage return and newline"] = "line one\r\nline two",
  ["runs of spaces"] = "a  b   c",
  ["a leading space"] = " leading",
  ["a trailing space"] = "trailing ",
  ["only spaces"] = "    ",
  ["a tab"] = "before\tafter",
  ["a byte above 127"] = "caf\xc3\xa9",
  ["every byte from 0 to 255"] = nil,   -- built below
  ["a null byte in the middle"] = "before\0after",
  ["text that is all one token"] = "the",
  ["repeated merges"] = "thethethe",
}

local every_byte = {}
for byte = 0, 255 do every_byte[#every_byte + 1] = string.char(byte) end
awkward["every byte from 0 to 255"] = table.concat(every_byte)

-- sorted, so the report reads the same every run
local names = {}
for name in pairs(awkward) do names[#names + 1] = name end
table.sort(names)

for _, name in ipairs(names) do
  local text = awkward[name]
  local numbers, complaint = tokenizer.encode(vocabulary, text)
  if not numbers then
    check("round trip: " .. name, false, "encoding refused: " .. tostring(complaint))
  else
    local back, decode_complaint = tokenizer.decode(vocabulary, numbers)
    if not back then
      check("round trip: " .. name, false, "decoding refused: " .. tostring(decode_complaint))
    else
      check("round trip: " .. name, back == text,
            "in  " .. readable(text) .. "\n      out " .. readable(back))
    end
  end
end
-- }}}

-- {{{ merging actually happens
-- A round trip passes perfectly if nothing merges at all -- every byte its own
-- token, decoded straight back. So the round trip alone cannot tell a working
-- tokenizer from one that does nothing, and this is the check that can.
local unmerged = tokenizer.encode(vocabulary, "the")
check("merging shortens what it can", unmerged and #unmerged < 3,
      unmerged and ("'the' became " .. #unmerged .. " tokens, expected fewer than 3"))

local nothing_to_merge = tokenizer.encode(vocabulary, "xqz")
check("text with no rule stays one token per byte",
      nothing_to_merge and #nothing_to_merge == 3)
-- }}}

-- {{{ the strongest rule wins
-- Order is the whole of this algorithm. Joining a weaker pair first can make a
-- stronger one impossible, and the result differs from what the model was
-- trained on -- which is exactly the failure that shows as mild stupidity
-- rather than as an error.
local ordered = tokenizer.load(
  { "a", "b", "c", "ab", "bc", "abc" },
  { { 1, 2 }, { 0, 3 } })   -- b+c ranks above a+ab

local result = tokenizer.encode(ordered, "abc")
local as_text = result and tokenizer.decode(ordered, result)
check("the strongest rule is applied first",
      result and #result == 2 and result[1] == 0 and result[2] == 4,
      result and ("got " .. #result .. " tokens: " .. table.concat(result, ", ")
                  .. " (" .. tostring(as_text) .. ")"))
-- }}}

-- {{{ refusals
local missing = tokenizer.load({ "a", "b" }, {})
local refused, why = tokenizer.encode(missing, "z")
check("refuses text it has no tokens for", refused == nil and why ~= nil,
      "silently dropping a byte misreads a document instead of complaining")

local bad_number, decode_why = tokenizer.decode(vocabulary, { 999999 })
check("refuses a token number it does not have",
      bad_number == nil and decode_why ~= nil)
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("tokenizer: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
