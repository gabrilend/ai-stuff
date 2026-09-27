-- 065-re-abstraction.lua
--
-- Finding the part at fault when a workflow fails (issue 507): dynamic
-- re-abstraction, in the owner's words. Look narrowly first; widen the view
-- only when the narrow look finds nothing; narrow again to fix.
--
--   level 1   each covered issue alone, audited in a seeded order. An audit
--             fixes its own part or changes nothing; a checksum of the design
--             before and after says which. After a change the workflow runs
--             again; passing ends the search.
--   level 2   nothing changed: the issues paired at random, an odd one out
--             left out (already looked at alone). Each pair is inspected: no
--             code written, one part named, or none.
--   level 3…  nothing named: groups merged pairwise again, until one group
--             holds every covered issue — the bigger picture, looked at last.
--   then      the first part named is audited alone, with the finding in
--             hand: back within fixing range.
--
-- The shuffle and the pairing are seeded from the ledger's head hash when the
-- search begins, so the same history gives the same order — random, and
-- predictable in kind.

local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local kinds = require("034-turn-kinds")
local snapshots = require("036-snapshots")
local pool = require("039-the-turn-pool")
local issue_files = require("044-issue-files")
local workflows = require("063-workflows")

local re_abstraction = {}

-- {{{ function re_abstraction.shuffle
-- A Fisher–Yates shuffle driven by a small generator seeded from a hex
-- string (the ledger's head hash). Returns a new array.
function re_abstraction.shuffle(items, seed_hex)
    local state = tonumber(seed_hex:sub(1, 8), 16) or 1
    -- {{{ local function next_number
    -- A linear congruential generator, kept in 31 bits so LuaJIT's doubles
    -- hold every step exactly.
    local function next_number()
        state = (state * 1103515245 + 12345) % 2147483648
        return state
    end
    -- }}}
    local out = {}
    for i, v in ipairs(items) do out[i] = v end
    for i = #out, 2, -1 do
        local j = next_number() % i + 1
        out[i], out[j] = out[j], out[i]
    end
    return out
end
-- }}}

-- {{{ function re_abstraction.ladder
-- The groups to inspect, level by level after the singles: pairs of the
-- previous level's groups (an odd one out left out), then pairs of those,
-- ending with one group of everything. `order` is the shuffled ids.
-- Returns an array of levels; each level an array of groups (arrays of ids).
function re_abstraction.ladder(order)
    local levels = {}
    local current = {}
    for i, id in ipairs(order) do current[i] = { id } end
    while true do
        local merged = {}
        for i = 1, #current - 1, 2 do
            local group = {}
            for _, id in ipairs(current[i]) do group[#group + 1] = id end
            for _, id in ipairs(current[i + 1]) do group[#group + 1] = id end
            merged[#merged + 1] = group
        end
        if #merged == 0 then
            break
        end
        levels[#levels + 1] = merged
        current = merged
        if #merged == 1 then
            break
        end
    end
    -- The last look is always at everything: if pairing left some out, one
    -- more level holds every id.
    local last = levels[#levels]
    if not last or #last[1] < #order then
        local all = {}
        for i, id in ipairs(order) do all[i] = id end
        if #order > 1 then
            levels[#levels + 1] = { all }
        end
    end
    return levels
end
-- }}}

-- {{{ local function design_checksum
-- One checksum over every file of the design (links by target).
local function design_checksum(project, record, previous)
    local snap = snapshots.take(project, { record.design }, {}, previous)
    local keys = {}
    for path in pairs(snap) do keys[#keys + 1] = path end
    table.sort(keys)
    local parts = {}
    for i, path in ipairs(keys) do parts[i] = path .. "\t" .. snap[path].hash end
    return require("015-sha-256").of_string(table.concat(parts, "\n")), snap
end
-- }}}

-- {{{ function re_abstraction.search
-- Searches for and fixes the fault behind one failing workflow. `failure` is
-- { workflow, output } from 063's run_all. Returns { fixed = boolean, turns =
-- number, path = array of sentences describing each look }.
function re_abstraction.search(project, record, failure, target, options)
    local covered = {}
    for _, id in ipairs(failure.workflow.covers) do
        if issue_files.find(record.issues, id) then covered[#covered + 1] = id end
    end
    local seed = ledger.head(record.ledger) or string.rep("0", 64)
    local order = re_abstraction.shuffle(covered, seed)
    local result = { fixed = false, turns = 0, path = {} }
    local output = failure.output
    local _, snap = design_checksum(project, record, nil)

    -- {{{ local function run_turn
    local function run_turn(kind, values)
        local turn = kinds.make_turn(record, kind, values)
        result.turns = result.turns + 1
        local results, summary = pool.run_set(project, record, { turn }, options)
        if #summary.breaches > 0 then
            error("re-abstraction: an " .. kind .. " turn wrote outside its folders; stopping")
        end
        return turn, results[1]
    end
    -- }}}

    -- {{{ local function audit
    -- Audits one issue; returns whether the design changed, and whether the
    -- workflow now passes.
    local function audit(id, finding)
        local before
        before, snap = design_checksum(project, record, snap)
        run_turn("audit", {
            about = id, target = target, workflow = failure.workflow.name, output = output,
            finding = finding or "nothing yet: you are the first to look",
            issue_text = fs.read(issue_files.find(record.issues, id)),
        })
        local after
        after, snap = design_checksum(project, record, snap)
        local changed = before ~= after
        ledger.append(record.ledger, "audited", id, (changed and "changed" or "unchanged")
            .. " for " .. failure.workflow.name .. (finding and " (with a finding)" or ""))
        result.path[#result.path + 1] = "audit " .. id .. ": " .. (changed and "changed" or "unchanged")
        if not changed then
            return false, false
        end
        local passes, new_output = workflows.run_one(failure.workflow, record.design)
        output = new_output
        return true, passes
    end
    -- }}}

    -- Level 1: each issue alone.
    local any_changed = false
    for _, id in ipairs(order) do
        local changed, passes = audit(id, nil)
        any_changed = any_changed or changed
        if passes then
            result.fixed = true
            return result
        end
    end
    -- Something changed but the workflow still fails: the narrow look did
    -- find faults; one more narrow pass over the design as it now is, before
    -- concluding the fault lies between parts.
    if any_changed then
        for _, id in ipairs(order) do
            local _, passes = audit(id, nil)
            if passes then
                result.fixed = true
                return result
            end
        end
    end

    -- Wider, level by level, until one group holds everything.
    for _, level in ipairs(re_abstraction.ladder(order)) do
        for _, group in ipairs(level) do
            local label = table.concat(group, "+")
            local texts = {}
            for _, id in ipairs(group) do
                texts[#texts + 1] = fs.read(issue_files.find(record.issues, id))
            end
            local turn = run_turn("inspect", {
                about = label, workflow = failure.workflow.name, output = output,
                finding_path = "finding (a file in your working folder)",
                group = table.concat(group, " "), group_texts = table.concat(texts, "\n\n---\n\n"),
            })
            local named, why = nil, ""
            local path = turn.folder .. "/finding"
            if fs.exists(path) then
                local text = fs.read(path)
                local first = text:match("^%s*(%S+)")
                why = text:gsub("^[^\n]*\n?", ""):gsub("%s+$", "")
                for _, id in ipairs(group) do
                    if id == first then named = id end
                end
            end
            ledger.append(record.ledger, "inspected", label, (named or "none") .. (why ~= "" and (": " .. why) or ""))
            result.path[#result.path + 1] = "inspect " .. label .. ": " .. (named or "none")
            if named then
                -- Back within fixing range: the named part, with the finding.
                local changed, passes = audit(named, named .. " — " .. (why ~= "" and why or "named by a look at " .. label))
                if passes then
                    result.fixed = true
                    return result
                end
                if not changed then
                    return result
                end
            end
        end
    end
    return result
end
-- }}}

return re_abstraction
