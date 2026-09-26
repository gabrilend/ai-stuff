#!/usr/bin/env luajit
-- 033-close-issue.lua
--
-- Closes an issue of this project the house way, in one step: the issue's
-- "Current Behavior" section is replaced with a description of what was
-- built (read from standard input), and the file is moved from issues/ into
-- issues/completed/. Nothing else in the issue is touched: its intended
-- behavior and steps stay as the blueprint.
--
-- The move is a plain rename, not `git mv`: the house commit tool commits
-- this session's own changes from its ledger, and a rename staged by hand
-- in the shared staging area collides with that.
--
-- Usage:
--   luajit scripts/033-close-issue.lua [project folder] <issue file name> < built.txt
--   (the project folder defaults to DIR below)

local DIR = "/mnt/mtwo/programming/ai-stuff/burner-of-down-things"
local args = { ... }
if args[1] and args[1]:sub(1, 1) == "/" then
    DIR = table.remove(args, 1)
end
local name = args[1]
if not name then
    io.stderr:write("usage: 033-close-issue.lua [project folder] <issue file name> < built.txt\n")
    os.exit(2)
end
if not name:match("%.md$") then
    name = name .. ".md"
end

local from = DIR .. "/issues/" .. name
local to = DIR .. "/issues/completed/" .. name

local file = io.open(from, "rb")
if not file then
    io.stderr:write("close-issue: no open issue at " .. from .. "\n")
    os.exit(1)
end
local text = file:read("*a")
file:close()

local built = io.read("*a"):gsub("%s+$", "")
if built == "" then
    io.stderr:write("close-issue: standard input was empty; describe what was built\n")
    os.exit(1)
end

-- The section runs from its heading to the next "## " heading.
local head_start, head_end = text:find("## Current Behavior\n", 1, true)
if not head_start then
    io.stderr:write("close-issue: " .. name .. " has no '## Current Behavior' section\n")
    os.exit(1)
end
local next_heading = text:find("\n## ", head_end, true)
if not next_heading then
    io.stderr:write("close-issue: nothing follows Current Behavior in " .. name .. "\n")
    os.exit(1)
end
local new_text = text:sub(1, head_end) .. "\n" .. built .. "\n" .. text:sub(next_heading)

local out = assert(io.open(to, "wb"))
out:write(new_text)
out:close()
assert(os.remove(from))
print("closed " .. name)
