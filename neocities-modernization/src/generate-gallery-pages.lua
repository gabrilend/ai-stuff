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
    ["dnd-pictures-from-the-internet"] = "D&amp;D Pictures",
    ["fediverse-stars"] = "Fediverse Stars"
}

-- Grid layout
local COLUMNS = 4
local THUMBNAIL_WIDTH = 200
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

-- {{{ get_relative_image_path
-- Convert absolute path to relative path from output/gallery/
local function get_relative_image_path(absolute_path)
    -- Strip the DIR prefix
    if absolute_path:sub(1, #DIR) == DIR then
        local rel = absolute_path:sub(#DIR + 2)  -- +2 for the slash
        -- From output/gallery/, we need to go up two levels
        return "../../" .. rel
    end
    return absolute_path
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
-- Generate HTML table grid for images
local function generate_gallery_grid(images)
    local html = {}
    table.insert(html, '<table border="0" cellpadding="10" cellspacing="5">\n')

    local row_images = {}
    for i, img in ipairs(images) do
        table.insert(row_images, img)

        if #row_images == COLUMNS or i == #images then
            -- Start row
            table.insert(html, '<tr>\n')

            for _, row_img in ipairs(row_images) do
                local rel_path = get_relative_image_path(row_img.file_path)
                local alt_text = extract_display_name(row_img.filename)

                table.insert(html, string.format(
                    '  <td align="center" valign="top">' ..
                    '<a href="%s">' ..
                    '<img src="%s" width="%d" alt="%s" title="%s" loading="lazy" border="1">' ..
                    '</a><br><font size="1">%s</font></td>\n',
                    rel_path, rel_path, THUMBNAIL_WIDTH, alt_text, alt_text,
                    row_img.filename:sub(1, 20) .. (row_img.filename:len() > 20 and "..." or "")
                ))
            end

            -- Pad remaining cells if needed
            for _ = 1, COLUMNS - #row_images do
                table.insert(html, '  <td></td>\n')
            end

            table.insert(html, '</tr>\n')
            row_images = {}
        end
    end

    table.insert(html, '</table>\n')
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
    table.insert(html, '<a href="../chronological/index.html">Chronological</a>')
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
