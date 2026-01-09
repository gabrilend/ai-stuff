#!/usr/bin/env luajit
-- test_ffi.lua - Test Lua FFI bindings for Vulkan compute
--
-- This script verifies that the Lua FFI bindings work correctly
-- by computing a small diversity sequence.
--
-- Usage: luajit test_ffi.lua [DIR]
--   DIR - Path to vulkan-compute root directory (default: current directory)

-- {{{ Parse arguments and set up paths
local DIR = arg[1] or "."
package.path = DIR .. "/lua/?.lua;" .. package.path
_G.VK_COMPUTE_LIB = DIR .. "/build/libvkcompute.so"
-- }}}

local vk = require("vk_compute")

print("=== Vulkan Compute Lua FFI Test ===\n")

-- {{{ Test configuration
local NUM_POEMS = 100
local EMBEDDING_DIM = 768
local START_POEM = 0
-- }}}

-- {{{ Generate test embeddings
print("[1] Generating test embeddings...")
local embeddings = {}
math.randomseed(42)

for i = 1, NUM_POEMS do
    for d = 1, EMBEDDING_DIM do
        local base = (i - 1) / NUM_POEMS
        local variation = (math.random() - 0.5) * 0.1
        table.insert(embeddings, base + variation)
    end
end

print(string.format("    Generated %d embeddings (%d dims each)",
                   NUM_POEMS, EMBEDDING_DIM))
-- }}}

-- {{{ Initialize Vulkan
print("\n[2] Initializing Vulkan...")
local ctx = vk.init(false)
print("    Vulkan initialized successfully")
-- }}}

-- {{{ Compute diversity sequence
print(string.format("\n[3] Computing diversity sequence (start: %d)...", START_POEM))
local start_time = os.clock()

local sequence = vk.compute_diversity_sequence(
    ctx, embeddings, NUM_POEMS, EMBEDDING_DIM, START_POEM
)

local elapsed = os.clock() - start_time
print(string.format("    Computed sequence in %.3fs", elapsed))
-- }}}

-- {{{ Verify sequence
print("\n[4] Verifying sequence...")
local valid = true

-- Check sequence length
if #sequence ~= NUM_POEMS then
    print(string.format("    ERROR: Expected %d elements, got %d", NUM_POEMS, #sequence))
    valid = false
end

-- Check that it starts with start_poem
if sequence[1] ~= START_POEM then
    print(string.format("    ERROR: Expected start poem %d, got %d", START_POEM, sequence[1]))
    valid = false
end

-- Check that all poems appear exactly once
local seen = {}
for i = 1, NUM_POEMS do
    local poem_id = sequence[i]
    if seen[poem_id] then
        print(string.format("    ERROR: Duplicate poem ID: %d", poem_id))
        valid = false
        break
    end
    if poem_id < 0 or poem_id >= NUM_POEMS then
        print(string.format("    ERROR: Invalid poem ID: %d", poem_id))
        valid = false
        break
    end
    seen[poem_id] = true
end

if valid then
    print("    [OK] Sequence is valid")
    print("\n    First 10 poems in sequence:")
    for i = 1, math.min(10, NUM_POEMS) do
        print(string.format("      [%d] → poem %d", i - 1, sequence[i]))
    end
else
    print("    [FAILED] Sequence validation failed")
end
-- }}}

-- {{{ Cleanup
print("\n[5] Cleaning up...")
vk.shutdown(ctx)
print("    Vulkan shutdown complete")
-- }}}

-- {{{ Final result
if valid then
    print("\n[SUCCESS] FFI bindings test passed!")
    os.exit(0)
else
    print("\n[FAILED] Test failed")
    os.exit(1)
end
-- }}}
