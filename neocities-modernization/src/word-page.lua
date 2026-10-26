-- word-page.lua: one word-cloud word's page -- the poems closest in meaning
-- to the word, each drawn by the shared poem drawer. Loaded by the page
-- workers, which draw these pages beside the similar, different and
-- chronological pages (Issue 10-035); the ranking that chooses the poems is
-- done before, by src/generate-word-pages.lua.
--
-- poem-entry must have been configured in the same Lua state.

local poem_entry = require("poem-entry")
local chronological_page = require("chronological-page")
local text_formatter = require("text-formatter")
local page_head = require("page-head")
-- where a poem lives on the site, by its source key (Issue 8-019)
local poem_address = require("poem-address")

local M = {}

-- {{{ function M.file_name
-- The page's file name under wordcloud/: the word in lower case, letters and
-- digits only ("Don't" -> "dont.html"), as the word cloud links to it.
function M.file_name(word)
    return word:lower():gsub("[^%w]", "") .. ".html"
end
-- }}}

-- {{{ function M.entry
-- One poem on a word page: its " -> file:" line, then its entry from the
-- shared drawer (Issue 8-058), so it looks as it does on every other page.
-- poem        : a poem from poems.json
-- color_name  : string, its semantic colour ("gray" when it has none)
-- progress_pct: number 0-100, its place on the writing timeline (8-045)
-- chrono_file : string, the chronological page holding it ("03.html")
function M.entry(poem, color_name, progress_pct, chrono_file)
    local header = table.concat(text_formatter.wrap_file_header(" -> file: ",
        chronological_page.display_filename(poem), 80), "\n")
    return header .. "\n" .. poem_entry.format_entry(poem, {
        color_name = color_name,
        progress_pct = progress_pct,
        similar_link = poem_address.list_link(poem, "similar"),
        different_link = poem_address.list_link(poem, "different"),
        chrono_link = poem_address.chrono_link(poem, chrono_file),
    })
end
-- }}}

-- {{{ function M.page_html
-- The whole page around its poems.
-- word         : string, as shown
-- header_color : string "#rrggbb", the word's semantic colour (Issue 8-050c)
-- centre_link  : string, the chronological page and anchor of the poem
--                nearest the centre of this page's poems (Issue 8-050e)
-- count        : number of poems on the page
-- body         : string, the poems' entries, already drawn
-- The <head> comes from the shared page-head module, as on every page; each
-- <pre> centres as an inline block (text stays left) so the poem column sits
-- on the page centre line even when a picture is wider.
function M.page_html(word, header_color, centre_link, count, body)
    local base_path = ".."
    local head = page_head.head({
        title = "Poems similar to: " .. word,
        base_path = base_path,
        extra_css = "td { text-align: center; } pre { display: inline-block; text-align: left; margin: 0 auto; }\n"
                 .. "img, video, audio { margin-left: auto; margin-right: auto; }",
    })
    return string.format([[<!DOCTYPE html>
<html>
%s
]] .. require("page-theme").body_tag() .. [[
<center>
<h1>Poems similar to: <i><font color="%s">%s</font></i></h1>
<p>The %d poems closest in meaning to this word, arranged to spread the colours (progress bar shows chronological position)</p>
<!-- Issue 16-011: Changed main.html to wordcloud.html (main.html doesn't exist) -->
<p><a href="%s/wordcloud.html">Menu</a> │ <a href="%s">Chronological</a></p>
</center>
<hr>
<table align="center"><tr><td>
<pre>
]], head, header_color, word, count, base_path, centre_link) .. body .. [[</pre>
</td></tr></table>
</body>
</html>
]]
end
-- }}}

return M
