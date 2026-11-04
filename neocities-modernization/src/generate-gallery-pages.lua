#!/usr/bin/env luajit

-- {{{ generate-gallery-pages.lua
-- Issue 10-042a: Generate HTML gallery pages for standalone images
-- Creates gallery index and per-source gallery pages from image-catalog.json
--
-- Usage:
--   luajit src/generate-gallery-pages.lua [--dir PATH]
--
-- Output:
--   output/gallery/index.html - Gallery index listing all sources
--   output/gallery/my-art.html - Gallery for my-art images
--   output/gallery/poem-pictures.html - Gallery for poem-pictures images
--   output/gallery/things-i-almost-posted.html - Gallery for things-i-almost-posted
--   output/gallery/dnd-pictures.html - Gallery for dnd-pictures
--   output/gallery/fediverse-stars.html - Gallery for fediverse-stars
--
-- Note: fediverse-media is excluded as those images are inline with poems
-- }}}

-- --help: print the header above and exit, when run as a program (libs/script-help.lua)
dofile((debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./") .. "../libs/script-help.lua").handle_if_run(arg, debug.getinfo(1, "S").source:sub(2))

-- The project folder: --dir PATH, or the path below; a stray word stops the
-- program, named (libs/project-dir.lua, Issue 10-076). It used to be any bare
-- word, which is why its old parser had to swallow --assets' value by hand
-- (Issue 10-065): an unswallowed folder became the project root. --assets is
-- declared as taking a value, so the reader does that now. The assets folder
-- itself is read by utils.init_assets_root.
local DIR = dofile((debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./") .. "../libs/project-dir.lua")
    .read_if_run(arg, debug.getinfo(1, "S").source:sub(2),
        "/mnt/mtwo/programming/ai-stuff/neocities-modernization", { ["--assets"] = true })
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path

local dkjson = require("dkjson")
local utils = require("utils")
-- Issue 10-042d / 9-013: shared "source: sub: name.png" title helper
local image_titles = require("image-pseudo-embeddings")
-- Issue 10-062: which chronological page each picture is on (shared with the
-- poem-page renderer, so its links land on the same page)
local gallery_pages = require("gallery-pages")
utils.init_assets_root(arg)

-- Issue 10-003: Load unified config from config.lua
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local config = config_loader.load()

local M = {}

-- {{{ Configuration
-- The gallery's sources, their page names and titles, and the grid, all
-- from config.lua (sources.images): a source with a `gallery` entry is on
-- the gallery, in the order config lists it. (Issue 10-062: gallery-pages.lua
-- applies the same rule, standalone_sources(), so the poem-page renderer
-- counts exactly the same pictures to know which page one is on.)
local images_config = config.sources and config.sources.images
    or error("config.lua has no sources.images section")
local STANDALONE_SOURCES, SOURCE_SLUGS, SOURCE_TITLES = {}, {}, {}
for _, source in ipairs(images_config.directories or {}) do
    if source.gallery then
        STANDALONE_SOURCES[#STANDALONE_SOURCES + 1] = source.name
        SOURCE_SLUGS[source.name] = source.gallery.slug
            or error("config.lua: gallery source " .. source.name .. " has no slug")
        SOURCE_TITLES[source.name] = source.gallery.title
            or error("config.lua: gallery source " .. source.name .. " has no title")
    end
end
local layout = images_config.gallery_layout or error("config.lua has no sources.images.gallery_layout")
local COLUMNS = layout.columns or error("gallery_layout.columns missing")
local THUMBNAIL_WIDTH = layout.thumbnail_width or error("gallery_layout.thumbnail_width missing")
local MASONRY_GAP = layout.column_gap or error("gallery_layout.column_gap missing")     -- px between columns
local MASONRY_VGAP = layout.picture_gap or error("gallery_layout.picture_gap missing")  -- px between stacked pictures
-- }}}

-- {{{ load_image_catalog
local function load_image_catalog()
    local catalog_path = DIR .. "/assets/image-catalog.json"
    local file = io.open(catalog_path, "r")
    if not file then
        require("output").print("Error: Could not open " .. catalog_path)
        return nil
    end

    local content = file:read("*a")
    file:close()

    local data, pos, err = dkjson.decode(content)
    if err then
        require("output").print("Error parsing image catalog: " .. tostring(err))
        return nil
    end

    return data
end
-- }}}

-- {{{ filter_standalone_images
-- Filter to only standalone images (exclude fediverse-media)
local function filter_standalone_images(catalog)
    return gallery_pages.standalone_images(catalog)
end
-- }}}

-- {{{ group_by_source
-- Group images by their source_name
local function group_by_source(images)
    local groups = {}
    for _, img in ipairs(images) do
        local source = img.source_name
        if not groups[source] then
            groups[source] = {}
        end
        table.insert(groups[source], img)
    end
    return groups
end
-- }}}

-- {{{ url_encode_path
-- Percent-encode a relative URL path so filenames containing spaces, ?, #, %,
-- parentheses, etc. don't break the href/src. Path separators (/) and the safe
-- set [A-Za-z0-9-._~] are preserved, so the "../../gallery/..." structure still
-- resolves; only the unsafe bytes inside each segment are escaped. Without this
-- a space silently truncated the src and the browser drew a broken-image icon.
local function url_encode_path(path)
    return (path:gsub("[^%w%-%._~/]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end
-- }}}

-- {{{ get_relative_image_path
-- Convert absolute path to a URL-safe relative path from output/gallery/.
local function get_relative_image_path(absolute_path)
    -- Reference the copy in output/media/, not the original under input/. The
    -- original under input/ is never uploaded, so a "../../input/images/..." path
    -- 404s in production. Gallery pages live in output/gallery/, so a "../media/"
    -- relative path reaches the copy both locally and deployed (both under
    -- /similar-different/) with no rewrite.
    --
    -- LAYOUT must match flatten_media_files + media_href in the other generators:
    -- art images keep their <source>/<subpath> (so my-art/x.png and
    -- my-art/game-design/x.png don't collide into one output/media/x.png);
    -- Mastodon hashes collapse to the bare basename. url_encode_path preserves
    -- the slashes between segments.
    local path = absolute_path or ""
    local sub = path:match("input/images/(.+)$") or (path:match("([^/]+)$") or path)
    return url_encode_path("../media/" .. sub)
end
-- }}}

-- {{{ caption_with_breaks
-- Render a filename as a thumbnail caption that WRAPS on dashes/underscores
-- instead of being chopped to 20 chars + "...". We HTML-escape the name, then
-- insert <wbr> (a zero-width break opportunity) after each - or _ so a long
-- name like "dnd-pictures-from-the-internet-04" folds onto several lines inside
-- the thumbnail column rather than truncating or overflowing. The caller wraps
-- this in a width-constrained span so the breaks actually engage.
local function caption_with_breaks(filename)
    local safe = filename:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    return (safe:gsub("([%-_])", "%1<wbr>"))
end
-- }}}

-- {{{ extract_display_name
-- Extract a display name from filename (used as alt text)
local function extract_display_name(filename)
    -- Remove extension
    local name = filename:match("^(.+)%.[^%.]+$") or filename
    -- Convert dashes/underscores to spaces
    name = name:gsub("[%-_]", " ")
    -- Title case (capitalize first letter of each word)
    name = name:gsub("(%a)([%w]*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
    return name
end
-- }}}

-- {{{ generate_html_header
local function generate_html_header(title)
    -- every colour from config.lua html_theme, through the shared theme (one place)
    local theme = require("page-theme").colours()
    local bg, text, link, vlink = theme.background, theme.text, theme.link, theme.vlink

    return string.format([[<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>%s</title>
</head>
<body bgcolor="%s" text="%s" link="%s" vlink="%s">
<center>
]], title, bg, text, link, vlink)
end
-- }}}

-- {{{ generate_html_footer
local function generate_html_footer()
    return [[
</center>
</body>
</html>
]]
end
-- }}}

-- {{{ generate_gallery_grid
-- Generate a MASONRY layout for images. The old fixed <table> grid forced every
-- row to the height of its tallest image, so portrait/landscape mixes left big
-- ragged vertical gaps. CSS multi-column layout packs each column independently
-- (an item flows under the previous one in its column), giving uniform ~18px
-- gaps and no wasted space -- and needs no JavaScript, so it still works as a
-- plain neocities page. break-inside:avoid keeps an image and its caption
-- together rather than splitting them across a column boundary.
local function generate_gallery_grid(images)
    local html = {}
    -- Cap the masonry to COLUMNS columns and center the whole block. column-width
    -- (not column-count) lets it gracefully drop to fewer columns on narrow
    -- screens while holding the thumbnail size.
    -- Exactly COLUMNS columns (the user wants four, always). Each column is an
    -- independent vertical stack: an item flows directly under the previous one
    -- in its column, no row alignment -- that is what CSS multi-column does. The
    -- container max-width keeps the columns near the thumbnail size and centers
    -- the block. Items are display:block (not inline-block, which would add a
    -- baseline gap) so they pack as close as MASONRY_VGAP allows.
    local container_max = (THUMBNAIL_WIDTH + MASONRY_GAP) * COLUMNS
    table.insert(html, string.format(
        '<div style="column-count:%d; column-gap:%dpx; max-width:%dpx; margin:0 auto;">\n',
        COLUMNS, MASONRY_GAP, container_max))

    for _, img in ipairs(images) do
        local rel_path = get_relative_image_path(img.file_path)
        local alt_text = extract_display_name(img.filename)
        table.insert(html, string.format(
            '  <div style="display:block; margin:0 0 %dpx; text-align:center; ' ..
            'break-inside:avoid; -webkit-column-break-inside:avoid;">' ..
            '<a href="%s"><img src="%s" alt="%s" title="%s" loading="lazy" border="1" ' ..
            'style="width:100%%; height:auto; display:block;"></a>' ..
            '<font size="1"><span style="display:inline-block; max-width:%dpx; ' ..
            'word-wrap:break-word; overflow-wrap:break-word;">%s</span></font>' ..
            '</div>\n',
            MASONRY_VGAP, rel_path, rel_path, alt_text, alt_text,
            THUMBNAIL_WIDTH, caption_with_breaks(img.filename)
        ))
    end

    table.insert(html, '</div>\n')
    return table.concat(html)
end
-- }}}

-- {{{ generate_source_gallery
-- Generate a gallery page for a specific source
local function generate_source_gallery(source_name, images)
    local slug = SOURCE_SLUGS[source_name]
    local title = SOURCE_TITLES[source_name]

    local html = {}
    table.insert(html, generate_html_header("Gallery: " .. title))

    -- Navigation
    table.insert(html, '<p>')
    table.insert(html, '<a href="../wordcloud.html">Menu</a> | ')
    table.insert(html, '<a href="index.html">Gallery Index</a>')
    table.insert(html, '</p>\n')

    -- Title
    table.insert(html, '<h1>' .. title .. '</h1>\n')
    table.insert(html, '<p>' .. #images .. ' images</p>\n')
    table.insert(html, '<hr width="80%">\n')

    -- Grid
    table.insert(html, generate_gallery_grid(images))

    -- Footer nav
    table.insert(html, '<hr width="80%">\n')
    table.insert(html, '<p><a href="index.html">Back to Gallery Index</a></p>\n')

    table.insert(html, generate_html_footer())

    return table.concat(html), slug .. ".html"
end
-- }}}

-- {{{ generate_gallery_index
-- Generate the main gallery index page
local function generate_gallery_index(grouped_images)
    local html = {}
    table.insert(html, generate_html_header("Gallery"))

    -- Navigation
    table.insert(html, '<p>')
    table.insert(html, '<a href="../wordcloud.html">Menu</a> | ')
    table.insert(html, '<a href="../explore.html">Explore</a> | ')
    table.insert(html, '<a href="' .. gallery_pages.page_file(1, "forward") .. '">Chronological</a>')
    table.insert(html, '</p>\n')

    -- Title
    table.insert(html, '<h1>Image Gallery</h1>\n')

    -- Count total
    local total = 0
    for _, images in pairs(grouped_images) do
        total = total + #images
    end
    table.insert(html, '<p>' .. total .. ' standalone images across ' .. #STANDALONE_SOURCES .. ' collections</p>\n')
    table.insert(html, '<hr width="80%">\n')

    -- Source list with representative thumbnails
    table.insert(html, '<table border="0" cellpadding="20" cellspacing="10">\n')

    for _, source_name in ipairs(STANDALONE_SOURCES) do
        local images = grouped_images[source_name]
        if images and #images > 0 then
            local slug = SOURCE_SLUGS[source_name]
            local title = SOURCE_TITLES[source_name]

            -- Pick a representative image (first one)
            local rep_img = images[1]
            local rel_path = get_relative_image_path(rep_img.file_path)

            table.insert(html, '<tr>\n')
            table.insert(html, string.format(
                '  <td align="center" valign="middle">' ..
                '<a href="%s.html"><img src="%s" width="150" loading="lazy" border="1"></a></td>\n',
                slug, rel_path
            ))
            table.insert(html, string.format(
                '  <td valign="middle"><h2><a href="%s.html">%s</a></h2>' ..
                '<p>%d images</p></td>\n',
                slug, title, #images
            ))
            table.insert(html, '</tr>\n')
        end
    end

    table.insert(html, '</table>\n')

    -- Footer
    table.insert(html, '<hr width="80%">\n')
    table.insert(html, '<p><a href="../wordcloud.html">Back to Menu</a></p>\n')

    table.insert(html, generate_html_footer())

    return table.concat(html)
end
-- }}}

-- {{{ image_qualified_title
-- "source: sub: name.png" for a catalog image: strip the (absolute)
-- source_directory prefix off relative_path, then delegate to the shared title
-- helper that poem-page image entries also use (Issue 9-013 / 10-042d).
local function image_qualified_title(img)
    local full = img.relative_path or ""
    local base = img.source_directory or ""
    local rel = (base ~= "" and full:sub(1, #base) == base)
        and (full:sub(#base + 1):gsub("^/+", ""))
        or (img.filename or full)
    return image_titles.qualified_image_title(img.source_name, rel)
end
-- }}}

-- {{{ jump_bar
-- Issue 10-062: the page numbers, three spaces apart, each a link to that page
-- of the same view; the page being read is bold and not a link. In a <pre> so
-- the three spaces survive.
local function jump_bar(current, pages, direction)
    local cells = {}
    for p = 1, pages do
        if p == current then
            cells[#cells + 1] = "<b>" .. p .. "</b>"
        else
            cells[#cells + 1] = string.format('<a href="%s">%d</a>', gallery_pages.page_file(p, direction), p)
        end
    end
    return '<pre style="text-align:center">' .. table.concat(cells, "   ") .. '</pre>'
end
-- }}}

-- {{{ direction_toggle
-- Issue 10-062: the two orders, the one being read in bold, the other a link to
-- page 1 of that view (oldest first, or newest first).
local function direction_toggle(direction)
    local forward, reverse = "oldest first", "newest first"
    if direction == "forward" then
        reverse = string.format('<a href="%s">%s</a>', gallery_pages.page_file(1, "reverse"), reverse)
        forward = "<b>" .. forward .. "</b>"
    else
        forward = string.format('<a href="%s">%s</a>', gallery_pages.page_file(1, "forward"), forward)
        reverse = "<b>" .. reverse .. "</b>"
    end
    return '<p>' .. forward .. ' &#9474; ' .. reverse .. '</p>'
end
-- }}}

-- {{{ generate_gallery_chronological_page
-- Issue 10-042d: all standalone images, every source, in time order, as a
-- vertical scroll. Between each pair of images is a caption block naming the
-- image ABOVE and the image BELOW, so every title shows twice (once on each
-- side of its picture). Each image is anchored for deep-linking from poems.
--
-- Issue 10-062: one PAGE of that scroll, in one direction. `view` is the whole
-- ordered list for the direction (oldest first, or the same list reversed);
-- this page draws view[first..last]. A caption names the image below only
-- when it is on this page: the last picture of a page closes like the last
-- picture of the gallery, and the jump bar under it leads on.
local function generate_gallery_chronological_page(view, page, index, direction)
    local SEP = string.rep("─", 78)
    local function esc(s) return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
    local first = (page - 1) * index.page_size + 1
    local last = math.min(page * index.page_size, #view)
    local heading = direction == "forward" and "Images &mdash; Chronological" or "Images &mdash; Newest First"
    local title = (direction == "forward" and "Images — Chronological" or "Images — Newest First")
        .. string.format(" (page %d of %d)", page, index.pages)

    local html = {}
    table.insert(html, generate_html_header(title))
    table.insert(html, '<center>')
    table.insert(html, '<h1>' .. heading .. '</h1>')
    table.insert(html, '<p><a href="index.html">Gallery Index</a> &#9474; <a href="../wordcloud.html">Menu</a></p>')  -- the site's menu, as on the other gallery pages
    table.insert(html, direction_toggle(direction))
    table.insert(html, jump_bar(page, index.pages, direction))
    table.insert(html, '<hr>')
    if #view == 0 then
        table.insert(html, '<p>0 images from all collections</p>')
    else
        table.insert(html, string.format('<p>%d images from all collections, %s; this page: %d to %d</p>',
            #view, direction == "forward" and "in time order" or "newest first", first, last))
    end
    table.insert(html, '</center>')

    for i = first, last do
        local img = view[i]
        local rel = get_relative_image_path(img.relative_path)
        local img_title = image_qualified_title(img)
        -- The anchor is the picture's own (hash-based), the same in both views.
        local forward_position = direction == "forward" and i or (#view - i + 1)
        table.insert(html, string.format(
            '<a name="%s"></a><img src="%s" alt="%s" loading="lazy" style="max-width:min(100%%,800px); height:auto; display:block; margin:1em auto;">',
            gallery_pages.anchor(img, forward_position), rel, esc(img_title)))
        -- Caption block: sep, blank, title-of-image-above (this), blank,
        -- title-of-image-below (next, when on this page), blank, sep.
        local block = { SEP, "", esc(img_title), "" }
        if i < last then
            table.insert(block, esc(image_qualified_title(view[i + 1])))
        end
        table.insert(block, "")
        table.insert(block, SEP)
        table.insert(html, '<pre style="text-align:center">' .. table.concat(block, "\n") .. '</pre>')
    end

    table.insert(html, '<center>')
    table.insert(html, jump_bar(page, index.pages, direction))
    table.insert(html, '</center>')
    table.insert(html, generate_html_footer())
    return table.concat(html, "\n")
end
-- }}}

-- {{{ M.chronological_pages
-- Issue 10-062: every page of the chronological gallery, both directions, as
-- { {file = name, html = text}, ... }, plus the index they were laid out from.
-- The reverse view is the same sorted list read backwards -- no second pass
-- over the catalog. page_count is config.pagination.gallery_chronological_pages.
function M.chronological_pages(catalog, page_count)
    local index = gallery_pages.build_index(catalog, page_count)
    local reversed = {}
    for i = index.total, 1, -1 do reversed[#reversed + 1] = index.sorted[i] end
    local pages = {}
    for _, view in ipairs({ { "forward", index.sorted }, { "reverse", reversed } }) do
        for page = 1, index.pages do
            pages[#pages + 1] = {
                file = gallery_pages.page_file(page, view[1]),
                html = generate_gallery_chronological_page(view[2], page, index, view[1]),
            }
        end
    end
    return pages, index
end
-- }}}

-- {{{ M.write_chronological_pages
-- Write every chronological page into output_dir, plus chronological.html as a
-- copy of the first forward page: the gallery used to be that one file, so
-- bookmarks and links already out in the world still open the gallery (at its
-- start; a #picture fragment for a later page lands on page 1's top). Numbered
-- pages left over from a build with more pages are removed, so a smaller page
-- count never leaves stale pages behind. Returns the written file names.
function M.write_chronological_pages(output_dir, catalog, page_count)
    local pages, index = M.chronological_pages(catalog, page_count)
    local written = {}
    local function write(name, text)
        local handle = io.open(output_dir .. "/" .. name, "w")
        if not handle then error("gallery: could not write " .. output_dir .. "/" .. name) end
        handle:write(text)
        handle:close()
        written[#written + 1] = name
    end
    for _, page in ipairs(pages) do write(page.file, page.html) end
    write("chronological.html", pages[1].html)
    for page = index.pages + 1, 99 do
        os.remove(output_dir .. "/" .. gallery_pages.page_file(page, "forward"))
        os.remove(output_dir .. "/" .. gallery_pages.page_file(page, "reverse"))
    end
    return written, index
end
-- }}}

-- {{{ M.generate
-- output_dir: where the pages go (default the site's gallery/; another
-- folder for a trial)
function M.generate(output_dir)
    require("output").print("Loading image catalog...")
    local catalog = load_image_catalog()
    if not catalog then
        return false
    end

    require("output").print("Filtering standalone images...")
    local standalone = filter_standalone_images(catalog)
    require("output").print("Found " .. #standalone .. " standalone images")

    require("output").print("Grouping by source...")
    local grouped = group_by_source(standalone)

    -- Create output directory
    output_dir = output_dir or (DIR .. "/output/gallery")
    os.execute("mkdir -p " .. output_dir)

    -- Generate index page
    require("output").print("Generating gallery index...")
    local index_html = generate_gallery_index(grouped)
    local index_file = io.open(output_dir .. "/index.html", "w")
    if index_file then
        index_file:write(index_html)
        index_file:close()
        require("output").print("  Created: output/gallery/index.html")
    end

    -- Issue 10-042d: chronological images pages (all sources, by time).
    -- Issue 10-062: split into pages, oldest first and newest first.
    require("output").print("Generating chronological images pages...")
    local page_count = config.pagination and config.pagination.gallery_chronological_pages
    local written, index = M.write_chronological_pages(output_dir, catalog, page_count)
    require("output").print(string.format("  Created: %d chronological pages (%d per direction, %d images each) "
        .. "and output/gallery/chronological.html", #written - 1, index.pages, index.page_size))

    -- Generate per-source gallery pages
    for _, source_name in ipairs(STANDALONE_SOURCES) do
        local images = grouped[source_name]
        if images and #images > 0 then
            require("output").print("Generating gallery for " .. source_name .. " (" .. #images .. " images)...")
            local page_html, filename = generate_source_gallery(source_name, images)
            local page_file = io.open(output_dir .. "/" .. filename, "w")
            if page_file then
                page_file:write(page_html)
                page_file:close()
                require("output").print("  Created: output/gallery/" .. filename)
            end
        else
            require("output").print("Skipping " .. source_name .. " (no images)")
        end
    end

    require("output").print("Gallery generation complete!")
    return true
end
-- }}}

-- Run if executed directly
if arg and arg[0]:match("generate%-gallery%-pages%.lua$") then
    -- start, end and any stopping error go to the run's log (Issue 10-075)
    require("output").guard("generate-gallery-pages.lua", M.generate)
end

return M
