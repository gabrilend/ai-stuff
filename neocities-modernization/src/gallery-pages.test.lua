#!/usr/bin/env luajit

-- Guards issue 10-062: the paginated chronological image gallery.
--
-- What it pins. gallery-pages.lua decides which page a picture is on from its
-- position in the catalog's time order alone; the gallery generator lays its
-- pages out with it and the poem-page renderer writes its links with it. The
-- promise that matters is that the two agree: every picture's link names a page
-- that really holds that picture's anchor, in a build with more pictures than
-- fit on one page. This suite checks the arithmetic, then builds the real pages
-- from a made-up catalog and follows every link.
--
-- It writes the pages to a scratch folder, never to output/.
--
-- Run directly:  luajit src/gallery-pages.test.lua [project-dir]

local DIR = arg and arg[1] or nil

-- {{{ local function setup_path()
local function setup_path()
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*/)") or "./"
    local project_dir = DIR or src_dir:gsub("src/$", "")
    if project_dir == "" then project_dir = "./" end
    if project_dir:sub(-1) ~= "/" then project_dir = project_dir .. "/" end
    package.path = src_dir .. "?.lua;" .. project_dir .. "libs/?.lua;" .. project_dir .. "src/?.lua;"
        .. package.path
    return project_dir
end
-- }}}

local PROJECT = setup_path()
local G = require("gallery-pages")

local SCRATCH = "/tmp/neocities-modernization/tmp/gallery-pages-test"
local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition, detail)
    if condition then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. detail) or ""))
    end
end
-- }}}

-- {{{ local function read_file()
local function read_file(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local contents = handle:read("*a")
    handle:close()
    return contents
end
-- }}}

-- {{{ local function catalog_of()
-- n gallery pictures, deliberately listed NEWEST first so the sort has work to
-- do, spread over the five gallery sources, plus pictures the gallery leaves
-- out (fediverse-media) that must not shift any page.
local function catalog_of(n)
    local sources = G.STANDALONE_SOURCES
    local images = {}
    for i = n, 1, -1 do
        local source = sources[(i - 1) % #sources + 1]
        images[#images + 1] = {
            source_name = source,
            source_directory = "/p/input/images/" .. source,
            relative_path = string.format("/p/input/images/%s/pic-%03d.png", source, i),
            file_path = string.format("/p/input/images/%s/pic-%03d.png", source, i),
            filename = string.format("pic-%03d.png", i),
            modification_time = 1700000000 + i * 60,
            -- The anchor is the hash's first 12 characters, so they must differ there.
            hash = string.format("%012x", i) .. string.rep("0", 20),
        }
        if i % 4 == 0 then
            images[#images + 1] = { source_name = "fediverse-media", modification_time = 1700000000 + i * 60,
                hash = string.format("ffff%08x", i) .. string.rep("0", 20), relative_path = "files/x.png", filename = "x.png" }
        end
    end
    return { images = images }
end
-- }}}

-- {{{ Case: the arithmetic
do
    check("page size is the total split into ten, rounded up", G.page_size(95, 10) == 10 and G.page_size(101, 10) == 11)
    check("an empty gallery still has a page size", G.page_size(0, 10) == 1)
    check("positions 1..size are page 1", G.page_of(1, 10) == 1 and G.page_of(10, 10) == 1)
    check("the next position starts page 2", G.page_of(11, 10) == 2)
    check("25 pictures in pages of 3 fill 9 pages, never more than ten", G.pages_used(25, G.page_size(25, 10)) == 9)
    check("1001 pictures fill exactly ten pages", G.pages_used(1001, G.page_size(1001, 10)) == 10)
    check("forward page names are zero-padded", G.page_file(3, "forward") == "chronological-03.html")
    check("reverse page names say so", G.page_file(10, "reverse") == "chronological-reverse-10.html")
    check("an unknown direction is refused", not pcall(G.page_file, 1, "sideways"))
    for _, bad in ipairs({ 0, -1, 2.5, "10" }) do
        check("a page count of " .. tostring(bad) .. " (" .. type(bad) .. ") is refused",
            not pcall(G.page_size, 10, bad))
    end
    check("a missing page count is refused", not pcall(G.build_index, catalog_of(3), nil))
end
-- }}}

-- {{{ Case: the order and the index
do
    local index = G.build_index(catalog_of(23), 10)
    check("only the gallery's sources are counted", index.total == 23, tostring(index.total))
    check("23 pictures make pages of 3", index.page_size == 3 and index.pages == 8,
        index.page_size .. " / " .. index.pages)
    check("the order is oldest first", index.sorted[1].filename == "pic-001.png"
        and index.sorted[23].filename == "pic-023.png")
    local a = G.anchor(index.sorted[7], 7)
    check("a picture's anchor is its hash's first 12 characters", a == "img-" .. string.format("%012x", 7))
    check("the 7th picture is on page 3", index.by_anchor[a] == 3)
    check("its link names that page", G.link_for(index, a) == "chronological-03.html#" .. a)
    check("an anchor the gallery does not hold has no link", G.link_for(index, "img-nowhere") == nil)

    -- Same timestamp: the order falls back to the hash, whatever order the
    -- catalog lists them in, so the pages are the same on every build.
    local tie1 = { images = {
        { source_name = "my-art", modification_time = 5, hash = "bbb", relative_path = "b" },
        { source_name = "my-art", modification_time = 5, hash = "aaa", relative_path = "a" },
    } }
    local tie2 = { images = { tie1.images[2], tie1.images[1] } }
    local s1, s2 = G.build_index(tie1, 10).sorted, G.build_index(tie2, 10).sorted
    check("pictures with the same time are ordered by hash, whatever the catalog order",
        s1[1].hash == "aaa" and s2[1].hash == "aaa")
    check("sorting does not reorder the catalog itself", tie1.images[1].hash == "bbb")
end
-- }}}

-- {{{ Case: the real pages, and every link followed
do
    os.execute('rm -rf "' .. SCRATCH .. '"; mkdir -p "' .. SCRATCH .. '"')
    -- The generator reads arg[1] as its project folder, as when run by run.sh.
    local gallery = require("generate-gallery-pages")
    local catalog = catalog_of(23)
    -- A stale page from a build that had more pages must not survive.
    local stale = io.open(SCRATCH .. "/chronological-09.html", "w"); stale:write("old"); stale:close()

    local ok, written, index = pcall(gallery.write_chronological_pages, SCRATCH, catalog, 10)
    check("the pages build", ok, tostring(written))
    check("8 pages each way plus chronological.html", ok and #written == 17, ok and tostring(#written) or "")
    check("a page left over from a bigger build is removed", read_file(SCRATCH .. "/chronological-09.html") == nil)
    check("chronological.html is the first forward page, for old links",
        read_file(SCRATCH .. "/chronological.html") == read_file(SCRATCH .. "/chronological-01.html"))

    -- Every picture: its link names a page that holds its anchor, forward; and
    -- the reverse view holds it too, exactly once.
    local all_found, reverse_found = true, true
    local missing = nil
    for position, img in ipairs(index.sorted) do
        local anchor = G.anchor(img, position)
        local file, frag = G.link_for(index, anchor):match("^(.-)#(.+)$")
        local page = read_file(SCRATCH .. "/" .. file) or ""
        if not page:find('<a name="' .. frag .. '">', 1, true) then
            all_found = false; missing = missing or (anchor .. " not on " .. file)
        end
        local hits = 0
        for p = 1, index.pages do
            local rpage = read_file(SCRATCH .. "/" .. G.page_file(p, "reverse")) or ""
            local _, n = rpage:gsub('<a name="' .. anchor:gsub("%-", "%%-") .. '">', "")
            hits = hits + n
        end
        if hits ~= 1 then reverse_found = false end
    end
    check("every picture's link lands on a page holding its anchor", all_found, missing)
    check("every picture is in the reverse view exactly once", reverse_found)

    local f1 = read_file(SCRATCH .. "/chronological-01.html") or ""
    local r1 = read_file(SCRATCH .. "/chronological-reverse-01.html") or ""
    local f8 = read_file(SCRATCH .. "/chronological-08.html") or ""
    check("forward page 1 starts with the oldest picture", f1:find("pic-001.png", 1, true) ~= nil
        and f1:find("pic-004.png", 1, true) == nil)
    check("reverse page 1 starts with the newest", r1:find("pic-023.png", 1, true) ~= nil
        and r1:find("pic-001.png", 1, true) == nil)
    check("the last forward page holds the remainder", f8:find("pic-022.png", 1, true) ~= nil
        and f8:find("pic-023.png", 1, true) ~= nil and f8:find("this page: 22 to 23", 1, true) ~= nil)

    -- The jump bar: 1..8, three spaces apart, the page being read bold and unlinked.
    check("the jump bar links every other page, three spaces apart",
        f1:find('<b>1</b>   <a href="chronological-02.html">2</a>   <a href="chronological-03.html">3</a>', 1, true) ~= nil)
    check("it stops at the last page", f1:find('<a href="chronological-08.html">8</a></pre>', 1, true) ~= nil
        and not f1:find("chronological-09.html", 1, true))
    check("the reverse view's bar links reverse pages",
        r1:find('<b>1</b>   <a href="chronological-reverse-02.html">2</a>', 1, true) ~= nil)
    local _, bars = f1:gsub('<b>1</b>   ', "")
    check("the bar is at the top and the bottom", bars == 2)

    check("forward pages offer the newest-first view",
        f1:find('<b>oldest first</b> &#9474; <a href="chronological-reverse-01.html">newest first</a>', 1, true) ~= nil)
    check("reverse pages offer the oldest-first view",
        r1:find('<a href="chronological-01.html">oldest first</a> &#9474; <b>newest first</b>', 1, true) ~= nil)

    -- Captions name the next picture only when it is on the same page.
    local f2 = read_file(SCRATCH .. "/chronological-02.html") or ""
    check("a caption names the picture below it on the same page",
        f2:find("pic%-004%.png\n\n[^\n]*pic%-005%.png") ~= nil)
    check("the last picture of a page names nothing below it",
        f2:find("pic%-006%.png\n\n─") ~= nil and f2:find("pic-007.png", 1, true) == nil)

    check("titles say which page", f8:find("<title>Images — Chronological (page 8 of 8)</title>", 1, true) ~= nil)

    -- An empty gallery: one page each way, saying so.
    os.execute('rm -rf "' .. SCRATCH .. '"; mkdir -p "' .. SCRATCH .. '"')
    ok, written = pcall(gallery.write_chronological_pages, SCRATCH, { images = {} }, 10)
    check("an empty gallery writes one page each way", ok and #written == 3, tostring(written))
    check("and says it is empty", (read_file(SCRATCH .. "/chronological-01.html") or ""):find("0 images", 1, true) ~= nil)

    check("a bad page count stops the build",
        not pcall(gallery.write_chronological_pages, SCRATCH, catalog, 0))
    check("the shipped config asks for ten pages",
        dofile(PROJECT .. "config.lua").pagination.gallery_chronological_pages == 10)
end
-- }}}

os.execute('rm -rf "' .. SCRATCH .. '"')
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
