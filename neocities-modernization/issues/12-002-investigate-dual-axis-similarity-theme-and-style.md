# Issue 12-002: Investigate Dual-Axis Similarity (Theme AND Style)

**Created**: 2026-02-18
**Status**: Open
**Priority**: Research
**Phase**: 12 (Experimental AI Features)

---

## Current Behavior

The similarity system uses **single-axis cosine similarity** on 768-dimensional embeddings from EmbeddingGemma. This captures a blend of semantic and stylistic features, but:

1. **Poems that are thematically similar but stylistically different** may rank lower than expected
2. **Poems that are stylistically similar but thematically different** may also rank lower
3. The current algorithm functions as **AND-like** (all dimensions must align), not **OR-like** (similar on either axis)

**Example (poem 7721):**
- Anchor: "I am a slow burn. glacial pace. read me as such. sit with me. drink tea with me. trust me."
- Top match (0.74): "I am NOT larping. I am expressing how I feel imaginatively."
- The match shares first-person declaration style but NOT the meditative theme of patience/presence

---

## Intended Behavior

A similarity system that captures **BOTH**:
- **Thematic resonance**: What the poem is about (emotions, concepts, subject matter)
- **Writing style**: How the poem is written (structure, voice, rhythm, formatting)

With **OR-like combination**: A poem should rank high if it's similar on theme OR similar on style (or both).

---

## Research Questions

### Phase A: Understanding Current Limitations

- [ ] **Q1**: What exactly does EmbeddingGemma encode? Run experiments comparing known-similar poems
- [ ] **Q2**: Are the top similarity matches consistent across different anchor poems?
- [ ] **Q3**: What's the distribution of similarity scores? Are 0.70-0.75 actually "good" scores?

### Phase B: Defining Theme vs Style

- [ ] **Q4**: USER INPUT REQUIRED - What features constitute "writing style" for this poetry collection?
  - Sentence length patterns?
  - Punctuation usage?
  - Person (1st/2nd/3rd)?
  - Question/exclamation presence?
  - Line break frequency?
  - Vocabulary complexity?
  - Formatting (indentation, ASCII art)?

- [ ] **Q5**: USER INPUT REQUIRED - What constitutes "thematic similarity"?
  - Same emotional tone?
  - Same subject matter?
  - Same conceptual metaphors?
  - Same intended audience/context?

### Phase C: Approach Selection

- [ ] **Q6**: USER INPUT REQUIRED - Which approach to prioritize?
  1. **Hand-crafted style features** + embedding hybrid (fast, interpretable)
  2. **Dual embedding** with separate theme/style prompts (moderate, systematic)
  3. **LLM labeling** with theme/style tags (accurate, one-time expensive)
  4. **LLM pairwise comparison** (most accurate, very expensive)

- [ ] **Q7**: USER INPUT REQUIRED - Acceptable processing time?
  - Minutes (feature extraction only)
  - Hours (LLM labeling, ~6,860 calls)
  - Day+ (LLM pairwise, ~600K+ calls)

### Phase D: Combination Strategy

- [ ] **Q8**: USER INPUT REQUIRED - How to combine theme and style scores?
  - `max(theme, style)` - OR-like, either axis is sufficient
  - `0.5*theme + 0.5*style` - weighted average
  - `theme * style` - multiplicative (both must be present)
  - Custom weighting based on experimentation?

- [ ] **Q9**: USER INPUT REQUIRED - Should the weight be configurable per-user or fixed?

---

## Suggested Implementation Steps

### Step 1: Baseline Analysis (No Code Changes)
1. Sample 10-20 anchor poems across different styles
2. Manually evaluate top 10 matches for each
3. Document what "should" be similar but isn't
4. Identify patterns in what the current algorithm gets wrong

### Step 2: Style Feature Extraction Prototype
1. Define style feature vector (sentence length, punctuation, etc.)
2. Implement extraction in Lua
3. Compute style similarity using cosine or Euclidean
4. Test: Does style-only similarity find structurally similar poems?

### Step 3: Hybrid Scoring Prototype
1. Implement combination function (max, weighted, etc.)
2. Re-rank existing candidates using hybrid score
3. Compare rankings: old vs new
4. USER EVALUATION: Are the new rankings better?

### Step 4: LLM Enhancement (Optional)
1. Design prompt for theme/style labeling
2. Test on sample of 100 poems with llama3.2
3. Evaluate label quality and consistency
4. USER DECISION: Scale to full dataset?

### Step 5: Integration
1. Add new similarity mode to config.lua
2. Update similarity-calculator.lua with hybrid algorithm
3. Regenerate similarity matrices
4. Update HTML generation to use new scores

---

## User Decision Points

This issue is designed to be **user-guided**. The following decisions MUST be made by the user:

| Decision | Options | Impact |
|----------|---------|--------|
| Style features to extract | See Q4 | Determines style similarity accuracy |
| Theme definition | See Q5 | Determines what "thematic" means |
| Approach selection | See Q6 | Determines implementation complexity |
| Processing budget | See Q7 | Determines LLM usage |
| Combination strategy | See Q8 | Determines OR vs AND behavior |
| Configurability | See Q9 | Determines user control |

---

## Technical Considerations

### Available Models (GPU Server)
- `llama3.2:latest` (2GB) - Fast, good for labeling
- `gemma3:12b-it-qat` (8.9GB) - Slower, higher quality
- `embeddinggemma:latest` (768-dim) - Current embedding model

### Processing Estimates
| Approach | Calls | Time (est.) | Regeneration |
|----------|-------|-------------|--------------|
| Style features only | 0 | ~5 min | ~5 min |
| Style + embedding hybrid | 0 | ~10 min | ~10 min |
| LLM labeling (llama3.2) | 6,860 | ~2-4 hours | ~2-4 hours |
| LLM pairwise (top 50) | 343,000 | ~48-96 hours | ~48-96 hours |

### Storage Requirements
- Style features: ~1MB JSON
- LLM labels: ~5MB JSON
- New similarity matrices: Same as current (~100MB)

---

## Related Documents

- `/docs/similarity-algorithm-research.md` - Algorithm comparison
- `/src/similarity-calculator.lua` - Current implementation
- `/src/similarity-engine.lua` - Embedding generation
- `/config.lua` - Similarity configuration (lines 287-294)
- `/assets/embeddings/embeddinggemma_latest/` - Current embeddings

---

## Success Criteria

1. User can articulate what "similar" means for their poetry collection
2. New algorithm produces rankings that user evaluates as "better"
3. Processing time is acceptable for regeneration
4. System is configurable for experimentation

---

## Notes

This issue explores the fundamental question: **What does "similar" mean for poetry?**

The current embedding approach assumes similarity is a single axis. This investigation explores whether poetry similarity is better modeled as multiple axes (theme, style, structure, etc.) that can be weighted and combined.

The research may conclude that:
- Current approach is sufficient (no changes needed)
- Simple style features improve results significantly
- LLM-based approaches are worth the cost
- A hybrid approach is optimal

All outcomes are valid research results.

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-18 | Issue created based on investigation of poem 7721 similarity results |

