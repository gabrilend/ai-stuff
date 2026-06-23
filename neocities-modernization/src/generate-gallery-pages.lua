#!/usr/bin/env luajit

-- {{{ generate-gallery-pages.lua
-- Issue 10-042a: Generate HTML gallery pages for standalone images
-- Creates gallery index and per-source gallery pages from image-catalog.json
--
-- Usage:
--   luajit src/generate-gallery-pages.lua [DIR]
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

-- {{{ setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- {{{ parse_args
local function parse_args(args)
    local dir = nil
    local i = 1
    while i <= #(args or {}) do
        local a = args[i]
        if not a:match("^%-") then
            dir = a
            i = i + 1
        else
            i = i + 1
        end
    end
    return dir
end
-- }}}

local provided_dir = parse_args(arg)
local DIR = setup_dir_path(provided_dir)
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path

local dkjson = require("dkjson")
local utils = require("utils")
-- Issue 10-042d / 9-013: shared "source: sub: name.png" title helper
local image_titles = require("image-pseudo-embeddings")
utils.init_assets_root(arg)

-- Issue 10-003: Load unified config from config.lua
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local config = config_loader.load()

local M = {}

-- {{{ Configuration
-- Sources to include in gallery (exclude fediverse-media which is inline with poems)
local STANDALONE_SOURCES = {
    "my-art",
    "things-I-almost-posted",
    "poem-pictures",
    "dnd-pictures-from-the-internet",
    "fediverse-stars"
}

-- Map source names to URL-friendly slugs
local SOURCE_SLUGS = {
    ["my-art"] = "my-art",
    ["things-I-almost-posted"] = "things-i-almost-posted",
    ["poem-pictures"] = "poem-pictures",
    ["dnd-pictures-from-the-internet"] = "dnd-pictures",
    ["fediverse-stars"] = "fediverse-stars"
}

-- Map source names to display titles
local SOURCE_TITLES = {
    ["my-art"] = "My Art",
    ["things-I-almost-posted"] = "Things I Almost Posted",
    ["poem-pictures"] = "Poem Pictures",
    -- Keep the full source name so it is clear these were found, not authored
    ["dnd-pictures-from-the-internet"] = "dnd-pictures-from-the-internet",
    ["fediverse-stars"] = "Fediverse Stars"
}

-- Grid layout
local COLUMNS = 4
local THUMBNAIL_WIDTH = 200
local MASONRY_GAP = 16   -- px between COLUMNS (horizontal)
local MASONRY_VGAP = 8   -- px between stacked images WITHIN a column (vertical) -- tight pack
-- }}}

-- {{{ load_image_catalog
local function load_image_catalog()
    local catalog_path = DIR .. "/assets/image-catalog.json"
    local file = io.open(catalog_path, "r")
    if not file then
        print("Error: Could not open " .. catalog_path)
        return nil
    end

    local content = file:read("*a")
    file:close()

    local data, pos, err = dkjson.decode(content)
    if err then
        print("Error parsing image catalog: " .. tostring(err))
        return nil
    end

    return data
end
-- }}}

-- {{{ filter_standalone_images
-- Filter to only standalone images (exclude fediverse-media)
local function filter_standalone_images(catalog)
    local standalone = {}
    local standalone_set = {}
    for _, source in ipairs(STANDALONE_SOURCES) do
        standalone_set[source] = true
    end

    for _, img in ipairs(catalog.images or {}) do
        if standalone_set[img.source_name] then
            table.insert(standalone, img)
        end
    end

    return standalone
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
    -- Strip the DIR prefix
    if absolute_path:sub(1, #DIR) == DIR then
        local rel = absolute_path:sub(#DIR + 2)  -- +2 for the slash
        -- From output/gallery/, we need to go up two levels. Encode so odd
        -- filenames (spaces, ?) survive as a usable URL, not a truncated one.
        return url_encode_path("../../" .. rel)
    end
    return url_encode_path(absolute_path)
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
    local theme = config.html_theme or {}
    local bg = theme.background or "#000000"
    local text = theme.text or "#FFFFFF"
    local link = theme.link or "#6699FF"
    local vlink = theme.vlink or "#9966FF"

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
    local slug = SOURCE_SLUGS[source_name] or source_name:lower():gsub("%s+", "-")
    local title = SOURCE_TITLES[source_name] or source_name

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
    table.insert(html, '<a href="chronological.html">Chronological</a>')
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
            local slug = SOURCE_SLUGS[source_name] or source_name:lower():gsub("%s+", "-")
            local title = SOURCE_TITLES[source_name] or source_name

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

-- {{{ image_anchor
-- Stable per-image anchor so poem pages can deep-link to one image here.
local function image_anchor(img, fallback_index)
    return "img-" .. (img.hash and img.hash:sub(1, 12) or tostring(fallback_index))
end
-- }}}

-- {{{ generate_gallery_chronological
-- Issue 10-042d: all standalone images, every source, in time order, as a
-- vertical scroll. Between each pair of images is a caption block naming the
-- image ABOVE and the image BELOW, so every title shows twice (once on each
-- side of its picture). Each image is anchored for deep-linking from poems.
local function generate_gallery_chronological(images)
    table.sort(images, function(a, b)
        return (tonumber(a.modification_time) or 0) < (tonumber(b.modification_time) or 0)
    end)

    local SEP = string.rep("─", 78)
    local function esc(s) return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end

    local html = {}
    table.insert(html, generate_html_header("Images — Chronological"))
    table.insert(html, '<center>')
    table.insert(html, '<h1>Images &mdash; Chronological</h1>')
    table.insert(html, '<p><a href="index.html">Gallery Index</a> &#9474; <a href="../index.html">Menu</a></p>')
    table.insert(html, '<hr>')
    table.insert(html, '<p>' .. #images .. ' images from all collections, in time order</p>')
    table.insert(html, '</center>')

    for i, img in ipairs(images) do
        local rel = get_relative_image_path(img.relative_path)
        local title = image_qualified_title(img)
        table.insert(html, string.format(
            '<a name="%s"></a><img src="%s" alt="%s" loading="lazy" style="max-width:min(100%%,800px); height:auto; display:block; margin:1em auto;">',
            image_anchor(img, i), rel, esc(title)))
        -- Caption block: sep, blank, title-of-image-above (this), blank,
        -- title-of-image-below (next), blank, sep. The last image has no below.
        local block = { SEP, "", esc(title), "" }
        if images[i + 1] then
            table.insert(block, esc(image_qualified_title(images[i + 1])))
        end
        table.insert(block, "")
        table.insert(block, SEP)
        table.insert(html, '<pre style="text-align:center">' .. table.concat(block, "\n") .. '</pre>')
    end

    table.insert(html, generate_html_footer())
    return table.concat(html, "\n")
end
-- }}}

-- {{{ M.generate
function M.generate()
    print("Loading image catalog...")
    local catalog = load_image_catalog()
    if not catalog then
        return false
    end

    print("Filtering standalone images...")
    local standalone = filter_standalone_images(catalog)
    print("Found " .. #standalone .. " standalone images")

    print("Grouping by source...")
    local grouped = group_by_source(standalone)

    -- Create output directory
    local output_dir = DIR .. "/output/gallery"
    os.execute("mkdir -p " .. output_dir)

    -- Generate index page
    print("Generating gallery index...")
    local index_html = generate_gallery_index(grouped)
    local index_file = io.open(output_dir .. "/index.html", "w")
    if index_file then
        index_file:write(index_html)
        index_file:close()
        print("  Created: output/gallery/index.html")
    end

    -- Issue 10-042d: chronological images page (all sources, by time)
    print("Generating chronological images page...")
    local chrono_html = generate_gallery_chronological(standalone)
    local chrono_file = io.open(output_dir .. "/chronological.html", "w")
    if chrono_file then
        chrono_file:write(chrono_html)
        chrono_file:close()
        print("  Created: output/gallery/chronological.html")
    end

    -- Generate per-source gallery pages
    for _, source_name in ipairs(STANDALONE_SOURCES) do
        local images = grouped[source_name]
        if images and #images > 0 then
            print("Generating gallery for " .. source_name .. " (" .. #images .. " images)...")
            local page_html, filename = generate_source_gallery(source_name, images)
            local page_file = io.open(output_dir .. "/" .. filename, "w")
            if page_file then
                page_file:write(page_html)
                page_file:close()
                print("  Created: output/gallery/" .. filename)
            end
        else
            print("Skipping " .. source_name .. " (no images)")
        end
    end

    print("Gallery generation complete!")
    return true
end
-- }}}

-- Run if executed directly
if arg and arg[0]:match("generate%-gallery%-pages%.lua$") then
    M.generate()
end

return M
