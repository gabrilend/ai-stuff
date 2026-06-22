# text-chunking.lua

Shared long-text chunking and chunk-vector recombination for embedding
generation (Issue 10-050). Pure functions — no network, no files — so they are
unit-testable without an inference server (`luajit libs/text-chunking-test.lua`).

Embedding models have a fixed context window (nomic-embed-text v1.5 = 2048
tokens); a longer poem is otherwise rejected or silently truncated. This module
splits a too-long text at meaningful boundaries, and folds the resulting
per-chunk vectors back into one vector per poem. Chunk sizing is **token-exact** —
there is no character estimate anywhere (an estimate can undercount dense text
and silently overflow the context).

## External functions

### `chunk_text_by_tokens(text, count_fn, max_tokens) -> chunks, counts`
Split `text` into chunks each at most `max_tokens` tokens, preferring to cut at
paragraph > sentence > line > word boundaries, with a hard token split as last
resort. Returns two parallel arrays: the chunk strings and their **exact token
counts** (a free byproduct of sizing, so callers never re-estimate).
- `count_fn(string)` must return the string's exact token count under the model's
  tokenizer. It is injected, so the algorithm stays a pure function (production
  passes a `/tokenize`-backed counter via `fuzzy.make_token_counter`; tests pass a
  deterministic mock).
- `max_tokens` is **required** — compute it exactly with
  `fuzzy.embedding_chunk_budget` (model context − BERT specials − tokenized
  prefix). There is no guessed default; passing `nil` raises.
- A text that already fits returns a one-element array. Empty/whitespace-only
  input returns `({}, {})`.
- **Invariant:** lossless — `table.concat(chunks) == text`.

### `combine_chunk_vectors(vectors, weights, strategy) -> vector`
Fold one poem's per-chunk vectors into a single vector.
- `vectors` — array of equal-length number arrays.
- `weights` — per-chunk weights (chunk char lengths for the default strategy);
  optional, ignored by `mean`/`first_only`.
- `strategy` — `"length_weighted_mean"` (default) | `"mean"` | `"first_only"`.
- Returns `nil` for no input; returns a single vector unchanged.
- Raises an error on a chunk whose dimension differs from the first (no silent
  blending of malformed vectors).

## Tunables
- `SEPARATORS` — boundary priority list: `{"\n\n", ". ", "\n", " "}`.

The per-chunk token budget is **not** a constant here — it is computed at the
call site by `fuzzy.embedding_chunk_budget` as `MODEL_CONTEXT_TOKENS (2048) −
EMBED_SPECIAL_TOKENS (2) − tokens(prefix)`, so there is no guessed headroom.

## Related
- `libs/fuzzy-computing.lua` — `embed_texts_with_chunking` calls this, packing the
  resulting chunks into token-budgeted `/v1/embeddings` requests using the exact
  counts returned here. `make_token_counter` / `embedding_chunk_budget` supply the
  counter and budget.
- `src/centroid-generator.lua`, `src/similarity-engine.lua`,
  `src/generate-word-pages.lua` — all embedding chunkers use this one path.
- `issues/10-050-batched-embedding-generation-with-long-text-chunking.md`.
