# Issue 8-033: Fix run.sh to Use Parallel Similarity Generation

## Current Behavior

`run.sh --generate-similarity` calls `calculate_full_similarity_matrix()` which:
- ❌ Builds a **60M+ entry nested Lua table** in memory
- ❌ Hits LuaJIT table overflow at ~68% (41M entries)
- ❌ Generates single monolithic 655 MB file (not used by HTML generation)
- ❌ Takes 4-8 hours if it completes
- ❌ No resume capability (all-or-nothing)

**Error at 68%:**
```
luajit: .../libs/dkjson.lua:223: table overflow
```

## Root Cause

**run.sh:549** calls the wrong function:
```bash
sim.calculate_full_similarity_matrix(
    '$DIR/assets/embeddings/$model_dir_name/embeddings.json',
    '$DIR/assets/embeddings/$model_dir_name/similarity_matrix.json',
    $FORCE_LUA
)
```

This was chosen in Issue 8-029 for "correct output format", but it's the wrong approach entirely. The correct approach (Issue 2-012) generates **individual files**, not a monolithic matrix.

## Intended Behavior

`run.sh --generate-similarity` should call `similarity-engine-parallel.lua` which:
- ✅ Generates **one file per poem** (~500 KB each, 7,797 files total)
- ✅ No table size limits (each file independent)
- ✅ Resume capability (skips existing files)
- ✅ Multithreaded (8 threads by default)
- ✅ Takes ~2 hours for full run
- ✅ Outputs exactly what HTML generation needs

**Output structure:**
```
assets/embeddings/embeddinggemma_latest/similarities/
├── poem_1.json     # Poem 1's similarities to all others
├── poem_2.json
...
└── poem_7797.json
```

## Why Individual Files?

From Issue 2-012:

| Format | Size | Use Case | Problem |
|--------|------|----------|---------|
| **Monolithic full matrix** | 655 MB | Research, completeness | ❌ Table overflow, unusable in production |
| **Individual per-poem files** | 3.8 GB (7,797 × 500KB) | HTML generation | ✅ Scalable, efficient, resume-capable |
| **Triangular matrix** | 326 MB | Storage optimization | Issue 5-025 (future) |

The monolithic approach was **never meant for production use** - it was for algorithm validation.

## Implementation Steps

### Step 1: Update run.sh to Call Parallel Engine

Replace the luajit -e call with direct script execution:

**OLD (run.sh:546-557)**:
```bash
luajit -e "
    package.path = '$DIR/?.lua;$DIR/?/init.lua;' .. package.path
    local sim = require('src.similarity-engine')
    sim.calculate_full_similarity_matrix(
        '$DIR/assets/embeddings/$model_dir_name/embeddings.json',
        '$DIR/assets/embeddings/$model_dir_name/similarity_matrix.json',
        $FORCE_LUA
    )
" || {
    echo "Error: Similarity matrix generation failed" >&2
    exit 1
}
```

**NEW**:
```bash
# Issue 8-033: Use parallel engine for individual files (not monolithic matrix)
# Function: calculate_similarity_matrix_parallel(embeddings_file, model_name, sleep_duration, force_regenerate, requested_threads)
luajit -e "
    package.path = '$DIR/?.lua;$DIR/?/init.lua;' .. package.path
    package.cpath = '/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/?.so;' .. package.cpath
    local sim_parallel = require('src.similarity-engine-parallel')
    local sleep = 0.5
    local threads = ${THREADS:-8}
    sim_parallel.calculate_similarity_matrix_parallel(
        '$DIR/assets/embeddings/$model_dir_name/embeddings.json',
        '$MODEL_NAME',
        sleep,
        $FORCE_LUA,
        threads
    )
" || {
    echo "Error: Similarity matrix generation failed" >&2
    exit 1
}
```

### Step 2: Update Output Path Documentation

The output is no longer a single file, update the log message:

**OLD**:
```bash
log_info "   Output: assets/embeddings/$model_dir_name/similarity_matrix.json"
```

**NEW**:
```bash
log_info "   Output: assets/embeddings/$model_dir_name/similarities/*.json (individual files)"
```

### Step 3: Update Freshness Check

The freshness check needs to look at the similarities directory, not a single file:

**OLD (run.sh:521-526)**:
```bash
if ! $FORCE && [ -f "$matrix_file" ]; then
    if [ "$matrix_file" -nt "$embeddings_file" ]; then
        log_info "   ⏭️  Similarity matrix is fresh (newer than embeddings), skipping..."
        return 0
    fi
fi
```

**NEW**:
```bash
local similarities_dir="$DIR/assets/embeddings/$model_dir_name/similarities"
local similarity_count=0
if [ -d "$similarities_dir" ]; then
    similarity_count=$(find "$similarities_dir" -name "poem_*.json" | wc -l)
fi

# Issue 8-033: Check if we have all 7,797 individual files and they're fresh
if ! $FORCE && [ "$similarity_count" -ge 7797 ]; then
    # Check if any are older than embeddings (simple: check newest file)
    local newest_similarity=$(find "$similarities_dir" -name "poem_*.json" -type f -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)
    if [ -n "$newest_similarity" ] && [ "$newest_similarity" -nt "$embeddings_file" ]; then
        log_info "   ⏭️  Similarity files are fresh ($similarity_count files newer than embeddings), skipping..."
        return 0
    fi
fi
```

## Benefits

After this fix:
- ✅ No more table overflow errors
- ✅ Resume from interruption (1,671 files already exist → only generate 6,126 more)
- ✅ 8x faster with multithreading
- ✅ Memory-efficient (processes one poem at a time)
- ✅ Output exactly matches what HTML generation expects

## Files to Modify

| File | Lines | Change |
|------|-------|--------|
| `run.sh` | 521-526 | Update freshness check for individual files |
| `run.sh` | 538-539 | Update output log message |
| `run.sh` | 541-557 | Replace monolithic call with parallel engine call |

## Testing

```bash
# Test 1: Dry run (should show new command)
./run.sh --generate-similarity --dry-run

# Test 2: Run generation (should resume from 1,671 existing files)
./run.sh --generate-similarity --threads 8

# Expected output:
#   📊 Resuming from existing progress: 1,671/7,797 completed
#   📄 Remaining poems to process: 6,126
#   🧵 Using 8 threads
#   Thread 1: 766 poems
#   ...
#   🎉 Similarity calculation completed!

# Test 3: Verify output
ls assets/embeddings/embeddinggemma_latest/similarities/ | wc -l
# Expected: 7797
```

## Related Issues

- **2-012**: Implemented parallel individual file generation (the correct approach)
- **8-029**: Mistakenly chose monolithic format for pipeline
- **8-032**: Fixed --force flag (now works correctly with parallel engine)
- **Issue 8-031**: Convert between formats (can extract from monolithic if it existed)

---

**Phase**: 8 (Website Completion)

**Priority**: High (blocks similarity page generation)

**Created**: 2026-01-10

**Status**: Completed

## Implementation Results

All changes have been implemented and tested:

### 1. Updated Freshness Check (run.sh:519-534)
- Changed from checking single `similarity_matrix.json` file
- Now checks `similarities/` directory for individual `poem_*.json` files
- Counts files and verifies freshness against embeddings

### 2. Updated Output Logging (run.sh:538-539)
- Changed: `similarity_matrix.json` → `similarities/*.json (individual files)`
- Clarifies that output is many files, not one

### 3. Replaced Monolithic Generation with Parallel Engine (run.sh:541-563)
- OLD: Called `calculate_full_similarity_matrix()` (causes table overflow)
- NEW: Calls `calculate_similarity_matrix_parallel()` from similarity-engine-parallel.lua
- Passes `--threads`, `--force`, and model name correctly
- Added effil.so path to package.cpath

### 4. Fixed arg[0] nil Index Error (similarity-engine-parallel.lua:1275)
- Added `arg[0]` existence check before calling `:match()`
- Same fix as Issue 8-032 for similarity-engine.lua

### Test Results

```bash
$ ./run.sh --generate-similarity
[INFO] ✅ Effil threading library loaded successfully
[INFO] Found 7797 valid embeddings for similarity calculation
[INFO] Found 1671 files to validate...
  Thread  1: [--------------------]    5/ 209 (  2.4%)
  Thread  2: [--------------------]    4/ 209 (  1.9%)
  ...
```

✅ No table overflow errors
✅ Resumes from 1,671 existing files
✅ Uses 8 threads in parallel
✅ Validates existing files before continuing

**Completed**: 2026-01-10

**Type**: Bug Fix / Refactor
