#!/usr/bin/env luajit
-- {{{ wordcloud-snapshot.test.lua
-- Tests for trimming a saved word-cloud page down to the cloud. The real
-- snapshots in archive/ are checked too, since the trim relies on markers every
-- one of them must carry -- a snapshot in a new shape should fail here, not
-- reach the site with its broken links.
--
-- Usage: luajit libs/wordcloud-snapshot.test.lua [DIR]
-- }}}

local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/libs/?.lua;" .. package.path
local snap = require("wordcloud-snapshot")

local passed, failed = 0, 0

-- {{{ local function check
local function check(name, ok, detail)
    if ok then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. detail) or ""))
    end
end
-- }}}

print("cloud_only")
do
    local page = table.concat({
        "<html><head><style>.w{}</style></head>",
        '<body bgcolor="#000000">', "<center>",
        "<h1>Menu</h1>", '<p><a href="explore.html">Explore</a></p>', "<hr>",
        "<h2>Word Cloud</h2>", '<p><a href="wordcloud/water.html">water</a></p>',
        "<hr>", '<h2 id="poem-index">Poem Index</h2>',
        '<pre><a href="chronological/65.html#poem-1">1</a></pre>',
        "</center>", "</body></html>",
    }, "\n")
    local out = snap.cloud_only(page, "../../../")
    check("keeps the cloud", out and out:find("<h2>Word Cloud</h2>", 1, true) ~= nil)
    check("keeps the page head (the cloud's styles)", out and out:find("<style>", 1, true) ~= nil)
    check("drops the menu", out and out:find("Menu", 1, true) == nil)
    check("drops the poem index", out and out:find("poem-index", 1, true) == nil
        and out:find("chronological/", 1, true) == nil)
    check("word links climb to the site root",
        out and out:find('href="../../../wordcloud/water.html"', 1, true) ~= nil)
    check("closes the page", out and out:find("</body>\n</html>", 1, true) ~= nil)

    local bad, why = snap.cloud_only("<html><body>no markers</body></html>", "../")
    check("a page in another shape is refused", bad == nil and why ~= nil)
end

print("root_prefix_for")
check("archive/wordclouds/x.html climbs three levels",
    snap.root_prefix_for("archive/wordclouds/x.html") == "../../../")
check("archive/x.html climbs two levels", snap.root_prefix_for("archive/x.html") == "../../")

print("every real snapshot has the expected layout")
do
    local listing = io.popen('find "' .. DIR .. '/archive" -name "*.html"')
    local count = 0
    for path in listing:lines() do
        local f = io.open(path, "rb")
        local html = f:read("*a")
        f:close()
        local out, why = snap.cloud_only(html, "../../../")
        check(path:match("archive/.*$"), out ~= nil, why)
        count = count + 1
    end
    listing:close()
    check("found snapshots to check", count > 0, tostring(count))
end

print("")
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
