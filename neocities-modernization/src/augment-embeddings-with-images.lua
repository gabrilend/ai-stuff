#!/usr/bin/env luajit
-- augment-embeddings-with-images.lua
--
-- Issue 9-013 (redesign) pipeline hook. Runs AFTER poem embeddings exist
-- (Stage 6) and BEFORE the GPU similarity stage (Stage 7). It gives every
-- TEXT-LESS image a "pseudo-embedding" (the normalized average of the poem
-- before and after it in time) so images rank on similar/different pages like
-- poems. See src/image-pseudo-embeddings.lua for the pure math.
--
-- Three image classes (decided from the data, see issue 9-013):
--   1. text + image post  -> keep the post's real text embedding (left alone)
--   2. image-only post     -> REPLACE its useless 🖼 embedding with a pseudo
--   3. standalone catalog image (my-art, ...) -> APPEND a new pseudo entry
--
-- Outputs (idempotent — safe to re-run):
--   embeddings.json        : augmented in place (class-2 replaced, class-3
--                            appended with is_image=true). The similarity stage
--                            reads this unchanged.
--   image-manifest.json     : poem_index -> render data for every image entry,
--                            so the HTML renderer can draw an image box instead
--                            of looking the index up in poems.json (where the
--                            class-3 pseudo-poems do not exist).
--
-- Run from any directory: luajit src/augment-embeddings-with-images.lua [DIR]

-- {{{ Setup directory + module path
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path

local dkjson = require("dkjson")
local pseudo = require("image-pseudo-embeddings")
local utils = require("utils")  -- Issue 10-054: central cache-location functions
-- }}}

local M = {}

-- {{{ local function read_json()
local function read_json(path)
    local f = io.open(path, "r")
    if not f then return nil, "cannot open " .. path end
    local s = f:read("*a"); f:close()
    return dkjson.decode(s)
end
-- }}}

-- {{{ local function write_json()
local function write_json(path, data)
    local f = assert(io.open(path, "w"))
    f:write(dkjson.encode(data, { indent = false }))
    f:close()
end
-- }}}

-- {{{ function M.parse_iso8601()
-- Minimal ISO-8601 -> Unix epoch, matching poem-extractor's parser. Used to put
-- text poems and image-only posts on the same numeric timeline as catalog
-- images (which already carry a unix modification_time).
function M.parse_iso8601(ts)
    if not ts or ts == "" then return 0 end
    local y, mo, d, h, mi, s = ts:match("(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)")
    if y then
        return os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s })
    end
    y, mo, d = ts:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if y then
        return os.time({ year = y, month = mo, day = d, hour = 12, min = 0, sec = 0 })
    end
    return 0
end
-- }}}

-- {{{ function M.is_image_only()
-- Class 2 detector. Strips whitespace and the image-placeholder emojis the
-- collection uses, then treats <10 remaining characters as "no usable text".
-- Mirrors poem-extractor's is_image_only_post so classification is consistent.
function M.is_image_only(content)
    local stripped = (content or ""):gsub("%s+", ""):gsub("[🖼📷📸🎨🌅🌄🌃🌉🏞️]", "")
    return #stripped < 10
end
-- }}}

-- {{{ function M.rel_below_source()
-- The image path below its source directory, for the "source: sub: name.png"
-- title. Catalog `relative_path` is actually absolute, so strip the
-- `source_directory` prefix.
function M.rel_below_source(img)
    local full = img.relative_path or img.file_path or ""
    local base = img.source_directory or ""
    if base ~= "" and full:sub(1, #base) == base then
        return (full:sub(#base + 1):gsub("^/+", ""))
    end
    return img.filename or full
end
-- }}}

-- {{{ function M.augment()
-- Pure-ish core: operates on already-loaded tables, returns the augmented
-- embeddings list and the image manifest. No file I/O (so it is testable).
--   embeddings_data : { embeddings = [ {embedding, poem_index, id, ...}, ... ] }
--   poems_data      : { poems = [ {poem_index, id, category, content,
--                                  creation_date, attachments}, ... ] }
--   catalog_data    : { images = [ {source_name, modification_time, ...}, ... ] }
function M.augment(embeddings_data, poems_data, catalog_data)
    local report = { class1 = 0, class2 = 0, class3 = 0, skipped = 0 }

    -- Poem metadata by poem_index (content, date, attachments).
    local poem_by_index = {}
    for _, p in ipairs(poems_data.poems or {}) do
        poem_by_index[p.poem_index] = p
    end

    -- Drop any previously-appended image entries so re-runs are idempotent;
    -- keep only the genuine poem entries (poem_index present in poems.json).
    local poem_entries, max_index = {}, 0
    for _, e in ipairs(embeddings_data.embeddings or {}) do
        if not e.is_image and poem_by_index[e.poem_index] then
            poem_entries[#poem_entries + 1] = e
            if e.poem_index > max_index then max_index = e.poem_index end
        end
    end

    -- Classify poems and build the chronological SPINE (text poems only:
    -- ordinary poems + class-1 text+image posts; class-2 image-only posts are
    -- excluded so an image never averages over another image).
    local spine, class2_entries = {}, {}
    for _, e in ipairs(poem_entries) do
        local p = poem_by_index[e.poem_index]
        local has_att = p.attachments and #p.attachments > 0
        if has_att and M.is_image_only(p.content) then
            class2_entries[#class2_entries + 1] = { entry = e, poem = p }
            report.class2 = report.class2 + 1
        else
            if has_att then report.class1 = report.class1 + 1 end
            spine[#spine + 1] = {
                poem_index = e.poem_index,
                timestamp = M.parse_iso8601(p.creation_date),
                embedding = e.embedding,
            }
        end
    end

    local manifest = {}  -- poem_index -> render record

    -- Class 2: replace each image-only post's embedding with its pseudo, in
    -- place (its entry keeps its poem_index, so it stays ranked).
    do
        local imgs = {}
        for _, c in ipairs(class2_entries) do
            imgs[#imgs + 1] = {
                id = c.entry.poem_index,
                source_name = c.poem.category or "fediverse",
                rel_below_source = nil,
                timestamp = M.parse_iso8601(c.poem.creation_date),
                _entry = c.entry, _poem = c.poem,
            }
        end
        local results, skipped = pseudo.compute_image_pseudo_embeddings(spine, imgs)
        report.skipped = report.skipped + #skipped
        for _, r in ipairs(results) do
            r.image._entry.embedding = r.embedding  -- replace in place
            manifest[tostring(r.image._entry.poem_index)] = {
                is_image = true, class = 2,
                poem_index = r.image._entry.poem_index,
                category = r.image._poem.category,
                source_id = r.image._poem.id,
                attachments = r.image._poem.attachments,
                creation_date = r.image._poem.creation_date,
            }
        end
    end

    -- Class 3: standalone catalog images become NEW appended entries. Skip
    -- fediverse-media (those are poem attachments, already handled as class 1/2).
    local appended = {}
    do
        local imgs = {}
        for _, im in ipairs(catalog_data.images or {}) do
            if im.source_name ~= "fediverse-media" then
                imgs[#imgs + 1] = {
                    id = im.hash,
                    source_name = im.source_name,
                    rel_below_source = M.rel_below_source(im),
                    timestamp = tonumber(im.modification_time) or M.parse_iso8601(im.modification_date),
                    _img = im,
                }
            end
        end
        local results, skipped = pseudo.compute_image_pseudo_embeddings(spine, imgs)
        report.skipped = report.skipped + #skipped
        for _, r in ipairs(results) do
            max_index = max_index + 1
            local new_entry = {
                embedding = r.embedding,
                poem_index = max_index,
                id = "img-" .. tostring(r.image.id),
                is_image = true,
                content_length = 0,
            }
            appended[#appended + 1] = new_entry
            report.class3 = report.class3 + 1
            manifest[tostring(max_index)] = {
                is_image = true, class = 3,
                poem_index = max_index,
                source_name = r.image.source_name,
                display_title = r.display_title,
                relative_path = r.image._img.relative_path,
                source_directory = r.image._img.source_directory,
                width = r.image._img.width, height = r.image._img.height,
                creation_date = r.image._img.modification_date,
                -- Deep-link target on the chronological gallery page. MUST match
                -- generate-gallery-pages.lua's image_anchor() = "img-" .. hash:sub(1,12).
                gallery_anchor = "img-" .. tostring(r.image.id):sub(1, 12),
            }
        end
    end

    -- Final augmented list: poems (with class-2 replaced) + appended class-3.
    local out = {}
    for _, e in ipairs(poem_entries) do out[#out + 1] = e end
    for _, e in ipairs(appended) do out[#out + 1] = e end
    return out, manifest, report
end
-- }}}

-- {{{ local function main()
local function main()
    -- Resolve the model through the shared resolver instead of a hardcoded
    -- default: it reads this run's overrides notepad (tmp/run-overrides.lua,
    -- written by run.sh from --model) and falls back to config.lua -- so the CLI
    -- override is honored and there is no source-code default to drift out of
    -- sync with config. Works standalone too (no notepad => config default).
    local inference_config = require("inference-server-config")
    inference_config.set_project_root(DIR)
    local model = inference_config.get_selected_model()
    local edir = utils.embeddings_dir(model)  -- Issue 10-054: movable (embeddings.json, manifest)
    local emb_path = edir .. "/embeddings.json"
    local manifest_path = edir .. "/image-manifest.json"

    local embeddings_data = assert(read_json(emb_path), "missing embeddings.json — run Stage 6 first")
    local poems_data = assert(read_json(DIR .. "/assets/poems.json"), "missing poems.json")
    local catalog_data = read_json(DIR .. "/assets/image-catalog.json")
    if not catalog_data then
        print("[augment] No image-catalog.json; only image-only posts will be pseudo-embedded.")
        catalog_data = { images = {} }
    end

    local out, manifest, report = M.augment(embeddings_data, poems_data, catalog_data)
    embeddings_data.embeddings = out
    embeddings_data.metadata = embeddings_data.metadata or {}
    embeddings_data.metadata.image_pseudo_embeddings = report

    write_json(emb_path, embeddings_data)
    write_json(manifest_path, { metadata = report, images = manifest })

    print(string.format(
        "[augment] class1(text+img) kept=%d  class2(image-only) replaced=%d  class3(standalone) appended=%d  skipped=%d",
        report.class1, report.class2, report.class3, report.skipped))
    print(string.format("[augment] embeddings: %d entries -> %s", #out, emb_path))
    print(string.format("[augment] manifest: %s", manifest_path))
end
-- }}}

-- Run main() only when invoked as a script (not when required by the test).
if not _G.AUGMENT_NO_MAIN then
    main()
end

return M
