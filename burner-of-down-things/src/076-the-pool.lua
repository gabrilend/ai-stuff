-- 076-the-pool.lua
--
-- Every asset ever made, each beside a `.card` of facts about it (docs/067,
-- issue 809a), and a `.ratings` file of every rating it has been given,
-- appended one line at a time so two raters at once never lose each
-- other's line (809b). Counting cards, per category and per tier (809c),
-- is here too; floors (809d) are a later piece of the same pool.

local fs = require("017-the-filesystem")
local text_tables = require("014-text-tables")

local pool = {}

-- A card's own fields, matching docs/067's list exactly: what the asset is,
-- its category, its parameters by name, the seed it was made with, the
-- paintbrush and its version, the canvas that made it, and its ratings —
-- empty until a person or a machine rates it (809b).
pool.FIELDS = { "what", "category", "params", "seed", "paintbrush", "paintbrush_version", "canvas", "ratings" }

-- {{{ function pool.card
-- Builds a card table from what is known about one asset. Refuses a
-- missing field by name, so a caller's mistake is caught here, not on read.
function pool.card(fields)
    local card = {}
    for _, name in ipairs(pool.FIELDS) do
        if fields[name] == nil and name ~= "ratings" then
            error("pool.card: missing field '" .. name .. "'")
        end
        card[name] = fields[name]
    end
    card.ratings = card.ratings or {}
    return card
end
-- }}}

-- {{{ function pool.write_card
-- Writes a card beside its asset: an asset at ".../name.png" gets a card at
-- ".../name.png.card". Uses 014's record writer, so the write goes through
-- a neighbour file and a rename like every other write in the machine.
function pool.write_card(asset_path, card)
    text_tables.write_record(asset_path .. ".card", card)
end
-- }}}

-- How a rating is written: one line of tab-separated fields, appended in a
-- single write. A line this long or shorter goes to the file in one
-- write() on an O_APPEND file, which the kernel never splits between two
-- writers; a rating's note is short, and a longer line is refused rather
-- than risk tearing.
pool.RATING_FIELDS = { "tier", "by", "time", "note" }
pool.MAX_RATING_LINE = 1024
pool.TIERS = 5

-- {{{ function pool.ratings_path
function pool.ratings_path(asset_path)
    return asset_path .. ".ratings"
end
-- }}}

-- {{{ function pool.rate
-- Appends one rating to an asset (809b): `tier` 1-5; `by` "person" or
-- "machine" (docs/067: a person first; a machine grader only once its
-- agreement with the owner is measured); `note` optional. Never reads or
-- rewrites the card or the ratings already given: one line, one write,
-- append-only, like the ledger (016). Returns the rating as a table.
function pool.rate(asset_path, tier, by, note)
    if type(tier) ~= "number" or tier % 1 ~= 0 or tier < 1 or tier > pool.TIERS then
        error("pool.rate: a tier is a whole number from 1 to " .. pool.TIERS .. ", got " .. tostring(tier))
    end
    if by ~= "person" and by ~= "machine" then
        error("pool.rate: a rating is by 'person' or 'machine', got " .. tostring(by))
    end
    if not fs.exists(asset_path .. ".card") then
        error("pool.rate: no card beside " .. asset_path .. "; only a pooled asset is rated")
    end
    local rating = { tier = tier, by = by, time = os.date("%Y-%m-%d %H:%M:%S"), note = note or "" }
    local fields = {}
    for i, name in ipairs(pool.RATING_FIELDS) do
        fields[i] = rating[name]
    end
    local line = text_tables.row_line(fields) .. "\n"
    if #line > pool.MAX_RATING_LINE then
        error("pool.rate: a rating line may be at most " .. pool.MAX_RATING_LINE .. " bytes; shorten the note")
    end
    local file = assert(io.open(pool.ratings_path(asset_path), "ab"))
    -- Unbuffered, so the whole line leaves in the one write() below.
    file:setvbuf("no")
    file:write(line)
    file:close()
    return rating
end
-- }}}

-- {{{ function pool.ratings
-- Every rating appended to an asset, oldest first; none for an asset never
-- rated. A torn or malformed line is refused, naming it.
function pool.ratings(asset_path)
    local file = io.open(pool.ratings_path(asset_path), "rb")
    if not file then
        return {}
    end
    local text = file:read("*a")
    file:close()
    if text ~= "" and text:sub(-1) ~= "\n" then
        error("pool.ratings: the last line of " .. pool.ratings_path(asset_path) .. " is torn")
    end
    local out = {}
    local n = 0
    for line in text:gmatch("([^\n]*)\n") do
        n = n + 1
        local raw = text_tables.split_line(line)
        local tier = tonumber(raw[1])
        if #raw ~= #pool.RATING_FIELDS or not tier or (raw[2] ~= "person" and raw[2] ~= "machine") then
            error("pool.ratings: line " .. n .. " of " .. pool.ratings_path(asset_path) .. " is not a rating")
        end
        out[#out + 1] = {
            tier = tier, by = raw[2],
            time = text_tables.unescape(raw[3]), note = text_tables.unescape(raw[4]),
        }
    end
    return out
end
-- }}}

-- {{{ function pool.tier
-- What an asset's ratings resolve to as one tier: the latest rating by a
-- person; with none, the latest by a machine; nil when never rated.
function pool.tier(ratings)
    local latest_person, latest_machine
    for _, rating in ipairs(ratings) do
        if rating.by == "person" then
            latest_person = rating
        else
            latest_machine = rating
        end
    end
    local chosen = latest_person or latest_machine
    return chosen and chosen.tier
end
-- }}}

-- {{{ function pool.read_card
-- The card at `<asset_path>.card`, with its `ratings` the ones written into
-- the card itself followed by every one appended since (pool.rate).
function pool.read_card(asset_path)
    local card = text_tables.read_record(asset_path .. ".card")
    card.ratings = card.ratings or {}
    for _, rating in ipairs(pool.ratings(asset_path)) do
        card.ratings[#card.ratings + 1] = rating
    end
    return card
end
-- }}}

-- {{{ local function card_paths
-- Every ".card" file found under `dir`, walking its folders. Never opens
-- anything but ".card" files, and never the asset a card sits beside.
local function card_paths(dir)
    local paths = {}
    if not fs.is_folder(dir) then
        return paths
    end
    for _, name in ipairs(fs.list(dir)) do
        local path = dir .. "/" .. name
        if fs.is_folder(path) then
            for _, nested in ipairs(card_paths(path)) do
                paths[#paths + 1] = nested
            end
        elseif name:match("%.card$") then
            paths[#paths + 1] = path
        end
    end
    return paths
end
-- }}}

-- {{{ function pool.counts
-- Per-category counts (issue 809c), read from cards alone; per tier, see
-- tier_counts.
function pool.counts(pool_dir)
    local counts = {}
    for _, path in ipairs(card_paths(pool_dir)) do
        local card = text_tables.read_record(path)
        counts[card.category] = (counts[card.category] or 0) + 1
    end
    return counts
end
-- }}}

-- {{{ function pool.tier_counts
-- Per category, per tier (809c's per-tier half, now that 809b has decided
-- what ratings resolve to): {[category] = {[1..5] = n, unrated = n}}.
-- Reads cards and ratings files alone, never an asset.
function pool.tier_counts(pool_dir)
    local counts = {}
    for _, path in ipairs(card_paths(pool_dir)) do
        local asset_path = path:sub(1, -6)
        local card = pool.read_card(asset_path)
        local per = counts[card.category] or { unrated = 0 }
        for t = 1, pool.TIERS do
            per[t] = per[t] or 0
        end
        local tier = pool.tier(card.ratings)
        if tier then
            per[tier] = per[tier] + 1
        else
            per.unrated = per.unrated + 1
        end
        counts[card.category] = per
    end
    return counts
end
-- }}}

return pool
