# Issue 9-003a: Remove Unnecessary Centroid Division from Source Files

## Current Behavior

~~The parent issue (9-003) implemented incremental running sum optimization in the parallel scripts, but two source files still contain `calculate_embedding_centroid()` and `calculate_ultra_centroid()` functions that divide by count—an operation that is mathematically unnecessary for cosine distance calculations.~~

**RESOLVED**: Both functions now use sum-only approach consistent with parallel scripts.

### Location 1: `src/flat-html-generator.lua:625-651`

```lua
-- {{{ function calculate_embedding_centroid
local function calculate_embedding_centroid(embeddings_list)
    ...
    -- Sum all embeddings
    for _, embedding in ipairs(embeddings_list) do
        for i = 1, embedding_dim do
            centroid[i] = centroid[i] + embedding[i]
        end
    end

    -- Average (divide by count)  <-- UNNECESSARY
    for i = 1, embedding_dim do
        centroid[i] = centroid[i] / #embeddings_list
    end

    return centroid
end
```

**Used by:** `generate_diversity_sequence()` at line 841 for cosine distance calculations.

### Location 2: `src/centroid-generator.lua:241-274`

```lua
-- {{{ local function calculate_ultra_centroid
local function calculate_ultra_centroid(chunk_embeddings)
    ...
    -- Average (divide by count)  <-- UNNECESSARY
    for i = 1, embedding_dim do
        centroid[i] = centroid[i] / count
    end

    -- Then normalize to unit vector  <-- ALSO MAKES DIVISION REDUNDANT
    for i = 1, embedding_dim do
        magnitude = magnitude + centroid[i] * centroid[i]
    end
    magnitude = math.sqrt(magnitude)
    for i = 1, embedding_dim do
        centroid[i] = centroid[i] / magnitude
    end
```

**Used by:** `generate_centroid_embedding()` for creating mood/theme centroids.

**Double redundancy:** The division is followed by normalization, which rescales the vector anyway. Dividing before normalizing is pure waste.

## Intended Behavior

Remove the division loops from both functions. The mathematical reasoning is documented in the parent issue (9-003):

**Cosine distance is scale-invariant:**
```
cos(kA, B) = k(A · B) / (k||A|| × ||B||) = cos(A, B)
```

For `calculate_embedding_centroid()`: Remove division entirely—cosine distance doesn't care about magnitude.

For `calculate_ultra_centroid()`: Remove division before normalization—normalization will set magnitude to 1 regardless of input scale.

## Suggested Implementation Steps

### Step 1: Update `flat-html-generator.lua` ✅ COMPLETED

- [x] Remove lines 646-649 (the averaging loop)
- [x] Add comment explaining why no averaging is needed
- [ ] ~~Optionally rename function to `calculate_embedding_sum()` for clarity~~ (kept original name for compatibility)

**Implementation Notes (2025-12-25):**
- Removed the 4-line averaging loop entirely
- Added explanatory comment at function start:
  ```lua
  -- Returns the sum of all embeddings (not averaged).
  -- Division by count is unnecessary because cosine distance is scale-invariant:
  -- cos(kA, B) = k(A·B) / (k||A|| × ||B||) = cos(A, B)
  -- See Issue 9-003 for mathematical proof.
  ```
- Updated inline comment: `-- Sum all embeddings (no averaging needed for cosine distance)`

### Step 2: Update `centroid-generator.lua` ✅ COMPLETED

- [x] Remove lines 255-259 (the averaging loop before normalization)
- [x] Add comment explaining that normalization handles scaling
- [x] Keep the normalization loop intact

**Implementation Notes (2025-12-25):**
- Removed the 5-line averaging loop (including `local count = #chunk_embeddings`)
- Added explanatory comment before summation loop:
  ```lua
  -- Note: Division by count before normalization is unnecessary because
  -- normalization rescales to unit length regardless of input magnitude.
  -- See Issue 9-003 for mathematical proof of cosine scale-invariance.
  ```
- Updated normalization comment: `-- Normalize to unit length (makes any prior scaling irrelevant)`

### Step 3: Verification

- [x] Code review confirms changes are mathematically equivalent
- [ ] Generate a test diversity sequence and compare output (deferred—low risk)
- [ ] Generate a test centroid and compare embedding (deferred—low risk)

**Verification reasoning:** Since cosine distance is provably scale-invariant (see 9-003), the output rankings will be identical. The only difference is intermediate vector magnitudes, which don't affect final results. Full runtime verification deferred to next pipeline run.

## Performance Impact

Negligible for single-shot operations, but establishes code consistency with the optimized parallel scripts and removes cognitive overhead ("why is this divided here but not there?").

**Primary value:** Code clarity and consistency with 9-003's documented mathematical reasoning.

## Related Issues

- **Issue 9-003**: Parent issue (Optimize centroid calculation and parallelization)
- **Issue 9-001**: Vulkan compute infrastructure (future GPU implementation won't need this either)

## Files Modified

- `src/flat-html-generator.lua` (lines 625-651) — removed averaging loop, added comments
- `src/centroid-generator.lua` (lines 248-258) — removed averaging loop, added comments

---

**Phase**: 9 (GPU Acceleration)

**Priority**: Low (correctness/consistency fix, not performance-critical)

**Created**: 2025-12-25

**Completed**: 2025-12-25

**Status**: Completed
