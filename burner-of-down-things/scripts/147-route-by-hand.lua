#!/usr/bin/env luajit
-- 147-route-by-hand.lua
--
-- Issue 904's second step, run by the owner by hand: routes one parcel
-- folder with a real model through the `ollama` row (903) and prints every
-- prompt the router was handed, every answer the model gave, why any
-- answer was sent back, and the outcome. It writes no ledger and touches
-- no case: each attempt's turn folder is kept under the project's scratch
-- space, and its path is printed so the files can be read afterwards.
--
-- Usage:
--   luajit scripts/147-route-by-hand.lua [project folder] <parcel folder> [model]
--   (the model defaults to the switchboard's router_model setting, 090;
--   with neither, it refuses rather than guess one)

local DIR = "/mnt/mtwo/programming/ai-stuff/burner-of-down-things"
local args = { ... }
-- The first argument is the project folder when it is one (it holds
-- src/013-paths.lua); otherwise DIR above is the project.
if args[1] and io.open(args[1] .. "/src/013-paths.lua", "rb") then
    DIR = table.remove(args, 1)
end
local parcel_folder, model = args[1], args[2]
if not parcel_folder then
    io.stderr:write("usage: 147-route-by-hand.lua [project folder] <parcel folder> [model]\n")
    os.exit(2)
end

package.path = DIR .. "/src/?.lua;" .. package.path
local paths = require("013-paths")
local fs = require("017-the-filesystem")
local parcel = require("079-the-parcel")
local settings = require("090-switchboard-settings")
local stations = require("093-the-station-table")
local router = require("141-the-router")

local project = paths.for_project(DIR)
model = model or settings.read(project).router_model
if not model then
    io.stderr:write("route-by-hand: no model named, and no router_model in "
        .. settings.path(project) .. "; name one, e.g. llama3.2:1b\n")
    os.exit(1)
end

local p = parcel.read(parcel_folder)
if not p then
    io.stderr:write("route-by-hand: nothing in " .. parcel_folder .. "\n")
    os.exit(1)
end

local turns = string.format("%s/route-by-hand/%s-%d", project.scratch, os.date("%Y%m%d-%H%M%S"), math.random(1000, 9999))
fs.make_folder(turns)

local ask = router.harness_asker(project, turns, model)
local function loud_ask(prompt, attempt)
    io.write("---- attempt ", attempt, ": the prompt ----\n", prompt)
    local answer, why = ask(prompt, attempt)
    io.write("---- attempt ", attempt, ": the answer ----\n", tostring(answer or ("(none: " .. tostring(why) .. ")")), "\n")
    return answer, why
end

local result = router.route({ rows = stations.TABLE, parcel = p, ask = loud_ask })
io.write("---- outcome ----\n")
if result.status == "routed" then
    io.write(string.format("routed: shape %s, station %s, after %d attempt(s)\n", result.shape, result.station, result.attempts))
else
    io.write("waiting for the person after ", result.attempts, " attempts; sent back:\n")
    for i, why in ipairs(result.sent_back) do
        io.write("  ", i, ". ", why, "\n")
    end
end
io.write("turn folders: ", turns, "\n")
os.exit(result.status == "routed" and 0 or 3)
