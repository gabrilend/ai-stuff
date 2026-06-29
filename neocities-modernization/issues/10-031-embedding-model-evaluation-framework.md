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

Currently using: `nomic-embed-text-v1.5` (768 dimensions, served locally by
llama.cpp per Issue 10-049; the Ollama era this issue was first written against
is gone). The `--model` CLI flag now propagates correctly to every stage via the
per-run overrides notepad (model-propagation bugfix), so a model swap lands its
caches in the right per-model directory.

Three models are being compared in the first implementation of this framework
(the GGUF files live in `assets/models/`):
- `nomic-embed-text-v1.5` (768 dims; clustering task-prefix `"clustering: "`)
- `mxbai-embed-large-v1` (1024 dims; no task prefix — symmetric similarity)
- `embeddinggemma-300m` (768 dims; clustering prompt `"task: clustering | query: "`)

Each model is registered in `src/similarity-engine.lua`'s model table (dimensions)
and as a local `inference_servers` entry in `config.lua` (its GGUF `model_path`
plus the clustering-appropriate `embedding_prompt_prefix`, so each model is used
the way its makers intend for similarity — a fair comparison, not an accidental
prefix mismatch).

Other models considered and deferred (kept here for the record):
- A non-neural lexical/TF-IDF baseline (the clearest way to see "structure vs
  semantics", since every transformer is semantic) — not built this round.
- `Qwen3-Embedding-0.6B` (instruction-tunable: A/B "theme" vs "style" prompts).
- `bge-large-en-v1.5` / `e5-large` (a different retrieval lineage).

## Intended Behavior

Create a framework for systematically evaluating and comparing embedding models to understand:

1. **What each model "values"** - Semantic meaning? Word choice? Sentence structure? Length?
2. **Model "personality"** - Does it emphasize verbs? Nouns? Abstract concepts? Concrete imagery?
3. **Similarity interpretation** - What makes two poems "similar" according to each model?
4. **Diversity interpretation** - What makes poems "maximally different"?

### Decided Scope (2026-06-29 — first implementation)

To get a usable comparison without embedding the whole corpus three times:
- **Sample**: ~500 poems chosen from `assets/poems.json` with the project's
  seeded RNG (Issue 10-058), so the sample — and therefore the comparison — is
  reproducible. Every candidate a model can rank "most similar" must be embedded
  in that model's space, so the sample IS the candidate pool.
- **Anchors**: ~8 poems picked from the sample to span the characteristic table
  below (short/long, abstract/concrete, emotional, question-heavy, etc.).
- **Per model**: start the local llama.cpp server on that model's GGUF, embed the
  500 sample poems (with the model's clustering prompt), stop it, move to the next.
  Only anchor-vs-sample rankings are needed — NOT the full O(N^2) matrix or the
  diversity cache — so this is cheap and does not touch the live site's caches.
- **Deliverable**: `output/model-evaluation/comparison-report.html` — for each
  anchor, three columns (one per model) of the top-K most similar poems with
  scores, the agreements/divergences highlighted, the rank-correlation metrics,
  and a DATA-DRIVEN personality blurb per model (e.g. mean word-count delta and
  lexical Jaccard between an anchor and its top matches — surface vs semantic).

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

| File | Purpose | Status |
|------|---------|--------|
| `scripts/evaluate-embedding-models` | Bash orchestrator: select sample, start a server per model, embed, build report | done |
| `src/model-comparison.lua` | Data + report layer (`select` / `embed` / `report` subcommands) | done |
| `libs/model-evaluator.lua` | Pure comparison + personality stats (cosine, rank, Kendall tau, lexical Jaccard) | done |
| `output/model-evaluation/` | Evaluation output (sample.json, per-model embeddings, comparison-report.html, metrics.json) | generated |
| `docs/embedding-model-analysis.md` | Findings documentation | pending (write after reading the first report) |

### Build prerequisites discovered during implementation

- **llama.cpp rebuild.** EmbeddingGemma uses the `gemma-embedding` architecture,
  added to llama.cpp ~Sept 2025. The pinned binary was `b4404` (early 2025) and
  failed to load the GGUF with "unknown model architecture". `scripts/build-deps.sh`
  was bumped to `b9842` and gained `-DLLAMA_BUILD_TOOLS=ON` (upstream moved the
  server/cli/embedding binaries from `examples/` to `tools/` across that range).
  The CUDA build hit a gcc-14 ICE (segfault in the VRP pass on `peg-parser.cpp`)
  under 8 parallel jobs — an out-of-memory death; `BUILD_JOBS=1` resolved it.
- **Context limits + chunking.** `mxbai-embed-large` is BERT-large with a 512-token
  context; long poems exceed it and the server returns
  `exceed_context_size_error`. The embed step therefore uses
  `fuzzy.embed_texts_with_chunking` (Issue 10-050), which splits to the loaded
  model's budget and averages chunk vectors — nomic/gemma (~2048 ctx) embed whole.
- **Prompt-prefix fairness.** Each model's `inference_servers` entry carries the
  clustering-appropriate prefix (nomic `"clustering: "`, gemma
  `"task: clustering | query: "`, mxbai none) so all three are asked the same
  question the way their makers intend — not an accidental mismatch.

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
