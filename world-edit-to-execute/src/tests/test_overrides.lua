#!/usr/bin/env luajit
-- test_overrides.lua - the model-override file (issue 504) and the chooser that reads it (516's stand-in)
--
-- The override file: read, written back the same, every problem in a bad
-- file reported with its line, map-only overrides winning over every-map
-- ones, paths matched whatever their case, slashes or extension, sets
-- merged with the first winning, saved whole. The chooser: an override's
-- file read from a real store (assets/dedup.lua, in a folder under TMPDIR),
-- the map's model when there is no override or it can't be read, a
-- placeholder when neither, each path chosen once, every use counted.
--
-- Run: luajit src/tests/test_overrides.lua [DIR]
-- Issues: issues/504-create-asset-pack-specification.md, issues/516-draw-wc3-models-in-engine.md

-- {{{ Setup
local DIR = arg[1] or (arg[0] or ""):match("^(.*)/src/tests/[^/]*$")
    or ((arg[0] or ""):match("^src/tests/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local overrides = require("assets.overrides")
local chooser = require("assets.chooser")
local dedup = require("assets.dedup")

local TMP = (os.getenv("TMPDIR") or "/tmp") .. "/test-overrides-" .. tostring(os.time()) .. "-" .. tostring(math.random(1e9))
assert(TMP:match("/test%-overrides%-%d+%-%d+$"), "refusing an odd scratch folder")
os.execute("mkdir -p '" .. TMP .. "'")
-- }}}

-- {{{ Test utilities
local test_count, pass_count, fail_count = 0, 0, 0

local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        fail_count = fail_count + 1
        print("  [FAIL] " .. name .. (msg and ": " .. tostring(msg) or ""))
    end
end

local function test_section(name)
    print("\n=== " .. name .. " ===")
end

local function h(c) return "sha256:" .. string.rep(c, 64) end
local A, B, C, M1, M2 = h("a"), h("b"), h("c"), h("1"), h("2")

local function has_problem(problems, pattern)
    for _, p in ipairs(problems or {}) do
        if p:find(pattern, 1, true) then return true end
    end
    return false
end
-- }}}

-- {{{ Reading a file
test_section("reading an overrides file")
local GOOD = table.concat({
    "wete-overrides 1",
    "# grim footmen, from a friend",
    "name\tGrim footmen",
    "",
    "override\tUnits\\Human\\Footman\\Footman\t" .. A .. "\tscale=1.25\ttint=255,200,10",
    "override\tunits/human/footman/footman.mdx\t" .. B .. "\tteam_colour=off\tmap=" .. M1,
    "override\tDoodads\\Tree.mdl\t" .. C,
}, "\n") .. "\n"
do
    local set, problems = overrides.parse(GOOD, "good")
    test("a good file reads", set ~= nil, problems and table.concat(problems, "; "))
    set = set or overrides.new()
    test("its name", set.name == "Grim footmen")
    test("three overrides", set:count() == 3, set:count())
    local e = set:lookup("UNITS/HUMAN/FOOTMAN/FOOTMAN.MDX")
    test("a path matches whatever its case, slashes and extension", e and e.file == A)
    test("its scale and tint", e and e.scale == 1.25 and e.tint[1] == 255 and e.tint[2] == 200 and e.tint[3] == 10)
    test("team colour is on unless turned off", e and e.team_colour == true)
    test("it applies to every map", e and e.map == nil)
    test("it remembers its line", e and e.line == 5, e and e.line)
    local own = set:lookup("Units\\Human\\Footman\\Footman", M1)
    test("on its own map, a map's override wins", own and own.file == B and own.team_colour == false and own.map == M1)
    test("on another map, the every-map one", (set:lookup("Units\\Human\\Footman\\Footman", M2) or {}).file == A)
    local tree = set:lookup("doodads/tree")
    test("defaults: scale 1, no tint", tree and tree.scale == 1 and tree.tint[1] == 255 and tree.tint[2] == 255 and tree.tint[3] == 255)
    test("a path nobody overrode", set:lookup("Units\\Orc\\Grunt\\Grunt") == nil)
    test("a map's override doesn't leak to every map", (function()
        local only = overrides.parse("wete-overrides 1\noverride\tx\t" .. A .. "\tmap=" .. M1 .. "\n")
        return only:lookup("x") == nil and only:lookup("x", M2) == nil and only:lookup("x", M1) ~= nil
    end)())
    test("Windows line ends read the same", (function()
        local crlf = overrides.parse((GOOD:gsub("\n", "\r\n")), "crlf")
        return crlf and crlf:count() == 3 and crlf.name == "Grim footmen"
    end)())
    test("a file without a final line break reads", overrides.parse("wete-overrides 1\noverride\tx\t" .. A) ~= nil)
    test("key drops case, slashes, a leading slash and the extension",
        overrides.key("\\Units\\X.MDX") == "units/x" and overrides.key("a/b.mdl") == "a/b" and overrides.key("a.mdx.txt") == "a.mdx.txt")
end
-- }}}

-- {{{ Bad files
test_section("a bad file is refused, every problem named with its line")
do
    local function bad(text) local s, p = overrides.parse(text, "f"); return s, p end
    local s, p = bad("hello\n")
    test("a file without the header is refused", s == nil and has_problem(p, "f:1: not an overrides file"))
    s, p = bad("wete-overrides 2\n")
    test("an unknown version is refused", s == nil and has_problem(p, "version 2"))
    s, p = bad("")
    test("an empty file is refused", s == nil and has_problem(p, "f:1: not an overrides file (the first line must be \"wete-overrides 1\")"))
    s, p = bad("wete-overrides 3\n")
    test("the refusal says which version is known", has_problem(p, "f:1: format version 3 is not known (this reader knows 1)"))
    s, p = bad("wete-overrides 1")
    test("a header alone is an empty set", s ~= nil and s:count() == 0)
    local text = table.concat({
        "wete-overrides 1",
        "override\tx\tsha256:" .. string.rep("A", 64),                    -- 2 upper-case hash
        "override\tx\t" .. A .. "\tscale=0",                               -- 3
        "override\tx\t" .. A .. "\tscale=-1",                              -- 4
        "override\tx\t" .. A .. "\tscale=big",                             -- 5
        "override\tx\t" .. A .. "\ttint=256,0,0",                          -- 6
        "override\tx\t" .. A .. "\ttint=1,2",                              -- 7
        "override\tx\t" .. A .. "\tteam_colour=maybe",                     -- 8
        "override\tx\t" .. A .. "\tcolour=red",                            -- 9
        "override\tx\t" .. A .. "\tscale=1\tscale=2",                      -- 10
        "override\tx\t" .. A .. "\tmap=nope",                              -- 11
        "override\tx",                                                     -- 12
        "frobnicate\tx",                                                   -- 13
        "override\ty\t" .. A,                                              -- 14
        "override\tY.mdx\t" .. B,                                          -- 15 same path as 14
        "name\tone",                                                       -- 16
        "name\ttwo",                                                       -- 17
        "override\t\t" .. A,                                               -- 18
        "override\tx\t" .. A .. "\tnot-an-option",                         -- 19
        "override\tx\tsha256:abc",                                         -- 20 short hash
        "override\tx\t" .. A .. "\tscale=inf",                             -- 21
        "name",                                                            -- 22
    }, "\n")
    s, p = bad(text)
    test("a file with problems gives no set", s == nil)
    test("an upper-case hash", has_problem(p, "f:2: the file must be a hash, sha256: and 64 lower-case hex digits"))
    test("the map's message in full", has_problem(p, "f:11: map must be a hash, sha256: and 64 lower-case hex digits"))
    test("the path's message in full", has_problem(p, "f:18: the model path is missing or holds a tab or line break"))
    test("the tint's message in full", has_problem(p, "f:6: tint must be three whole numbers from 0 to 255"))
    test("team colour's message in full", has_problem(p, "f:8: team_colour must be on or off: maybe"))
    test("a zero scale", has_problem(p, "f:3: scale must be a number above 0"))
    test("a negative scale", has_problem(p, "f:4: scale must be a number above 0"))
    test("a scale that isn't a number", has_problem(p, "f:5: scale is not a number"))
    test("a tint out of range", has_problem(p, "f:6: tint must be three whole numbers"))
    test("a tint with two numbers", has_problem(p, "f:7: tint must be R,G,B"))
    test("team colour neither on nor off", has_problem(p, "f:8: team_colour must be on or off"))
    test("an unknown option", has_problem(p, "f:9: unknown option colour"))
    test("an option given twice", has_problem(p, "f:10: scale given twice"))
    test("a map that isn't a hash", has_problem(p, "f:11: map must be a hash"))
    test("an override without a file", has_problem(p, "f:12: an override needs a model path and a file"))
    test("an unknown line", has_problem(p, "f:13: unknown line kind"))
    test("the same path twice names the first line", has_problem(p, "f:15: the same model path and map as line 14"))
    test("a second name", has_problem(p, "f:17: the set is named twice"))
    test("an empty model path", has_problem(p, "f:18: the model path is missing"))
    test("something that isn't key=value", has_problem(p, "f:19: expected key=value"))
    test("a short hash", has_problem(p, "f:20: the file must be a hash"))
    test("an endless scale", has_problem(p, "f:21: scale must be a number above 0"))
    test("a name without a value", has_problem(p, "f:22: name takes one value"))
    test("every problem, not just the first (19 of 21 lines)", #p == 19, #p)
    test("the same path for two scopes is fine",
        overrides.parse("wete-overrides 1\noverride\tx\t" .. A .. "\noverride\tx\t" .. B .. "\tmap=" .. M1 .. "\n") ~= nil)
    test("nothing in the file is run as code", (function()
        _G.__ran = nil
        local s2 = overrides.parse("wete-overrides 1\nname\t__ran = true\noverride\tos.exit(1)\t" .. A .. "\n")
        return s2 ~= nil and _G.__ran == nil and s2.name == "__ran = true"
    end)())
end
-- }}}

-- {{{ Writing
test_section("written back the same")
do
    local set = assert(overrides.parse(GOOD, "good"))
    local text = overrides.write(set)
    local again = assert(overrides.parse(text, "again"))
    test("written and read again, the same overrides", again:count() == 3 and again.name == "Grim footmen")
    test("and written again, the same text", overrides.write(again) == text, text)
    test("defaults are left out", not text:find("scale=1\t", 1, true) and not text:find("scale=1\n", 1, true)
        and not text:find("team_colour=on", 1, true) and not text:find("tint=255,255,255", 1, true))
    test("the rest are written", text:find("scale=1.25", 1, true) and text:find("tint=255,200,10", 1, true)
        and text:find("team_colour=off", 1, true) and text:find("map=" .. M1, 1, true))
    test("the header comes first", text:sub(1, 17) == "wete-overrides 1\n")
    test("an unnamed set writes no name", not overrides.write(overrides.new()):find("name", 1, true))
    local exact = overrides.new("n")
    exact:add({ path = "p", file = A, team_colour = false, map = M1 })
    exact:add({ path = "q", file = B, tint = { 200, 255, 255 } })
    exact:add({ path = "r", file = C, tint = { 255, 255, 10 }, team_colour = true })
    exact:add({ path = "s", file = C, tint = { 255, 9, 255 }, scale = 2.5 })
    test("the exact text", overrides.write(exact) == "wete-overrides 1\nname\tn\n"
        .. "override\tp\t" .. A .. "\tteam_colour=off\tmap=" .. M1 .. "\n"
        .. "override\tq\t" .. B .. "\ttint=200,255,255\n"
        .. "override\tr\t" .. C .. "\ttint=255,255,10\n"
        .. "override\ts\t" .. C .. "\tscale=2.5\ttint=255,9,255\n", overrides.write(exact))
    test("team_colour=on reads as on", assert(overrides.parse("wete-overrides 1\noverride\tx\t" .. A .. "\tteam_colour=on")):lookup("x").team_colour == true)
    local odd = overrides.new()
    odd:add({ path = "x", file = A, scale = 0.1 + 0.2 })
    local back = assert(overrides.parse(overrides.write(odd)))
    test("an awkward scale reads back exactly", back:lookup("x").scale == 0.1 + 0.2)
    odd:add({ path = "y", file = A, scale = 3 })
    test("a whole scale is written without a point", overrides.write(odd):find("scale=3\n", 1, true) ~= nil)
end
-- }}}

-- {{{ Changing a set
test_section("adding and removing (what the override screen will do)")
do
    local set = overrides.new("mine")
    test("an override is added", set:add({ path = "Units\\X", file = A }) ~= nil and set:count() == 1)
    test("the same path again replaces it", set:add({ path = "units/x.mdx", file = B }) ~= nil
        and set:count() == 1 and set:lookup("units\\x").file == B)
    test("the same path for one map is another override", set:add({ path = "units/x", file = C, map = M1 }) ~= nil
        and set:count() == 2)
    local e, why = set:add({ path = "y", file = "nope" })
    test("a bad override is refused with a reason", e == nil and why:find("hash", 1, true))
    e, why = set:add({ path = "y", file = A, tint = { 1, 2, 3.5 } })
    test("a fractional tint is refused", e == nil and why:find("whole", 1, true))
    e, why = set:add({ path = "y", file = A, tint = "red" })
    test("a tint that isn't a list is refused", e == nil and why:find("tint", 1, true))
    e, why = set:add({ path = "y", file = A, team_colour = "on" })
    test("team colour must be true or false", e == nil and why == "team_colour must be on or off")
    e, why = set:add({ path = "y", file = A, tint = { 1, 2 } })
    test("a tint of two numbers is refused", e == nil and why == "tint must be three numbers")
    e, why = set:add({ path = "y", file = A, tint = { -1, 0, 0 } })
    test("a negative tint is refused", e == nil)
    test("a black tint is fine", set:add({ path = "black", file = A, tint = { 0, 0, 0 } }) ~= nil and set:remove("black"))
    e = set:add({ path = "a\tb", file = A })
    test("a path with a tab is refused", e == nil)
    test("removing the every-map one leaves the map's", set:remove("UNITS/X") == true
        and set:lookup("units/x") == nil and set:lookup("units/x", M1).file == C and set:count() == 1
        and overrides.write(set):find(C, 1, true) and not overrides.write(set):find(B, 1, true))
    test("removing what isn't there says so", set:remove("units/x") == false and set:remove("q", M2) == false)
    test("removing the map's one", set:remove("units/x", M1) == true and set:count() == 0)
end
-- }}}

-- {{{ Merging
test_section("merging sets: the first wins, conflicts listed")
do
    local mine = overrides.new("mine")
    mine:add({ path = "a", file = A })
    mine:add({ path = "b", file = B })
    local theirs = overrides.new("theirs")
    theirs:add({ path = "A.mdx", file = C })          -- conflicts with mine
    theirs:add({ path = "b", file = B })              -- the same file: no conflict
    theirs:add({ path = "c", file = C })
    theirs:add({ path = "a", file = C, map = M1 })    -- another scope: no conflict
    local both, conflicts = overrides.merge({ mine, theirs })
    test("every path and scope once", both:count() == 4, both:count())
    test("the first set wins", both:lookup("a").file == A)
    test("the second fills in", both:lookup("c").file == C and both:lookup("a", M1).file == C)
    test("one conflict, naming both sets", #conflicts == 1 and conflicts[1].kept == "mine"
        and conflicts[1].dropped == "theirs" and conflicts[1].path == "A.mdx", #conflicts)
    local _, unnamed = overrides.merge({ overrides.new(), theirs, mine })
    test("an unnamed set is named by its place", (function()
        local first = overrides.new(); first:add({ path = "a", file = B })
        local _, c = overrides.merge({ first, mine })
        return #c == 1 and c[1].kept == "set 1" and c[1].dropped == "mine"
    end)())
    test("the order decides", #unnamed == 1 and unnamed[1].kept == "theirs")
end
-- }}}

-- {{{ Files on disk
test_section("the player's file")
do
    local root = TMP .. "/root"
    os.execute("mkdir -p '" .. root .. "/player-data'")
    local path = overrides.file_for(root)
    test("it lives in the player data folder", path == root .. "/player-data/overrides.txt", path)
    local none = overrides.load(path)
    test("no file is no overrides", none:count() == 0)
    local set = assert(overrides.parse(GOOD))
    test("saved", overrides.save(set, path) == path)
    local f = io.open(path, "rb"); local text = f:read("*a"); f:close()
    test("the file holds the set", text == overrides.write(set))
    test("no part file is left", io.open(path .. ".part", "rb") == nil)
    test("loaded back", overrides.load(path):count() == 3)
    local g = io.open(path, "wb"); g:write("wete-overrides 1\noverride\tx\n"); g:close()
    local ok, err = pcall(overrides.load, path)
    test("a broken file is an error naming its problems", not ok and tostring(err):find(path .. ":2:", 1, true), err)
    local ok2, err2 = pcall(overrides.save, set, TMP .. "/no/such/folder/overrides.txt")
    test("a file that can't be written is an error", not ok2 and tostring(err2):find("can't write", 1, true), err2)
end
-- }}}

-- {{{ The chooser
test_section("the chooser: override, then the map's model, then a placeholder")
do
    local store = dedup.open(TMP .. "/blobs")
    local grim = store:store("GRIM FOOTMAN")
    local bad = store:store("NOT A MODEL")
    local set = overrides.new()
    set:add({ path = "Units\\Human\\Footman\\Footman", file = grim, scale = 1.5, tint = { 200, 200, 255 } })
    set:add({ path = "Units\\Orc\\Grunt\\Grunt", file = bad })
    set:add({ path = "Units\\Undead\\Ghoul\\Ghoul", file = C })             -- not in the store
    set:add({ path = "Units\\Human\\Peasant\\Peasant", file = grim, map = M1 })
    local asked = {}
    local function requested(path)
        asked[#asked + 1] = path
        local k = overrides.key(path)
        if k == "units/human/footman/footman" or k == "units/orc/grunt/grunt" or k == "units/human/peasant/peasant" then
            return { name = "map's " .. k }
        end
        if k == "units/broken" then error("bad bytes") end
        return nil
    end
    local function read(bytes)
        if bytes == "NOT A MODEL" then error("not mdx") end
        return { name = "override: " .. bytes }
    end
    local c = chooser.new({ overrides = set, store = store, map = M2, requested = requested, read = read })

    local m, source, look = c:choose("units/human/footman/footman.mdx")
    test("an override is drawn in place of the map's model", source == "override" and m and m.name == "override: GRIM FOOTMAN")
    test("with its look", look and look.scale == 1.5 and look.tint[3] == 255 and look.team_colour == true and look.file == grim)
    test("the map's model isn't even read", #asked == 0, #asked)
    m, source, look = c:choose("Units\\Orc\\Grunt\\Grunt")
    test("an override that doesn't read falls back to the map's", source == "requested" and m.name == "map's units/orc/grunt/grunt" and look == nil)
    m, source = c:choose("Units\\Undead\\Ghoul\\Ghoul")
    test("an override missing from the store falls back, then to a placeholder", source == "placeholder" and m == nil)
    m, source = c:choose("Units\\Human\\Peasant\\Peasant")
    test("another map's override doesn't apply here", source == "requested")
    m, source = c:choose("Units\\Nothing")
    test("a model nobody has is a placeholder", source == "placeholder" and m == nil)
    m, source = c:choose("Units\\Broken")
    test("a model that raises is a placeholder", source == "placeholder")
    local before = #asked
    c:choose("UNITS\\NOTHING.MDX"); c:choose("units/human/footman/footman")
    test("each path is chosen once", #asked == before, #asked)

    local n = c:counts()
    test("uses are counted by source", n.override == 2 and n.requested == 2 and n.placeholder == 4,
        string.format("%d %d %d", n.override, n.requested, n.placeholder))
    test("failed overrides are counted", n.override_failed == 2, n.override_failed)
    local ph = c:placeholders()
    test("each placeholder path once, in order", #ph == 3 and ph[1].path == "Units\\Undead\\Ghoul\\Ghoul"
        and ph[2].path == "Units\\Nothing" and ph[3].path == "Units\\Broken", #ph)
    test("with why", ph[1].reason:find("override failed", 1, true) and ph[1].reason:find("store has no", 1, true)
        and ph[2].reason:find("neither the map nor the install", 1, true) and ph[3].reason:find("bad bytes", 1, true))
    local fo = c:failed_overrides()
    test("failed overrides listed with why", #fo == 2 and fo[1].reason:find("doesn't read as a model", 1, true)
        and fo[2].path == "Units\\Undead\\Ghoul\\Ghoul")
    local report = c:report()
    test("the report counts and names them", report:find("2 from overrides, 2 as the map asks, 4 placeholders", 1, true)
        and report:find("placeholder: Units\\Nothing", 1, true) and report:find("override failed: Units\\Orc\\Grunt\\Grunt", 1, true), report)

    c:clear()
    local again = #asked
    c:choose("Units\\Nothing")
    test("clear forgets the choices", #asked == again + 1 and #c:placeholders() == 1)
    test("but keeps the counts", c:counts().placeholder == 5)

    local on_map = chooser.new({ overrides = set, store = store, map = M1, requested = requested, read = read })
    test("on its own map, the map's override applies", select(2, on_map:choose("units/human/peasant/peasant")) == "override")

    local plain = chooser.new({ requested = requested })
    test("without overrides, the map's model", select(2, plain:choose("Units\\Orc\\Grunt\\Grunt")) == "requested")
    test("needs requested", not pcall(chooser.new, {}))
    test("needs a store when there are overrides", not pcall(chooser.new, { overrides = set, requested = requested }))
    test("an empty set needs no store", pcall(chooser.new, { overrides = overrides.new(), requested = requested }))
    local nameless = chooser.new({ overrides = set, store = { path = function() error("no") end }, requested = requested })
    test("a store that can't name the file falls back", select(2, nameless:choose("units/human/footman/footman")) == "requested"
        and nameless:failed_overrides()[1].reason:find("can't name", 1, true))
    local default_read = chooser.new({ overrides = set, store = store, requested = requested })
    test("the default reader reads models (not these bytes)",
        select(2, default_read:choose("units/human/footman/footman")) == "requested")
end
-- }}}

if TMP:match("/test%-overrides%-%d+%-%d+$") then os.execute("rm -rf '" .. TMP .. "'") end

print(string.format("\n%d tests: %d passed, %d failed", test_count, pass_count, fail_count))
if fail_count > 0 then os.exit(1) end
