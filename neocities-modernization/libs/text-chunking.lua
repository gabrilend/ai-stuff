-- {{{ text-chunking.lua
-- Issue 10-050: shared long-text chunking + chunk-vector recombination.
--
-- Why this module exists: embedding models have a fixed context window
-- (nomic-embed-text v1.5 caps at 2048 tokens). A poem longer than that is
-- either rejected by the server or silently truncated by the model. Before
-- this module, src/centroid-generator.lua had its own recursive splitter and
-- every other consumer had none. This centralises one algorithm so the poem
-- loop, word-cloud, colors, and centroids all chunk identically.
--
-- The two halves of the problem:
--   1. SPLIT a too-long text into pieces that each fit the model, preferring to
--      cut at meaningful boundaries (paragraph > sentence > line > word) so a
--      chunk is a coherent unit of meaning, not an arbitrary byte range.
--   2. RECOMBINE the per-chunk vectors back into one vector for the poem, so
--      downstream code keeps seeing exactly one embedding per poem.
--
-- Chunk sizing is EXACT: the fit test is the real token count from an injected
-- `count_fn(string) -> token_count`, never a character estimate. There is no
-- chars-per-token heuristic anywhere — an estimate can undercount dense text and
-- silently overflow the context. The count_fn is a parameter (not a hard
-- dependency) so the algorithm stays a PURE function, unit-testable with a mock
-- counter and no server. See libs/text-chunking-test.lua.
--
-- chunk_text_by_tokens returns (chunks, counts): the exact token count of each
-- chunk, computed as a byproduct of sizing, so callers (request packing in
-- fuzzy-computing) never have to re-estimate or re-tokenize.
-- }}}

local M = {}

-- {{{ Tunables
-- Boundary separators in descending priority. We try to cut at a paragraph
-- break first (most semantically clean), fall back to sentence, then line, then
-- word, and finally a hard token split if a single "word" is itself longer
-- than a chunk (degenerate input, e.g. a giant URL or base64 blob).
--
-- ". " is a plain-string approximation of a sentence boundary. It misses
-- abbreviations and "?"/"!" endings, but it is cheap and the consequence of a
-- miss is only a slightly larger-or-smaller chunk, never a failure.
M.SEPARATORS = { "\n\n", ". ", "\n", " " }
-- }}}

-- {{{ local function split_keeping_separator(text, sep)
-- Split `text` on the literal string `sep`, but KEEP each separator attached to
-- the end of the piece it followed. This matters because it makes the split
-- lossless: table.concat(pieces) == text exactly, so re-packing the pieces can
-- never corrupt or drop characters from a poem. (A naive gmatch split would
-- silently eat the delimiters.) Splitting only ever happens at whitespace
-- separators, which WordPiece never tokenizes across — so the token count of a
-- concatenation equals the sum of its pieces' counts, which is what lets the
-- packer below keep an EXACT running token total.
local function split_keeping_separator(text, sep)
    local pieces = {}
    local start = 1
    while true do
        -- plain=true: treat sep as a literal string, not a Lua pattern, so
        -- "." and other magic chars in a separator are matched verbatim.
        local s, e = string.find(text, sep, start, true)
        if not s then
            pieces[#pieces + 1] = string.sub(text, start)
            break
        end
        pieces[#pieces + 1] = string.sub(text, start, e)
        start = e + 1
    end
    return pieces
end
-- }}}

-- {{{ local function largest_prefix_within(text, count_fn, max_tokens)
-- Binary-search the largest character prefix of `text` whose exact token count
-- is <= max_tokens. Used only by the no-separator hard split below. Token count
-- is monotonic non-decreasing in prefix length, so binary search is valid.
local function largest_prefix_within(text, count_fn, max_tokens)
    local lo, hi, best = 1, #text, 1
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if count_fn(string.sub(text, 1, mid)) <= max_tokens then
            best = mid
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    return best
end
-- }}}

-- {{{ local function hard_split_by_tokens(text, count_fn, max_tokens)
-- Last resort when a blob has no separator of any priority yet exceeds the token
-- budget (e.g. a giant unbroken URL/base64 run). Carves off the largest
-- token-fitting prefix repeatedly. Rare in prose/poetry; included for safety.
-- Returns (chunks, counts) with each chunk's exact token count.
local function hard_split_by_tokens(text, count_fn, max_tokens)
    local chunks, counts = {}, {}
    local s = 1
    while s <= #text do
        local remaining = string.sub(text, s)
        local len = largest_prefix_within(remaining, count_fn, max_tokens)
        if len < 1 then len = 1 end  -- always make progress
        local piece = string.sub(remaining, 1, len)
        chunks[#chunks + 1] = piece
        counts[#counts + 1] = count_fn(piece)
        s = s + len
    end
    return chunks, counts
end
-- }}}

-- {{{ local function chunk_by_tokens_recursive(text, count_fn, max_tokens, sep_index)
-- Greedily PACK pieces (split at the current priority's separator) into chunks
-- up to max_tokens, making the fewest, fullest chunks that still respect
-- boundaries. Any single piece that is itself too large is recursively re-split
-- at the next-lower separator. Returns (chunks, counts) — the exact token count
-- of every emitted chunk, free, because we already counted to size it.
local function chunk_by_tokens_recursive(text, count_fn, max_tokens, sep_index)
    -- Whole text fits: return it as a single chunk with its exact count. (We
    -- tokenize even short texts — the count is needed for request packing, so
    -- there is no char shortcut to skip it.)
    local n_text = count_fn(text)
    if n_text <= max_tokens then
        return { text }, { n_text }
    end

    local sep = M.SEPARATORS[sep_index]
    if not sep then
        return hard_split_by_tokens(text, count_fn, max_tokens)
    end

    local pieces = split_keeping_separator(text, sep)
    if #pieces == 1 then
        return chunk_by_tokens_recursive(text, count_fn, max_tokens, sep_index + 1)
    end

    -- Greedy pack by summed exact piece counts. Because pieces split at
    -- whitespace separators, the token count of a concatenation equals the sum
    -- of its pieces' counts, so the running sum (current_tokens) is exact and
    -- each assembled chunk is provably <= max_tokens.
    local chunks, counts = {}, {}
    local current = ""
    local current_tokens = 0
    for _, piece in ipairs(pieces) do
        local pt = count_fn(piece)
        if pt > max_tokens then
            -- piece alone overflows: flush, then split it at a finer separator
            if #current > 0 then
                chunks[#chunks + 1] = current
                counts[#counts + 1] = current_tokens
                current = ""
                current_tokens = 0
            end
            local subs, subcounts = chunk_by_tokens_recursive(piece, count_fn, max_tokens, sep_index + 1)
            for i = 1, #subs do
                chunks[#chunks + 1] = subs[i]
                counts[#counts + 1] = subcounts[i]
            end
        elseif current_tokens + pt <= max_tokens then
            current = current .. piece
            current_tokens = current_tokens + pt
        else
            if #current > 0 then
                chunks[#chunks + 1] = current
                counts[#counts + 1] = current_tokens
            end
            current = piece
            current_tokens = pt
        end
    end
    if #current > 0 then
        chunks[#chunks + 1] = current
        counts[#counts + 1] = current_tokens
    end
    return chunks, counts
end
-- }}}

-- {{{ function M.chunk_text_by_tokens(text, count_fn, max_tokens)
-- Public entry point for exact, token-bounded chunking. count_fn(string) must
-- return that string's exact token count under the embedding model's tokenizer.
-- Returns (chunks, counts): chunks each <= max_tokens tokens, and counts[i] the
-- exact token count of chunks[i]. A text that already fits comes back as one
-- element; whitespace-only input returns ({}, {}). max_tokens is REQUIRED —
-- compute it exactly (see fuzzy.embedding_chunk_budget); there is no default.
function M.chunk_text_by_tokens(text, count_fn, max_tokens)
    if not max_tokens then
        error("chunk_text_by_tokens: max_tokens is required (compute it exactly, "
            .. "e.g. fuzzy.embedding_chunk_budget)")
    end
    if type(text) ~= "string" or text:match("^%s*$") then
        return {}, {}
    end
    return chunk_by_tokens_recursive(text, count_fn, max_tokens, 1)
end
-- }}}

-- {{{ function M.combine_chunk_vectors(vectors, weights, strategy)
-- Fold the per-chunk embedding vectors of ONE poem back into a single vector.
--
--   vectors  : array of equal-length number arrays (one per chunk)
--   weights  : array of per-chunk weights (chunk char lengths for the default
--              strategy); ignored by "mean" and "first_only". Optional.
--   strategy : "length_weighted_mean" (default) | "mean" | "first_only"
--
-- Strategy rationale (full discussion in issues/10-050):
--   length_weighted_mean — a chunk holding more text holds more meaning, so it
--     pulls the combined vector harder. Best default for stanzas of uneven size.
--   mean — equal weight per chunk; simplest, fine when chunks are even.
--   first_only — keep only the opening chunk's vector; cheap, throws away the
--     rest, useful only if a poem's head is treated as its anchor.
--
-- Returns nil if there are no vectors. A single vector is returned as-is.
function M.combine_chunk_vectors(vectors, weights, strategy)
    strategy = strategy or "length_weighted_mean"

    if not vectors or #vectors == 0 then
        return nil
    end
    if #vectors == 1 then
        return vectors[1]
    end
    if strategy == "first_only" then
        return vectors[1]
    end

    local dim = #vectors[1]
    local combined = {}
    for d = 1, dim do
        combined[d] = 0
    end

    -- "mean" is just length_weighted_mean with every weight equal to 1, so we
    -- collapse both into one accumulation pass driven by a per-chunk weight.
    local total_weight = 0
    for c = 1, #vectors do
        local vec = vectors[c]
        -- Guard: a chunk whose embedding failed/short-circuited would corrupt
        -- the mean. Error loudly on a mismatched-dimension vector rather than
        -- blend garbage (prefer breaking over silent fallback, per project policy).
        if #vec ~= dim then
            error(string.format(
                "combine_chunk_vectors: chunk %d has dimension %d, expected %d",
                c, #vec, dim))
        end
        local w
        if strategy == "mean" then
            w = 1
        else
            w = (weights and weights[c]) or 1
        end
        total_weight = total_weight + w
        for d = 1, dim do
            combined[d] = combined[d] + (vec[d] * w)
        end
    end

    if total_weight == 0 then
        return nil
    end
    for d = 1, dim do
        combined[d] = combined[d] / total_weight
    end
    return combined
end
-- }}}

return M

-- vim: set foldmethod=marker:
