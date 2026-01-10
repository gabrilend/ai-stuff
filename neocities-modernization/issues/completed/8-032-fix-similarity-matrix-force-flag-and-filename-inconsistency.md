# Issue 8-032: Fix Similarity Matrix --force Flag and Filename Inconsistency

## Current Behavior

When running `./run.sh --generate-similarity --force`, the pipeline produces contradictory output:

```
[INFO] Running similarity engine analysis...
[INFO] No similarity matrix found. Use interactive mode (-I) to generate...
[INFO] ✅ Full similarity matrix already exists and is complete
```

**Two bugs cause this**:

### Bug 1: Filename Inconsistency

**similarity-engine.lua:1536** checks for:
```lua
local similarity_file = utils.asset_path("similarity-matrix.json")  -- HYPHEN
```

**run.sh:542** outputs to:
```lua
'$DIR/assets/embeddings/$model_dir_name/similarity_matrix.json'  -- UNDERSCORE
```

One uses `similarity-matrix.json` (hyphen), the other `similarity_matrix.json` (underscore). They check different files!

### Bug 2: `--force` Flag Ignored

**run.sh:544** hardcodes `force_regenerate` to `false`:
```lua
sim.calculate_full_similarity_matrix(
    '$DIR/assets/embeddings/$model_dir_name/embeddings.json',
    '$DIR/assets/embeddings/$model_dir_name/similarity_matrix.json',
    false  -- ⚠️ HARDCODED! Ignores --force CLI flag
)
```

The `$FORCE` variable from CLI is never passed to the Lua function.

## Intended Behavior

1. **Consistent filenames** across all code paths
2. **`--force` flag respected**: When user passes `--force`, similarity matrix regenerates even if it exists
3. **No contradictory messages**: Clear, consistent status reporting

## Root Cause Analysis

**Filename Bug**: Historical inconsistency - different developers used different naming conventions (hyphen vs underscore) in different parts of the codebase.

**Force Flag Bug**: run.sh line 544 was never updated to use the `$FORCE` variable that gets set from CLI arguments.

## Suggested Implementation Steps

### Step 1: Standardize Filename (Choose Underscore)

**Rationale**: `similarity_matrix.json` (underscore) is used in:
- run.sh output path (line 532, 542)
- Issue 8-029 documentation
- calculate_full_similarity_matrix() output path

Only the analysis fallback code uses hyphen. Change it to match.

#### A. Update similarity-engine.lua Line 1536

```lua
-- OLD
local similarity_file = utils.asset_path("similarity-matrix.json")

-- NEW
local similarity_file = utils.asset_path("similarity_matrix.json")
```

### Step 2: Pass `--force` Flag Through

#### A. Update run.sh Line 544

```bash
# OLD
sim.calculate_full_similarity_matrix(
    '$DIR/assets/embeddings/$model_dir_name/embeddings.json',
    '$DIR/assets/embeddings/$model_dir_name/similarity_matrix.json',
    false
)

# NEW
sim.calculate_full_similarity_matrix(
    '$DIR/assets/embeddings/$model_dir_name/embeddings.json',
    '$DIR/assets/embeddings/$model_dir_name/similarity_matrix.json',
    $FORCE_LUA
)
```

#### B. Define `$FORCE_LUA` Variable

Add after line 230 (where `$FORCE` is set):

```bash
# Convert boolean for Lua
if $FORCE; then
    FORCE_LUA="true"
else
    FORCE_LUA="false"
fi
```

### Step 3: Test

```bash
# Test 1: Without --force (should skip if exists)
./run.sh --generate-similarity
# Expected: "✅ Full similarity matrix already exists and is complete"

# Test 2: With --force (should regenerate)
./run.sh --generate-similarity --force
# Expected: "🔍 Generating FULL similarity matrix..."

# Test 3: Fresh generation (file doesn't exist)
rm assets/embeddings/embeddinggemma_latest/similarity_matrix.json
./run.sh --generate-similarity
# Expected: Generates matrix without contradictory messages
```

## Files to Modify

| File | Line | Change |
|------|------|--------|
| `src/similarity-engine.lua` | 1536 | `similarity-matrix.json` → `similarity_matrix.json` |
| `run.sh` | ~230 | Add `FORCE_LUA` variable |
| `run.sh` | 544 | `false` → `$FORCE_LUA` |

## Expected Output After Fix

### Without `--force` (file exists):
```
[INFO] Running similarity engine analysis...
[INFO] ✅ Full similarity matrix already exists and is complete
✅ Pipeline completed successfully
```

### With `--force` (regenerate):
```
[INFO] Running similarity engine analysis...
[INFO] 🔍 Generating FULL similarity matrix (all poem pairs)...
[INFO] ⚠️  This will generate ALL 47.1M comparisons and may take 4-8 hours
[INFO] Processing poem 1/7797 (ID: 1)
...
```

## Quality Assurance Criteria

- [ ] No contradictory messages in any execution mode
- [ ] `--force` flag triggers regeneration
- [ ] Without `--force`, existing matrix is reused
- [ ] Filename is consistent across all code paths
- [ ] Both interactive (`-I`) and pipeline modes work correctly

## Related Issues

- **8-029**: Consolidated similarity matrix functions
- **8-023**: Fixed similarity function naming
- **8-001**: Pipeline integration

## Priority

**High** - This breaks the user's ability to regenerate similarity matrices when needed.

---

**Phase**: 8 (Website Completion)

**Priority**: High (blocks regeneration)

**Created**: 2026-01-10

**Status**: Completed

## Implementation Results

All three bugs have been fixed:

### 1. Fixed Filename Inconsistency
**File**: `src/similarity-engine.lua:1537`
- Changed `similarity-matrix.json` → `similarity_matrix.json`
- Added comment explaining Issue 8-032

### 2. Passed `--force` Flag Through
**File**: `run.sh:325-329`
- Added `FORCE_LUA` variable conversion (bash boolean → Lua boolean)

**File**: `run.sh:545`
- Changed hardcoded `false` → `$FORCE_LUA`
- Added comment explaining Issue 8-032

### 3. Fixed Unintended `main()` Execution
**File**: `src/similarity-engine.lua:1659`
- Changed `if arg then` → `if arg and arg[0] then`
- Prevents `main()` execution when required as module from `luajit -e`
- Added comment explaining the distinction

### Test Results

**Without `--force`** (file exists):
```bash
$ ./run.sh --generate-similarity
[INFO] ✅ Full similarity matrix already exists and is complete
✅ Pipeline completed successfully
```
✅ No contradictory messages, correctly skips regeneration

**With `--force`** (regenerate):
```bash
$ ./run.sh --generate-similarity --force
[INFO] 🔍 Generating FULL similarity matrix (all poem pairs)...
[INFO] ⚠️  This will generate ALL 47.1M comparisons and may take 4-8 hours
[INFO] Processing 7797 poems for full similarity matrix
[INFO] Processing poem 1/7797 (ID: 1)
...
```
✅ Correctly regenerates despite existing file

**Completed**: 2026-01-10

**Type**: Bug Fix
