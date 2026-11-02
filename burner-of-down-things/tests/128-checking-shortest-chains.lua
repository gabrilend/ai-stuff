-- 128-checking-shortest-chains.lua
--
-- Checks issue 905b: `integer-array + text -> image` becomes
-- table -> chart -> png, the shortest chain through a station table, found
-- without a model; an impossible shape says which type cannot be reached.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local plans = require("127-plans")
local station_table = require("093-the-station-table")

-- A station table shaped like 902d's, holding the stations the issue's own
-- example needs (the real table holds only what is built today).
local rows = {
    { name = "table", input = "integer-array + text", output = "table" },
    { name = "txt-table", input = "table", output = "text" },
    { name = "chart", input = "table", output = "canvas" },
    { name = "png", input = "canvas", output = "image" },
    { name = "slow-way", input = "text", output = "canvas" },
    { name = "report", input = "results", output = "finding" },
}

-- {{{ local function names
local function names(plan)
    local out = {}
    for i, row in ipairs(plan) do out[i] = row.name end
    return table.concat(out, " -> ")
end
-- }}}

local plan = plans.find(rows, "integer-array + text", "image")
kit.equal(plan and names(plan), "table -> chart -> png", "integer-array + text -> image becomes table -> chart -> png")
kit.check(plan and plans.check(plan, "integer-array + text", "image"), "the plan found fits at every joint")

local same = plans.find(rows, "text + integer-array", "image")
kit.equal(same and names(same), "table -> chart -> png", "the order a compound shape is written in does not matter")
kit.equal(plans.canonical(" text +integer-array "), "integer-array + text", "a shape has one canonical form")

local longer = plans.find(rows, "table", "image")
kit.equal(longer and names(longer), "chart -> png",
    "the shortest chain is chosen, not the longer one through txt-table and slow-way")

local none = plans.find(rows, "image", "image")
kit.equal(none and #none, 0, "a parcel already of the wanted shape needs no stations")

local nothing, why = plans.find(rows, "results", "image")
kit.equal(nothing, nil, "an impossible plan is refused")
kit.check(why and why:find("'image' cannot be reached from 'results'", 1, true) ~= nil,
    "the refusal names the type that cannot be reached")
kit.check(why and why:find("reachable: finding", 1, true) ~= nil, "and what can be reached instead")

local _, never = plans.find(rows, "table", "clip")
kit.check(never and never:find("no station gives it", 1, true) ~= nil,
    "a type no station gives at all is said plainly")

-- The real station table, as it stands, plans the one step it can.
local real = plans.find(station_table.TABLE, "table", "text")
kit.equal(real and names(real), "txt-table", "the real station table feeds the search unchanged")

kit.finish()
