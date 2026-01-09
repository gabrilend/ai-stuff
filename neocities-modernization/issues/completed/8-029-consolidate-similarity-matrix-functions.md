# Issue 8-029: Consolidate Similarity Matrix Functions

## Current Behavior

The codebase has two similarity matrix generation functions with incompatible output formats:

1. **`calculate_similarity_matrix()`** (lines 680-826 in similarity-engine.lua)
   - Generates top-N array format: `{similarities: [{poem_index, top_similar: [...]}]}`
   - Output: `similarity_matrix.json` (6.6MB)
   - Called by: `run.sh` line 540 (the pipeline)

2. **`calculate_full_similarity_matrix()`** (lines 829-962 in similarity-engine.lua)
   - Generates full pairwise format: `{similarities: {poem_id: {other_id: score}}}`
   - Output: `similarity_matrix_full.json` (655MB)
   - Called by: Interactive menu options only

**The Problem**: All consumers of similarity data (flat-html-generator.lua, main.lua, etc.) expect the full pairwise format, but the pipeline generates the incompatible top-N format.

This was introduced in Issue 8-023 which fixed a function naming bug but used the wrong function.

## Intended Behavior

- Single similarity matrix generation function that produces the format consumers expect
- Pipeline generates correct format for HTML generation
- No confusion between multiple incompatible formats
- Output goes to `similarity_matrix.json` (the filename all consumers read)

## Root Cause Analysis

Issue 5-016 established that `calculate_full_similarity_matrix()` is required for HTML generation. Issue 8-023 fixed a syntax error but chose the wrong function, breaking compatibility.

## Suggested Implementation Steps

### Step 1: Update run.sh to call calculate_full_similarity_matrix
- Change line 540 from `calculate_similarity_matrix` to `calculate_full_similarity_matrix`
- Update parameters to match the function signature

### Step 2: Modify calculate_full_similarity_matrix output path
- Currently outputs to `similarity_matrix_full.json`
- Should output to `similarity_matrix.json` directly
- This ensures all consumers find the data where they expect it

### Step 3: Deprecate calculate_similarity_matrix
- Add deprecation comment explaining why it's unused
- Keep function for reference but mark as deprecated
- Document in this issue why it was removed from the pipeline

## Files to Modify

| File | Change |
|------|--------|
| `run.sh` | Change function call at line 540 |
| `src/similarity-engine.lua` | Modify output path in calculate_full_similarity_matrix |
| `src/similarity-engine.lua` | Add deprecation comment to calculate_similarity_matrix |

## Related Issues

- Issue 5-016: Established need for full similarity matrix
- Issue 8-023: Introduced the wrong function call (now being corrected)

## Implementation Results

### Changes Made

1. **run.sh line 541**: Changed `calculate_similarity_matrix` to `calculate_full_similarity_matrix`
   - Updated comment to reference Issue 8-029
   - Removed unused `top_n` parameter (nil)
   - Function now outputs correct full pairwise format

2. **src/similarity-engine.lua line 681**: Added deprecation notice to `calculate_similarity_matrix`
   - Documents why the function is deprecated
   - Points to `calculate_full_similarity_matrix` as the replacement
   - Function preserved for reference

### Verification

The pipeline (`run.sh --generate-similarity`) will now:
- Call `calculate_full_similarity_matrix()`
- Output to `similarity_matrix.json` (the path all consumers expect)
- Generate full pairwise format: `{similarities: {poem_id: {other_id: score}}}`

---

**Phase**: 8 (Website Completion)

**Priority**: High (blocks HTML generation)

**Created**: 2026-01-04

**Completed**: 2026-01-04

**Status**: Completed

**Type**: Refactor / Bug Fix
