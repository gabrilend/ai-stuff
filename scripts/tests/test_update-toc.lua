#!/usr/bin/env luajit
-- test_update-toc.lua
-- Drives update-toc against small fake projects and checks that it finds the
-- documents a table of contents does not link to and the links that reach
-- nothing, that --write lists only those and leaves every hand-written line
-- alone, and that a project without a table gets a whole one (issue A05).
--
-- Why this test exists. The house rule that every new document is added to
-- docs/table-of-contents.md is followed by hand, and nothing checked it. A
-- tool that "keeps the table current" by rewriting it would destroy the
-- groupings and descriptions people wrote, so most of what is checked here is
-- what --write must NOT touch.
--
-- Run: `luajit test_update-toc.lua [SCRIPTS_DIR]`. Exits 1 on any failure.

-- {{{ DIR + paths
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local TOOL = DIR .. "/update-toc"
local SCRATCH = (os.getenv("TMPDIR") or "/tmp") .. "/test-update-toc-" .. os.time() .. "-" .. math.random(1e6)
-- }}}

local failures = 0

-- {{{ local function check
local function check(label, ok)
    failures = failures + (ok and 0 or 1)
    print((ok and "ok   " or "FAIL ") .. label)
end
-- }}}

-- {{{ local function write / read
local function write(path, text)
    os.execute("mkdir -p '" .. path:match("(.*)/") .. "'")
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end
local function read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
-- }}}

-- {{{ local function run
-- Returns update-toc's stdout and exit status.
local function run(args)
    local handle = io.popen(TOOL .. " " .. args .. " 2>&1; echo \"exit=$?\"")
    local out = handle:read("*a")
    handle:close()
    return out, tonumber(out:match("exit=(%d+)%s*$"))
end
-- }}}

-- {{{ a project with a hand-written table
local P = SCRATCH .. "/hand"
local HAND = table.concat({
    "# Hand Project Docs",
    "",
    "## Design",
    "- [Roadmap](roadmap.md) - where it is going 📝",
    "- **[formats/mpq.md](formats/mpq.md)** - the archive format",
    "- [Vision](../notes/vision.md) - outside docs/, still a real file",
    "- [Later](not-written-yet.md) - planned",
    "- [Site](https://example.org/docs.md) and [a section](#design) are not files",
    "",
    "```",
    "- [Example](in-a-code-block.md)",
    "```",
    "",
    "Trailing words the owner wrote.",
    "",
}, "\n")
write(P .. "/docs/table-of-contents.md", HAND)
write(P .. "/docs/roadmap.md", "# Roadmap\n")
write(P .. "/docs/formats/mpq.md", "# MPQ Archive Format\n")
write(P .. "/docs/formats/w3e.md", "```\n# not the title\n```\n# W3E Terrain [v2]\n")
write(P .. "/docs/in-a-code-block.md", "# Only Mentioned In Code\n")
write(P .. "/docs/untitled.md", "no heading here\n")
write(P .. "/docs/.hidden/secret.md", "# hidden\n")
write(P .. "/notes/vision.md", "# Vision\n")
-- }}}

print("Reporting:")
local out, status = run("'" .. P .. "'")
check("exit 1 when anything is unlisted or dead", status == 1)
check("a document only named inside a code block is unlisted",
    out:find("docs/in-a-code-block.md: not linked", 1, true) ~= nil)
check("a document nothing names is unlisted",
    out:find("docs/formats/w3e.md: not linked", 1, true) ~= nil)
check("a listed document is not reported",
    out:find("roadmap.md: not linked", 1, true) == nil
    and out:find("mpq.md: not linked", 1, true) == nil)
check("a hidden folder is nobody's documentation",
    out:find("secret", 1, true) == nil)
check("a link to a missing file is dead, with its line number",
    out:find("table-of-contents.md:7: link reaches no file: not-written-yet.md", 1, true) ~= nil)
check("a link out of docs/ to a real file is not dead",
    out:find("vision", 1, true) == nil)
check("web links and anchors are not files",
    out:find("example.org", 1, true) == nil and out:find("#design", 1, true) == nil)

print("Writing into a hand-written table:")
local dry, dry_status = run("'" .. P .. "' --write --dry-run")
check("--dry-run prints and changes nothing",
    dry_status == 0 and read(P .. "/docs/table-of-contents.md") == HAND
    and dry:find("Not Yet Filed", 1, true) ~= nil)
out, status = run("'" .. P .. "' --write")
local after = read(P .. "/docs/table-of-contents.md")
check("--write succeeds", status == 0)
check("every hand-written byte is still there, in front",
    after:sub(1, #HAND) == HAND)
check("the unlisted documents are listed by title",
    after:find("- [W3E Terrain \\[v2\\]](formats/w3e.md)", 1, true) ~= nil
    and after:find("- [Only Mentioned In Code](in-a-code-block.md)", 1, true) ~= nil)
check("a document with no heading is listed by its file name",
    after:find("- [untitled](untitled.md)", 1, true) ~= nil)
check("the dead link is still reported, and left in place",
    out:find("not-written-yet.md", 1, true) ~= nil
    and after:find("[Later](not-written-yet.md)", 1, true) ~= nil)
out, status = run("'" .. P .. "'")
check("after --write only the dead link is left to report",
    status == 1 and out:find("not linked", 1, true) == nil
    and out:find("not-written-yet.md", 1, true) ~= nil)

print("Running --write again:")
out, status = run("'" .. P .. "' --write")
check("a second --write with nothing new changes nothing",
    status == 0 and read(P .. "/docs/table-of-contents.md") == after
    and out:find("unchanged", 1, true) ~= nil)

-- file one entry by hand, above the block
local filed = after:gsub("Trailing words", "- [W3E](formats/w3e.md) - filed by hand\n\nTrailing words", 1)
write(P .. "/docs/table-of-contents.md", filed)
run("'" .. P .. "' --write")
after = read(P .. "/docs/table-of-contents.md")
check("an entry filed by hand leaves the unfiled block",
    after:find("- [W3E Terrain", 1, true) == nil
    and after:find("- [W3E](formats/w3e.md) - filed by hand", 1, true) ~= nil)

-- file the rest, and fix the dead link
write(P .. "/docs/not-written-yet.md", "# Later\n")
local all_filed = read(P .. "/docs/table-of-contents.md")
    :gsub("Trailing words", "- [a](in-a-code-block.md) [b](untitled.md)\n\nTrailing words", 1)
write(P .. "/docs/table-of-contents.md", all_filed)
out, status = run("'" .. P .. "' --write")
after = read(P .. "/docs/table-of-contents.md")
check("once everything is filed the block disappears",
    after:find("update-toc:", 1, true) == nil)
check("...and the table is the owner's text alone, with no blank line left behind",
    after == all_filed:gsub("\n\n<!%-%- update%-toc.*$", "\n"))
out, status = run("'" .. P .. "'")
check("a clean project exits 0", status == 0 and out:find("all listed", 1, true) ~= nil)

print("A project with no table of contents:")
local N = SCRATCH .. "/bare"
write(N .. "/docs/roadmap.md", "# Roadmap\n")
write(N .. "/docs/formats/mpq.md", "# MPQ Archive Format\n")
write(N .. "/docs/formats/deep/w3e.md", "# W3E Terrain\n")
write(N .. "/docs/a space.md", "# Spaced Out\n")
out, status = run("'" .. N .. "'")
check("a missing table is a finding", status == 1
    and out:find("table-of-contents.md: does not exist", 1, true) ~= nil)
out, status = run("'" .. N .. "' --write")
local tree = read(N .. "/docs/table-of-contents.md") or ""
check("--write writes a whole table", status == 0 and tree:find("^# bare Documentation") ~= nil)
check("folders come first, nested, files under them",
    tree:find("- **formats/**\n  - **deep/**\n    - [W3E Terrain](formats/deep/w3e.md)\n  - [MPQ Archive Format](formats/mpq.md)\n- [Roadmap](roadmap.md)", 1, true) ~= nil)
check("a space in a path is written so the link survives",
    tree:find("(a%20space.md)", 1, true) ~= nil)
check("the written table carries no date that would change every run",
    not tree:find("%d%d%d%d%-%d%d%-%d%d"))
out, status = run("'" .. N .. "'")
check("the written table passes its own check", status == 0)
local tree_out = run("'" .. N .. "' --tree")
check("--tree prints the same table without writing", tree_out:find(tree, 1, true) ~= nil)

print("Ignoring and arguments:")
out, status = run("'" .. P .. "' --ignore '^docs/formats/'")
check("--ignore leaves matching documents out", out:find("formats", 1, true) == nil)
out, status = run("'" .. SCRATCH .. "/nowhere'")
check("no docs/ folder exits 2", status == 2)
out, status = run("'" .. P .. "' --dry-run")
check("--dry-run without --write is refused", status == 2)
out, status = run("--help")
check("--help prints usage and exits 0", status == 0 and out:find("usage:", 1, true) ~= nil)

print("Markers that do not pair are an error, not a guess:")
write(P .. "/docs/table-of-contents.md",
    "# T\n<!-- update-toc: unfiled documents start -->\n- [x](x.md)\nowner text\n")
local before = read(P .. "/docs/table-of-contents.md")
out, status = run("'" .. P .. "' --write")
check("a lone start marker stops --write and leaves the file alone",
    status ~= 0 and read(P .. "/docs/table-of-contents.md") == before)

os.execute("rm -rf '" .. SCRATCH .. "'")
print("")
print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)
