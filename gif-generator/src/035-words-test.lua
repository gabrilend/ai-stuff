-- 035-words-test.lua — proof for the word files and pattern{...}.
--
-- What this is, generally: the two hand-written words load and pass
-- their own check; a score using the ring pattern reads into ordinary
-- strokes that compile; and every broken word file or misused pattern
-- is refused with its name. Broken word files are written into a scratch
-- copy of the words folder in RAM, never into the project.
-- Run: luajit src/035-words-test.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local words = require("034-words")
local score = require("022-score")
local compile = require("024-compile")

local SCRATCH = DIR .. "/tmp/shared-memory/words-test"
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

-- {{{ local function write()
local function write(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end
-- }}}

-- the shipped words load and keep the contract
local vocabulary = words.load_all(DIR)
check("the ring is a pattern", vocabulary.patterns.ring ~= nil)
check("an alias finds its pattern", vocabulary.patterns.circle == vocabulary.patterns.ring)
check("slowly is known but draws nothing", vocabulary.entries.slowly
      and vocabulary.patterns.slowly == nil)
check("every form points at its word", vocabulary.forms.gently == "slowly")
check("the ring passes its own check", (words.check(DIR, "ring")))
check("slowly passes its own check", (words.check(DIR, "slowly")))

-- a score using the ring reads into ordinary strokes that compile
write(SCRATCH .. "-ring-score.lua", table.concat({
    'canvas{ size = 128, fps = 25, length = 2.5, seed = 3 }',
    'pattern{ name = "ring", at = 0.0, lasts = 2.1, color = "jade",',
    '         center = {64, 64}, radius = 40 }',
}, "\n"))
local raw = score.read(SCRATCH .. "-ring-score.lua", vocabulary)
check("the ring expands into two strokes", #raw.strokes == 2)
check("an odd number of tenths stays in tenths",
      raw.strokes[1].lasts == 1.1 and raw.strokes[2].at == 1.1
      and math.abs(raw.strokes[2].lasts - 1.0) < 1e-9)
check("each stroke remembers its pattern", raw.strokes[1].comment == "from pattern ring")
local ok, compiled = pcall(compile.score, raw)
check("the expanded strokes pass the wall", ok, compiled)

-- {{{ local function read_refusal()
local function read_refusal(text, with_words)
    write(SCRATCH .. "-bad-score.lua", text)
    local ok2, err = pcall(score.read, SCRATCH .. "-bad-score.lua",
                           with_words and vocabulary or nil)
    return (not ok2) and err or nil
end
-- }}}

local canvas = 'canvas{ size = 64, fps = 25, length = 2.0, seed = 1 }\n'
local err = read_refusal(canvas .. 'pattern{ name = "rnig", at = 0.0, lasts = 1.0, color = "ice", center = {9,9}, radius = 5 }', true)
check("an unknown pattern teaches the nearest", err and err:find("nearest: 'ring'"), err)
err = read_refusal(canvas .. 'pattern{ name = "ring", at = 0.0, lasts = 1.0, color = "ice", center = {9,9}, radius = 5 }', false)
check("a pattern without word files is refused", err and err:find("no word files"), err)
err = read_refusal(canvas .. 'pattern{ name = "slowly", at = 0.0, lasts = 1.0, color = "ice" }', true)
check("a plain word cannot be drawn as a pattern", err and err:find("no pattern named 'slowly'"), err)

-- broken word files, each in its own scratch folder of words
-- {{{ local function load_refusal()
local function load_refusal(name, text)
    local root = SCRATCH .. "-" .. name
    os.execute("mkdir -p '" .. root .. "/words'")
    write(root .. "/words/" .. name .. ".lua", text)
    local ok3, why = pcall(words.load_all, root)
    os.remove(root .. "/words/" .. name .. ".lua")
    return (not ok3) and why or nil
end
-- }}}

err = load_refusal("misnamed", 'return { word = "other", aliases = {}, kind = "plain", meaning = "a sentence long enough" }')
check("a word must match its file name", err and err:find("must match"), err)
err = load_refusal("nokind", 'return { word = "nokind", aliases = {}, kind = "shiny", meaning = "a sentence long enough" }')
check("an unknown kind names the kinds", err and err:find("plain, pattern") or (err and err:find("pattern, plain")), err)
err = load_refusal("noexpand", 'return { word = "noexpand", aliases = {}, kind = "pattern", meaning = "a sentence long enough", fields = {}, example = "pattern{ name = \\"noexpand\\" }" }')
check("a pattern needs expand", err and err:find("needs expand"), err)
err = load_refusal("reader", 'local f = io.open("/etc/passwd") return { word = "reader", aliases = {}, kind = "plain", meaning = "a sentence long enough" }')
check("a word file cannot reach io", err and err:find("failed while loading"), err)

print("words: " .. passed .. " passed, " .. failed .. " failed")
os.exit(failed == 0 and 0 or 1)
