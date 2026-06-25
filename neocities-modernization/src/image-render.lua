-- image-render.lua
--
-- Issue 9-013 (redesign) — renderer side. The augmentation step
-- (augment-embeddings-with-images.lua) ranks images alongside poems and writes
-- image-manifest.json. This module lets flat-html-generator DRAW those image
-- entries: it injects lightweight "pseudo-poem" objects into the poems list so
-- the existing poem_index lookups find them, and formats an image as a small
-- box instead of a poem.
--
-- Kept separate (and dependency-light) so it can be required from both the main
-- thread and each effil worker's fresh Lua state, and unit-tested on its own.

local M = {}

local manifest_cache = nil  -- per-process memoize (worker states each load once)

-- {{{ function M.load_manifest()
-- Read image-manifest.json from `path`. Returns the { "poem_index" = record }
-- map, or an empty table if the file is absent (the feature is optional: no
-- manifest -> no image entries, poems render exactly as before). Memoized per
-- process so each worker state parses it at most once.
function M.load_manifest(path, read_json_fn)
    if manifest_cache ~= nil then return manifest_cache end
    local data = read_json_fn(path)
    manifest_cache = (data and data.images) or {}
    return manifest_cache
end
-- }}}

-- {{{ local function basename()
local function basename(path)
    return (path or ""):match("([^/]+)$") or (path or "")
end
-- }}}

-- {{{ local function media_href()
-- Where a file lives under output/media/, url-encoded for an href/src.
-- Art images (path under input/images/<source>/...) KEEP their source + subdir
-- structure, because their human-given basenames collide (e.g.
-- my-art/proposed-movement-design.png vs my-art/game-design/proposed-movement-design.png)
-- and a flat output/media/<basename> would let one silently overwrite the other.
-- flatten_media_files writes art to the very same <source>/<subpath>, so the two
-- agree. Mastodon attachments (content-addressed hashes, NOT under input/images/)
-- keep just the basename -- already unique, and we don't want their 7-level
-- nesting back. Slashes are preserved; space / ? / # / % are percent-encoded.
-- Inlined (not required from a lib) on purpose: this module also runs inside
-- effil worker threads with their own Lua state.
local function media_href(path)
    path = path or ""
    local sub = path:match("input/images/(.+)$") or (path:match("([^/]+)$") or path)
    return (sub:gsub("[^%w%-%._~/]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end
-- }}}

-- {{{ local function media_type_for()
-- Guess a media_type from a filename extension (the manifest stores width/height
-- but render_attachment_images keys image rendering off "image/...").
local function media_type_for(filename)
    local ext = (filename or ""):match("%.([%a%d]+)$")
    return "image/" .. (ext and ext:lower() or "png")
end
-- }}}

-- {{{ function M.inject_pseudo_poems()
-- Append one pseudo-poem per manifest image to poems_data.poems so the
-- renderer's poem_index lookups resolve them. Idempotent: a second call is a
-- no-op (guarded by a marker on poems_data), so it is safe to call after every
-- poems.json load. Class 2 (image-only posts) ALREADY exist in poems_data with
-- their real poem_index -- we only TAG those in place; class 3 (standalone
-- catalog images, poem_index beyond the poem range) are genuinely new and get
-- appended.
function M.inject_pseudo_poems(poems_data, manifest)
    if not poems_data or not poems_data.poems then return poems_data end
    if poems_data._images_injected then return poems_data end
    poems_data._images_injected = true
    if not manifest then return poems_data end

    -- Index existing poems so class-2 entries can be tagged in place.
    local by_index = {}
    for _, p in ipairs(poems_data.poems) do by_index[p.poem_index] = p end

    for key, rec in pairs(manifest) do
        local pidx = rec.poem_index or tonumber(key)
        if rec.class == 2 then
            -- Tag the existing image-only post so the formatter draws it as an
            -- image. Its attachments + content already live in poems_data.
            local p = by_index[pidx]
            if p then
                p.is_image = true
                p.image_class = 2
                p.display_title = rec.category and (rec.category .. ": image post") or "image post"
            end
        else
            -- Class 3: build a fresh pseudo-poem carrying the catalog image as a
            -- normal attachment. The attachment keeps the FULL relative_path (not
            -- just the basename) so render_attachment_images can namespace it the
            -- same way flatten_media_files did -- output/media/<source>/<subpath>.
            -- Passing only the basename used to work when media was flat, but that
            -- is exactly what let same-named art images collide; the full path
            -- carries the source + subdirs that keep them distinct. fname stays
            -- the basename purely for the human-facing title/type.
            local fname = basename(rec.relative_path)
            poems_data.poems[#poems_data.poems + 1] = {
                poem_index = pidx,
                id = "img-" .. tostring(pidx),
                is_image = true,
                image_class = 3,
                category = "image",
                content = "",
                creation_date = rec.creation_date,
                display_title = rec.display_title or fname,
                gallery_anchor = rec.gallery_anchor,  -- deep-link to the chrono gallery
                attachments = {{
                    relative_path = rec.relative_path,
                    media_type = media_type_for(fname),
                    width = rec.width, height = rec.height,
                    description = rec.display_title or fname,
                }},
            }
        end
    end
    return poems_data
end
-- }}}

-- Document-relative bases: "up to the site root, then down to the target." These
-- image entries are only ever rendered into poem pages, which live one directory
-- below the root (output/similar/, output/different/, output/chronological/), so
-- the prefix is "../". Relative paths resolve identically whether opened locally
-- from any folder or served on the site -- no per-environment conversion. (If an
-- image entry were ever rendered at another depth, this prefix would move with
-- the page; today every caller is depth 1.) flatten_media_files puts each image
-- at output/media/<source>/<subpath>, which "../media/" + media_href() reaches.
local MEDIA_BASE = "../media/"
local GALLERY_BASE = "../gallery/chronological.html#"

-- {{{ function M.text_image_link()
-- For a TEXT+IMAGE post (a normal poem that also carries an image attachment),
-- a direct link to the image file, always labelled "image.png" regardless of
-- the real filename. These pictures have no gallery entry/name of their own, so
-- this gives the reader a way to open the image. Returns "" when there is no
-- image attachment (pure-text poems get nothing).
function M.text_image_link(poem)
    local att = poem.attachments and poem.attachments[1]
    if not att then return "" end
    local raw = att.relative_path or att.url or ""
    if raw == "" then return "" end
    -- media_href keeps art's source+subdir structure (collision-safe) and
    -- url-encodes; Mastodon hashes collapse to the bare name. Matches the <img>
    -- src in format_image_entry and where flatten_media_files placed the file.
    return string.format('<a href="%s%s">image.png</a>', MEDIA_BASE, media_href(raw))
end
-- }}}

-- {{{ function M.format_image_entry()
-- Render a ranked IMAGE as a compact, CSS-free box: a marker + the
-- source-qualified title, the image(s), then a closing rule. Self-contained
-- (builds its own <img> from the attachment) so it renders identically in the
-- main thread and in each effil worker without needing their private helpers.
function M.format_image_entry(poem)
    local title = poem.display_title or "image"
    local esc = title:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    local imgs = {}
    for _, att in ipairs(poem.attachments or {}) do
        -- media_href namespaces art by source+subdir (so same-named pieces don't
        -- collide in output/media/) and url-encodes; Mastodon hashes stay flat.
        local src = MEDIA_BASE .. media_href(att.relative_path or att.url or "")
        if att.width and att.height then
            imgs[#imgs + 1] = string.format(
                '  <img src="%s" alt="%s" loading="lazy" width="%d" height="%d" style="display:block; max-width:min(100%%,800px); height:auto">',
                src, esc, att.width, att.height)
        else
            imgs[#imgs + 1] = string.format(
                '  <img src="%s" alt="%s" loading="lazy" style="display:block; max-width:min(100%%,800px); height:auto">',
                src, esc)
        end
    end
    -- For a standalone catalog image, link the title to its spot on the
    -- chronological gallery page (Issue 9-013 gallery links). Image-only posts
    -- carry no gallery_anchor, so their title stays plain text.
    local title_html = esc
    if poem.gallery_anchor then
        title_html = string.format('<a href="%s%s">%s</a>', GALLERY_BASE, poem.gallery_anchor, esc)
    end
    return table.concat({
        "<hr>",
        string.format('<font color="#868E96"><b>&#x1F5BC; %s</b></font>', title_html),
        table.concat(imgs, "\n"),
        "<hr>",
        "",
    }, "\n")
end
-- }}}

-- {{{ function M.reset_cache()
-- Test hook: drop the memoized manifest so fixtures don't bleed between cases.
function M.reset_cache()
    manifest_cache = nil
end
-- }}}

return M
