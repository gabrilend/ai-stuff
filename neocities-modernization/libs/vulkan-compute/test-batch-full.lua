#!/usr/bin/env luajit
-- test-batch-full.lua - Test batch diversity sequence generation with full dataset
--
-- This script tests the GPU-accelerated batch parallel diversity sequence
-- generation on the complete dataset of 7,797 poems. Expected runtime: 20-30 seconds.

local ffi = require("ffi")

-- {{{ Load dependencies
-- Set library path for vk_compute to find the shared library
_G.VK_COMPUTE_LIB = "./build/libvkcompute.so"

-- Add library paths
package.path = package.path .. ";./lua/?.lua;./?/init.lua"
package.path = package.path .. ";/home/ritz/programming/ai-stuff/libs/lua/?.lua"

local vk = require("vk_compute")

-- Load JSON library
local json = require("dkjson")
-- }}}

-- {{{ Configuration
local EMBEDDINGS_FILE = "/home/ritz/programming/ai-stuff/neocities-modernization/assets/embeddings/embeddinggemma_latest/embeddings.json"
local OUTPUT_FILE = "/home/ritz/programming/ai-stuff/neocities-modernization/output/diversity-cache-gpu-batch.bin"
local NUM_POEMS = 7797
local EMBEDDING_DIM = 768
local BATCH_SIZE = 3584  -- Optimal for GTX 1080 Ti

-- Parse command line arguments
local DEBUG = false
for i = 1, #arg do
    if arg[i] == "--debug" then
        DEBUG = true
    end
end

local function debug_print(...)
    if DEBUG then
        print(string.format("[DEBUG] %s", string.format(...)))
        io.stdout:flush()
    end
end
-- }}}

-- {{{ local function load_embeddings()
-- Load embeddings from JSON file
local function load_embeddings(filepath)
    print(string.format("[Loading] Reading embeddings from: %s", filepath))
    debug_print("Opening file...")

    local f = io.open(filepath, "rb")
    if not f then
        error("Failed to open embeddings file: " .. filepath)
    end

    debug_print("Reading file contents...")
    local content = f:read("*all")
    f:close()
    debug_print("Read %d bytes", #content)

    debug_print("Decoding JSON...")
    local data = json.decode(content)
    debug_print("JSON decoded successfully")

    if not data.embeddings then
        error("Invalid embeddings file format: missing 'embeddings' field")
    end

    -- Convert to flat array format expected by GPU
    -- JSON structure: { metadata: {...}, embeddings: [{poem_index, id, embedding: [...]}, ...] }
    debug_print("Converting to flat array format...")
    local embeddings = {}
    local idx = 1

    -- Sort by poem_index to ensure correct order
    debug_print("Sorting %d embeddings by poem_index...", #data.embeddings)
    table.sort(data.embeddings, function(a, b)
        return a.poem_index < b.poem_index
    end)
    debug_print("Sort complete")

    for i, poem_data in ipairs(data.embeddings) do
        local embedding = poem_data.embedding

        if not embedding then
            error(string.format("Missing embedding for poem index %d", poem_data.poem_index))
        end

        if #embedding ~= EMBEDDING_DIM then
            error(string.format("Poem index %d has wrong embedding dimension: %d (expected %d)",
                              poem_data.poem_index, #embedding, EMBEDDING_DIM))
        end

        for j = 1, EMBEDDING_DIM do
            embeddings[idx] = embedding[j]
            idx = idx + 1
        end
    end

    local actual_poems = #data.embeddings
    print(string.format("[Loading] Loaded %d embeddings (%d floats total)",
                       actual_poems, #embeddings))

    if actual_poems ~= NUM_POEMS then
        print(string.format("[Warning] Expected %d poems but found %d", NUM_POEMS, actual_poems))
    end

    return embeddings
end
-- }}}

-- {{{ local function main()
local function main()
    print("=" .. string.rep("=", 78))
    print("  Batch Parallel Diversity Sequence Generation - Full Dataset Test")
    print("=" .. string.rep("=", 78))
    if DEBUG then
        print("  [DEBUG MODE ENABLED]")
    end
    print()

    -- Load embeddings
    debug_print("Starting load_embeddings()")
    local embeddings = load_embeddings(EMBEDDINGS_FILE)
    debug_print("Embeddings loaded, table size: %d", #embeddings)

    -- Initialize Vulkan
    print("\n[Vulkan] Initializing compute context...")
    debug_print("Calling vk.init(false)")
    local ctx = vk.init(false)  -- disable validation layers for performance
    debug_print("vk.init() returned: %s", tostring(ctx))

    if not ctx then
        error("Failed to initialize Vulkan context")
    end

    print()
    print("[Batch] Starting batch parallel computation...")
    print(string.format("  Poems: %d", NUM_POEMS))
    print(string.format("  Embedding Dim: %d", EMBEDDING_DIM))
    print(string.format("  Batch Size: %d", BATCH_SIZE))
    print(string.format("  Expected Time: 20-30 seconds"))
    print(string.format("  Output: %s", OUTPUT_FILE))
    print()

    local start_time = os.clock()
    debug_print("Starting batch processing at time %.3f", start_time)

    -- Run batch processing
    debug_print("Calling compute_all_diversity_sequences_batched()")
    local sequences = vk.compute_all_diversity_sequences_batched(
        ctx,
        embeddings,
        NUM_POEMS,
        EMBEDDING_DIM,
        OUTPUT_FILE,
        BATCH_SIZE
    )
    debug_print("Batch processing returned")

    local elapsed = os.clock() - start_time

    print()
    print("=" .. string.rep("=", 78))
    print("  Results")
    print("=" .. string.rep("=", 78))
    print(string.format("  Total Time: %.2f seconds", elapsed))
    print(string.format("  Sequences Generated: %d", NUM_POEMS))
    print(string.format("  Average Time per Sequence: %.4f seconds", elapsed / NUM_POEMS))
    print(string.format("  Output File: %s", OUTPUT_FILE))
    print()

    -- Validate first sequence
    if sequences and sequences[0] then
        print("  First sequence (poem 0):")
        local seq = sequences[0]
        print(string.format("    First 10 poems: %s",
                          table.concat({seq[1], seq[2], seq[3], seq[4], seq[5],
                                      seq[6], seq[7], seq[8], seq[9], seq[10]}, ", ")))
        print(string.format("    Length: %d", #seq))
    end

    print()
    print("[SUCCESS] Batch processing completed successfully!")
    print()

    -- Cleanup
    vk.shutdown(ctx)
end
-- }}}

-- Run main with error handling
local success, err = pcall(main)
if not success then
    print("\n[ERROR] " .. tostring(err))
    os.exit(1)
end
