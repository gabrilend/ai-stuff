# embedding-space

How this project prepares embedding vectors before anything compares them, and
the note that records which preparation a cache was built with.

In one sentence: subtract the direction every vector shares, so that cosine
similarity measures what a poem is about rather than measuring the model's habit.

## Why

The model does not spread its output over the whole sphere. On this corpus the
average of all poem vectors has length **0.766** against vectors of length 1.0 —
roughly three quarters of every vector is one direction common to all of them.
Run `scripts/measure-embedding-spread` to re-measure; it is a property of the
model in use, not a constant.

Measured over 4,000 poems with twenty neighbours each
(`scripts/measure-centering-effect`):

| | as-is | centered |
|---|---|---|
| most-listed poem (out of 4000) | 526 | 191 |
| top 1% of poems take | 11.8% | 5.3% of all neighbour slots |
| poems in **nobody's** list | 226 | 12 |

That last row is the reason this module exists. About one poem in eighteen
appeared in no other poem's similar list at all — not ranked low, *absent*,
unreachable by anyone browsing sideways. The shared direction had made a handful
of vectors everyone's neighbour and a long tail nobody's.

Neighbour lists change by about **42%** when this is applied. It is not a
refinement; it is a different set of answers, and switching it on or off
invalidates every cache built from it.

## External functions

### `M.corpus_mean(entries)`
- **entries**: array of records each carrying an `embedding` field (a Lua array
  of numbers) — i.e. `embeddings.json`'s `.embeddings` as loaded.
- **returns**: `mean, count` — a Lua array of the same dimension plus how many
  vectors were averaged; or `nil, message` on failure.
- Errors rather than averaging past a vector of the wrong length. Two dimensions
  in one file means two models' output got mixed together, and an average across
  them is a number with no meaning that would flow silently into everything
  downstream.

### `M.centered(vec, mean)`
- **vec**: Lua array of numbers. **mean**: the corpus mean, or nil.
- **returns**: a **new** array with the mean subtracted. The caller's copy is
  untouched, because several stages keep the raw vectors after comparing.
- A nil mean returns the vector unchanged, so a caller that could not compute a
  mean degrades to the previous behaviour rather than to zeros. Callers that must
  not degrade silently should check `corpus_mean`'s second return value.

### `M.SPACE_VERSION`
Read-only string naming how vectors are prepared (currently
`"mean-centered-v1"`). **Change it whenever the preparation changes in a way that
alters similarity scores.** Anything holding the old string is then known to be
stale rather than assumed fine.

### `M.write_fingerprint(cache_dir)` / `M.read_fingerprint(cache_dir)` / `M.is_current(cache_dir)`
Stamp, read, and test the note a cache directory carries.

- `write_fingerprint` returns `true`, or `false, message`. Call it **after** the
  cache is successfully written — a note written first survives a crashed rebuild
  and marks a half-finished cache as current.
- `is_current` returns true only when the stored note equals `SPACE_VERSION`. An
  unmarked directory counts as a mismatch, so the first run after this module
  lands rebuilds, which is correct.

### `M.FINGERPRINT_FILE` / `M.fingerprint_path(cache_dir)`
The filename (`embedding_space.fingerprint`) and its full path in a directory.

## Why a fingerprint and not a timestamp

Similarity files carry no record of how the vectors were prepared. A set built
before centering looks exactly like one built after: same filenames, same count,
same shape, a complete and ordered list of neighbours for every poem. It is
simply a *different* set. Existence and mtime cannot tell them apart, so the
directory carries a note and a mismatch forces a rebuild.

The FP16 diversity cache takes the same idea further: the space version is part
of its **filename**, so an older cache is never opened at all rather than being
opened and found plausible.

## Who applies it

| stage | where | note |
|---|---|---|
| 7 — similarity matrix | `libs/vulkan-compute/lua/vk_similarity.lua` | centered when packing the flat GPU buffer; everything downstream inherits it |
| 8 — diversity cache | `scripts/precompute-diversity-sequences-gpu` | centered before FP32→FP16 conversion |
| 10 — word pages | `src/generate-word-pages.lua` | centered per comparison |

Safe to feed the shaders centered vectors: `similarity_full.comp` computes both
norms itself rather than assuming unit length.

## Word-to-poem is a different case

Word pages center too, but they *must*, and for a sharper reason. A single word
carries **more** of the shared direction than a whole poem does (0.829 against
0.766), so the offset is not constant across that comparison and distorts the
ordering rather than merely compressing it. Poem-to-poem survives without
centering — it just survives badly, as the table above shows.

## Related

- `scripts/measure-embedding-spread` — how much of each vector is shared, per model
- `scripts/measure-centering-effect` — what centering does to neighbour lists
- `libs/embedding-space.test.lua` — round-trip and rejection tests
