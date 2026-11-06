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

**2026-11-03: phase 5, project-file-server.** `project-file-server -I
[folder]` now opens a menu built with `lua-menu.sh`, in place of the
numbered prompt. A "Do" list chooses what Go does: generate the page, serve it
over HTTP, open it in a browser, or go into the chosen folder. The folder
section offers the current folder, its parent and its subfolders, plus
"Another folder..." to type one; this is the issue's "directory selection".
"Page goes to" offers the scanned folder or a typed file (the "output
configuration"), and a Port field sets where it is served. The panel below
the items shows a two-level tree of the folder under the cursor (the
"directory tree preview") and the end of the last generation. While
generating, the library's own progress lines show as it runs (the
"generation progress"). After each step the menu opens again with a one-line
note; q leaves. Tested by `tests/test-project-file-server-interactive.sh`
(23 checks, a real menu in a pretend terminal, including serving on a random
port until Ctrl+C).

Decisions:

- **One Go button and a "Do" list**, as in the other phases. `menu.lua` is
  left alone.
- **Stacked on PR #130 (issue 007).** On main the runner loads its library
  from under the folder being scanned, so it can only scan the monorepo
  itself. Choosing folders in a menu needs #130's fix.
- **"Go into the folder" instead of a separate browser.** Picking a subfolder
  and choosing Go into lists its own subfolders; the parent is always offered
  to move back up.
- **Serving binds to 127.0.0.1.** The old prompt served on every interface.
  The page lists the folder's contents and the server shares the page's whole
  folder, so other machines shouldn't reach it by default. Ctrl+C stops the
  server and returns to the menu: the menu catches the signal rather than
  ignoring it, since the server would inherit an ignored signal.
- **The port must be 1024-65535,** since lower ports need root.
- **`open` is used only on macOS.** On Linux the same name can be `openvt`.
  The old prompt fell back to it on any system.
- **The tree preview is two levels deep, hidden entries left out,** at most
  200 lines, and lists at most 60 subfolders, so a big folder stays quick.
  Names are printed as text and never run.

Phase 1 (filesystem_scanner.sh) is PR #213, phase 3 (state-daemon.sh) is PR
#211, phase 4 (backup-conversations) is PR #216, and phase 2's sync-visions
viewer is PR #170 (issue 005). With all of them merged, every phase has been
built.
