-- 066-checking-re-abstraction.lua
--
-- Checks issue 507, dynamic re-abstraction: the seeded shuffle and the
-- ladder of ever-wider groups; an inspection that cannot touch the design;
-- and the search on the notes fixture — a fault one narrow audit fixes
-- (the innocent parts left alone once the workflow passes), a fault only a
-- wider look can name (fixed by narrowing back), and a fault nobody finds.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs
local ledger = require("016-ledger")
local kinds = require("034-turn-kinds")
local outline = require("042-the-outline")
local describing = require("045-describing")
local building = require("050-building")
local re_abstraction = require("065-re-abstraction")

-- The shuffle: the same seed gives the same order; a different seed may not.
local seed = string.rep("ab", 32)
local a = re_abstraction.shuffle({ "102", "201", "301" }, seed)
local b = re_abstraction.shuffle({ "102", "201", "301" }, seed)
kit.equal(table.concat(a, " "), table.concat(b, " "), "the same seed gives the same order")
local seen = {}
for _, id in ipairs(a) do seen[id] = true end
kit.check(seen["102"] and seen["201"] and seen["301"] and #a == 3, "a shuffle keeps every id once")

-- The ladder, in the owner's example of three: one pair (the odd one left
-- out), then one group of all three.
local ladder = re_abstraction.ladder({ "a", "b", "c" })
kit.equal(#ladder, 2, "three issues: two wider levels")
kit.equal(table.concat(ladder[1][1], "+"), "a+b", "a pair, with c left out")
kit.equal(#ladder[1], 1, "only one pair")
kit.equal(table.concat(ladder[2][1], "+"), "a+b+c", "then everything at once")
local five = re_abstraction.ladder({ "a", "b", "c", "d", "e" })
kit.equal(#five[1], 2, "five issues: two pairs first")
kit.equal(table.concat(five[#five][1], "+"), "a+b+c+d+e", "and the last look holds all five")
kit.equal(#re_abstraction.ladder({ "a" }), 0, "one issue has no wider look")

-- An inspection writes no code.
kit.equal(table.concat(kinds.TABLE.inspect.writes, " "), "turn", "an inspection writes only in its own folder")
kit.equal(table.concat(kinds.TABLE.audit.writes, " "), "design/", "an audit writes the design")

-- {{{ local function described_case
local function described_case(label, options_text)
    local project, record = kit.fixture_case(label, options_text)
    describing.step(project, record, outline.step(project, record, {}), {})
    return project, record
end
-- }}}

-- {{{ local function lines_of
local function lines_of(record, kind)
    local out = {}
    for _, l in ipairs(ledger.read(record.ledger)) do
        if l.kind == kind then out[#out + 1] = l end
    end
    return out
end
-- }}}

-- A fault one narrow audit fixes.
local p1, r1 = described_case("narrow", 'quiet_bug = { ["201"] = 1 }')
local report1 = building.step(p1, r1, {})
kit.check(report1.delivered, "the quiet bug is found and fixed")
local audits1 = lines_of(r1, "audited")
local fixed_at
for i, l in ipairs(audits1) do
    if l.about == "201" and l.text:find("^changed") then fixed_at = i end
end
kit.check(fixed_at ~= nil, "201's audit changed the design")
kit.equal(fixed_at, #audits1, "and no audit came after the one that fixed it")
kit.equal(#lines_of(r1, "inspected"), 0, "no wider look was needed")
kit.equal(kit.turns_of(r1, "repair"), 0, "no issue was repaired blindly")
for _, l in ipairs(audits1) do
    if l.about ~= "201" then
        kit.check(l.text:find("^unchanged") ~= nil, "an innocent part audited before the fix was left unchanged: " .. l.about)
    end
end

-- A fault only a wider look names.
local p2, r2 = described_case("hidden", 'quiet_bug = { ["201"] = 1 }, hidden_bug = true')
local report2 = building.step(p2, r2, {})
kit.check(report2.delivered, "the hidden bug is found and fixed")
local inspections = lines_of(r2, "inspected")
kit.check(#inspections >= 1, "at least one wider look")
local named = inspections[#inspections]
kit.check(named.text:find("^201") ~= nil and named.about:find("201", 1, true) ~= nil,
    "the look that named the part held 201 and named it: " .. named.about .. " -> " .. named.text)
local audits2 = lines_of(r2, "audited")
kit.check(audits2[#audits2].about == "201" and audits2[#audits2].text:find("with a finding", 1, true) ~= nil,
    "the fix came from narrowing back to 201 with the finding in hand")
local singles_unchanged = 0
for i = 1, 3 do
    if audits2[i] and audits2[i].text:find("^unchanged") then singles_unchanged = singles_unchanged + 1 end
end
kit.equal(singles_unchanged, 3, "each part alone looked right first")

-- A fault nobody finds.
local p3, r3 = described_case("unfindable", 'quiet_bug = { ["201"] = 1 }, unfindable_bug = true')
local report3 = building.step(p3, r3, {})
kit.check(not report3.delivered, "a fault nobody finds is not delivered")
kit.check(#lines_of(r3, "workflow-failed") >= 1, "workflow-failed recorded")
local widest = lines_of(r3, "inspected")
kit.check(#widest >= 1 and select(2, widest[#widest].about:gsub("%+", "")) == 2,
    "the last look held all three covered issues: " .. (widest[#widest] and widest[#widest].about or "none"))

kit.check(ledger.verify(r2.ledger).ok, "the ledger verifies")
kit.finish()
