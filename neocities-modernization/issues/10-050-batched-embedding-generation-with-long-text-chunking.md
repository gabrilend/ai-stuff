# Issue 10-050: Batched Embedding Generation With Long-Text Chunking

## Current Behavior

Every embedding goes out as its own HTTP request. The hot loop is
roughly: read one poem → `inference_config.format_embedding_prompt(text)`
→ shell out to `curl` via `io.popen` → POST one input → wait for one
response → parse one vector → write to cache. The same shape appears in
five call sites (see Related Documents). Each request pays for fork +
exec(curl), TCP setup, JSON ser/deser, one llama.cpp forward pass, and
process teardown. The forward pass is single-digit percent of that wall
time; the rest is per-request overhead.

For long texts (poems that exceed the embedding model's context window —
2048 tokens for nomic-embed-text v1.5), behavior diverges by call site:

- `src/centroid-generator.lua` has `generate_embedding_with_chunking`,
  which recursively splits text at paragraph (`\n\n`) and then line
  (`\n`) boundaries when a single embedding call fails. Each chunk is
  embedded separately; downstream code receives a *list* of vectors and
  treats them as a multi-vector centroid (no combination step — the
  centroid concept naturally handles multiple vectors).
- Every other consumer (poem embeddings, word embeddings, color
  embeddings, similarity-engine embeddings) sends the whole text in
  one request and either errors out or silently truncates. There is no
  chunk-and-recombine path for the "one vector per item" use cases.

  The error-vs-truncate boundary is set by the server's `--ubatch-size`
  (the largest input, in tokens, that fits one physical batch). It was
  raised from llama-server's default of 512 (~2048 chars) to 8192
  (~32k chars) in `scripts/start-llamacpp-server.sh` to match the
  known-good words-pdf launcher. Effect on the current ~8361-poem corpus:
  the 27 poems over ~2048 tokens are now accepted but TRUNCATED by the
  model (nomic's context caps at 2048 tokens regardless of ubatch); the
  2 poems over ~8192 tokens still error. Both populations are exactly the
  case this issue's chunk-and-recombine path is meant to handle properly.
  Cranking ubatch higher is the wrong fix — a larger single dispatch means
  a longer GPU kernel, which is counterproductive on a display-driving
  Pascal card. Chunking into <=2048-token pieces keeps each kernel short.

Observed embedding throughput on the 1080 Ti, against the
nomic-embed-text v1.5 GGUF served by `llama-server`: ~10–20 embeddings/sec,
dominated by per-request overhead.

### Implemented offline; live verification is the only thing left

All five embedding call sites now go through the shared batched primitive; the
per-item curl implementations are deleted (one code path to /v1/embeddings).
What remains is running it against a live server (the GPU box under freeze
triage) — see the verification note at the end of this section.

Implemented and unit-tested offline:
- `libs/text-chunking.lua` — `chunk_text_for_embedding` (lossless recursive
  split at paragraph > sentence > line > word, char-length based) and
  `combine_chunk_vectors` (length-weighted mean / mean / first-only). Tests in
  `libs/text-chunking-test.lua` (12 checks, no server needed).
- `libs/fuzzy-computing.lua` — `get_embeddings_batch(texts, model, endpoint,
  format_fn)` sends one array request, returns vectors aligned to input order
  (via OpenAI's 0-based `data[].index`). `embed_texts_with_chunking` +
  `_embed_with_chunking_impl` chunk each text, flatten across the batch, embed
  in `BATCH_SIZE`-bounded sub-requests, and recombine per text. `get_embedding`
  is now a one-input shim. The flatten/distribute/recombine core is tested with
  a mock embedder in `libs/embed-chunking-test.lua` (18 checks). Live smoke test
  in `libs/fuzzy-computing-batch-test.lua` (skips cleanly when no server is up).
  Chunk sizing uses EXACT token counts: `chunk_text_by_tokens` sizes each chunk
  by an injected `count_fn`, which in production calls llama-server's `/tokenize`
  endpoint (`fuzzy.tokenize_count`) — so a chunk is provably within the model's
  context with no truncation risk, even on dense/non-English text the char
  heuristic mis-sizes. The per-chunk budget is COMPUTED, not guessed:
  `fuzzy.embedding_chunk_budget` = model context (2048) − BERT specials (2) −
  the tokenized task prefix. There is no estimate fallback: if `/tokenize` is
  unreachable the counter raises (the embed call would fail next anyway). All
  embedding chunkers use this path — the poem loop, the word-cloud loop, AND
  `src/centroid-generator.lua` (which kept its own recursive char splitter until
  now). Sizing is token-exact end to end: there is NO character heuristic left
  anywhere. `chunk_text_by_tokens` returns each chunk's exact token count as a
  byproduct, and request packing (`REQUEST_TOKEN_BUDGET`) reuses those exact
  counts — the old `estimate_tokens` (chars/4) and the entire char-based
  `chunk_text_for_embedding` path are deleted. Every chunk is tokenized once and
  that count drives both the context-fit decision and request packing.
  Requests are then bounded by a TOKEN budget (`REQUEST_TOKEN_BUDGET`, not a flat
  item count); a failed request leaves its items nil and the poem path single-
  retries them. Both were real defects found against the long-poem tail of the
  corpus: a fixed 16-item batch of near-max chunks made one request carry ~16× a
  single chunk's load, which stalled past the client timeout and cascaded.
- `src/similarity-engine.lua` (`generate_all_embeddings`, the ~8000-poem loop) —
  rewired: each window of poems is partitioned into normal-text poems (embedded
  as one batched + chunked call) and deferred poems (image-only inherit / empty
  random, handled after so same-window neighbours are inheritable). Network
  error thresholds + backoff, the count-only progress file, periodic cache
  checkpoints, and the exact success/error record shapes (Issue 8-019 keys) are
  all preserved. Chunking params are recorded under `metadata.chunking`.
  endpoint + prompt-prefix are threaded through so this file's config instance
  stays authoritative (fuzzy-computing loads the config under a different module
  key = a separate instance).

Also rewired to the shared primitive:
- `src/generate-word-pages.lua` — collects all cache-missing words and embeds
  them in one `embed_texts_with_chunking` call (was one curl per word).
- `src/semantic-color-calculator.lua` — `generate_color_embeddings` embeds all
  color words in one `get_embeddings_batch` call (was a per-color loop + 0.5s
  sleeps). `generate_single_embedding` deleted.
- `src/centroid-generator.lua` — its bespoke recursive binary chunker
  (`find_safe_split_point` + recursive `generate_embedding_with_chunking`) and
  single-input curl (`generate_embedding`) are deleted; it now uses the shared
  chunker + one batched request per centroid, still returning the LIST of
  per-chunk vectors that `calculate_ultra_centroid` folds into one centroid
  (its distinct "many vectors per centroid" semantics are preserved).

All consumers thread their own endpoint + prompt-formatter into the primitive,
so fuzzy-computing's separate inference-server-config instance is never consulted
for server selection.

Documentation gap (pre-existing, not introduced here): none of the modified
source files had `.info.md` companions; only the new `libs/text-chunking.lua`
got one. Retrofitting the rest is left as separate documentation work.

Cannot yet be verified end-to-end: every networked path. The inference server
is down (the GPU box under freeze triage). Verification steps once it is back up:
1. `luajit libs/fuzzy-computing-batch-test.lua` — exercises the batch round trip.
2. A small `./run.sh --generate-embeddings` slice — confirms the poem loop.
The ~29 long poems will now produce chunk-and-recombined vectors instead of
truncated ones, so the similarity + diversity caches must be regenerated after.

Deviation from the plan below: the cache stores only the COMBINED vector per
poem (plus `metadata.chunking`), not the per-chunk vectors. Re-combining under a
different strategy therefore requires re-embedding. Storing per-chunk vectors to
make strategy changes cheap is deferred — it only benefits the ~29 poems long
enough to chunk, and it would change the per-record shape that downstream
readers depend on.

## Intended Behavior

A single HTTP request carries a batch of N inputs to llama-server's
`/v1/embeddings` endpoint (the OpenAI shape, which accepts a string OR
a string-array as `input`). The server batches the N inputs in one GPU
forward pass, returns `data[0..N-1].embedding`. One round trip per N
items instead of N round trips. GPU utilization rises from "barely
warm" to "actually working."

Texts that exceed the model's context window are detected before being
sent. They are recursively split at semantic boundaries (paragraphs,
then sentences, then lines) using the same algorithm the centroid
generator already uses. The chunks of one poem are packed into the
same batch alongside other poems' single-chunk texts; after the
response comes back, chunks belonging to the same poem are combined
into a single vector via length-weighted mean pooling (see "Combining
Strategy" below). The downstream cache and consumers continue to see
exactly one vector per poem.

Throughput target: ~150–200 embeddings/sec on the 1080 Ti at batch
size 16, an order of magnitude improvement. Generating embeddings for
the project's ~8000 poems drops from ~13 minutes to ~1–2 minutes.

The cache format is unchanged: `embeddings.json` still has one vector
per item, keyed by item ID. Only the *generation path* changes.

## Suggested Implementation Steps

### Batched request primitive

1. Add `M.get_embeddings_batch(texts, model)` to `libs/fuzzy-computing.lua`,
   alongside the existing `M.get_embedding`. Inputs: a Lua array of
   strings. Output: a Lua array of vectors, in the same order. Internally:
   - `format_embedding_prompt` each text in turn (the per-item task prefix
     is applied per-item, not per-batch)
   - Encode the request body with `input = prefixed_array`
   - POST to `/v1/embeddings`
   - Walk `response.data[]`, return `{response.data[i].embedding}` in order
2. Keep `M.get_embedding` as a one-line shim that calls
   `get_embeddings_batch({text}, model)[1]`. Old call sites keep working
   during the rollout; new call sites use the batch entry point directly.

### Long-text chunking

3. Add `M.chunk_text_for_embedding(text, max_tokens)` to a new
   `libs/text-chunking.lua` (extracted from `centroid-generator.lua`'s
   internal helpers so all consumers can share it).
4. Decision: tokenizer-aware vs character-count heuristic. Default to
   character-count (~4 chars per token for English) with a configurable
   safety factor, because:
   - Avoids a Lua dependency on the GGUF tokenizer
   - Errs on the side of over-chunking, which is the safe direction
     (smaller chunks always fit; over-large chunks fail loudly)
   - The user can pass `--token-aware` later if more precision matters
5. Split priority: paragraph (`\n\n`) > sentence (`. ` followed by
   uppercase) > line (`\n`) > word (any whitespace). Recursive until
   every chunk fits.

### Chunk packing and recombination

6. `M.get_embeddings_batch` accepts an OPTIONAL companion array of
   item IDs paralleling `texts`. Without IDs, treats each input as
   one item. With IDs, multiple inputs with the same ID are recognized
   as chunks of the same logical item and their vectors are combined
   before the result table is built.
7. Combining strategy (see "Combining Strategy" section): default
   length-weighted mean. Configurable via a `combine` parameter.

### Cache integration

8. The cache-skip filter runs BEFORE the batch is built. Items already
   present in the cache do not enter the batch. The result is merged
   with the cached vectors so downstream consumers see the union.
9. Cache invalidation marker: the chunking threshold (max_tokens) and
   combining strategy are part of the cache metadata so a tuning
   change invalidates the cache rather than producing silently-mixed
   vectors.

### Error handling

10. If the server returns 422 on a batch (input rejected), bisect the
    batch and retry the halves. The offending input is isolated in O(log N)
    bisections. The offending input itself gets recursively chunked.
11. If one entry in `response.data[]` is missing or has zero-length
    embedding, route THAT item to a single-item retry. Do not fail the
    whole batch.
12. Network errors retry the whole batch with exponential backoff
    (existing logic from `libs/fuzzy-computing.lua` can be lifted).

### Call-site refactor

13. The five consumers each grow a "collect a batch, send it, distribute
    results" wrapper around their existing per-item logic. See Related
    Documents for the file list. The order of refactor:
    1. `libs/fuzzy-computing.lua` (the helper)
    2. The poem-embedding loop driven from `generate-embeddings.sh` —
       this is the highest-impact consumer (8000+ items)
    3. `src/generate-word-pages.lua` (word-cloud embeddings, ~200 items)
    4. `src/centroid-generator.lua` (~tens of centroids, biggest individual
       texts — keep its existing "many vectors per centroid" semantics
       distinct from "one vector per poem")
    5. `src/similarity-engine.lua` (per-word similarity calls)
    6. `src/semantic-color-calculator.lua` (only ~7 colors; minimal payoff)

### Tunables (constants near the top of `libs/fuzzy-computing.lua`)

14. `BATCH_SIZE` — start at 16, document the VRAM/throughput trade-off.
15. `MAX_TOKENS_PER_INPUT` — start at 1800 (1800 × 4 chars/token = 7200 chars,
    fits comfortably under the 2048-token context window).
16. `CHARS_PER_TOKEN` — heuristic for length estimation; 4 for English.
17. `CHUNK_COMBINE_STRATEGY` — "length_weighted_mean" (default) | "mean" |
    "first_only".

## Combining Strategy

For a poem that splits into chunks A, B, C with vectors v_A, v_B, v_C
and character lengths len_A, len_B, len_C:

- **`length_weighted_mean` (default)**: `(len_A·v_A + len_B·v_B + len_C·v_C) / (len_A + len_B + len_C)`.
  Longer chunks contribute more to the final vector, which matches
  intuition: a chunk that holds more text holds more meaning. This is
  the recommendation for poetry where stanzas vary in length.
- **`mean`**: `(v_A + v_B + v_C) / 3`. Equal weight per chunk regardless
  of size. Simpler; appropriate if all chunks are roughly equal length
  (which the chunking algorithm tries to produce anyway).
- **`first_only`**: `v_A`. Drops later chunks. Useful if the opening of a
  poem is its semantic anchor (a common pattern), but throws away the
  rest of the text.

Each is one normalization step away from the others, so a poem can be
re-combined under a different strategy without re-embedding — useful
for experimentation. The cache stores the per-chunk vectors and the
combined result is computed on read; OR (alternative) the cache stores
only the combined result. Decision: cache the per-chunk vectors AND
the combined, so strategy changes are recombinable without regenerating.

`max_pool` (per-dimension max) was considered and rejected: not
theoretically justified for cosine-similarity downstream consumers,
and produces vectors that drift from the model's training distribution.

## Related Documents

Files this issue touches:
- `libs/fuzzy-computing.lua` — single helper grows a batch-aware sibling
- `src/centroid-generator.lua` — has the precedent chunking pattern in
  `generate_embedding_with_chunking`; we will extract that into a shared
  module and the centroid generator will switch to it
- `src/similarity-engine.lua` — per-call site refactor
- `src/generate-word-pages.lua` — per-call site refactor
- `src/semantic-color-calculator.lua` — per-call site refactor (low payoff)
- `generate-embeddings.sh` — orchestrates the poem-embedding loop; the
  highest-impact place to wire batching
- `config.lua` — `inference_servers` entries gain a `batch_size` field
  if we want per-server tuning (large GPU = bigger batch)

Connected issues:
- `issues/completed/8-008-implement-configurable-centroid-embedding-system.md`
  established the recursive-chunking precedent for long centroid sources.
- `issues/10-049-replace-ollama-with-llamacpp.md` produced the
  OpenAI-shaped `/v1/embeddings` endpoint this batches against. With Ollama
  the same approach would have worked via `/api/embed` (which already took
  array inputs), but the throughput ceiling was lower because Ollama added
  its own queueing layer.
- `issues/10-031-embedding-model-evaluation-framework.md` is adjacent —
  evaluating different models for embedding quality. Batched embedding
  generation makes that evaluation cheap enough to actually run.

## Risks

- **VRAM pressure at large batches.** llama-server's `--parallel N`
  multiplies the KV cache by N. Pure batched-array calls go through one
  slot, so VRAM is bounded by the largest single batch's input tokens.
  On the 1080 Ti (11 GB), batch size 64 with 1800 tokens each is
  ~115k tokens × ~2 KB per token = ~230 MB of KV cache; safe. Smaller
  GPUs may need batch_size lowered.
- **Length-estimation drift.** Character-count is a heuristic. A poem
  with unusual Unicode (CJK, emoji-dense) may underestimate token count.
  Mitigation: if a batch returns 422, bisect and retry; the chunking
  algorithm will produce smaller pieces on the retry.
- **Cache invalidation.** Embeddings produced under different chunking
  thresholds are not bit-identical and may not even be cosine-close to
  ones produced under the new chunking. The cache should be invalidated
  on threshold changes. A safer pattern: store the chunking parameters
  alongside the cache so a load-time mismatch triggers regeneration.
- **Determinism across re-runs.** Same input + same chunking algorithm
  produces the same chunks, but the combination step's output depends on
  the strategy. Switching strategies invalidates downstream consumers
  (similarity matrix, diversity cache, color-poem mapping). Treat
  strategy as a project-level constant once chosen.

## Expected Outcome

- `libs/fuzzy-computing.lua` exposes a `get_embeddings_batch` function
  callers use directly.
- The poem embedding stage (driven by `generate-embeddings.sh`) runs
  ~10× faster end-to-end on the same model and hardware.
- Long poems that previously errored out or were silently truncated now
  produce well-defined, deterministic vectors.
- A new `libs/text-chunking.lua` holds the chunking algorithm, replacing
  the duplicate in `centroid-generator.lua`.
- Cache format unchanged externally; internally augmented with chunking
  parameters so invalidation is detectable.
- The `inference_servers` config schema may grow an optional `batch_size`
  field for per-server tuning.
