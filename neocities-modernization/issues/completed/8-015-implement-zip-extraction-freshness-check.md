# Issue 8-015: Implement ZIP Extraction Freshness Check

## Current Behavior

The `scripts/update` extraction script runs the full ZIP extraction pipeline every time, regardless of whether the source files have changed:

1. Creates a new temporary directory
2. Extracts all ZIP archives (651MB+ fediverse, 606MB+ messages)
3. Runs extraction scripts for fediverse, messages, and notes
4. Processes and generates JSON output files
5. Cleans up temporary files

This is wasteful when the source ZIP files haven't changed since the last extraction.

**Source files:**
- `input/most-recent-29.zip` (651MB) → fediverse data
- `input/similar-different.zip` (606MB) → additional archives

**Output files:**
- `input/fediverse/files/poems.json` (8.9MB)
- `input/messages/files/poems.json` (1.1MB)
- `input/notes/files/poems.json` (2.1MB)

## Intended Behavior

The extraction script should check if the output files are newer than the source ZIP files. If all outputs are fresh, skip the extraction entirely:

```
scripts/update
  ├── Check: Are all poems.json files newer than source ZIPs?
  │   ├── YES → Skip extraction, print "Extraction data is up to date"
  │   └── NO  → Run full extraction pipeline
  └── Continue with pipeline
```

This follows the same pattern as `M.is_html_fresh()` in `src/main.lua`.

## Implementation Steps

### Step 1: Add freshness check function to scripts/update ✅ COMPLETED
- [x] Implement `is_extraction_fresh()` bash function
- [x] Compare ZIP modification times to output JSON modification times
- [x] Return 0 (true) if all outputs are newer than all source ZIPs
- [x] Use `stat -c %Y` for portable modification time comparison

### Step 2: Update scripts/update to use freshness check ✅ COMPLETED
- [x] Add freshness check before extraction
- [x] Print status message when skipping extraction
- [x] Add `--force` flag to bypass freshness check

### Step 3: Test the implementation ✅ COMPLETED
- [x] Verify extraction skips when data is fresh
- [x] Verify extraction runs when ZIP is newer (tested with `touch`)
- [x] Verify `--force` flag works

## Dependencies

- Requires `scripts/update` modifications only (simpler than modifying Lua scripts)

## Quality Assurance Criteria

- [x] Extraction skips when all outputs are newer than inputs
- [x] Extraction runs when any source ZIP is newer than its output
- [x] `--force` flag bypasses freshness check
- [x] Pipeline still works correctly after changes

## Related Issues

- **Issue 8-001**: Integrate complete HTML generation into pipeline (uses similar pattern)

---

**ISSUE STATUS: COMPLETED**

**Created**: 2025-12-23

**Completed**: 2025-12-23

**Phase**: 8 (Website Completion)

## Implementation Log

### 2025-12-23: Implementation Completed
- Added `is_extraction_fresh()` bash function to `scripts/update`
- Function compares modification times of:
  - Source: All ZIP files in `input/` directory
  - Output: `input/{fediverse,messages,notes}/files/poems.json`
- Returns fresh (0) if oldest output is newer than newest ZIP
- Added `--force` / `-f` flag to bypass freshness check
- Tested all scenarios:
  - ✅ Skips extraction when outputs are newer
  - ✅ Runs extraction when ZIP is touched/updated
  - ✅ `--force` flag correctly bypasses check
