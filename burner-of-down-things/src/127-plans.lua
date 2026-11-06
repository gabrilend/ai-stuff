-- 127-plans.lua
--
-- Plans joined by shape (docs/068, issue 905). When no single station
-- takes a parcel's shape to the one wanted, the switchboard plans a chain
-- of stations through the station table, each one's output the next one's
-- input -- found by a search over shapes, never by a model (905b); every
-- joint checked before the first station runs (905c); then run in order,
-- each result kept as a new parcel and handed on (905d).
--
-- A shape is a string. Several inputs are one shape written with `+`
-- ("integer-array + text"); the order they are written in does not matter,
-- so every shape is put in one canonical form before it is compared.
-- Works on any rows shaped like 902d's station table ({name, input,
-- output, run}), so it can be proven against a fixture table before the
-- real table holds the stations a long plan needs.

local fs = require("017-the-filesystem")
local text_tables = require("014-text-tables")
local shape_graph = require("083-the-shape-graph")

local plans = {}

-- {{{ function plans.canonical
-- A shape in one form: its parts trimmed, sorted, joined by " + ".
function plans.canonical(shape)
    if type(shape) ~= "string" or not shape:match("%S") then
        error("plans: a shape is a non-empty string, got " .. tostring(shape))
    end
    local parts = {}
    for part in shape:gmatch("[^+]+") do
        part = part:match("^%s*(.-)%s*$")
        if part == "" then
            error("plans: a shape has an empty part: '" .. shape .. "'")
        end
        parts[#parts + 1] = part
    end
    table.sort(parts)
    return table.concat(parts, " + ")
end
-- }}}

-- {{{ function plans.find
-- The shortest chain of stations from shape `from` to shape `wanted`
-- (905b): a breadth-first search over 905a's shape graph, edges tried in
-- row order, so the same table always gives the same plan. Returns the
-- array of rows in running order (empty when `from` already is `wanted`),
-- or nil and a sentence naming the type that cannot be reached and what
-- can be reached instead.
function plans.find(rows, from, wanted)
    from, wanted = plans.canonical(from), plans.canonical(wanted)
    local canonical_rows = {}
    for i, row in ipairs(rows) do
        canonical_rows[i] = { name = row.name, input = plans.canonical(row.input),
            output = plans.canonical(row.output), row = row }
    end
    local graph = shape_graph.build(canonical_rows)
    local came_by = { [from] = false }
    local queue, head = { from }, 1
    while head <= #queue do
        local shape = queue[head]
        head = head + 1
        if shape == wanted then
            break
        end
        for i, edge in ipairs(graph.edges) do
            if edge.from == shape and came_by[edge.to] == nil then
                came_by[edge.to] = { shape = shape, row = canonical_rows[i].row }
                queue[#queue + 1] = edge.to
            end
        end
    end
    if came_by[wanted] == nil then
        local reached = {}
        for _, shape in ipairs(queue) do
            if shape ~= from then
                reached[#reached + 1] = shape
            end
        end
        local gives_wanted = false
        for _, edge in ipairs(graph.edges) do
            if edge.to == wanted then gives_wanted = true end
        end
        local why = gives_wanted
            and ("no chain of stations leads there from " .. from)
            or "no station gives it"
        return nil, string.format("'%s' cannot be reached from '%s': %s; reachable: %s", wanted, from, why,
            #reached > 0 and table.concat(reached, ", ") or "nothing")
    end
    local chain = {}
    local shape = wanted
    while came_by[shape] do
        table.insert(chain, 1, came_by[shape].row)
        shape = came_by[shape].shape
    end
    return chain
end
-- }}}

-- {{{ function plans.check
-- Every joint of a plan, before anything runs (905c): the first station
-- takes `from`, each station's output is the next one's input, and the
-- last gives `wanted`. Returns true, or nil and a sentence naming the
-- joint that does not fit -- a plan found by `find` always fits; one
-- handed over by the router or a person may not.
function plans.check(plan, from, wanted)
    if #plan == 0 then
        if plans.canonical(from) == plans.canonical(wanted) then
            return true
        end
        return nil, "an empty plan cannot turn '" .. from .. "' into '" .. wanted .. "'"
    end
    if plans.canonical(plan[1].input) ~= plans.canonical(from) then
        return nil, string.format("the start does not fit: the parcel is '%s' but '%s' takes '%s'",
            from, plan[1].name, plan[1].input)
    end
    for i = 1, #plan - 1 do
        local a, b = plan[i], plan[i + 1]
        if plans.canonical(a.output) ~= plans.canonical(b.input) then
            return nil, string.format("joint %d does not fit: '%s' gives '%s' but '%s' takes '%s'",
                i, a.name, a.output, b.name, b.input)
        end
    end
    local last = plan[#plan]
    if plans.canonical(last.output) ~= plans.canonical(wanted) then
        return nil, string.format("the end does not fit: '%s' gives '%s' but '%s' is wanted",
            last.name, last.output, wanted)
    end
    return true
end
-- }}}

-- {{{ local function keep_parcel
-- One station's result kept as a parcel of its own (079's form: a folder
-- of files): text as `result.txt`, a table as the record `result.lua`.
local function keep_parcel(folder, value)
    fs.make_folder(folder)
    if type(value) == "string" then
        fs.write(folder .. "/result.txt", value)
    elseif type(value) == "table" then
        text_tables.write_record(folder .. "/result.lua", value)
    else
        fs.write(folder .. "/result.txt", tostring(value))
    end
    return folder
end
-- }}}

-- {{{ function plans.run
-- Runs a plan on a parcel's value (905d): checks every joint first and
-- refuses, running nothing, when one does not fit; then each station in
-- order, its result kept as a new parcel in `keep_folder/NN-<station>/`
-- and handed to the next. A station that fails stops the plan; the
-- parcels kept so far stay, and the failure names the station. Returns
-- { result, parcels = array of {station, folder} }, or nil and why.
function plans.run(plan, from, wanted, value, keep_folder)
    local fits, why = plans.check(plan, from, wanted)
    if not fits then
        return nil, "refused before anything ran: " .. why
    end
    local parcels = {}
    for i, row in ipairs(plan) do
        local ok, result = pcall(row.run, value)
        if not ok then
            return nil, string.format("station %d, '%s', failed: %s", i, row.name, tostring(result)), parcels
        end
        local folder = keep_parcel(string.format("%s/%02d-%s", keep_folder, i, row.name), result)
        parcels[#parcels + 1] = { station = row.name, folder = folder }
        value = result
    end
    return { result = value, parcels = parcels }
end
-- }}}

return plans
