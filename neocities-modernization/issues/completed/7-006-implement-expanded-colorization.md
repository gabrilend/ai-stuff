# Issue 7-006: Implement Expanded Colorization

**Priority**: Low
**Phase**: 7 (Stabilization and Polish)
**Status**: Open
**Created**: 2026-01-30

---

## Summary

Implement full-line colorization and colorful stage delimiters as proposed in 7-003's "Proposed Enhancement: Expanded Colorization" section.

---

## Current Behavior

Only icons/emojis are colorized while the rest of the line remains white:

```
⚠️  Skipped older: ./input/similar-different.zip (2025-12-13)
↑ yellow    ↑ white text
```

Stage delimiters are plain:

```
═══════════════════════════════════════════════════════════════════════════
📁 Stage 1/10: Updating input files from words repository
═══════════════════════════════════════════════════════════════════════════
```

---

## Intended Behavior

### Full-Line Colorization

When a line has semantic meaning, color the **entire line**:

```lua
-- Before:
print(COLOR_YELLOW .. "⚠️  " .. COLOR_RESET .. "Skipped older: " .. path)

-- After:
print(COLOR_YELLOW .. "⚠️  Skipped older: " .. path .. COLOR_RESET)
```

### Colorful Stage Delimiters

```
[magenta]════════════════════════════════════════════════════════════════════[reset]
[green]📁 Stage 1/10:[reset] Updating input files from words repository
[magenta]════════════════════════════════════════════════════════════════════[reset]
```

---

## Files to Update

| File | Changes |
|------|---------|
| `scripts/zip-extractor.lua` | Full-line coloring for warnings |
| `scripts/update-words` | Full-line coloring for sync status |
| `run.sh` | Colorful stage delimiters |
| `libs/utils.lua` | Add semantic output helpers (optional) |
| All extractor scripts | Consistent full-line coloring |

---

## Implementation

See `issues/completed/7-003-cleanup-run-sh-output-formatting.md` section "Proposed Enhancement: Expanded Colorization" for detailed implementation suggestions including:

- Stage delimiter function for bash
- Semantic line helpers for Lua
- Example code for both approaches

---

## Success Criteria

- [x] All warning/error lines fully colorized (not just icon)
- [x] Stage delimiters use magenta or gradient colors
- [x] Stage numbers highlighted in green
- [x] Visual consistency across all pipeline scripts

---

## Implementation Notes (2026-01-30)

### Stage Delimiters (run.sh)
- Added `COLOR_MAGENTA="\033[95m"` for bright magenta delimiters
- Updated `log_stage()` function to display:
  - Magenta `═══...═══` delimiters
  - Green stage text

### Full-Line Colorization (Lua scripts)
All print statements with semantic meaning now color the entire line instead of just the icon.

**Pattern change:**
```lua
-- Before: Only icon colored
print(COLOR_YELLOW .. "⚠️  " .. COLOR_RESET .. "Message: " .. value)

-- After: Full line colored
print(COLOR_YELLOW .. "⚠️  Message: " .. value .. COLOR_RESET)
```

**Files updated:**
- `scripts/zip-extractor.lua` - 7 instances
- `scripts/extract-notes.lua` - 2 instances
- `scripts/extract-fediverse.lua` - 5 instances
- `scripts/extract-messages.lua` - 4 instances

**Note:** `scripts/generate-html-parallel` uses colors in HTML output (not terminal), so no changes needed there.

---

## Related Documents

- `issues/completed/7-003-cleanup-run-sh-output-formatting.md` - Parent issue with detailed proposals
