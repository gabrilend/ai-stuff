# Issue 029: HDBSCAN-Driven Theme Discovery Pipeline

## Current Behavior

`compile-pdf-ai.lua` selects per-page and per-poem visual themes by
embedding hand-written theme **descriptions** (lines 483–577) and
ranking each page/poem embedding against them by cosine similarity.
The current descriptions are a mix of two sources:

- Ten themes produced by an LLM consolidation pass over a
  September-2025 analysis of the corpus (see `theme-analysis/`,
  which is incomplete — 12/40 slices recorded as processed,
  several `analysis_NNN.analysis` files are just the placeholder
  `ANALYSIS_FAILED`).
- Twelve "simple themes" merged in from `art-themes.json` (nature,
  urban, energy, love, melancholy, dream, constellation, spiral,
  circuit, lightning, crystal, neutral) — generic art-system
  primitives, not derived from this corpus at all.

The result is exactly the failure mode `--natural-themes` exposed
in the run statistics: a handful of broad themes win the bulk of
the assignments while many themes get zero or near-zero hits.
`connection` swallows 52% of the 489 pages because its keyword
list (friends, community, support, etc.) brushes against nearly
every poem; the twelve merged primitives almost never win because
they have no corpus-specific vocabulary; the remaining themes
fragment small. The theme set does not reflect the corpus's
actual semantic structure.

## Intended Behavior

This issue covers two related changes — the theme discovery
pipeline AND a runtime fix to how per-poem themes are computed.

### Runtime fix: whole-poem embeddings, not per-segment

Today, `build_book` splits long poems into per-column-fitting
segments via `append_long_poem`, then iterates the resulting
segments in `generate_individual_poem_art` and calls
`analyze_individual_poem_for_tier2(box.poem)` —
**but `box.poem` is the SEGMENT, not the original whole poem**.
A 9000-character poem split across two columns ends up with
two segment embeddings (each capturing only half the poem's
content) rather than one whole-poem embedding. The same hits
`analyze_individual_poem_theme` for Tier 3 colors. The themes
that segments get assigned therefore reflect half-poem
semantics, which is one reason the per-poem theme statistics
read as arbitrary.

The fix attaches the original whole-poem text to every entry
inserted into `book.pages` (both the whole-poem inserts and
the per-segment inserts from `append_long_poem`), as a
`_full_text` field on the table. `analyze_individual_poem_*`
read `poem._full_text` in preference to
`table.concat(poem, " ")`, so each poem's theme reflects the
whole poem's semantics regardless of how the layout cut it.

As a side effect this also fixes the cache mismatch the
discovery pipeline noticed: once the runtime is embedding
whole-poem text, the cache fills with whole-poem keys, and the
discovery pipeline's hit rate goes from ~22% (segment-keyed
cache, useless for whole-poem queries) to ~99% after one
warmup `./run`.

### Discovery pipeline

Replace the hand-written theme list with one **derived from the
corpus** by clustering every poem's embedding directly. The
themes ARE the clusters. By construction, cluster sizes reflect
real prevalence and the cardinality is whatever the data
supports rather than a pre-decided 10/20/40 pyramid.

Pipeline overview (offline, one-shot, lives in `themes-v2/`):

1. **Load** every poem's cached embedding (the cache in
   `tmp/embeddings/` already contains all 6,487 poem vectors from
   prior runs; nothing needs to be re-embedded).
2. **Cluster** with HDBSCAN in pure LuaJIT. HDBSCAN is chosen
   because it picks the cluster count from the data (no K
   guessing), handles varying density natively (some themes are
   tight, others diffuse), and tolerates noise (poems that don't
   fit anywhere become a labeled `-1` group rather than getting
   force-fit into the nearest cluster).
3. **Extract distinctive vocabulary** per cluster via TF-IDF over
   the constituent poem text. The top 20 words per cluster
   surface what makes that cluster different from the others —
   not the most common words (which are the same stop-word soup
   everywhere) but the most cluster-specific.
4. **Name** each cluster: prompt the local Qwen3 chat server with
   the top words plus a few sample poem excerpts, ask for five
   candidate snake_case theme names, embed each candidate via
   nomic, pick the candidate with the highest cosine similarity
   to the cluster centroid. The cluster picks its own name.
5. **Emit** `themes/derived-taxonomy.lua` containing, per
   cluster: `{ name, description, centroid (768 floats),
   top_words, member_count }`. The runtime loads this file
   directly and uses the stored centroids — no startup-time
   re-embedding of theme descriptions.

The pyramid structure (Tier 1 = 10 themes, Tier 2 = 20, Tier 3 =
40 in nesting layers) is retired. The renderer's three tiers
(page art, column patterns, poem color) remain — they correspond
to different visual treatments, not different theme sets — but
all three are driven by the same cluster IDs. A page's Tier 1
theme is the dominant cluster among its constituent poems; each
poem's Tier 2 and Tier 3 themes are that poem's own cluster.
Same theme = same visual identity across all three layers, which
also fixes the current "page theme is `connection`, poems on it
are `online_communities`/`mental_overflow`/`gaming_culture`"
mismatch.

The number of clusters is determined by HDBSCAN's
`min_cluster_size` / `min_samples` parameters (configurable at
the top of `hdbscan.lua`). Starting values: `min_cluster_size =
30`, `min_samples = 5`. Expected output is somewhere in the
20–60 cluster range for 6,487 poems with default settings;
tunable based on actual results.

## Suggested Implementation Steps

This issue is built in **three slices**, each committed and
testable independently.

### Slice 0: runtime whole-poem fix

0. In `compile-pdf-ai.lua:build_book`, at the top of the
   per-poem loop, compute the full poem text once and attach
   it to the poem table:
   ```
   local full_text = table.concat(poem, " ")
   poem._full_text = full_text
   ```
   This propagates through the short-poem-fits and
   short-poem-moves-to-next-column branches automatically
   because they insert the same `poem` table reference into
   `book.pages`.

1. In `compile-pdf-ai.lua:append_long_poem`, after constructing
   each segment table and before inserting it, copy the parent
   poem's `_full_text` onto the segment:
   ```
   segment._full_text = poem._full_text
   ```

2. In `analyze_individual_poem_for_tier2` and
   `analyze_individual_poem_theme`, change the text source
   from `table.concat(poem, " ")` to
   `poem._full_text or table.concat(poem, " ")`. The
   `or`-fallback covers any caller that doesn't go through
   build_book (kept for safety, not expected to fire in
   normal operation).

3. The first `./run` after this fix repopulates the embedding
   cache with whole-poem keys. The discovery pipeline's slice 1
   then sees near-100% cache hits.

### Slice 1: data loading (depends on slice 0)

1. Create the `themes-v2/` directory.
2. `themes-v2/load-poem-embeddings.lua` (LuaJIT):
   - Read `tmp/compiled-cleaned.txt` (the same input the runtime
     consumes), split on lines of exactly 80 dashes, apply the
     runtime's `normalize_poem_spacing` so the per-poem text
     matches what the runtime would have embedded.
   - For each poem at least 10 characters long, call
     `fuzz.get_embedding(text, LLM_MODEL, NOMIC_PREFIX)`. That
     function handles the cache lookup itself: hits return in
     microseconds, misses post to the llama-server embedding
     endpoint and write the result back to the cache. The
     embedding server **must** be running
     (`scripts/start-llamacpp-server.sh --background`); a server
     outage during a miss is a hard error from `fuzz`.
   - Pack the 768-float result into `tmp/poem-embeddings.bin`:
     a raw little-endian float32 stream, 768 floats per poem,
     written in poem-index order. Header: 4-byte poem count
     (uint32 LE), 4-byte dimension (uint32 LE).
   - Parallel write `tmp/poem-texts.lua`: `return { [1] = "poem
     1 text", ... }` for the TF-IDF and naming steps.
   - Probe the cache directly per poem (using a local copy of
     `djb2_hash`) so the operator gets a hit/miss count and an
     elapsed-time report. The first run on a corpus state will
     typically be mostly misses (~75%), because the runtime
     embeds per-page-segment text after splitting long poems
     across pages; whole-poem embeddings for clustering aren't
     populated until this script runs. Subsequent invocations
     of this script will be near-100% hits.

### Slice 2: clustering, vocabulary, naming, driver

3. `themes-v2/hdbscan.lua` (LuaJIT + FFI for distance loop):
   - Read `tmp/poem-embeddings.bin` via FFI `ffi.new("float[?]",
     ...)`.
   - Cosine distance: `1 - dot(a, b)` since nomic vectors are
     unit-normalized (verify on first run; renormalize if not).
   - Core distances: for each point, distance to its k-th nearest
     neighbor (k = min_samples).
   - Mutual reachability graph: keep only the k-NN edges per
     point (sparse, ~21M brute pairs evaluated but only ~100k
     edges retained). Edge weight `mr_dist(a,b) = max(d(a,b),
     core_a, core_b)`.
   - MST: Prim's algorithm with a binary heap on the mutual
     reachability graph.
   - Condensation hierarchy: walk MST edges in descending order,
     split clusters at each threshold; clusters that fall below
     `min_cluster_size` are "fallen out of" — their points
     become noise of their parent.
   - Flat extraction: compute stability per condensed cluster
     (sum of `lambda_birth - lambda_death` over points); select
     the subset of clusters that maximizes total stability
     subject to the no-ancestor-and-descendant-both constraint.
   - Output `tmp/clusters.json` (via `dkjson`): `{ clusters:
     [{id, centroid: [...768], member_ids: [...]}, ...], noise:
     [...]}` where `member_ids` and `noise` are indices into
     the poem-texts list.
4. `themes-v2/tfidf.lua` (LuaJIT):
   - Read `tmp/poem-texts.lua` and `tmp/clusters.json`.
   - Tokenize each poem (lowercase, split on whitespace, strip
     punctuation, drop stop words from a small built-in list).
   - Compute term frequency per cluster (sum over member poems)
     and document frequency across all poems.
   - TF-IDF score = TF * log(N_poems / DF_word).
   - Output `tmp/cluster-tfidf.json`: `{ [cluster_id]: [{word,
     tfidf}, ...] }` truncated to top 20 per cluster.
5. `themes-v2/name-clusters.lua` (LuaJIT):
   - For each cluster: build a prompt with the top 20 words and
     three representative poem excerpts (poems closest to the
     centroid by cosine).
   - Post to the Qwen3 chat endpoint
     (`libs/inference-server-config.lua:CHAT_ENDPOINT`) with a
     "propose 5 single-concept snake_case theme names for a
     cluster of poems sharing these words and excerpts" prompt.
   - Parse the response into 5 candidate names.
   - Embed each candidate via `fuzz.get_embedding`.
   - Pick the candidate with the highest cosine similarity to
     the cluster centroid. Tie-break by candidate index (first
     wins) for determinism.
   - Emit `themes/derived-taxonomy.lua`: `return { themes = {
     [cluster_id] = {name, description, centroid: {...},
     top_words: {...}, member_count}, ...}}`.
6. `themes-v2/run.sh`:
   - Bash driver that runs the four scripts in order.
   - `--start-at <step>` to resume from a specific step.
   - `--clean` to wipe `tmp/poem-embeddings.bin`,
     `tmp/poem-texts.lua`, `tmp/clusters.json`,
     `tmp/cluster-tfidf.json` and start fresh.
   - Each script is independently runnable, the driver is for
     convenience.

### Follow-up (NOT in this issue, deferred)

- Wire `compile-pdf-ai.lua` to consume `themes/derived-taxonomy.lua`
  in place of the hard-coded `tier1_descriptions` /
  `tier2_descriptions` / `tier3_descriptions` tables. Centroids
  are stored, so the startup-time embedding pass over the theme
  descriptions disappears.
- Map each cluster to one of the ~15 existing art generators in
  `theme_generators` (compile-pdf-ai.lua:1965), by embedding
  each generator's style description and picking the closest one
  per cluster. Until this is done, most clusters fall back to
  the `neutral` generator visually.
- Delete the now-obsolete `theme-analysis/` directory (after
  confirming nothing useful was salvageable from
  `narratives/` — that subdirectory looks like a side-quest,
  not part of the theme pipeline).

## Relevant Files

- `themes-v2/load-poem-embeddings.lua` (new, slice 1)
- `themes-v2/hdbscan.lua` (new, slice 2)
- `themes-v2/tfidf.lua` (new, slice 2)
- `themes-v2/name-clusters.lua` (new, slice 2)
- `themes-v2/run.sh` (new, slice 2)
- `themes/derived-taxonomy.lua` (new, output of slice 2)
- `libs/fuzzy-computing.lua` (read-only, cache-key formula
  reference for slice 1)
- `libs/inference-server-config.lua` (read-only, endpoint
  reference for slice 2's name-clusters step)
- `libs/dkjson.lua` (read-only, JSON serialization for the
  intermediate files)
- `compile-pdf-ai.lua` (NOT touched in this issue — wiring is
  deferred to a follow-up so this pipeline can land and be
  tested in isolation)

## Design Notes

**Why HDBSCAN over K-means.** K-means forces every point into a
cluster, assumes spherical clusters of similar density, and
requires guessing K. Embedding spaces frequently violate all
three. HDBSCAN handles variable density (some themes are tight,
others diffuse), labels poems that don't fit anywhere as noise
rather than misclassifying them, and picks the cluster count
from the data structure. The cost is that HDBSCAN is more code
to implement (~500 lines vs. ~100 for K-means), but it is a
one-time cost that better matches the actual question being
asked: "what are the natural themes in this corpus?"

**Why one cluster set drives all three rendering tiers.** The
pyramid in the current system was a historical artifact —
described in the README as a hardware-era compromise — and it
created a real coherence problem: a page might be tagged as
theme A while its constituent poems were tagged as themes B,
C, D from a different taxonomy. With one cluster set, the
page's theme is just the dominant cluster among its poems, and
all three rendering tiers operate over the same vocabulary.

**Why TF-IDF for distinctive words instead of raw frequency.**
The top 20 words in any cluster by raw frequency are mostly
"the", "and", "of", "I", etc. — the same across every cluster
and useless for naming. TF-IDF re-weights by document
frequency, so words common to all poems get downweighted and
words specific to one cluster surface. This is what makes
"anarchist" jump out of a politics cluster instead of "the".

**Why the LLM picks from candidates instead of writing one
name.** Asking the LLM "name this cluster" gives a single
answer, which is hard to verify. Asking for 5 candidates and
then picking the one closest to the centroid in embedding
space (a) gives the LLM room to brainstorm, (b) lets the
cluster's own semantic location have the final vote, (c) is
deterministic given fixed embeddings (no temperature in the
final choice). It also turns naming into a closed-loop
self-validation: the cluster picks the name that best
describes itself by its own embedding-space geometry.

**Why centroids are stored, not just names.** The runtime
currently re-embeds every theme description at startup, which
takes a full pass through the embedding server. If we store
the centroid (which IS the theme's representation in embedding
space), the runtime loads a float array from disk and skips
the embedding pass entirely. Faster startup, less server load,
and the runtime-side theme representation is bit-identical to
what the discovery pipeline produced.

**Hard-error on cache miss in slice 1.** The cache is supposed
to contain every poem from prior runs. A miss means either the
input file differs from what previously ran (different
content, different cleaning) or the cache key formula changed.
Both are operator-visible problems that should fail loudly
rather than silently triggering a re-embed.

**FFI in hdbscan.lua.** LuaJIT FFI with `ffi.new("float[?]",
n*768)` for the embedding storage gives roughly C-speed inner
loops on the distance computation. Pure-Lua tables would be
5-10x slower (~5-10 minutes on this corpus vs. ~30 seconds
with FFI). Both are acceptable for offline work, but FFI is
the right default when LuaJIT is already the chosen runtime.
