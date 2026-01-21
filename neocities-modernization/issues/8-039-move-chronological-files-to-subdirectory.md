# Issue 8-039: Move Chronological Files to Subdirectory

## Priority
Medium

## Current Behavior

Chronological HTML files are generated in the root of the output directory:
```
output/
├── chronological.html          (or redirect to chronological-01.html)
├── chronological-01.html
├── chronological-02.html
├── ...
├── similar/
│   └── XXXX-NN.html
└── different/
    └── XXXX-NN.html
```

This mixes chronological files with other root-level files and creates inconsistency with the similar/different structure.

## Intended Behavior

Move chronological files into their own subdirectory:
```
output/
├── chronological/
│   ├── index.html              (redirect to 01.html for clean URLs)
│   ├── 01.html
│   ├── 02.html
│   └── ...
├── similar/
│   └── XXXX-NN.html
└── different/
    └── XXXX-NN.html
```

**URL structure:**
- Local: `file:///home/ritz/programming/ai-stuff/neocities-modernization/output/chronological/01.html`
- Production: `/similar-different/chronological/01.html`

**Benefits:**
1. Consistent directory structure (similar/, different/, chronological/)
2. Cleaner root output directory
3. Easier to manage/delete chronological files as a unit
4. Matches typical web project organization

## Scope of Changes

### 1. File Output Location (`flat-html-generator.lua`)

**Current (lines ~2223-2256):**
```lua
output_file = string.format("%s/chronological-%02d.html", output_dir, page_num)
output_file = output_dir .. "/chronological.html"
```

**Change to:**
```lua
-- Ensure directory exists
local chrono_dir = output_dir .. "/chronological"
os.execute(string.format('mkdir -p "%s"', chrono_dir))

output_file = string.format("%s/chronological/%02d.html", output_dir, page_num)
-- Or with index.html as redirect:
output_file = output_dir .. "/chronological/index.html"
```

### 2. Links FROM Similar/Different Pages

**Current (lines ~1558, 2671, 2674):**
```lua
chronological_link = string.format("<a href='%s/chronological.html#%s'>chronological</a>", base_path, anchor_id)
chrono_link = string.format("<a href='%s/chronological-%02d.html#%s'>chronological</a>", ...)
```

**Change to:**
```lua
chronological_link = string.format("<a href='%s/chronological/01.html#%s'>chronological</a>", base_path, anchor_id)
-- Or for paginated:
chrono_link = string.format("<a href='%s/chronological/%02d.html#%s'>chronological</a>", ...)
```

### 3. Internal Pagination Links (within chronological pages)

**Current (lines ~2011-2035):**
```lua
"<a href='chronological-01.html'>« First</a>"
"<a href='chronological-%02d.html'>‹ Prev</a>"
```

**Change to:**
```lua
"<a href='01.html'>« First</a>"
"<a href='%02d.html'>‹ Prev</a>"
```

Since files are now in the same directory, simpler relative paths work.

### 4. Redirect/Index File

**Current (lines ~2241-2256):**
Creates `chronological.html` with redirect to `chronological-01.html`

**Change to:**
Create `chronological/index.html` with redirect to `01.html`:
```html
<meta http-equiv="refresh" content="0;url=01.html">
```

### 5. Base Path Calculation

**Current:**
Similar/different pages calculate `base_path` for linking to chronological:
```lua
-- From output/similar/0001-01.html to output/chronological.html
base_path = "file:///home/ritz/.../output"
```

**Verify:**
The existing `base_path` should still work since it points to the output root. Links just need `/chronological/` added.

### 6. URL Switching Script (`scripts/convert-urls`)

**May need updates for:**
- New path pattern: `output/chronological/` instead of `output/chronological*.html`
- Production path: `/similar-different/chronological/`

**Likely no changes needed** if the script does generic path replacement, but should be tested.

### 7. Filename Simplification (Optional Enhancement)

Consider simplifying filenames while in the subdirectory:
- `chronological/chronological-01.html` → `chronological/01.html`
- Removes redundant "chronological-" prefix

## Suggested Implementation Steps

1. **Create output directory structure**:
   ```lua
   local chrono_dir = output_dir .. "/chronological"
   os.execute(string.format('mkdir -p "%s"', chrono_dir))
   ```

2. **Update file output paths** in `generate_chronological_html()`:
   - Change output filename pattern
   - Update redirect/index file location

3. **Update chronological link generation**:
   - Search for all `chronological.html` and `chronological-%02d.html` references
   - Update to `chronological/01.html` or `chronological/%02d.html` pattern

4. **Update internal pagination links**:
   - Simplify to relative paths within the chronological directory

5. **Test link integrity**:
   - From similar pages → chronological (with anchor)
   - From different pages → chronological (with anchor)
   - Between chronological pages (pagination)

6. **Update URL switching script** if needed

7. **Clean up old files**:
   - Remove `output/chronological*.html` after migration
   - Or handle in a separate cleanup step

## Files to Modify

| File | Changes |
|------|---------|
| `src/flat-html-generator.lua` | Output paths, link generation, pagination links |
| `scripts/convert-urls` | Verify/update path patterns (if needed) |
| `run.sh` | Add mkdir for chronological/ if not handled in Lua |

## Related Documents

- `src/flat-html-generator.lua` - Primary implementation
- `scripts/convert-urls` - URL switching script
- `issues/completed/phase-9/9-005b-url-switching-helper-script.md` - URL conversion

## Testing Checklist

- [ ] Chronological files generated in `output/chronological/`
- [ ] Index/redirect file works at `chronological/index.html`
- [ ] Links from similar pages reach correct chronological page + anchor
- [ ] Links from different pages reach correct chronological page + anchor
- [ ] Pagination within chronological pages works
- [ ] URL switching script handles new paths (local ↔ production)
- [ ] No broken links in generated output

## Implementation Progress

### 2026-01-21: Implemented

**Changes to `src/flat-html-generator.lua`:**

1. **`generate_chronological_page_navigation()`** (lines 2149-2194):
   - Updated internal pagination links to use relative paths within `chronological/` directory
   - Changed from `chronological-01.html` to `01.html` (simpler relative paths)

2. **Output file paths** (lines 2382-2402):
   - Creates `chronological/` subdirectory with `mkdir -p`
   - Paginated: writes to `chronological/01.html`, `chronological/02.html`, etc.
   - Single page: writes to `chronological/index.html` (for clean URLs)

3. **Redirect/index file** (lines 2410-2426):
   - For paginated: creates `chronological/index.html` redirecting to `01.html`

4. **Links FROM similar/different TO chronological**:
   - `format_single_poem_with_progress_and_color()` (line 1696): `chronological/index.html#anchor`
   - Effil worker thread (lines 2860-2869):
     - Paginated: `chronological/02.html#anchor`
     - Single: `chronological/index.html#anchor`

5. **Log message update** (line 3416): Updated to reflect new path

**Directory structure after change:**
```
output/
├── chronological/
│   ├── index.html      (single page or redirect)
│   ├── 01.html         (if paginated)
│   ├── 02.html         (if paginated)
│   └── ...
├── similar/
└── different/
```

**No changes needed to:**
- `scripts/convert-urls` - Already uses generic path patterns

## Metadata

- **Status**: ✅ Complete
- **Created**: 2026-01-19
- **Completed**: 2026-01-21
- **Phase**: 8 (Website Completion / Structure)
- **Estimated Complexity**: Medium (multiple link references to update)
- **Dependencies**: None
- **Affects**: All generated HTML files (chronological, similar, different)
