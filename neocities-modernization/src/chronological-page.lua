-- {{{ chronological-page.lua
-- The frame around the chronological pages: the page itself (head, title,
-- page navigation, menu link), the line above each poem (its anchor and its
-- file name), the page's file name, and the redirect that sends
-- chronological/index.html to the first page. The poems inside come from
-- poem-entry.lua. (Issue 8-058.)
--
-- Why a module: the chronological pages are built by the same worker threads
-- as the similar and different pages, and a worker can only use code it can
-- load from disk. Everything here was in the main program until the pages
-- moved to the workers; the HTML it writes is unchanged.
-- }}}

local text_formatter = require("text-formatter")

local M = {}

-- {{{ function M.page_links
-- "« First │ ‹ Prev │ Page X of Y │ Next › │ Last »", each a link except
-- where there is nowhere to go; "" for a single page. Shared by every page
-- type that comes in numbered pages (chronological, similar, different).
-- current_page, total_pages: numbers, 1-based
-- file_for: function(page number) -> the file name to link (same folder)
function M.page_links(current_page, total_pages, file_for)
    if total_pages <= 1 then
        return ""
    end
    local parts = {}
    -- {{{ backward links: live unless on the first page
    if current_page > 1 then
        parts[#parts + 1] = string.format("<a href='%s'>« First</a>", file_for(1))
        parts[#parts + 1] = string.format("<a href='%s'>‹ Prev</a>", file_for(current_page - 1))
    else
        parts[#parts + 1] = "« First"
        parts[#parts + 1] = "‹ Prev"
    end
    -- }}}
    parts[#parts + 1] = string.format("Page %d of %d", current_page, total_pages)
    -- {{{ forward links: live unless on the last page
    if current_page < total_pages then
        parts[#parts + 1] = string.format("<a href='%s'>Next ›</a>", file_for(current_page + 1))
        parts[#parts + 1] = string.format("<a href='%s'>Last »</a>", file_for(total_pages))
    else
        parts[#parts + 1] = "Next ›"
        parts[#parts + 1] = "Last »"
    end
    -- }}}
    -- Issue 8-052: the box-drawing vertical, so it matches the frames
    return table.concat(parts, " │ ")
end
-- }}}

-- {{{ function M.navigation
-- The chronological pages' links: 01.html, 02.html, ... within
-- chronological/ (Issue 8-039).
function M.navigation(current_page, total_pages)
    return M.page_links(current_page, total_pages, function(n)
        return string.format("%02d.html", n)
    end)
end
-- }}}

-- {{{ function M.display_filename
-- The name a poem is shown under: "notes/<its original file name>" for notes,
-- "<category>/<id>" for everything else (no ".txt").
function M.display_filename(poem)
    local category = poem.category or "unknown"
    if category == "notes" and poem.metadata and poem.metadata.source_file then
        return category .. "/" .. poem.metadata.source_file
    end
    return category .. "/" .. tostring(poem.id or "unknown")
end
-- }}}

-- {{{ function M.entry_header
-- What sits above each poem on a chronological page: the anchor the other
-- pages link to ("poem-<poem_index>", Issue 16-006) and the " -> file: <name>"
-- line, wrapped at a dash or slash if the name is long. Ends with a newline.
function M.entry_header(poem)
    return string.format('<span id="poem-%d"></span>', poem.poem_index or 0)
        .. table.concat(text_formatter.wrap_file_header(" -> file: ", M.display_filename(poem), 80), "\n")
        .. "\n"
end
-- }}}

-- {{{ function M.file_name
-- "01.html", "02.html", ... when the view has more than one page;
-- "index.html" when it is one page.
function M.file_name(page_num, total_pages)
    if total_pages > 1 then
        return string.format("%02d.html", page_num)
    end
    return "index.html"
end
-- }}}

-- {{{ function M.page_html
-- The whole page around body (the poems' text, already drawn).
-- head_block: string, the shared <head> lines (viewport, font, centring)
function M.page_html(page_num, total_pages, head_block, body)
    -- {{{ one page of many: page numbers in the title, navigation above and below
    if total_pages > 1 then
        local nav = M.navigation(page_num, total_pages)
        local nav_html = nav ~= "" and string.format("<p>%s</p>", nav) or ""
        return table.concat({
            '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="UTF-8">\n',
            string.format("<title>Poetry Collection - Chronological Order (Page %d of %d)</title>\n", page_num, total_pages),
            head_block, "</head>\n",
            '<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">\n<center>\n',
            "<h1>Poetry Collection</h1>\n<p>Poems in true chronological order by post date</p>\n",
            nav_html, "\n",
            '<p><a href="../wordcloud.html">Menu</a></p>\n</center>\n',
            '<table align="center"><tr><td>\n<pre>\n', body, "\n</pre>\n</td></tr></table>\n",
            "<center>", nav_html, "</center>\n</body>\n</html>",
        })
    end
    -- }}}
    -- {{{ the whole view on one page
    return table.concat({
        '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="UTF-8">\n',
        "<title>Poetry Collection - Chronological Order</title>\n",
        head_block, "</head>\n",
        '<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">\n<center>\n',
        "<h1>Poetry Collection</h1>\n<p>All poems in true chronological order by post date</p>\n",
        '<p><a href="../wordcloud.html">Menu</a></p>\n</center>\n',
        '<table align="center"><tr><td>\n<pre>\n', body, "\n</pre>\n</td></tr></table>\n",
        "</body>\n</html>",
    })
    -- }}}
end
-- }}}

-- {{{ function M.redirect_html
-- chronological/index.html when the view is paginated: sends the reader to
-- the first page (Issue 8-039).
function M.redirect_html()
    return [[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="0;url=01.html">
<title>Redirecting...</title>
</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
<p>Redirecting to <a href="01.html">01.html</a>...</p>
</body>
</html>]]
end
-- }}}

return M
