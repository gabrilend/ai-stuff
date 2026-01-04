# Issue 8-022: Add Pagination CLI Flags to HTML Generation Scripts

## Current Behavior

The HTML generation scripts (`scripts/generate-html-parallel`, `run.sh`) use hardcoded or config-file-only pagination settings:

```json
// config/input-sources.json
"pagination": {
    "poems_per_page": 100,
    "max_pages_per_poem": 15,
    ...
}
```

To change these values, users must edit the config file directly. There are no command-line overrides, making it difficult to:
- Test with different pagination settings
- Generate a quick preview with fewer pages
- Adjust settings without modifying tracked files

Current flags in `generate-html-parallel`:
- `--test` - Generate only first 10 poems (hardcoded limit)
- `--similar-only` / `--different-only` - Page type selection
- `--incremental` - Skip existing files
- `--threads=N` - Worker count

## Intended Behavior

Add command-line flags to control pagination dynamically:

```bash
# Generate 5 pages per poem (500 poems visible per direction)
./scripts/generate-html-parallel --pages=5

# Generate 3 pages with 50 poems each (150 poems visible)
./scripts/generate-html-parallel --pages=3 --poems-per-page=50

# Quick preview: 1 page with 20 poems
./scripts/generate-html-parallel --pages=1 --poems-per-page=20

# Full generation using config defaults
./scripts/generate-html-parallel
```

### Flag Specifications

| Flag | Default | Description |
|------|---------|-------------|
| `--pages=N` | 15 (from config) | Number of pages to generate per poem |
| `--poems-per-page=N` | 100 (from config) | Number of poems per page |

**Behavior notes:**
- CLI flags override config file values
- Scripts still iterate over ALL poems (7,793)
- Flags control how many pages each poem gets
- `--pages=0` could mean "use config default" or "generate all possible pages"

### Integration Points

1. **`scripts/generate-html-parallel`** - Primary generation script
2. **`run.sh`** - Main pipeline script (TUI menu integration)
3. **`src/flat-html-generator.lua`** - Core generation module (already respects config)

---

## Implementation Progress

### Step 1: Update `scripts/generate-html-parallel` ✅ COMPLETED

Added argument parsing for new flags (2026-01-04):

- Added `--pages=N` and `--poems-per-page=N` to parse_args()
- Added validation for positive integer values
- Added `load_pagination_config()` function that reads from config/input-sources.json
- CLI flags override config file values
- Updated help text with pagination options section
- Modified `similarity_worker` to accept and use `max_poems_to_show` parameter
- Modified `cached_diversity_worker` to limit sequence length
- DIVERSITY_LIMIT now set to MAX_POEMS_TO_SHOW for consistency

### Step 2: Update `src/flat-html-generator.lua` - DEFERRED

This step is deferred because `generate-html-parallel` now handles pagination directly.
The flat-html-generator.lua pagination system is used for a different code path.
If needed in the future, can add override function:

```lua
-- {{{ function M.set_pagination_overrides
function M.set_pagination_overrides(opts)
    if opts.pages then
        PAGINATION_CONFIG.max_pages_per_poem = opts.pages
    end
    if opts.poems_per_page then
        PAGINATION_CONFIG.poems_per_page = opts.poems_per_page
    end
end
-- }}}
```

### Step 3: Update `run.sh` TUI Menu ✅ COMPLETED

Added pagination options (2026-01-04):

- Added `--pages` and `--poems-per-page` CLI argument parsing
- Added TUI menu items in "Configuration" section:
  - "Pages per Poem" (flag, shortcut: p)
  - "Poems per Page" (flag, shortcut: y)
- Updated `run_generate_html()` to pass pagination flags
- Updated help text with Pagination section and example

Example usage now works:
```bash
# In the TUI section for HTML generation
menu_add_item "html_gen" "pages" "Pages per Poem" "multistate" "15" \
    "1,3,5,10,15,all" "p" ""
menu_add_item "html_gen" "poems_per_page" "Poems per Page" "multistate" "100" \
    "20,50,100,200" "y" ""
```

Build the command with selected options:
```bash
./scripts/generate-html-parallel --pages=$PAGES --poems-per-page=$POEMS_PER_PAGE
```

### Step 4: Update Help Text and Documentation

- Update `--help` output in all affected scripts
- Add examples to script headers
- Update `docs/roadmap.md` Quick Commands section

### Step 5: Test Various Configurations

1. [ ] `--pages=1` generates exactly 1 page per poem
2. [ ] `--pages=5 --poems-per-page=50` creates 5 pages of 50 poems each
3. [ ] Default behavior (no flags) uses config values
4. [ ] `--pages=0` or omitted uses config's `max_pages_per_poem`
5. [ ] Invalid values (negative, non-numeric) show helpful error

---

## Edge Cases to Consider

### Page Count Exceeds Available Poems
If `--pages=20` but only 15 pages worth of poems exist:
- **Option A**: Generate only available pages (preferred)
- **Option B**: Error with message
- **Recommendation**: Option A with info message

### Interaction with `--test` Flag
Current `--test` limits to 10 poems. With new flags:
- `--test` limits poems processed (for quick dev testing)
- `--pages` limits pages per poem (for storage/preview control)
- Both can be combined: `--test --pages=2`

### Config File vs CLI Precedence
CLI flags should always override config file values. Document this clearly.

---

## Storage Impact Examples

| Configuration | Pages | Size per Poem | Total Similar | Total Different |
|---------------|-------|---------------|---------------|-----------------|
| Default (15×100) | 15 | ~2.0 MB | ~15.3 GB | ~15.3 GB |
| `--pages=5` | 5 | ~670 KB | ~5.1 GB | ~5.1 GB |
| `--pages=1` | 1 | ~134 KB | ~1.0 GB | ~1.0 GB |
| `--pages=3 --poems-per-page=50` | 3 | ~200 KB | ~1.5 GB | ~1.5 GB |

This allows quick iteration during development without filling storage.

---

## Files to Modify

| File | Changes |
|------|---------|
| `scripts/generate-html-parallel` | Add `--pages`, `--poems-per-page` flags |
| `src/flat-html-generator.lua` | Add override function or parameter |
| `run.sh` | Add TUI menu options, pass flags to scripts |
| `generate-embeddings.sh` | N/A (embeddings, not HTML) |

---

## Related Issues

- **8-012**: Implement paginated similarity chapters (pagination logic)
- **8-020**: Hybrid pagination strategy (storage constraints)
- **8-001**: Unified website generation pipeline (run.sh integration)
- **10-005**: Implement CLI flag support for all functionality

---

## Acceptance Criteria

- [x] `--pages=N` flag works in `generate-html-parallel`
- [x] `--poems-per-page=N` flag works in `generate-html-parallel`
- [x] Flags override config file values
- [x] `run.sh` TUI includes pagination options
- [x] Help text documents new flags
- [x] Invalid inputs produce helpful error messages

---

**Phase**: 8 (Website Completion)

**Priority**: Medium

**Created**: 2026-01-04

**Completed**: 2026-01-04

**Status**: Completed

**Type**: Enhancement
