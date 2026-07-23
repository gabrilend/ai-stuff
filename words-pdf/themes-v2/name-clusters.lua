-- themes-v2/name-clusters.lua
-- Issue 029, slice 2: assign human-readable names to HDBSCAN clusters.
--
-- For each cluster:
--   1. Find the 3 poems closest to the cluster centroid by cosine
--      similarity (the "most representative" exemplars).
--   2. Build a prompt for Qwen3 with the TF-IDF top words and the
--      sample excerpts; ask for 5 candidate snake_case theme names.
--   3. Embed each candidate via fuzz.get_embedding (nomic encoder).
--   4. Pick the candidate with the highest cosine similarity to the
--      cluster centroid — i.e. the name that best represents the
--      cluster's actual semantic location.
--
-- This closes the loop: the LLM brainstorms names, but the cluster's
-- own embedding-space geometry has the final vote. The choice is
-- deterministic once the embeddings and candidates are fixed.
--
-- Output: themes/derived-taxonomy.lua containing one entry per cluster:
--   { name, description, centroid: {768 floats}, top_words, member_count }
-- This file is the runtime's source-of-truth for theme definitions
-- (compile-pdf-ai.lua loads it instead of hard-coded theme tables).

local DIR = "/home/ritz/programming/ai-stuff/words-pdf"
if arg[1] and arg[1] ~= "" then DIR = arg[1] end

package.path = package.path .. ";" .. DIR .. "/?.lua;" .. DIR .. "/libs/?.lua"

local INPUT_CLUSTERS    = DIR .. "/tmp/shared-memory/clusters.lua"
local INPUT_TFIDF       = DIR .. "/tmp/shared-memory/cluster-tfidf.lua"
local INPUT_TEXTS       = DIR .. "/tmp/shared-memory/poem-texts.lua"
local INPUT_POEMS_BIN   = DIR .. "/tmp/shared-memory/poem-embeddings.bin"
local INPUT_CENTROIDS_BIN = DIR .. "/tmp/shared-memory/cluster-centroids.bin"
local OUTPUT_TAXONOMY   = DIR .. "/themes/derived-taxonomy.lua"

local SAMPLE_EXCERPTS_PER_CLUSTER = 3
local EXCERPT_CHARS = 240   -- per-excerpt prompt budget
local CANDIDATES_REQUESTED = 5
local MAX_NAMING_ATTEMPTS = 20  -- per cluster; each attempt re-samples examples
local FEWSHOT_PAIRS = 2         -- how many good/bad pairs to show per attempt

local LLM_MODEL    = "nomic-embed-text:v1.5"
local NOMIC_PREFIX = "clustering: "  -- same prefix as the rest of the pipeline
local CHAT_MODEL   = "Qwen3-8B"

local ffi = require("ffi")
local fuzz = require("libs/fuzzy-computing")
local dkjson = require("libs/dkjson")
local inference_config = require("libs/inference-server-config")
local generators = require("themes/generators")

-- Issue 030: minimum cosine similarity between a cluster centroid and a
-- generator's style_description embedding for the cluster to map to that
-- generator. Below this, the cluster falls back to `neutral` (and the
-- fallback is logged — should be very rare). 0.3 is intentionally low;
-- the embeddings tend to land in a narrow cosine band and "no good fit"
-- means the generator pool isn't covering the corpus's territory.
local GENERATOR_MATCH_THRESHOLD = 0.3

-- {{{ local function read_uint32_le
local function read_uint32_le(f)
    local b = f:read(4)
    if not b or #b < 4 then return nil end
    return b:byte(1) + b:byte(2) * 256 + b:byte(3) * 65536 + b:byte(4) * 16777216
end
-- }}}

-- {{{ local function load_packed_floats
-- Reads a header-prefixed packed float32 binary (count, dim, then n*dim
-- floats). Returns (n, dim, FFI float buffer).
local function load_packed_floats(path)
    local f = io.open(path, "rb")
    if not f then error("Cannot read " .. path) end
    local n = read_uint32_le(f)
    local dim = read_uint32_le(f)
    local total = n * dim
    local buf = ffi.new("float[?]", total)
    local raw = f:read(total * 4)
    f:close()
    if #raw ~= total * 4 then
        error(string.format("Truncated %s: expected %d bytes, got %d", path, total * 4, #raw))
    end
    ffi.copy(buf, raw, total * 4)
    return n, dim, buf
end
-- }}}

-- {{{ local function cosine_sim_ffi
-- Cosine similarity between two FFI float vectors. Both are assumed
-- unit-normalized (nomic) so this is just a dot product, but we
-- normalize defensively to handle centroids that weren't re-normalized
-- by upstream code.
local function cosine_sim_ffi(a, b, dim, a_off, b_off)
    a_off = a_off or 0
    b_off = b_off or 0
    local dot, mag_a, mag_b = 0, 0, 0
    for d = 0, dim - 1 do
        local av, bv = a[a_off + d], b[b_off + d]
        dot = dot + av * bv
        mag_a = mag_a + av * av
        mag_b = mag_b + bv * bv
    end
    if mag_a == 0 or mag_b == 0 then return 0 end
    return dot / (math.sqrt(mag_a) * math.sqrt(mag_b))
end
-- }}}

-- {{{ local function find_representative_excerpts
-- For one cluster, find the SAMPLE_EXCERPTS_PER_CLUSTER member poems
-- whose embeddings are closest to the cluster centroid. Returns a list
-- of poem indices (sorted by similarity descending).
local function find_representative_excerpts(member_ids, poem_emb, dim, centroid, centroid_offset)
    local scored = {}
    for _, pid in ipairs(member_ids) do
        local sim = cosine_sim_ffi(poem_emb, centroid, dim, pid * dim, centroid_offset)
        table.insert(scored, {pid = pid, sim = sim})
    end
    table.sort(scored, function(a, b) return a.sim > b.sim end)
    local out = {}
    for i = 1, math.min(SAMPLE_EXCERPTS_PER_CLUSTER, #scored) do
        out[i] = scored[i].pid
    end
    return out
end
-- }}}

-- {{{ GOOD_EXAMPLES / BAD_EXAMPLES
-- Pool of correctly-formatted responses, taken from the project's
-- original hand-written theme set. Each entry is exactly what we want
-- the model to emit: CANDIDATES_REQUESTED bare snake_case names,
-- newline-separated, no preamble, no decoration.
local GOOD_EXAMPLES = {
    "anarchist_theory\ndigital_loneliness\nmutual_aid\nprogramming_philosophy\ngender_fluidity",
    "neurodivergence\ntrans_experience\nfragmented_consciousness\nplural_systems\nintimate_relationships",
    "economic_systems\nsocial_organization\ntechnical_architecture\nonline_communities\nlocal_organizing",
    "mental_overflow\nsystem_glitches\ndigital_chaos\nspiritual_technology\ncosmic_consciousness",
    "mystical_practice\nresource_scarcity\nmutual_aid_practice\nsurvival_preparation\ncreative_process",
    "generative_art\nartistic_expression\ntechnical_creativity\ncollaborative_creation\ndigital_art",
    "music_creation\nwriting_craft\ndesign_thinking\nmaker_culture\naesthetic_philosophy",
    "ai_consciousness\ninfrastructure_critique\nsocial_media_fatigue\ngeographic_isolation\nemotional_walls",
    "autistic_masking\nwitch_identity\ndirect_action\nelectoral_critique\nresistance_organizing",
    "queer_identity\nsacred_geometry\nasynchronous_communication\nphysical_craft\nfederated_networks",
}

-- Pool of incorrectly-formatted responses spanning the typical Qwen3
-- failure modes seen in earlier runs: preamble, numbering, code fences,
-- explanations, JSON, refusals, formatting inconsistencies. The model
-- is shown these as "bad" so it can contrast them against the good
-- examples and infer the format target.
local BAD_EXAMPLES = {
    -- numbered list
    "1. anarchist_theory\n2. digital_loneliness\n3. mutual_aid\n4. programming_philosophy\n5. gender_fluidity",
    -- bulleted list
    "- anarchist_theory\n- digital_loneliness\n- mutual_aid\n- programming_philosophy\n- gender_fluidity",
    -- JSON array
    '["anarchist_theory", "digital_loneliness", "mutual_aid", "programming_philosophy", "gender_fluidity"]',
    -- chatty preamble + good content
    "Sure! Here are 5 theme names that fit this cluster:\n\nanarchist_theory\ndigital_loneliness\nmutual_aid\nprogramming_philosophy\ngender_fluidity",
    -- code fence wrapper
    "```\nanarchist_theory\ndigital_loneliness\nmutual_aid\nprogramming_philosophy\ngender_fluidity\n```",
    -- per-name justifications
    "anarchist_theory (politics)\ndigital_loneliness (isolation in online spaces)\nmutual_aid (community care)\nprogramming_philosophy (code as practice)\ngender_fluidity (identity)",
    -- PascalCase instead of snake_case
    "AnarchistTheory\nDigitalLoneliness\nMutualAid\nProgrammingPhilosophy\nGenderFluidity",
    -- spaces instead of underscores
    "anarchist theory\ndigital loneliness\nmutual aid\nprogramming philosophy\ngender fluidity",
    -- refusal
    "I'm sorry, I cannot help name a cluster without more context. Please provide additional information about the poems.",
    -- mixed valid lines with stray commentary
    "anarchist_theory\nThis cluster seems to be about politics.\ndigital_loneliness\nMany poems express isolation.\nmutual_aid",
}
-- }}}

-- {{{ local function build_excerpt_block
-- Just the per-cluster context (top words + sample excerpts). Pulled
-- into its own helper because it's identical across retries — only the
-- example pool selection changes per attempt.
local function build_excerpt_block(top_words, excerpts, texts)
    local word_list = {}
    for _, entry in ipairs(top_words) do
        table.insert(word_list, entry.word)
    end
    local sample_block = {}
    for i, pid in ipairs(excerpts) do
        local t = texts[pid + 1] or ""
        t = t:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        if #t > EXCERPT_CHARS then t = t:sub(1, EXCERPT_CHARS) .. "…" end
        table.insert(sample_block, string.format("  %d. %s", i, t))
    end
    return table.concat(word_list, ", "), table.concat(sample_block, "\n")
end
-- }}}

-- {{{ local function build_prompt
-- Constructs the user-message content for the LLM. Structure:
--   1. /no_think (Qwen3 control to skip the internal reasoning block)
--   2. Task description + the cluster's distinctive context.
--   3. FEWSHOT_PAIRS alternating "Good response: X / Bad response: Y"
--      pairs, randomly sampled from the example pools.
--   4. A final "Here is a good response:" trigger that primes the
--      model to complete in the good pattern.
--
-- Each call samples fresh randomness so retries get different example
-- sets — the model gets a different "launch trajectory" to glide along
-- when a previous attempt failed to produce parseable output.
local function build_prompt(top_words, excerpts, texts, attempt_seed)
    local rng = (math.random) and math.random or function() return 0 end
    -- Reseed once per attempt so we sample a fresh pair of examples.
    if attempt_seed then math.randomseed(attempt_seed) end

    local word_str, excerpt_str = build_excerpt_block(top_words, excerpts, texts)

    -- Sample without replacement so a single attempt never shows the
    -- same good (or bad) example twice — maximizes the diversity the
    -- model sees per prompt and across retries.
    local function shuffled_indices(n)
        local idx = {}
        for i = 1, n do idx[i] = i end
        for i = n, 2, -1 do
            local j = rng(i)
            idx[i], idx[j] = idx[j], idx[i]
        end
        return idx
    end
    local good_pick = shuffled_indices(#GOOD_EXAMPLES)
    local bad_pick  = shuffled_indices(#BAD_EXAMPLES)

    local parts = {
        "/no_think",
        "You are naming a cluster of poems that share a theme.",
        "",
        "Top distinctive words in the cluster:",
        word_str,
        "",
        "Three representative excerpts:",
        excerpt_str,
        "",
        string.format(
            "Propose %d short snake_case theme names. Each name: lowercase, 1-3 words joined by underscores, no punctuation, no quotes. Output ONLY the names, one per line. No preamble, no numbering, no bullets, no commentary, no code fences, no JSON, nothing else.",
            CANDIDATES_REQUESTED),
        "",
        "Examples of good and bad response formats follow. Pay attention to the pattern.",
        "",
    }

    for pair_idx = 1, FEWSHOT_PAIRS do
        local good = GOOD_EXAMPLES[good_pick[pair_idx]]
        local bad  = BAD_EXAMPLES[bad_pick[pair_idx]]
        table.insert(parts, "Good response:")
        table.insert(parts, good)
        table.insert(parts, "")
        table.insert(parts, "Bad response:")
        table.insert(parts, bad)
        table.insert(parts, "")
    end

    table.insert(parts, "Here is a good response for the cluster described at the top:")

    return table.concat(parts, "\n")
end
-- }}}
-- }}}

-- {{{ local function chat_completion
-- Posts a chat-completion request to the Qwen3 endpoint and returns
-- the raw response text. Uses curl via io.popen so we don't take an
-- extra dependency on luasocket here. Same pattern as the existing
-- chat callers in src/web-server.lua.
local function chat_completion(prompt)
    local endpoint = inference_config.CHAT_ENDPOINT .. "/v1/chat/completions"
    -- 150 tokens: 5 newline-separated snake_case names average ~25
    -- tokens. The cap exists so a runaway model (preamble paragraph,
    -- looping repetition) can't burn unbounded server time per
    -- cluster; the retry loop above us re-attempts on parse failure.
    local body = dkjson.encode({
        model = CHAT_MODEL,
        messages = {{role = "user", content = prompt}},
        temperature = 0.7,
        max_tokens = 150,
    })

    -- Hand the body to curl via a temporary file. inline -d with shell
    -- quoting is fragile when the body contains backticks, quotes,
    -- newlines — all of which the prompt does.
    local tmp_path = os.tmpname()
    local tf = io.open(tmp_path, "w")
    tf:write(body)
    tf:close()

    local cmd = string.format(
        "curl --silent --max-time 60 -X POST -H 'Content-Type: application/json' -d @%s '%s'",
        tmp_path, endpoint)
    local p = io.popen(cmd, "r")
    if not p then error("curl popen failed") end
    local response = p:read("*a")
    p:close()
    os.remove(tmp_path)

    if not response or response == "" then
        error("Empty response from chat endpoint " .. endpoint .. " — is Qwen3 server running?")
    end

    local decoded, _, err = dkjson.decode(response)
    if not decoded then
        error("Chat response not valid JSON: " .. tostring(err) .. "\nRaw: " .. response:sub(1, 300))
    end
    if decoded.error then
        error("Chat endpoint returned error: " .. dkjson.encode(decoded.error))
    end
    local content = decoded.choices and decoded.choices[1]
        and decoded.choices[1].message and decoded.choices[1].message.content
    if not content then
        error("Chat response missing message content: " .. response:sub(1, 300))
    end
    return content
end
-- }}}

-- {{{ local function parse_candidates
-- Splits the LLM response into candidate names. Tolerates numbered
-- lists ("1. anarchist_theory"), bullet points ("- foo"), code fences,
-- and stray empty lines. Lowercases, strips non-[a-z0-9_] characters
-- (collapses to underscores), drops anything that ends up too short or
-- too long to be a usable theme name.
local function parse_candidates(text)
    local names = {}
    for line in text:gmatch("[^\r\n]+") do
        -- Strip leading numbering / bullets / whitespace / code fences.
        local cleaned = line:gsub("^%s*", "")
                            :gsub("^%d+%.%s*", "")
                            :gsub("^%-+%s*", "")
                            :gsub("^%*+%s*", "")
                            :gsub("^`+", "")
                            :gsub("`+$", "")
                            :gsub("^['\"]", "")
                            :gsub("['\"]$", "")
                            :lower()
        -- Replace remaining non-alphanumeric runs with single underscore.
        cleaned = cleaned:gsub("[^a-z0-9_]+", "_"):gsub("^_+", ""):gsub("_+$", "")
        if #cleaned >= 3 and #cleaned <= 40 then
            table.insert(names, cleaned)
        end
    end
    -- Dedupe while preserving order.
    local seen, unique = {}, {}
    for _, n in ipairs(names) do
        if not seen[n] then
            seen[n] = true
            table.insert(unique, n)
        end
    end
    return unique
end
-- }}}

-- {{{ local function pick_best_candidate
-- For each candidate name, embed it via nomic, compute cosine to the
-- cluster centroid, return the highest-scoring (name, score) pair.
local function pick_best_candidate(candidates, centroid_buf, centroid_offset, dim)
    local best_name, best_score = nil, -2
    for _, name in ipairs(candidates) do
        local emb = fuzz.get_embedding(name, LLM_MODEL, NOMIC_PREFIX)
        if type(emb) == "table" then
            local emb_buf = ffi.new("float[?]", dim)
            for d = 1, dim do emb_buf[d - 1] = emb[d] end
            local sim = cosine_sim_ffi(emb_buf, centroid_buf, dim, 0, centroid_offset)
            if sim > best_score then
                best_score = sim
                best_name = name
            end
        end
    end
    return best_name, best_score
end
-- }}}

-- {{{ local function build_description
-- Synthesizes a one-line theme description from the cluster's top TF-IDF
-- words. Used by the runtime to give the operator something readable in
-- progress_ui.log lines (the centroid itself is opaque). Same style as
-- the old hand-written tier descriptions: "Description sentence. Words,
-- comma-separated."
local function build_description(top_words)
    local list = {}
    for _, entry in ipairs(top_words) do table.insert(list, entry.word) end
    return string.format(
        "Cluster characterized by these distinctive words: %s.",
        table.concat(list, ", "))
end
-- }}}

-- {{{ local function vec_to_ffi
-- Convert a Lua array of floats into an FFI float buffer for fast cosine
-- math against the other FFI buffers loaded elsewhere in this script.
local function vec_to_ffi(t, dim)
    local buf = ffi.new("float[?]", dim)
    for d = 1, dim do buf[d - 1] = t[d] end
    return buf
end
-- }}}

-- {{{ local function embed_axis
-- Computes axis_vector = normalize(embed(high_words) - embed(low_words))
-- for one parameter. Returns a Lua array of `dim` floats. Each axis is
-- computed once per (generator, parameter) pair and reused across every
-- cluster that maps to that generator.
--
-- Both embedding calls go through fuzz.get_embedding so the cache picks
-- them up — re-running themes-rebuild after a generators.lua tweak only
-- pays the embedding cost for the words that actually changed.
local function embed_axis(low_words, high_words, dim)
    if not low_words or not high_words or low_words == "" or high_words == "" then
        return nil  -- parameter is degenerate (e.g. neutral has no params)
    end
    local low  = fuzz.get_embedding(low_words,  LLM_MODEL, NOMIC_PREFIX)
    local high = fuzz.get_embedding(high_words, LLM_MODEL, NOMIC_PREFIX)
    local axis = {}
    local mag = 0
    for d = 1, dim do
        axis[d] = high[d] - low[d]
        mag = mag + axis[d] * axis[d]
    end
    mag = math.sqrt(mag)
    if mag == 0 then return nil end
    for d = 1, dim do axis[d] = axis[d] / mag end
    return axis
end
-- }}}

-- {{{ local function precompute_generator_metadata
-- Walks one tier's generator registry, embedding each style_description
-- and each parameter's low_words/high_words. Returns:
--   { [name] = {
--       style_embedding = {.. dim floats ..},
--       style_embedding_ffi = ffi.new buffer (for fast cosine),
--       parameter_axes = {
--         {name, min, max, axis = {.. dim floats ..}}, ...
--       },
--     }, ... }
-- Logs progress per generator so the operator sees what's happening.
local function precompute_generator_metadata(tier_name, registry, dim)
    print(string.format("\n🔧 Embedding %s generator metadata (style + parameter axes)", tier_name))
    local meta = {}
    local total_axes = 0
    for name, entry in pairs(registry) do
        local style_emb = fuzz.get_embedding(entry.style_description, LLM_MODEL, NOMIC_PREFIX)
        local axes = {}
        for _, p in ipairs(entry.parameters or {}) do
            local axis = embed_axis(p.low_words, p.high_words, dim)
            if axis then
                table.insert(axes, {
                    name = p.name,
                    min = p.min,
                    max = p.max,
                    axis = axis,
                })
                total_axes = total_axes + 1
            end
        end
        meta[name] = {
            style_embedding = style_emb,
            style_embedding_ffi = vec_to_ffi(style_emb, dim),
            parameter_axes = axes,
        }
        print(string.format("    ✓ %-15s style + %d axes", name, #axes))
    end
    print(string.format("  → %d generators, %d total parameter axes embedded",
        select(2, (function() local n=0; for _ in pairs(meta) do n=n+1 end; return nil,n end)()),
        total_axes))
    return meta
end
-- }}}

-- {{{ local function find_best_generator
-- For one cluster centroid, finds the generator whose style_description
-- embedding has the highest cosine similarity to the centroid. Returns
-- (name, similarity). If the best match is below GENERATOR_MATCH_THRESHOLD,
-- returns ("neutral", similarity) instead and logs a warning — that's
-- the signal the generator pool isn't broad enough to cover this cluster.
local function find_best_generator(cent_buf, centroid_offset, dim, generator_meta)
    local best_name, best_sim = nil, -2
    for name, info in pairs(generator_meta) do
        local sim = cosine_sim_ffi(cent_buf, info.style_embedding_ffi, dim, centroid_offset, 0)
        if sim > best_sim then
            best_sim = sim
            best_name = name
        end
    end
    if best_sim < GENERATOR_MATCH_THRESHOLD then
        print(string.format(
            "    ⚠ best generator %s only at sim %.3f (< %.2f threshold) — falling back to neutral",
            best_name, best_sim, GENERATOR_MATCH_THRESHOLD))
        return "neutral", best_sim
    end
    return best_name, best_sim
end
-- }}}

-- {{{ local function write_axes_block
-- Serializes one cluster's tier_N_parameter_axes table into the
-- derived-taxonomy.lua output. Each axis is a 768-float Lua table
-- written compactly on a single line per axis. Empty list writes "{}".
local function write_axes_block(out, axes)
    if not axes or #axes == 0 then
        out:write("{},\n")
        return
    end
    out:write("{\n")
    for _, a in ipairs(axes) do
        out:write(string.format(
            "        {name = %q, min = %g, max = %g, axis = {",
            a.name, a.min, a.max))
        for d, v in ipairs(a.axis) do
            if d > 1 then out:write(",") end
            out:write(string.format("%.7g", v))
        end
        out:write("}},\n")
    end
    out:write("      },\n")
end
-- }}}

-- {{{ local function main
local function main()
    print("📖 Loading clusters: " .. INPUT_CLUSTERS)
    local clusters_data = dofile(INPUT_CLUSTERS)
    print(string.format("    %d clusters", #clusters_data.clusters))

    print("📖 Loading TF-IDF: " .. INPUT_TFIDF)
    local tfidf_data = dofile(INPUT_TFIDF)

    print("📖 Loading poem texts: " .. INPUT_TEXTS)
    local texts = dofile(INPUT_TEXTS)

    print("📦 Loading poem embeddings: " .. INPUT_POEMS_BIN)
    local n_poems, poem_dim, poem_emb = load_packed_floats(INPUT_POEMS_BIN)
    print(string.format("    %d poems × %d dim", n_poems, poem_dim))

    print("📦 Loading cluster centroids: " .. INPUT_CENTROIDS_BIN)
    local n_clusters, cent_dim, cent_buf = load_packed_floats(INPUT_CENTROIDS_BIN)
    if cent_dim ~= poem_dim then
        error(string.format(
            "Dimension mismatch: poems are %d-dim, centroids are %d-dim",
            poem_dim, cent_dim))
    end
    if n_clusters ~= #clusters_data.clusters then
        error(string.format(
            "Cluster count mismatch: clusters.lua has %d, centroids.bin has %d",
            #clusters_data.clusters, n_clusters))
    end

    -- Issue 030 Phase 2: pre-embed generator style descriptions and
    -- parameter axes once. Each cluster will pick the closest generator
    -- by cosine similarity between its centroid and the generator's
    -- style embedding, then inherit that generator's parameter axes.
    local tier1_meta = precompute_generator_metadata("Tier 1", generators.tier1, cent_dim)
    local tier2_meta = precompute_generator_metadata("Tier 2", generators.tier2, cent_dim)

    -- Make sure output directory exists. themes/ already does in
    -- practice (palette.lua lives there), but defensive.
    os.execute("mkdir -p " .. DIR .. "/themes")

    print("\n📝 Writing " .. OUTPUT_TAXONOMY)
    local out = io.open(OUTPUT_TAXONOMY, "w")
    if not out then error("Cannot write " .. OUTPUT_TAXONOMY) end
    out:write("-- Generated by themes-v2/name-clusters.lua (issues 029 + 030).\n")
    out:write("-- Loaded at runtime by compile-pdf-ai.lua in place of hard-coded\n")
    out:write("-- tier1/2/3_descriptions tables. Centroids are stored so the\n")
    out:write("-- runtime can skip re-embedding theme descriptions at startup.\n")
    out:write("-- Issue 030 schema additions:\n")
    out:write("--   tier1_generator   : name of best-matching generator from themes/generators.lua\n")
    out:write("--   tier1_parameter_axes : list of {name, min, max, axis = {dim floats}} for that generator\n")
    out:write("--   tier2_generator / tier2_parameter_axes : same for Tier 2 (currently stub-mapped)\n")
    out:write("return {\n")
    out:write(string.format("  embedding_dim = %d,\n", cent_dim))
    out:write(string.format("  cluster_count = %d,\n", n_clusters))
    out:write(string.format("  noise_count = %d,\n", clusters_data.noise_count))
    out:write("  themes = {\n")

    local seen_names = {}
    for i, cluster in ipairs(clusters_data.clusters) do
        local centroid_offset = (i - 1) * cent_dim
        local top_words = tfidf_data[cluster.id] or {}
        local excerpts = find_representative_excerpts(
            cluster.member_ids, poem_emb, poem_dim, cent_buf, centroid_offset)

        print(string.format("\n  cluster %d (%d poems):", cluster.id, cluster.member_count))
        print(string.format("    top words: %s",
            table.concat((function()
                local w = {}
                for j = 1, math.min(8, #top_words) do
                    table.insert(w, top_words[j].word)
                end
                return w
            end)(), ", ")))

        -- Retry-until-success: each attempt uses a fresh seed so the
        -- few-shot example pool is resampled, giving the model a
        -- different trajectory to complete from. Failures are not
        -- fallback-eligible — there's always a valid response available,
        -- the question is only whether this particular sampling found
        -- one. Hard-error only if MAX_NAMING_ATTEMPTS consecutive
        -- attempts all fail to parse.
        local candidates = {}
        local last_response = ""
        local attempts_used = 0
        for attempt = 1, MAX_NAMING_ATTEMPTS do
            attempts_used = attempt
            local prompt = build_prompt(
                top_words, excerpts, texts,
                cluster.id * 1000 + attempt)
            local response = chat_completion(prompt)
            last_response = response
            candidates = parse_candidates(response)
            if #candidates > 0 then break end
            if attempt < MAX_NAMING_ATTEMPTS then
                print(string.format(
                    "    ↻ attempt %d returned nothing parseable, retrying with fresh examples",
                    attempt))
            end
        end
        print(string.format("    candidates (after %d attempt%s): %s",
            attempts_used, attempts_used == 1 and "" or "s",
            table.concat(candidates, ", ")))

        if #candidates == 0 then
            error(string.format(
                "Cluster %d: no parseable response from Qwen3 after %d attempts. Last raw response:\n%s",
                cluster.id, MAX_NAMING_ATTEMPTS, last_response))
        end

        local best_name, best_score = pick_best_candidate(
            candidates, cent_buf, centroid_offset, cent_dim)
        -- Disambiguate name collisions: append _2, _3, ... if a previous
        -- cluster already claimed this name. Centroids will still differ
        -- (different clusters), so the runtime can tell them apart by
        -- cluster_id even though the human-readable name is suffixed.
        local final_name = best_name
        local suffix = 2
        while seen_names[final_name] do
            final_name = best_name .. "_" .. suffix
            suffix = suffix + 1
        end
        seen_names[final_name] = true
        print(string.format("    ✅ chose: %s (centroid sim %.3f)", final_name, best_score))

        -- Issue 030 Phase 2: cluster→generator mapping per tier.
        -- Tier 1 is the substantive one (22 candidate generators).
        -- Tier 2 currently has only the stub "default" generator, so the
        -- match is trivial; the schema is still populated so downstream
        -- consumers can rely on tier2_generator existing.
        local tier1_gen, tier1_gen_sim = find_best_generator(
            cent_buf, centroid_offset, cent_dim, tier1_meta)
        local tier2_gen = find_best_generator(
            cent_buf, centroid_offset, cent_dim, tier2_meta)
        print(string.format("    🎨 tier1 generator: %s (sim %.3f)",
            tier1_gen, tier1_gen_sim))

        local description = build_description(top_words)
        out:write(string.format("    {\n      id = %d,\n      name = %q,\n",
            cluster.id, final_name))
        out:write(string.format("      description = %q,\n", description))
        out:write(string.format("      member_count = %d,\n", cluster.member_count))
        out:write("      top_words = {")
        for j, entry in ipairs(top_words) do
            if j > 1 then out:write(", ") end
            out:write(string.format("%q", entry.word))
        end
        out:write("},\n")
        -- Generator mapping + axes per tier. Each axis is a 768-float
        -- vector that the runtime projects poem embeddings onto.
        out:write(string.format("      tier1_generator = %q,\n", tier1_gen))
        out:write("      tier1_parameter_axes = ")
        write_axes_block(out, tier1_meta[tier1_gen].parameter_axes)
        out:write(string.format("      tier2_generator = %q,\n", tier2_gen))
        out:write("      tier2_parameter_axes = ")
        write_axes_block(out, tier2_meta[tier2_gen].parameter_axes)
        -- Centroid: 768 floats. Written compact, one per line would
        -- balloon the file. The runtime parses this back into a Lua
        -- table; FFI conversion happens on the consumer side.
        out:write("      centroid = {")
        for d = 0, cent_dim - 1 do
            if d > 0 then out:write(",") end
            out:write(string.format("%.7g", cent_buf[centroid_offset + d]))
        end
        out:write("},\n")
        out:write("    },\n")
        out:flush()  -- guard against mid-run server hiccup; partial file is recoverable
    end
    out:write("  },\n}\n")
    out:close()
    print("\n✅ Wrote " .. OUTPUT_TAXONOMY)
end
-- }}}

main()
