-- 009-soramech-worker.lua - the body of one worker thread.
--
-- In plain terms: each worker waits at the pool. Whenever a job is there,
-- the first free worker takes it (first come, first served), looks up which
-- box the job's station runs, runs it against the shared memory, and reports
-- "done" for that station. Then it goes back to the pool. Workers never talk
-- to each other and never decide what runs next: the wiring does that.
--
-- Started by the game with love.thread.newThread; it receives, once, on the
-- "worker-setup" channel, a flat table:
--   [1] block A, [2] block B (byte data: the two unit blocks),
--   [3] header (byte data), [4] fold strength, [5] tiers shown,
--   [6] hub radius, [7] edge radius, [8] first move station index,
--   [9] unit count
-- then loops on the "soramech-pool" channel. A task is a flat table
-- { station index, step number }. The string "stop" ends the loop.

require("love.data")
require("love.thread")
local records = require("005-unit-records")
local move_box = require("006-the-move-box")

local setup = love.thread.getChannel("worker-setup"):demand()
local pool = love.thread.getChannel("soramech-pool")
local done = love.thread.getChannel("soramech-done")

local block_a = records.records_at(setup[1]:getFFIPointer())
local block_b = records.records_at(setup[2]:getFFIPointer())
local header = records.header_at(setup[3]:getFFIPointer())
local fold = {
    strength = setup[4],
    tiers_shown = setup[5],
    hub_radius = setup[6],
    edge_radius = setup[7],
}
local first_move_station = setup[8]
local unit_count = setup[9]

-- {{{ local function run_move_unit()
-- The move box at its station: the station's index says which unit; the
-- header says which block is front and how long the step lasts.
local function run_move_unit(station_index)
    local unit_index = station_index - first_move_station
    -- a station index outside the move stations is a wiring mistake
    if unit_index < 0 or unit_index >= unit_count then
        error("worker: station " .. station_index .. " is not a move station")
    end
    -- front is block A when the header says 0, block B when it says 1
    if header[0].front < 0.5 then
        move_box.move_unit(block_a, block_b, unit_index, header[0].step_seconds, fold)
    else
        move_box.move_unit(block_b, block_a, unit_index, header[0].step_seconds, fold)
    end
end
-- }}}

-- Which box each kind of task runs. One entry today; the dispatch table is
-- where new boxes join.
local BOXES = {
    move_unit = run_move_unit,
}

-- {{{ local function work()
local function work()
    while true do
        local task = pool:demand()
        -- the game is closing: leave the loop
        if task == "stop" then
            return
        end
        local station_index = task[1]
        -- every task in this program today is a move; the box name is fixed
        -- here until a second box kind arrives with its own station range
        BOXES.move_unit(station_index)
        done:push(station_index)
    end
end
-- }}}

work()
