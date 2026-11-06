-- 108-checking-the-story-command.lua
--
-- Checks the `story` row of the command table (issue 1001): run on a real
-- case folder, it writes output/story/<case>.md inside the case, and run
-- again over an unchanged ledger it adds no chapter.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local case = require("018-the-case")
local ledger = require("016-ledger")
local rows = require("107-the-story-commands")

local project, folder = kit.project_copy("story-command")
local source = folder .. "/notes-source"
kit.write_file(source .. "/notes.lua", "print('notes')\n")
local record = case.open(project, "notes", source, "stand-in")
ledger.append(record.ledger, "request-received", "tags.txt", "noticed in input/")

-- {{{ local function a_run
local function a_run()
    local said = {}
    return {
        case = record, project = project, args = {},
        done = {}, waiting = {}, failed = {},
        say = function(...) said[#said + 1] = table.concat({ ... }) end,
        said = said,
    }
end
-- }}}

local first = a_run()
rows.story.run(first)
local path = record.folder .. "/output/story/notes.md"
kit.check(kit.fs.exists(path), "the story is written inside the case, at output/story/<case>.md")
kit.equal(first.said[1], path, "the command prints where the story is")
kit.check(first.done[1]:find("2 new chapter(s)", 1, true) ~= nil, "the first run tells two chapters")
local text = kit.fs.read(path)
kit.check(text:find("## Chapter 2: request tags.txt (ledger lines 2-2)", 1, true) ~= nil,
    "the request is told as its own chapter")

local second = a_run()
rows.story.run(second)
kit.check(second.done[1]:find("0 new chapter(s)", 1, true) ~= nil, "a second run over an unchanged ledger tells nothing")
kit.equal(kit.fs.read(path), text, "and leaves the story as it was")
kit.equal(rows.story.needs_case, true, "the command holds the case lock, as every row that reads the ledger does")

kit.finish()
