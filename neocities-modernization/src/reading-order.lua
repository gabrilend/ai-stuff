-- reading-order.lua
--
-- Issue 10-064: the `--reverse` reading order.
--
-- WHAT IT DOES (for a CEO): by default the site reads oldest first -- the
-- newest poem sits at the very bottom of the very last chronological page, the
-- hardest place on the site to reach. A build made with `--reverse` puts the
-- newest poems on page 1 instead, and lays out each poem's "similar" and
-- "different" lists by date rather than by score. This module holds the two
-- rules, so every program that writes a page or a link to one uses the same
-- answer.
--
-- ONE FLAG, TWO OPERATIONS -- kept apart on purpose:
--
--   1. Chronological pages (chrono_page): which slice of the timeline lands on
--      which page NUMBER. Reversed, page 1 holds the newest `per_page` poems,
--      page 2 the ones before them, and so on; a short page, if any, is the
--      last one and holds the oldest poems. Within every page the poems still
--      read oldest to newest, top to bottom, so the newest poem of all is at
--      the bottom of page 1.
--
--   2. Similar / different pages (reorder_by_date): WHICH poems a page shows
--      is unchanged -- still chosen by the similarity and diversity caches --
--      but the poems the build shows are laid out by date: similar newest
--      first, different oldest first (an asymmetry the issue asks for). The
--      whole shown list is re-sorted first and paginated after, so it reads in
--      one continuous time order across its pages. Nothing is recomputed.
--
-- Without --reverse both functions give exactly today's answer.
--
-- Dependency-free on purpose: it is also required inside the HTML generator's
-- effil worker threads, each with its own fresh Lua state.

local M = {}

-- {{{ function M.chrono_page()
-- The chronological page (1-based) of the poem at 1-based `position` in the
-- oldest-first order of `total` poems. per_page nil means "not paginated":
-- everything is on page 1.
function M.chrono_page(position, per_page, total, reverse)
    if not per_page then return 1 end
    if reverse then
        -- Count back from the newest: positions total .. total-per_page+1 are
        -- page 1, and so on.
        return math.floor((total - position) / per_page) + 1
    end
    return math.floor((position - 1) / per_page) + 1
end
-- }}}

-- {{{ function M.chrono_page_range()
-- The first and last oldest-first positions on chronological page `page`, the
-- inverse of chrono_page. The page lists them in that (ascending) order in
-- both modes.
function M.chrono_page_range(page, per_page, total, reverse)
    if not per_page then return 1, total end
    if reverse then
        local last = total - (page - 1) * per_page
        return math.max(1, last - per_page + 1), last
    end
    local first = (page - 1) * per_page + 1
    return first, math.min(page * per_page, total)
end
-- }}}

-- {{{ function M.shown_count()
-- How many entries of a similar/different list the build actually shows: the
-- pages it writes, counted from the top. With `pages_is_all`, every page the
-- list fills, up to max_pages; otherwise through the highest page number asked
-- for. (A page list such as 1,3 writes pages 1 and 3; re-sorting the prefix
-- through page 3 keeps page 3 the same slice it would be in a build of every
-- page.) Never more than the list holds.
function M.shown_count(list_len, per_page, pages_is_all, pages_list, max_pages)
    local last_page
    if pages_is_all then
        last_page = math.ceil(list_len / per_page)
        if max_pages then last_page = math.min(last_page, max_pages) end
    else
        last_page = 1
        for _, p in ipairs(pages_list or { 1 }) do
            if p > last_page then last_page = p end
        end
    end
    return math.min(list_len, last_page * per_page)
end
-- }}}

-- {{{ local function iso_timestamp()
-- A gallery picture is not on the chronological pages, so it has no place in
-- the mapping; it is dated from its own creation_date, read the way the
-- chronological sort reads a poem's ("YYYY-MM-DDTHH:MM:SS", local os.time).
local function iso_timestamp(date)
    if type(date) ~= "string" then return nil end
    local y, mo, d, h, mi, s = date:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not y then
        y, mo, d = date:match("(%d+)-(%d+)-(%d+)")
        h, mi, s = 0, 0, 0
    end
    if not y then return nil end
    return os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d),
        hour = tonumber(h), min = tonumber(mi), sec = tonumber(s) })
end
-- }}}

-- {{{ function M.reorder_by_date()
-- A NEW list: the first `shown` entries of `list` sorted by date -- "similar"
-- newest first, "different" oldest first -- followed by the rest untouched
-- (they are never drawn, but the TXT export and archive keep their order).
--
-- Each entry is { poem = poem, id = poem_index (optional), ... } -- the worker
-- threads' similarity entries carry no id, so the poem's own poem_index is the
-- fallback key. Its date is the poem's
-- timestamp from chrono_mapping (compute_chronological_mapping's, the same
-- one the chronological pages are built from); ties keep chronological-page
-- order, then poem_index. An entry the mapping does not hold (a gallery
-- picture) is dated from its creation_date; one with no date at all stays
-- after every dated entry, in its score order, since it has no place in time.
function M.reorder_by_date(list, kind, shown, chrono_mapping)
    if kind ~= "similar" and kind ~= "different" then
        error("reading-order: kind must be \"similar\" or \"different\", got " .. tostring(kind))
    end
    if type(chrono_mapping) ~= "table" then
        error("reading-order: reorder_by_date needs the chronological mapping")
    end
    local newest_first = (kind == "similar")

    local keyed = {}
    for i = 1, shown do
        local entry = list[i]
        local index = entry.id or (entry.poem and entry.poem.poem_index)
        local m = index and chrono_mapping[index]
        keyed[#keyed + 1] = {
            entry = entry,
            time = (m and m.timestamp) or iso_timestamp(entry.poem and entry.poem.creation_date),
            position = m and m.position,
            score_rank = i,
            index = index or 0,
        }
    end
    table.sort(keyed, function(a, b)
        if (a.time == nil) ~= (b.time == nil) then return a.time ~= nil end
        if a.time == nil then return a.score_rank < b.score_rank end
        if a.time ~= b.time then
            if newest_first then return a.time > b.time end
            return a.time < b.time
        end
        local pa, pb = a.position or math.huge, b.position or math.huge
        if pa ~= pb then
            if newest_first then return pa > pb end
            return pa < pb
        end
        return a.index < b.index
    end)

    local out = {}
    for i, k in ipairs(keyed) do out[i] = k.entry end
    for i = shown + 1, #list do out[#out + 1] = list[i] end
    return out
end
-- }}}

return M
