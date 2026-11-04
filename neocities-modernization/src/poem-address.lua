-- poem-address.lua: where a poem lives on the site -- its anchor on the
-- chronological pages, its similar and different pages, its text exports --
-- all named by its source key ("fediverse-2339"), never by its number
-- (Issue 8-019).
--
-- Why by key: numbers are counted fresh on every extraction, in date order,
-- so poem 1551 is a different poem after anything older arrives, and an old
-- link would land on it without a sign. A key moves only when an earlier item
-- of its own source leaves (owner, 2026-10-22: accepted). And a link whose
-- poem has moved to the next chronological page finds no anchor on the old
-- page, so the browser shows that page's top -- the owner's rule ("if the
-- specified poem ID doesn't exist on that page, we take them to the top of
-- the page"), with no code on the page.
--
-- A key is letters, digits, "_" and one "-" (the extractor makes it from the
-- source name and a counting number), so it needs no escaping in a file name,
-- an id or an address. One module owns every address, so no page can drift
-- from the others.
--
-- Loaded by the main program and by every page worker.

local M = {}

-- {{{ function M.key
-- The poem's source key; a poem without one is an error (it came from a
-- poem list made before source keys: rerun the extraction).
function M.key(poem)
    local key = poem.source_key
    if type(key) ~= "string" or not key:match("^[%w_]+%-%d+$") then
        error(string.format("poem %s (%s/%s) has no source key; rerun the extraction (stage 3)",
            tostring(poem.poem_index), tostring(poem.category), tostring(poem.id)))
    end
    return key
end
-- }}}

-- {{{ function M.anchor
-- The poem's anchor id on the chronological pages: its key.
function M.anchor(poem)
    return M.key(poem)
end
-- }}}

-- {{{ function M.page_file
-- The file name of page n of the poem's similar or different list
-- ("fediverse-2339-01.html"), inside similar/ or different/.
function M.page_file(poem, n)
    return string.format("%s-%02d.html", M.key(poem), n)
end
-- }}}

-- {{{ function M.text_file
-- The file name of the poem's list as text ("fediverse-2339.txt").
function M.text_file(poem)
    return M.key(poem) .. ".txt"
end
-- }}}

-- {{{ function M.list_link
-- A link from another page (one folder down: ../similar/...) to page 1 of
-- the poem's similar or different list. page_type: "similar" or "different".
function M.list_link(poem, page_type)
    return string.format("<a href='../%s/%s'>%s</a>", page_type, M.page_file(poem, 1), page_type)
end
-- }}}

-- {{{ function M.chrono_href
-- The address of the poem's place on a chronological page, from a page one
-- folder down: "../chronological/03.html#fediverse-2339".
-- chrono_file: the chronological page that holds it ("03.html").
function M.chrono_href(poem, chrono_file)
    return string.format("../chronological/%s#%s", chrono_file, M.anchor(poem))
end
-- }}}

-- {{{ function M.chrono_link
-- The same, as a link reading "chronological".
function M.chrono_link(poem, chrono_file)
    return string.format("<a href='%s'>chronological</a>", M.chrono_href(poem, chrono_file))
end
-- }}}

return M
