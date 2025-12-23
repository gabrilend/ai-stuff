# 10-004: Implement Built-Up Command Preview System

## Status
- **Phase**: 10
- **Priority**: Medium
- **Type**: Enhancement
- **Status**: Open
- **Created**: 2025-12-23

## Current Behavior

The `run.sh` script currently operates as a simple orchestrator that runs all pipeline stages sequentially without showing the user what will be executed. When using the `-I` flag for interactive mode, users can select options from `src/main.lua`'s menu, but there is no preview of the resulting command.

The script has minimal command-line interface:
```bash
./run.sh [-I] [--dir PATH] [PROJECT_DIR]
```

## Intended Behavior

Implement a "Command Preview" panel similar to `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh` (lines 767-774):

```bash
# Configure command preview section
menu_add_section "preview" "multi" "Command Preview"
menu_add_item "preview" "cmd_preview" "" "text" "" \
    "The command that will be executed (press ~ to copy to clipboard)"
menu_set_command_config "./run.sh" "cmd_preview" "files"
```

Key features:
1. **Real-time preview**: As users toggle options in the TUI, the preview updates to show the exact command that will be executed
2. **Copy to clipboard**: Press `~` to copy the built-up command for use elsewhere
3. **Educational value**: Users can learn the CLI flags by watching the command build up
4. **Transparency**: Users always know exactly what will run before execution

Example preview output:
```
╭─ Command Preview ─────────────────────────────────────────────────────────────╮
│ ./run.sh --update-words --extract --validate --generate-html --threads 4      │
│ (press ~ to copy to clipboard)                                                │
╰───────────────────────────────────────────────────────────────────────────────╯
```

## Reference Implementation

From `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh`:

The `menu_set_command_config` function takes three parameters:
1. Base command (e.g., `"./run.sh"`)
2. Preview item ID (where to display the command)
3. List section ID (items that affect the command)

The TUI library then automatically:
- Tracks which options/flags are enabled
- Builds the command string with appropriate flags
- Updates the preview item whenever options change

## Implementation Steps

1. [ ] Ensure run.sh has comprehensive CLI flag support (see issue 10-005)
2. [ ] Add TUI integration to run.sh (similar to issue 10-001 pattern)
3. [ ] Add Command Preview section to TUI menu configuration
4. [ ] Configure `menu_set_command_config` with appropriate parameters
5. [ ] Test that preview updates correctly when options are toggled
6. [ ] Test clipboard copy functionality with `~` key
7. [ ] Document the feature in usage help text

## Dependencies

- Issue 10-005: CLI flag support (required - command preview needs flags to display)
- Issue 10-001: TUI integration pattern (reference)
- TUI library: `/home/ritz/programming/ai-stuff/libs/menu.tui`

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh` (reference implementation)
- `/home/ritz/programming/ai-stuff/libs/menu.tui` (TUI library)
- `/mnt/mtwo/programming/ai-stuff/neocities-modernization/run.sh` (target script)

---
