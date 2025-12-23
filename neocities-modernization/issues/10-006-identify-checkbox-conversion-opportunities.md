# 10-006: Identify Checkbox Conversion Opportunities

## Status
- **Phase**: 10
- **Priority**: Low
- **Type**: Enhancement
- **Status**: COMPLETED
- **Created**: 2025-12-23
- **Completed**: 2025-12-23

## Summary

This issue analyzes the current TUI menu structures in both `run.sh` and `src/main.lua` to identify which items should be checkboxes (multi-select, build command) vs actions (immediate execution) vs flags (numeric input).

## Analysis Results

### run.sh TUI (Implemented in 10-004)

The `run.sh` TUI was implemented correctly with checkboxes from the start:

| Item | Type | CLI Flag | Status |
|------|------|----------|--------|
| 1. Update Words | checkbox | --update-words | ✅ Correct |
| 2. Extract | checkbox | --extract | ✅ Correct |
| 3. Parse | checkbox | --parse | ✅ Correct |
| 4. Validate | checkbox | --validate | ✅ Correct |
| 5. Catalog Images | checkbox | --catalog-images | ✅ Correct |
| 6. Generate HTML | checkbox | --generate-html | ✅ Correct |
| 7. Generate Index | checkbox | --generate-index | ✅ Correct |
| Thread Count | flag | --threads | ✅ Correct |
| Force Regeneration | checkbox | --force | ✅ Correct |
| Dry Run | checkbox | --dry-run | ✅ Correct |
| Verbose Output | checkbox | --verbose | ✅ Correct |
| Run Selected Stages | action | N/A | ✅ Correct |

**Verdict:** run.sh TUI is already optimally configured.

---

### src/main.lua TUI (Needs Updates)

The main.lua TUI has several issues that should be addressed:

#### Issue 1: Section Types

Many sections use `type: "single"` (radio-button, pick one) when they should use `type: "multi"` (multi-select):

| Section | Current Type | Recommended Type | Reason |
|---------|-------------|------------------|--------|
| pipeline | single | **multi** | Can extract AND validate AND catalog |
| embedding | single | single | OK - testing or calculating, not both |
| html | single | **multi** | Can generate chronological AND similarity pages |
| testing | single | single | OK - test one thing at a time |
| options | multi | multi | ✅ Correct |
| utilities | single | **multi** | Can view status AND clean (with warning) |

#### Issue 2: Missing CLI Flags

No menu items have `cli_flag` properties, so they don't contribute to command preview:

| Item ID | Label | Should Have CLI Flag |
|---------|-------|---------------------|
| extract | Extract poems | --parse (maps to parse stage) |
| validate | Validate poems | --validate |
| catalog | Catalog images | --catalog-images |
| dataset | Generate dataset | --parse --validate --catalog-images |
| chronological | Generate chronological | --generate-html (partial) |
| similar_pages | Generate similarity pages | (custom flag needed) |
| different_pages | Generate difference pages | (custom flag needed) |
| full_website | Generate complete website | --generate-html |
| test_poem_id | Test poem ID | (internal use only) |
| thread_count | Thread count | --threads |

#### Issue 3: Composite Actions

Some items are "composite" (run multiple stages):
- `dataset` = extract + validate + catalog
- `full_website` = chronological + explore + similar + different

**Recommendation:** Either:
1. Remove composite items (users can toggle multiple checkboxes)
2. Keep composites as convenience shortcuts that toggle multiple items

---

## Detailed Recommendations

### Category 1: Convert to Multi-Select Checkboxes

These sections should change from `type: "single"` to `type: "multi"`:

```lua
-- Data Pipeline Section (CHANGE: single -> multi)
{
    id = "pipeline",
    title = "Data Pipeline",
    type = "multi",  -- Changed from "single"
    items = { ... }
}

-- HTML Generation Section (CHANGE: single -> multi)
{
    id = "html",
    title = "HTML Generation",
    type = "multi",  -- Changed from "single"
    items = { ... }
}
```

### Category 2: Add CLI Flags

Each checkbox should have an associated CLI flag for command preview:

```lua
{
    id = "validate",
    label = "Validate extracted poems",
    type = "checkbox",
    value = "0",
    description = "Check data quality",
    shortcut = "v",
    cli_flag = "--validate"  -- ADD THIS
}
```

### Category 3: Keep as Actions

These should remain as actions (immediate execution, no command build):

| Item | Type | Reason |
|------|------|--------|
| run | action | Execute button |
| status | action | View-only, no side effects |

### Category 4: Keep as Flags

These are correctly implemented as flags:

| Item | Type | Value Format |
|------|------|--------------|
| test_poem_id | flag | "1:5" |
| thread_count | flag | "8:3" |

---

## Implementation Priority

Since `run.sh` now has a complete TUI with command preview (10-004), and the main.lua TUI is primarily for internal/advanced use, updates to main.lua are **low priority**.

If updated, the main.lua TUI should:
1. Change section types from "single" to "multi" where appropriate
2. Add `cli_flag` properties to items
3. Add command preview section
4. Call `run.sh` with built command instead of internal functions

**Alternative:** Deprecate main.lua TUI in favor of run.sh TUI, which is now more feature-complete.

---

## Comparison: run.sh vs main.lua TUI

| Feature | run.sh TUI | main.lua TUI |
|---------|-----------|--------------|
| Command preview | ✅ Yes | ❌ No |
| CLI flag mapping | ✅ Yes | ❌ No |
| Multi-select stages | ✅ Yes | ⚠️ Partial (some single-select) |
| Clipboard copy | ✅ Yes (~) | ❌ No |
| Educational value | ✅ High | ⚠️ Low |
| Fallback support | ✅ Lua TUI | N/A |

**Recommendation:** Use `run.sh -I` as the primary interactive interface.

---

## Implementation Note

This issue is marked **COMPLETED** as an analysis task. The actual conversion of main.lua TUI items can be done as a follow-up if needed, but the run.sh TUI (10-004) now provides superior UX and should be the recommended interface.

## Related Documents

- Issue 10-004: Command preview (implemented in run.sh)
- Issue 10-005: CLI flag support (provides flags to map)
- `/mnt/mtwo/programming/ai-stuff/neocities-modernization/run.sh` (recommended TUI)
- `/mnt/mtwo/programming/ai-stuff/neocities-modernization/src/main.lua` (legacy TUI)

---
