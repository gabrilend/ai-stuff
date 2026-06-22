-- themes-v2/tfidf.lua
-- Issue 029, slice 2: per-cluster distinctive vocabulary via TF-IDF.
--
-- Reads tmp/poem-texts.lua (text per poem) and tmp/clusters.lua (HDBSCAN
-- output mapping poems to clusters). For each cluster, computes the
-- words that are MOST distinctive vs. the rest of the corpus — not the
-- most frequent (which would be stop words everywhere) but the words
-- whose frequency in this cluster outweighs their frequency overall.
--
-- TF-IDF formula used:
--   tf(word, cluster)  = count of word in cluster / total words in cluster
--   df(word)           = number of poems containing word
--   idf(word)          = log(total_poems / (1 + df(word)))
--   score(word, cluster) = tf(word, cluster) * idf(word)
--
-- Output: tmp/cluster-tfidf.lua with top 20 words per cluster, used by
-- name-clusters.lua as the prompt seed for theme name generation.

local DIR = "/home/ritz/programming/ai-stuff/words-pdf"
if arg[1] and arg[1] ~= "" then DIR = arg[1] end

package.path = package.path .. ";" .. DIR .. "/?.lua;" .. DIR .. "/libs/?.lua"

local INPUT_TEXTS    = DIR .. "/tmp/poem-texts.lua"
local INPUT_CLUSTERS = DIR .. "/tmp/clusters.lua"
local OUTPUT_TFIDF   = DIR .. "/tmp/cluster-tfidf.lua"

local TOP_N = 20  -- words to keep per cluster

-- {{{ STOP_WORDS
-- Hand-picked from common English stop word lists, trimmed to what
-- actually shows up in this corpus and what's truly content-empty.
-- We deliberately keep words like "I", "me", "you" — they DO carry
-- meaning in poetry (1st-person vs. 2nd-person voice differs across
-- themes). Removing them would homogenize the clusters.
local STOP_WORDS = {}
for _, w in ipairs({
    "the", "a", "an", "and", "or", "but", "if", "then", "else",
    "for", "to", "of", "in", "on", "at", "by", "with", "from",
    "is", "are", "was", "were", "be", "been", "being",
    "have", "has", "had", "having", "do", "does", "did", "doing",
    "will", "would", "should", "could", "may", "might", "must", "can",
    "this", "that", "these", "those", "it", "its",
    "so", "as", "than", "into", "out", "up", "down", "off",
    "not", "no", "yes",
    "very", "just", "only", "even", "also", "still",
    "there", "here", "where", "when", "why", "how", "what", "who", "which",
    "any", "all", "some", "more", "most", "other", "another",
    "about", "over", "under", "between", "through",
}) do STOP_WORDS[w] = true end
-- }}}

-- {{{ local function tokenize
-- Lowercase, split on non-alphanumeric, drop stop words and tokens
-- shorter than 3 chars (mostly numbers and stray characters). Keeps
-- alphanumeric tokens including embedded underscores so things like
-- "non_binary" survive intact, but the corpus has very few of those.
local function tokenize(text)
    local tokens = {}
    for word in text:lower():gmatch("[%w_]+") do
        if #word >= 3 and not STOP_WORDS[word] and not word:match("^%d+$") then
            table.insert(tokens, word)
        end
    end
    return tokens
end
-- }}}

-- {{{ local function compute_document_frequency
-- For each word, count the number of poems that contain it. Returns
-- a map word -> count. Also returns the total poem count.
local function compute_document_frequency(texts)
    local df = {}
    local n = 0
    for _, text in pairs(texts) do
        n = n + 1
        local seen = {}
        for _, word in ipairs(tokenize(text)) do
            seen[word] = true
        end
        for word in pairs(seen) do
            df[word] = (df[word] or 0) + 1
        end
    end
    return df, n
end
-- }}}

-- {{{ local function compute_cluster_tf
-- For one cluster's poem ids, count word frequencies summed across all
-- member poems. Returns the count map and the total token count.
local function compute_cluster_tf(member_ids, texts)
    local tf = {}
    local total = 0
    for _, pid in ipairs(member_ids) do
        -- Texts are 1-indexed but cluster member_ids are 0-indexed (matches
        -- the embedding buffer). +1 to convert.
        local text = texts[pid + 1]
        if text then
            for _, word in ipairs(tokenize(text)) do
                tf[word] = (tf[word] or 0) + 1
                total = total + 1
            end
        end
    end
    return tf, total
end
-- }}}

-- {{{ local function top_tfidf
-- Compute TF-IDF scores for every word in the cluster, return the top N.
local function top_tfidf(cluster_tf, total_tokens, df, total_docs, top_n)
    local scored = {}
    local log = math.log
    for word, count in pairs(cluster_tf) do
        local tf = count / total_tokens
        local idf = log(total_docs / (1 + (df[word] or 0)))
        local score = tf * idf
        if score > 0 then  -- some idf values can be ~0 for pervasive words
            table.insert(scored, {word = word, score = score, count = count})
        end
    end
    table.sort(scored, function(a, b) return a.score > b.score end)
    local out = {}
    for i = 1, math.min(top_n, #scored) do
        out[i] = scored[i]
    end
    return out
end
-- }}}

-- {{{ local function main
local function main()
    print("📖 Loading " .. INPUT_TEXTS)
    local texts = dofile(INPUT_TEXTS)
    print(string.format("    %d poems loaded", select(2, next(texts)) and #texts or 0))

    print("📖 Loading " .. INPUT_CLUSTERS)
    local clusters_data = dofile(INPUT_CLUSTERS)
    print(string.format("    %d clusters, %d noise points",
        #clusters_data.clusters, clusters_data.noise_count))

    print("\n🔢 Computing document frequencies across whole corpus")
    local df, total_docs = compute_document_frequency(texts)
    print(string.format("    %d unique words across %d poems", select(2, (function()
        local n = 0; for _ in pairs(df) do n = n + 1 end; return nil, n
    end)()), total_docs))

    print("\n🔍 Per-cluster TF-IDF (top " .. TOP_N .. ")")
    local out = io.open(OUTPUT_TFIDF, "w")
    if not out then error("Cannot write " .. OUTPUT_TFIDF) end
    out:write("-- Generated by themes-v2/tfidf.lua (issue 029)\n")
    out:write("return {\n")
    for _, cluster in ipairs(clusters_data.clusters) do
        local cluster_tf, total_tokens = compute_cluster_tf(cluster.member_ids, texts)
        local top = top_tfidf(cluster_tf, total_tokens, df, total_docs, TOP_N)
        print(string.format("  cluster %d (%d poems): top word = %s (%.4f)",
            cluster.id, cluster.member_count,
            top[1] and top[1].word or "(none)",
            top[1] and top[1].score or 0))
        out:write(string.format("  [%d] = {\n", cluster.id))
        for _, entry in ipairs(top) do
            out:write(string.format("    {word = %q, score = %.6f, count = %d},\n",
                entry.word, entry.score, entry.count))
        end
        out:write("  },\n")
    end
    out:write("}\n")
    out:close()

    print("\n✅ Wrote " .. OUTPUT_TFIDF)
end
-- }}}

main()
