-- 05-ordering-engine.lua — turn the catalog into a WALK ORDER.
--
-- General description: the catalog is just a heap of records. This file decides
-- the order you step through them. It never moves a record; it returns a list of
-- positions -- an ordering -- into the catalog. Three walks are offered:
--
--   chronological : follow time, oldest-first or newest-first (built now)
--   similar       : hop to the nearest neighbour by meaning (Phase 2)
--   different     : hop to the LEAST similar thing not yet seen (Phase 2)
--
-- "Meaning" here is the similarity between two files' policy descriptions -- the
-- little texts that say what each file is for -- not their raw bytes, because you
-- cannot embed a ten-gigabyte video. Until those policy embeddings exist, the
-- two meaning-walks announce a fallback and hand back the chronological order.
-- The greedy diversity algorithm that powers "different" is already written here
-- (lifted from the neocities diversity-chaining design) so Phase 2 only has to
-- supply the numbers.

local DIR = DIR or "/home/ritz/programming/ai-stuff/filesystem-tapestry"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/libs/?.lua;" .. package.path
local utils = require("01-utils")

local M = {}

-- {{{ M.chronological
-- Sort catalog positions by a date field. field is "created" or "modified";
-- direction is "asc" (oldest first) or "desc". include_excluded decides whether
-- junk-directory files appear in the order -- the browse walk leaves them out,
-- but a full-timeline view can ask for them (excluded, yet still referenced
-- chronologically). Ties break on path so the order is deterministic and a
-- re-run produces the identical walk.
function M.chronological(records, opts)
    opts = opts or {}
    local field = opts.field or "modified"
    local ascending = (opts.direction or "asc") ~= "desc"
    local include_excluded = opts.include_excluded == true

    local order = {}
    for i, rec in ipairs(records) do
        if include_excluded or not rec.excluded then
            order[#order + 1] = i
        end
    end

    table.sort(order, function(a, b)
        local ra, rb = records[a], records[b]
        local va, vb = ra[field] or 0, rb[field] or 0
        if va ~= vb then
            if ascending then return va < vb else return va > vb end
        end
        return ra.path < rb.path   -- stable tie-break
    end)
    return order
end
-- }}}

-- {{{ M.nearest_neighbour_order  (Phase 2 seam)
-- Given a seed position and a similarity provider sim(i, j) -> score in [0,1],
-- order the pool from most to least similar to the seed. This is the "similar"
-- walk. Written now; called once policy embeddings feed sim().
function M.nearest_neighbour_order(pool, seed, sim)
    local order = {}
    for _, i in ipairs(pool) do if i ~= seed then order[#order + 1] = i end end
    table.sort(order, function(a, b) return sim(seed, a) > sim(seed, b) end)
    table.insert(order, 1, seed)
    return order
end
-- }}}

-- {{{ M.diversity_chain  (Phase 2 seam)
-- The "different" walk, faithful to neocities diversity-chaining: start at seed,
-- and at each step jump to the not-yet-visited file that is LEAST similar to
-- where you stand. A greedy chain that keeps surprising you. sim(i, j) is the
-- similarity provider; higher means more alike, so we minimise it.
function M.diversity_chain(pool, seed, sim)
    local visited = { [seed] = true }
    local chain = { seed }
    local current = seed
    for _ = 2, #pool do
        local next_pos, lowest = nil, math.huge
        for _, cand in ipairs(pool) do
            if not visited[cand] then
                local score = sim(current, cand)
                if score < lowest then lowest = score; next_pos = cand end
            end
        end
        if not next_pos then break end
        visited[next_pos] = true
        chain[#chain + 1] = next_pos
        current = next_pos
    end
    return chain
end
-- }}}

-- {{{ MODES dispatch table
-- Mode name -> builder. A table, not an if/else ladder: adding a walk is adding
-- a row. Each builder takes (records, opts) and returns an ordering.
--
-- similar/different look for opts.similarity (the Phase-2 provider). When it is
-- absent they warn and delegate to chronological, so a meaning-walk is never
-- silently wrong -- it either uses real similarity or tells you it could not.
local MODES

local function meaning_walk(kind, records, opts)
    if not opts.similarity then
        utils.log_warn(string.format(
            "'%s' walk needs policy embeddings (Phase 2), none loaded "
            .. "-- FALLBACK to chronological order", kind))
        return MODES.chronological(records, opts)
    end
    local pool = {}
    for i, rec in ipairs(records) do
        if opts.include_excluded or not rec.excluded then pool[#pool + 1] = i end
    end
    local seed = opts.seed or pool[1]
    local sim = opts.similarity
    if kind == "similar" then
        return M.nearest_neighbour_order(pool, seed, sim)
    else
        return M.diversity_chain(pool, seed, sim)
    end
end

MODES = {
    chronological = function(records, opts) return M.chronological(records, opts) end,
    similar       = function(records, opts) return meaning_walk("similar", records, opts) end,
    different     = function(records, opts) return meaning_walk("different", records, opts) end,
}
-- }}}

-- {{{ M.build
-- The one entry point the navigator calls: build(records, mode, opts) -> order.
-- Unknown modes are an error, not a guess.
function M.build(records, mode, opts)
    local builder = MODES[mode]
    if not builder then
        error("unknown ordering mode: " .. tostring(mode)
            .. " (want chronological / similar / different)")
    end
    return builder(records, opts or {})
end
-- }}}

M.MODES = MODES
return M
