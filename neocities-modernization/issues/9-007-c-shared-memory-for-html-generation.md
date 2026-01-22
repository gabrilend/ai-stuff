# Issue 9-007: C Shared Memory for HTML Generation Threading

## Priority
High

## Current Behavior

HTML generation (Stage 9) uses parallel threads via effil, but each thread must reload
large JSON files independently because Lua's effil.table creates a bottleneck:

```lua
-- Each of 8 threads reloads ~830 MB:
local poems_data = t_utils.read_json_file(poems_file)           -- 200 MB
local diversity_cache = t_utils.read_json_file(...)             -- 286 MB
local similarity_cache = t_utils.read_json_file(...)            -- 344 MB
```

**Result**: 8 threads × 830 MB = **6.6 GB RAM** for redundant data copies.

### Failed Approach: effil.table Sharing

We attempted to share data via effil.table (like the diversity stage does), but this
created a different bottleneck: all worker threads serialized through the main thread
to access shared data, causing severe performance degradation.

**Problem**: effil.table requires cross-thread communication through a single point,
which becomes the bottleneck when multiple threads make frequent data requests.

## Intended Behavior

Use C-level shared memory (mmap or POSIX shm) to allow true parallel read access
without serialization through the main thread.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Shared Memory Region                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ embeddings  │  │  diversity  │  │  similarity_rankings   │  │
│  │   73 MB     │  │   286 MB    │  │       344 MB           │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
        ▲                 ▲                     ▲
        │                 │                     │
   ┌────┴────┐       ┌────┴────┐          ┌────┴────┐
   │ Thread 1│       │ Thread 2│   ...    │ Thread 8│
   └─────────┘       └─────────┘          └─────────┘

   All threads read directly from shared memory - no serialization!
```

### Benefits

1. **Single copy in RAM**: ~700 MB instead of 6.6 GB
2. **True parallel reads**: No main thread bottleneck
3. **Zero-copy access**: Threads read directly from mapped memory
4. **Consistent with GPU approach**: Similar to how Vulkan compute shares data

## Technical Design

### Option A: POSIX Shared Memory (Recommended)

```c
// shm_cache.c - Shared memory cache for HTML generation

#include <sys/mman.h>
#include <fcntl.h>

typedef struct {
    size_t embeddings_offset;
    size_t embeddings_count;
    size_t diversity_offset;
    size_t diversity_count;
    size_t rankings_offset;
    size_t rankings_count;
    // Data follows header...
} SharedCache;

// Create shared memory region
SharedCache* shm_cache_create(const char* name, size_t size);

// Load JSON into shared memory (main thread only)
int shm_cache_load_embeddings(SharedCache* cache, const char* json_path);
int shm_cache_load_diversity(SharedCache* cache, const char* json_path);
int shm_cache_load_rankings(SharedCache* cache, const char* json_path);

// Read-only access for worker threads
const float* shm_cache_get_embedding(SharedCache* cache, int poem_id);
const int* shm_cache_get_diversity_sequence(SharedCache* cache, int poem_id);
const float* shm_cache_get_similarity_rankings(SharedCache* cache, int poem_id);

// Cleanup
void shm_cache_destroy(SharedCache* cache);
```

### Option B: Memory-Mapped File

```c
// Map existing JSON files directly (simpler but requires binary format)
void* mmap_file(const char* path, size_t* size_out);
```

### Lua FFI Bindings

```lua
-- libs/shm-cache.lua
local ffi = require("ffi")
local shm = ffi.load("shm_cache")

ffi.cdef[[
    typedef struct SharedCache SharedCache;
    SharedCache* shm_cache_create(const char* name, size_t size);
    const float* shm_cache_get_embedding(SharedCache* cache, int poem_id);
    // ... etc
]]

local M = {}

function M.init(embeddings_path, diversity_path, rankings_path)
    -- Load all data into shared memory once
    local cache = shm.shm_cache_create("/neocities_html_cache", 800*1024*1024)
    shm.shm_cache_load_embeddings(cache, embeddings_path)
    shm.shm_cache_load_diversity(cache, diversity_path)
    shm.shm_cache_load_rankings(cache, rankings_path)
    return cache
end

function M.get_embedding(cache, poem_id)
    return shm.shm_cache_get_embedding(cache, poem_id)
end

return M
```

## Suggested Implementation Steps

1. **Create C library** (`libs/shm-cache/`)
   - Header: `include/shm_cache.h`
   - Source: `src/shm_cache.c`
   - Makefile for building shared library

2. **Binary data format**
   - Design compact binary format for embeddings (float32 arrays)
   - Design format for diversity sequences (int32 arrays)
   - Design format for similarity rankings (poem_id + score pairs)

3. **JSON → Binary converter**
   - One-time conversion script: `scripts/convert-cache-to-binary`
   - Run during pipeline stage 6 or 7

4. **Lua FFI bindings**
   - `libs/shm-cache.lua` with LuaJIT FFI interface

5. **Update flat-html-generator.lua**
   - Main thread: `shm_cache.init()` once
   - Worker threads: Direct reads via FFI (no JSON parsing)

6. **Thread-local poem data**
   - Keep poem content (text) in thread-local storage
   - Only share numeric data (embeddings, rankings) via shm

## Storage Format Considerations

### Current JSON (human-readable, large)
```json
{"embeddings": [{"id": 1, "embedding": [0.123, 0.456, ...]}]}
```

### Proposed Binary (compact, fast)
```
Header: [magic][version][count][embedding_dim]
Data:   [poem_id_1][float32 × 768][poem_id_2][float32 × 768]...
```

**Size reduction**: 73 MB JSON → ~24 MB binary (embeddings only)

## Related Documents

- `src/flat-html-generator.lua` - Current HTML generation with per-thread loading
- `libs/vulkan-compute/` - Example of C library integration with Lua FFI
- Issue 9-003 - Previous effil.table optimization (works for diversity, not for HTML)
- `scripts/precompute-diversity-sequences` - Example of effil.table usage

## Workaround Until Implemented

Reduce thread count to limit RAM usage:
```bash
./run.sh --generate-html --threads 2
```

## Metadata

- **Status**: Open
- **Created**: 2026-01-21
- **Phase**: 9 (Performance Optimization)
- **Estimated Complexity**: High (C development + FFI bindings)
- **RAM Savings**: ~5 GB (from 6.6 GB to ~1.5 GB)
