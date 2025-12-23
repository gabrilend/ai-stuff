# 10-006: Identify Checkbox Conversion Opportunities

## Status
- **Phase**: 10
- **Priority**: Low
- **Type**: Enhancement
- **Status**: Open
- **Created**: 2025-12-23

## Current Behavior

When the TUI is integrated (via issue 10-001 or run.sh), many options are likely implemented as action buttons or sequential menu items. The user must navigate and select each option individually.

## Intended Behavior

Options that represent independent, toggleable stages should be converted to checkboxes. This allows users to:
1. Select multiple stages at once
2. See at a glance which stages are enabled
3. Toggle stages on/off without navigating to each one
4. Build up a command with multiple flags (for command preview system)

### Checkbox vs Action Analysis

**Should be Checkboxes** (independent, toggleable, contribute to command):
- Pipeline stages:
  - [ ] Update words
  - [ ] Extract content
  - [ ] Validate poems
  - [ ] Catalog images
  - [ ] Generate HTML
  - [ ] Generate numeric index
- Configuration toggles:
  - [ ] Force regeneration
  - [ ] Verbose output
  - [ ] Dry run mode

**Should be Actions** (immediate execution, don't build up):
- "Run Selected Operations" (execute button)
- "Help" (display help)
- "Quit" (exit TUI)

**Should be Text Entry (flag type)**:
- Thread count (numeric input)
- Output directory path
- Test poem ID

### Reference from issue-splitter.sh

The issue-splitter.sh demonstrates the pattern (lines 675-706):

```bash
# Checkboxes (multi-select section with items that build up command)
menu_add_section "options" "multi" "Options"
menu_add_item "options" "execute_all" "No Confirmations" "checkbox" "0" \
    "Skip all confirmation prompts during execution" "" "--force"
menu_add_item "options" "feedback" "Feedback Loop" "checkbox" "0" \
    "Ask for feedback and offer retry after each operation" "" "--feedback"

# Flag type for numeric values (value:width format)
menu_add_section "streaming" "multi" "Streaming Settings"
menu_add_item "streaming" "parallel" "Parallel Jobs" "flag" "3:2" \
    "Max concurrent Claude calls (type 1-10)" "" "--parallel"
```

Key observation: Each checkbox/flag has an associated CLI flag (last parameter) that gets added to the command preview.

## Implementation Steps

1. [ ] Review current TUI implementation in src/main.lua interactive mode
2. [ ] List all menu items that represent optional stages
3. [ ] For each item, determine if it should be:
   - checkbox (toggleable, builds command)
   - flag (numeric/text input, builds command)
   - action (immediate, no command contribution)
4. [ ] Document the recommended type for each menu item
5. [ ] Update TUI configuration to use checkbox type where appropriate
6. [ ] Ensure each checkbox has a corresponding CLI flag (from issue 10-005)
7. [ ] Test that toggling checkboxes updates command preview (issue 10-004)

## Analysis Template

For each menu item, record:

| Item | Current Type | Recommended Type | CLI Flag | Reason |
|------|-------------|------------------|----------|--------|
| Update words | action | checkbox | --update-words | Independent stage |
| Thread count | ? | flag | --threads | Numeric input |
| Run | action | action | N/A | Execute button |

## Dependencies

- Issue 10-001: TUI integration (provides menu structure to analyze)
- Issue 10-005: CLI flag support (provides flags to associate)
- Issue 10-004: Command preview (checkboxes feed into this)

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh` (checkbox pattern reference)
- `/home/ritz/programming/ai-stuff/libs/menu.tui` (TUI library types)
- `/mnt/mtwo/programming/ai-stuff/neocities-modernization/src/main.lua` (current interactive menu)

---
