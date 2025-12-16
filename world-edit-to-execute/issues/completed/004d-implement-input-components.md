# Issue 004d: Implement Number Input and Text Input Components

**Phase:** 0 - Tooling/Infrastructure
**Type:** Sub-Issue of 004
**Priority:** Medium
**Affects:** src/cli/lib/tui.sh
**Dependencies:** 004a (uses key reading)

---

## Current Behavior

No inline input components exist. Values like parallel count or directory paths
must be entered via standard prompts that break the TUI flow.

---

## Intended Behavior

Create input components for:

1. **Number Input** - Bounded numeric input with +/- adjustment
2. **Text Input** - Single-line text entry with basic editing
3. **Path Input** - Path entry with optional tab completion

### Visual Design

**Number Input:**
```
  Parallel Count: [3]     +/- to adjust, 0-9 to type, Enter to confirm
```

**Text Input:**
```
  Project Directory:
  > /mnt/mtwo/programming/ai-stuff/world-edit-to-execute_
    [Enter to confirm, Esc to cancel]
```

---

## Suggested Implementation Steps

### 1. Number Input Component

```bash
# {{{ number_input
# Interactive number input with bounds checking
# Args: label, min, max, default
# Returns: selected number (or -1 on cancel)
number_input() {
    local label="$1"
    local min="${2:-0}"
    local max="${3:-100}"
    local current="${4:-$min}"
    local row="${5:-}"

    # Ensure current is within bounds
    [[ $current -lt $min ]] && current=$min
    [[ $current -gt $max ]] && current=$max

    local buffer="$current"
    local editing=0  # 0 = adjust mode, 1 = typing mode

    while true; do
        # Render
        if [[ -n "$row" ]]; then
            tui_goto "$row" 0
            tui_clear_line
        fi

        if [[ $editing -eq 1 ]]; then
            echo -n "  ${label}: [${TUI_INVERSE}${buffer}_${TUI_RESET}]"
            echo -n "  ${TUI_DIM}(type number, Enter to confirm)${TUI_RESET}"
        else
            echo -n "  ${label}: ${TUI_BOLD}[${buffer}]${TUI_RESET}"
            echo -n "  ${TUI_DIM}(+/- or ↑/↓, 0-9 to edit, Enter to confirm)${TUI_RESET}"
        fi

        local key
        key=$(tui_read_key)

        case "$key" in
            SELECT)
                # Validate and return
                if [[ -z "$buffer" ]] || [[ ! "$buffer" =~ ^[0-9]+$ ]]; then
                    buffer=$current
                fi
                [[ $buffer -lt $min ]] && buffer=$min
                [[ $buffer -gt $max ]] && buffer=$max
                echo "$buffer"
                return 0
                ;;
            QUIT|ESCAPE)
                echo "-1"
                return 1
                ;;
            UP)
                if [[ $editing -eq 0 ]]; then
                    [[ $buffer -lt $max ]] && ((buffer++))
                fi
                ;;
            DOWN)
                if [[ $editing -eq 0 ]]; then
                    [[ $buffer -gt $min ]] && ((buffer--))
                fi
                ;;
            INDEX:*)
                local digit="${key#INDEX:}"
                if [[ $editing -eq 0 ]]; then
                    # First digit clears buffer
                    buffer="$digit"
                    editing=1
                else
                    # Append digit
                    buffer="${buffer}${digit}"
                fi
                # Auto-validate against max
                if [[ ${#buffer} -gt ${#max} ]] || [[ $buffer -gt $max ]]; then
                    buffer=$max
                fi
                ;;
            BACKSPACE)
                if [[ ${#buffer} -gt 0 ]]; then
                    buffer="${buffer%?}"
                fi
                if [[ -z "$buffer" ]]; then
                    buffer="0"
                    editing=0
                fi
                ;;
            CHAR:+)
                [[ $buffer -lt $max ]] && ((buffer++))
                editing=0
                ;;
            CHAR:-)
                [[ $buffer -gt $min ]] && ((buffer--))
                editing=0
                ;;
        esac
    done
}
# }}}
```

### 2. Text Input Component

```bash
# {{{ text_input
# Single-line text input with basic editing
# Args: label, default, max_length
# Returns: entered text (or empty on cancel)
text_input() {
    local label="$1"
    local default="${2:-}"
    local max_length="${3:-256}"
    local row="${4:-}"

    local buffer="$default"
    local cursor=${#buffer}

    while true; do
        # Render
        if [[ -n "$row" ]]; then
            tui_goto "$row" 0
            tui_clear_line
        fi

        echo -n "  ${label}:"
        echo
        echo -n "  > "

        # Display buffer with cursor
        if [[ $cursor -eq ${#buffer} ]]; then
            echo -n "${buffer}${TUI_INVERSE} ${TUI_RESET}"
        else
            echo -n "${buffer:0:$cursor}"
            echo -n "${TUI_INVERSE}${buffer:$cursor:1}${TUI_RESET}"
            echo -n "${buffer:$((cursor+1))}"
        fi

        tui_clear_line
        echo
        echo -n "    ${TUI_DIM}[Enter to confirm, Esc to cancel]${TUI_RESET}"

        local key
        key=$(tui_read_key)

        case "$key" in
            SELECT)
                echo "$buffer"
                return 0
                ;;
            QUIT|ESCAPE)
                echo ""
                return 1
                ;;
            LEFT)
                [[ $cursor -gt 0 ]] && ((cursor--))
                ;;
            RIGHT)
                [[ $cursor -lt ${#buffer} ]] && ((cursor++))
                ;;
            HOME|TOP)
                cursor=0
                ;;
            END|BOTTOM)
                cursor=${#buffer}
                ;;
            BACKSPACE)
                if [[ $cursor -gt 0 ]]; then
                    buffer="${buffer:0:$((cursor-1))}${buffer:$cursor}"
                    ((cursor--))
                fi
                ;;
            CHAR:*)
                local char="${key#CHAR:}"
                if [[ ${#buffer} -lt $max_length ]] && [[ -n "$char" ]]; then
                    buffer="${buffer:0:$cursor}${char}${buffer:$cursor}"
                    ((cursor++))
                fi
                ;;
        esac
    done
}
# }}}
```

### 3. Path Input Component

```bash
# {{{ path_input
# Path input with optional directory validation
# Args: label, default, must_exist
# Returns: entered path (or empty on cancel)
path_input() {
    local label="$1"
    local default="${2:-$(pwd)}"
    local must_exist="${3:-0}"
    local row="${4:-}"

    local buffer="$default"
    local cursor=${#buffer}
    local error_msg=""

    while true; do
        # Render
        if [[ -n "$row" ]]; then
            tui_goto "$row" 0
        fi
        tui_clear_line

        echo -n "  ${label}:"
        echo
        echo -n "  > "

        # Display buffer with cursor
        if [[ $cursor -eq ${#buffer} ]]; then
            echo -n "${buffer}${TUI_INVERSE} ${TUI_RESET}"
        else
            echo -n "${buffer:0:$cursor}"
            echo -n "${TUI_INVERSE}${buffer:$cursor:1}${TUI_RESET}"
            echo -n "${buffer:$((cursor+1))}"
        fi

        tui_clear_line
        echo

        # Show error or hints
        if [[ -n "$error_msg" ]]; then
            echo "    ${TUI_RED}${error_msg}${TUI_RESET}"
        else
            echo -n "    ${TUI_DIM}[Enter to confirm, Tab to complete, Esc to cancel]${TUI_RESET}"
        fi

        local key
        key=$(tui_read_key)
        error_msg=""

        case "$key" in
            SELECT)
                # Validate if required
                if [[ "$must_exist" == "1" ]] && [[ ! -d "$buffer" ]]; then
                    error_msg="Directory does not exist"
                    continue
                fi
                echo "$buffer"
                return 0
                ;;
            QUIT|ESCAPE)
                echo ""
                return 1
                ;;
            LEFT)
                [[ $cursor -gt 0 ]] && ((cursor--))
                ;;
            RIGHT)
                [[ $cursor -lt ${#buffer} ]] && ((cursor++))
                ;;
            BACKSPACE)
                if [[ $cursor -gt 0 ]]; then
                    buffer="${buffer:0:$((cursor-1))}${buffer:$cursor}"
                    ((cursor--))
                fi
                ;;
            CHAR:$'\t')
                # Tab completion
                local completed
                completed=$(path_complete "$buffer")
                if [[ -n "$completed" ]] && [[ "$completed" != "$buffer" ]]; then
                    buffer="$completed"
                    cursor=${#buffer}
                fi
                ;;
            CHAR:*)
                local char="${key#CHAR:}"
                if [[ -n "$char" ]]; then
                    buffer="${buffer:0:$cursor}${char}${buffer:$cursor}"
                    ((cursor++))
                fi
                ;;
        esac
    done
}
# }}}

# {{{ path_complete
# Basic path completion using bash completion
path_complete() {
    local partial="$1"

    # Expand ~ to home directory
    local expanded="${partial/#\~/$HOME}"

    # Use compgen for completion
    local completions
    completions=$(compgen -d -- "$expanded" 2>/dev/null | head -1)

    if [[ -n "$completions" ]]; then
        # If it's a directory, add trailing slash
        if [[ -d "$completions" ]]; then
            completions="${completions%/}/"
        fi

        # Convert back to ~ if applicable
        if [[ "$completions" == "$HOME"* ]]; then
            completions="~${completions#$HOME}"
        fi

        echo "$completions"
    else
        echo "$partial"
    fi
}
# }}}
```

### 4. Helper Functions

```bash
# {{{ input_confirm
# Simple yes/no confirmation
# Args: prompt, default (y/n)
# Returns: 0 for yes, 1 for no
input_confirm() {
    local prompt="$1"
    local default="${2:-n}"

    local hint
    if [[ "$default" == "y" ]]; then
        hint="[Y/n]"
    else
        hint="[y/N]"
    fi

    echo -n "  ${prompt} ${hint} "

    local key
    key=$(tui_read_key)

    case "$key" in
        CHAR:y|CHAR:Y) return 0 ;;
        CHAR:n|CHAR:N) return 1 ;;
        SELECT)
            [[ "$default" == "y" ]] && return 0 || return 1
            ;;
        *)
            [[ "$default" == "y" ]] && return 0 || return 1
            ;;
    esac
}
# }}}
```

---

## Testing

```bash
#!/usr/bin/env bash
source libs/tui.sh

tui_init
tui_clear

echo "Input Component Tests"
echo "====================="
echo

# Test number input
echo "1. Number Input Test"
count=$(number_input "Parallel Count" 1 10 3)
echo "  Selected: $count"
echo

# Test text input
echo "2. Text Input Test"
name=$(text_input "Project Name" "my-project")
echo "  Entered: $name"
echo

# Test path input
echo "3. Path Input Test"
dir=$(path_input "Project Directory" "$(pwd)" 1)
echo "  Selected: $dir"
echo

# Test confirmation
echo "4. Confirmation Test"
if input_confirm "Continue with these settings?" "y"; then
    echo "  Confirmed!"
else
    echo "  Cancelled"
fi

tui_cleanup
```

---

## Related Documents

- issues/004-redesign-interactive-mode-interface.md (parent)
- issues/004a-create-tui-core-library.md (dependency)

---

## Acceptance Criteria

### Number Input
- [ ] Displays current value in brackets: `[3]`
- [ ] +/- keys increment/decrement
- [ ] ↑/↓ keys increment/decrement
- [ ] Typing digits enters number directly
- [ ] Backspace removes last digit
- [ ] Enter confirms value
- [ ] Esc cancels input
- [ ] Respects min/max bounds

### Text Input
- [ ] Displays cursor position visually
- [ ] ←/→ keys move cursor
- [ ] Home/End jump to start/end
- [ ] Backspace removes character before cursor
- [ ] Enter confirms input
- [ ] Esc cancels input
- [ ] Handles arbitrary text

### Path Input
- [ ] All text input features work
- [ ] Tab triggers path completion
- [ ] Validates directory exists when required
- [ ] Shows error message for invalid paths
- [ ] Expands ~ to home directory

---

## Notes

The path completion is basic - consider using a file picker dialog for
complex path selection in future iterations. For now, tab completion
of the current partial path is sufficient.

---

## Implementation Complete

*Implemented on 2025-12-16*

### Changes Made

Created `/home/ritz/programming/ai-stuff/scripts/libs/input.sh` with:

1. **Number Input:**
   - `input_number()` - Interactive bounded number input
   - `input_number_inline()` - Inline render for menus
   - +/- and ↑/↓ increment/decrement
   - Direct digit typing with auto-edit mode
   - Min/max validation

2. **Text Input:**
   - `input_text()` - Single-line text input
   - Cursor movement (←/→, Home/End)
   - Insert/delete at cursor
   - Max length enforcement

3. **Path Input:**
   - `input_path()` - Path input with validation
   - `input_path_complete()` - Tab completion
   - Directory/file validation modes
   - ~ expansion support
   - Error messages for invalid paths

4. **Confirmation & Choice:**
   - `input_confirm()` - Yes/no with default
   - `input_choice()` - Select from list

5. **Specialized:**
   - `input_password()` - Masked password input

### Test Script

Created `libs/test-input.sh` for interactive testing of all components.

### Acceptance Criteria Status

#### Number Input
- [x] Displays current value in brackets: `[3]`
- [x] +/- keys increment/decrement
- [x] ↑/↓ keys increment/decrement
- [x] Typing digits enters number directly
- [x] Backspace removes last digit
- [x] Enter confirms value
- [x] Esc cancels input
- [x] Respects min/max bounds

#### Text Input
- [x] Displays cursor position visually
- [x] ←/→ keys move cursor
- [x] Home/End jump to start/end
- [x] Backspace removes character before cursor
- [x] Enter confirms input
- [x] Esc cancels input
- [x] Handles arbitrary text

#### Path Input
- [x] All text input features work
- [x] Tab triggers path completion
- [x] Validates directory exists when required
- [x] Shows error message for invalid paths
- [x] Expands ~ to home directory
