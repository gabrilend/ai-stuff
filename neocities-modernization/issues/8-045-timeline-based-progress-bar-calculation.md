# Issue 8-045: Timeline-Based Progress Bar Calculation

## Priority
High (the bars on the owner's pages are visibly wrong and some overflow the frame)

## Status
- **REOPENED** 2026-09-22, sorted from `next-issue-please-sort` (items 1 and 7
  of that file). First completed 2026-01-30.
- **Umbrella**: 8-058 (the main-thread / worker duplication that let this drift).

## Current Behavior

The timeline calculation below was built, but only half the page builders use it.

- **Where it works.** The chronological position map
  (`compute_chronological_mapping()` in `src/flat-html-generator.lua`) gives every
  poem a `timeline_progress` value: the share of the author's writing span that
  had passed when the poem was written (a number, 0 to 100). The threaded worker
  that builds similar/different pages reads it, as do the chronological pages and
  the word pages.
- **Where it does not.** The single-threaded poem formatter,
  `format_single_poem_with_progress_and_color()`, was listed under Affected Files
  below but never converted. It still calls `calculate_chronological_progress()`,
  which divides the poem's global index (its position in the combined poem list,
  where poems are numbered source by source: fediverse first, then boosts,
  notes, and messages from about 6483 up) by a "total" found by
  `generate_paginated_poem_page_html()` and
  `generate_flat_poem_list_html_with_progress()`. That "total" is the largest
  `id` in the page's ranked list, and the list mixes two numbering schemes: the
  anchor poem is entered with its global index, every other entry with its
  per-source number (largest: fediverse 6458). So the bar shows
  "global index ÷ max(anchor's global index, about 6458)". Any poem from the
  messages range comes out near or above 100%, whatever its date.
- The owner's samples came from this single-threaded formatter. Only it writes a
  ` -> file: X` line above the top bar together with a centre "chronological"
  link, and the measured bar lengths fit its formula exactly. It runs when the
  thread count is 1, or when the effil threading library fails to load. That
  failure falls back to the formatter with only a warning (see 8-058).
- **No bound on the bar.** `progress_dashes()` in `src/poem-bars.lua`, and its
  main-thread twin `generate_progress_dashes()` in `flat-html-generator.lua`,
  multiply the percentage by the frame width (83 columns, 82 for golden poems)
  with no check that the percentage is between 0 and 100. A value of 117% draws
  97 filled cells and the bar runs past the frame.
- **Silent defaults hide a missing timeline entry.** The worker uses
  `timeline_progress = 50` when a poem has no map entry. The word pages
  (`generate-word-pages.lua`) fall back to the position calculation.

Measured against `assets/poems.json` by the 2026-09-22 investigation:

| Poem | Global index | Written | Place in date order | Timeline share (correct) | Bar the owner saw |
|---|---|---|---|---|---|
| messages/260 | 6742 | 2024-03-06 | 1842 of 8531 (21.6%) | 53.2% | 82 of 83 cells |
| messages/1514 | 7996 | 2026-05-12 | 8305 (97.4%) | 93.9% | 97 cells (overflows) |
| messages/1106 | 7588 | — | 7838 (91.9%) | 86.8% | 91 cells (overflows) |
| fediverse/696 | 701 | — | 1024 (12.0%) | 50.5% | 9 cells |

The owner's words, verbatim from the sorting inbox:

> progress bars are fucked. this one:
>
>  -> file: messages/260
> ══════════════════════════════════════════════════════════════════════════════════─
>  Also, if they delete it we should be entitled to a copy of it so we can post it
>  elsewhere. Otherwise they're destroying our content, which they orient their
>  business around and which we own.
>
> progress bar is almost full. yet it's from messages 260, which is clearly near
> the beginning of my corpus.

> also sometimes progress bars are too long? Like these two:
>
>  -> file: messages/1514
> ═════════════════════════════════════════════════════════════════════════════════════════════════
>  just because someone is giving you what you need doesn't mean they'll help you
>  when in need.
>
>  -> file: messages/1106
> ═══════════════════════════════════════════════════════════════════════════════════════════
>  "save yourself, do it for you" ugh what if I don't wanna

The ═/─ mix on the fediverse/696 sample in the same inbox is intended (8-035:
═ is the filled part, ─ the unfilled part). It stood out only because the
percentage feeding it was wrong.

## Original Behavior (pre-2026-01, kept as the rationale for the timeline design)

Progress bars were calculated based on **poem position** in the chronological list:

```lua
local progress_pct = (chrono_info.position / chrono_info.total_poems) * 100
```

This means:
- Poem #1 of 7844 = 0% progress
- Poem #3922 of 7844 = 50% progress
- Poem #7844 of 7844 = 100% progress

The bar fills uniformly regardless of when poems were actually written. A burst of 100 poems in one week takes up the same visual space as 100 poems spread across a year.

## Intended Behavior

Progress bars should be calculated based on **actual timestamps**:

```lua
local progress_pct = (poem_timestamp - first_timestamp) / (last_timestamp - first_timestamp) * 100
```

This means:
- First poem ever written = 0% progress
- Poem from the midpoint in time = ~50% progress (regardless of poem count)
- Most recent poem = 100% progress

### Visual Impact

**Before (position-based):**
```
Poem from Jan 2020:  ═══════════════────────────────────────────────────────────
Poem from Jun 2020:  ═════════════════════════════════────────────────────────── (even spacing)
Poem from Dec 2020:  ═══════════════════════════════════════════════────────────
```

**After (timeline-based):**
```
Poem from Jan 2020:  ═══════════────────────────────────────────────────────────
Poem from Jun 2022:  ═══════════════════════════════════════════════════════════ (2.5 years later = big jump)
Poem from Jul 2022:  ═══════════════════════════════════════════════════════════ (1 month later = tiny increment)
```

### Semantic Meaning

The progress bar becomes a **visual timeline** that:
1. Shows periods of prolific writing as dense clusters
2. Shows periods of silence as empty gaps
3. Directly correlates with chronological.html's structure
4. Gives viewers intuition about when in the author's life a poem was written

## Technical Design

### Data Requirements

Each poem needs a parseable timestamp. Current sources:

| Source | Timestamp Field | Format |
|--------|-----------------|--------|
| Fediverse | `metadata.creation_date` | ISO 8601 (`2024-01-15T14:30:00Z`) |
| Notes | `metadata.creation_date` or file mtime | ISO 8601 or Unix |
| Messages | `metadata.creation_date` | ISO 8601 |
| Bluesky | `metadata.creation_date` | ISO 8601 |

### Calculation Changes

**1. Pre-compute timeline bounds (once per generation):**
```lua
local first_timestamp = poems_data.poems[1].timestamp_unix
local last_timestamp = poems_data.poems[#poems_data.poems].timestamp_unix
local timeline_span = last_timestamp - first_timestamp
```

**2. Calculate progress for each poem:**
```lua
local poem_timestamp = poem.timestamp_unix or parse_timestamp(poem.metadata.creation_date)
local progress_pct = ((poem_timestamp - first_timestamp) / timeline_span) * 100
```

**3. Pass to chrono_map:**
```lua
chrono_map[poem_idx] = {
    position = i,                    -- Still useful for "poem N of M"
    page_number = page_num,
    total_poems = total_poems,
    total_pages = total_pages,
    timeline_progress = progress_pct  -- NEW: time-based progress
}
```

### Affected Files

1. **`src/flat-html-generator.lua`**:
   - `build_chronological_position_map()` - add timeline calculation
   - `format_single_poem_with_progress_and_color()` - use timeline_progress
   - Effil worker `format_poem_entry()` - use timeline_progress

2. **`src/poem-extractor.lua`** (possibly):
   - Ensure all poems have parseable timestamps
   - Add `timestamp_unix` field during extraction for efficiency

### Edge Cases

1. **Missing timestamps or a missing map entry**: an error naming the poem, not a
   fallback. (First built as "fall back to position" and "default to 50%"; both
   silent fallbacks hid the bug this reopening is about.)
2. **Same-day poems**: Will cluster together (intended behavior)
3. **Single poem**: 0% or 100%? (suggest: 50% to center it)
4. **Percentage outside 0–100** (future timestamp, bad input): an error naming
   the poem. The bar drawer never clamps silently.

## Suggested Implementation Steps

1. **Audit timestamp availability**:
   - Count poems with valid `metadata.creation_date`
   - Identify any sources missing timestamps

2. **Add timestamp parsing utility**:
   ```lua
   local function parse_iso_timestamp(iso_string)
       -- Convert "2024-01-15T14:30:00Z" to Unix timestamp
       local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)"
       local y, m, d, h, min, s = iso_string:match(pattern)
       return os.time({year=y, month=m, day=d, hour=h, min=min, sec=s})
   end
   ```

3. **Modify `build_chronological_position_map()`**:
   - Calculate first/last timestamps
   - Add `timeline_progress` to each entry

4. **Update progress bar generation**:
   - Use `chrono_info.timeline_progress` instead of position calculation
   - Keep position-based as fallback

5. **Update effil worker**:
   - Same changes as main scope

6. **Test with known timeline gaps**:
   - Find poems with large time gaps between them
   - Verify progress bar jumps appropriately

### Steps for the 2026-09-22 reopening

7. **Convert the single-threaded formatter.** **Done 2026-09-22.**
   `format_single_poem_with_progress_and_color()` reads the poem's
   `timeline_progress` from the chronological map, the same way the worker
   does. It and `format_all_poems_with_progress_and_color()` no longer take a
   poem total.
8. **Delete the old formula.** **Done 2026-09-22.**
   `calculate_chronological_progress()` and both "largest id in the ranked
   list" blocks are gone.
9. **Missing map entry is an error** **Done 2026-09-22** in the worker, the
   single-threaded formatter and the word pages, replacing the 50% default and
   the position fallback. Also: a poem with no date is an error in the
   chronological sort (it used to be dated by its id -- a few seconds after
   1970 -- which stretched the timeline back to 1970). The other date sources
   (a date in the first line, the file's timestamp) still stand behind a
   missing `creation_date`; every poem in the corpus has a `creation_date`
   today, so they never run. Because a worker can now stop with an error, the
   HTML orchestrator checks once a second for a failed worker and stops the
   run with its error (before, a dead worker left the orchestrator waiting
   forever). run.sh's pre-flight gate runs `scripts/check-poem-dates`, the
   same date reading, before any stage (10-069). Tests:
   `src/flat-html-generator.progress-bars.test.lua` (three poems numbered
   against their date order; an undated poem is refused).
10. **Bound the bar drawer.** **Done 2026-09-22.** `check_percentage()` in
    `src/poem-bars.lua` raises an error naming the poem (its `poem_id`, when
    the caller supplies one) when the percentage is below 0, above 100, missing
    or not a number. `progress_dashes()` calls it, and so does the main-thread
    copy (`generate_progress_dashes()` in `flat-html-generator.lua`) until step
    11 removes that copy. Tests: the 0%/100%/117%/-5%/missing/NaN cases in
    `src/poem-bars.test.lua` (40 checks pass).
11. **One bar drawer.** Delete the main-thread copies of the bar-drawing code in
    `flat-html-generator.lua` so every caller goes through `src/poem-bars.lua`
    (overlaps 8-058).
12. **Tests.** In `src/poem-bars.test.lua`: 0% and 100% draw the full frame width
    exactly; 117% raises an error. In the style of
    `src/flat-html-generator.chronological-links.test.lua`: a three-poem corpus
    whose global-index order is the reverse of its date order must produce bars
    that follow the dates, from both the worker and the single-threaded path.

## Configuration Options

Consider making this configurable in `config/input-sources.json`:

```json
"progress_bar": {
    "mode": "timeline",  // "timeline" or "position"
    "fallback_to_position": true  // If timestamp missing
}
```

## Visual Verification

After implementation, check a known gap period:
- If no poems exist between Jan 2021 and Jun 2021, poems from Dec 2020 and Jul 2021 should have a visible gap in their progress bars

## Related Documents

- `src/flat-html-generator.lua` - Progress bar generation
- `src/poem-extractor.lua` - Timestamp extraction
- `issues/8-030-add-chronological-anchor-links.md` - Chronological navigation
- `src/poem-bars.lua` - the bar drawer that needs the 0–100 bound
- `issues/8-058-eliminate-main-thread-worker-code-duplication.md` - the umbrella
- `issues/9-006-poem-box-format-validator.md` - the whole-output width checker
  that would catch an over-long bar

## Open Questions

1. **Answered: time share or place in order?** The design above fills the bar
   by the share of the writing *span* that had passed (messages/260 → 53%);
   place in date order would give 22%.
   - **Owner (2026-09-22):** "It should be by date. So if I wrote 3 poems in
     the first year, then 100 poems in the second year, then those 3 first
     poems would each get, what, 1/6th of the progress bar to themselves?"
   - **Confirmed:** yes. By date, the first year is the first half of the bar,
     so those 3 poems share that half and each has about 1/6 of the bar to
     itself. The 100 poems of year two share the second half.
   - **What it changes:** the timeline formula stays as designed, and
     messages/260's correct bar is about 53%. The work is only steps 7–12:
     bring the single-threaded path onto the timeline number and bound it.

## Metadata

- **Status**: Reopened 2026-09-22 (single-threaded path never converted; bars unbounded)
- **Created**: 2026-01-21
- **First completed**: 2026-01-30
- **Phase**: 8 (Website Completion)
- **Estimated Complexity**: Medium
- **Dependencies**: All poems need parseable timestamps
- **Affects**: Progress bar display on all pages

## Implementation Notes

**Audit Results:**
- All 7,844 poems have `creation_date` field (100% coverage)
- Timeline spans: April 2021 → January 2026 (~4.7 years)
- Timestamp format: ISO 8601 with optional milliseconds

**Files Modified:**
1. `src/flat-html-generator.lua`:
   - `compute_chronological_mapping()`: Now calculates `timeline_progress` for each poem
   - Chronological page generation: Uses timeline-based progress instead of position
   - Effil worker: Uses `timeline_progress` from chrono_map

2. `src/generate-word-pages.lua`:
   - Uses `timeline_progress` from chrono_map with position fallback

**Key Changes:**
- Progress bars now show actual temporal position in the author's timeline
- Periods of prolific writing appear as dense clusters
- Periods of silence appear as visible gaps in progression
- Falls back to position-based calculation if timeline_progress missing
