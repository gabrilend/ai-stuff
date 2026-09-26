-- 043-the-graph.lua
--
-- Which issue builds on which (docs/006, "the graph"): read from the
-- outline, and the structure every later phase leans on. An issue's level is
-- 0 when nothing blocks it, else one more than its highest blocker's level;
-- the levels are the build order. An issue's reach is itself plus everything
-- built on it, directly or not — what a change to it forces to be rebuilt.
--
-- A node (docs/002): id (string), name (string), blocked_by (array of ids),
-- blocks (array of ids, the reverse edges), level (number), covers (array).

local outline = require("042-the-outline")

local graph = {}

-- {{{ local function by_id
local function by_id(a, b)
    return a < b
end
-- }}}

-- {{{ function graph.build
-- From outline rows (already checked: no cycles, every blocker exists).
-- Returns { nodes = { [id] = node }, ids = sorted array of ids }.
function graph.build(rows)
    local nodes, ids = {}, {}
    for _, row in ipairs(rows) do
        nodes[row.id] = {
            id = row.id, name = row.name, blocked_by = outline.words(row.blocked_by),
            covers = outline.words(row.covers), blocks = {},
        }
        ids[#ids + 1] = row.id
    end
    table.sort(ids, by_id)
    for _, id in ipairs(ids) do
        for _, b in ipairs(nodes[id].blocked_by) do
            local blocks = nodes[b].blocks
            blocks[#blocks + 1] = id
        end
    end
    for _, id in ipairs(ids) do
        table.sort(nodes[id].blocks, by_id)
    end
    -- Levels by repeated passes: a node gets its level once all its blockers
    -- have theirs. Terminates because the outline has no cycles.
    local remaining = #ids
    while remaining > 0 do
        local progressed = false
        for _, id in ipairs(ids) do
            local node = nodes[id]
            if not node.level then
                local level, ready = 0, true
                for _, b in ipairs(node.blocked_by) do
                    if not nodes[b].level then
                        ready = false
                        break
                    end
                    level = math.max(level, nodes[b].level + 1)
                end
                if ready then
                    node.level = level
                    remaining = remaining - 1
                    progressed = true
                end
            end
        end
        if not progressed then
            error("graph: the blockers go round in a circle (the outline check should have caught this)")
        end
    end
    return { nodes = nodes, ids = ids }
end
-- }}}

-- {{{ function graph.levels
-- Arrays of ids per level, level 0 first, ids in order within each.
function graph.levels(g)
    local levels = {}
    for _, id in ipairs(g.ids) do
        local level = g.nodes[id].level
        levels[level + 1] = levels[level + 1] or {}
        local list = levels[level + 1]
        list[#list + 1] = id
    end
    return levels
end
-- }}}

-- {{{ function graph.reach
-- The given ids plus everything built on them, sorted.
function graph.reach(g, ids)
    local seen, stack = {}, {}
    for _, id in ipairs(ids) do
        if g.nodes[id] then
            stack[#stack + 1] = id
        end
    end
    while #stack > 0 do
        local id = table.remove(stack)
        if not seen[id] then
            seen[id] = true
            for _, above in ipairs(g.nodes[id].blocks) do
                stack[#stack + 1] = above
            end
        end
    end
    local out = {}
    for id in pairs(seen) do
        out[#out + 1] = id
    end
    table.sort(out, by_id)
    return out
end
-- }}}

-- {{{ function graph.text
-- The viewing side: each level and its issues, with names and blockers.
function graph.text(g, marks)
    local lines = {}
    for level, ids in ipairs(graph.levels(g)) do
        lines[#lines + 1] = string.format("level %d", level - 1)
        for _, id in ipairs(ids) do
            local node = g.nodes[id]
            local on = #node.blocked_by > 0 and ("  ← " .. table.concat(node.blocked_by, " ")) or ""
            local mark = marks and marks[id] and (" [" .. marks[id] .. "]") or ""
            lines[#lines + 1] = string.format("  %s  %s%s%s", id, node.name, on, mark)
        end
    end
    return table.concat(lines, "\n")
end
-- }}}

return graph
