-- {{{ embedding-space.lua
-- How this project prepares embedding vectors before anything compares them.
--
-- In a sentence: subtract the direction every vector shares, so that cosine
-- similarity measures what a poem is about instead of measuring the model's
-- habit.
--
-- The model does not spread its output over the whole sphere. Measured on this
-- corpus, the average of all poem vectors has length 0.766 against vectors of
-- length 1.0 -- roughly three quarters of every vector is one direction common
-- to all of them. Run scripts/measure-embedding-spread to re-measure; the figure
-- is a property of the model in use, not a constant.
--
-- What that costs, measured over 4,000 poems with twenty neighbours each
-- (scripts/measure-centering-effect):
--
--                                as-is    centred
--   most-listed poem              526        191    out of 4000
--   top 1% of poems take        11.8%       5.3%    of all neighbour slots
--   poems in NOBODY's list        226         12
--
-- That third row is the reason this module exists. Two hundred and twenty-six
-- poems -- about one in eighteen -- appeared in no other poem's similar list at
-- all. Not ranked low: absent, unreachable by anyone browsing sideways. The
-- shared direction had made a handful of vectors everyone's neighbour and a
-- long tail nobody's. Subtracting it cuts the unreachable count to twelve.
--
-- Neighbour lists change by about 42% when this is applied, so it is not a
-- refinement -- it is a different set of answers, and switching it on or off
-- invalidates every cache built from it. That is what the fingerprint below is
-- for: a cache carries a note saying which space it was built in, and a stage
-- that finds the wrong note rebuilds instead of trusting it.
--
-- Deliberately NOT applied to word-to-poem comparison by a different rule: those
-- centre too, but they must, and for a sharper reason. A single word carries
-- MORE of the shared direction than a whole poem does (0.829 against 0.766), so
-- the offset is not constant across that comparison and distorts the ordering
-- rather than merely compressing it. Poem-to-poem survives without centring;
-- it just survives badly, as the table above shows.
-- }}}

local M = {}

-- {{{ M.SPACE_VERSION
-- Names how vectors are prepared. Written into a cache directory as a note, and
-- compared against on the next run.
--
-- Change this string whenever the preparation changes in a way that alters
-- similarity scores. Anything holding the old string is then known to be stale
-- rather than assumed to be fine -- which matters because a stale similarity
-- cache is not obviously wrong when you look at it. It is a complete, ordered,
-- plausible set of neighbours. It is simply the wrong set.
M.SPACE_VERSION = "mean-centered-v1"
-- }}}

-- {{{ M.FINGERPRINT_FILE
-- Sits beside the caches it describes, in the model's embeddings directory.
M.FINGERPRINT_FILE = "embedding_space.fingerprint"
-- }}}

-- {{{ function M.corpus_mean
-- The direction every vector shares: the plain average of all of them.
--
-- entries: array of records each carrying an `embedding` field (a Lua array of
--          numbers) -- i.e. embeddings.json's `.embeddings` as loaded.
-- returns: a Lua array of the same dimension, or nil plus a message.
--
-- Errors rather than averages past a vector of the wrong length. Two different
-- dimensions in one file means two models' output got mixed together, and an
-- average taken across them is a number with no meaning that would nonetheless
-- flow silently into every comparison downstream.
function M.corpus_mean(entries)
    if type(entries) ~= "table" or #entries == 0 then
        return nil, "corpus_mean: no embeddings to average"
    end

    local dims, mean, counted = nil, nil, 0
    for i = 1, #entries do
        local e = entries[i]
        local v = e and e.embedding
        if type(v) == "table" and #v > 0 then
            if not dims then
                dims = #v
                mean = {}
                for j = 1, dims do mean[j] = 0 end
            end
            if #v ~= dims then
                return nil, string.format(
                    "corpus_mean: dimension mismatch -- expected %d, found %d at entry %d "
                    .. "(embeddings.json mixes models; regenerate it)", dims, #v, i)
            end
            for j = 1, dims do mean[j] = mean[j] + v[j] end
            counted = counted + 1
        end
    end

    if not mean or counted == 0 then
        return nil, "corpus_mean: no usable embeddings found"
    end
    for j = 1, dims do mean[j] = mean[j] / counted end
    return mean, counted
end
-- }}}

-- {{{ function M.centered
-- One vector with the shared direction removed. Returns a NEW array; the caller's
-- copy is untouched, because several stages keep the raw vectors for other
-- purposes after comparing.
--
-- A nil mean returns the vector unchanged rather than erroring, so that a caller
-- which could not compute a mean degrades to the previous behaviour instead of
-- to zeros. Callers that must not degrade silently should check the mean
-- themselves -- corpus_mean's second return value says how many it averaged.
function M.centered(vec, mean)
    if not mean or type(vec) ~= "table" or #vec ~= #mean then
        return vec
    end
    local out = {}
    for j = 1, #vec do out[j] = vec[j] - mean[j] end
    return out
end
-- }}}

-- {{{ function M.fingerprint_path
function M.fingerprint_path(cache_dir)
    return cache_dir .. "/" .. M.FINGERPRINT_FILE
end
-- }}}

-- {{{ function M.read_fingerprint
-- What space the caches in this directory were built in, or nil if unmarked.
-- An unmarked directory is treated as "built before this was tracked", which is
-- a mismatch against any named version -- so the first run after this module
-- lands rebuilds, which is correct.
function M.read_fingerprint(cache_dir)
    local f = io.open(M.fingerprint_path(cache_dir), "r")
    if not f then return nil end
    local s = f:read("*l")
    f:close()
    if not s then return nil end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
-- }}}

-- {{{ function M.write_fingerprint
-- Stamp a cache directory with the space its contents were built in. Call this
-- AFTER the cache is successfully written, never before: a note written first
-- would survive a crashed rebuild and mark a half-finished cache as current.
function M.write_fingerprint(cache_dir)
    local f, err = io.open(M.fingerprint_path(cache_dir), "w")
    if not f then
        return false, "could not write embedding-space fingerprint: " .. tostring(err)
    end
    f:write(M.SPACE_VERSION, "\n")
    f:close()
    return true
end
-- }}}

-- {{{ function M.is_current
-- Does this directory's cache match the space we would build now?
function M.is_current(cache_dir)
    return M.read_fingerprint(cache_dir) == M.SPACE_VERSION
end
-- }}}

return M
