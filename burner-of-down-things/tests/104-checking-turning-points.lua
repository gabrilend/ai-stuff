-- 104-checking-turning-points.lua
--
-- Checks issue 1001b: a ledger with one of each turning-point kind segments
-- into that many chapters, in ledger order; a turn's own lines join the
-- chapter of the result they lead to; a stretch of one kind of work is one
-- chapter, but two failures in a row are two.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local ledger = require("016-ledger")
local story = require("103-the-story")

local folder = kit.scratch("turning-points")
local path = folder .. "/ledger"

ledger.create(path, "case notes opened on /src/notes")                      -- 1 opened
ledger.append(path, "surveyed", "-", "12 files, 2 languages")                 -- 2 surveyed
ledger.append(path, "turn-started", "0001-describe-101", "describe 101 by stand-in") -- 3
ledger.append(path, "turn-ended", "0001-describe-101", "kept: exit 0; 1 file(s) changed") -- 4
ledger.append(path, "described", "101", "attempt 1")                          -- 5 described
ledger.append(path, "request-received", "tags.txt", "noticed in input/")      -- 6 request
ledger.append(path, "turn-started", "0002-build-101", "build 101 by stand-in") -- 7
ledger.append(path, "turn-ended", "0002-build-101", "kept: exit 0; 2 file(s) changed") -- 8
ledger.append(path, "build-failed", "101", "tests still fail after 2 tries") -- 9 failure
ledger.append(path, "turn-started", "0003-repair-101", "repair 101 by stand-in") -- 10 repair
ledger.append(path, "turn-ended", "0003-repair-101", "kept: exit 0; 1 file(s) changed") -- 11
ledger.append(path, "built", "101", "acceptance passed")                      -- 12 built

local cut = story.chapters(ledger.read(path))
local expected = { "opened", "surveyed", "described", "request", "failure", "repair", "built" }

kit.equal(#cut.chapters, #expected, "one chapter per turning point")
for i, turning in ipairs(expected) do
    kit.equal(cut.chapters[i] and cut.chapters[i].turning, turning,
        "chapter " .. i .. " is the " .. turning .. " turning point, in ledger order")
end
kit.equal(#cut.waiting, 0, "nothing waits when the ledger ends on a turning point")

local described = cut.chapters[3]
kit.equal(described.first, 3, "the describe turn's own lines open the described chapter")
kit.equal(described.last, 5, "the described chapter ends at its result")

local told = {}
for _, chapter in ipairs(cut.chapters) do
    for _, line in ipairs(chapter.lines) do
        told[#told + 1] = line.seq
    end
end
kit.equal(#told, 12, "every line of the ledger is in some chapter")
local in_order = true
for i, seq in ipairs(told) do
    if seq ~= i then in_order = false end
end
kit.check(in_order, "the chapters together tell the lines once each, in ledger order")

-- A stretch of one kind of work is one chapter; failures are told one by one;
-- working lines at the very end wait for the chapter they belong to.
ledger.append(path, "described", "102", "added by request tags.txt")          -- 13
ledger.append(path, "described", "103", "added by request tags.txt")          -- 14
ledger.append(path, "build-failed", "102", "a test failed")                   -- 15
ledger.append(path, "build-failed", "103", "a test failed")                   -- 16
ledger.append(path, "goodbye", "-", "build: ok")                              -- 17

cut = story.chapters(ledger.read(path))
kit.equal(#cut.chapters, 10, "two described lines make one chapter; two failures make two")
kit.equal(cut.chapters[8].turning, "described", "the two described lines are one chapter")
kit.equal(cut.chapters[8].last - cut.chapters[8].first, 1, "that chapter tells both lines")
kit.equal(cut.chapters[9].thing, "102", "the first failure is its own chapter")
kit.equal(cut.chapters[10].thing, "103", "the second failure is its own chapter")
kit.equal(#cut.waiting, 1, "the trailing goodbye waits for the next chapter")
kit.equal(cut.waiting[1] and cut.waiting[1].seq, 17, "the waiting line is the goodbye")

kit.finish()
