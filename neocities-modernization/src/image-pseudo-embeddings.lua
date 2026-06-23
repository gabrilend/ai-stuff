-- image-pseudo-embeddings.lua
--
-- Issue 9-013 (redesign): give every image a "pseudo-embedding" so it can be
-- ranked on similar/different pages like a poem. An image carries no usable
-- semantic vector of its own, so we synthesize one from WHERE it sits in time:
-- the average of the embeddings of the poem immediately before it and the poem
-- immediately after it chronologically. That places the image at the semantic
-- midpoint of its two temporal neighbours -- its true "between two moments"
-- position.
--
-- This module is deliberately PURE: it takes poems-with-embeddings and image
-- records that already carry a numeric `timestamp`, and returns image
-- pseudo-poems. No file I/O, no date parsing, no GPU -- so it is unit-testable
-- on tiny fixtures. The pipeline caller does the loading, the ISO-date ->
-- timestamp conversion, and the join of embeddings.json to poems.json.

local M = {}

-- {{{ local function l2_normalize()
-- Scale a vector to unit length. Cosine similarity is unaffected by magnitude,
-- but normalizing keeps the pseudo-embeddings on the same footing as the poem
-- embeddings the downstream cosine code expects. A zero vector is returned
-- unchanged (no division by zero) -- it would only arise from degenerate input.
local function l2_normalize(vec)
    local sum = 0
    for i = 1, #vec do sum = sum + vec[i] * vec[i] end
    if sum == 0 then return vec end
    local inv = 1 / math.sqrt(sum)
    local out = {}
    for i = 1, #vec do out[i] = vec[i] * inv end
    return out
end
-- }}}

-- {{{ local function crooked_embedding()
-- Build an image's pseudo-embedding by CROSS-CUTTING its two neighbours instead
-- of averaging them: the first SEAM dimensions come from the poem BEFORE the
-- image, the rest from the poem AFTER.
--
-- Why not the midpoint? Averaging two unit vectors smooths them toward the
-- corpus centre -- measured at +12% closer to the centroid, with the spread
-- collapsing -- which turns images into "hubs" that flood every poem's similar
-- list (and never appear in the diversity-spread different lists). Concatenation
-- keeps each dimension's full, real-poem magnitude, so the result sits at the
-- normal baseline centrality (measured -0.1%) and ranks like an ordinary poem.
--
-- nomic-embed-text-v1.5 is a Matryoshka model: its leading dimensions carry the
-- coarse meaning, so the seam reads poetically as "the image takes its SUBJECT
-- from the poem before it and its TEXTURE from the poem after it." The seam
-- position is a FLAVOUR knob (it shifts which poems the image resembles) and was
-- measured to NOT affect hubness, so it is safe to tune for feel.
--
-- The one-neighbour case (an image before the first poem or after the last) has
-- only one side, so it simply takes that real poem's direction.
local SEAM_FRACTION = 0.5  -- 0.5 = half subject / half texture; lower leans toward the 'after' poem
local function crooked_embedding(before, after)
    if before and after then
        local seam = math.floor(#before * SEAM_FRACTION)
        local out = {}
        for i = 1, #before do out[i] = (i <= seam) and before[i] or after[i] end
        return l2_normalize(out)
    end
    -- Exactly one side present (timeline end). Copy + normalize it.
    local single = before or after
    local out = {}
    for i = 1, #single do out[i] = single[i] end
    return l2_normalize(out)
end
-- }}}

-- {{{ function M.qualified_image_title()
-- Build the colon-joined "full path" title shared with Issue 10-042d, e.g.
--   my-art: air-defence-drones-5.png
--   my-art: game-design: camera-idea.png
-- source_name is the gallery source; rel_below_source is the image's path BELOW
-- that source dir (subdirs + filename). Slashes become ": " so nesting reads as
-- a breadcrumb instead of a URL.
function M.qualified_image_title(source_name, rel_below_source)
    local tail = (rel_below_source or ""):gsub("^/+", ""):gsub("/", ": ")
    if tail == "" then return source_name end
    return source_name .. ": " .. tail
end
-- }}}

-- {{{ function M.find_chrono_neighbors()
-- Given poems sorted ascending by timestamp and a target time, return the
-- nearest poem at-or-before and the nearest at-or-after (either may be nil at
-- the ends). Binary search -> O(log n) per image. `sorted_poems` must already
-- be sorted by `.timestamp`.
function M.find_chrono_neighbors(sorted_poems, t)
    local lo, hi = 1, #sorted_poems
    if hi == 0 then return nil, nil end
    -- Find the first index whose timestamp >= t.
    local first_ge = hi + 1
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if sorted_poems[mid].timestamp >= t then
            first_ge = mid
            hi = mid - 1
        else
            lo = mid + 1
        end
    end
    local after = sorted_poems[first_ge]              -- at-or-after (or nil)
    local before = sorted_poems[first_ge - 1]         -- strictly before (or nil)
    -- If a poem sits exactly at t, treat it as BOTH sides so the image lands on
    -- that exact moment rather than averaging across it.
    if after and after.timestamp == t then
        return after, after
    end
    return before, after
end
-- }}}

-- {{{ function M.compute_image_pseudo_embeddings()
-- Core entry point. Inputs:
--   poems  : array of { poem_index, timestamp (number), embedding (array) }
--   images : array of { id, source_name, rel_below_source, timestamp (number), ... }
-- Returns: array of image pseudo-poems, each carrying the synthesized
-- `embedding`, a `display_title`, and the original image record under `image`.
-- Images whose neighbours have no usable embedding (empty timeline) are skipped
-- and reported in the second return value so the caller can warn -- a missing
-- pseudo-embedding is an error condition (no silent fallback), per project rules.
function M.compute_image_pseudo_embeddings(poems, images)
    -- Sort a shallow copy by timestamp so the caller's order is untouched.
    local sorted = {}
    for i = 1, #poems do sorted[i] = poems[i] end
    table.sort(sorted, function(a, b) return a.timestamp < b.timestamp end)

    local pseudo = {}
    local skipped = {}
    for _, img in ipairs(images) do
        local before, after = M.find_chrono_neighbors(sorted, img.timestamp)
        local be = before and before.embedding
        local ae = after and after.embedding
        if be or ae then
            pseudo[#pseudo + 1] = {
                is_image = true,
                id = img.id,
                source_name = img.source_name,
                rel_below_source = img.rel_below_source,
                display_title = M.qualified_image_title(img.source_name, img.rel_below_source),
                timestamp = img.timestamp,
                embedding = crooked_embedding(be, ae),
                image = img,            -- keep the raw record for rendering
            }
        else
            skipped[#skipped + 1] = img
        end
    end
    return pseudo, skipped
end
-- }}}

return M
