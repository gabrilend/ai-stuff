# Issue 016: Dynamic File Dependencies Based on Mode Selection

**Phase:** 0 - Tooling/Infrastructure
**Type:** Enhancement
**Priority:** High
**Status:** Completed

---

## Current Behavior

Previously, all issue files in the TUI list were always enabled regardless of which operation mode was selected. This allowed users to select files that couldn't actually be processed by the chosen mode, leading to confusion or wasted processing.

---

## Intended Behavior

Issue files should be dynamically disabled (shown with gray `[o]`) based on:

1. **Mode compatibility** - Only files that can be processed by the selected mode should be enabled
2. **Skip Analyzed interaction** - Files that would be skipped should be disabled when Skip Analyzed is on
3. **Clear feedback** - Disabled files show why they're disabled and which option(s) to change

---

## Dependency Rules Implemented

### Rule 1: Review Structures Mode
- **Condition:** File is NOT a root issue with sub-issues
- **Trigger:** `review=1`
- **Message:** "Review mode: only root issues with sub-issues (enable Analyze)"
- **Effect:** Sub-issues and standalone issues are disabled when Review mode is selected

### Rule 2: Execute Recommendations Mode
- **Condition:** File has NO existing analysis AND is not a root with subs
- **Trigger:** `execute=1`
- **Message:** "Execute mode: no analysis to execute (run Analyze first)"
- **Effect:** Files without analysis can't have recommendations executed

### Rule 3: Clear Analysis Mode
- **Condition:** File has NO existing analysis AND is not a root with subs
- **Trigger:** `clear=1`
- **Message:** "Clear mode: no analysis to clear"
- **Effect:** Files without analysis can't have anything cleared

### Rule 4: Skip Analyzed (Regular Analysis)
- **Condition:** File HAS existing analysis (`## Sub-Issue Analysis` or `## Initial Analysis`)
- **Trigger:** `skip_existing=1`
- **Message:** "Skipped: has existing analysis (disable Skip Analyzed)"
- **Effect:** In Analyze mode with Skip on, analyzed files are disabled

### Rule 5: Skip Analyzed (Structure Reviews)
- **Condition:** File HAS existing structure review (`## Structure Review`)
- **Trigger:** `skip_existing=1`
- **Message:** "Skipped: already structure-reviewed (disable Skip Analyzed)"
- **Effect:** In Review mode with Skip on, reviewed roots are disabled

---

## Implementation Details

Added to the file item loop in `run_tui()`:

1. Track file properties: `is_sub`, `is_root_with_subs`, `has_analysis`, `has_struct_review`
2. After adding each file item, conditionally add dependencies based on properties
3. Dependencies use `menu_add_dependency` with `invert=true` to disable when condition IS met

---

## Acceptance Criteria

- [x] Review mode disables non-root issues
- [x] Execute mode disables issues without analysis
- [x] Clear mode disables issues without analysis
- [x] Skip Analyzed disables issues with analysis (in analyze mode)
- [x] Skip Analyzed disables structure-reviewed roots (in review mode)
- [x] Disabled items show descriptive reason with suggested action
- [x] Disabled items are automatically unchecked and removed from command

---

## Related Documents

- `issue-splitter.sh` - Implementation location
- `libs/lua-menu.sh` - Dependency API
- `libs/menu.lua` - Dependency rendering
