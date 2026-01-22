# Issue 6-031: Configurable Poem Exclusion Filter

## Priority
Medium

## Current Behavior

All extracted poems from all sources (fediverse, notes, messages, bluesky) are included in the final dataset. This includes:

- Mundane posts ("I wanted to transfer a craigslist link to my phone")
- Test posts
- Incomplete thoughts
- Posts that don't represent the poetic voice of the collection

These low-quality entries:
1. Pollute the semantic centroid calculations
2. Appear in similarity/diversity rankings where they don't belong
3. Reduce the overall coherence of the collection
4. Cannot be removed without manual post-processing

## Intended Behavior

A configuration file (`config/excluded-poems.txt`) allows specifying poems to exclude by their category-specific ID. Excluded poems are filtered out during the extraction/anonymization step, before they enter the pipeline.

### Config File Format

Simple, human-readable format with category sections:

```
# Poems to exclude from the collection
# Format: category-specific IDs, one per line
# Lines starting with # are comments
# Blank lines are ignored

notes:
what-a-lame-movie
craigslist-link-transfer
test-post-please-ignore

fediverse:
1234
5678
9012

messages:
42
108

bluesky:
at://did:plc:abc123/app.bsky.feed.post/xyz789
```

### ID Formats by Category

| Category | ID Format | Example |
|----------|-----------|---------|
| notes | Filename (without extension) | `what-a-lame-movie` |
| fediverse | Numeric post ID from ActivityPub | `1234567890` |
| messages | Numeric message index | `42` |
| bluesky | AT Protocol URI or record key | `3k...abc` |

### Exclusion Behavior

1. **During extraction**: Each extraction script checks the exclusion list
2. **Matching**: IDs are matched against the category-specific identifier
3. **Logging**: Excluded poems are logged with a count summary
4. **Metadata**: Extraction summary includes `poems_excluded` count

### ID Stability (CRITICAL)

**Excluded poems leave gaps - IDs must never shift.**

When `fediverse-0004` is excluded:
- ✅ Correct: `fediverse-0003`, (gap), `fediverse-0005`, `fediverse-0006`
- ❌ Wrong: `fediverse-0003`, `fediverse-0004` (was 5), `fediverse-0005` (was 6)

**Rationale:**
1. **Stable anchor links**: `#poem-fediverse-0004` should always point to the same poem (or nothing if excluded)
2. **External references**: Bookmarks, citations, and links remain valid
3. **Reproducibility**: Running the pipeline twice produces identical IDs
4. **Debugging**: ID mismatches between runs indicate real changes, not index drift

**Implementation requirement:**
- IDs are assigned based on the source data's inherent ordering (post ID, filename, etc.)
- Exclusion filters *after* ID assignment, not before
- The `poem_index` in poems.json may have gaps (e.g., 1, 2, 3, 5, 6 if 4 is excluded)
- HTML anchors use the original ID regardless of exclusion

### Example Output

```
📋 Extracting fediverse posts...
   ✅ Loaded 7500 activities
   🚫 Excluding 12 poems from config/excluded-poems.txt
   📝 Final count: 7488 poems
```

## Technical Design

### Config Parser

Create `libs/exclusion-filter.lua`:

```lua
-- {{{ load_exclusion_config
local function load_exclusion_config(config_path)
    local exclusions = {
        notes = {},
        fediverse = {},
        messages = {},
        bluesky = {}
    }

    local current_category = nil

    for line in io.lines(config_path) do
        -- Skip comments and blank lines
        line = line:match("^%s*(.-)%s*$")  -- trim
        if line == "" or line:match("^#") then
            goto continue
        end

        -- Check for category header
        local category = line:match("^(%w+):$")
        if category and exclusions[category] then
            current_category = category
            goto continue
        end

        -- Add ID to current category
        if current_category then
            exclusions[current_category][line] = true
        end

        ::continue::
    end

    return exclusions
end
-- }}}

-- {{{ is_excluded
local function is_excluded(exclusions, category, id)
    if not exclusions[category] then return false end
    return exclusions[category][tostring(id)] == true
end
-- }}}
```

### Integration Points

**1. `scripts/extract-fediverse.lua`**:
```lua
local exclusions = load_exclusion_config("config/excluded-poems.txt")
-- In main extraction loop:
if is_excluded(exclusions, "fediverse", post_id) then
    excluded_count = excluded_count + 1
    goto continue
end
```

**2. `scripts/extract-notes.lua`**:
```lua
-- ID is the filename without extension
local note_id = filename:match("(.+)%..+$") or filename
if is_excluded(exclusions, "notes", note_id) then
    excluded_count = excluded_count + 1
    goto continue
end
```

**3. `scripts/extract-messages.lua`**:
```lua
if is_excluded(exclusions, "messages", message_index) then
    excluded_count = excluded_count + 1
    goto continue
end
```

**4. Bluesky extraction** (if exists):
```lua
-- ID could be the rkey or full AT URI
if is_excluded(exclusions, "bluesky", record_key) then
    excluded_count = excluded_count + 1
    goto continue
end
```

### Finding Poem IDs

To identify poems for exclusion, users can:

1. **Browse chronological.html**: Each poem shows its source identifier
2. **Search poems.json**: `jq '.poems[] | select(.content | contains("craigslist"))' input/fediverse/files/poems.json`
3. **Use grep on output**: Search generated HTML for content snippets
4. **Review word cloud outliers**: Words that seem out of place may indicate problematic poems

### Edge Cases

1. **Missing config file**: Continue without exclusions (log warning)
2. **Invalid category**: Ignore unknown category headers (log warning)
3. **Non-existent ID**: Silently ignore (poem may have already been removed)
4. **Duplicate IDs**: Deduplicated by hash table storage
5. **ID gaps in output**: Expected and correct - similarity rankings skip missing IDs gracefully
6. **Chronological display**: Excluded poems simply don't appear; surrounding poems keep their positions

## Suggested Implementation Steps

1. **Create config file structure**:
   - Create `config/excluded-poems.txt` with header comments
   - Add example entries for each category

2. **Create exclusion filter library**:
   - Create `libs/exclusion-filter.lua`
   - Implement `load_exclusion_config()`
   - Implement `is_excluded()`
   - Add helper for counting exclusions

3. **Integrate with extract-fediverse.lua**:
   - Load exclusion config at startup
   - Check each post before processing
   - Track and report exclusion count

4. **Integrate with extract-notes.lua**:
   - Same pattern as fediverse
   - Use filename as ID

5. **Integrate with extract-messages.lua**:
   - Same pattern
   - Use message index as ID

6. **Integrate with bluesky extraction** (if applicable):
   - Same pattern
   - Use record key as ID

7. **Update extraction summary**:
   - Add `poems_excluded` to JSON output
   - Add exclusion count to console output

8. **Test with sample exclusions**:
   - Add a few test poems to exclusion list
   - Run extraction pipeline
   - Verify excluded poems don't appear in poems.json

9. **Document ID discovery methods**:
   - Add section to docs explaining how to find poem IDs
   - Include jq query examples

## Future Enhancements

- **Exclusion reasons**: Optional comment after ID explaining why excluded
- **Regex patterns**: Match content patterns instead of specific IDs
- **Inclusion list**: Inverse - only include specified poems
- **Quality scoring**: Automatic detection of low-quality content
- **UI for curation**: Web interface for reviewing and excluding poems

## Related Documents

- `scripts/extract-fediverse.lua` - Primary extraction script
- `scripts/extract-notes.lua` - Notes extraction
- `scripts/extract-messages.lua` - Messages extraction
- `config/input-sources.json` - Other configuration
- `issues/6-030-enhance-embedding-content-preprocessing.md` - Related quality improvements

## Metadata

- **Status**: Complete
- **Created**: 2026-01-21
- **Completed**: 2026-01-21
- **Phase**: 6 (Embedding & Semantic)
- **Estimated Complexity**: Low-Medium
- **Dependencies**: None
- **Affects**: All extraction scripts, final poem count, semantic calculations

---

## Implementation Notes (2026-01-21)

### Files Created

1. **`config/excluded-poems.txt`** - Configuration file with category sections:
   - Supports `fediverse:`, `notes:`, `messages:`, `bluesky:` sections
   - Comments start with `#`, blank lines ignored
   - IDs listed one per line under their category
   - Includes documentation header with ID format examples

2. **`libs/exclusion-filter.lua`** - Exclusion filter library:
   - `M.load(file_path)` - Load exclusions from a specific path
   - `M.load_default(dir)` - Load from default config location
   - `filter:is_excluded(category, id)` - Check if a poem should be excluded
   - `filter:count([category])` - Get exclusion count (total or per-category)
   - `filter:get_excluded_ids(category)` - List excluded IDs for debugging
   - `filter:summary()` - Human-readable summary string

### Scripts Updated

1. **`scripts/extract-fediverse.lua`**:
   - Loads exclusion filter after ActivityPub data
   - Checks `poem_exclusions:is_excluded("fediverse", poem_id)` before processing
   - Uses `goto continue` to skip excluded poems (ID still increments)
   - Reports exclusion stats: `"🚫 Excluded posts: N (tombstoned)"`
   - Adds `poems_excluded` to extraction_summary JSON

2. **`scripts/extract-notes.lua`**:
   - Notes use filename (without extension) as exclusion ID
   - Same pattern: check before processing, report stats

3. **`scripts/extract-messages.lua`**:
   - Messages use formatted index ("0001", "0002") as exclusion ID
   - Same pattern: check before processing, report stats

### ID Stability Implementation

The critical requirement that excluded poems leave ID gaps is implemented by:
1. Assigning IDs **before** the exclusion check
2. Using `goto continue` to skip processing but preserve ID sequence
3. In messages, incrementing `i` even for excluded entries

Example: If poem 0004 is excluded, the sequence remains 0001, 0002, 0003, 0005, 0006... (gap where 0004 was).

### Usage Example

```bash
# Add exclusion to config
echo "0042" >> config/excluded-poems.txt  # under fediverse: section

# Re-run extraction
luajit scripts/extract-fediverse.lua

# Output will show:
# 🚫 Exclusion filter loaded: fediverse: 1
# ...
# 🚫 Excluded posts: 1 (tombstoned)
```

### Testing

Tested with temporary config file containing fediverse IDs 0003 and 0005:
- `is_excluded("fediverse", "0001")` → false ✓
- `is_excluded("fediverse", "0003")` → true ✓
- `is_excluded("fediverse", "0005")` → true ✓
- `is_excluded("fediverse", "0007")` → false ✓
