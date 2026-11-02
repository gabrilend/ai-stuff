-- 154-checking-the-source-end.lua
--
-- Checks issue 808, step 1: a Lua file whose first line is
-- `-- lua 5.1 (LuaJIT 2.1)` passes; one without it is refused; each
-- language's own parser runs over the file and its words come back when
-- the file does not parse; a parser that is not installed is refused by
-- name; a `.src` canvas reads through the wall; its document matches.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local source_end = require("153-the-source-end")
local wall = require("151-the-wall")

local scratch = kit.scratch("source-end")

-- {{{ local function file
local function file(name, text)
    local path = scratch .. "/" .. name
    kit.write_file(path, text)
    return path
end
-- }}}

local good_lua = file("adder.lua", "-- lua 5.1 (LuaJIT 2.1)\nlocal function add(a, b) return a + b end\nreturn add\n")
kit.check(source_end.check_first_line("lua", kit.fs.read(good_lua)), "a Lua file opening '-- lua 5.1 (LuaJIT 2.1)' passes the first-line check")
kit.check(source_end.check_file("lua", good_lua, "LuaJIT 2.1"), "and the whole check, parser included")

local bare = file("bare.lua", "local x = 1\nreturn x\n")
local ok, why = source_end.check_first_line("lua", kit.fs.read(bare))
kit.equal(ok, nil, "a Lua file without the line is refused")
kit.check(why:find("as '-- lua <version>'", 1, true) ~= nil, "the refusal says what the line should read: " .. why)

local wrong_version = file("old.lua", "-- lua 5.4\nreturn 1\n")
local _, vwhy = source_end.check_first_line("lua", kit.fs.read(wrong_version), "LuaJIT 2.1")
kit.check(vwhy and vwhy:find("not the version 'LuaJIT 2.1'", 1, true) ~= nil, "a line naming another version than the canvas's is refused")
local _, empty_version = source_end.check_first_line("lua", "-- lua \nreturn 1\n")
kit.check(empty_version ~= nil, "a line naming no version is refused")
local _, other = source_end.check_first_line("lua", "# lua 5.1\n")
kit.check(other ~= nil, "a line in another language's comment form is refused")

local broken = file("broken.lua", "-- lua 5.1 (LuaJIT 2.1)\nlocal function (\n")
local nok, findings = source_end.check_file("lua", broken)
kit.equal(nok, nil, "a Lua file that does not parse is refused")
kit.check(findings[1]:find("it does not parse:", 1, true) == 1 and findings[1]:find("broken.lua", 1, true) ~= nil,
    "with the parser's own words: " .. findings[1])

local c_good = file("hello.c", "// c c99\nint main(void) { return 0; }\n")
kit.check(source_end.check_file("c", c_good), "a C file with its line that parses passes (cc -fsyntax-only)")
local c_bad = file("bad.c", "// c c99\nint main(void) { return 0 }\n")
kit.check(not source_end.check_file("c", c_bad), "a C file that does not parse is refused")
local sh_good = file("hello.sh", "# bash 5\necho hello\n")
kit.check(source_end.check_file("bash", sh_good), "a bash file with its line that parses passes (bash -n)")
local sh_bad = file("bad.sh", "# bash 5\nif then fi\n")
kit.check(not source_end.check_file("bash", sh_bad), "a bash file that does not parse is refused")

local misnamed = file("adder.txt", "-- lua 5.1 (LuaJIT 2.1)\nreturn 1\n")
local _, mfind = source_end.check_file("lua", misnamed)
kit.check(mfind and mfind[1]:find("ends in .lua", 1, true) ~= nil, "a file whose ending does not match its language is refused")

source_end.LANGUAGES.ghost = { extension = "gh", comment = "--", parser = "no-such-parser-anywhere %s", program = "no-such-parser-anywhere" }
local ghost = file("x.gh", "-- ghost 1\n")
local _, gwhy = source_end.check_parse("ghost", ghost)
kit.check(gwhy and gwhy:find("not installed", 1, true) ~= nil, "a parser that is not installed is refused by name, never passed")
source_end.LANGUAGES.ghost = nil
kit.raises(function() source_end.check_first_line("luaa", "") end, "did you mean 'lua'", "an unknown language is refused with the nearest")

-- The canvas, through the wall.
local canvas = 'canvas{ category = "source", seed = 4 }\nsource{ language = "lua", version = "5.1 (LuaJIT 2.1)", purpose = "adds two numbers", prompt = "Write add(a, b)." }\n'
local read, rf = source_end.read(canvas)
kit.check(read ~= nil, "a .src canvas reads: " .. tostring(rf and wall.text(rf[1])))
kit.equal(read.first_line, "-- lua 5.1 (LuaJIT 2.1)", "the canvas says what the file's first line must be")
kit.equal(read.extension, "lua", "and its ending")
kit.equal(read.seed, 4, "and keeps its seed")
local _, bad = source_end.read('canvas{ category = "still" }\nsource{ language = "lau", version = "1", purpose = "p", prmpt = "q" }\n')
local texts = {}
for i, f in ipairs(bad) do texts[i] = wall.text(f) end
local all = table.concat(texts, "\n")
kit.check(all:find("wants one of bash, c, lua, got 'lau'; did you mean 'lua'", 1, true) ~= nil, "an unknown language is a finding with the nearest")
kit.check(all:find("has no field 'prmpt'; did you mean 'prompt'", 1, true) ~= nil, "a misspelt field is a finding")
kit.check(all:find("needs its field 'prompt'", 1, true) ~= nil, "the missing prompt is a finding")
kit.check(all:find("category is 'source', not 'still'", 1, true) ~= nil, "a .src canvas's category must be source")
local _, nosrc = source_end.read('canvas{ category = "source" }\n')
kit.check(nosrc and wall.text(nosrc[1]):find("needs one source", 1, true) ~= nil, "a canvas with no source{} is refused")

kit.equal(kit.fs.read(kit.DIR .. "/docs/paintbrush-src.md"), wall.document(source_end.SRC),
    "the committed docs/paintbrush-src.md is exactly what the table generates")

kit.finish()
