# 10-033: Fix HTML Generation Memory Exhaustion

## Current Behavior

When running HTML generation (stage 9) with `--force`, the system becomes unresponsive:
- RAM and swap reach 100%
- CPU at 100%, very hot
- GPU barely used (3% VRAM)
- System requires hard reboot or killing the process

## Root Cause Analysis

The HTML generation is loading **gigabytes** of JSON data multiple times:

| File | Size | Who Loads It |
|------|------|--------------|
| `similarity_matrix.json` | **662MB** | Main thread only (**unused!**) |
| `similarity_rankings_cache.json` | **384MB** | Each worker thread × N |
| `diversity_cache.json` | **318MB** | Each worker thread × N |
| `embeddings.json` | **77MB** | Main thread only (**unused!**) |
| `poems.json` | **12MB** | Main thread + each worker thread |

### Memory Math (with 4 threads default from TUI)

- Main thread loads: 662MB + 77MB + 12MB = **751MB**
- Each worker loads: 384MB + 318MB + 12MB = **714MB**
- 4 workers × 714MB = **2,856MB**
- JSON parsing overhead (3-5×): multiply by ~4
- **Total potential memory: 14+ GB**

### Why the data isn't needed

Looking at `flat-html-generator.lua:1173`:
```lua
-- Parameter similarity_data is kept for API compatibility but not used when cache is available
```

Both `similarity_data` and `embeddings_data` are passed to functions that **only use cache lookups**:
- `generate_similarity_ranked_list()` uses `SIMILARITY_RANKINGS_CACHE`
- `generate_maximum_diversity_sequence()` uses `DIVERSITY_CACHE`

The main thread loads 739MB of data that is **never used**.

## Intended Behavior

- HTML generation should use < 2GB RAM total
- No unnecessary data loading
- Worker threads should share data where possible

## Suggested Implementation Steps

### Quick Fix (Low Risk)
In `src/main.lua`, skip loading `similarity_matrix.json` and `embeddings.json` since caches are always used:

```lua
function M.generate_website_html(force, pages_spec, poems_per_page, num_threads, chrono_per_page)
    -- ... existing dependency checks ...

    -- Only load poems_data (12MB) - other data loaded from cache in generator
    utils.log_info("Loading poems data...")
    local poems_data = utils.read_json_file(poems_file)

    -- Pass nil for similarity_data and embeddings_data (cache used internally)
    local gen_success = flat_html_generator.generate_complete_flat_html_collection(
        poems_data, nil, nil, output_dir, pages_spec, poems_per_page, num_threads, chrono_per_page
    )
```

### Medium-term Fix
1. In worker thread function, use memory-mapped files or shared memory instead of loading full JSON per thread
2. Consider streaming JSON parsing for large files

### Long-term Architecture
1. Replace effil with process-based parallelism (each process has own memory space, OS manages better)
2. Use memory-mapped similarity cache instead of JSON
3. Consider binary format for large data files

## Related Documents

- `src/main.lua:527-615` - generate_website_html function
- `src/flat-html-generator.lua:3082-3254` - parallel processing section
- Issue 9-002 - Added parallel HTML generation

## Implementation (Completed)

### Fix 1: Skip Loading Unused Data Files (main.lua)
- Removed loading of `similarity_matrix.json` (662MB) and `embeddings.json` (77MB)
- These files are never used - generator functions use pre-computed caches
- **Savings: 739MB from main thread**

### Fix 2: Default to Single-Threaded Mode (run.sh)
- Changed default thread count from 4 to 1
- Each parallel worker loads 700MB+ of data independently
- With single thread, only one copy of caches is loaded
- Description updated to warn users about high RAM usage with threads > 1

### Expected Memory Usage After Fix
- Single-threaded mode: ~2-3GB (poems.json + caches with JSON overhead)
- This is down from potential 14+ GB with 4 threads

### Future Improvements (Not Implemented)
- Shared memory for parallel workers (effil.table)
- Memory-mapped cache files instead of JSON
- Binary format for large data files

## Status

**IMPLEMENTED** - Two-part fix applied
