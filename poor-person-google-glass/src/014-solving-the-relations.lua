-- 014-solving-the-relations.lua - statements into numbers.
--
-- In plain terms: the reader (013) gives sentences like "the lid is slightly
-- wider than the drum" and "the lid sits on top of the drum" as statements.
-- Here they become numbers, in three passes:
--   sizes       each part's three extents (along its axis, across, deep)
--   directions  which world axis each part's own axis runs along
--   places      each part's middle point
-- Each pass handles a part only after every part it mentions, so every
-- name becomes a number exactly once. A part mentioning a part that
-- mentions it back (a circle) has no first one to solve, and is refused.
--
-- Units: a part of any kind with no size sentence keeps its kind's default
-- extents (docs/shape-words.md), so 1 unit is the width of a default part,
-- and every size said in a description is a multiple of that.
--
-- World directions: x left to right, y up, z toward the viewer. A part's
-- extents sit on the world axes according to its axis (AXIS_LAYOUT).
--
-- Result: { parts = list of solved part (in the order they were named),
--           assumptions = list of { part = name, text = string } }
-- solved part = { name, kind, colour = {r,g,b}, line,
--                 extents = { along, across, deep } (numbers),
--                 axis = "x"|"y"|"z", centre = { x, y, z } }

local words = require("012-the-shape-words")

local M = {}

-- Which extent lies along each world axis (x, y, z), for each part axis.
M.AXIS_LAYOUT = {
    y = { "across", "along", "deep" },
    x = { "along", "across", "deep" },
    z = { "across", "deep", "along" },
}
local AXIS_INDEX = { x = 1, y = 2, z = 3 }

-- Each place word to the world direction it moves in (index, sign);
-- places with no direction keep the other part's middle.
local PLACE_DIRECTION = {
    top = { 2, 1 }, bottom = { 2, -1 }, right = { 1, 1 }, left = { 1, -1 },
    front = { 3, 1 }, back = { 3, -1 },
}

-- {{{ local function in_order()
-- The parts in an order where each comes after those it depends on.
-- depends(name) -> list of { other = name, line = whole }. Circles are
-- reported through refuse(line, message) once each, and the parts in them
-- are left out of the order.
local function in_order(parts, depends, pass_name, refuse)
    local order, state, stack = {}, {}, {}
    local function visit(name)
        if state[name] == "done" then return true end
        if state[name] == "visiting" then
            -- the circle is the stack from this name's first appearance
            local circle, lines = {}, {}
            local from = 0
            for i, entry in ipairs(stack) do if entry.name == name then from = i end end
            for i = from, #stack do
                circle[#circle + 1] = stack[i].name
                if stack[i].line then lines[#lines + 1] = stack[i].line end
            end
            circle[#circle + 1] = name
            refuse(lines[1] or 0, pass_name .. " go round in a circle: " .. table.concat(circle, " -> ")
                .. " (lines " .. table.concat(lines, ", ") .. ")")
            return false
        end
        state[name] = "visiting"
        local fine = true
        for _, dependency in ipairs(depends(name)) do
            stack[#stack + 1] = { name = name, line = dependency.line }
            if not visit(dependency.other) then fine = false end
            stack[#stack] = nil
        end
        state[name] = "done"
        if fine then order[#order + 1] = name end
        return fine
    end
    for _, part in ipairs(parts) do visit(part.name) end
    return order
end
-- }}}

-- {{{ local function largest()
local function largest(extents) return math.max(extents.along, extents.across, extents.deep) end
-- }}}

-- {{{ local function extent_value()
-- One named extent of a solved part ("thin" is its kind's thinnest,
-- "all" its largest).
local function extent_value(part, extent)
    if extent == "all" then return largest(part.extents) end
    if extent == "thin" then return part.extents[words.KINDS[part.kind].thin] end
    return part.extents[extent]
end
-- }}}

-- {{{ local function solve_size()
-- One part's extents from its kind and its size sentences.
local function solve_size(part, statements, solved, refuse, assume)
    local kind = words.KINDS[part.kind]
    local base = { along = kind.along, across = kind.across, deep = kind.deep }
    local explicit, whole = {}, nil

    for _, s in ipairs(statements) do
        if s.type == "proportion" and s.how == "shaped_like" then
            local other = solved[s.other].extents
            base = { along = other.along, across = other.across, deep = other.deep }
        end
    end
    local own = {}
    for _, s in ipairs(statements) do
        local value, key = nil, nil
        if s.type == "extent" and s.other == part.name then
            -- measured by its own other extent: applied once the rest is known
            own[#own + 1] = s
        elseif s.type == "extent" then
            value = s.ratio * extent_value(solved[s.other], s.other_extent)
            key = (s.extent == "thin") and kind.thin or s.extent
        elseif s.type == "proportion" and (s.how == "scaled_to" or s.how == "same_size") then
            value, key = largest(solved[s.other].extents), "all"
        end
        if key == "all" then
            -- one sentence about the whole part; two that disagree conflict
            if whole and math.abs(whole.value - value) > 1e-9 then
                refuse(s.line, "'" .. part.name .. "' is given two overall sizes (lines " .. whole.line .. " and " .. s.line .. ")")
            end
            whole = { value = value, line = s.line }
        elseif key then
            -- a tied extent (round: across and deep; all-equal kinds:
            -- every one) carries the same value to its partners
            local keys = { key }
            if kind.links == "all" then keys = { "along", "across", "deep" }
            elseif kind.links == "round" and key ~= "along" then keys = { "across", "deep" } end
            for _, k in ipairs(keys) do
                if explicit[k] and math.abs(explicit[k].value - value) > 1e-9 then
                    refuse(s.line, "'" .. part.name .. "' has its " .. k .. " set twice, differently (lines "
                        .. explicit[k].line .. " and " .. s.line .. ")")
                end
                explicit[k] = { value = value, line = s.line }
            end
        end
    end

    local extents = {}
    if next(explicit) and whole then
        local any = next(explicit)
        refuse(whole.line, "'" .. part.name .. "' is given an overall size (line " .. whole.line
            .. ") and a single measurement (line " .. explicit[any].line .. "); say one")
    end
    if next(explicit) then
        -- extents not mentioned keep the proportions of those that are:
        -- scaled by the average (geometric mean) of the mentioned ones' scales
        local product, count = 1, 0
        for k, entry in pairs(explicit) do product = product * entry.value / base[k]; count = count + 1 end
        local scale = product ^ (1 / count)
        for _, k in ipairs({ "along", "across", "deep" }) do
            extents[k] = explicit[k] and explicit[k].value or base[k] * scale
        end
    elseif whole then
        local scale = whole.value / largest(base)
        for _, k in ipairs({ "along", "across", "deep" }) do extents[k] = base[k] * scale end
    else
        for _, k in ipairs({ "along", "across", "deep" }) do extents[k] = base[k] end
        local shaped = false
        for _, s in ipairs(statements) do if s.type == "proportion" and s.how == "shaped_like" then shaped = true end end
        if not shaped then
            assume(part.name, string.format("no size given: a %s's own proportions (along %g, across %g, deep %g)",
                part.kind, base.along, base.across, base.deep))
        end
    end
    -- {{{ own measures
    -- "half as deep as it is wide": the other extent as it now stands; an
    -- extent already set by another sentence, or by another own measure,
    -- is set twice
    for _, s in ipairs(own) do
        local key = (s.extent == "thin") and kind.thin or s.extent
        local other_key = (s.other_extent == "thin") and kind.thin or s.other_extent
        if explicit[key] then
            refuse(s.line, "'" .. part.name .. "' has its " .. key .. " set twice (lines " .. explicit[key].line .. " and " .. s.line .. ")")
        end
        -- tied extents move together: setting a round part's depth sets its
        -- width, and the other way round, which would contradict itself
        local keys = { key }
        if kind.links == "all" then keys = { "along", "across", "deep" }
        elseif kind.links == "round" and key ~= "along" then keys = { "across", "deep" } end
        for _, k in ipairs(keys) do
            if k == other_key then
                refuse(s.line, "'" .. part.name .. "' is a " .. part.kind .. ": its " .. key .. " and " .. other_key .. " are always equal")
            end
        end
        local value = s.ratio * extents[other_key]
        for _, k in ipairs(keys) do extents[k] = value end
        explicit[key] = { value = value, line = s.line }
    end
    -- }}}
    -- a ring is a tube bent round; thicker than it is wide, it has no hole
    if part.kind == "ring" and extents.along >= extents.across then
        refuse(part.line, "'" .. part.name .. "' is a ring as thick as it is wide, so it has no hole")
    end
    return extents
end
-- }}}

-- {{{ local function half_extents()
-- Half of a solved part's size along world x, y and z.
local function half_extents(part)
    local layout = M.AXIS_LAYOUT[part.axis]
    return { part.extents[layout[1]] / 2, part.extents[layout[2]] / 2, part.extents[layout[3]] / 2 }
end
M.half_extents = half_extents
-- }}}

-- {{{ function M.solve()
-- model: the reader's { parts, statements }. Returns the result described
-- at the top, and a list of refusals ({ line, message }).
function M.solve(model)
    local refusals, assumptions = {}, {}
    local function refuse(line, message) refusals[#refusals + 1] = { line = line, message = message } end
    local function assume(name, text) assumptions[#assumptions + 1] = { part = name, text = text } end

    local about = {}
    for _, part in ipairs(model.parts) do about[part.name] = {} end
    for _, s in ipairs(model.statements) do
        if about[s.subject] then table.insert(about[s.subject], s) end
    end

    -- {{{ dependency lists, one per pass
    local function depends_on(types)
        return function(name)
            local list = {}
            for _, s in ipairs(about[name]) do
                -- a part measured by its own other extent depends on nothing
                if types[s.type] and s.other and s.other ~= name then list[#list + 1] = { other = s.other, line = s.line } end
            end
            return list
        end
    end
    -- }}}

    local solved = {}
    for index, part in ipairs(model.parts) do
        solved[part.name] = { name = part.name, kind = part.kind, line = part.line, index = index }
    end

    -- {{{ pass 1: sizes
    for _, name in ipairs(in_order(model.parts, depends_on({ extent = true, proportion = true }), "sizes", refuse)) do
        solved[name].extents = solve_size(solved[name], about[name], solved, refuse, assume)
    end
    -- }}}

    -- {{{ pass 2: directions
    -- around / through / aligned take the other part's axis
    local function coaxial(s)
        return s.type == "aligned" or (s.type == "place" and (s.place == "around" or s.place == "through"))
    end
    local direction_order = in_order(model.parts, function(name)
        local list = {}
        for _, s in ipairs(about[name]) do if coaxial(s) then list[#list + 1] = { other = s.other, line = s.line } end end
        return list
    end, "directions", refuse)
    for _, name in ipairs(direction_order) do
        local axis, from = nil, nil
        for _, s in ipairs(about[name]) do
            local wanted = (s.type == "direction" and s.axis) or (coaxial(s) and solved[s.other].axis) or nil
            if wanted then
                if axis and axis ~= wanted then
                    refuse(s.line, "'" .. name .. "' is turned two ways (lines " .. from .. " and " .. s.line .. ")")
                end
                axis, from = wanted, s.line
            end
        end
        solved[name].axis = axis or "y"
    end
    -- }}}

    -- {{{ pass 3: places
    -- the first part named that no sentence places is the middle of
    -- everything; every other part must be placed by a sentence
    local anchor = nil
    for _, part in ipairs(model.parts) do
        local placed = false
        for _, s in ipairs(about[part.name]) do if s.type == "place" or s.type == "aligned" then placed = true end end
        if not placed then anchor = anchor or part.name end
    end
    local place_order = in_order(model.parts, depends_on({ place = true, aligned = true }), "places", refuse)
    for _, name in ipairs(place_order) do
        local part = solved[name]
        -- a part whose size or direction could not be solved cannot be placed
        if part.extents and part.axis then
            local place, aligned = nil, nil
            for _, s in ipairs(about[name]) do
                if s.type == "place" then
                    if place then refuse(s.line, "'" .. name .. "' is placed twice (lines " .. place.line .. " and " .. s.line .. ")") end
                    place = s
                elseif s.type == "aligned" then
                    aligned = s
                end
            end
            local centre = nil
            -- the part it is placed by could not be placed itself (already
            -- refused): this one has nowhere to go either, and says nothing
            -- more, since the first refusal is the one to fix
            local leaning_on = (place and solved[place.other]) or (aligned and solved[aligned.other])
            if leaning_on and leaning_on.centre == nil then
                place, aligned, centre = nil, nil, false
            end
            if centre == false then
                centre = nil
            elseif place then
                local other = solved[place.other]
                local h_self, h_other = half_extents(part), half_extents(other)
                centre = { other.centre[1], other.centre[2], other.centre[3] }
                local direction = PLACE_DIRECTION[place.place]
                if direction then
                    local k = direction[1]
                    centre[k] = centre[k] + direction[2] * (h_other[k] + h_self[k])
                elseif place.place == "end" or place.place == "other_end" then
                    local k = AXIS_INDEX[other.axis]
                    local sign = (place.place == "end") and 1 or -1
                    centre[k] = centre[k] + sign * (h_other[k] + h_self[k])
                end
                -- centre, around, through: the other part's middle, as copied
            elseif aligned then
                local other = solved[aligned.other]
                centre = { other.centre[1], other.centre[2], other.centre[3] }
            elseif name == anchor then
                centre = { 0, 0, 0 }
            else
                refuse(part.line, "'" .. name .. "' is never placed (say where, e.g. 'the " .. name
                    .. " sits on top of the " .. (anchor or "...") .. "')")
            end
            -- aligned: onto the other part's axis line, keeping its place
            -- along that line
            if centre and aligned then
                local other = solved[aligned.other]
                local along = AXIS_INDEX[other.axis]
                for k = 1, 3 do if k ~= along then centre[k] = other.centre[k] end end
            end
            part.centre = centre
        end
    end
    -- }}}

    -- {{{ colours
    local next_default = 0
    for _, part in ipairs(model.parts) do
        local colour, from = part.colour, part.line
        for _, s in ipairs(about[part.name]) do
            if s.type == "colour" then
                if colour and colour ~= s.colour then
                    refuse(s.line, "'" .. part.name .. "' is given two colours (lines " .. from .. " and " .. s.line .. ")")
                end
                colour, from = s.colour, s.line
            end
        end
        if colour == nil then
            next_default = next_default + 1
            colour = words.DEFAULT_COLOURS[(next_default - 1) % #words.DEFAULT_COLOURS + 1]
            assume(part.name, "no colour given: " .. colour)
        end
        local c = words.COLOURS[colour]
        solved[part.name].colour = { c[1], c[2], c[3] }
        solved[part.name].colour_word = colour
    end
    -- }}}

    local result = { parts = {}, assumptions = assumptions, anchor = anchor }
    for _, part in ipairs(model.parts) do result.parts[#result.parts + 1] = solved[part.name] end
    table.sort(refusals, function(a, b) return a.line < b.line end)
    return result, refusals
end
-- }}}

return M
