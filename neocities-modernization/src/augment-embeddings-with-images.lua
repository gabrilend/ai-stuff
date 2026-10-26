#!/usr/bin/env luajit
-- augment-embeddings-with-images.lua
--
-- Issue 9-013 pipeline hook. Runs AFTER poem embeddings exist (Stage 6) and
-- BEFORE the GPU similarity stage (Stage 7). It places every picture among the
-- poems by what the picture shows: Stage 6's picture step
-- (src/picture-embeddings.lua) asked the vision model for each picture's
-- vector, and this step folds those vectors into the embedding set, so
-- pictures rank on similar/different pages like poems.
--
-- Three image classes (decided from the data, see issue 9-013):
--   1. text + image post  -> its text vector blended with its pictures'
--      (half and half, config.lua picture_embeddings.text_share); the pure
--      text vector is kept beside the blend (text_embedding) so a re-run, or
--      Stage 6 reusing the post's vector, never blends a blend
--   2. image-only post     -> REPLACE its useless 🖼 embedding with its
--      pictures' vector (the average, for several); a post whose media has
--      no picture (a video, a sound) keeps the neighbours-in-time cross-cut
--      (src/image-pseudo-embeddings.lua), the owner's choice for those few
--   3. standalone catalog image (my-art, ...) -> APPEND a new entry with its
--      picture's vector
-- A picture with no vector in the cache is an error: it says to run Stage 6.
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

-- --help: print the header above and exit, when run as a program (libs/script-help.lua)
dofile((debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./") .. "../libs/script-help.lua").handle_if_run(arg, debug.getinfo(1, "S").source:sub(2))

-- {{{ Setup directory + module path
local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path

local dkjson = require("dkjson")
local pseudo = require("image-pseudo-embeddings")
_G.PICTURE_EMBEDDINGS_NO_MAIN = true   -- its helpers, not its main
local picture_step = dofile(DIR .. "/src/picture-embeddings.lua")
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

-- {{{ local function normalised()
-- A vector scaled to length 1 (a new array). A zero vector is an error: no
-- real picture or poem gives one, so it means something upstream broke.
local function normalised(vec)
    local sum = 0
    for i = 1, #vec do sum = sum + vec[i] * vec[i] end
    if sum == 0 then error("augment: a zero vector cannot be placed") end
    local inv = 1 / math.sqrt(sum)
    local out = {}
    for i = 1, #vec do out[i] = vec[i] * inv end
    return out
end
-- }}}

-- {{{ local function blend()
-- The normalised weighted sum of normalised vectors: parts is an array of
-- { vector, weight }.
local function blend(parts)
    local out = {}
    for _, part in ipairs(parts) do
        local v = normalised(part[1])
        for i = 1, #v do out[i] = (out[i] or 0) + v[i] * part[2] end
    end
    return normalised(out)
end
-- }}}

-- {{{ local function pictures_vector()
-- One vector for a post's pictures: the average of each picture's vector.
-- Returns nil for a post with no picture among its attachments.
local function pictures_vector(poem, pictures_in)
    local parts = {}
    for _, attachment in ipairs(poem.attachments or {}) do
        if picture_step.is_picture(attachment) then
            parts[#parts + 1] = { pictures_in.vector_of(picture_step.post_picture_path(pictures_in.dir, attachment)), 1 }
        end
    end
    if #parts == 0 then return nil end
    return blend(parts)
end
-- }}}

-- {{{ function M.augment()
-- Pure-ish core: operates on already-loaded tables, returns the augmented
-- embeddings list and the image manifest. No file I/O (so it is testable).
--   embeddings_data : { embeddings = [ {embedding, poem_index, id, ...}, ... ] }
--   poems_data      : { poems = [ {poem_index, id, category, content,
--                                  creation_date, attachments}, ... ] }
--   catalog_data    : { images = [ {source_name, modification_time, ...}, ... ] }
--   pictures_in     : { vector_of = function(absolute path) -> vector (an
--                       error when the picture has none), dir = project folder
--                       (post attachments live under it), text_share = the
--                       text's part of a text + picture post (number, 0-1) }
function M.augment(embeddings_data, poems_data, catalog_data, pictures_in)
    local report = { class1 = 0, class2 = 0, class3 = 0, skipped = 0,
                     by_picture = 0, by_neighbours = 0, blended = 0 }

    -- Poem metadata by poem_index (content, date, attachments). max_index is
    -- the highest poem number in poems.json: the standalone pictures are
    -- numbered after it. It used to be the highest poem that HAD an
    -- embedding, so when poems arrived after the embeddings were made (16
    -- notes on 2026-10-07), pictures took the newest poems' numbers and drew
    -- in their place on every similar and different page.
    local poem_by_index, max_index = {}, 0
    for _, p in ipairs(poems_data.poems or {}) do
        poem_by_index[p.poem_index] = p
        if p.poem_index > max_index then max_index = p.poem_index end
    end

    -- Drop any previously-appended image entries so re-runs are idempotent;
    -- keep only the genuine poem entries (poem_index present in poems.json).
    local poem_entries = {}
    for _, e in ipairs(embeddings_data.embeddings or {}) do
        if not e.is_image and poem_by_index[e.poem_index] then
            poem_entries[#poem_entries + 1] = e
        end
    end

    local manifest = {}  -- poem_index -> render record
    -- {{{ local function record_class2()
    local function record_class2(entry, poem, placed_by)
        manifest[tostring(entry.poem_index)] = {
            is_image = true, class = 2,
            poem_index = entry.poem_index,
            category = poem.category,
            source_id = poem.id,
            attachments = poem.attachments,
            creation_date = poem.creation_date,
            placed_by = placed_by,
        }
    end
    -- }}}

    -- Classify poems and build the chronological SPINE (text poems only:
    -- ordinary poems + class-1 text+image posts, by their TEXT vectors;
    -- class-2 image-only posts are excluded so the neighbours-in-time
    -- placement never borrows from a picture).
    local spine, class2_entries = {}, {}
    for _, e in ipairs(poem_entries) do
        local p = poem_by_index[e.poem_index]
        local has_att = p.attachments and #p.attachments > 0
        if has_att and M.is_image_only(p.content) then
            report.class2 = report.class2 + 1
            local vector = pictures_vector(p, pictures_in)
            if vector then
                -- placed by its own pictures, in place (it keeps its number)
                e.embedding = vector
                record_class2(e, p, "picture")
                report.by_picture = report.by_picture + 1
            else
                -- its media has no picture (a video, a sound): placed by
                -- the poems either side of it in time, below
                class2_entries[#class2_entries + 1] = { entry = e, poem = p }
            end
        else
            -- the pure text vector: kept beside a blend from an earlier run
            -- (text_embedding), else the entry's own
            local text_vector = e.text_embedding or e.embedding
            if has_att then
                report.class1 = report.class1 + 1
                local vector = pictures_vector(p, pictures_in)
                if vector then
                    -- text + picture: blended, the text vector kept beside
                    e.text_embedding = text_vector
                    e.embedding = blend({ { text_vector, pictures_in.text_share },
                                          { vector, 1 - pictures_in.text_share } })
                    report.blended = report.blended + 1
                end
                -- text + video or sound only: its text alone, as any poem
            end
            spine[#spine + 1] = {
                poem_index = e.poem_index,
                timestamp = M.parse_iso8601(p.creation_date),
                embedding = text_vector,
            }
        end
    end

    -- Class 2 without a picture: replace the post's embedding with the
    -- neighbours-in-time cross-cut, in place (its entry keeps its
    -- poem_index, so it stays ranked).
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
            record_class2(r.image._entry, r.image._poem, "neighbours")
            report.by_neighbours = report.by_neighbours + 1
        end
    end

    -- Class 3: standalone catalog images become NEW appended entries, each
    -- with its own picture's vector. Skip fediverse-media (those are poem
    -- attachments, already handled as class 1/2). Catalog order, as before:
    -- the numbers they get follow it.
    local appended = {}
    for _, im in ipairs(catalog_data.images or {}) do
        if im.source_name ~= "fediverse-media" then
            max_index = max_index + 1
            appended[#appended + 1] = {
                embedding = normalised(pictures_in.vector_of(im.file_path)),
                poem_index = max_index,
                id = "img-" .. tostring(im.hash),
                is_image = true,
                content_length = 0,
            }
            report.class3 = report.class3 + 1
            report.by_picture = report.by_picture + 1
            manifest[tostring(max_index)] = {
                is_image = true, class = 3,
                poem_index = max_index,
                source_name = im.source_name,
                display_title = pseudo.qualified_image_title(im.source_name, M.rel_below_source(im)),
                relative_path = im.relative_path,
                source_directory = im.source_directory,
                width = im.width, height = im.height,
                creation_date = im.modification_date,
                -- Deep-link target on the chronological gallery page. MUST match
                -- generate-gallery-pages.lua's image_anchor() = "img-" .. hash:sub(1,12).
                gallery_anchor = "img-" .. tostring(im.hash):sub(1, 12),
                placed_by = "picture",
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

-- {{{ function M.pictures_from_cache()
-- The pictures_in for M.augment, from Stage 6's picture cache: each picture
-- is fingerprinted again (a picture edited since Stage 6 has a new
-- fingerprint, and is reported as having no vector rather than given its old
-- one).
function M.pictures_from_cache(dir, model, edir, poems_data, catalog_data)
    local settings = require("config-loader").load().picture_embeddings
        or error("config.lua has no picture_embeddings section")
    local long_side = settings.long_side or error("config.lua picture_embeddings.long_side is missing")
    local text_share = settings.text_share or error("config.lua picture_embeddings.text_share is missing")
    local cache_path = edir .. "/picture_embeddings.json"
    local cache = read_json(cache_path)
    if not cache or not cache.pictures then
        error(string.format("augment: no picture vectors for %s (%s); run Stage 6 "
            .. "(--generate-embeddings), which embeds the pictures", model, cache_path))
    end
    local paths = picture_step.pictures_to_place(dir, poems_data, catalog_data)
    local hashes = picture_step.fingerprints(paths, dir .. "/tmp/shared-memory/picture-embeddings")
    return {
        dir = dir,
        text_share = text_share,
        vector_of = function(path)
            local hash = hashes[path] or error("augment: " .. path .. " is not among the pictures to place")
            local entry = cache.pictures[picture_step.cache_key(hash, long_side)]
            if not entry then
                error(string.format("augment: %s has no picture vector (new or changed since "
                    .. "Stage 6 ran); run Stage 6 (--generate-embeddings)", path))
            end
            return entry.embedding
        end,
    }
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
    local catalog_data = assert(read_json(DIR .. "/assets/image-catalog.json"),
        "missing image-catalog.json -- run the picture catalog (Stage 5) first")

    local pictures_in = M.pictures_from_cache(DIR, model, edir, poems_data, catalog_data)
    local out, manifest, report = M.augment(embeddings_data, poems_data, catalog_data, pictures_in)
    embeddings_data.embeddings = out
    embeddings_data.metadata = embeddings_data.metadata or {}
    embeddings_data.metadata.image_pseudo_embeddings = report

    write_json(emb_path, embeddings_data)
    write_json(manifest_path, { metadata = report, images = manifest })
    -- Issue 8-019: the pictures are filed by number after the poems; record
    -- which numbering, beside the list (the embeddings keep theirs)
    require("numbering-stamp").write(manifest_path, require("numbering-stamp").of_embeddings(embeddings_data))

    require("output").print(string.format(
        "[augment] text+picture posts=%d (blended %d)  picture-only posts=%d  gallery pictures appended=%d",
        report.class1, report.blended, report.class2, report.class3))
    require("output").print(string.format(
        "[augment] placed by their pictures=%d  by the poems either side (no picture in their media)=%d  skipped=%d",
        report.by_picture, report.by_neighbours, report.skipped))
    require("output").print(string.format("[augment] embeddings: %d entries -> %s", #out, emb_path))
    require("output").print(string.format("[augment] manifest: %s", manifest_path))
end
-- }}}

-- Run main() only when invoked as a script (not when required by the test).
if not _G.AUGMENT_NO_MAIN then
    -- start, end and any stopping error go to the run's log (Issue 10-075)
    require("output").guard("augment-embeddings-with-images.lua", main)
end

return M
