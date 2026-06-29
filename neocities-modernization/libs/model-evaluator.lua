-- {{{ model-evaluator.lua
-- Pure comparison + statistics for the embedding-model evaluation framework
-- (Issue 10-031). Given several models' embeddings of the SAME pool of poems,
-- it answers: for a given anchor poem, what does each model call "most similar",
-- how much do the models agree, and -- the interesting part -- what KIND of
-- similarity does each model seem to reward (surface word overlap vs something
-- deeper, and does it favor poems of similar length)?
--
-- General description (for a CEO): three judges each rank the same line-up of
-- poems by "how like this one is it". This module measures how often the judges
-- agree, where they sharply disagree, and what each judge seems to care about --
-- so a human can read three columns side by side and SEE that one judge rewards
-- shared wording while another rewards shared meaning.
--
-- Deliberately has NO IO and NO model/server knowledge: it takes plain Lua
-- tables (vectors and text) and returns plain Lua tables. That keeps the math
-- testable in isolation and lets the generation/orchestration layer own all the
-- messy parts (servers, files). Data generation and data viewing stay apart.
-- }}}

local M = {}

-- {{{ local function cosine(a, b)
-- Cosine similarity of two equal-length vectors. The embedding spaces differ in
-- dimensionality across models (768 vs 1024), which is fine: cosine is only ever
-- compared WITHIN a single model's space, never across, so the absolute numbers
-- are per-model and only their RANKINGS are compared between models.
local function cosine(a, b)
    local dot, na, nb = 0.0, 0.0, 0.0
    for i = 1, #a do
        local x, y = a[i], b[i]
        dot = dot + x * y
        na = na + x * x
        nb = nb + y * y
    end
    if na == 0 or nb == 0 then return 0.0 end
    return dot / (math.sqrt(na) * math.sqrt(nb))
end
M.cosine = cosine
-- }}}

-- {{{ function M.rank_anchor(anchor_vec, pool, exclude_index, top_k)
-- Rank every poem in `pool` (a map of poem_index -> vector) by cosine similarity
-- to anchor_vec, nearest first, dropping the anchor itself (exclude_index).
-- Returns an array of { poem_index = n, score = s }, length min(top_k, #pool-1).
-- A stable tiebreaker (poem_index ascending) keeps the ranking deterministic so
-- two runs -- and the rank-correlation math below -- are reproducible.
function M.rank_anchor(anchor_vec, pool, exclude_index, top_k)
    local scored = {}
    for idx, vec in pairs(pool) do
        if idx ~= exclude_index then
            scored[#scored + 1] = { poem_index = idx, score = cosine(anchor_vec, vec) }
        end
    end
    table.sort(scored, function(p, q)
        if p.score ~= q.score then return p.score > q.score end
        return p.poem_index < q.poem_index
    end)
    if top_k and #scored > top_k then
        for i = #scored, top_k + 1, -1 do scored[i] = nil end
    end
    return scored
end
-- }}}

-- {{{ function M.topk_agreement(rank_a, rank_b, k)
-- How many poems appear in BOTH models' top-k for the same anchor (set overlap,
-- order ignored). The headline "do they even pick the same poems" number.
function M.topk_agreement(rank_a, rank_b, k)
    local in_a = {}
    for i = 1, math.min(k, #rank_a) do in_a[rank_a[i].poem_index] = true end
    local shared = 0
    for i = 1, math.min(k, #rank_b) do
        if in_a[rank_b[i].poem_index] then shared = shared + 1 end
    end
    return shared
end
-- }}}

-- {{{ function M.kendall_tau(rank_a, rank_b)
-- Kendall's tau-b over the poems the two rankings share: +1 = identical order,
-- 0 = unrelated, -1 = reversed. We restrict to the intersection of the two
-- rankings (each model only ranks the pool it embedded, and we usually pass the
-- top-N slices) and count concordant vs discordant pairs. This is O(n^2) in the
-- shared set, which is fine for the small top-N slices we feed it.
function M.kendall_tau(rank_a, rank_b)
    local pos_a, pos_b = {}, {}
    for i, e in ipairs(rank_a) do pos_a[e.poem_index] = i end
    for i, e in ipairs(rank_b) do pos_b[e.poem_index] = i end
    local common = {}
    for idx in pairs(pos_a) do
        if pos_b[idx] then common[#common + 1] = idx end
    end
    local n = #common
    if n < 2 then return nil, n end  -- undefined with fewer than two shared items
    local concordant, discordant = 0, 0
    for i = 1, n - 1 do
        for j = i + 1, n do
            local di = pos_a[common[i]] - pos_a[common[j]]
            local dj = pos_b[common[i]] - pos_b[common[j]]
            local s = di * dj
            if s > 0 then concordant = concordant + 1
            elseif s < 0 then discordant = discordant + 1 end
            -- ties (s == 0) contribute to neither; with distinct ranks there are none
        end
    end
    local total = concordant + discordant
    if total == 0 then return nil, n end
    return (concordant - discordant) / total, n
end
-- }}}

-- {{{ local function word_set(text)
-- Lowercased set of alphanumeric word tokens. Used for the lexical-overlap
-- signal: it is the crudest, most "surface" notion of similarity there is, which
-- is exactly why it is useful as a contrast to what the neural models do.
local function word_set(text)
    local set = {}
    for w in tostring(text):lower():gmatch("[%w']+") do
        set[w] = true
    end
    return set
end
-- }}}

-- {{{ function M.lexical_jaccard(text_a, text_b)
-- Jaccard overlap of the two poems' word sets: |A n B| / |A u B|, in [0,1].
-- High = the two poems literally share many words (surface/structural kinship);
-- low = they share few words yet a model still called them similar (so the model
-- is rewarding something OTHER than shared vocabulary -- meaning, theme, tone).
function M.lexical_jaccard(text_a, text_b)
    local a, b = word_set(text_a), word_set(text_b)
    local inter, union = 0, 0
    local seen = {}
    for w in pairs(a) do
        seen[w] = true
        union = union + 1
        if b[w] then inter = inter + 1 end
    end
    for w in pairs(b) do
        if not seen[w] then union = union + 1 end
    end
    if union == 0 then return 0.0 end
    return inter / union
end
-- }}}

-- {{{ function M.personality(anchor_text, anchor_len, ranked, texts, lengths, k)
-- Turn a model's top-k matches for one anchor into interpretable signals:
--   mean_jaccard  : average word-overlap between the anchor and its top matches.
--                   Higher => this model leans on shared wording (surface/structure).
--   mean_len_ratio: average length similarity, min/max of the word counts, in (0,1].
--                   Near 1 => the model's favourites are close in length to the
--                   anchor (a length bias); lower => it pairs across lengths freely.
--   mean_score    : average cosine of the top matches (how "confident" / tight the
--                   neighbourhood is in this model's space -- only comparable to the
--                   same model's other anchors, not across models).
-- These are descriptive, not verdicts: the report shows them so a human can judge.
function M.personality(anchor_text, anchor_len, ranked, texts, lengths, k)
    k = math.min(k or #ranked, #ranked)
    local sum_j, sum_lr, sum_s, n = 0.0, 0.0, 0.0, 0
    for i = 1, k do
        local idx = ranked[i].poem_index
        local t = texts[idx]
        if t then
            n = n + 1
            sum_j = sum_j + M.lexical_jaccard(anchor_text, t)
            local la, lb = anchor_len or 0, lengths[idx] or 0
            if la > 0 and lb > 0 then
                sum_lr = sum_lr + (math.min(la, lb) / math.max(la, lb))
            end
            sum_s = sum_s + ranked[i].score
        end
    end
    if n == 0 then return { mean_jaccard = 0, mean_len_ratio = 0, mean_score = 0, n = 0 } end
    return {
        mean_jaccard = sum_j / n,
        mean_len_ratio = sum_lr / n,
        mean_score = sum_s / n,
        n = n,
    }
end
-- }}}

-- {{{ function M.mean(list)
-- Small helper: arithmetic mean of a numeric array, or nil if empty (so callers
-- can render "n/a" rather than divide by zero -- nil-as-error, not nil-as-zero).
function M.mean(list)
    local sum, n = 0.0, 0
    for _, v in ipairs(list) do
        if v then sum = sum + v; n = n + 1 end
    end
    if n == 0 then return nil end
    return sum / n
end
-- }}}

return M
