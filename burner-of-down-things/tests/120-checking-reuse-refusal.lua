-- 120-checking-reuse-refusal.lua
--
-- Checks issue 901d: a fresh number is recorded once and accepted; a
-- reused number is refused, naming its first use (case and ledger line);
-- a number the machine has not given yet is refused, naming the next free
-- one; a parcel with no tag is accepted and records nothing.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local case = require("018-the-case")
local ledger = require("016-ledger")
local parcel = require("079-the-parcel")
local numbers = require("117-tag-numbers")

local project, folder = kit.project_copy("reuse-refusal")
local source = folder .. "/source"
kit.write_file(source .. "/a.lua", "print('a')\n")
local notes = case.open(project, "notes", source, "stand-in")
local receipts = case.open(project, "receipts", source, "stand-in")

-- {{{ local function a_parcel
local function a_parcel(label, first_line)
    local where = kit.scratch(label)
    kit.write_file(where .. "/a.txt", first_line .. "\n1 2 3\n")
    return parcel.read(where)
end
-- }}}

-- {{{ local function numbered_lines
local function numbered_lines(record)
    local n = 0
    for _, line in ipairs(ledger.read(record.ledger)) do
        if line.kind == "numbered" then n = n + 1 end
    end
    return n
end
-- }}}

local first = numbers.accept(project, notes, a_parcel("first", "language model prompt 1: draw a circle"))
kit.check(first and first.tagged, "a fresh number is accepted")
kit.equal(first and first.number, 1, "its number is read")
kit.equal(numbered_lines(notes), 1, "a fresh number is recorded in the ledger once")
local recorded_line = ledger.read(notes.ledger)[first.line]
kit.equal(recorded_line.kind .. " " .. recorded_line.about .. " " .. recorded_line.text, "numbered 1 draw a circle",
    "the ledger line records the number and the wish")

local again, finding = numbers.accept(project, receipts, a_parcel("reused", "language model prompt 1: draw a square"))
kit.equal(again, nil, "a reused number is refused, even arriving at another case")
kit.check(finding and finding:find("number 1 was first used in case notes, ledger line " .. first.line, 1, true) ~= nil,
    "the refusal names the first use: its case and ledger line")
kit.equal(numbered_lines(receipts), 0, "a refused number is not recorded again")

local ahead, ahead_finding = numbers.accept(project, receipts, a_parcel("ahead", "language model prompt 14597: draw a star"))
kit.equal(ahead, nil, "a number the machine has not given is refused")
kit.check(ahead_finding and ahead_finding:find("the next free number is 2", 1, true) ~= nil,
    "the refusal names the next free number")

local second = numbers.accept(project, receipts, a_parcel("second", "language model prompt 2: sum these"))
kit.check(second and second.tagged and second.number == 2, "the next free number is accepted at any case")
kit.equal(numbers.next_free(project), 3, "and the next free number moves on")

local plain = numbers.accept(project, notes, a_parcel("plain", "just some numbers"))
kit.check(plain and plain.tagged == false, "a parcel with no tag is accepted as it is")
kit.equal(numbered_lines(notes), 1, "and records nothing")

local bad, bad_finding = numbers.accept(project, notes, a_parcel("bad", "language model prompt: draw"))
kit.equal(bad, nil, "a malformed tag is refused")
kit.check(bad_finding and bad_finding:find("<number>: <what is wanted>", 1, true) ~= nil,
    "with 901b's finding naming the right form")

kit.check(ledger.verify(notes.ledger).ok and ledger.verify(receipts.ledger).ok,
    "both ledgers still verify after the numbers are recorded")

kit.finish()
