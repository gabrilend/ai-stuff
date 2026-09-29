-- 087-checking-the-storyteller-kind.lua
--
-- Checks issue 1001a: a storyteller turn's reads name only the ledger and
-- requests, and its writes name only the story file.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local kinds = require("034-turn-kinds")

local project, record = kit.fixture_case("storyteller-kind")

local turn = kinds.make_turn(record, "storyteller", {
    about = record.name,
    story_path = "output/story/" .. record.name .. ".md",
    ledger_text = "(the ledger, for the test)",
    requests_text = "(no requests yet)",
})

kit.equal(turn.kind, "storyteller", "the turn's kind is storyteller")
kit.equal(#turn.reads, 2, "the storyteller turn reads exactly two paths")

local reads_ledger, reads_input = false, false
for _, path in ipairs(turn.reads) do
    if path == record.ledger then reads_ledger = true end
    if path == record.input .. "/" then reads_input = true end
end
kit.check(reads_ledger, "the storyteller turn reads the ledger")
kit.check(reads_input, "the storyteller turn reads input/")

kit.equal(#turn.writes, 1, "the storyteller turn writes exactly one path")
kit.equal(turn.writes[1], record.folder .. "/output/story/" .. record.name .. ".md",
    "the storyteller turn writes only the story file")

kit.check(turn.prompt:find("turn: storyteller " .. record.name, 1, true) ~= nil,
    "the prompt names the turn and the case")
kit.check(kinds.reads_source("storyteller") == false,
    "the storyteller never reads the source (it works from the ledger alone)")

kit.finish()
