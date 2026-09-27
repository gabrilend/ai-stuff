-- 058-the-center.lua
--
-- The machine's personality (docs/009): a table of weights computed from the
-- ledger and from nothing else. Walking the ledger from its first line, every
-- weight so far shrinks a little before each line (the keep factor), and the
-- line's `about` gains the weight its kind gives. What the person keeps
-- pointing at, and what keeps going wrong, grows heavy; what is left alone
-- fades.
--
-- It decides two things:
--   order    waiting requests, heaviest first (a request's own weight plus
--            the weights of the issues it touched, once graded); issues in
--            a wave, heaviest first
--   words    a paragraph every turn is handed, naming the heaviest things
--
-- It holds no text a model wrote and cannot be edited: the only way to move
-- it is to do something the ledger records. Anyone holding the ledger can
-- recompute it exactly — *at least then, the evil singularity is
-- predictable in kind.*
--
-- The numbers live in BALANCE; every change to them is written, with its
-- reason, in docs/balance-updates.md.

local text_tables = require("014-text-tables")
local ledger = require("016-ledger")
local fs = require("017-the-filesystem")

local center = {}

center.BALANCE = {
    keep = 0.97,
    weights = {
        ["request-received"] = 3,
        ["build-failed"] = 2,
        ["describe-failed"] = 2,
        ["breach"] = 2,
        ["built"] = 0.5,
        ["described"] = 0.5,
    },
    -- `graded` adds this much to each touched issue (read from its text).
    graded_per_issue = 1,
}

-- {{{ function center.compute
-- From ledger lines (016's read). Returns a center:
--   weights   about -> number
--   last      about -> the kind of the last line that added to it
--   lines     how many ledger lines it was computed from
--   head      the last line's hash
function center.compute(lines)
    local weights, last = {}, {}
    local keep = center.BALANCE.keep
    for _, line in ipairs(lines) do
        for about, w in pairs(weights) do
            weights[about] = w * keep
        end
        local add = center.BALANCE.weights[line.kind]
        if add and line.about ~= "-" then
            weights[line.about] = (weights[line.about] or 0) + add
            last[line.about] = line.kind
        end
        if line.kind == "graded" then
            for id in (line.text:match("touched ([^;]*)") or ""):gmatch("%d%d%d") do
                weights[id] = (weights[id] or 0) + center.BALANCE.graded_per_issue
                last[id] = "graded"
            end
        end
    end
    local head = #lines > 0 and lines[#lines].hash or nil
    return { weights = weights, last = last, lines = #lines, head = head }
end
-- }}}

-- {{{ function center.heaviest
-- The `n` heaviest abouts: array of { about, weight, last }, heaviest first,
-- ties by name.
function center.heaviest(c, n)
    local list = {}
    for about, w in pairs(c.weights) do
        list[#list + 1] = { about = about, weight = w, last = c.last[about] }
    end
    table.sort(list, function(a, b)
        if a.weight ~= b.weight then return a.weight > b.weight end
        return a.about < b.about
    end)
    local out = {}
    for i = 1, math.min(n, #list) do
        out[i] = list[i]
    end
    return out
end
-- }}}

-- The words for why something is heavy, by the kind that last moved it.
local WHY = {
    ["request-received"] = "the person asked for it",
    ["graded"] = "a request touched it",
    ["build-failed"] = "its build has been failing",
    ["describe-failed"] = "it could not be described",
    ["breach"] = "a turn broke its confinement",
    ["built"] = "it was built",
    ["described"] = "it was described",
}

-- {{{ local function names_of
-- Issue id -> name, from the case's outline when there is one.
local function names_of(record)
    local names = {}
    local path = record and (record.blueprint .. "/outline.tsv")
    if path and fs.exists(path) then
        for _, row in ipairs((text_tables.read(path))) do
            names[row.id] = row.name
        end
    end
    return names
end
-- }}}

-- {{{ function center.paragraph
-- The paragraph every turn is handed: the five heaviest things in words.
function center.paragraph(c, record)
    local top = center.heaviest(c, 5)
    if #top == 0 then
        return "Nothing has been asked of this case yet; no part of it is weightier than another."
    end
    local names = names_of(record)
    local lines = { "Computed from the case's ledger (" .. c.lines .. " lines), the heaviest things lately:" }
    for _, t in ipairs(top) do
        local label = names[t.about] and ("issue " .. t.about .. " " .. names[t.about])
            or (t.about:match("^%d%d%d$") and ("issue " .. t.about) or ("request " .. t.about))
        lines[#lines + 1] = string.format("- %s (weight %.2f): %s", label, t.weight, WHY[t.last] or t.last or "")
    end
    lines[#lines + 1] = "Where your work touches these, take particular care: they are what the person is attending to."
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ function center.order_requests
-- Waiting requests (055's waiting) heaviest first: each request's own weight
-- plus the weight of every issue its graded line touched. Ties: oldest first.
function center.order_requests(c, waiting, index)
    local scored = {}
    for i, w in ipairs(waiting) do
        local score = c.weights[w.name] or 0
        local graded = index.graded and index.graded[w.name]
        if graded then
            for id in (graded.text:match("touched ([^;]*)") or ""):gmatch("%d%d%d") do
                score = score + (c.weights[id] or 0)
            end
        end
        scored[i] = { w = w, score = score }
    end
    table.sort(scored, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.w.seq < b.w.seq
    end)
    local out = {}
    for i, s in ipairs(scored) do
        out[i] = s.w
    end
    return out
end
-- }}}

-- {{{ function center.order_ids
-- Issue ids heaviest first; ties by id.
function center.order_ids(c, ids)
    local out = {}
    for i, id in ipairs(ids) do
        out[i] = id
    end
    table.sort(out, function(a, b)
        local wa, wb = c.weights[a] or 0, c.weights[b] or 0
        if wa ~= wb then return wa > wb end
        return a < b
    end)
    return out
end
-- }}}

-- {{{ function center.options_for
-- The options every step of a run takes from the center: the paragraph for
-- the turns, the order for requests and waves. Recomputed from the ledger
-- each time it is asked, so it follows the run as the ledger grows.
function center.options_for(record)
    local c = center.compute(ledger.read(record.ledger))
    return {
        pool = { center = center.paragraph(c, record) },
        order = function(waiting)
            local now = center.compute(ledger.read(record.ledger))
            return center.order_requests(now, waiting, ledger.index(ledger.read(record.ledger)))
        end,
        build_order = function(ids)
            return center.order_ids(center.compute(ledger.read(record.ledger)), ids)
        end,
    }
end
-- }}}

-- {{{ function center.write_view
-- center.txt: the ten heaviest, the line count, the head hash. A view only:
-- the machine never reads it back, and deleting it changes nothing.
function center.write_view(record, c)
    local lines = {
        string.format("the center of case %s, from %d ledger lines (head %s)", record.name, c.lines, c.head or "-"),
        "",
    }
    local top = center.heaviest(c, 10)
    local most = top[1] and top[1].weight or 1
    local names = names_of(record)
    for _, t in ipairs(top) do
        local label = t.about .. (names[t.about] and (" " .. names[t.about]) or "")
        lines[#lines + 1] = string.format("  %-36s %7.3f  %s  %s", label:sub(1, 36), t.weight,
            string.rep("█", math.max(1, math.floor(t.weight / most * 24 + 0.5))), WHY[t.last] or "")
    end
    if #top == 0 then
        lines[#lines + 1] = "  (nothing weighs anything yet)"
    end
    local text = table.concat(lines, "\n") .. "\n"
    fs.write(record.folder .. "/center.txt", text)
    return text
end
-- }}}

return center
