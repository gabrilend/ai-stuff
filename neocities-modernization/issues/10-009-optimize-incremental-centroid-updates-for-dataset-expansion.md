# Issue 10-009: Optimize Incremental Centroid Updates for Dataset Expansion

**Phase**: 10 (Developer Tooling)
**Priority**: Medium
**Status**: Open
**Created**: 2026-01-12

## Current Behavior

When new poems are added to the dataset, the entire diversity sequence generation process must be recalculated from scratch for each affected anchor poem. This involves:
- Recalculating all centroids even when most haven't changed
- Recomputing diversity scores for poems that were already processed
- No memory of which poems contributed to each centroid
- Significant computational overhead when adding new poems

The current system treats dataset expansion as a complete regeneration rather than an incremental update.

## Intended Behavior

The system should support incremental updates when new poems are added to the dataset by:
- "Unwinding" existing centroids by keeping memory of constituent poems
- Inserting new poems into the appropriate positions in existing sequences
- Only recalculating centroids and scores for affected positions
- Skipping unrelated calculations where the new poems don't impact results
- Making dataset expansion much cheaper computationally

This would enable easier iteration on the "LLM training scheme" by allowing quick updates when new content is added.

## Suggested Implementation Steps

### Step 1: Design Centroid Memory Structure
1. Analyze current centroid calculation in diversity sequence generation
2. Design a data structure to track:
   - Which poems contributed to each centroid
   - The order poems were added to the centroid
   - Intermediate centroid values at each step
3. Determine storage format (JSON, binary, or database)
4. Calculate storage overhead for the memory system

### Step 2: Implement Centroid Unwinding
1. Modify centroid calculation to record constituent poems
2. Create functions to:
   - "Unwind" a centroid to a previous state
   - "Rewind" a centroid by adding new poems
   - Verify centroid integrity after modifications
3. Add validation that unwound/rewound centroids match from-scratch calculations

### Step 3: Implement Incremental Insertion Algorithm
1. Create algorithm to determine where new poems fit in existing sequences
2. For each new poem:
   - Find its relationship to existing sequence poems
   - Determine insertion point(s) based on diversity scores
   - Update only affected centroids from that point forward
3. Optimize to skip poems that won't be affected:
   - Identify anchor poems where new poems will be at the end (dissimilar)
   - Skip recalculation for unaffected positions

### Step 4: Create Update Detection System
1. Implement change detection for:
   - New poems added to the dataset
   - Modified embeddings for existing poems
   - Deleted poems (if applicable)
2. Create differential update planner:
   - Identify which diversity sequences need updates
   - Prioritize updates based on impact
   - Generate minimal update plan

### Step 5: Add Incremental Update Interface
1. Create command-line interface for incremental updates
2. Add options for:
   - Update vs full regeneration mode
   - Verification of incremental results
   - Progress tracking for updates
3. Implement safety checks:
   - Validate incremental results match full calculation
   - Detect when full regeneration is required
   - Handle edge cases gracefully

### Step 6: Performance Testing and Optimization
1. Benchmark incremental updates vs full regeneration
2. Measure storage overhead for centroid memory
3. Test with various dataset sizes and update patterns
4. Optimize hotspots identified during testing

## Technical Considerations

### Memory Structure Design
```lua
-- Example centroid memory structure
centroid_memory = {
  anchor_poem_id = 123,
  sequence_position = 5,
  constituent_poems = {1, 45, 78, 234, 567}, -- IDs in order added
  centroid_value = {...},  -- The actual centroid embedding
  calculated_at = timestamp
}
```

### Calculation Efficiency
- **Current**: O(n²) for n poems - full recalculation for every update
- **Target**: O(k × m) where k = new poems, m = affected positions
- **Best case**: New poems only affect tail positions (minimal recalculation)
- **Worst case**: New poems are highly similar to many existing poems (more updates needed)

### Storage Considerations
- Current diversity_cache.bin: ~94 MB for 7,797 sequences
- Estimated overhead for centroid memory: ~200-300 MB
- Trade-off: Storage cost vs computational savings on updates

### Validation Strategy
- Always verify first update matches full calculation
- Random sampling validation for subsequent updates
- Option to force full recalculation for verification

## Related Documents

- Phase 9 GPU acceleration: `/issues/9-001-implement-vulkan-compute-infrastructure.md`
- Diversity sequence generation: `/issues/completed/phase-9/9-001d-implement-diversity-sequence-gpu-algorithm.md`
- Centroid optimization: `/issues/9-003-optimize-centroid-calculation-and-parallelization.md`
- Data flow architecture: `/docs/data-flow-architecture.md`

## Related Tools

- Diversity sequence generator: `/libs/vulkan-compute/diversity-batch.lua`
- Centroid calculator: (integrated in diversity algorithm)
- Diversity cache: `/assets/diversity_cache.bin`

## Dependencies

- Phase 9 diversity sequence generation (completed)
- Understanding of current centroid calculation algorithm
- Storage system for centroid memory

## Success Criteria

- [ ] Centroid memory structure designed and implemented
- [ ] Unwinding/rewinding functions work correctly
- [ ] Incremental insertion algorithm functional
- [ ] Validation confirms incremental results match full calculation
- [ ] Performance improvement measured and documented
- [ ] Command-line interface for incremental updates
- [ ] Documentation for developers

## Original Insight (from sort-me)

> "we should be able to 'unwind' a centroid if we keep a memory of the poems that built it. In doing so, we can recalculate it very easily, since we know the answers already. if we start from the first one, already calculated, then iterate through... we can find out where to place any new poems that aren't built into the centroid yet. then it's just a matter of inserting them, and calculating only what comes afterwards. yes, it's still repeating work. but it's much cheaper because we can skip anything that's unrelated."

The key insight is that by maintaining a memory of how centroids were constructed, we can make incremental updates dramatically cheaper than full regeneration. This becomes especially valuable for:
- Adding new poems to the dataset
- Experimenting with different similarity algorithms
- Iterating on the "LLM training scheme" mentioned in the note

## Performance Expectations

For adding 100 new poems to a dataset of 7,797:
- **Current approach**: ~10-12 hours (full regeneration)
- **Incremental approach (estimated)**: ~30-60 minutes (20x speedup)

The speedup comes from:
1. Skipping unaffected anchor poems (poems where new content is highly dissimilar)
2. Only recalculating from insertion point forward (not from scratch)
3. Reusing existing centroid calculations up to the insertion point
