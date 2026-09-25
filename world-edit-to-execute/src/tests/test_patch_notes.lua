#!/usr/bin/env luajit
-- test_patch_notes.lua - turning Liquipedia's patch pages into plain notes
--
-- The markup rules on hand-made lines, a subpage template flattened to one
-- bullet, and (when the cache exists) the real 1.22 page: its balance lines
-- come from its subpages and carry the source and licence.
--
-- Run: luajit src/tests/test_patch_notes.lua [DIR]
-- Issue: issues/completed/115b-notes-for-versions-we-dont-read.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
arg = { [0] = "test" }
local notes = dofile(DIR .. "/src/cli/patch-notes-build.lua")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end

test("icons dropped, links to their text", notes.plain("[[File:Wc3Buff.png|22px]] [[Knight]]s have [[Sundering Blades]] by default.")
    == "Knights have Sundering Blades by default.")
test("piped links show the label", notes.plain("All towers ''([[Scout Tower|scout]], [[Guard Tower|guard]])''") == "All towers (scout, guard)")
test("code marks and entities", notes.plain("cheat <code>maxfps</code> 30&nbsp;FPS") == "cheat maxfps 30 FPS")

local parsed = notes.parse("{{Infobox patch\n|release=2008-06-30\n|version=1.22.0.6328\n}}\n==Fixes==\n* One.\n** Two.\n", "none")
test("sections and bullet depth", parsed.sections[1].heading == "Fixes" and parsed.sections[1].lines[2].depth == 2
    and parsed.release == "2008-06-30" and parsed.build == "1.22.0.6328")

local f = io.open(DIR .. "/wc3-installs/external-notes/sources.tsv", "r")
if not f then
    print("  [SKIP] real pages -- nothing cached (luajit src/cli/patch-notes-fetch.lua) --")
else
    f:close()
    local all = notes.build()
    local n = all["1.22a"]
    local found = false
    for _, sec in ipairs(n and n.sections or {}) do
        for _, l in ipairs(sec.lines) do
            if l.text:find("base damage increased from 25 to 28", 1, true) then found = true end
        end
    end
    test("1.22's Knight line comes from its subpage", found)
    test("each version carries its source and licence", n and n.url:match("^https://liquipedia.net/warcraft/") and n.license == "CC BY-SA 3.0")
end

print(string.format("\nTests: %d passed, %d failed", pass, fail))
os.exit(fail > 0 and 1 or 0)
