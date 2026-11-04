-- 037-lexicon-test.lua — proof for the unknown-word finder.
--
-- What this is, generally: plain prose with a few picture words gives
-- back exactly those words, in order, each with its sentence; a word
-- with a file, its alias, and their inflections are known.
-- Run: luajit src/037-lexicon-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local words = require("034-words")
local lexicon = require("036-lexicon")
local vocabulary = words.load_all(DIR)
local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition, detail)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name .. (detail and (" — " .. tostring(detail)) or ""))
    end
end
-- }}}

-- {{{ local function list()
local function list(found)
    local out = {}
    for _, f in ipairs(found) do out[#out + 1] = f.word end
    return table.concat(out, " ")
end
-- }}}

local found = lexicon.unknown(
    "A spiral of ember light slowly unwinds. Then rain falls across the "
    .. "whole canvas, and the spiral fades.", vocabulary)
check("the picture words are found, in order, once each",
      list(found) == "spiral unwinds rain falls", list(found))
check("each carries its sentence",
      found[3] and found[3].sentence:find("rain falls across"), found[3] and found[3].sentence)

check("a word with a file is known", #lexicon.unknown("a ring.", vocabulary) == 0)
check("its alias is known", #lexicon.unknown("two circles.", vocabulary) == 0)
check("an inflection of a known word is known",
      #lexicon.unknown("the rings fading gently.", vocabulary) == 0,
      list(lexicon.unknown("the rings fading gently.", vocabulary)))
check("vocabulary words are known",
      #lexicon.unknown("an ember arc, clockwise, eased with smoothstep.", vocabulary) == 0,
      list(lexicon.unknown("an ember arc, clockwise, eased with smoothstep.", vocabulary)))
check("a word and its plural start one session between them",
      list(lexicon.unknown("the hands turn. one hand stops.", vocabulary)) == "hands",
      list(lexicon.unknown("the hands turn. one hand stops.", vocabulary)))
check("in either order",
      list(lexicon.unknown("one hand stops. the hands turn.", vocabulary)) == "hand",
      list(lexicon.unknown("one hand stops. the hands turn.", vocabulary)))
check("a blank line ends a sentence",
      lexicon.unknown("a ring\n\nthen sparkles", vocabulary)[1].sentence == "then sparkles")

print("lexicon: " .. passed .. " passed, " .. failed .. " failed")
os.exit(failed == 0 and 0 or 1)
