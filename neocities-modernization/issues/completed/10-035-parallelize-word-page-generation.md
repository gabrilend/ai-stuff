# 10-035: Parallelize Word Page Generation

## Current Behavior

**All three steps built (2026-10-22); its question answered; completed 2026-10-25.**
- Centre once: `embedding-space.centre_once` / `cosine_centred`; the poems
  are prepared once per run, each word once. The centre-poem search keeps
  each poem's length too, and walks the poems in an order worked out once
  (it re-sorted all 8,622 keys for every word). Scores are the same to the
  last bit (tested on 50 random pairs); 200 pages byte-identical.
- Worker jobs: `src/generate-word-pages.lua` plans each page (poems, order,
  heading colour, centre link) and
  `flat-html-generator.generate_word_pages_on_workers` has the page workers
  draw them through `src/word-page.lua`. The jobs carry their poems, as the
  chronological jobs do: the workers' own poem list marks image-only posts
  to be drawn as a gallery picture box, which drew 11 of 200 pages
  differently (see the open question). `--threads` added, passed by
  `run.sh` stage 10 and `scripts/render-page-sample`. 200 pages
  byte-identical; 60 sample word pages identical to the last render.
- GPU ranking: `libs/vulkan-compute/lua/vk_cross.lua` runs
  `shaders/similarity_cross.comp`, every word against every poem in one
  dispatch (200 x 8,622 scores). Each word keeps a shortlist -- every poem
  within 0.0001 of its 50th-best GPU score (`shortlist`) -- and scores only
  those exactly on the CPU. The GPU's single-precision scores differ from the
  exact ones by about a millionth, so the shortlist always holds the exact
  top list, ties included: 200 pages byte-identical. `run.sh` stage 10 now
  checks for the GPU library and shader, as stages 7 and 8 do.
- Three quiet fallbacks became errors: a word with no recorded colour (grey
  heading), a page with no centre poem (link to the top of the timeline), a
  word with no vector (page skipped with a warning). None fired on 200 words.
- Time for 200 words: 32 s → 18 s. Left: ~13 s reading the 129 MB vector
  file (the JSON reader), well under a second on the GPU, 2 s drawing on 4
  workers. Reading the vectors from a binary file would cut the 13 s; the
  half-precision file the diversity step writes is not exact enough to give
  the same pages.
- Tests: `libs/embedding-space.test.lua` (centred score),
  `libs/vk-cross.test.lua` (GPU against CPU), `src/word-page.test.lua`
  (module and worker job), `src/generate-word-pages.order.test.lua` (order
  rules and the shortlist).

### Answered question
- **Answered (owner, 2026-10-22, recorded in Issue 9-013):** "I think every
  post with pictures should follow the example in the right column, the one
  with all the extra information." Every page now draws an image-only post
  as the ordinary post it is; the picture box is only for gallery pictures.
  The question, as asked:
- The workers' poem list tags image-only posts (a post that is only a
  picture, 84 in the current manifest) to be drawn as a gallery picture box
  titled "fediverse: image post", and that box's picture description is that
  title rather than the post's own description. The similar and different
  pages draw them that way; the chronological and word pages (whose jobs
  carry plain poems) draw them as ordinary posts with their own picture
  description. Which way should every page draw them? (Issue 9-013.)

Measured 2026-10-21 (EmbeddingGemma 2, 8,622 poems, 200 words, 50 poems a
page): 32 s.
- ~13 s loading, once: the 129 MB poem-vector file, the two averages, the
  timeline.
- ~0.08 s per word ranking: every poem against the word, each poem vector
  re-centred on the poem average for every word (the same subtraction done
  200 times).
- ~0.013 s per word drawing 50 poems and writing the page.

## Intended Behavior

Owner, 2026-10-22, choosing three of the four options in 8-058:
"let's do these three", and on what one pipeline means: "we want both. If
the other 'worker queue' implementations aren't running in parallel, then we
need to update them to do so." So: every page passes through the one worker
queue, and the batch work runs in parallel.

1. **Centre once.** Every poem vector is centred on the poem average and its
   length taken once per run; every word is centred on the word average once.
   A word's score against a poem is then one dot product divided by the two
   lengths -- the same number `cosine_across_populations` gives, without
   repeating the subtraction for every word.
2. **Rank every word at once on the GPU.** All words against all poems is one
   rectangular table of dot products (words x poems), a new compute shader
   beside the all-pairs similarity shader in `libs/vulkan-compute/`. The
   build ranks on the GPU; the CPU version of step 1 stays in a test as the
   reference the GPU's numbers are checked against (not a second runtime
   path).
3. **Word pages are worker jobs.** The main program ranks, picks each page's
   poems, spreads the colours and finds the centre poem, then hands out one
   job per word: the word, its colour, the centre link, and the page's poems
   in order (numbers, timeline progress, chronological page). The page
   workers (`run_page_workers` in `src/flat-html-generator.lua`) draw and
   write them, beside "a poem's pages" and "a chronological page"; the page
   shell moves to `src/word-page.lua` so a worker can load it.

## Suggested Implementation Steps

1. Step 1 (centre once), in `generate_word_html`; render 60 word pages
   before and after (`scripts/render-page-sample --words 60
   --poems-per-word-page 50 --copy-pictures`) and compare; differences only
   where two scores were within rounding of each other.
2. Step 3: `src/word-page.lua` (page shell, one entry), a `word_page` job in
   the worker pool, a thread count for the word-page step (`--threads`,
   passed by `run.sh` stage 10 and by the render tool). Byte-identical to
   step 1's pages.
3. Step 2: shader `similarity_cross.comp`, a C entry point and a Lua binding
   that take two sets of centred, unit-length vectors and return the table of
   dot products; the word-page step ranks from it. A test compares the GPU's
   table with the CPU reference to within half-precision rounding.
4. Tests: the order test (`src/generate-word-pages.order.test.lua`) still
   passes; a new test for the centred score against
   `cosine_across_populations`; the pool test for a `word_page` job.

## Earlier analysis (2026, before the owner's decision of 2026-10-22)

### Key Difference from Poem Page Parallelization

**Poem pages** (Issue 10-034):
- Work slice = 80KB (pre-computed ranking for one poem)
- Rankings are pre-cached, just need lookup

**Word pages** (this issue):
- No pre-computed cache exists
- Each word needs similarity against ALL poems
- Work = word + word_embedding, workers compute similarity on-the-fly

## Proposed Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MAIN THREAD (ORCHESTRATOR)                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ word_embeddings: { "word": [768 floats], ... } (~30MB)       │   │
│  │ word_colors: { "word": {color: "blue"}, ... } (~1MB)         │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                  │                                   │
│                    ┌─────────────┴─────────────┐                    │
│                    │    Request Handler Loop   │                    │
│                    │  - Send word + embedding  │                    │
│                    │  - Track completion       │                    │
│                    └─────────────┬─────────────┘                    │
└──────────────────────────────────┼──────────────────────────────────┘
                                   │ effil channels
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐
│    WORKER 1       │  │    WORKER 2       │  │    WORKER 3       │
│ ┌───────────────┐ │  │ ┌───────────────┐ │  │ ┌───────────────┐ │
│ │ poems.json    │ │  │ │ poems.json    │ │  │ │ poems.json    │ │
│ │ poem_embeddings│ │  │ │ poem_embeddings│ │  │ │ poem_embeddings│ │
│ │ poem_colors   │ │  │ │ poem_colors   │ │  │ │ poem_colors   │ │
│ │   ~90MB       │ │  │ │   ~90MB       │ │  │ │   ~90MB       │ │
│ ├───────────────┤ │  │ ├───────────────┤ │  │ ├───────────────┤ │
│ │ Current Work  │ │  │ │ Current Work  │ │  │ │ Current Work  │ │
│ │ - word        │ │  │ │ - word        │ │  │ │ - word        │ │
│ │ - embedding   │ │  │ │ - embedding   │ │  │ │ - embedding   │ │
│ │   ~3KB        │ │  │ │   ~3KB        │ │  │ │   ~3KB        │ │
│ └───────────────┘ │  │ └───────────────┘ │  │ └───────────────┘ │
│  Compute similarity│  │  Compute similarity│  │  Compute similarity│
│  Sort & select     │  │  Sort & select     │  │  Sort & select     │
│  Generate HTML     │  │  Generate HTML     │  │  Generate HTML     │
└───────────────────┘  └───────────────────┘  └───────────────────┘
```

## Memory Comparison

| Component | Current | With Orchestrator (4 threads) |
|-----------|---------|-------------------------------|
| Main thread | ~90MB | ~35MB (words + word_colors only) |
| Per worker | N/A | ~90MB (poems + embeddings + colors) |
| Total | ~90MB | ~395MB |

Note: Memory increases with parallelization because workers need poem embeddings.
Trade-off is speed vs memory.

## Alternative: Pre-compute Word Rankings Cache

Could create `word_similarity_cache.json`:
```json
{
  "rankings": {
    "love": [4521, 2301, 8732, ...],  // poem indices sorted by similarity
    "time": [1234, 5678, ...],
    ...
  }
}
```

- Cache size: 7,135 words × 8,275 integers × 4 bytes ≈ 236MB
- One-time computation cost: ~5-10 minutes with GPU
- Parallelization then matches poem page approach (80KB slices)

## Implementation Steps

### Option A: On-the-fly Parallel (simpler, more memory)

1. Modify `generate_all_word_pages()` to accept `num_threads` parameter
2. Add effil thread detection (copy from flat-html-generator.lua)
3. Create work request/response channels
4. Worker loads: poems.json, embeddings.json, poem_colors.json
5. Orchestrator sends: word + word_embedding + word_color
6. Worker computes similarity, generates HTML

### Option B: Pre-compute Cache (faster, less memory per run)

1. Create `scripts/generate-word-rankings` using GPU
2. Store rankings in `word_similarity_cache.json`
3. Modify word page generator to use cache
4. Parallelize like poem pages (send ranking slice, not embeddings)

## Related Documents

- Issue 10-034: Lazy loading orchestrator for parallel HTML (completed)
- Issue 8-058: one page drawer, one worker queue (the word pages joined the drawer 2026-10-21)
- Issue 10-074: every batch step runs in parallel (this is its step 1)
- `src/generate-word-pages.lua`: Current sequential implementation
- `src/flat-html-generator.lua:3162-4231`: Orchestrator pattern reference


