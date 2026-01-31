# Issue 10-016: TUI Per-Stage Regeneration Options

**Priority**: Medium
**Phase**: 10 (Developer Experience & Tooling)
**Status**: Open
**Created**: 2026-01-30

---

## Current Behavior

The `run.sh` TUI menu presents stage selection as binary checkboxes:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Pipeline Configuration                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Force regenerate all?                                                      │
│   [x] No  [ ] Yes                                                            │
│                                                                              │
│   Select stages to run:                                                      │
│   [x] 1.  update-words                                                       │
│   [x] 2.  extract                                                            │
│   [x] 3.  generate-poems-json                                                │
│   ...                                                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

There's no way to force regeneration of a **specific stage** without regenerating everything.

---

## Intended Behavior

### 1. Move "Force Regenerate All" to Top of Stages Section

Currently buried in options. Should be the first item in the stages section, making it:
- More discoverable
- Logically grouped with what it affects

### 2. Add Indented Per-Stage Regeneration Options

Each stage should have an indented sub-option for forcing regeneration:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Pipeline Configuration                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Select stages to run:                                                      │
│                                                                              │
│   [x] Force regenerate ALL stages                                            │
│                                                                              │
│   [x] 1.  update-words                                                       │
│       [ ] ↳ Force regenerate                                                 │
│   [x] 2.  extract                                                            │
│       [ ] ↳ Force regenerate                                                 │
│   [x] 3.  generate-poems-json                                                │
│       [ ] ↳ Force regenerate                                                 │
│   [x] 4.  generate-embeddings                                                │
│       [ ] ↳ Force regenerate                                                 │
│   ...                                                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3. Gray Out and Skip When "Force All" is Selected

When "Force regenerate ALL stages" is checked:
- All per-stage "Force regenerate" options become **grayed out**
- Navigation should **skip over** these options (not selectable)
- Visual indicator that they're overridden:

```
│   [x] Force regenerate ALL stages                                            │
│                                                                              │
│   [x] 1.  update-words                                                       │
│       [░] ↳ Force regenerate (overridden)                                    │
│   [x] 2.  extract                                                            │
│       [░] ↳ Force regenerate (overridden)                                    │
```

Or simply hide them when "Force All" is active:

```
│   [x] Force regenerate ALL stages                                            │
│                                                                              │
│   [x] 1.  update-words                                                       │
│   [x] 2.  extract                                                            │
│   [x] 3.  generate-poems-json                                                │
```

---

## Use Cases

### Case 1: Regenerate Only Embeddings

User updates the embedding model and wants to regenerate just the embeddings without re-extracting everything:

```
│   [ ] Force regenerate ALL stages                                            │
│                                                                              │
│   [x] 1.  update-words                                                       │
│       [ ] ↳ Force regenerate                                                 │
│   [x] 2.  extract                                                            │
│       [ ] ↳ Force regenerate                                                 │
│   [x] 3.  generate-poems-json                                                │
│       [ ] ↳ Force regenerate                                                 │
│   [x] 4.  generate-embeddings                                                │
│       [x] ↳ Force regenerate   ← Only this one                               │
```

### Case 2: Re-extract After Archive Update

User added a new messages archive and wants to re-extract only that stage:

```
│   [x] 2.  extract                                                            │
│       [x] ↳ Force regenerate                                                 │
```

### Case 3: Full Rebuild

User wants to start completely fresh:

```
│   [x] Force regenerate ALL stages                                            │
```

---

## Technical Implementation

### TUI Library Changes

The `scripts/lua-menu.sh` or equivalent TUI library needs:

1. **Nested/indented options**: Visual indentation for sub-options
2. **Conditional visibility**: Hide or gray-out options based on parent state
3. **Skip logic**: Navigation should jump over disabled options

### Proposed Data Structure

```lua
local menu_items = {
    {
        id = "force_all",
        label = "Force regenerate ALL stages",
        type = "checkbox",
        checked = false,
        disables = {"force_stage_1", "force_stage_2", ...}  -- IDs to disable when checked
    },
    {
        id = "stage_1",
        label = "1.  update-words",
        type = "checkbox",
        checked = true
    },
    {
        id = "force_stage_1",
        label = "↳ Force regenerate",
        type = "checkbox",
        checked = false,
        indent = 4,
        parent = "stage_1",  -- Only visible when parent is checked
        disabled_by = "force_all"  -- Grayed out when this is checked
    },
    -- ...
}
```

### Navigation Behavior

```lua
function next_selectable_item(items, current_index, direction)
    local idx = current_index + direction
    while idx >= 1 and idx <= #items do
        local item = items[idx]
        -- Skip disabled items
        if not is_disabled(item) then
            -- Skip hidden items (parent unchecked)
            if not is_hidden(item) then
                return idx
            end
        end
        idx = idx + direction
    end
    return current_index  -- No valid item found
end
```

---

## Suggested Implementation Steps

1. **Refactor TUI data model** to support indentation and parent-child relationships
2. **Add `disabled_by` field** to menu items
3. **Implement `is_disabled()` check** that looks at disabling items' state
4. **Update navigation logic** to skip disabled items
5. **Update rendering** to show grayed-out state for disabled items
6. **Move "Force All" option** to top of stages section
7. **Add per-stage force options** as indented children of each stage
8. **Connect to run.sh stage execution** - pass `--force-stage N` flags

---

## CLI Equivalent

For non-TUI usage, add corresponding flags:

```bash
./run.sh --force-stage 4 --force-stage 5
# Regenerates only stages 4 and 5, uses cached data for others

./run.sh --force-all
# Existing behavior - regenerates everything
```

---

## Success Criteria

- [ ] "Force regenerate ALL stages" moved to top of stages section
- [ ] Each stage has indented "Force regenerate" sub-option
- [ ] Sub-options grayed out when "Force All" is checked
- [ ] Navigation skips disabled/grayed options
- [ ] Per-stage force flags passed to pipeline correctly
- [ ] CLI `--force-stage N` flag working

---

## Related Files

- `run.sh` - Main pipeline script, stage execution
- `scripts/lua-menu.sh` - TUI menu library
- `issues/completed/7-003-cleanup-run-sh-output-formatting.md` - Parent issue

---

## Notes

- This is a significant TUI enhancement that may require refactoring the menu library
- Consider whether hidden vs grayed-out is better UX for disabled options
- The `--force-stage N` CLI flag allows scripted usage without TUI
- Each stage may need to implement its own force-regenerate behavior (delete cached files, etc.)
