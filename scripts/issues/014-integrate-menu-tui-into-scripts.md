# 014: Integrate Menu TUI into More Scripts

## Current Behavior

The `lua-menu.sh` / `menu.lua` TUI library is primarily used by `issue-splitter.sh`. Other scripts that could benefit from interactive mode still use basic argument parsing:

- `filesystem_scanner.sh` - No interactive mode
- `sync-visions.sh` - Has `-I` flag but limited TUI
- `state-daemon.sh` - CLI only, no interactive browsing
- `backup-conversations` - No project selection TUI
- `project-file-server` - Basic `-I` mode without full menu

## Intended Behavior

All scripts that accept multiple options or operate on selectable targets should support a consistent `-I` / `--interactive` mode using the `lua-menu.sh` library:

- **filesystem_scanner.sh**: Directory selection, cron configuration
- **sync-visions.sh**: Project selection, sync options
- **state-daemon.sh**: Key browsing, value editing, watch mode
- **backup-conversations**: Project selection with transcript preview
- **project-file-server**: Directory selection, output configuration

## Suggested Implementation Steps

### Phase 1: filesystem_scanner.sh
1. Source `libs/lua-menu.sh`
2. Add directory selection section with recent directories
3. Add cron configuration section with schedule preview
4. Add action buttons (Scan Now, Install Cron, Remove Cron)

### Phase 2: sync-visions.sh
1. Source `libs/lua-menu.sh`
2. Add project multi-select with vision preview
3. Add options section (clear first, verbose, stats only)
4. Show sync statistics in content panel

### Phase 3: state-daemon.sh
1. Source `libs/lua-menu.sh`
2. Add key list section with current values
3. Add action buttons (Set, Delete, Clear All)
4. Add watch mode with auto-refresh

### Phase 4: backup-conversations
1. Source `libs/lua-menu.sh`
2. Add project list with conversation count
3. Add output path configuration
4. Show sample transcript in preview panel

### Phase 5: project-file-server
1. Enhance existing `-I` mode
2. Add directory tree preview
3. Add output configuration section
4. Show generation progress

## Source Scripts

- `./libs/lua-menu.sh` (TUI library)
- `./issue-splitter.sh` (reference implementation)

## Example Integration Pattern

```bash
#!/bin/bash
# Example script integration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/libs/lua-menu.sh"

if [[ "$1" == "-I" || "$1" == "--interactive" ]]; then
    menu_init
    menu_set_title "Script Name"

    # Add sections
    menu_add_section "options" "Options" "checkbox"
    menu_add_item "options" "verbose" "Verbose output" "checkbox" false
    menu_add_item "options" "dry_run" "Dry run" "checkbox" false

    menu_add_section "targets" "Targets" "radio"
    menu_add_item "targets" "all" "All items" "radio" true
    menu_add_item "targets" "selected" "Selected only" "radio" false

    menu_add_section "actions" "Actions" "action"
    menu_add_item "actions" "run" "Run" "action"
    menu_add_item "actions" "cancel" "Cancel" "action"

    menu_run

    case "$MENU_RESULT_ACTION" in
        run)
            VERBOSE=$(menu_get_value "verbose")
            DRY_RUN=$(menu_get_value "dry_run")
            # Continue with execution
            ;;
        cancel)
            exit 0
            ;;
    esac
else
    # Traditional CLI mode
    parse_args "$@"
fi
```

## Related Documents

- `README.md` - Scripts documentation
- `libs/lua-menu.sh` - TUI library documentation
- `libs/README-lua-menu-user.md` - User guide
- `libs/README-lua-menu-dev.md` - Developer guide

## What Happened

**2026-11-03: phase 3, state-daemon.sh.** `state-daemon.sh -I` opens a menu
built with `lua-menu.sh`. It lists every key as `key = value`, with the full
pair in the description line. A "Do" list chooses what Go does: Refresh,
Set a key, Delete the checked keys, Clear all keys, Watch, Stop the daemon
(or Start the daemon when it is not running). After each step the menu opens
again with fresh values and a one-line note in the subtitle; q leaves.
`state-daemon.sh watch [secs]` is the watch mode on its own. Tested by
`tests/test-state-daemon-interactive.sh` (16 checks, a real menu in a
pretend terminal). It needed the fix in issue 052 first, so a daemon can run
in a test's own folder; the branch is stacked on it.

Decisions:

- **One Go button and a "Do" list, not one button per action.** `menu_run`
  reports only that an action was pressed, not which one. Telling actions
  apart would mean changing `menu.lua`, which PRs #93 and #197 are also
  rewriting.
- **Set asks at a plain prompt after the menu closes.** The menu has no
  free-text field. A key must be one word with no `=`, because the daemon
  reads the first word of a SET line as the key and `dump` writes `key=value`.
- **Clear asks y/N first**; delete acts only on the keys checked with space.
- **Watch is its own loop rather than a menu that refreshes itself.** The
  menu cannot redraw on a timer. Watch redraws every 2 seconds until any key
  is pressed. Without a terminal on standard input it keeps to the interval
  instead of spinning.

Phases 1 (filesystem_scanner.sh), 4 (backup-conversations) and 5
(project-file-server) are still to do. Phase 2's sync-visions viewer is PR
#170 (issue 005).
