-- themes-v2/load-poem-embeddings.lua
-- Issue 029, slice 1: collect every poem's embedding into one packed
-- binary file the HDBSCAN step can mmap (well, fread) without thousands
-- of dofile calls per run. Also emits a parallel text lookup so the
-- TF-IDF and naming steps can find each poem by index.
--
-- The embedding cache (libs/fuzzy-computing.lua, tmp/embeddings/) is
-- NOT authoritative for whole-poem texts. The runtime's PDF generator
-- ends up embedding per-page-segment text — long poems get split across
-- pages, and each split segment is embedded under its own cache key.
-- For corpus-level clustering we want whole-poem semantics, which
-- typically means embedding ~75% of poems fresh. The pipeline therefore
-- relies on libs/fuzzy-computing.lua's get_embedding, which uses the
-- cache when available and posts to the llama-server embedding endpoint
-- on miss (auto-writing the result back to the cache for future runs).
--
-- REQUIREMENT: scripts/start-llamacpp-server.sh --background must be
-- running before this script. If the embedding server is down, fresh
-- embeddings hard-error and the pipeline stops.
--
-- Run with:
--   luajit themes-v2/load-poem-embeddings.lua [DIR]
-- DIR defaults to the canonical project path; pass an alternate path to
-- target a different project root.

local DIR = "/home/ritz/programming/ai-stuff/words-pdf"
if arg[1] and arg[1] ~= "" then DIR = arg[1] end

-- Wire package paths so libs/fuzzy-computing.lua and its dependencies
-- resolve regardless of where luajit is invoked from.
package.path = package.path .. ";" .. DIR .. "/?.lua;" .. DIR .. "/libs/?.lua"
package.cpath = package.cpath .. ";" .. DIR .. "/libs/luahpdf/?.so"

local INPUT_FILE  = DIR .. "/tmp/compiled-cleaned.txt"
local OUTPUT_BIN  = DIR .. "/tmp/poem-embeddings.bin"
local OUTPUT_TEXT = DIR .. "/tmp/poem-texts.lua"

local LLM_MODEL    = "nomic-embed-text:v1.5"
local NOMIC_PREFIX = "clustering: "
local EMBEDDING_DIM = 768

local DELIMITER = string.rep("-", 80)
local MIN_POEM_CHARS = 10  -- matches analyze_individual_poem_for_tier2's filter

local ffi = require("ffi")
local fuzz = require("libs/fuzzy-computing")

-- {{{ local function djb2_hash
-- Verbatim copy of libs/fuzzy-computing.lua:djb2_hash, kept inline so
-- we can probe the cache for hit/miss telemetry without poking at
-- fuzz's internals (it doesn't expose the hash, and the probe is
-- informational — get_embedding handles real lookups).
local function djb2_hash(s)
    local hash = 5381
    for i = 1, #s do
        hash = (hash * 33 + s:byte(i)) % 2147483648
    end
    return hash
end
local function cache_probe_path(text)
    return string.format(
        "%s/tmp/embeddings/%08x.lua",
        DIR, djb2_hash(LLM_MODEL .. "\0" .. NOMIC_PREFIX .. text))
end
-- }}}

-- {{{ local function detect_poem_type
-- Verbatim copy of compile-pdf-ai.lua:detect_poem_type. Drives which
-- branch of normalize_poem_spacing runs, which in turn determines the
-- exact joined-text string the runtime would have embedded.
local function detect_poem_type(poem)
    if #poem == 0 then return "unknown" end
    local has_fediverse = false
    local has_cw = false
    for _, line in ipairs(poem) do
        if line:match("fediverse/") then
            has_fediverse = true
        elseif line:match("^CW:") then
            has_cw = true
        end
    end
    if has_fediverse and has_cw then return "fediverse_with_cw"
    elseif has_fediverse        then return "fediverse_no_cw"
    else                              return "messages_notes" end
end
-- }}}

-- {{{ local function normalize_poem_spacing
-- Verbatim copy of compile-pdf-ai.lua:normalize_poem_spacing. The runtime
-- normalizes every poem BEFORE embedding, so the cache key is based on
-- the normalized text — not the raw delimiter-split chunk. Replicating
-- the normalization here is the only way to recover the same cache key.
local function normalize_poem_spacing(poem)
    if #poem == 0 then return poem end
    local result = {}
    local poem_type = detect_poem_type(poem)

    if poem_type == "fediverse_with_cw" then
        local cw_line = ""
        local content_start = 1
        for i, line in ipairs(poem) do
            if line:match("^CW:") then
                cw_line = line
                content_start = i + 1
                break
            end
        end
        if cw_line ~= "" then
            table.insert(result, cw_line)
            table.insert(result, "")
        end
        local content_found = false
        for i = content_start, #poem do
            local line = poem[i]
            if line ~= "" or content_found then
                table.insert(result, line)
                if line ~= "" then content_found = true end
            end
        end
    else
        -- fediverse_no_cw and messages_notes both strip leading blanks.
        local content_found = false
        for _, line in ipairs(poem) do
            if line ~= "" or content_found then
                table.insert(result, line)
                if line ~= "" then content_found = true end
            end
        end
    end

    return result
end
-- }}}

-- {{{ local function split_poems
-- Same delimiter-based splitter as compile-pdf-ai.lua:load_file. Returns
-- a flat list of poem-line-lists (one per delimiter-bounded segment).
local function split_poems(path)
    local f = io.open(path, "r")
    if not f then
        error("Cannot open input file " .. path
            .. "\nDid ./run finish at least once to populate tmp/compiled-cleaned.txt?")
    end
    local poems, current = {}, {}
    for line in f:lines() do
        if line == DELIMITER then
            table.insert(poems, current)
            current = {}
        else
            table.insert(current, line)
        end
    end
    -- Note: load_file does NOT flush the trailing buffer if the file
    -- ends without a delimiter. The cleaned input ends with one, so the
    -- last `current` is always empty by the time the loop exits. We
    -- mirror that behavior — anything tacked on the end without a
    -- trailing delimiter would NOT have been embedded by the runtime
    -- and therefore would NOT be in the cache.
    f:close()
    return poems
end
-- }}}

-- {{{ local function write_uint32_le
local function write_uint32_le(file, n)
    file:write(string.char(
        n % 256,
        math.floor(n / 256) % 256,
        math.floor(n / 65536) % 256,
        math.floor(n / 16777216) % 256))
end
-- }}}

-- {{{ local function get_poem_embedding
-- Wraps fuzz.get_embedding with dimension validation. Cache hits return
-- in microseconds; misses post to the llama-server embedding endpoint
-- (which mean-pools chunks for long poems before caching the final
-- vector under the full-text key). A nil return is unexpected — fuzz
-- already hard-errors on server failure — but we double-check rather
-- than write a malformed binary record on the off chance.
local function get_poem_embedding(poem_index, text)
    local emb = fuzz.get_embedding(text, LLM_MODEL, NOMIC_PREFIX)
    if type(emb) ~= "table" then
        error(string.format(
            "get_embedding returned %s for poem %d (text starts %q)\n"
            .. "Likely the embedding server at INFERENCE_EMBEDDING_HOST is down.",
            type(emb), poem_index, text:sub(1, 80)))
    end
    if #emb ~= EMBEDDING_DIM then
        error(string.format(
            "Embedding for poem %d has %d dims, expected %d (text starts %q)",
            poem_index, #emb, EMBEDDING_DIM, text:sub(1, 80)))
    end
    return emb
end
-- }}}

-- {{{ local function main
local function main()
    print("📂 Reading " .. INPUT_FILE)
    local raw_segments = split_poems(INPUT_FILE)
    print(string.format("   split into %d raw segments", #raw_segments))

    -- Normalize and filter to match what the runtime would have embedded.
    -- Poems that wouldn't have been embedded by the runtime are not in
    -- the cache, so including them here would trigger a (false-positive)
    -- miss.
    local kept = {}     -- list of {text, raw_index}
    local skipped_short = 0
    for raw_index, raw_lines in ipairs(raw_segments) do
        local normalized = normalize_poem_spacing(raw_lines)
        local text = table.concat(normalized, " ")
        if #text >= MIN_POEM_CHARS then
            table.insert(kept, {text = text, raw_index = raw_index})
        else
            skipped_short = skipped_short + 1
        end
    end
    print(string.format(
        "   kept %d poems, skipped %d (below %d-char minimum)",
        #kept, skipped_short, MIN_POEM_CHARS))

    -- Open the binary embedding output. Format:
    --   uint32 little-endian: poem count
    --   uint32 little-endian: embedding dim (768)
    --   float32 little-endian * (count * dim): packed embeddings,
    --     poem 0's 768 floats, then poem 1's 768 floats, etc.
    print("\n🧮 Loading embeddings from cache → " .. OUTPUT_BIN)
    local bin = io.open(OUTPUT_BIN, "wb")
    if not bin then
        error("Cannot write " .. OUTPUT_BIN
            .. "\nEnsure tmp/ exists (the ./run script creates it).")
    end
    write_uint32_le(bin, #kept)
    write_uint32_le(bin, EMBEDDING_DIM)

    -- One reusable FFI buffer for the 768 floats of each poem. ffi.string
    -- with an explicit length grabs the raw bytes from the buffer, which
    -- we write directly — no per-float string concatenation, no manual
    -- byte packing, no endian conversion (x86_64 Linux is little-endian
    -- and float32 is the native layout).
    local emb_buf = ffi.new("float[?]", EMBEDDING_DIM)
    local emb_bytes = EMBEDDING_DIM * 4

    -- Track cache hit/miss so the operator can see whether the embedding
    -- server actually got hit (and how hard). We probe the cache directly
    -- before calling get_embedding so the count is accurate; get_embedding
    -- doesn't expose hit/miss telemetry.
    local cache_hits, cache_misses = 0, 0
    local start_time = os.time()

    for i, poem in ipairs(kept) do
        -- Cheap pre-probe to learn whether this call will hit cache.
        -- get_embedding does the same probe internally; double-doing
        -- it is fine, it's a single io.open.
        local probe_f = io.open(cache_probe_path(poem.text), "r")
        if probe_f then
            cache_hits = cache_hits + 1
            probe_f:close()
        else
            cache_misses = cache_misses + 1
        end

        local emb = get_poem_embedding(i, poem.text)
        for d = 1, EMBEDDING_DIM do
            emb_buf[d - 1] = emb[d]
        end
        bin:write(ffi.string(emb_buf, emb_bytes))

        if i % 50 == 0 or i == #kept then
            local elapsed = os.time() - start_time
            io.write(string.format(
                "\r   poem %d/%d (cache: %d hits, %d misses; elapsed %ds)",
                i, #kept, cache_hits, cache_misses, elapsed))
            io.flush()
        end
    end
    io.write("\n")
    bin:close()

    -- Text lookup, same indexing as the binary file: kept[i] is the
    -- i-th poem in both files. Storing as a Lua return-table so the
    -- downstream scripts can just dofile() it.
    print("\n📝 Writing text lookup → " .. OUTPUT_TEXT)
    local txt = io.open(OUTPUT_TEXT, "w")
    if not txt then
        error("Cannot write " .. OUTPUT_TEXT)
    end
    txt:write("-- Generated by themes-v2/load-poem-embeddings.lua (issue 029)\n")
    txt:write("-- Poem text indexed 1..N, same ordering as tmp/poem-embeddings.bin\n")
    txt:write("return {\n")
    for i, poem in ipairs(kept) do
        txt:write(string.format("  [%d] = %q,\n", i, poem.text))
    end
    txt:write("}\n")
    txt:close()

    local total_bytes = 8 + (#kept * emb_bytes)  -- 8-byte header + payload
    print(string.format(
        "\n✅ Wrote %d poems × %d dims to %s (%d bytes)",
        #kept, EMBEDDING_DIM, OUTPUT_BIN, total_bytes))
    print(string.format("✅ Wrote text lookup (%d entries) to %s", #kept, OUTPUT_TEXT))

    local elapsed = os.time() - start_time
    local hit_pct = cache_hits / (cache_hits + cache_misses) * 100
    print(string.format(
        "\n📊 Cache performance: %d hits / %d misses (%.1f%% hit rate) in %d seconds",
        cache_hits, cache_misses, hit_pct, elapsed))
    if cache_misses > 0 then
        print(string.format(
            "   %d fresh embeddings were computed and written to the cache,",
            cache_misses))
        print("   so subsequent runs of this script will be much faster.")
    end
end
-- }}}

main()
