-- 076-the-pool.lua
--
-- Every asset ever made, each beside a `.card` of facts about it (docs/067,
-- issue 809a). This piece is the schema and a single write; appending to a
-- card safely under two writers (809b), counting cards (809c) and floors
-- (809d) are later pieces of the same pool.

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

-- {{{ function pool.read_card
function pool.read_card(asset_path)
    return text_tables.read_record(asset_path .. ".card")
end
-- }}}

return pool
