# Issue 10-031: Embedding Model Evaluation Framework

## Status
- **Phase**: 10
- **Priority**: Medium
- **Type**: Research / Tooling
- **Status**: Open
- **Created**: 2026-03-18

## Current Behavior

Embedding model selection is ad-hoc:
- Pick "newest" or "most recommended" model
- No systematic comparison of model behavior
- No visibility into what aspects of text each model emphasizes
- Results accepted on faith without understanding model biases

Currently using: `nomic-embed-text` (768 dimensions)

Available alternatives:
- `mxbai-embed-large` (1024 dimensions)
- `all-minilm` (384 dimensions)
- `bge-small` (384 dimensions)
- `snowflake-arctic-embed` (1024 dimensions)
- Custom fine-tuned models

## Intended Behavior

Create a framework for systematically evaluating and comparing embedding models to understand:

1. **What each model "values"** - Semantic meaning? Word choice? Sentence structure? Length?
2. **Model "personality"** - Does it emphasize verbs? Nouns? Abstract concepts? Concrete imagery?
3. **Similarity interpretation** - What makes two poems "similar" according to each model?
4. **Diversity interpretation** - What makes poems "maximally different"?

### Evaluation Methodology

#### Step 1: Select Anchor Poems (Test Set)

Choose 5-10 poems that represent diverse characteristics:

| Anchor | Characteristics | Why Include |
|--------|-----------------|-------------|
| Short haiku | Minimal text, imagery-heavy | Tests how models handle sparse input |
| Long narrative | Extended text, story structure | Tests handling of length and coherence |
| Abstract/philosophical | Conceptual, no concrete nouns | Tests semantic vs surface understanding |
| Concrete/descriptive | Physical objects, sensory details | Tests noun/adjective emphasis |
| Emotional/personal | Feelings, relationships | Tests sentiment capture |
| Technical/structured | Code-like, formatted | Tests handling of non-prose |
| Question-heavy | Interrogative mood | Tests handling of sentence type |
| Verb-focused action | Movement, change | Tests verb sensitivity |

#### Step 2: Generate Embeddings Per Model

For each model M and anchor poem A:
```
embeddings[M][A] = model_M.embed(poem_A)
```

#### Step 3: Compute Similarity Rankings

For each model M and anchor A, rank all poems by similarity:
```
rankings[M][A] = sort_by_cosine_similarity(embeddings[M], embeddings[M][A])
```

#### Step 4: Compare Rankings Across Models

For the same anchor poem, compare what different models consider "most similar":

```
Anchor: "the silence between stars speaks in wavelengths we forgot how to hear"

Model: nomic-embed-text
  1. "listening to frequencies beyond human range" (0.92)
  2. "the radio static holds messages from elsewhere" (0.89)
  3. "what the deaf ocean tells the blind shore" (0.87)

Model: mxbai-embed-large
  1. "what the deaf ocean tells the blind shore" (0.94)
  2. "memory fades like starlight through fog" (0.91)
  3. "listening to frequencies beyond human range" (0.88)
```

**Analysis**: nomic emphasizes "frequencies/wavelengths" (technical terms), while mxbai connects "silence/deaf" and "stars/starlight" (semantic parallelism).

#### Step 5: Characterize Model "Personality"

Build a profile for each model based on patterns:

```
nomic-embed-text:
  - Strong: Technical vocabulary matching, concrete nouns
  - Weak: Abstract emotional connections
  - Bias: Prefers longer poems (more signal)

mxbai-embed-large:
  - Strong: Metaphorical connections, semantic parallelism
  - Weak: Surface-level word matching
  - Bias: Treats short and long poems more equally
```

### Output Artifacts

1. **Comparison Report** (`output/model-evaluation/comparison-report.html`)
   - Side-by-side similarity rankings per anchor
   - Highlighted differences between models
   - Model personality summaries

2. **Similarity Matrices** (`output/model-evaluation/{model}/similarity-{anchor}.json`)
   - Full similarity scores for each model-anchor combination
   - Enables detailed analysis

3. **Dimension Analysis** (`output/model-evaluation/dimension-analysis.md`)
   - Which embedding dimensions correlate with which text features?
   - Requires statistical analysis of dimension activations

### TUI Integration

Add to run.sh interactive mode:
```
═══════════════════════════════════════════════════════════════════════════════
                    Model Evaluation (Research Tools)
═══════════════════════════════════════════════════════════════════════════════
  [ ] Run model comparison                        --evaluate-models
  Models: [nomic-embed-text, mxbai-embed-large ▼] --eval-models=...
  Anchors: [auto-select diverse ▼]                --eval-anchors=...
```

## Suggested Implementation Steps

### Phase 1: Infrastructure
1. [ ] Create `scripts/evaluate-embedding-models` script
2. [ ] Define anchor poem selection criteria
3. [ ] Implement multi-model embedding generation
4. [ ] Store embeddings in separate files per model

### Phase 2: Comparison Engine
5. [ ] Implement ranking comparison algorithm
6. [ ] Calculate rank correlation metrics (Kendall's tau, Spearman's rho)
7. [ ] Identify significant ranking disagreements

### Phase 3: Analysis
8. [ ] Build model personality profiler
9. [ ] Implement dimension activation analysis
10. [ ] Generate comparison report HTML

### Phase 4: Integration
11. [ ] Add CLI flags for model evaluation
12. [ ] Add TUI section for evaluation tools
13. [ ] Document findings in `docs/embedding-model-analysis.md`

## Files to Create

| File | Purpose |
|------|---------|
| `scripts/evaluate-embedding-models` | Main evaluation script |
| `libs/model-evaluator.lua` | Comparison algorithms |
| `output/model-evaluation/` | Evaluation output directory |
| `docs/embedding-model-analysis.md` | Findings documentation |

## Metrics to Compute

### Rank Correlation
- **Kendall's Tau**: Measures agreement in pairwise orderings
- **Spearman's Rho**: Correlation of rank positions
- **Top-K Agreement**: Do models agree on the top 10/50/100 similar poems?

### Divergence Analysis
- **Maximum Disagreement**: Poems ranked very differently by different models
- **Consistent Agreement**: Poems all models agree are similar/different
- **Outlier Detection**: Poems one model ranks very differently than others

### Text Feature Correlation
- Correlate similarity scores with:
  - Word count
  - Vocabulary complexity (unique words / total words)
  - Part-of-speech distribution
  - Sentiment scores
  - Topic keywords

## Open Questions

### Methodological
- How many anchor poems are needed for statistically meaningful comparison?
- Should anchors be manually curated or algorithmically selected for diversity?
- How to weight disagreements (rank 1 vs 2 more important than rank 500 vs 501)?

### Interpretation
- Can we identify which embedding dimensions correspond to which text features?
- Is there a way to visualize model "attention" on specific words/phrases?
- How stable are rankings across minor text variations (typo correction, punctuation)?

### Practical
- Should we cache embeddings for all models to enable quick re-comparison?
- How to handle models with different embedding dimensions (768 vs 1024)?
- Can we create a "meta-model" that combines insights from multiple models?

### Research Extensions
- Could we fine-tune a model specifically for poetry similarity?
- What would ground-truth "human similarity judgments" look like for validation?
- Are there model characteristics that predict better "exploration experience"?

## Related Documents

- Issue 12-002: Investigate dual-axis similarity (theme and style)
- Issue 10-017: Multi-Ollama server configuration (model selection infrastructure)
- `libs/ollama-config.lua`: Model configuration
- `docs/effil-vs-compute-shader-feasibility.md`: Performance considerations

## Example Analysis Output

```
═══════════════════════════════════════════════════════════════════════════════
                    Embedding Model Comparison Report
═══════════════════════════════════════════════════════════════════════════════

Anchor: "the silence between stars" (poem_index: 4521)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                    nomic-embed-text          mxbai-embed-large
                    ────────────────          ─────────────────
Rank 1:             "frequencies beyond"      "deaf ocean tells"
Rank 2:             "radio static holds"      "memory fades like"
Rank 3:             "deaf ocean tells"        "frequencies beyond"
...

Kendall's Tau:      0.73 (moderate agreement)
Top-10 Agreement:   6/10 poems shared
Top-50 Agreement:   34/50 poems shared

Maximum Disagreement:
  "memory fades like starlight" - nomic: #47, mxbai: #2 (Δ45 ranks)
  Analysis: mxbai connects "stars/starlight" metaphorically;
            nomic treats them as different concrete nouns

Model Personality Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
nomic-embed-text:
  ✓ Strong at: Technical/scientific vocabulary, word-level matching
  ✗ Weak at: Metaphorical connections, abstract themes
  Bias: Favors longer poems (+0.03 similarity per 10 words)

mxbai-embed-large:
  ✓ Strong at: Semantic parallelism, metaphor recognition
  ✗ Weak at: Technical jargon, code-like text
  Bias: More balanced across poem lengths

Recommendation: Use mxbai-embed-large for poetry exploration (better metaphor
handling), nomic-embed-text for technical/structured text search.
```

---

## Implementation Log

(To be filled during implementation)
