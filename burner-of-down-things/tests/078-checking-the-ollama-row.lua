-- 078-checking-the-ollama-row.lua
--
-- Checks issue 903a: the harness table has every field 037's other rows
-- have, and refuses to build a command for a turn with no model named.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local harnesses = require("037-the-harness-table")

local row = harnesses.TABLE.ollama
kit.check(row ~= nil, "the harness table has an ollama row")
kit.equal(row.name, "ollama", "the row names itself ollama")
kit.equal(row.cost, "local", "the row's cost is local")
kit.check(type(row.needs) == "table" and row.needs[1] == "ollama", "the row needs the ollama program")
kit.check(type(row.pool) == "number", "the row has a pool size")
kit.check(type(row.limit) == "number", "the row has a time limit")
kit.check(type(row.command) == "function", "the row has a command function")

local turn = { folder = "/tmp/burner-of-down-things-fixture-turn" }
kit.raises(function() row.command({}, turn) end, "turn.model",
    "a turn with no model named is refused, naming why")

turn.model = "llama3.2"
local line = row.command({}, turn)
kit.check(line:find("ollama run", 1, true) ~= nil, "the command runs ollama")
kit.check(line:find("llama3.2", 1, true) ~= nil, "the command names the turn's model")
kit.check(line:find("prompt.md", 1, true) ~= nil, "the command reads the turn's prompt")

kit.finish()
