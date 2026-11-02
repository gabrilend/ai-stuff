-- 130-checking-plan-execution.lua
--
-- Checks issue 905d: a two-station plan runs end to end, each result kept
-- as a new parcel and handed to the next station, and every intermediate
-- parcel is kept; a station that fails stops the plan, naming it, and the
-- parcels before it stay.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local plans = require("127-plans")
local parcel = require("079-the-parcel")
local text_tables = require("014-text-tables")
local station_table = require("093-the-station-table")

-- A station of the test's own: lines of "name count" text into a table of
-- rows; then the real 807a table station renders it back as text.
local split = {
    name = "split", input = "text", output = "table",
    run = function(text)
        local rows = {}
        for line in text:gmatch("[^\n]+") do
            local cells = {}
            for cell in line:gmatch("%S+") do cells[#cells + 1] = cell end
            rows[#rows + 1] = cells
        end
        return rows
    end,
}
local txt_table = station_table.TABLE[1]

local plan = plans.find({ split, txt_table }, "text", "text + table")
kit.equal(plan, nil, "a shape no station gives is not planned")
plan = { split, txt_table }
local keep = kit.scratch("plan-execution")
local done, why = plans.run(plan, "text", "text", "notes 12\ntags 3\nledger 100\n", keep)

kit.check(done ~= nil, "a two-station plan runs end to end" .. (why and (": " .. why) or ""))
kit.equal(done and done.result, "notes   12\ntags    3\nledger  100", "the last station's result is the plan's result")
kit.equal(done and #done.parcels, 2, "every station's result is kept as a parcel")

local first = done and parcel.read(done.parcels[1].folder)
kit.check(first and first.files[1].name == "result.lua", "the first result, a table, is kept as a record")
local kept_rows = first and text_tables.read_record(first.files[1].path)
kit.equal(kept_rows and kept_rows[3][2], "100", "the kept intermediate parcel holds what was handed on")
local second = done and parcel.read(done.parcels[2].folder)
kit.equal(second and kit.fs.read(second.files[1].path), done and done.result, "the last parcel is kept too")
kit.equal(done and done.parcels[1].folder, keep .. "/01-split", "parcels are kept in running order, named by station")

-- A station that fails stops the plan, naming it; what ran before is kept.
local broken = { name = "broken", input = "table", output = "text", run = function() error("the paint ran out") end }
local keep2 = kit.scratch("plan-failure")
local failed, failure, kept = plans.run({ split, broken }, "text", "text", "a 1\n", keep2)
kit.equal(failed, nil, "a failing station stops the plan")
kit.check(failure and failure:find("station 2, 'broken', failed: ", 1, true) ~= nil, "the failure names the station")
kit.equal(kept and #kept, 1, "the parcel before the failure is kept")
kit.check(kit.fs.exists(keep2 .. "/01-split/result.lua"), "on disk")

kit.finish()
