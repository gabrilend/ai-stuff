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

- [ ] All warning/error lines fully colorized (not just icon)
- [ ] Stage delimiters use magenta or gradient colors
- [ ] Stage numbers highlighted in green
- [ ] Visual consistency across all pipeline scripts

---

## Related Documents

- `issues/completed/7-003-cleanup-run-sh-output-formatting.md` - Parent issue with detailed proposals
