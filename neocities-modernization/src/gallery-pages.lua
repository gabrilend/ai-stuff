-- gallery-pages.lua
--
-- Issue 10-062: which page of the chronological image gallery a picture is on.
--
-- WHAT IT DOES (for a CEO): the chronological image gallery used to be one very
-- long page. It is now split into pages, forward (oldest first) and reverse
-- (newest first). A poem page that shows a picture links to that picture's spot
-- in the gallery, so the link has to name the right page. This module is the one
-- place that decides it: the gallery generator uses it to lay out its pages, and
-- the poem-page renderer uses it to write its links, so the two cannot disagree.
--
-- HOW A PAGE IS CHOSEN: from the picture's position in the catalog's
-- chronological order, nothing else. Sort the gallery's pictures by time (ties
-- broken by hash, then path, so the order never depends on the catalog file's
-- order), take page_size = ceil(total / page_count), and a picture at 0-based
-- position i is on page floor(i / page_size) + 1. No earlier pipeline stage
-- records anything: both users read the same catalog and call the same function.
-- (With few pictures this can give fewer than page_count pages -- 25 pictures
-- in pages of 3 fill 9 -- never more.)
--
-- Dependency-free on purpose: it is also required inside the HTML generator's
-- effil worker threads, each with its own fresh Lua state.

local M = {}

-- The image sources the gallery shows. fediverse-media is left out: those
-- pictures are poem attachments and appear inline with their poems.
M.STANDALONE_SOURCES = {
    "my-art",
    "things-I-almost-posted",
    "poem-pictures",
    "dnd-pictures-from-the-internet",
    "fediverse-stars",
}

-- {{{ function M.standalone_images()
-- The catalog's pictures that the gallery shows, in catalog order.
function M.standalone_images(catalog)
    local wanted = {}
    for _, source in ipairs(M.STANDALONE_SOURCES) do wanted[source] = true end
    local images = {}
    for _, img in ipairs((catalog and catalog.images) or {}) do
        if wanted[img.source_name] then images[#images + 1] = img end
    end
    return images
end
-- }}}

-- {{{ function M.sort_chronological()
-- A NEW list, oldest first. The tie-breaks matter: table.sort is not stable,
-- and two pictures with the same timestamp (a folder copied at once) would
-- otherwise swap places between builds -- and with them, possibly, pages.
function M.sort_chronological(images)
    local sorted = {}
    for i, img in ipairs(images) do sorted[i] = img end
    table.sort(sorted, function(a, b)
        local ta, tb = tonumber(a.modification_time) or 0, tonumber(b.modification_time) or 0
        if ta ~= tb then return ta < tb end
        local ha, hb = a.hash or "", b.hash or ""
        if ha ~= hb then return ha < hb end
        return (a.relative_path or "") < (b.relative_path or "")
    end)
    return sorted
end
-- }}}

-- {{{ function M.anchor()
-- A picture's anchor on its gallery page, "img-" + the first 12 characters of
-- its content hash. augment-embeddings-with-images.lua writes the same string
-- into the image manifest (gallery_anchor), which is how a poem page knows
-- which picture it is linking to. A picture with no hash is anchored by its
-- 1-based chronological position instead; nothing links to those.
function M.anchor(img, position)
    return "img-" .. (img.hash and img.hash:sub(1, 12) or tostring(position))
end
-- }}}

-- {{{ function M.check_page_count()
-- config.pagination.gallery_chronological_pages: a whole number, at least 1.
-- Anything else is an error (no fallbacks).
function M.check_page_count(page_count)
    if type(page_count) ~= "number" or page_count < 1 or page_count ~= math.floor(page_count) then
        error(string.format("gallery pages: config.pagination.gallery_chronological_pages must be "
            .. "a whole number, at least 1; got %s", tostring(page_count)))
    end
    return page_count
end
-- }}}

-- {{{ function M.page_size()
-- Pictures per page: the total split into page_count pages, rounded up. At
-- least 1, so an empty gallery still has a (single, empty) first page.
function M.page_size(total, page_count)
    M.check_page_count(page_count)
    return math.max(1, math.ceil(total / page_count))
end
-- }}}

-- {{{ function M.pages_used()
-- How many pages the gallery actually fills: at least 1.
function M.pages_used(total, page_size)
    return math.max(1, math.ceil(total / page_size))
end
-- }}}

-- {{{ function M.page_of()
-- The page (1-based) of the picture at 1-based position `position` in a view.
-- The same formula serves both directions: in the reverse view a picture's
-- position is total - forward_position + 1.
function M.page_of(position, page_size)
    return math.floor((position - 1) / page_size) + 1
end
-- }}}

-- {{{ function M.page_file()
-- The file name of a page: chronological-NN.html (forward, oldest first) or
-- chronological-reverse-NN.html (newest first), NN zero-padded to two places
-- like the poem chronological pages (chronological/01.html).
function M.page_file(page, direction)
    if direction == "reverse" then
        return string.format("chronological-reverse-%02d.html", page)
    elseif direction == "forward" then
        return string.format("chronological-%02d.html", page)
    end
    error("gallery pages: direction must be \"forward\" or \"reverse\", got " .. tostring(direction))
end
-- }}}

-- {{{ function M.build_index()
-- Everything both users need, from the catalog alone:
--   sorted     the gallery's pictures, oldest first
--   total, page_size, pages
--   by_anchor  anchor -> forward page number
function M.build_index(catalog, page_count)
    local sorted = M.sort_chronological(M.standalone_images(catalog))
    local size = M.page_size(#sorted, page_count)
    local index = {
        sorted = sorted,
        total = #sorted,
        page_size = size,
        pages = M.pages_used(#sorted, size),
        by_anchor = {},
    }
    for position, img in ipairs(sorted) do
        index.by_anchor[M.anchor(img, position)] = M.page_of(position, size)
    end
    return index
end
-- }}}

-- {{{ function M.link_for()
-- The gallery-relative link to one picture -- "chronological-NN.html#img-..." --
-- or nil when the anchor is not a picture the gallery shows (a source the
-- gallery leaves out), so the caller can leave the title unlinked rather than
-- point at a spot that does not exist.
function M.link_for(index, anchor)
    local page = index.by_anchor[anchor]
    if not page then return nil end
    return M.page_file(page, "forward") .. "#" .. anchor
end
-- }}}

return M
