#!/usr/bin/env luajit
-- test_route_b.lua - reading Liquipedia's infoboxes and comparing them with Route A
--
-- Hand-made infobox text checks the reader (fields over several lines, a
-- nested template, numbers with commas and comments), the verdict rules
-- (rounding, a blank cell the wiki writes as 0), and then, when the install
-- and the cache exist, the real Knight: its page as it stood under 1.29.2
-- gives the same hit points as the game's own 1.29.2 table (835).
--
-- Run: luajit src/tests/test_route_b.lua [DIR]
-- Issue: issues/112e-route-b-published-values-cross-check.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
local route_b = require("gamedata.route_b")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end

local page = table.concat({
    "Intro text.",
    "{{Infobox unit",
    "|name=Test Knight",
    "|id=hkni",
    "|hp=835",
    "|gold=2,45<!-- a comment -->",
    "|cooldown=1.40",
    "|abilities={{Abil|Defend}}",
    "and a second line",
    "|dmgbase2=0",
    "}}",
    "After the box.",
}, "\n")

local template, fields = route_b.parse_infobox(page)
test("template name", template == "Infobox unit", tostring(template))
test("plain field", fields.hp == "835")
test("field over two lines", fields.abilities == "{{Abil|Defend}}\nand a second line", fields.abilities)
test("the box ends at its closing braces", fields.dmgbase2 == "0", fields.dmgbase2)

-- Some item pages put several fields on one line; a link's pipe is not a cut.
local _, item = route_b.parse_infobox("{{Infobox item\n|name=Dagger\n|gold=800 |lumber=0 |hotkey=D\n|text=[[Blink|blinks]] away\n}}")
test("several fields on one line", item.gold == "800" and item.lumber == "0" and item.hotkey == "D", tostring(item.gold))
test("a link's pipe stays in its value", item.text == "[[Blink|blinks]] away", tostring(item.text))
test("an underscore in the template name is a space", route_b.parse_infobox("{{Infobox_building\n|id=hcas\n}}") == "Infobox building")

local n, d = route_b.number(fields.gold)
test("number: comma and comment removed", n == 245 and d == 0, tostring(n))
n, d = route_b.number(fields.cooldown)
test("number: decimals counted", n == 1.4 and d == 2)
test("number: text is not a number", route_b.number("varies") == nil)

-- A made-up Route A with one row, to check the verdicts end to end.
local a = { tables = {
    UnitBalance = { rows = { hkni = { HP = 835, goldcost = 245 } } },
    UnitWeapons = { rows = { hkni = { cool1 = 1.4 } } },
    UnitData = { rows = { hkni = {} } },
} }
local rows = route_b.compare_page(a, page, "Test Knight")
local by = {}
for _, r in ipairs(rows or {}) do by[r.field] = r.verdict end
test("hp matches", by.hp == "match", tostring(by.hp))
test("gold matches", by.gold == "match", tostring(by.gold))
test("cooldown within the page's rounding", by.cooldown == "match", tostring(by.cooldown))
test("an unused second weapon written as 0", by.dmgbase2 == "blank_is_zero", tostring(by.dmgbase2))
local castle = route_b.compare_page(a, "{{Infobox_building\n|id=hkni\n|hp=835 / 1336\n}}", "x")
test("'base / upgraded' reads the base", castle[1].verdict == "match" and castle[1].form == "base / upgraded", castle[1].verdict)
local wrong = route_b.compare_page(a, page:gsub("|hp=835", "|hp=885"), "Test Knight")
local hp_verdict
for _, r in ipairs(wrong) do if r.field == "hp" then hp_verdict = r.verdict end end
test("a different number is a mismatch", hp_verdict == "mismatch")

-- An upgraded building: the game counts the whole chain (Town Hall 385 +
-- Keep 320 = 705), the page the step (320). Proven by the sum; a sum that
-- doesn't add up stays a mismatch.
local chain_a = { upgraded_from = { hkee = "htow" }, tables = {
    UnitBalance = { rows = { htow = { goldcost = 385 }, hkee = { goldcost = 705 } } },
    UnitWeapons = { rows = {} }, UnitData = { rows = {} } } }
local keep = route_b.compare_all(chain_a, {
    Keep = { text = "{{Infobox building\n|id=hkee\n|gold=320\n}}", source = "old", no_old = false },
    Wrong = { text = "{{Infobox building\n|id=hkee\n|gold=300\n}}", source = "old", no_old = false },
    Later = { text = "{{Infobox building\n|id=htow\n|gold=400\n}}", source = "current", no_old = true } })
local by_title = {}
for _, r in ipairs(keep.rows) do by_title[r.title] = r.verdict end
test("an upgrade's step plus the earlier building is the game's cost", by_title.Keep == "upgrade_step", tostring(by_title.Keep))
test("a step that doesn't add up stays a mismatch", by_title.Wrong == "mismatch", tostring(by_title.Wrong))
test("a page written after 1.30 is not checkable", by_title.Later == "later_page", tostring(by_title.Later))

local cache = DIR .. "/wc3-installs/external-values"
local knight = io.open(cache .. "/old/Knight.wikitext", "r")
local install = io.open(DIR .. "/wc3-installs/frozen-throne/War3x.mpq", "r")
if not knight or not install then
    print("  [SKIP] the real Knight -- needs the install and the Knight's old revision cached (luajit src/cli/route-b-fetch.lua) --")
else
    local text = knight:read("*a")
    knight:close(); install:close()
    local real_a = route_b.load_route_a(DIR .. "/wc3-installs/frozen-throne", DIR .. "/wc3-installs/patch-layers")
    local real = route_b.compare_page(real_a, text, "Knight")
    local hp
    for _, r in ipairs(real or {}) do if r.field == "hp" then hp = r end end
    test("the Knight's hit points under 1.29.2: both routes say 835", hp and hp.a == 835 and hp.b == 835 and hp.verdict == "match",
        hp and (tostring(hp.a) .. " / " .. tostring(hp.b)) or "no hp row")
end

print(string.format("%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
