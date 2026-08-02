#!/usr/bin/env luajit
-- 067-test-the-reader.lua
--
-- Checks that something too big to hold can be read: cut on meaningful
-- boundaries, walked a window at a time, and returned as a few valuable
-- pieces that say where they came from -- with the machine's own judgement
-- doing the deciding rather than the reader.
--
-- usage:
--   luajit 067-test-the-reader.lua [--dir ROOT]

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

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

say("")
say("  reading something too big to hold")
say("  " .. string.rep("-", 58))
say("")

local reader_module = dofile(DIR .. "/src/066-the-reader.lua")
local hands = dofile(DIR .. "/src/064-the-hands.lua")

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

-- {{{ a document with the answer buried in a known place
-- Records with blank lines between, so there are real boundaries to cut on
-- and a known place the answer sits.
local records = {}
for number = 1, 400 do
  records[#records + 1] = "record " .. number
    .. "\n  a line of ordinary detail about record " .. number
    .. "\n  and a second line of the same"
end
records[137] = "record 137\n  THE THING WANTED lives here\n  and nothing else does"
local document = table.concat(records, "\n\n")
-- }}}

-- {{{ chunking cuts where it should
local chunks = reader_module.chunk(document, 400)
local rejoined = table.concat(chunks)
check("chunking loses nothing", rejoined == document,
      "the pieces do not add back up to the whole")

local sizes_sane = true
for _, chunk in ipairs(chunks) do
  if #chunk > 400 then sizes_sane = false end
end
check("no piece is larger than it was asked to be", sizes_sane)

local cut_well = 0
for index = 1, #chunks - 1 do
  local ends_with = chunks[index]:sub(-1)
  if ends_with == "\n" or ends_with == " " then cut_well = cut_well + 1 end
end
check("nearly every cut lands on a boundary",
      cut_well >= (#chunks - 1) * 0.9,
      cut_well .. " of " .. (#chunks - 1) .. " cuts were clean")

-- content with no boundary anywhere is cut at the byte, which is right
-- rather than a failure: there is nothing meaningful to cut on.
local unbroken = string.rep("x", 1000)
local unbroken_chunks = reader_module.chunk(unbroken, 128)
check("content with no boundaries is still cut, and loses nothing",
      table.concat(unbroken_chunks) == unbroken and #unbroken_chunks == 8,
      #unbroken_chunks .. " pieces")

check("something shorter than one piece is one piece",
      #reader_module.chunk("short", 400) == 1)
-- }}}

-- {{{ reading it: the machine's judgement decides, not the reader
local windows_seen = 0
local reader = reader_module.new({
  context = 4000,
  ask = function(question, window, numbers)
    windows_seen = windows_seen + 1
    local pages = nil
    local found = false
    for index, page in ipairs(window) do
      if page:find("THE THING WANTED", 1, true) then
        found = true
        pages = pages or {}
        pages[index] = true
      end
    end
    return { found = found, pages = pages }
  end,
})

local found, why = reader_module.read(reader, document, "where is the thing wanted")
check("the answer is found in a document far too large",
      found ~= nil and found.text:find("THE THING WANTED", 1, true) ~= nil, why)

-- the claim is a ratio, not a size: what crosses must be a small fraction
-- of what was read, whatever the document happens to weigh.
check("and only the useful part crosses",
      found ~= nil and #found.text < #document / 50,
      found and (#found.text .. " characters out of " .. #document))

check("and it says which piece of how many it was",
      found ~= nil and #found.from_chunks == 1 and found.of_chunks == #chunks,
      found and ("piece " .. tostring(found.from_chunks[1]) .. " of " .. found.of_chunks))

check("the whole thing was covered in a predictable number of passes",
      found ~= nil and found.passes == math.ceil(#chunks / reader.resident)
      and windows_seen == found.passes,
      found and (found.passes .. " passes over " .. #chunks .. " pieces"))
-- }}}

-- {{{ an honest empty answer
local absent = reader_module.new({
  context = 4000,
  ask = function() return { found = false } end,
})
local nothing, absent_reason = reader_module.read(absent, document, "something not in it")
check("a document that does not answer says so, having read it all",
      nothing == nil and absent_reason:find("none of it answered") ~= nil,
      absent_reason)

local unjudged = reader_module.new({ context = 4000 })
local no_judge, judge_reason = reader_module.read(unjudged, document, "anything")
check("a reader with nothing to judge with refuses",
      no_judge == nil and judge_reason:find("judge") ~= nil, judge_reason)
-- }}}

-- {{{ an answer spanning several pieces is summarised, and says so
local spread = {}
for number = 1, 300 do
  spread[#spread + 1] = "line " .. number .. " mentioning the thing wanted"
end
local everywhere = table.concat(spread, "\n\n")

local summarising = reader_module.new({
  context = 4000,
  ask = function() return { found = true } end,
  summarise = function(question, pages)
    return "the thing wanted appears in all " .. #pages .. " pieces kept"
  end,
})
local spanning = reader_module.read(summarising, everywhere, "where is it")
check("an answer spanning pieces is summarised",
      spanning ~= nil and spanning.summarised and #spanning.from_chunks > 1,
      spanning and tostring(#spanning.from_chunks))

local atom = reader_module.as_atom(spanning, "the long thing")
check("and the summary is labelled a summary, not a quotation",
      atom.content:find("not a quotation", 1, true) ~= nil, atom.content:sub(1, 80))
check("and the atom names where it came from",
      atom.derived_from[1] == "the long thing"
      and atom.topic:find("the long thing", 1, true) ~= nil)

local single_atom = reader_module.as_atom(found, "the records")
check("a single piece is labelled a piece, not a summary",
      single_atom.content:find("^piece ") ~= nil,
      single_atom.content:sub(1, 60))
-- }}}

-- {{{ a widened search carries findings forward
local widened_question = nil
local widening = reader_module.new({
  context = 4000,
  resident = 8,
  ask = function(question, window)
    if question:find("wider") then widened_question = question end
    for _, page in ipairs(window) do
      if page:find("THE THING WANTED", 1, true) then
        return { found = true }
      end
    end
    return { found = false, widen = true,
             question = "the same thing, asked wider" }
  end,
})
local widened = reader_module.read(widening, document, "the narrow question")
check("a search that widens says it widened",
      widened ~= nil and widened.widened, "the widening was not reported")
check("and the widened question reaches later passes",
      widened_question == "the same thing, asked wider",
      tostring(widened_question))
-- }}}

-- {{{ the seam with the hands: a huge answer crosses as something small
local catalogue = hands.new({
  budget = 2048,
  reader = reader_module.for_hands(reader_module.new({
    context = 4000,
    ask = function(question, window)
      for index, page in ipairs(window) do
        if page:find("THE THING WANTED", 1, true) then
          return { found = true, pages = { [index] = true } }
        end
      end
      return { found = false }
    end,
  }), "the long document"),
})
hands.offer(catalogue, {
  name = "read", takes = {}, gives = "far too much text",
  does = function() return document end,
})

local answer = hands.answer(catalogue, hands.find(catalogue, "<call read>"))
check("a hand's huge answer crosses as a few useful lines",
      answer.ok and answer.read and #answer.text < 600
      and answer.whole_length == #document,
      answer.text and answer.text:sub(1, 60))
check("and what crossed contains what was wanted",
      answer.ok and answer.text:find("THE THING WANTED", 1, true) ~= nil)
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not solve:")
say("    - an answer needing the first piece and the last one together.")
say("      Each pass sees a window, so a relationship spanning the whole")
say("      document is invisible to every pass. A widened search carries")
say("      findings forward, which helps; some questions will still come")
say("      back wrong rather than unanswered.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("the reader: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
