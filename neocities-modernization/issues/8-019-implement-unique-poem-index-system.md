# Issue 8-019: Implement Unique poem_index System

## Reopened 2026-10-21: the index is unique but not stable

### Current Behavior

**Built 2026-10-22 (steps 1-3 of the steps below; the first build after it
must re-embed, `--force`):**
- `poem-extractor.number_poems` gives each poem its source key
  (`fediverse-2339`) and numbers all poems 1..N by date, a tie broken by key
  (dates from `src/poem-dates.lua`, shared with the chronological pages).
  Two poems with one key, or a poem with no date, stop the extraction.
  poems.json records `metadata.numbering.fingerprint`, a code made from the
  keys in order (`libs/text-fingerprint.lua`, FNV-1a 64).
- The embedding stage stores each vector with its source key and the code
  of the text it was made from, and reuses a stored vector only when both
  match (`similarity-engine.reusable_vector`); image-only posts and empty
  poems are made fresh every run, and an image-only post now borrows its
  neighbour's vector from this run only (it used to look in the old file,
  filed under the old numbers). embeddings.json records the numbering.
- Every cache made from the numbers is stamped with the numbering it was
  made under, in a file beside it (`<cache>.numbering`,
  `libs/numbering-stamp.lua`): poem colours, the picture list, the
  similarity rankings, the diversity walks. Stage 9 (`main.lua`
  `generate_website_html`) and stage 10 (`generate-word-pages` on a build)
  check every stamp against poems.json and stop with what to rerun. The
  checks are at the stages' doors, not in the shared drawing functions, so
  the tests and the sample renderer still draw from today's caches.
- `scripts/renumber-diversity-cache` is retired (`-done`): it repaired old
  caches; stage 8 now regenerates the walks in about 84 s.
- Tests: `src/poem-extractor.numbering.test.lua`,
  `src/similarity-engine.reuse.test.lua` (reuse by key and text, the
  2026-10-07 swap, the stamps), `libs/text-fingerprint.test.lua`.
- Not yet: anchors and page names by key (step 4).

**Before 2026-10-22:**
`src/poem-extractor.lua` sorted all poems by category, then by each source's
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

**The diversity cache was in positions, not poem numbers (found and fixed
2026-10-21).** `scripts/precompute-diversity-sequences-gpu` wrote the GPU's
positions (0 .. N-1, the order of the embeddings file) as both keys and
entries, under a comment saying they were converted; the similarity cache is
in poem numbers (1 .. N). The page builder read both as poem numbers, so
since 2026-01-17 (the GPU diversity cache becoming the default) every
"different" page showed the walk of the poem after its anchor, each listed
poem one below the intended one; position 0 surfaced as a "poem 0" in 149
lists, which the old page code dropped quietly. Found when the new page
module refused a ranking naming a poem not in the poem list.
- The writer now maps each position to the poem number stored at it in the
  embeddings file, and marks the cache `numbering = "poem_index"`.
- The page builder refuses a cache without the mark; `run.sh` stage 8
  regenerates one whatever its date.
- `scripts/renumber-diversity-cache --model NAME` (retired 2026-10-22, now `-done`) repaired an old cache in
  place in seconds (the original kept in RAM), checking it was made from the
  same embeddings file. The EmbeddingGemma 2 cache is repaired; the older
  models' caches are not.

**Notes are numbered by date (2026-10-21).** Owner: "this is bad and wrong.
We should replace it with by date." `scripts/extract-notes.lua` now sorts
the notes by their file's modification time, oldest first (the file name
breaks a tie), before giving out ids; a note whose date cannot be read stops
the extraction (it used to be dated "now"). Pinned by
`scripts/notes-tooling-exclusion.test.sh`. The order no longer depends on how
the disk lists the folder, but a note with an older date than the newest
still renumbers the notes after it -- the open question below decides
whether that matters. The next extraction renumbers the notes once, so the
next build must re-embed them (`--force` does).

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

### Decision: the global number is counted fresh each run (owner, 2026-10-21)

> recomputed each run. This should be a trivial computation, just... counting
> in a specific order with a specific method. Probably no branches even at
> all.

The alternative, a register handing each item a number once and forever, was
de-selected: it keeps old numbers meaningful, but it is a second record that
must be kept in step with the sources, and its numbers carry no order.

So the number is a view, not an identity. Every run sorts all items, poems
and pictures together, in one fixed order (date, then source name to break a
tie) and counts 1..N. Nothing stored on disk is keyed by the number; it is
worked out again each run from what is stored.

### What identifies an item: its source key

Every source's own number (the `id` field, shown as `fediverse/2339`) is a
position in that source's list, counted 1, 2, 3...:

| source | table it comes from | its number |
|---|---|---|
| fediverse post | `outbox.json` (Mastodon export), `orderedItems` | position in that list (`scripts/extract-fediverse.lua`) |
| fediverse boost | the same list, type `Announce` | a separate count of boosts |
| message | `export.json` (Element "Messages to yourself" export), `messages` | position in that list (`scripts/extract-messages.lua`) |
| bluesky post | `repo-*.car` (Bluesky repository archive), post records | rank by `createdAt` (`scripts/extract-bluesky-data`) |
| note | the notes folder (`~/notes`, copied to `input/notes`) | rank by file date (`scripts/extract-notes.lua`) |
| picture | the picture sources in config.lua | rank in the gallery |

**The source key is that counting number with its source**:
`fediverse-2339`, `messages-618`, `notes-41`. Owner, 2026-10-22, on the
long ids each item also carries (a post's status id, a message's event id):
"yo what that ID is brutal. We should have an incremental ID, none of this
randomly generated GUID nonsense." A counting number shifts when an earlier
item leaves (a deleted post, something removed because it put someone at
risk) or an older note arrives, and that is accepted: "that's okay because
it's rare, and only for the most recent things ... Let's just shift
everything down. Sometimes words have the wrong link and that's okay." New
items arrive at the end of their source, so in the usual case nothing
shifts; and a shift in one source never moves another source's keys (today
the global number moves every page after an addition in any source).

What a shift must never do is attach a vector to the wrong poem (the notes
of 2026-10-07 did): every cached vector carries a fingerprint of its text,
and a mismatch is re-embedded (step 3).

Two items with one source key stop the extraction with both named. The one
case on 2026-10-21, two notes in the folder twice (the same bytes and the
same date at the top and under `reddit-comments/`), was settled by the owner
("if they're reddit comments, then we should delete the note version and
leave the reddit-comments version"); the top-level copies of
`harambe-conspiracy` and `planes-and-trains-and-tanks` were deleted from
`~/notes` and `input/notes`.

### Links when the numbers move (owner, 2026-10-21)

> if the specified poem ID doesn't exist on that page, we take them to the
> top of the page?

Anchors are named by source key, not by the global number:
`chronological/02.html#fediverse-2339`. A link written before poems were
added then does one of two things, with no code on the page:
- the poem is still on page 02: the browser lands on it;
- the additions pushed it onto page 03: page 02 has no such anchor, and a
  browser that cannot find an anchor shows the top of the page. That is the
  owner's rule, and every browser already does it.
A numbered anchor (`#poem-1551`) would never reach the top-of-page case:
with numbers counted by date and pages cut by date, poem 1551 is always on
page 02, so after additions the old link lands on a different poem without
any sign. Numbered anchors go.

An anchor id is the source key as it is (`fediverse-2339`): letters, digits
and one dash. Two items with one key stop the build.

**Similar and different pages are named by source key too** (owner,
2026-10-21: "we will have to name these pages by source name as well"):
`similar/fediverse-2339-01.html`. A bookmarked address keeps showing its
poem's list until something earlier in that source is removed; then it
shows the neighbour's, as the owner accepted above.

### Suggested Implementation Steps

1. **Source keys.** The key is the source and its counting number
   (`fediverse-2339`), from the numbers the extractors already give out;
   pictures get theirs from the gallery order. Extraction stops on two items
   with one key.
2. **One counting step.** After extraction, sort every item (poems and
   gallery pictures) by date, then source name, and number 1..N. Pictures
   then sit among the poems by date (Issue 9-013), and the gallery index is
   counted separately over the pictures alone.
3. **Caches keyed by source name, checked by text.** The embeddings store
   each vector under its source name with a fingerprint of the text it was
   made from; the embedding stage re-embeds any item whose fingerprint
   differs, and refuses to hand a vector to an item whose text does not
   match. The similarity rankings and the diversity walk store source names
   (or are rebuilt each run from the vectors); the page builder turns them
   into this run's numbers with one table, source name to number.
4. **Anchors and page addresses by source key**: the chronological pages'
   anchors, the similar and different page file names, and every link to
   them (`ranked-page`, word pages, word cloud, source browser, the
   storage measure that counts page files).
5. **A check** (test and pre-flight): every vector's fingerprint matches its
   item's text, and every anchor id is unique.
6. **Re-embed once** under the new keys (the next `--force` build).

### Answered questions

- Long ids or counting numbers: counting numbers (owner, 2026-10-22, quoted
  above).
- Bluesky posts carry no id the extractor reads: counting them by creation
  time is enough ("I have not made two posts in the same millisecond").

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
