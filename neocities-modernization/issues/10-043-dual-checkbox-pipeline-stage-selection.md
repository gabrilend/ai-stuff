# Issue 10-043: Dual Checkbox Pipeline Stage Selection

## Status: Open
## Priority: Medium
## Phase: 10 (Developer Experience & Tooling)

## Current Behavior

The interactive mode (`run.sh -I`) currently presents pipeline stages with two separate menu items per stage:

```
[ ] 1. Update Words
[ ]     ↳ Force regenerate
[ ] 2. Extract
[ ]     ↳ Force regenerate
...
```

This creates several usability issues:
1. **Visual clutter**: 20+ menu items for 10 stages (doubled with force options)
2. **Semantic disconnect**: "Force" only makes sense when paired with "regenerate", but they're separate checkboxes
3. **Navigation overhead**: Moving between related options requires extra keystrokes
4. **Mental model mismatch**: Users think in terms of "run stage X with force" as a single decision

Additionally, the global "Force regenerate ALL stages" option at the top disables per-stage force options via dependency rules, which creates confusion about which force settings are active.

## Intended Behavior

### Visual Design

Replace the current dual-item layout with a **dual-checkbox-per-line** design:

```
   ,- regenerate
   |  ,- force
   |  |
  [ ][ ] all stages
  [ ][ ] 1. Update Words
  [ ][ ] 2. Extract
  [ ][ ] 3. Parse
  [ ][ ] 4. Validate
  [ ][ ] 5. Catalog Images
  [ ][ ] 6. Embeddings ⚠️
  [ ][ ] 7. Similarity ⚠️
  [ ][ ] 8. Diversity ⚠️
  [ ][ ] 9. Generate HTML
  [ ][ ] 10. Generate Index
```

### Visual Indicators

- **Regenerate checkbox** (first/left): Green asterisk `[*]` when enabled
- **Force checkbox** (second/right): Red asterisk `[*]` when enabled
- Both enabled: `[*][*]` with green and red respectively
- Neither enabled: `[ ][ ]`

### Selection Mechanics

#### Method 1: Toggle key (Enter/Space)
Four-state cycle per line:
1. Press 1: Enable regenerate → `[*][ ]` (green)
2. Press 2: Also enable force → `[*][*]` (green + red)
3. Press 3: Disable force only → `[*][ ]` (green)
4. Press 4: Disable regenerate → `[ ][ ]`
5. Press 5: (cycle repeats to state 1)

#### Method 2: Directional keys (Left/Right or h/l)
Direct navigation between checkboxes on same line:
- **Left (h)**: Move focus to regenerate checkbox, or disable if already there
- **Right (l)**: Move focus to force checkbox, or enable if already there

The right-key approach allows rapid selection: press right twice to set both checkboxes.

### "All Stages" Line Behavior

The first line controls all individual stage checkboxes collectively:

1. **Checking "all stages" regenerate**: Sets regenerate checkbox on ALL 10 stages
2. **Checking "all stages" force**: Sets BOTH regenerate and force on ALL 10 stages (force requires regenerate)
3. **Unchecking "all stages" regenerate**: Clears regenerate AND force on ALL stages
4. **Unchecking "all stages" force**: Clears only force on ALL stages (regenerate remains)

### Bidirectional Sync

The "all stages" line reflects the aggregate state:
- **Regenerate shows `[*]`**: When ALL 10 stages have regenerate checked
- **Force shows `[*]`**: When ALL 10 stages have both regenerate AND force checked
- **Regenerate shows `[ ]`**: When ANY stage has regenerate unchecked
- **Force shows `[ ]`**: When ANY stage has force unchecked

Example scenario:
1. User clicks "all stages" regenerate → All 10 stages get green `[*]`
2. User unchecks stage 5's regenerate → "all stages" regenerate becomes `[ ]`
3. User re-checks stage 5's regenerate → "all stages" regenerate returns to `[*]`

### CLI Flag Mapping

The dual checkboxes map to CLI flags:

| State | First Checkbox | Second Checkbox | CLI Flags |
|-------|---------------|-----------------|-----------|
| Off   | `[ ]`         | `[ ]`           | (none)    |
| Regen | `[*]` green   | `[ ]`           | `--stage-N` |
| Force | `[*]` green   | `[*]` red       | `--stage-N --force-stage N` |

Note: Force cannot be enabled without regenerate (semantically meaningless).

## Suggested Implementation Steps

### Phase 1: Menu Item Type Extension

1. **Add new item type "dual_checkbox"** to menu.lua state structure
   - Store two values per item: `regenerate_value` and `force_value`
   - Track which sub-checkbox has focus (0 = regenerate, 1 = force)

2. **Extend lua-menu.sh API**
   - New function: `menu_add_dual_checkbox "section" "item_id" "label" "regen_default" "force_default" "description" "regen_flag" "force_flag"`
   - Example: `menu_add_dual_checkbox "stages" "stage_1" "1. Update Words" "1" "0" "Sync input files" "--update-words" "--force-stage 1"`

### Phase 2: Rendering

1. **Update render_item()** in menu.lua
   - For dual_checkbox type: render `[X][Y] label` format
   - X = regenerate state (green `*` or space)
   - Y = force state (red `*` or space)
   - Apply ANSI colors: `\e[92m` for green, `\e[91m` for red

2. **Highlight focused sub-checkbox**
   - When navigating, show which sub-checkbox is active
   - Options: underline, bold, or inverted colors

### Phase 3: Input Handling

1. **Extend toggle_item()** for dual_checkbox
   - Implement 4-state cycle when pressing Enter/Space
   - Track: none → regen → regen+force → regen → none

2. **Add sub-checkbox navigation**
   - Left (h): Move focus to first checkbox or unset if on first
   - Right (l): Move focus to second checkbox or set if on second
   - Maintain consistent behavior with existing checkbox h/l shortcuts

3. **Constraint enforcement**
   - Cannot enable force without regenerate
   - Disabling regenerate automatically disables force

### Phase 4: "All Stages" Logic

1. **Implement aggregate line**
   - Special handling when item_id == "all_stages" or similar marker
   - On toggle: propagate state to all stage checkboxes

2. **Implement upward sync**
   - After any individual stage change, recalculate "all" state
   - Create helper: `recalculate_all_stages_state()`

3. **Visual feedback**
   - Consider brief flash animation when "all" propagates changes
   - Use existing flash_items mechanism from 10-018

### Phase 5: Command Preview Integration

1. **Update build_command_preview()** (or equivalent)
   - Dual checkbox with regen only: add stage flag (e.g., `--update-words`)
   - Dual checkbox with both: add stage flag AND force flag

2. **Update sync_checkboxes_from_command()**
   - Parse both stage flags and force-stage flags
   - Map back to dual_checkbox states

### Phase 6: Migration

1. **Update run.sh interactive_mode_tui()**
   - Replace 20 individual menu_add_item calls with 11 dual_checkbox calls
   - Remove dependency rules (no longer needed with unified checkboxes)

2. **Backward compatibility**
   - CLI flags remain unchanged
   - Values extraction at runtime maps to existing FORCE_STAGE_N variables

## Related Documents

- `run.sh:1238-1320` - Current pipeline stage TUI setup
- `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua` - Menu rendering and input
- `/home/ritz/programming/ai-stuff/scripts/libs/lua-menu.sh` - Bash wrapper API
- Issue 10-016: Per-stage regeneration options (current implementation)
- Issue 10-018: Animated command option transitions (potential flash effect)

## ASCII Art Reference

Current layout:
```
Pipeline Stages (toggle stages to run)
[ ] Force regenerate ALL stages
[*] 1. Update Words
[ ]     ↳ Force regenerate
[*] 2. Extract
[ ]     ↳ Force regenerate
...
```

Proposed layout:
```
   ,- regenerate
   |  ,- force
   |  |
  [ ][ ] all stages
  [*][ ] 1. Update Words
  [*][ ] 2. Extract
  [*][ ] 3. Parse
  [*][ ] 4. Validate
  [*][ ] 5. Catalog Images
  [ ][ ] 6. Embeddings ⚠️
  [ ][ ] 7. Similarity ⚠️
  [ ][ ] 8. Diversity ⚠️
  [*][ ] 9. Generate HTML
  [*][ ] 10. Generate Index
```

With force enabled on stage 9:
```
  [*][*] 9. Generate HTML        ← both green and red asterisks
```

## Notes

- This change reduces the stage section from 21 items to 11 items (52% reduction)
- The dual-checkbox pattern could be reused for other paired options in the future
- Consider whether the column headers (regenerate/force) should be rendered as part of section title or as a decorative element above the items
- The four-state cycle mimics familiar patterns from multi-state toggles (like tri-state checkboxes in file managers)

## Acceptance Criteria

- [ ] Dual checkboxes render correctly with green/red visual distinction
- [ ] Toggle cycling works: off → regen → regen+force → regen → off
- [ ] Left/right keys navigate between sub-checkboxes on same line
- [ ] "All stages" line propagates changes to all individual stages
- [ ] Individual stage changes update "all stages" line state correctly
- [ ] Command preview shows correct flags for each state
- [ ] Editing command preview syncs back to dual checkboxes correctly
- [ ] Force cannot be enabled without regenerate (constraint enforced)
- [ ] CLI execution produces correct --force-stage flags

---

Created: 2026-03-25
Author: gabrilend (via Claude Code)
