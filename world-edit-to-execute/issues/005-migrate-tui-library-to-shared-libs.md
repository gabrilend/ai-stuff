# Issue 005: Migrate TUI Library to Shared Libs Directory

**Phase:** 0 - Tooling/Infrastructure
**Type:** Enhancement
**Priority:** Medium
**Affects:** src/cli/lib/tui.sh (to be created)
**Dependencies:** 004-redesign-interactive-mode-interface

---

## Current Behavior

The TUI (Terminal User Interface) library will be created as part of issue 004,
located within this project at `src/cli/lib/tui.sh`. This limits reusability
across other projects.

---

## Intended Behavior

Extract the TUI library to the shared libs directory so it can be used by
multiple projects:

**Shared Library Location:**
```
/home/ritz/programming/ai-stuff/libs/
└── tui/
    ├── tui.sh              Main TUI module
    ├── checkbox.sh         Checkbox component
    ├── multistate.sh       Multi-state toggle component
    ├── number-input.sh     Number input component
    ├── keybindings.sh      Key reading and vim bindings
    └── README.md           Usage documentation
```

**Project Symlinks:**
```
/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/
└── src/
    └── cli/
        └── lib/
            └── tui -> /home/ritz/programming/ai-stuff/libs/tui
```

---

## Suggested Implementation Steps

### 1. Create Shared Libs Directory Structure

```bash
mkdir -p /home/ritz/programming/ai-stuff/libs/tui
```

### 2. Create Modular TUI Components

**Main module (`tui.sh`):**
```bash
#!/bin/bash
# tui.sh
# Terminal User Interface library for checkbox-style interactive menus
#
# Usage:
#   source /home/ritz/programming/ai-stuff/libs/tui/tui.sh
#   tui_init
#   # ... use components ...
#   tui_cleanup

TUI_LIB_DIR="${TUI_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}"

# Source components
source "${TUI_LIB_DIR}/keybindings.sh"
source "${TUI_LIB_DIR}/checkbox.sh"
source "${TUI_LIB_DIR}/multistate.sh"
source "${TUI_LIB_DIR}/number-input.sh"

# {{{ tui_init
tui_init() {
    # Save terminal state
    tput smcup 2>/dev/null       # Alternative screen buffer
    tput civis 2>/dev/null       # Hide cursor
    stty -echo 2>/dev/null       # Disable echo
    TUI_INITIALIZED=true
    trap tui_cleanup EXIT INT TERM
}
# }}}

# {{{ tui_cleanup
tui_cleanup() {
    if [[ "$TUI_INITIALIZED" == true ]]; then
        tput cnorm 2>/dev/null   # Show cursor
        tput rmcup 2>/dev/null   # Restore screen
        stty echo 2>/dev/null    # Re-enable echo
        TUI_INITIALIZED=false
    fi
}
# }}}

# {{{ tui_clear
tui_clear() {
    clear
}
# }}}

# {{{ tui_get_dimensions
tui_get_dimensions() {
    TUI_ROWS=$(tput lines)
    TUI_COLS=$(tput cols)
}
# }}}
```

**Keybindings module (`keybindings.sh`):**
```bash
#!/bin/bash
# keybindings.sh
# Key reading with arrow key and vim keybinding support

# {{{ tui_read_key
tui_read_key() {
    local key
    IFS= read -rsn1 key

    # Handle escape sequences (arrows)
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.1 key
        case "$key" in
            '[A') echo "UP" ;;
            '[B') echo "DOWN" ;;
            '[C') echo "RIGHT" ;;
            '[D') echo "LEFT" ;;
            *)    echo "ESC" ;;
        esac
    else
        case "$key" in
            'k')     echo "UP" ;;
            'j')     echo "DOWN" ;;
            'h')     echo "LEFT" ;;
            'l')     echo "RIGHT" ;;
            'g')     echo "TOP" ;;
            'G')     echo "BOTTOM" ;;
            'i'|'')  echo "SELECT" ;;   # Enter
            'A')     echo "SELECT" ;;   # Shift+A
            ' ')     echo "TOGGLE" ;;
            'a')     echo "ALL" ;;
            'n')     echo "NONE" ;;
            'r')     echo "RUN" ;;
            'q')     echo "QUIT" ;;
            '?')     echo "HELP" ;;
            [0-9])   echo "INDEX:$key" ;;
            *)       echo "OTHER:$key" ;;
        esac
    fi
}
# }}}

# {{{ tui_wait_key
tui_wait_key() {
    local prompt="${1:-Press any key to continue...}"
    echo "$prompt"
    read -rsn1
}
# }}}
```

**Checkbox module (`checkbox.sh`):**
```bash
#!/bin/bash
# checkbox.sh
# Checkbox component for multi-select interfaces

declare -A TUI_CHECKBOX_STATE
declare -a TUI_CHECKBOX_ITEMS
declare -a TUI_CHECKBOX_LABELS
TUI_CHECKBOX_CURSOR=0

# {{{ checkbox_init
checkbox_init() {
    TUI_CHECKBOX_STATE=()
    TUI_CHECKBOX_ITEMS=()
    TUI_CHECKBOX_LABELS=()
    TUI_CHECKBOX_CURSOR=0
}
# }}}

# {{{ checkbox_add
checkbox_add() {
    local id="$1"
    local label="$2"
    local checked="${3:-0}"

    TUI_CHECKBOX_ITEMS+=("$id")
    TUI_CHECKBOX_LABELS+=("$label")
    TUI_CHECKBOX_STATE[$id]="$checked"
}
# }}}

# {{{ checkbox_render
checkbox_render() {
    local i=0
    for id in "${TUI_CHECKBOX_ITEMS[@]}"; do
        local label="${TUI_CHECKBOX_LABELS[$i]}"
        local checked="${TUI_CHECKBOX_STATE[$id]:-0}"
        local prefix="  "
        local box="[ ]"

        if [[ $i -eq $TUI_CHECKBOX_CURSOR ]]; then
            prefix="▸ "
        fi

        if [[ "$checked" == "1" ]]; then
            box="[●]"
        fi

        echo "${prefix}${box} ${label}"
        ((i++))
    done
}
# }}}

# {{{ checkbox_toggle
checkbox_toggle() {
    local id="${TUI_CHECKBOX_ITEMS[$TUI_CHECKBOX_CURSOR]}"
    if [[ "${TUI_CHECKBOX_STATE[$id]}" == "1" ]]; then
        TUI_CHECKBOX_STATE[$id]=0
    else
        TUI_CHECKBOX_STATE[$id]=1
    fi
}
# }}}

# {{{ checkbox_move
checkbox_move() {
    local direction="$1"
    local count=${#TUI_CHECKBOX_ITEMS[@]}

    case "$direction" in
        up)
            ((TUI_CHECKBOX_CURSOR--))
            [[ $TUI_CHECKBOX_CURSOR -lt 0 ]] && TUI_CHECKBOX_CURSOR=$((count - 1))
            ;;
        down)
            ((TUI_CHECKBOX_CURSOR++))
            [[ $TUI_CHECKBOX_CURSOR -ge $count ]] && TUI_CHECKBOX_CURSOR=0
            ;;
        top)
            TUI_CHECKBOX_CURSOR=0
            ;;
        bottom)
            TUI_CHECKBOX_CURSOR=$((count - 1))
            ;;
    esac
}
# }}}

# {{{ checkbox_select_all
checkbox_select_all() {
    for id in "${TUI_CHECKBOX_ITEMS[@]}"; do
        TUI_CHECKBOX_STATE[$id]=1
    done
}
# }}}

# {{{ checkbox_select_none
checkbox_select_none() {
    for id in "${TUI_CHECKBOX_ITEMS[@]}"; do
        TUI_CHECKBOX_STATE[$id]=0
    done
}
# }}}

# {{{ checkbox_get_selected
checkbox_get_selected() {
    local selected=()
    for id in "${TUI_CHECKBOX_ITEMS[@]}"; do
        if [[ "${TUI_CHECKBOX_STATE[$id]}" == "1" ]]; then
            selected+=("$id")
        fi
    done
    printf '%s\n' "${selected[@]}"
}
# }}}
```

**Multi-state module (`multistate.sh`):**
```bash
#!/bin/bash
# multistate.sh
# Multi-state toggle component (3+ options, cycle with h/l)

declare -A TUI_MULTISTATE_OPTIONS
declare -A TUI_MULTISTATE_STATE

# {{{ multistate_define
multistate_define() {
    local name="$1"
    local options="$2"      # Comma-separated: "text,json,yaml"
    local default="$3"

    TUI_MULTISTATE_OPTIONS[$name]="$options"

    if [[ -n "$default" ]]; then
        TUI_MULTISTATE_STATE[$name]="$default"
    else
        # Use first option as default
        TUI_MULTISTATE_STATE[$name]="${options%%,*}"
    fi
}
# }}}

# {{{ multistate_render
multistate_render() {
    local name="$1"
    local current="${TUI_MULTISTATE_STATE[$name]}"

    echo "◀ [${current^^}] ▶"
}
# }}}

# {{{ multistate_cycle
multistate_cycle() {
    local name="$1"
    local direction="$2"    # "left" or "right"
    local options="${TUI_MULTISTATE_OPTIONS[$name]}"
    local current="${TUI_MULTISTATE_STATE[$name]}"

    IFS=',' read -ra opts <<< "$options"
    local count=${#opts[@]}
    local idx=0

    # Find current index
    for i in "${!opts[@]}"; do
        if [[ "${opts[$i]}" == "$current" ]]; then
            idx=$i
            break
        fi
    done

    # Cycle
    if [[ "$direction" == "right" ]]; then
        idx=$(( (idx + 1) % count ))
    else
        idx=$(( (idx - 1 + count) % count ))
    fi

    TUI_MULTISTATE_STATE[$name]="${opts[$idx]}"
}
# }}}

# {{{ multistate_get
multistate_get() {
    local name="$1"
    echo "${TUI_MULTISTATE_STATE[$name]}"
}
# }}}

# {{{ multistate_is_defined
multistate_is_defined() {
    local name="$1"
    [[ -n "${TUI_MULTISTATE_OPTIONS[$name]}" ]]
}
# }}}
```

**Number input module (`number-input.sh`):**
```bash
#!/bin/bash
# number-input.sh
# Number input component with +/- adjustment

# {{{ number_input
number_input() {
    local label="$1"
    local min="$2"
    local max="$3"
    local current="$4"
    local result="$current"

    while true; do
        tui_clear
        echo "$label: [$result]"
        echo "(${min}-${max}, Enter to confirm, +/- or j/k to adjust)"

        local key=$(tui_read_key)

        case "$key" in
            SELECT)
                break
                ;;
            UP|"+")
                ((result++))
                [[ $result -gt $max ]] && result=$max
                ;;
            DOWN|"-")
                ((result--))
                [[ $result -lt $min ]] && result=$min
                ;;
            INDEX:*)
                local digit="${key#INDEX:}"
                local new_result="${result}${digit}"
                if [[ $new_result -le $max ]]; then
                    result=$new_result
                fi
                ;;
            LEFT)
                # Backspace behavior
                result="${result%?}"
                [[ -z "$result" || $result -lt $min ]] && result=$min
                ;;
            QUIT)
                echo "$current"  # Return original on quit
                return 1
                ;;
        esac
    done

    echo "$result"
    return 0
}
# }}}
```

### 3. Create Symlinks in Projects

```bash
# For world-edit-to-execute project
mkdir -p /mnt/mtwo/programming/ai-stuff/world-edit-to-execute/src/cli/lib
ln -s /home/ritz/programming/ai-stuff/libs/tui \
      /mnt/mtwo/programming/ai-stuff/world-edit-to-execute/src/cli/lib/tui

# For scripts directory (issue-splitter uses it)
ln -s /home/ritz/programming/ai-stuff/libs/tui \
      /home/ritz/programming/ai-stuff/scripts/lib/tui
```

### 4. Update issue-splitter.sh to Use Shared Library

```bash
# At top of issue-splitter.sh
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
TUI_LIB_DIR="${SCRIPT_DIR}/lib/tui"

if [[ -d "$TUI_LIB_DIR" ]]; then
    source "${TUI_LIB_DIR}/tui.sh"
else
    error "TUI library not found at $TUI_LIB_DIR"
fi
```

### 5. Create README.md for Library

```markdown
# TUI Library

Terminal User Interface library for bash scripts with checkbox-style
interactive menus.

## Features

- Checkbox multi-select with vim keybindings
- Multi-state toggles (cycle with h/l)
- Number input with +/- adjustment
- Arrow key and vim navigation (j/k/h/l)
- Index-based jumping (1-9)
- Full-screen mode with clean exit

## Usage

```bash
source /home/ritz/programming/ai-stuff/libs/tui/tui.sh

tui_init

# Add checkboxes
checkbox_init
checkbox_add "opt1" "Option 1" 1    # checked
checkbox_add "opt2" "Option 2" 0    # unchecked

# Define multi-state
multistate_define "format" "text,json,yaml" "text"

# Main loop
while true; do
    tui_clear
    checkbox_render
    echo "Format: $(multistate_render 'format')"

    key=$(tui_read_key)
    case "$key" in
        UP)    checkbox_move up ;;
        DOWN)  checkbox_move down ;;
        TOGGLE) checkbox_toggle ;;
        LEFT)  multistate_cycle "format" left ;;
        RIGHT) multistate_cycle "format" right ;;
        RUN)   break ;;
        QUIT)  tui_cleanup; exit 0 ;;
    esac
done

tui_cleanup

# Get results
selected=$(checkbox_get_selected)
format=$(multistate_get "format")
```

## Components

| File | Description |
|------|-------------|
| tui.sh | Main module, init/cleanup |
| keybindings.sh | Key reading, vim bindings |
| checkbox.sh | Checkbox multi-select |
| multistate.sh | Multi-state toggle |
| number-input.sh | Number input with bounds |
```

---

## Directory Structure After Implementation

```
/home/ritz/programming/ai-stuff/
├── libs/
│   └── tui/
│       ├── tui.sh
│       ├── keybindings.sh
│       ├── checkbox.sh
│       ├── multistate.sh
│       ├── number-input.sh
│       └── README.md
│
├── scripts/
│   ├── issue-splitter.sh
│   └── lib/
│       └── tui -> /home/ritz/programming/ai-stuff/libs/tui
│
/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/
└── src/
    └── cli/
        ├── issue-splitter.sh -> /home/ritz/programming/ai-stuff/scripts/issue-splitter.sh
        └── lib/
            └── tui -> /home/ritz/programming/ai-stuff/libs/tui
```

---

## Related Documents

- issues/004-redesign-interactive-mode-interface.md (source of TUI design)
- /home/ritz/programming/ai-stuff/scripts/issue-splitter.sh
- ~/.claude/CLAUDE.md (interface specifications)

---

## Acceptance Criteria

- [ ] TUI library exists at /home/ritz/programming/ai-stuff/libs/tui/
- [ ] All components are modular and independently sourceable
- [ ] Symlink works from world-edit-to-execute project
- [ ] Symlink works from scripts directory
- [ ] issue-splitter.sh successfully sources the library
- [ ] README.md documents usage and API
- [ ] Library works when sourced from any project
- [ ] No hardcoded paths in library (uses TUI_LIB_DIR)

---

## Notes

This follows the same pattern as issue-splitter.sh migration:
- Shared code lives in `/home/ritz/programming/ai-stuff/`
- Projects symlink to shared location
- Updates to library automatically available to all projects

The modular structure allows projects to source only needed components
if desired, though the main `tui.sh` provides convenient all-in-one sourcing.

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-16 00:21*

I've read the issue file. Let me analyze whether it should be split into sub-issues.

## Analysis

This issue is already quite well-structured and has a clear linear progression. However, it does contain several distinct implementation tasks that could benefit from being tracked separately. The main areas are:

1. Creating the shared library structure with multiple component files
2. Setting up symlinks across projects
3. Updating existing scripts to use the library
4. Documentation

## Suggested Sub-Issues

### 005a-create-shared-tui-directory-structure
**Description:** Create the base directory structure at `/home/ritz/programming/ai-stuff/libs/tui/` and implement the main `tui.sh` module with init/cleanup functions.

**Covers:**
- Creating the libs/tui directory
- Implementing tui.sh (main module with tui_init, tui_cleanup, tui_clear, tui_get_dimensions)
- Implementing keybindings.sh (tui_read_key, tui_wait_key)

**Dependencies:** 004 (the TUI design must exist first)

---

### 005b-implement-checkbox-component
**Description:** Implement the checkbox multi-select component as a standalone module.

**Covers:**
- Creating checkbox.sh with all checkbox_* functions
- State management (TUI_CHECKBOX_STATE, TUI_CHECKBOX_ITEMS, etc.)
- Rendering, toggling, navigation, select all/none

**Dependencies:** 005a (needs keybindings.sh for key handling)

---

### 005c-implement-multistate-and-number-components
**Description:** Implement the multi-state toggle and number input components.

**Covers:**
- Creating multistate.sh with multistate_define, multistate_render, multistate_cycle, multistate_get
- Creating number-input.sh with number_input function
- These are simpler components that can be grouped together

**Dependencies:** 005a (needs keybindings.sh)

---

### 005d-create-symlinks-and-integrate
**Description:** Set up project symlinks and update issue-splitter.sh to use the shared library.

**Covers:**
- Creating symlink at world-edit-to-execute/src/cli/lib/tui
- Creating symlink at scripts/lib/tui
- Updating issue-splitter.sh to source from TUI_LIB_DIR
- Testing that sourcing works from multiple locations

**Dependencies:** 005a, 005b, 005c (all components must exist)

---

### 005e-document-tui-library
**Description:** Create README.md and ensure library is properly documented.

**Covers:**
- Writing README.md with usage examples
- Documenting all components and their APIs
- Adding any inline documentation needed

**Dependencies:** 005b, 005c (need to know final API to document)

---

## Dependency Graph

```
004 (prerequisite - TUI design)
 │
 ▼
005a (core + keybindings)
 │
 ├──────┬──────┐
 ▼      ▼      │
005b   005c    │
 │      │      │
 └──────┴──────┘
        │
        ▼
      005d (integration)
        │
        ▼
      005e (documentation)
```

## Recommendation

**Split this issue.** While the issue is well-written, it encompasses 5 distinct files to create plus integration work. Splitting allows:

1. Parallel work on 005b and 005c after 005a is done
2. Clear checkpoints for testing individual components
3. Easier tracking of which components are complete
4. Documentation can be written incrementally as components finish

The split also aligns with the modular design philosophy stated in the issue itself—each component should be "independently sourceable."
