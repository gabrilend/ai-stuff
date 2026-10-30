-- 057-skill-examples-test.lua - checks the studio skill says only what the
-- studio does (issue 701f).
--
-- What this is, generally: the skill an assistant loads to make pictures
-- here (`skills/gif-studio/SKILL.md`, beside this project in the ai-stuff
-- repository) shows its examples as fenced blocks, each labelled with what
-- it is:
--   ```lua score     a score; it must pass the wall and film
--   ```lua scene     a shape scene; it must film through the film tool
--   ```lua refused   a score the wall refuses; the ```text block right
--                    after it is the refusal, word for word
-- This films every one, and checks every project file the skill names in
-- backticks exists, so the skill cannot drift from the studio.
--
-- Usage: luajit src/057-skill-examples-test.lua DIR [SKILL]
--   DIR    the gif-generator project
--   SKILL  the skill file (default: DIR/../skills/gif-studio/SKILL.md)
-- Prints one line per check; exits 1 if any failed.

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/gif-generator"
local SKILL = arg[2] or (DIR .. "/../skills/gif-studio/SKILL.md")
package.path = DIR .. "/src/?.lua;" .. package.path
local score = require("022-score")
local compile = require("024-compile")
local main = require("026-render-main")
local SCRATCH = "/dev/shm/gif-generator/skill-examples-test"
os.execute(string.format("rm -rf %q; mkdir -p %q", SCRATCH, SCRATCH))

local passed, failed = 0, 0
-- {{{ local function check()
local function check(label, ok)
    if ok then
        passed = passed + 1
        print("  ok   - " .. label)
    else
        failed = failed + 1
        print("  FAIL - " .. label)
    end
end
-- }}}

-- {{{ local function blocks_of()
-- Every fenced block in the text, in order: { info = "lua score", text = ... }.
local function blocks_of(text)
    local blocks, open = {}, nil
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local fence, info = line:match("^(%s*)```(.*)$")
        if fence and not open then
            open = { info = info, lines = {}, indent = #fence }
        elseif fence and open then
            open.text = table.concat(open.lines, "\n")
            blocks[#blocks + 1] = open
            open = nil
        elseif open then
            open.lines[#open.lines + 1] = line:sub(open.indent + 1)
        end
    end
    return blocks
end
-- }}}

-- {{{ local function write_file()
local function write_file(path, text)
    local handle = assert(io.open(path, "w"))
    handle:write(text, "\n")
    handle:close()
end
-- }}}

-- {{{ local function name_of()
-- An example's name: the first word of its opening comment, or its place.
local function name_of(text, fallback)
    return text:match("^%-%-%s*([%w%-]+)") or fallback
end
-- }}}

local handle = io.open(SKILL, "rb")
check("the skill is where the tests look for it (" .. SKILL .. ")", handle ~= nil)
if not handle then
    print("")
    print(string.format("%d passed, %d failed", passed, failed))
    os.exit(1)
end
local text = handle:read("*a")
handle:close()
local blocks = blocks_of(text)

local seen = { score = 0, scene = 0, refused = 0 }
for i, block in ipairs(blocks) do
    local kind = block.info:match("^lua%s+(%a+)$")
    if kind == "score" then
        seen.score = seen.score + 1
        local name = name_of(block.text, "score-" .. i)
        local path = SCRATCH .. "/" .. name .. ".lua"
        write_file(path, block.text)
        local ok, compiled = pcall(compile.score, score.read(path))
        check("the skill's score '" .. name .. "' passes the wall", ok)
        if ok then
            local bytes = main.render_to_gif(compiled)
            check("and films", type(bytes) == "string" and bytes:sub(1, 6) == "GIF89a")
        end
    elseif kind == "scene" then
        seen.scene = seen.scene + 1
        local name = name_of(block.text, "scene-" .. i)
        local path = SCRATCH .. "/" .. name .. ".lua"
        write_file(path, block.text)
        local film_ok = os.execute(string.format("luajit %q %q %q --out=%q > %q 2>&1",
            DIR .. "/src/039-shape-films.lua", DIR, path, SCRATCH, SCRATCH .. "/" .. name .. ".log"))
        local gif = io.open(SCRATCH .. "/" .. name .. ".gif", "rb")
        local head = gif and gif:read(6)
        if gif then gif:close() end
        check("the skill's scene '" .. name .. "' films through the film tool",
              (film_ok == 0 or film_ok == true) and head == "GIF89a")
    elseif kind == "refused" then
        seen.refused = seen.refused + 1
        local path = SCRATCH .. "/refused-" .. i .. ".lua"
        write_file(path, block.text)
        local ok, refusal = pcall(compile.score, score.read(path))
        refusal = tostring(refusal):gsub("^[^\n]-:%d+: ", "")
        local said = blocks[i + 1]
        check("the skill's refused score is refused", not ok)
        check("with exactly the refusal the skill shows",
              said ~= nil and said.info == "text" and refusal == said.text)
        if said and refusal ~= said.text then
            print("    the wall says:\n" .. refusal)
        end
    end
end
check("the skill shows at least one score, one scene and one refusal",
      seen.score >= 1 and seen.scene >= 1 and seen.refused >= 1)

-- Every project file the skill names in backticks is still there.
local missing = {}
for path in text:gmatch("`([%w%-%./]+)`") do
    local first = path:match("^([%w%-]+)/")
    -- a placeholder in capitals (input/NAME.lua) names no one file
    if (first == "src" or first == "docs" or first == "tests" or first == "input")
       and not path:match("%u%u") then
        local probe = io.open(DIR .. "/" .. path, "rb")
        if probe then probe:close() else
            local dir_probe = os.execute(string.format("test -d %q", DIR .. "/" .. path))
            if not (dir_probe == 0 or dir_probe == true) then missing[#missing + 1] = path end
        end
    end
end
check("every project file the skill names exists"
      .. (#missing > 0 and (" (missing: " .. table.concat(missing, ", ") .. ")") or ""), #missing == 0)

local tools_missing = {}
for tool in text:gmatch("`%./([%w%-]+)") do
    local probe = io.open(DIR .. "/" .. tool, "rb")
    if probe then probe:close() else tools_missing[#tools_missing + 1] = tool end
end
check("every ./tool the skill names exists"
      .. (#tools_missing > 0 and (" (missing: " .. table.concat(tools_missing, ", ") .. ")") or ""),
      #tools_missing == 0)

os.execute(string.format("rm -r %q", SCRATCH))
print("")
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
