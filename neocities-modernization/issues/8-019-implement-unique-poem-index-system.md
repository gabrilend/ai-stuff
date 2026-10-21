# Issue 8-019: Implement Unique poem_index System

## Reopened 2026-10-21: the index is unique but not stable

### Current Behavior

`src/poem-extractor.lua` sorts all poems by category, then by each source's
own id, and numbers them 1..N in that order. A note's own id is its position
in `find`'s listing of the notes folder (`scripts/extract-notes.lua`), which
follows how ext4 stores the directory, not names or dates. So adding a note
renumbers every note after it, and adding a poem to an earlier category
renumbers everything in the categories after it.

What it broke, found 2026-10-21:
- 17 notes reached `~/notes` at 17:49 on 2026-10-07 (pittiless,
  spirit-of-life, work-at-power, ...), between that day's noon extraction and
  the 18:02 copy into `input/`. They landed all through the listing (note
  positions 27 to 542), each pushing every later note up one. The last 16
  notes -- old ones, division-by-zero, symbeline-superheros, rivers... --
  were pushed past the old end, to 8607–8622.
- The embeddings are filed by poem number. About 555 of the 582 notes now
  sit at a number whose embedding was made from a different note: for notes
  the recorded text length no longer tracks the real length (correlation
  0.12 for EmbeddingGemma 2, 0.08 for the September EmbeddingGemma 300m;
  1.00 for every other category). Every note's similar and different list on
  the live site is ranked from another note's meaning.
- The gallery pictures were numbered after the highest embedded poem, so 16
  took 8607–8622 (fixed 2026-10-20 in the image step; see Issue 9-013).
- Page addresses use the number (`similar/0001-01.html`), so a renumbering
  also moves every page a link points to.

### The three numbers each item needs (owner, 2026-10-21)

> pictures should have their own index, for the gallery. But they should
> also have another index that displays their providence. We already use a
> dual-index system for fediverse / messages / notes, so look to that for
> inspiration. This however adds a third index for the gallery which is just
> separate.

- **Source index** (provenance): which source and which item in it --
  `fediverse/1583`, `notes/<file name>`, `my-art/<path>`. It must come from
  the item itself (a post id, a file name), never from a listing position.
- **Gallery index**: pictures only, their place in the gallery.
- **Global number**: one number for every item, poem or picture, used to rank
  them together and to name their pages.

### Open question (for the owner)

How is the global number given out?
- **A. Once, on first sight, never reused.** An append-only register maps
  each source index to its number; a new item gets the next number, and
  nothing that already has one ever moves. Embeddings, rankings and page
  addresses stay attached. Pictures are numbered the same way, so they can
  never collide with a poem. Order on the pages (by date) comes from dates,
  not from numbers.
- **B. Re-derived each run in a meaningful order** (for example by date,
  pictures interleaved among the poems). Every cache must then be filed by
  source index and checked against the text it was made from, and every page
  address changes whenever anything is added before it.
- Recommended: A, with every cache also checked against a fingerprint of its
  text, so a vector can never again attach to the wrong poem.

### Suggested Implementation Steps (after the question is answered)

1. Notes get a stable source id: the file name (exclusions already name
   notes by file name).
2. A register file, append-only, written by extraction (A) -- or the sort
   order (B).
3. The embedding cache stores each vector's text fingerprint and the
   embedding stage re-embeds any poem whose fingerprint differs.
4. A check (test and pre-flight) that every embedding's fingerprint matches
   its poem.
5. Re-embed the notes (and the 16 shifted poems) once.

## Original issue (2025-12-25)

### Current Behavior (then)

The poem identification system uses `id` fields derived from source filenames, which creates **collisions across categories**:

```
fediverse/0002.txt → id: 2, category: "fediverse"
messages/0002.txt  → id: 2, category: "messages"  ← COLLISION!
notes/0002.txt     → id: 2, category: "notes"     ← COLLISION!
```

This causes problems in the embedding pipeline:

1. **Generation** stores embeddings at array index: `embeddings[5731] = {id: 2, ...}`
2. **Loading** (incremental mode) stores by `emb.id`: `existing_embeddings[2] = {...}`
3. **Lookup** uses array index: `existing_embeddings[5731]` → **nil!**

Result: Incremental embedding mode fails for all non-fediverse poems because array index ≠ source file ID.

### Discovery Context

While debugging embedding generation failures (2025-12-25), traced the root cause to:
- `similarity-engine.lua:336-339` stores loaded embeddings by `emb.id`
- `similarity-engine.lua:368` looks up by array index `i`
- These only match for fediverse poems where source ID ≈ array position

## Intended Behavior

Add a new `poem_index` field that provides a **unique, stable, array-aligned identifier** for each poem:

```json
{
  "poems": [
    {
      "poem_index": 1,           // Unique global identifier (1-indexed)
      "id": 1,                   // Original source file ID (preserved for display)
      "category": "fediverse",
      "filepath": "fediverse/0001.txt"
    },
    {
      "poem_index": 5731,        // Unique! Different from id
      "id": 2,                   // Same numeric ID, different poem
      "category": "messages",
      "filepath": "messages/0002.txt"
    }
  ]
}
```

### Benefits

| Aspect | Current (`id`) | Proposed (`poem_index`) |
|--------|----------------|------------------------|
| Uniqueness | Collisions across categories | Globally unique |
| Array alignment | Mismatched after fediverse | Always matches array position |
| Stability | Depends on extraction order | Stable once assigned |
| Display | Used for filenames | Keep `id` for display, `poem_index` for internals |

## Implementation Steps (Completed 2025-12-25)

### Phase A: Add poem_index to Extraction ✅

**File: `src/poem-extractor.lua`**

1. [x] During poem extraction, assign `poem_index = array_position`
2. [x] Ensure poem_index is 1-indexed (Lua convention)
3. [x] Add poem_index to each poem's metadata
4. [x] Bumped extraction_version to 2.1

Implementation: Added loop after sorting to assign `poem_index = i` for each poem.

### Phase B: Update Embedding System ✅

**File: `src/similarity-engine.lua`**

1. [x] Update `generate_all_embeddings()` to store by `poem_index` if available, fallback to array index
2. [x] Update incremental loading to store by `poem_index`
3. [x] Update lookup to use `poem.poem_index`
4. [x] Add `poem_index` field to each embedding record for future incremental loads
5. [x] Backward compatibility maintained via `poem.poem_index or i` fallback

### Phase C: Update HTML Generation ✅

**Files: `src/flat-html-generator.lua`, `scripts/generate-html-parallel`, `src/centroid-html-generator.lua`**

1. [x] Use category prefix for output filenames: `similar/{category}-{id}.html` (e.g., `fediverse-0002.html`)
2. [x] Update navigation links to use category prefix
3. [x] Keep `id` + `category` for display (e.g., "fediverse #2")
4. [x] Update all file existence checks in incremental mode
5. [x] Fix embedding lookup in parallel generator to use `poem.poem_index`

**Note**: User preferred category prefix over poem_index for file naming (more readable URLs).

### Phase D: Update Similarity Matrix ✅

**Files: `src/similarity-engine-parallel.lua`, `src/html-generator/similarity-engine.lua`**

1. [x] Update `get_poem_similarity_file()` to use `poem_index` for file naming
2. [x] Files now named `poem_index_{N}.json` instead of `poem_{id}.json`
3. [x] Add backward compatibility loading for old `poem_{id}.json` files
4. [x] Update similarity data to include both `poem_id` and `poem_index` in metadata

### Phase E: Migration ✅

1. [x] Regenerated poems.json with `poem_index` field
2. [x] Existing embeddings will work via fallback mechanism
3. [x] Full regeneration recommended for clean state

### Verification

```bash
$ jq '.poems[] | select(.id == 2) | {poem_index, id, category}' assets/poems.json
{
  "poem_index": 2,
  "id": 2,
  "category": "fediverse"
}
{
  "poem_index": 6437,
  "id": 2,
  "category": "messages"
}
{
  "poem_index": 7518,
  "id": 2,
  "category": "notes"
}
```

Three poems with `id: 2` now have unique `poem_index` values, preventing collisions.

## Technical Notes

### Why Not Just Fix the Lookup?

We could patch `similarity-engine.lua` to store/lookup by array index consistently. However:

1. **Array index is implicit** - Not stored in the data, computed at runtime
2. **Fragile** - Any change to poems.json order breaks embeddings
3. **No audit trail** - Can't verify which poem an embedding belongs to

`poem_index` makes the identifier **explicit and persistent**.

### Relationship to Other IDs

| Field | Purpose | Scope | Example |
|-------|---------|-------|---------|
| `poem_index` | Internal processing, embeddings, similarity | Global | 5731 |
| `id` | Source file reference, display | Per-category | 2 |
| `filepath` | Unique source identification | Global | "messages/0002.txt" |

### Chronological Sorting

`poem_index` is assigned during extraction (which may be chronological). For display sorting:
- Use `created_at` for chronological views
- Use `poem_index` for stable internal references
- These are orthogonal concerns

## The Rule This Issue Establishes

**Any table that maps a poem to its embedding is keyed on `poem_index`, on both
the write side and the read side. Never on `id`.**

This is the whole point of the issue and it applies to every builder, including
ones written long after this issue closed. `id` is a per-category number that
restarts at 1 five times over — bluesky, fediverse, fediverse_boost, messages,
notes — so five different poems answer to `id = 1`. Building a lookup on it does
two kinds of damage at once, and neither one announces itself:

1. **Last-write-wins silently discards embeddings.** 8,415 entries collapse into
   5,997 distinct keys, so roughly 29% of the corpus is thrown away before any
   ranking happens.
2. **The survivors attach to the wrong poems.** A table written with `id` and
   read with `poem_index` looks consistent — every lookup succeeds — but the
   embedding found under key 939 belongs to whichever poem was written last, not
   to poem 939.

There is no nil, no warning, and no crash. The output is a full page of plausible
poems in descending score order, every score computed correctly and every score
printed against the wrong poem. That is what makes this rule worth stating
separately from the migration steps below: the failure is invisible from the
outside, so it can only be prevented at the point where the lookup is built.

A third consequence is worth naming because it is easy to miss: keying on `id`
caps the reachable corpus at the largest `id` value. Nothing numbered above it
can ever be looked up, so entire categories become unreachable — `messages` and
`notes` could not appear on a word page at all.

## Files to Modify

| File | Changes |
|------|---------|
| `src/poem-extractor.lua` | Assign poem_index during extraction |
| `src/similarity-engine.lua` | Use poem_index for embedding storage/lookup |
| `src/similarity-engine-parallel.lua` | Same as above |
| `src/flat-html-generator.lua` | Use poem_index for output files |
| `scripts/generate-html-parallel` | Use poem_index for output files |
| `libs/utils.lua` | Add poem_index validation helper |
| `src/generate-word-pages.lua` | Key the word-page embedding lookup on poem_index |
| `src/centroid-html-generator.lua` | Key the centroid embedding lookup on poem_index, both sides |

The last two are page builders added during Phase 8 and later. Both were written
against `id` and both exhibited the failure described above until corrected —
which is the reason the rule now leads this section rather than being implied by
the steps.

## Where an Embedding Lookup May Still Be Wrong

A quick way to check any builder: the write and the read must name the same
field, and that field must be `poem_index`.

```
lookup[tostring(entry.poem_index)] = entry.embedding     -- write
local emb = lookup[tostring(poem.poem_index)]            -- read
```

If either line says `id`, the builder is wrong even when it appears to work.

## The Other Reason a Poem Can Be Unreachable

A correct key gets a poem as far as the lookup. It does not conjure an embedding
that was never generated. These are two different failures with the same
symptom — the poem never appears anywhere — and they must be told apart before
either is chased.

Run `scripts/measure-embedding-spread`. Its coverage section resolves the model
**through the project's own selection** rather than a typed path, lists how many
poems have no embedding, and breaks that count down by category. A whole category
missing there is a stale embeddings file, not a keying bug.

This distinction was not obvious in practice. After the key was corrected, the
`notes` category still failed to appear on any word page, which looked like the
fix being incomplete. It was not: the selected model's embeddings file covers
`poem_index` 1–7904 while the collection runs to 8510, and `notes` occupies
8041–8510 — entirely outside the embedded range. 606 poems (470 notes, 136
messages) have no embedding at all under the current model and cannot appear
until the embeddings are regenerated.

The lesson for this issue: **the reachability ceiling has two possible causes.**
Under the `id` bug it is the largest `id` value. Under a stale embeddings file it
is the highest embedded `poem_index`. Both present as "everything above N is
invisible", and the fix differs completely.

## Testing Strategy

1. [ ] Extract poems and verify poem_index assigned correctly
2. [ ] Generate embeddings and verify storage by poem_index
3. [ ] Run incremental mode and verify correct skip detection
4. [ ] Generate HTML and verify file naming
5. [ ] Full pipeline test: extract → embed → similarity → HTML

## Related Issues

- **Issue 4-004**: Verify and Resolve Cross-Category ID Mapping (identified the collision)
- **Issue 8-018**: Fix embedding directory case inconsistency (discovered during same debugging session)
- **Issue 9-003**: Optimize centroid calculation (uses embeddings, affected by this)

## Risk Assessment

- **Low**: poem_index is additive, doesn't break existing `id` usage
- **Medium**: Requires regeneration of embeddings after implementation
- **Low**: HTML output filenames may change (similar/5731.html vs similar/2.html)

---

**Phase**: 8 (Website Completion)

**Priority**: High (blocking correct incremental embedding behavior)

**Created**: 2025-12-25

**Completed**: 2025-12-25

**Status**: Complete

**Estimated Effort**: Medium (touches multiple files but straightforward logic)

**Files Modified**:
- `src/poem-extractor.lua` - Assign poem_index after sorting
- `src/similarity-engine.lua` - Use poem_index for embedding storage/lookup
- `src/similarity-engine-parallel.lua` - Use poem_index for similarity file naming
- `src/flat-html-generator.lua` - Use category prefix for HTML file naming
- `src/centroid-html-generator.lua` - Use category prefix for navigation links
- `src/html-generator/similarity-engine.lua` - Load similarities by poem_index
- `scripts/generate-html-parallel` - Update workers and file checks for category prefix
