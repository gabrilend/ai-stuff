-- 129-checking-joint-checks.lua
--
-- Checks issue 905c: a plan with one mismatched joint is refused before its
-- first station runs, naming the joint; so is a plan whose start or end
-- does not fit.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local plans = require("127-plans")

local ran = {}
-- {{{ local function station
local function station(name, input, output)
    return { name = name, input = input, output = output,
        run = function(value) ran[#ran + 1] = name; return value end }
end
-- }}}

local table_station = station("table", "integer-array + text", "table")
local chart = station("chart", "table", "canvas")
local png = station("png", "canvas", "image")
local wrong = station("png-of-text", "text", "image")

kit.check(plans.check({ table_station, chart, png }, "integer-array + text", "image"), "a plan that fits passes")

local result, why = plans.run({ table_station, chart, wrong }, "integer-array + text", "image", {}, kit.scratch("joints"))
kit.equal(result, nil, "a plan with one mismatched joint is refused")
kit.equal(#ran, 0, "and refused before its first station runs")
kit.check(why and why:find("joint 2 does not fit: 'chart' gives 'canvas' but 'png-of-text' takes 'text'", 1, true) ~= nil,
    "the refusal names the mismatched joint and both its sides")

local _, start = plans.check({ chart, png }, "text", "image")
kit.check(start and start:find("the start does not fit", 1, true) ~= nil, "a start the first station does not take is refused")
local _, finish = plans.check({ table_station, chart }, "integer-array + text", "image")
kit.check(finish and finish:find("the end does not fit: 'chart' gives 'canvas' but 'image' is wanted", 1, true) ~= nil,
    "an end that does not give the wanted shape is refused")
local _, empty = plans.check({}, "text", "image")
kit.check(empty ~= nil, "an empty plan cannot turn one shape into another")

kit.finish()
