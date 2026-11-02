-- 144-the-viewer.lua
--
-- The viewer (docs/067, issue 810): the pool as a gallery in the owner's
-- look, each asset with its category and tier; keys 1-5 append a person's
-- rating to the asset; a category's floor can be raised, showing first
-- what it would leave. Like a stranger, it reads only finished files and
-- their cards (and the pool's ratings and floor table, through 076); it
-- shares no code with any maker.
--
-- This file is the viewer without its window: the gallery, the keys and a
-- frame described as a draw list, all of which run and are checked with no
-- display (docs/010 question 11: the window opens on the owner's own
-- computer). The raylib window is a thin front that hands this file key
-- names and draws its draw list, one command at a time; it is built once
-- raylib is vendored into libs/.

local fs = require("017-the-filesystem")
local pool = require("076-the-pool")
local the_look = require("070-the-look")

local viewer = {}

-- What kind of asset a file is, by its ending, so the front knows whether
-- to show it as a picture, a first frame, or its first lines of text.
viewer.KINDS_BY_ENDING = {
    png = "still",
    gif = "clip", mp4 = "clip",
    txt = "text", md = "text",
}
-- Anything else that has a card is source (docs/067's `.src` end).
viewer.OTHER_KIND = "source"

-- The grounds of docs/067's look as colours, and what is drawn on each:
-- bright marks on a dark ground (night), dark on white (day).
viewer.GROUNDS = {
    black = { 0, 0, 0 },
    gray = { 40, 40, 40 },
    white = { 255, 255, 255 },
}
viewer.INK = {
    night = { bright = { 235, 235, 235 }, dim = { 110, 110, 110 } },
    day = { bright = { 20, 20, 20 }, dim = { 150, 150, 150 } },
}

-- The gallery's grid: a tile's size and the gap around it, in pixels, and
-- the height of the status line at the bottom.
viewer.TILE = 160
viewer.GAP = 16
viewer.LABEL = 18
viewer.STATUS = 28

-- {{{ local function kind_of
local function kind_of(path)
    local ending = path:match("%.([%w]+)$")
    return viewer.KINDS_BY_ENDING[ending and ending:lower() or ""] or viewer.OTHER_KIND
end
-- }}}

-- {{{ local function card_paths
-- Every ".card" under `dir`, the same walk 076's count utility makes, so
-- the gallery and the counts can never disagree about what the pool holds.
local function card_paths(dir, out)
    out = out or {}
    if not fs.is_folder(dir) then
        return out
    end
    for _, name in ipairs(fs.list(dir)) do
        local path = dir .. "/" .. name
        if fs.is_folder(path) then
            card_paths(path, out)
        elseif name:match("%.card$") then
            out[#out + 1] = path
        end
    end
    return out
end
-- }}}

-- {{{ function viewer.gallery
-- Every pooled asset (step 1): { asset, name, category, kind, tier, ratings },
-- `name` relative to the pool, `tier` nil when unrated, sorted by category
-- then name. Reads cards and ratings only, never an asset's own bytes.
function viewer.gallery(pool_dir)
    local entries = {}
    for _, card_path in ipairs(card_paths(pool_dir)) do
        local asset = card_path:sub(1, -6)
        local card = pool.read_card(asset)
        entries[#entries + 1] = {
            asset = asset,
            name = asset:sub(#pool_dir + 2),
            category = card.category,
            kind = kind_of(asset),
            tier = pool.tier(card.ratings),
            ratings = #card.ratings,
        }
    end
    table.sort(entries, function(a, b)
        if a.category ~= b.category then return a.category < b.category end
        return a.name < b.name
    end)
    return entries
end
-- }}}

-- {{{ function viewer.in_use
-- Whether an entry is kept in use by its category's floor: floor 0 keeps
-- everything; a higher floor keeps what is rated at or above it.
function viewer.in_use(entry, floors)
    local floor = pool.floor(floors, entry.category)
    if floor == 0 then
        return true
    end
    return entry.tier ~= nil and entry.tier >= floor
end
-- }}}

-- {{{ function viewer.open
-- The viewer's state over one pool: its entries, the floor table, the
-- selection, the window's size, the look, and the status line.
function viewer.open(pool_dir, width, height, look)
    return {
        pool_dir = pool_dir,
        entries = viewer.gallery(pool_dir),
        floors = pool.floors(pool_dir),
        selected = 1,
        width = width or 1280, height = height or 800,
        look = look or the_look.defaults(),
        status = "",
        pending = nil,
        quit = false,
    }
end
-- }}}

-- {{{ function viewer.columns
function viewer.columns(state)
    local n = math.floor((state.width - viewer.GAP) / (viewer.TILE + viewer.GAP))
    return math.max(1, n)
end
-- }}}

-- {{{ local function refresh
-- Reads the pool again after a rating or a floor, keeping the selection on
-- the same asset.
local function refresh(state)
    local current = state.entries[state.selected]
    state.entries = viewer.gallery(state.pool_dir)
    state.floors = pool.floors(state.pool_dir)
    if current then
        for i, e in ipairs(state.entries) do
            if e.asset == current.asset then
                state.selected = i
            end
        end
    end
end
-- }}}

-- {{{ local function propose_floor
local function propose_floor(state, step)
    local entry = state.entries[state.selected]
    local floor = pool.floor(state.floors, entry.category) + step
    if floor < 0 or floor > pool.TIERS then
        state.status = entry.category .. "'s floor is already " .. (floor < 0 and "0" or pool.TIERS)
        state.pending = nil
        return
    end
    local report = pool.floor_report(state.pool_dir, entry.category, floor)
    state.pending = { category = entry.category, floor = floor }
    state.status = report.line .. " — y to set it, any other key to leave it"
end
-- }}}

-- {{{ function viewer.key
-- One key, by name ("1".."5", "left", "right", "up", "down", "[", "]",
-- "y", "q"): the front hands keys in; this changes the state, and the pool
-- only by appending a rating (076's rate) or setting a floor (set_floor).
-- A floor is never set by the key that proposes it: "]" or "[" says its
-- cost on the status line, and only "y" next sets it. Returns the state.
function viewer.key(state, key)
    local pending = state.pending
    state.pending = nil
    if #state.entries == 0 then
        state.status = "the pool is empty"
        if key == "q" then state.quit = true end
        return state
    end
    local entry = state.entries[state.selected]
    local tier = tonumber(key)
    if tier and tier >= 1 and tier <= pool.TIERS and key:match("^%d$") then
        pool.rate(entry.asset, tier, "person")
        refresh(state)
        state.status = "rated " .. entry.name .. " " .. tier
    elseif key == "left" or key == "right" or key == "up" or key == "down" then
        local step = ({ left = -1, right = 1, up = -viewer.columns(state), down = viewer.columns(state) })[key]
        state.selected = math.max(1, math.min(#state.entries, state.selected + step))
        state.status = ""
    elseif key == "]" then
        propose_floor(state, 1)
    elseif key == "[" then
        propose_floor(state, -1)
    elseif key == "y" and pending then
        local report = pool.set_floor(state.pool_dir, pending.category, pending.floor)
        refresh(state)
        state.status = "floor set: " .. report.line
    elseif key == "q" then
        state.quit = true
    else
        state.status = ""
    end
    return state
end
-- }}}

-- {{{ function viewer.frame
-- The frame as a draw list (the path a window would take, without one):
--   { op = "clear", colour }
--   { op = "rect", x, y, w, h, colour, filled }      -- a tile, or the selection
--   { op = "image", path, x, y, w, h }               -- a still, fitted to its tile
--   { op = "text", text, x, y, size, colour }
-- Tiles left to right, top to bottom, in gallery order; each with its
-- category and tier beneath it; an asset its floor leaves out drawn dim;
-- the status line at the bottom. Scrolls so the selection is in view.
function viewer.frame(state)
    local ground = viewer.GROUNDS[state.look.ground] or viewer.GROUNDS.black
    local ink = viewer.INK[state.look.palette] or viewer.INK.night
    local list = { { op = "clear", colour = ground } }
    local columns = viewer.columns(state)
    local row_h = viewer.TILE + viewer.LABEL + viewer.GAP
    local rows_shown = math.max(1, math.floor((state.height - viewer.STATUS - viewer.GAP) / row_h))
    local selected_row = math.floor((state.selected - 1) / columns)
    local first_row = math.max(0, selected_row - rows_shown + 1)
    for i, e in ipairs(state.entries) do
        local row = math.floor((i - 1) / columns) - first_row
        if row >= 0 and row < rows_shown then
            local x = viewer.GAP + ((i - 1) % columns) * (viewer.TILE + viewer.GAP)
            local y = viewer.GAP + row * row_h
            local colour = viewer.in_use(e, state.floors) and ink.bright or ink.dim
            if e.kind == "still" then
                list[#list + 1] = { op = "image", path = e.asset, x = x, y = y, w = viewer.TILE, h = viewer.TILE }
            else
                list[#list + 1] = { op = "text", text = e.kind .. ": " .. e.name, x = x + 4, y = y + 4, size = 10, colour = colour }
            end
            list[#list + 1] = { op = "rect", x = x, y = y, w = viewer.TILE, h = viewer.TILE, colour = colour, filled = false }
            list[#list + 1] = {
                op = "text", x = x, y = y + viewer.TILE + 2, size = 14, colour = colour,
                text = e.category .. " · " .. (e.tier and ("tier " .. e.tier) or "unrated"),
            }
            if i == state.selected then
                list[#list + 1] = { op = "rect", x = x - 4, y = y - 4, w = viewer.TILE + 8, h = viewer.TILE + 8, colour = ink.bright, filled = false }
            end
        end
    end
    local status = state.status ~= "" and state.status
        or (#state.entries == 0 and "the pool is empty")
        or (state.entries[state.selected].name .. " — 1-5 rate, [ ] floor, q quit")
    list[#list + 1] = { op = "text", text = status, x = viewer.GAP, y = state.height - viewer.STATUS + 6, size = 16, colour = ink.bright }
    return list
end
-- }}}

viewer.kind_of = kind_of

return viewer
