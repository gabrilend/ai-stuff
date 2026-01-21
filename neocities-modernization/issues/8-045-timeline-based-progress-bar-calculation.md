# Issue 8-045: Timeline-Based Progress Bar Calculation

## Priority
Medium

## Current Behavior

Progress bars are calculated based on **poem position** in the chronological list:

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

1. **Missing timestamps**: Fall back to position-based for poems without dates
2. **Same-day poems**: Will cluster together (intended behavior)
3. **Single poem**: 0% or 100%? (suggest: 50% to center it)
4. **Future timestamps**: Clamp to 100%

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

## Metadata

- **Status**: Open
- **Created**: 2026-01-21
- **Phase**: 8 (Website Completion)
- **Estimated Complexity**: Medium
- **Dependencies**: All poems need parseable timestamps
- **Affects**: Progress bar display on all pages
