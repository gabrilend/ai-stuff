#!/usr/bin/env luajit
-- 116-promote-strategem.lua
--
-- Keeps a drafted strategem: moves strategems/drafts/<name>.md to
-- strategems/<name>.md and drops "(draft)" from its title. This is the
-- promotion gate of docs/069 (issue 1003d): the machine drafts strategems
-- from recurring lessons, but only the person makes one a strategem, by
-- running this script themselves. Nothing in the machine calls it, and a
-- turn cannot run it (turns have no way to run commands).
--
-- After the move it names any section still marked "not yet written", so
-- the person knows what is left to say in their own words.
--
-- Usage:
--   luajit scripts/116-promote-strategem.lua [project folder] <draft name>
--   (the project folder defaults to DIR below; the draft name is its file
--   name in strategems/drafts/, with or without .md)

local DIR = "/mnt/mtwo/programming/ai-stuff/burner-of-down-things"
local args = { ... }
if args[1] and args[1]:sub(1, 1) == "/" then
    DIR = table.remove(args, 1)
end
local name = args[1]
if not name then
    io.stderr:write("usage: 116-promote-strategem.lua [project folder] <draft name>\n")
    os.exit(2)
end

dofile(DIR .. "/src/013-paths.lua").set_search_path(DIR)
local drafts = require("111-the-strategem-drafts")

local ok, kept, unwritten = pcall(drafts.promote, DIR .. "/strategems", name)
if not ok then
    io.stderr:write("promote-strategem: ", tostring(kept), "\n")
    os.exit(1)
end
print("kept " .. kept)
if #unwritten > 0 then
    print("still to write in your own words: " .. table.concat(unwritten, "; "))
end
