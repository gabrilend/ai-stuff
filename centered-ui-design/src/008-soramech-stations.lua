-- 008-soramech-stations.lua - the soramech engine, in Lua, for this program.
--
-- In plain terms: the program is a wiring diagram of small jobs ("boxes")
-- placed at "stations". A station has input slots; it runs when, and only
-- when, every slot holds a value. Whoever delivers the last missing value
-- notices, takes one value from each slot, and drops the job into the pool,
-- where whichever worker thread is free picks it up — first come, first
-- served. Nothing scans for work: finishing one job is what starts the next.
--
-- The full design (by the owner) is in
-- /mnt/mtwo/programs/sora/minimal-soramech/docs/ (read 001 to 006). This file
-- is the Lua route (open question 7): stations live on the main thread as
-- tables; the pool is a LÖVE channel any worker can pop from; workers report
-- back on a second channel, and the main thread delivers their results to
-- the next stations. That last part is the one difference from the C engine,
-- where the worker itself delivers: separate Lua states cannot share the
-- station tables, so delivery is routed through the main thread.
--
-- Data:
--   station   { name (string), box (string, the job's name in the workers'
--               dispatch table), slot_count (whole), slots (list of queues),
--               filled (whole: how many slots hold at least one value),
--               where (string: "pool" — run by a worker, or "here" — run on
--               the main thread), on_ready (function, for "here" stations),
--               static (any plain value handed to the box every time) }
--   task      { station index (whole), the popped inputs (plain values) },
--             pushed into the pool channel as a flat table

local M = {}

-- {{{ function M.new_map()
-- An empty map. `pool` is anything with a push(table) method: a LÖVE
-- channel in the game, a plain list in tests.
function M.new_map(pool)
    return { stations = {}, pool = pool, tasks_sent = 0 }
end
-- }}}

-- {{{ function M.add_station()
-- Places a box at a new station; returns the station's index.
function M.add_station(map, description)
    local slots = {}
    for slot = 1, description.slot_count do
        slots[slot] = { first = 1, last = 0 }
    end
    local station = {
        name = description.name,
        box = description.box,
        slot_count = description.slot_count,
        slots = slots,
        filled = 0,
        where = description.where,
        on_ready = description.on_ready,
        static = description.static,
    }
    -- A station must say where it runs; a typo would otherwise never run.
    if station.where ~= "pool" and station.where ~= "here" then
        error("soramech: station '" .. tostring(station.name)
            .. "' must run 'pool' or 'here', not " .. tostring(station.where), 2)
    end
    -- A "here" station needs the function it runs.
    if station.where == "here" and type(station.on_ready) ~= "function" then
        error("soramech: station '" .. tostring(station.name)
            .. "' runs here but has no on_ready function", 2)
    end
    map.stations[#map.stations + 1] = station
    return #map.stations
end
-- }}}

-- {{{ local function pop_inputs()
-- Takes the oldest value from every slot (they are all non-empty), keeping
-- the filled count true.
local function pop_inputs(station)
    local inputs = {}
    for slot_index = 1, station.slot_count do
        local queue = station.slots[slot_index]
        inputs[slot_index] = queue[queue.first]
        queue[queue.first] = nil
        queue.first = queue.first + 1
        -- this slot just ran dry: one fewer filled slot
        if queue.first > queue.last then
            station.filled = station.filled - 1
        end
    end
    return inputs
end
-- }}}

-- {{{ function M.deliver()
-- Puts a value into one slot of one station. If that completes the
-- station's inputs, the station runs: into the pool, or right here.
-- Returns true if the station ran.
function M.deliver(map, station_index, slot_index, value)
    local station = map.stations[station_index]
    -- delivering to a station that does not exist is a wiring mistake
    if station == nil then
        error("soramech: no station " .. tostring(station_index), 2)
    end
    local queue = station.slots[slot_index]
    -- delivering to a slot the station does not have is a wiring mistake
    if queue == nil then
        error("soramech: station '" .. station.name .. "' has no slot " .. tostring(slot_index), 2)
    end
    -- this slot was empty: it now counts as filled
    if queue.first > queue.last then
        station.filled = station.filled + 1
    end
    queue.last = queue.last + 1
    queue[queue.last] = value

    -- not every slot holds a value yet: the station waits
    if station.filled < station.slot_count then
        return false
    end
    local inputs = pop_inputs(station)
    -- runs in a worker: becomes a task in the pool, taken first come first served
    if station.where == "pool" then
        local task = { station_index }
        for input_index = 1, #inputs do
            task[input_index + 1] = inputs[input_index]
        end
        map.pool:push(task)
        map.tasks_sent = map.tasks_sent + 1
    else
        -- runs here, on the delivering thread
        station.on_ready(inputs, station.static)
    end
    return true
end
-- }}}

return M
