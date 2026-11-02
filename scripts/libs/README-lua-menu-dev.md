# Lua Menu TUI - Developer Guide

Integrate interactive TUI menus into your bash scripts using this Lua-based library.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Your Script    │────▶│   lua-menu.sh    │────▶│ menu-runner.lua │
│  (bash)         │     │  (bash wrapper)  │     │    (luajit)     │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                         │
                               ┌─────────────────────────┴─────────┐
                               ▼                                   ▼
                        ┌─────────────┐                    ┌─────────────┐
                        │  menu.lua   │                    │   tui.lua   │
                        │ (component) │                    │(framebuffer)│
                        └─────────────┘                    └─────────────┘
```

## Quick Start

```bash
#!/bin/bash
LIBS_DIR="/home/ritz/programming/ai-stuff/scripts/libs"
source "${LIBS_DIR}/lua-menu.sh"

menu_init
menu_set_title "My Tool" "Configuration"

menu_add_section "opts" "multi" "Options"
menu_add_item "opts" "verbose" "Verbose" "checkbox" "0" "Enable verbose output"

menu_add_section "actions" "single" "Actions"
menu_add_item "actions" "run" "Run" "action" "" "Execute the tool"

if menu_run; then
    [[ "$(menu_get_value "verbose")" == "1" ]] && echo "Verbose enabled"
fi
```

## API Reference

### Initialization

```bash
source "${LIBS_DIR}/lua-menu.sh"
menu_init
menu_set_title "Title" "Subtitle"   # Subtitle is optional
```

### Sections

```bash
menu_add_section "section_id" "type" "Display Title"
```

| Type | Behavior | Use Case |
|------|----------|----------|
| `single` | Radio buttons - only one checkbox can be selected | Mode selection |
| `multi` | Independent checkboxes | Feature toggles |
| `list` | Same as multi (semantic alias) | File selection |

### Items

```bash
menu_add_item "section_id" "item_id" "Label" "type" "value" "description" "shortcut"
```

The 7th parameter `shortcut` is optional and defines a custom keyboard shortcut for the item.

| Parameter | Required | Description |
|-----------|----------|-------------|
| section_id | Yes | ID of the section to add item to |
| item_id | Yes | Unique identifier for the item |
| Label | Yes | Display text |
| type | Yes | checkbox, flag, multistate, select, select_dynamic, or action |
| value | Yes | Initial value |
| description | Yes | Help text shown when item is highlighted |
| shortcut | No | Single character keyboard shortcut (e.g., "r") |

#### checkbox

Binary toggle. In `single` sections, behaves as radio button.

```bash
menu_add_item "opts" "debug" "Debug Mode" "checkbox" "0" "Enable debug output"
menu_add_item "opts" "color" "Color Output" "checkbox" "1" "Use ANSI colors"
menu_add_item "opts" "reset" "Reset Settings" "checkbox" "0" "Reset to defaults" "r"
```

- **value**: `"0"` (unchecked) or `"1"` (checked)
- **Keyboard**: SPACE toggles, LEFT unchecks, RIGHT checks
- **Index shortcuts**: Only checkbox items get numeric index shortcuts
- **Custom shortcut**: The 7th parameter adds a quick-access key (shown in footer)

#### flag

Numeric text entry field.

```bash
menu_add_item "cfg" "threads" "Threads" "flag" "4" "Number of worker threads"
menu_add_item "cfg" "timeout" "Timeout" "flag" "30" "Timeout in seconds"
```

- **value**: Initial/default value (RIGHT arrow restores this)
- **Keyboard**:
  - Digits 0-9 enter values (first digit clears, subsequent append)
  - LEFT sets to "0", RIGHT sets to default
  - BACKSPACE deletes last digit
- **No index shortcut**: Flag items don't receive index numbers

#### multistate

Cycle through predefined options.

```bash
menu_add_item "out" "format" "Format" "multistate" "json" "json,xml,csv"
menu_add_item "log" "level" "Level" "multistate" "info" "debug,info,warn,error"
```

- **value**: Initial selection (must match one of the options)
- **config**: Comma-separated list of options (passed as 5th argument)
- **Keyboard**: SPACE/RIGHT cycle forward, LEFT cycles backward
- **No index shortcut**: Multistate items don't receive index numbers

#### select

Choose one value from a list in a dropdown (issue 017). Closed it reads
`Server: [GPU Server ▼]`; SPACE/ENTER opens a box of the options over the rows
below (above, when there is no room below).

```bash
menu_add_item "settings" "server" "Server" "select" "" "Which server" "" "--server"
menu_set_item_options "server" \
    "gpu|GPU Server|192.168.0.115:10265" \
    "local|Local|localhost:11434" \
    "off|Offline||switched off for the night"
```

- **Options**: one argument each, `value|label|description|disabled_reason`.
  Only the value is needed. An option with a disabled reason shows dim and
  cannot be chosen; the reason is shown when the cursor is on it.
- **value**: the chosen option's value. Left empty, the item starts on its
  first option that can be chosen. An item with no options shows
  `(no options available)` and does not open.
- **Closed**: LEFT/RIGHT cycle through the options, passing over disabled ones.
- **Open**: j/k (arrows) move, SPACE/ENTER choose and close, ESC/q close and
  keep the old value, HOME/END go to the ends, any other letter or digit
  jumps to the next option whose label starts with it (so `g` reaches
  "GPU Server"). Every key goes to the dropdown while it is open. A list
  longer than ten shows ten at a time with a scrollbar in the box's border.
- **Command preview**: adds `flag value`, as multistate does.

#### select_dynamic

A select item whose options are fetched each time it opens.

```bash
menu_add_item "settings" "server" "Server" "select_dynamic" "" "Which server" "" "--server"
menu_set_item_options_command "server" "./list-servers --menu-lines"
```

The command prints one `value|label|description|disabled_reason` line per
option. "loading..." shows while it runs; the list is kept until the next
opening, so drawing and LEFT/RIGHT never run it. From Lua, `options` may be a
function returning a list of `{value=, label=, description=, disabled=,
disabled_reason=}` tables (or plain strings) instead.

#### action

Execute button - activating returns from menu with "run" action.

```bash
menu_add_item "actions" "run" "Execute" "action" "" "Run with current settings"
```

- **value**: Ignored (use empty string)
- **Keyboard**: SPACE/ENTER activates, `` ` `` jumps here
- **No index shortcut**: Action items don't receive index numbers

### Custom Shortcuts

Define custom keyboard shortcuts for quick item access:

```bash
menu_add_item "cache" "flush" "Flush Cache" "checkbox" "0" "Clear all cached data" "f"
menu_add_item "cache" "rebuild" "Rebuild Index" "checkbox" "0" "Regenerate search index" "r"
menu_add_item "actions" "run" "Execute" "action" "" "Run operations" "x"
```

**Behavior:**
- First press: Jump to the item
- Second press (when already on item): Toggle/activate the item

**Display:**
- Shortcuts are shown in a cyan-colored line in the footer
- Format: `key:label` (e.g., `f:flush  r:rebuild  x:execute`)

**Best Practices:**
- Use memorable single letters (f=flush, r=reset, c=clean)
- Avoid conflicts with built-in keys (j, k, g, G, h, l, i, q, space, etc.)
- Safe choices: b, c, d, e, f, m, n, o, p, r, s, t, u, v, w, x, y, z

### Running & Results

```bash
if menu_run; then
    # User activated an action item
    value=$(menu_get_value "item_id")
    echo "Got: $value"
else
    # User quit (q/ESC/Ctrl+C)
    echo "Cancelled"
    exit 0
fi
```

## Complete Example

```bash
#!/bin/bash
# build-tool.sh - Interactive build configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBS_DIR="/home/ritz/programming/ai-stuff/scripts/libs"

source "${LIBS_DIR}/lua-menu.sh"

# ═══════════════════════════════════════════════════════════════════════════
# Initialize
# ═══════════════════════════════════════════════════════════════════════════
menu_init
menu_set_title "Build Tool" "Select build configuration"

# ═══════════════════════════════════════════════════════════════════════════
# Section 1: Build Mode (radio buttons)
# ═══════════════════════════════════════════════════════════════════════════
menu_add_section "mode" "single" "Build Mode"
menu_add_item "mode" "debug" "Debug Build" "checkbox" "1" \
    "Build with debug symbols and no optimization"
menu_add_item "mode" "release" "Release Build" "checkbox" "0" \
    "Build with full optimization"
menu_add_item "mode" "test" "Test Build" "checkbox" "0" \
    "Build and run test suite"

# ═══════════════════════════════════════════════════════════════════════════
# Section 2: Options (checkboxes)
# ═══════════════════════════════════════════════════════════════════════════
menu_add_section "options" "multi" "Build Options"
menu_add_item "options" "clean" "Clean First" "checkbox" "1" \
    "Remove build artifacts before building"
menu_add_item "options" "verbose" "Verbose Output" "checkbox" "0" \
    "Show detailed compiler output"
menu_add_item "options" "parallel" "Parallel Build" "checkbox" "1" \
    "Use multiple CPU cores"

# ═══════════════════════════════════════════════════════════════════════════
# Section 3: Settings (numeric inputs)
# ═══════════════════════════════════════════════════════════════════════════
menu_add_section "settings" "multi" "Settings"
menu_add_item "settings" "jobs" "Job Count" "flag" "4" \
    "Number of parallel jobs (LEFT=0, RIGHT=default)"
menu_add_item "settings" "opt_level" "Optimization" "multistate" "2" \
    "0,1,2,3,s,z"

# ═══════════════════════════════════════════════════════════════════════════
# Section 4: Targets (dynamic list)
# ═══════════════════════════════════════════════════════════════════════════
menu_add_section "targets" "list" "Build Targets"

targets=("libcore" "libutil" "main" "tests")
for i in "${!targets[@]}"; do
    default=$([[ "$i" -lt 3 ]] && echo "1" || echo "0")
    menu_add_item "targets" "target_$i" "${targets[$i]}" "checkbox" "$default" \
        "Build ${targets[$i]}"
done

# ═══════════════════════════════════════════════════════════════════════════
# Section 5: Action
# ═══════════════════════════════════════════════════════════════════════════
menu_add_section "actions" "single" "Actions"
menu_add_item "actions" "run" "Start Build" "action" "" \
    "Begin build with selected configuration"

# ═══════════════════════════════════════════════════════════════════════════
# Run Menu
# ═══════════════════════════════════════════════════════════════════════════
if menu_run; then
    # Extract mode
    MODE="debug"
    [[ "$(menu_get_value "release")" == "1" ]] && MODE="release"
    [[ "$(menu_get_value "test")" == "1" ]] && MODE="test"

    # Extract options
    CLEAN=$([[ "$(menu_get_value "clean")" == "1" ]] && echo "--clean")
    VERBOSE=$([[ "$(menu_get_value "verbose")" == "1" ]] && echo "--verbose")
    PARALLEL=$([[ "$(menu_get_value "parallel")" == "1" ]] && echo "--parallel")

    # Extract settings
    JOBS=$(menu_get_value "jobs")
    OPT=$(menu_get_value "opt_level")

    # Collect targets
    TARGETS=()
    for i in "${!targets[@]}"; do
        [[ "$(menu_get_value "target_$i")" == "1" ]] && TARGETS+=("${targets[$i]}")
    done

    # Execute
    echo "Building: $MODE"
    echo "Options: $CLEAN $VERBOSE $PARALLEL"
    echo "Jobs: $JOBS, Optimization: -O$OPT"
    echo "Targets: ${TARGETS[*]}"

    # ./build.sh --mode "$MODE" $CLEAN $VERBOSE $PARALLEL \
    #     --jobs "$JOBS" -O"$OPT" "${TARGETS[@]}"
else
    echo "Build cancelled."
    exit 0
fi
```

## Dependencies

- **LuaJIT** 2.0+ or LuaJIT 2.1
- **dkjson** - JSON library (located at `/home/ritz/programming/ai-stuff/libs/lua/`)

## Files

| File | Description |
|------|-------------|
| `lua-menu.sh` | Bash wrapper - source this in your scripts |
| `menu-runner.lua` | Standalone Lua entry point |
| `menu.lua` | Menu component (sections, items, navigation) |
| `tui.lua` | Framebuffer terminal library (rendering) |

## How It Works

1. **lua-menu.sh** collects menu configuration via bash function calls
2. Configuration is written to a temp JSON file
3. **menu-runner.lua** is invoked via `luajit`
4. Lua renders TUI directly to `/dev/tty` (bypasses stdout capture)
5. User interacts with menu
6. Results returned as JSON to stdout
7. **lua-menu.sh** parses results and populates `MENU_VALUES` array

## Tips

1. **Use descriptive IDs** - They're used with `menu_get_value`, keep them readable
2. **Group logically** - Use sections to organize related options
3. **Always include an action** - Users must explicitly select to run
4. **Document flag fields** - Include "LEFT=0, RIGHT=default" hints in descriptions
5. **Test with many items** - Index shortcuts scale automatically (11, 22, 111, etc.)
