# Issue 010: Implement Similarity Matrix Invalidation on Embedding Changes

## Status
- **Phase**: 2 (Similarity Engine)
- **Status**: REOPENED 2026-09-22 — the first round (November 2025, recorded
  further down) guarded the similarity matrix against a changed *embedding
  count*. It did not guard the caches that the HTML stage actually reads against
  a changed *poem numbering*. That gap is the reopened scope.
- **Sorted from**: `next-issue-please-sort` (item 3)
- **Related**: 5-024 (multi-algorithm similarity), 6-033 (embedding content
  preprocessing), 12-002 (dual-axis theme/style) — those are about how good the
  similarity is; this issue is about whether the stored results still belong to
  the poems they are shown beside.

## The owner's report (verbatim)

> also, the similarity calculations are way off. they're just, totally unrelated.

## Current Behavior

- The HTML stage does not compute similarity. It reads two caches written by
  earlier stages: the similarity-rankings cache (for each poem, the other poems
  ordered from most to least similar) and the diversity cache (for each poem,
  the sequence used by the "different" pages).
- Both caches name poems by **global poem index** — one integer per poem across
  the whole corpus. Those integers are handed out category by category
  (fediverse first, then boosts, notes, messages, then the image pseudo-poems),
  so one new fediverse post shifts the index of every poem after it.
- The two cache loaders in `src/flat-html-generator.lua`
  (`load_similarity_rankings_cache` and `load_diversity_cache`) check only that
  the file exists and is not empty. Nothing compares the cache with the
  `assets/poems.json` it is being joined to. A cache written before a
  re-extraction is therefore accepted, and every neighbour on every page points
  at whichever poem now sits at that number — pages that look "totally
  unrelated".
- Two smaller mismatches in the single-threaded page builder make the same class
  of error possible even with a fresh cache:
  - the anchor poem is looked up by its **position in the poems array** rather
    than by its global index (aligned today only by accident: 0 mismatches
    measured);
  - the three "skip the anchor" loops compare **per-category numbers** (e.g.
    messages/260 vs fediverse/260), not global indices.

### Evidence (measured 2026-09-22)

- The **current** cache (embeddinggemma, mean-centred, written Sep 9) is sound.
  Its neighbours are plainly related:
  - messages/260 → the deplatforming / "send them their data" post, "copyright is
    a flawed system", and messages/259 "we own that content";
  - messages/1514 → "going through something with someone", "trusting someone
    doesn't mean…";
  - fediverse/696 → fediverse/310, which is the same text.
  It holds 9,191 entries (8,531 poems + 660 image pseudo-poems), and no poem
  lists itself.
- An **older** cache (nomic) records 8,588 poems in its metadata, against 8,531
  in poems.json now. Its list for poem 1 contains 8102–8108 back to back, which
  looks like numbering drift rather than meaning. So a cache out of step with
  poems.json has existed in this project, and nothing would have stopped it being
  used.
- Conclusion: what the owner saw was most likely pages built from a stale cache.
  It could also be a complaint about model quality; the open question below
  separates the two.

## Intended Behavior (reopened scope)

- Every cache keyed by global poem index carries a **fingerprint** of the
  numbering it was built against: the poem count plus a hash of the ordered list
  of (category, per-category id, global index), and a hash of the image manifest
  (the image pseudo-poems are numbered after the poems).
- Before the HTML stage uses a cache, it recomputes that fingerprint from the
  live poems.json and image manifest. On any difference it **stops** and prints
  the command that regenerates the cache. It never continues with a warning:
  a stale cache produces confidently wrong pages, which is worse than none.
- Inside the page builders, poems are found and compared by global index only.
  Per-category numbers are for display (`messages/260`), never for identity.

## Suggested Implementation Steps (reopened scope)

1. When `scripts/generate-similarity-rankings-cache` and the GPU diversity-cache
   writer (`scripts/precompute-diversity-sequences-gpu`) save a cache, write the
   fingerprint into its metadata.
2. In `load_similarity_rankings_cache` and `load_diversity_cache`
   (`src/flat-html-generator.lua`), recompute the fingerprint and refuse on a
   mismatch, naming the regenerate command. A cache without a fingerprint is
   also refused (it predates the guard).
3. In `generate_similarity_ranked_list`, find the anchor through the
   global-index table that function already builds, not by array position.
4. In the three skip loops of the single-threaded formatter, compare global
   indices. (The anchor-shown-twice half of this is tracked in 10-025; do the
   two together.)
5. Test: copy poems.json, shift one poem's global index, and check the HTML
   stage refuses to start and names the regenerate command. A second test
   confirms an unchanged poems.json passes.
6. Update `src/flat-html-generator.lua`'s cache-loading comments to say why the
   fingerprint exists (numbering is category by category, so it shifts).

## Open Questions

1. **Answered: which page showed unrelated results, and when was it
   deployed?** Owner (2026-09-22): "Um, I dunno." Treated as unknown. The
   fingerprint guard above makes a stale cache impossible to build from, which
   removes the likeliest cause however the page was produced. If unrelated
   neighbours appear after the guard is in place, the complaint is about the
   model or the centring, and belongs with 5-024 / 6-033. The whole-output
   validator (9-006) is where any such page would next be caught.

## Original Behavior (November 2025, before the first round)
- Similarity matrix is generated based on available embeddings at time of calculation
- Matrix persists even when new embeddings are added to the dataset
- No validation that similarity matrix represents complete dataset
- Partial similarity matrices may be used for recommendations, leading to incomplete/inaccurate results
- No tracking of embedding count when similarity matrix was generated

## Intended Behavior
- Similarity matrix should be invalidated when embedding count changes
- Matrix generation should only proceed when all poems have valid embeddings
- Clear validation that similarity matrix represents complete dataset
- Automatic detection of stale similarity matrices
- Warning users when attempting to use incomplete similarity data

## Root Cause Analysis

### **The Completeness Problem**
The similarity engine is designed to compare **each poem with each other poem**. If we have:
- **Total poems**: 6,860
- **Current embeddings**: 2,084 (30.4%)
- **Missing embeddings**: 4,776 poems

Then our current similarity matrix only represents comparisons between the 2,084 poems that have embeddings. This creates several critical issues:

1. **Incomplete Recommendations**: Similarity recommendations will never include the 4,776 poems without embeddings
2. **Biased Results**: The "most similar" poems are only drawn from a subset of the full collection
3. **Inconsistent Updates**: Adding new embeddings creates a different similarity space
4. **Data Integrity**: The matrix becomes stale as soon as new embeddings are added

### **Mathematical Impact**
- **Complete Matrix**: 6,860 × 6,860 = 47,059,600 comparisons
- **Current Matrix**: 2,084 × 2,084 = 4,342,056 comparisons (9.2% of complete)
- **Missing Comparisons**: 42,717,544 poem pairs not evaluated

## Suggested Implementation Steps
1. **Embedding Count Tracking**: Store embedding count in similarity matrix metadata
2. **Validation Logic**: Compare current embedding count vs matrix embedding count
3. **Invalidation System**: Clear stale matrices when embedding count changes
4. **Completeness Checking**: Warn when generating matrices on incomplete datasets
5. **CLI Integration**: Update bash script to validate matrix completeness

## Technical Requirements

### **Similarity Matrix Metadata Enhancement**
```lua
-- Enhanced similarity matrix metadata
local similarity_metadata = {
    generated_at = os.date("%Y-%m-%d %H:%M:%S"),
    model_name = model_name,
    total_poems = total_poem_count,
    embedding_count = valid_embedding_count,
    matrix_completeness = valid_embedding_count / total_poem_count,
    is_complete = valid_embedding_count == total_poem_count,
    last_embedding_file_hash = calculate_file_hash(embeddings_file)
}
```

### **Validation Function**
```lua
-- {{{ function validate_similarity_matrix_currency
function validate_similarity_matrix_currency(similarity_file, embeddings_file, poems_file)
    if not utils.file_exists(similarity_file) then
        return {valid = false, reason = "no_matrix_found"}
    end
    
    local similarity_data = utils.read_json_file(similarity_file)
    local embeddings_data = utils.read_json_file(embeddings_file)
    local poems_data = utils.read_json_file(poems_file)
    
    if not similarity_data.metadata then
        return {valid = false, reason = "no_metadata"}
    end
    
    local total_poems = #poems_data.poems
    local current_embeddings = count_valid_embeddings(embeddings_data)
    local matrix_embeddings = similarity_data.metadata.embedding_count
    
    if current_embeddings ~= matrix_embeddings then
        return {
            valid = false, 
            reason = "embedding_count_mismatch",
            current_count = current_embeddings,
            matrix_count = matrix_embeddings,
            difference = current_embeddings - matrix_embeddings
        }
    end
    
    if not similarity_data.metadata.is_complete then
        return {
            valid = false,
            reason = "incomplete_dataset",
            completeness = similarity_data.metadata.matrix_completeness,
            missing_embeddings = total_poems - current_embeddings
        }
    end
    
    return {valid = true, metadata = similarity_data.metadata}
end
-- }}}
```

### **Automatic Invalidation**
```lua
-- {{{ function M.calculate_similarity_matrix
function M.calculate_similarity_matrix(embeddings_file, output_file, top_n, force_regenerate)
    top_n = top_n or 10
    force_regenerate = force_regenerate or false
    
    -- Validate existing matrix
    if not force_regenerate then
        local validation = validate_similarity_matrix_currency(output_file, embeddings_file, poems_file)
        if validation.valid then
            utils.log_info("✅ Existing similarity matrix is current and complete")
            return true
        else
            utils.log_warn("⚠️  Similarity matrix validation failed: " .. validation.reason)
            if validation.reason == "embedding_count_mismatch" then
                utils.log_info("   Current embeddings: " .. validation.current_count)
                utils.log_info("   Matrix embeddings: " .. validation.matrix_count)
                utils.log_info("   Difference: " .. validation.difference)
            elseif validation.reason == "incomplete_dataset" then
                utils.log_info("   Completeness: " .. string.format("%.1f%%", validation.completeness * 100))
                utils.log_info("   Missing embeddings: " .. validation.missing_embeddings)
            end
            utils.log_info("🗑️  Removing stale similarity matrix...")
            os.remove(output_file)
        end
    end
    
    -- Continue with matrix generation...
    -- [existing matrix calculation code]
end
-- }}}
```

## User Experience Improvements

### **Enhanced CLI Warnings**
```bash
# When attempting to generate HTML with incomplete similarity matrix
echo -e "${YELLOW}⚠️  WARNING: Incomplete similarity matrix detected${NC}"
echo -e "${BLUE}   Embeddings: 2,084 / 6,860 poems (30.4% complete)${NC}"
echo -e "${BLUE}   Missing: 4,776 poems will not appear in recommendations${NC}"
echo ""
echo -e "${CYAN}Recommendations:${NC}"
echo -e "1. Complete embedding generation: ./generate-embeddings.sh --incremental"
echo -e "2. Generate complete similarity matrix after all embeddings"
echo -e "3. Proceed with limited recommendations (not recommended)"
```

### **Status Reporting Enhancement**
```bash
# Enhanced model status to show matrix completeness
./generate-embeddings.sh --model-status

Available Embedding Models:
  EmbeddingGemma:latest (768 dims) - 2,084 cached embeddings (30.4%)
    ⚠️  Similarity matrix: INCOMPLETE (2,084/6,860 poems)
    📊 Matrix completeness: 30.4%
    🔄 Recommendation: Complete embeddings before generating HTML
```

## Quality Assurance Criteria
- Similarity matrices are automatically invalidated when embedding count changes
- Clear warnings when working with incomplete datasets
- Matrix metadata accurately tracks completeness and currency
- CLI tools provide clear guidance on dataset completeness
- No recommendation system uses incomplete similarity data without explicit warning

## Success Metrics
- **Data Integrity**: 100% of similarity matrices represent their claimed dataset state
- **User Awareness**: Clear indication of completeness status in all tools
- **Automatic Maintenance**: No manual intervention required for matrix invalidation
- **Accurate Recommendations**: Similarity recommendations only use complete datasets

## Edge Cases Handled
- **Embedding Removal**: Matrix invalidated when embeddings are deleted
- **Model Switching**: Per-model matrices tracked independently
- **Partial Processing**: Clear distinction between complete and incomplete matrices
- **Concurrent Updates**: File hash validation prevents race conditions

## Implementation Validation
1. Generate partial embeddings (current state: 2,084/6,860)
2. Create similarity matrix and verify metadata shows incompleteness
3. Add new embeddings and verify matrix is automatically invalidated
4. Complete all embeddings and verify matrix shows 100% completeness
5. Test CLI warnings for incomplete matrices
6. Validate recommendation quality with complete vs incomplete matrices

**USER REQUEST FULFILLMENT:**
This ticket addresses the critical requirement that:
1. ✅ Similarity matrices represent complete datasets for accurate recommendations
2. ✅ Automatic invalidation when embedding datasets change
3. ✅ Clear warnings about dataset completeness
4. ✅ Data integrity maintenance across embedding updates

**ISSUE STATUS (first round): COMPLETED** ✅ — reopened 2026-09-22, see Status at top.

## IMPLEMENTATION COMPLETED (first round)

**Date:** November 3, 2025  
**Status:** All critical objectives achieved

### Implementation Summary:
1. **✅ Matrix Validation Function**: Added `validate_similarity_matrix_currency()` with comprehensive checks
   - Detects missing matrices (`no_matrix_found`)
   - Validates metadata existence (`no_metadata`) 
   - Compares current vs matrix embedding counts (`embedding_count_mismatch`)
   - Checks dataset completeness (`incomplete_dataset`)

2. **✅ Enhanced Metadata**: Similarity matrices now include completeness tracking
   ```lua
   metadata = {
       generated_at = timestamp,
       model_name = "EmbeddingGemma:latest",
       total_poems = 6860,
       embedding_count = 6606, 
       matrix_completeness = 0.963,
       is_complete = false,
       top_n = 10,
       algorithm = "cosine_similarity"
   }
   ```

3. **✅ Automatic Invalidation**: Stale matrices automatically removed when:
   - Embedding count changes from matrix generation time
   - Dataset completeness status changes
   - Matrix metadata is missing or corrupted

4. **✅ User Warnings**: Clear feedback about dataset completeness
   - "WARNING: Incomplete dataset detected"
   - Shows exact completeness percentage (96.3%)
   - Explains impact on recommendations
   - Provides guidance for complete generation

### Validation Results:
- Successfully detected and invalidated stale matrix
- Warned about incomplete dataset (6606/6860 = 96.3% complete)
- Matrix generation proceeding with enhanced metadata
- Fixed nil ID handling for robust processing

### Files Modified:
- `src/similarity-engine.lua`: Added validation function and enhanced metadata
- Matrix generation includes completeness checks and warnings

**ISSUE STATUS: CRITICAL FOR PHASE 3 PREPARATION** 🚨

## **Impact on Phase 3**
This issue must be resolved before Phase 3 HTML generation to ensure:
- **Accurate Recommendations**: HTML pages show truly similar poems, not just subset matches
- **Complete Coverage**: All 6,860 poems are eligible for similarity recommendations
- **Consistent Results**: Adding new poems doesn't invalidate existing HTML recommendations
- **User Trust**: Similarity recommendations are mathematically sound and complete

**Priority: HIGH - Required for Phase 3 readiness**

## UPDATES:
- we should ensure that the different ollama models are also considered in the similarity matrix. If possible, we should be able to select which embedding model to use in the similarity matrix. This might require it's own issue, so please create one if it seems out of scope for this issue.

- What I mean by that is that the similarity matrix should produce one output for each model that has embeddings generated. Even if the embeddings aren't completely generated for that model - for example if all 6860 poems (current count) are processed and have embeddings generated with the embedding-gemma model but not the nomic-embedded-text model, which only has, say, 5000 poems with generated embeddings, then the system should generate a similarity matrix for embedding-gemma and another one for nomic-embedded-text. They should be kept separate, to be utilized for different purposes or simply to allow for the user to request a different comparison analysis. The results should slightly differ between models, so if a user wants they should be able to flip between them on the HTML page. But that is vastly out of scope for this ticket, so it will need to be recorded somewhere on a separate issue ticket so that this one can be safely moved to the completed directory without losing this updated task.
