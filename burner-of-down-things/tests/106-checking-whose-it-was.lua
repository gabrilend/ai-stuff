-- 106-checking-whose-it-was.lua
--
-- Checks issue 1001d: every chapter names whose each thing was -- a
-- request's chapter names the person as its author; a turn's work names the
-- role and the harness that played it, read from the ledger's own
-- turn-started lines.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local ledger = require("016-ledger")
local story = require("103-the-story")

local folder = kit.scratch("whose-it-was")
local ledger_path = folder .. "/ledger"
local story_path = folder .. "/output/story/notes.md"

ledger.create(ledger_path, "case notes opened on /src/notes")                -- 1
ledger.append(ledger_path, "turn-started", "0001-referee-notes", "referee notes by claude-code") -- 2
ledger.append(ledger_path, "turn-ended", "0001-referee-notes", "kept: exit 0; 3 file(s) changed") -- 3
ledger.append(ledger_path, "refereed", "-", "3 workflows, attempt 1")       -- 4
ledger.append(ledger_path, "turn-started", "0002-build-101", "build 101 by stand-in") -- 5
ledger.append(ledger_path, "turn-ended", "0002-build-101", "kept: exit 0; 2 file(s) changed") -- 6
ledger.append(ledger_path, "built", "101", "acceptance passed")             -- 7
ledger.append(ledger_path, "workflow-failed", "tags.workflow", "after two rounds of repair") -- 8
ledger.append(ledger_path, "request-received", "tags.txt", "noticed in input/") -- 9

local lines = ledger.read(ledger_path)
local whose = story.whose(lines)

kit.equal(whose[1], "the person", "the person opened the case")
kit.equal(whose[9], "the person", "the person asked for the request")
kit.equal(whose[4], "the referee (claude-code)", "the referee's work names the harness that played it")
kit.equal(whose[7], "the builder (the stand-in)", "the builder's work names the stand-in")
kit.equal(whose[6], "the builder (the stand-in)", "a turn's end names the same role and harness as its start")
kit.equal(whose[8], "the referee's check (claude-code)", "the check that caught it is the referee's")

story.tell(ledger_path, story_path, "notes")
local text = kit.fs.read(story_path)

-- {{{ local function chapter_named
-- The text of the chapter whose heading contains `label`.
local function chapter_named(label)
    local start = text:find("## Chapter ", 1, true)
    while start do
        local after = text:find("\n## Chapter ", start, true)
        local chapter = text:sub(start, after or #text)
        if chapter:match("^[^\n]*"):find(label, 1, true) then
            return chapter
        end
        start = after and after + 1
    end
    return nil
end
-- }}}

local request = chapter_named("request tags.txt")
kit.check(request ~= nil, "the request has a chapter of its own")
kit.check(request and request:find("\nWhose: the person.", 1, true) ~= nil,
    "a request's chapter names the person as its author")
kit.check(request and request:find("The person asked for something new, in tags.txt.", 1, true) ~= nil,
    "the request's sentence says the person asked")

local refereed = chapter_named(": refereed")
kit.check(refereed and refereed:find("The referee (claude-code), who never saw the design", 1, true) ~= nil,
    "the refereed chapter credits the referee and the model that played it")

local built = chapter_named(": built")
kit.check(built and built:find("Whose: the builder (the stand-in).", 1, true) ~= nil,
    "the built chapter names the builder and the stand-in once")

kit.finish()
