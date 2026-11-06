-- 124-checking-remaining-types.lua
--
-- Checks issue 902c: one fixture per remaining type is recognised --
-- `program`, `source`, `request`, `finding`, `results` -- and anything
-- matching none of the closed list is `unknown`, never assigned a guessed
-- type. Every name recognise() can answer is on the closed list, or is
-- `unknown`.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local shape_types = require("081-the-shape-types")

local fixtures = kit.project.fixtures .. "/shape-types"

-- {{{ local function file_type
local function file_type(name)
    return shape_types.recognise_file({ name = name, path = fixtures .. "/" .. name })
end
-- }}}

kit.equal(file_type("say-hello"), "program", "a script with a #! line is a program")
kit.equal(file_type("adder.lua"), "source", "a .lua file of code is source, by its name")
kit.equal(file_type("a-request.txt"), "request", "a parcel opening with a tag is a request")
kit.equal(file_type("a-finding.md"), "finding", "a ## heading with a Mechanism: line is a finding")
kit.equal(file_type("a-result.json"), "results", "a JSON object, as a harness writes result.json, is results")

-- program: by the executable bit too, when the path is known.
local scratch = kit.scratch("remaining-types")
kit.write_file(scratch .. "/run-me", "echo hi\n")
kit.fs.run("chmod +x " .. kit.fs.quote(scratch .. "/run-me"))
kit.equal(shape_types.recognise_file(scratch .. "/run-me"), "program", "an executable file is a program")
kit.write_file(scratch .. "/do-not-run-me", "echo hi\n")
kit.equal(shape_types.recognise_file(scratch .. "/do-not-run-me"), "text", "the same words, not executable, are text")

-- source needs a name: the same code with no path is only text.
kit.equal(shape_types.recognise(kit.fs.read(fixtures .. "/adder.lua")), "text",
    "code with no name to go by is text, not guessed to be source")
kit.equal(shape_types.recognise("1 2 3\n", scratch .. "/numbers.txt"), "integer-array",
    "a .txt of integers is still an integer array")

-- results: well-formed JSON objects and arrays only.
kit.equal(shape_types.recognise("[1, 2, 3]"), "results", "a JSON array is results")
kit.equal(shape_types.recognise("{}"), "results", "an empty JSON object is results")
kit.equal(shape_types.recognise('{"a": 1,}'), "text", "a trailing comma is not JSON")
kit.equal(shape_types.recognise('{"a": 01}'), "text", "a leading zero is not JSON")
kit.equal(shape_types.recognise('{"a": 1} trailing words'), "text", "words after the JSON are not results")
kit.equal(shape_types.recognise('{"a": "\\x"}'), "text", "a bad escape is not JSON")
kit.equal(shape_types.recognise("42"), "integer-array", "a bare JSON number is not results")
kit.equal(shape_types.recognise(string.rep("[", 500) .. string.rep("]", 500)), "text",
    "JSON nested past the limit is refused rather than read")

-- request and finding: the forms exactly.
kit.equal(shape_types.recognise("language model prompt: draw\n"), "text", "a malformed tag is not a request")
kit.equal(shape_types.recognise("## a heading\n\nno mechanism here\n"), "text", "a heading with no Mechanism: line is not a finding")

-- unknown, never a guess.
kit.equal(shape_types.recognise("\0\1\2\3\255"), "unknown", "bytes matching nothing are unknown")
kit.equal(shape_types.recognise(""), "unknown", "an empty file is unknown")
kit.equal(shape_types.recognise("  \n\t\n"), "unknown", "a file of nothing but space is unknown")
local listed = { unknown = true }
for _, name in ipairs(shape_types.TYPES) do listed[name] = true end
local samples = { "1 2", "1.5", "hi", "{}", "#!/bin/sh\n", "\0", "" }
local all_listed = true
for _, bytes in ipairs(samples) do
    if not listed[shape_types.recognise(bytes)] then all_listed = false end
end
kit.check(all_listed, "every answer is a type on the closed list, or unknown")

kit.finish()
