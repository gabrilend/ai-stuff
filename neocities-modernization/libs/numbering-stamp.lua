-- numbering-stamp.lua: which numbering of the poems a cache was made under
-- (Issue 8-019).
--
-- Poems are numbered fresh on every extraction, in date order, so a number
-- means "the Nth poem of THIS run". The embeddings, the similarity rankings,
-- the diversity walks, the poem colours and the picture list are all filed
-- by number; one made under another run's numbering would hand poems each
-- other's neighbours and colours, with nothing on the page to show it (the
-- notes of 2026-10-07). So each records the numbering it was made under:
--   - poems.json: metadata.numbering.fingerprint (the extractor writes it, a
--     code made from the poems' source keys in order)
--   - embeddings.json: metadata.numbering (the embedding stage copies it)
--   - every cache made from the embeddings: a stamp file beside it,
--     <cache>.numbering, holding the embeddings' numbering
-- and the stages that read them check before using them.

local M = {}

M.SUFFIX = ".numbering"

-- {{{ function M.of_poems
-- The numbering's code from a loaded poems.json; an error for a list made
-- before numbering stamps.
function M.of_poems(poems_data)
    local n = poems_data and poems_data.metadata and poems_data.metadata.numbering
    if not (n and n.fingerprint) then
        error("poems.json has no numbering fingerprint (made before Issue 8-019); rerun the extraction (stage 3)")
    end
    return n.fingerprint
end
-- }}}

-- {{{ function M.of_embeddings
-- The numbering a loaded embeddings.json was filed under; an error for one
-- made before numbering stamps.
function M.of_embeddings(embeddings_data)
    local n = embeddings_data and embeddings_data.metadata and embeddings_data.metadata.numbering
    if type(n) ~= "string" then
        error("embeddings.json records no numbering (made before Issue 8-019); rerun the embedding stage (stage 6, --force)")
    end
    return n
end
-- }}}

-- {{{ function M.write
-- Stamp a cache file with the numbering it was made under, beside it.
function M.write(cache_path, numbering)
    if type(numbering) ~= "string" or numbering == "" then
        error("numbering-stamp: no numbering to stamp " .. tostring(cache_path) .. " with")
    end
    local f = io.open(cache_path .. M.SUFFIX, "w")
    if not f then error("numbering-stamp: could not write " .. cache_path .. M.SUFFIX) end
    f:write(numbering, "\n")
    f:close()
end
-- }}}

-- {{{ function M.read
-- The numbering a cache was stamped with, or nil when it has no stamp.
function M.read(cache_path)
    local f = io.open(cache_path .. M.SUFFIX, "r")
    if not f then return nil end
    local value = f:read("*l")
    f:close()
    return value
end
-- }}}

-- {{{ function M.check
-- Stop unless the cache was made under the expected numbering.
-- what: how to name the cache in the error ("similarity rankings")
-- fix:  what to rerun ("stage 7")
function M.check(cache_path, expected, what, fix)
    local recorded = M.read(cache_path)
    if recorded == expected then return true end
    if not recorded then
        error(string.format("the %s (%s) record no numbering; rerun %s", what, cache_path, fix))
    end
    error(string.format("the %s were made under another numbering of the poems (%s, the poems are %s); rerun %s",
        what, recorded, expected, fix))
end
-- }}}

return M
