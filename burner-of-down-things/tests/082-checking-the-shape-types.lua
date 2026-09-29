-- 082-checking-the-shape-types.lua
--
-- Checks issue 902a: one fixture per scalar type is recognised; a file
-- matching none of the three falls through rather than being guessed.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local shape_types = require("081-the-shape-types")

kit.equal(shape_types.recognise("1 2 3\n4 5 6\n"), "integer-array", "whitespace-separated integers")
kit.equal(shape_types.recognise("-7\n"), "integer-array", "a single negative integer")
kit.equal(shape_types.recognise("1.5 2.0 -3.25\n"), "number-array", "numbers with fractional parts")
kit.equal(shape_types.recognise("hello world\nthis is plain text\n"), "text", "plain ascii text")
kit.equal(shape_types.recognise("café menu\n"), "text", "well-formed multi-byte UTF-8 is text")

-- A lone UTF-8 continuation byte (0x80) with nothing to continue: not
-- integers, not numbers, not well-formed UTF-8 — falls through to nil.
kit.equal(shape_types.recognise("\128\129\130"), nil, "malformed bytes fall through, never guessed")

for _, name in ipairs(shape_types.TYPES) do
    kit.check(type(name) == "string", "every type name is a string")
end
kit.check(#shape_types.TYPES == 11, "the closed list holds all eleven types")

kit.finish()
