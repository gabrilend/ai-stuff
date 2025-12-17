# Lua Menu TUI Library

A framebuffer-based terminal UI library for interactive menus in bash scripts.
Uses Lua for rendering with diff-based updates for flicker-free display.

## Quick Start

```bash
#!/bin/bash
source "/path/to/libs/lua-menu.sh"

# Initialize
menu_init
menu_set_title "My Script" "Interactive Mode"

# Add sections and items
menu_add_section "options" "multi" "Options"
menu_add_item "options" "verbose" "Verbose Output" "checkbox" "0" "Enable detailed logging"

menu_add_section "actions" "single" "Actions"
menu_add_item "actions" "run" "Run Script" "action" "" "Execute with selected options"

# Run menu and get results
if menu_run; then
    if [[ "$(menu_get_value "verbose")" == "1" ]]; then
        echo "Verbose mode enabled"
    fi
fi
```

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

## API Reference

### Initialization

```bash
source "/path/to/libs/lua-menu.sh"

menu_init                              # Initialize menu system
menu_set_title "Title" "Subtitle"      # Set header text (subtitle optional)
```

### Sections

Sections group related items. Each section has a type that controls item behavior.

```bash
menu_add_section "section_id" "type" "Display Title"
```

**Section Types:**

| Type | Behavior | Use Case |
|------|----------|----------|
| `single` | Radio buttons - only one item can be selected | Mode selection |
| `multi` | Checkboxes - multiple items can be selected | Feature toggles |
| `list` | Same as multi, semantically for file/item lists | File selection |

### Items

```bash
menu_add_item "section_id" "item_id" "Label" "type" "value" "description"
```

**Item Types:**

#### checkbox
Binary toggle (checked/unchecked).

```bash
menu_add_item "options" "debug" "Debug Mode" "checkbox" "0" "Enable debug output"
menu_add_item "options" "color" "Color Output" "checkbox" "1" "Use ANSI colors"
```
- Value: `"0"` (unchecked) or `"1"` (checked)
- In `single` sections: behaves as radio button
- In `multi` sections: independent toggle

#### flag
Text entry field for numeric values.

```bash
menu_add_item "settings" "threads" "Thread Count" "flag" "4" "Number of parallel threads"
menu_add_item "settings" "timeout" "Timeout (sec)" "flag" "30" "Request timeout"
```
- Value: initial/default value (also used for RIGHT arrow reset)
- Config field can specify display width: `"value:width"` e.g., `"5:3"` for 3-char wide field
- Input: digits only (0-9), max 5 characters
- LEFT arrow: sets to "0"
- RIGHT arrow: sets to default value
- First digit typed clears field, subsequent digits append

#### multistate
Cycle through predefined options.

```bash
menu_add_item "output" "format" "Output Format" "multistate" "json" "json,xml,csv"
menu_add_item "log" "level" "Log Level" "multistate" "info" "debug,info,warn,error"
```
- Value: initial selection (must match one option)
- Config: comma-separated list of options
- SPACE/ENTER: cycle forward
- LEFT: cycle backward
- RIGHT: cycle forward

#### action
Execute button - triggers menu exit with "run" action.

```bash
menu_add_item "actions" "run" "Execute" "action" "" "Run with selected options"
menu_add_item "actions" "preview" "Preview" "action" "" "Show what would be executed"
```
- Value: ignored (use empty string)
- When activated (SPACE/ENTER), menu returns with "run" action
- Renders with `-->` indicator

### Running the Menu

```bash
if menu_run; then
    # User selected an action item - proceed with execution
    value=$(menu_get_value "item_id")
else
    # User quit (q/Q/ESC/Ctrl+C)
    echo "Cancelled"
    exit 0
fi
```

### Getting Values

```bash
menu_get_value "item_id"    # Returns current value for item
```

## Keyboard Controls

| Key | Action |
|-----|--------|
| `j` / `DOWN` | Move cursor down |
| `k` / `UP` | Move cursor up |
| `h` / `LEFT` | Uncheck checkbox / Set flag to 0 / Cycle multistate backward |
| `l` / `RIGHT` | Check checkbox / Set flag to default / Cycle multistate forward |
| `SPACE` / `i` / `ENTER` | Toggle checkbox / Cycle multistate / Activate action |
| `g` | Jump to first item |
| `G` | Jump to last item |
| `` ` `` / `~` | Jump to action item |
| `0-9` | Jump to item by index (see below) / Enter digits on flag fields |
| `BACKSPACE` | Delete last digit (flag fields) |
| `q` / `Q` / `ESC` | Quit menu |

### Index Selection (Repeated Digits)

Items are indexed using a repeated-digit pattern that allows quick access to any item:

| Items | Index Pattern | Keys to Press |
|-------|---------------|---------------|
| 1-9 | 1, 2, 3...9 | Single digit |
| 10 | 0 | `0` |
| 11-19 | 11, 22, 33...99 | Same digit twice |
| 20 | 00 | `0` twice |
| 21-29 | 111, 222, 333...999 | Same digit three times |
| 30 | 000 | `0` three times |

**Example:** To jump to item 22 (displayed as `222`):
1. Press `2` → goes to item 2
2. Press `2` again → goes to item 12
3. Press `2` again → goes to item 22

Pressing a different digit resets the sequence.

**Note:** Index shortcuts only apply to checkbox items. Flag (text-entry),
multistate, and action items are completely skipped in the numbering sequence.
When on a flag field, digit keys enter text instead of navigating.

## Complete Example

```bash
#!/bin/bash
# example-script.sh - Demonstrates all menu features

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBS_DIR="/home/ritz/programming/ai-stuff/scripts/libs"

source "${LIBS_DIR}/lua-menu.sh"

# ═══════════════════════════════════════════════════════════════════════════
# Initialize Menu
# ═══════════════════════════════════════════════════════════════════════════
menu_init
menu_set_title "Example Script" "Interactive Configuration"

# ═══════════════════════════════════════════════════════════════════════════
# Section 1: Mode Selection (radio buttons)
# ═══════════════════════════════════════════════════════════════════════════
menu_add_section "mode" "single" "Operation Mode"
menu_add_item "mode" "build" "Build Project" "checkbox" "1" \
    "Compile source files"
menu_add_item "mode" "test" "Run Tests" "checkbox" "0" \
    "Execute test suite"
menu_add_item "mode" "deploy" "Deploy" "checkbox" "0" \
    "Deploy to production"

# ═══════════════════════════════════════════════════════════════════════════
# Section 2: Options (checkboxes)
# ═══════════════════════════════════════════════════════════════════════════
menu_add_section "options" "multi" "Build Options"
menu_add_item "options" "verbose" "Verbose Output" "checkbox" "0" \
    "Show detailed progress"
menu_add_item "options" "clean" "Clean First" "checkbox" "1" \
    "Remove build artifacts before building"
menu_add_item "options" "parallel" "Parallel Build" "checkbox" "1" \
    "Use multiple CPU cores"

# ═══════════════════════════════════════════════════════════════════════════
# Section 3: Settings (numeric inputs and multistate)
# ═══════════════════════════════════════════════════════════════════════════
menu_add_section "settings" "multi" "Settings"
menu_add_item "settings" "jobs" "Job Count" "flag" "4" \
    "Number of parallel jobs (LEFT=0, RIGHT=default, type to edit)"
menu_add_item "settings" "timeout" "Timeout (min)" "flag" "10" \
    "Build timeout in minutes"
menu_add_item "settings" "target" "Target Platform" "multistate" "linux" \
    "linux,macos,windows"

# ═══════════════════════════════════════════════════════════════════════════
# Section 4: Files to Process (dynamic list)
# ═══════════════════════════════════════════════════════════════════════════
menu_add_section "files" "list" "Source Files"

# Add files dynamically
files=("main.c" "util.c" "config.c" "network.c")
for i in "${!files[@]}"; do
    menu_add_item "files" "file_$i" "${files[$i]}" "checkbox" "1" \
        "Include ${files[$i]} in build"
done

# ═══════════════════════════════════════════════════════════════════════════
# Section 5: Actions
# ═══════════════════════════════════════════════════════════════════════════
menu_add_section "actions" "single" "Actions"
menu_add_item "actions" "run" "Start Build" "action" "" \
    "Execute build with selected options"

# ═══════════════════════════════════════════════════════════════════════════
# Run Menu
# ═══════════════════════════════════════════════════════════════════════════
if menu_run; then
    # Extract selected mode
    if [[ "$(menu_get_value "build")" == "1" ]]; then
        MODE="build"
    elif [[ "$(menu_get_value "test")" == "1" ]]; then
        MODE="test"
    elif [[ "$(menu_get_value "deploy")" == "1" ]]; then
        MODE="deploy"
    fi

    # Extract options
    VERBOSE=""
    [[ "$(menu_get_value "verbose")" == "1" ]] && VERBOSE="--verbose"

    CLEAN=""
    [[ "$(menu_get_value "clean")" == "1" ]] && CLEAN="--clean"

    PARALLEL=""
    [[ "$(menu_get_value "parallel")" == "1" ]] && PARALLEL="--parallel"

    # Extract settings
    JOBS=$(menu_get_value "jobs")
    TIMEOUT=$(menu_get_value "timeout")
    TARGET=$(menu_get_value "target")

    # Collect selected files
    SELECTED_FILES=()
    for i in "${!files[@]}"; do
        if [[ "$(menu_get_value "file_$i")" == "1" ]]; then
            SELECTED_FILES+=("${files[$i]}")
        fi
    done

    # Execute
    echo "Mode: $MODE"
    echo "Options: $VERBOSE $CLEAN $PARALLEL"
    echo "Jobs: $JOBS, Timeout: $TIMEOUT, Target: $TARGET"
    echo "Files: ${SELECTED_FILES[*]}"

    # Your actual command here:
    # ./build.sh --mode "$MODE" $VERBOSE $CLEAN $PARALLEL \
    #     --jobs "$JOBS" --timeout "$TIMEOUT" --target "$TARGET" \
    #     "${SELECTED_FILES[@]}"
else
    echo "Cancelled by user."
    exit 0
fi
```

## Display Layout

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                              Example Script                                   ║
║                          Interactive Configuration                            ║
╠══════════════════════════════════════════════════════════════════════════════╣
   Operation Mode
   ──────────────
1  [*] Build Project
2  [ ] Run Tests
3  [ ] Deploy

   Build Options
   ─────────────
4  [ ] Verbose Output
5  [*] Clean First
6 >[*] Parallel Build              <- cursor here (inverse video)

   Settings
   ────────
7    Job Count: [    4]
8    Timeout (min): [   10]
9    Target Platform <[LINUX]>

   Source Files
   ────────────
*  [*] main.c
*  [*] util.c
*  [ ] config.c
*  [*] network.c

   Actions
   ───────
*    Start Build -->

───────────────────────────────────────────────────────────────────────────────
Include main.c in build
╠══════════════════════════════════════════════════════════════════════════════╣
║                     j/k:nav  space:toggle  `:action  q:quit                   ║
```

## Dependencies

- **LuaJIT** (2.0+ or LuaJIT 2.1)
- **dkjson** - JSON library for Lua (included in libs/lua/)

## Files

| File | Description |
|------|-------------|
| `lua-menu.sh` | Bash wrapper - source this in your scripts |
| `menu-runner.lua` | Standalone Lua runner (called by wrapper) |
| `menu.lua` | Menu component (sections, items, navigation) |
| `tui.lua` | Framebuffer terminal library (low-level rendering) |

## Tips

1. **Use descriptive IDs** - Item IDs are used with `menu_get_value`, make them readable
2. **Group related items** - Use sections to organize logically related options
3. **Provide helpful descriptions** - Shown at bottom when item is highlighted
4. **Always include an action** - Users must explicitly activate to run
5. **Flag field hints** - Include "LEFT=0, RIGHT=default" in description for flag items
