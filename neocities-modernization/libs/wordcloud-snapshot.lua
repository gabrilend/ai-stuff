-- {{{ wordcloud-snapshot.lua
-- Turns a saved word-cloud page into the version the source browser publishes:
-- the cloud alone, with each word linking to that word's page on the live site.
--
-- Why. Every build saves the word-cloud page it made into archive/wordclouds/,
-- so the history of the cloud can be browsed (Issue 10-063). A saved page is the
-- whole page as it was: a menu, the cloud, and a poem index of thousands of
-- links. Its links were written for the site root ("wordcloud/water.html"), so
-- once published one level deeper, at source/archive/wordclouds/, every one of
-- them pointed at nothing -- 128,565 broken links in one build. The owner's call
-- (2026-10-07): keep only the cloud, point its words at the live site, and if a
-- word has no page today, "oh well". The saved originals in archive/ are not
-- changed; this runs on the copy being published.
--
-- Layout every snapshot shares (checked against all of them, 2026-06 to 2026-10):
--   <body ...> <center>
--   <h1>Menu</h1> <p>...menu links...</p> <hr>          <- removed
--   <h2>Word Cloud</h2> <p>...</p> <p>...cloud...</p> <p>...count...</p>   <- kept
--   <hr> <h2 id="poem-index">Poem Index</h2> ...        <- removed, to </body>
-- A snapshot that does not have these markers is refused, not published as-is:
-- a page in some new shape would otherwise bring its broken links back quietly.
-- }}}

local M = {}

local MENU_START = "<h1>Menu</h1>"
local CLOUD_START = "<h2>Word Cloud</h2>"
local INDEX_START = '<hr>\n<h2 id="poem-index">'

-- {{{ function M.cloud_only
-- html:        string, the saved page.
-- root_prefix: string, the climb from where the copy is published back to the
--              site root, e.g. "../../../" for source/archive/wordclouds/x.html.
--              Relative rather than an absolute address, so the same page works
--              on the live site AND inside the download-everything zip.
-- returns:     string, the trimmed page; or nil plus a reason.
function M.cloud_only(html, root_prefix)
    local menu_at = html:find(MENU_START, 1, true)
    local cloud_at = html:find(CLOUD_START, 1, true)
    local index_at = html:find(INDEX_START, 1, true)
    if not (menu_at and cloud_at and index_at) or not (menu_at < cloud_at and cloud_at < index_at) then
        return nil, "not the expected snapshot layout (menu, then cloud, then poem index)"
    end
    local head = html:sub(1, menu_at - 1)
    local cloud = html:sub(cloud_at, index_at - 1)
    -- Only the cloud's word links are rewritten; it holds no other kind.
    cloud = cloud:gsub('href="wordcloud/', 'href="' .. root_prefix .. 'wordcloud/')
    return head .. cloud .. "</center>\n</body>\n</html>\n"
end
-- }}}

-- {{{ function M.root_prefix_for
-- rel: string, the snapshot's path inside the project ("archive/wordclouds/x.html").
-- It is published at output/source/<rel>, so the climb to output/ is one "../"
-- per folder in rel, plus one for source/.
function M.root_prefix_for(rel)
    local _, folders = rel:gsub("/", "")
    return string.rep("../", folders + 1)
end
-- }}}

return M
