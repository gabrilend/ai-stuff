# 10-004: Implement Built-Up Command Preview System

## Status
- **Phase**: 10
- **Priority**: Medium
- **Type**: Enhancement
- **Status**: COMPLETED
- **Created**: 2025-12-23
- **Completed**: 2025-12-23

## Current Behavior

~~The `run.sh` script operates as a simple orchestrator without command preview.~~

**IMPLEMENTED**: Full TUI integration with real-time command preview.

## Implemented Behavior

The `-I` flag now launches a full TUI with:

1. **Pipeline Stages Section**: 7 checkboxes (one per stage), all mapped to CLI flags
2. **Configuration Section**: Thread count (flag type), force/dry-run/verbose checkboxes
3. **Command Preview Section**: Real-time preview that updates as options are toggled
4. **Actions Section**: Run button to execute selected stages

### Key Features

- **Real-time preview**: As users toggle options, the command preview updates instantly
- **Copy to clipboard**: Press `~` to copy the built-up command
- **Educational value**: Users learn CLI flags by watching the command build up
- **Fallback support**: Falls back to Lua TUI if bash TUI unavailable

### Example TUI Layout

```
╭─ Neocities Pipeline ────────────────────────────────────────────────────────╮
│ Use j/k to navigate, space to toggle, Enter to run                          │
├─ Pipeline Stages (toggle stages to run) ────────────────────────────────────┤
│ [x] 1. Update Words      Sync input files from words repository             │
│ [x] 2. Extract           Extract content from backup archives               │
│ [x] 3. Parse             Parse poems from JSON sources into poems.json      │
│ [x] 4. Validate          Run poem validation                                │
│ [x] 5. Catalog Images    Catalog images from input directories              │
│ [x] 6. Generate HTML     Generate website HTML                              │
│ [x] 7. Generate Index    Generate numeric similarity index                  │
├─ Configuration ─────────────────────────────────────────────────────────────┤
│ Thread Count: [  4]      Thread count for parallel HTML generation          │
│ [ ] Force Regeneration   Force regeneration even if files are fresh         │
│ [ ] Dry Run              Show what would be executed without running        │
│ [ ] Verbose Output       Show detailed progress information                 │
├─ Command Preview ───────────────────────────────────────────────────────────┤
│ ./run.sh --update-words --extract --parse --validate --catalog-images \     │
│          --generate-html --generate-index --threads 4                       │
│ (press ~ to copy to clipboard)                                              │
├─ Actions ───────────────────────────────────────────────────────────────────┤
│ [Run Selected Stages]                                                       │
╰─────────────────────────────────────────────────────────────────────────────╯
```

## Implementation Details (2025-12-23)

### Files Modified

1. **`run.sh`** - Added TUI integration:
   - Sources `/home/ritz/programming/ai-stuff/scripts/libs/lua-menu.sh`
   - Added `interactive_mode_tui()` function (lines 398-522)
   - Menu sections:
     - `stages`: 7 checkboxes with shortcuts 1-7 and CLI flags
     - `config`: thread flag, force/dry-run/verbose checkboxes
     - `preview`: command preview text item
     - `actions`: run button
   - `menu_set_command_config("./run.sh", "cmd_preview", "")` links checkboxes to preview
   - After TUI exits, falls through to execute selected stages

### Implementation Steps Completed

1. [x] Ensure run.sh has comprehensive CLI flag support (10-005 completed)
2. [x] Add TUI integration to run.sh (source lua-menu.sh)
3. [x] Add Command Preview section to TUI menu configuration
4. [x] Configure `menu_set_command_config` with appropriate parameters
5. [x] Each checkbox has associated CLI flag for command preview
6. [x] Clipboard copy via `~` key (built into TUI library)
7. [x] Updated help text to mention command preview

### Menu Item to CLI Flag Mapping

| Item ID | Label | CLI Flag |
|---------|-------|----------|
| update_words | 1. Update Words | --update-words |
| extract | 2. Extract | --extract |
| parse | 3. Parse | --parse |
| validate | 4. Validate | --validate |
| catalog_images | 5. Catalog Images | --catalog-images |
| generate_html | 6. Generate HTML | --generate-html |
| generate_index | 7. Generate Index | --generate-index |
| threads | Thread Count | --threads |
| force | Force Regeneration | --force |
| dry_run | Dry Run | --dry-run |
| verbose | Verbose Output | --verbose |

### Testing

```bash
# Launch TUI with command preview
./run.sh -I

# Non-interactive mode still works
./run.sh --validate --dry-run  # ✓ Works correctly
```

## Dependencies

- Issue 10-005: CLI flag support - **COMPLETED**
- TUI library: `/home/ritz/programming/ai-stuff/scripts/libs/lua-menu.sh`

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh` (reference implementation)
- `/home/ritz/programming/ai-stuff/scripts/libs/lua-menu.sh` (TUI library)
- `/mnt/mtwo/programming/ai-stuff/neocities-modernization/run.sh` (implemented)

---
