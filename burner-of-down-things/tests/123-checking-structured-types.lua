-- 123-checking-structured-types.lua
--
-- Checks issue 902b: one fixture per structured type is recognised -- a
-- PNG as `image`, an MP4 and a GIF as `clip`, a Lua data file as `table`;
-- a corrupt PNG signature is not mistaken for an image; a table file is
-- loaded as data and never run for effect.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local shape_types = require("081-the-shape-types")

local fixtures = kit.project.fixtures .. "/shape-types"
local png = kit.fs.read(fixtures .. "/white-square.png")
-- The MP4 is named .clip: the monorepo's .gitignore keeps every *.mp4 out
-- of git, and the recogniser reads bytes, never a name.
local mp4 = kit.fs.read(fixtures .. "/black-square-mp4.clip")
local gif = kit.fs.read(fixtures .. "/gray-square.gif")
local station = kit.fs.read(fixtures .. "/a-station.lua")

kit.equal(shape_types.recognise(png), "image", "a PNG is an image")
kit.equal(shape_types.recognise(mp4), "clip", "an MP4 is a clip")
kit.equal(shape_types.recognise(gif), "clip", "a GIF is a clip")
kit.equal(shape_types.recognise(station), "table", "a Lua data file returning a table is a table")

-- One wrong byte in the PNG signature, and it is not an image.
local corrupt = png:sub(1, 1) .. "Q" .. png:sub(3)
kit.check(shape_types.recognise(corrupt) ~= "image", "a corrupt PNG signature is not mistaken for an image")
kit.check(shape_types.recognise(png:sub(1, 8)) ~= "image", "a PNG signature with nothing after it is not an image")
kit.check(shape_types.recognise("GIF89a") ~= "clip", "a GIF's six letters alone are not a clip")

-- Tables: data, never effects.
kit.equal(shape_types.recognise("return 5\n"), "text", "a Lua file returning a number is not a table")
kit.equal(shape_types.recognise("return {\n"), "text", "a Lua file that does not load is not a table")
local marker = kit.scratch("never-run") .. "/ran"
kit.equal(shape_types.recognise("os.execute('touch " .. marker .. "') return {}\n"), "text",
    "a file that reaches for os is not a table")
kit.check(not kit.fs.exists(marker), "and what it reached for never ran")
local started = os.clock()
kit.equal(shape_types.recognise("while true do end return {}\n"), "text", "a file that never finishes is not a table")
kit.equal(shape_types.recognise("return { ('x'):rep(1e9) }\n"), "text",
    "a file reaching for string methods is not a table")
kit.check(os.clock() - started < 5, "and neither one hangs the machine")
kit.equal(("x"):rep(3), "xxx", "string methods are back once the file has been looked at")
kit.check(shape_types.recognise(string.dump(function() return {} end)) ~= "table",
    "precompiled bytecode is never loaded as a table")

-- 902a's types still read as before.
kit.equal(shape_types.recognise("1 2 3\n"), "integer-array", "integers are still an integer array")
kit.equal(shape_types.recognise("hello world\n"), "text", "plain text is still text")

kit.finish()
