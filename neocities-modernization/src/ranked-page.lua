-- {{{ ranked-page.lua
-- A poem's similar and different pages, and their text exports: the anchor
-- poem, then a page's slice of the ranked list, each poem under its
-- "--- #n source ---" line and drawn by the shared poem drawer
-- (poem-entry.lua), with the page navigation and the download line.
-- (Issue 8-058.)
--
-- Why a module: these pages are built by the worker threads, and a worker can
-- only use code it can load from disk. The same code used to be written out
-- inside the worker, where no test could reach it, while the tests exercised
-- a separate single-threaded copy that no build ran (and that held the only
-- page navigation and download offer). Now the worker and the tests call
-- this one module.
--
-- Everything a page needs about the wider collection arrives in a context
-- (`ctx`) built once per worker:
--   ctx.colors        : table, poem_index -> { color = name } (poem_colors.json)
--   ctx.chrono_map    : table, poem_index -> { page_number, total_pages,
--                       timeline_progress } (where each poem sits on the
--                       chronological pages and the writing timeline)
--   ctx.chrono_paged  : boolean, the chronological view is in numbered pages
--   ctx.poems_per_page: number
--   ctx.head_block    : string, the shared <head> lines
-- }}}

local text_formatter = require("text-formatter")
local poem_entry = require("poem-entry")
-- where a poem lives on the site, by its source key (Issue 8-019)
local poem_address = require("poem-address")
local image_render = require("image-render")
local page_links = require("chronological-page").page_links

local M = {}

-- {{{ function M.source_path
-- How a poem is named on a ranked page (Issue 8-036): "notes/<file name>",
-- "bluesky#<id>", or "<category>/<id>".
function M.source_path(poem)
    local category = poem.category or "unknown"
    -- {{{ dispatch on the source
    if category == "notes" and poem.metadata and poem.metadata.source_file then
        return "notes/" .. poem.metadata.source_file
    elseif category == "bluesky" then
        return "bluesky#" .. (poem.id or 0)
    end
    -- }}}
    return category .. "/" .. (poem.id or poem.poem_index or 0)
end
-- }}}

-- {{{ function M.ranked_list
-- A cached ranking (a list of poem numbers, most similar or most different
-- first) as poems, without the anchor itself (Issue 10-025: the anchor is
-- drawn once, above the list; the diversity cache stores it as its own first
-- entry). Each entry: { poem = <poem>, rank = <place in the cached list> }.
-- A number that is not in poem_by_index is an error: the caches and the poem
-- list disagree (as when notes were renumbered under their embeddings,
-- Issue 8-019), and dropping it quietly would hide that.
function M.ranked_list(ranking, anchor_index, poem_by_index)
    local result = {}
    for rank, index in ipairs(ranking) do
        -- the anchor: drawn above the list, never inside it
        if index ~= anchor_index then
            local poem = poem_by_index[index]
            if not poem then
                error(string.format("the ranking for poem %d names poem %d, which is not in the poem list",
                    anchor_index, index))
            end
            result[#result + 1] = { poem = poem, rank = rank }
        end
    end
    return result
end
-- }}}

-- {{{ function M.plan
-- Which pages a list gets, and how many poems they hold.
-- pages: the requested page numbers (1..N) or "all"; max_pages: the storage
-- cap that "all" stops at (Issue 10-036). Returns (page_numbers, count,
-- total_pages): the pages to write, how many poems of the list they hold,
-- and how many of them hold at least one poem.
function M.plan(list, pages, poems_per_page, max_pages)
    local filled = math.ceil(#list / poems_per_page)
    local numbers = {}
    if pages == "all" then
        for p = 1, math.min(filled, max_pages) do numbers[p] = p end
    else
        for i, p in ipairs(pages) do numbers[i] = p end
    end
    local count = math.min(#list, #numbers * poems_per_page)
    return numbers, count, math.min(#numbers, filled)
end
-- }}}

-- {{{ local function entry()
-- One poem's entry through the shared drawer: its colour, its place on the
-- writing timeline, and its three links. plain: true for a text export.
local function entry(poem, ctx, plain)
    -- a picture-only entry draws its own box and needs no links
    if poem.is_image then
        return poem_entry.format_entry(poem, { plain = plain })
    end
    local index = poem.poem_index
    local color_data = ctx.colors[index]
    -- Issue 8-045: a poem missing from the chronological map has no place on
    -- the timeline and no chronological page; stop rather than guess one
    local chrono = ctx.chrono_map[index]
    if not chrono then
        error("poem " .. tostring(index) .. " is not in the chronological map")
    end
    -- Issue 8-039: a paginated view -> its numbered page; else index.html
    local chrono_page = (ctx.chrono_paged and chrono.total_pages > 1)
        and string.format("%02d.html", chrono.page_number) or "index.html"
    return poem_entry.format_entry(poem, {
        color_name = color_data and color_data.color or "gray",
        progress_pct = chrono.timeline_progress,
        -- Issue 8-019: every address by the poem's source key
        similar_link = poem_address.list_link(poem, "similar"),
        different_link = poem_address.list_link(poem, "different"),
        -- Issue 16-006: the anchor on the chronological page is the poem_index
        chrono_link = poem_address.chrono_link(poem, chrono_page),
        plain = plain,
    })
end
-- }}}

-- {{{ local function ranked_header()
-- The line above the i-th poem of a list: "--- #i source ---" (Issue 8-036).
-- A long name wraps at a dash or slash; the closing " ---" is 4 wide and
-- holds dashes the wrapper would break at, so the name wraps to 76 and the
-- closer goes on its last line.
local function ranked_header(i, poem)
    local header = text_formatter.wrap_file_header(string.format("--- #%d ", i), M.source_path(poem), 76)
    header[#header] = header[#header] .. " ---"
    return table.concat(header, "\n") .. "\n"
end
-- }}}

-- {{{ local function labels()
local function labels(page_type)
    if page_type == "similar" then return "similarity" end
    if page_type == "different" then return "diversity" end
    error("unknown page type: " .. tostring(page_type))
end
-- }}}

-- {{{ function M.page_html
-- One page of a poem's similar or different list, or nil when page_num is
-- past the end of the list. total_pages: how many pages the list has (the
-- navigation line links them, above and below; Issues 8-012, 10-036).
-- download: false, or { file = "fediverse-2339.txt", count = n } -- the line offering
-- the list's text export, after the last poem (Issue 8-013).
function M.page_html(anchor, list, page_type, page_num, total_pages, download, ctx)
    local first = (page_num - 1) * ctx.poems_per_page + 1
    local last = math.min(first + ctx.poems_per_page - 1, #list)
    if first > #list then return nil end
    local type_label = labels(page_type)
    -- Issue 16-010: the shared head block, as on the chronological pages
    local parts = {
        '<!DOCTYPE html><html><head><meta charset="UTF-8">',
        '<title>Poems by ' .. type_label .. ' to ' .. M.source_path(anchor) .. ' (page ' .. page_num .. ')</title>',
        ctx.head_block,
        '</head><body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF"><table align="center"><tr><td><pre>'
    }
    -- page navigation, when the list runs to more than one page
    local nav = page_links(page_num, total_pages, function(n)
        return poem_address.page_file(anchor, n)
    end)
    if nav ~= "" then parts[#parts + 1] = " " .. nav .. "\n\n" end
    parts[#parts + 1] = "=== ANCHOR POEM ===\n"
    parts[#parts + 1] = entry(anchor, ctx)
    parts[#parts + 1] = "\n\n=== " .. type_label:upper() .. " RANKED ===\n\n"
    for i = first, last do
        local poem = list[i].poem
        parts[#parts + 1] = ranked_header(i, poem)
        -- Issue 9-013: a text + picture post gets a direct "image.png" link
        -- under its line (a picture entry's own title already links)
        if not poem.is_image then
            local link = image_render.text_image_link(poem)
            if link ~= "" then parts[#parts + 1] = " " .. link .. "\n" end
        end
        parts[#parts + 1] = entry(poem, ctx)
        parts[#parts + 1] = "\n\n"
    end
    if nav ~= "" then parts[#parts + 1] = " " .. nav .. "\n" end
    -- the download offer: present when the text export is written
    if download then
        parts[#parts + 1] = string.format(" download this list as text: <a href='%s'>%s</a> (%d poems)\n",
            download.file, download.file, download.count)
    end
    parts[#parts + 1] = '</pre></td></tr></table></body></html>'
    return table.concat(parts)
end
-- }}}

-- {{{ function M.text_export
-- The list's text export (Issue 8-013): the first `count` poems of the list,
-- drawn as on the pages but as plain text -- frames kept, no navigation
-- boxes, no links, pictures as their descriptions. No time stamp, so the
-- same inputs give the same bytes.
function M.text_export(anchor, list, page_type, count, ctx)
    local type_label = labels(page_type)
    local parts = {
        string.format("Poems by %s to %s\n", type_label, M.source_path(anchor)),
        string.format("%d poems, in the order of its %s pages\n\n", count, page_type),
        "=== ANCHOR POEM ===\n",
        entry(anchor, ctx, true),
        "\n\n=== " .. type_label:upper() .. " RANKED ===\n\n",
    }
    for i = 1, count do
        local poem = list[i].poem
        parts[#parts + 1] = ranked_header(i, poem)
        parts[#parts + 1] = entry(poem, ctx, true)
        parts[#parts + 1] = "\n\n"
    end
    return table.concat(parts)
end
-- }}}

return M
