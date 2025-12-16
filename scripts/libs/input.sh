#!/usr/bin/env bash
# Input Components - Number and text input for TUI
# Provides inline input fields for numbers, text, and paths.
#
# Usage: source this file after tui.sh, then use input_* functions.

# Prevent double-sourcing
[[ -n "${_INPUT_LOADED:-}" ]] && return 0
_INPUT_LOADED=1

# Library directory
INPUT_LIB_DIR="${INPUT_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Ensure TUI library is loaded
if [[ -z "${_TUI_LOADED:-}" ]]; then
    source "${INPUT_LIB_DIR}/tui.sh"
fi

# ============================================================================
# Number Input
# ============================================================================

# {{{ input_number
# Interactive number input with bounds checking
# Args: label min max [default] [row]
# Returns: selected number via stdout, -1 on cancel
# Exit code: 0 if confirmed, 1 if cancelled
input_number() {
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
            echo -n "  ${label}: [${TUI_INVERSE}${buffer}${TUI_RESET}${TUI_INVERSE}_${TUI_RESET}]"
            echo -n "  ${TUI_DIM}(type number, Enter to confirm)${TUI_RESET}"
        else
            echo -n "  ${label}: ${TUI_BOLD}[${buffer}]${TUI_RESET}"
            echo -n "  ${TUI_DIM}(+/- or ↑/↓, 0-9 to edit, Enter confirm)${TUI_RESET}"
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
                    local new_buffer="${buffer}${digit}"
                    # Only append if within bounds
                    if [[ $new_buffer -le $max ]]; then
                        buffer="$new_buffer"
                    fi
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

# {{{ input_number_inline
# Render a number input inline (for integration with menus)
# Args: label value [min] [max] [highlight]
input_number_inline() {
    local label="$1"
    local value="$2"
    local min="${3:-0}"
    local max="${4:-100}"
    local highlight="${5:-0}"

    if [[ "$highlight" == "1" ]]; then
        echo -n "${TUI_BOLD}▸ ${label}: ${TUI_RESET}"
        echo -n "${TUI_INVERSE}[${value}]${TUI_RESET}"
        echo -n " ${TUI_DIM}(${min}-${max})${TUI_RESET}"
    else
        echo -n "  ${label}: [${value}]"
        echo -n " ${TUI_DIM}(${min}-${max})${TUI_RESET}"
    fi
}
# }}}

# ============================================================================
# Text Input
# ============================================================================

# {{{ input_text
# Single-line text input with basic editing
# Args: label [default] [max_length] [row]
# Returns: entered text via stdout, empty on cancel
# Exit code: 0 if confirmed, 1 if cancelled
input_text() {
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
            tui_goto "$((row + 1))" 0
            tui_clear_line
            tui_goto "$((row + 2))" 0
            tui_clear_line
            tui_goto "$row" 0
        fi

        echo "  ${label}:"
        echo -n "  > "

        # Display buffer with cursor
        if [[ $cursor -ge ${#buffer} ]]; then
            echo -n "${buffer}${TUI_INVERSE} ${TUI_RESET}"
        else
            echo -n "${buffer:0:$cursor}"
            echo -n "${TUI_INVERSE}${buffer:$cursor:1}${TUI_RESET}"
            echo -n "${buffer:$((cursor+1))}"
        fi

        tui_clear_line
        echo
        echo -n "    ${TUI_DIM}[Enter confirm, Esc cancel, ←/→ move]${TUI_RESET}"

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
            DELETE)
                if [[ $cursor -lt ${#buffer} ]]; then
                    buffer="${buffer:0:$cursor}${buffer:$((cursor+1))}"
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

# ============================================================================
# Path Input
# ============================================================================

# {{{ input_path
# Path input with optional validation and tab completion
# Args: label [default] [must_exist] [row]
# must_exist: 0 = no validation, 1 = directory must exist, 2 = file must exist
# Returns: path via stdout, empty on cancel
# Exit code: 0 if confirmed, 1 if cancelled
input_path() {
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
            for ((i = 0; i < 5; i++)); do
                tui_clear_line
                echo
            done
            tui_goto "$row" 0
        fi

        echo "  ${label}:"
        echo -n "  > "

        # Display buffer with cursor
        if [[ $cursor -ge ${#buffer} ]]; then
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
            tui_clear_line
        else
            echo -n "    ${TUI_DIM}[Enter confirm, Esc cancel, Tab complete]${TUI_RESET}"
            tui_clear_line
        fi

        local key
        key=$(tui_read_key)
        error_msg=""

        case "$key" in
            SELECT)
                # Expand ~ to home directory for validation
                local expanded="${buffer/#\~/$HOME}"

                # Validate if required
                case "$must_exist" in
                    1)
                        if [[ ! -d "$expanded" ]]; then
                            error_msg="Directory does not exist"
                            continue
                        fi
                        ;;
                    2)
                        if [[ ! -f "$expanded" ]]; then
                            error_msg="File does not exist"
                            continue
                        fi
                        ;;
                esac

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
            DELETE)
                if [[ $cursor -lt ${#buffer} ]]; then
                    buffer="${buffer:0:$cursor}${buffer:$((cursor+1))}"
                fi
                ;;
            TAB)
                # Tab completion
                local completed
                completed=$(input_path_complete "$buffer")
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

# {{{ input_path_complete
# Basic path completion
# Args: partial_path
# Returns: completed path or original if no completion
input_path_complete() {
    local partial="$1"

    # Expand ~ to home directory
    local expanded="${partial/#\~/$HOME}"

    # Try directory completion first
    local completions
    completions=$(compgen -d -- "$expanded" 2>/dev/null | head -1)

    # If no directory completion, try file completion
    if [[ -z "$completions" ]]; then
        completions=$(compgen -f -- "$expanded" 2>/dev/null | head -1)
    fi

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

# ============================================================================
# Confirmation
# ============================================================================

# {{{ input_confirm
# Simple yes/no confirmation
# Args: prompt [default]
# default: "y" or "n" (default: "n")
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

    while true; do
        local key
        key=$(tui_read_key)

        case "$key" in
            CHAR:y|CHAR:Y)
                echo "y"
                return 0
                ;;
            CHAR:n|CHAR:N)
                echo "n"
                return 1
                ;;
            SELECT)
                if [[ "$default" == "y" ]]; then
                    echo "y"
                    return 0
                else
                    echo "n"
                    return 1
                fi
                ;;
            QUIT|ESCAPE)
                echo "n"
                return 1
                ;;
        esac
    done
}
# }}}

# {{{ input_choice
# Choice selection from a list
# Args: prompt option1 option2 [option3...]
# Returns: selected option via stdout (1-indexed), 0 on cancel
# Exit code: 0 if selected, 1 if cancelled
input_choice() {
    local prompt="$1"
    shift
    local -a options=("$@")
    local count=${#options[@]}
    local selected=0

    echo "  ${prompt}"

    for ((i = 0; i < count; i++)); do
        echo "    $((i+1)). ${options[$i]}"
    done

    echo -n "  Choice [1-${count}]: "

    while true; do
        local key
        key=$(tui_read_key)

        case "$key" in
            INDEX:*)
                local idx="${key#INDEX:}"
                if [[ $idx -ge 1 ]] && [[ $idx -le $count ]]; then
                    echo "$idx"
                    return 0
                fi
                ;;
            UP)
                [[ $selected -gt 0 ]] && ((selected--))
                ;;
            DOWN)
                [[ $selected -lt $((count - 1)) ]] && ((selected++))
                ;;
            SELECT)
                echo "$((selected + 1))"
                return 0
                ;;
            QUIT|ESCAPE)
                echo "0"
                return 1
                ;;
        esac
    done
}
# }}}

# ============================================================================
# Specialized Inputs
# ============================================================================

# {{{ input_password
# Password input (masked)
# Args: label [row]
# Returns: password via stdout, empty on cancel
input_password() {
    local label="$1"
    local row="${2:-}"

    local buffer=""

    while true; do
        if [[ -n "$row" ]]; then
            tui_goto "$row" 0
            tui_clear_line
            tui_goto "$((row + 1))" 0
            tui_clear_line
            tui_goto "$row" 0
        fi

        echo "  ${label}:"
        local masked
        masked=$(printf '%*s' "${#buffer}" '' | tr ' ' '*')
        echo -n "  > ${masked}${TUI_INVERSE} ${TUI_RESET}"
        tui_clear_line

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
            BACKSPACE)
                if [[ ${#buffer} -gt 0 ]]; then
                    buffer="${buffer%?}"
                fi
                ;;
            CHAR:*)
                local char="${key#CHAR:}"
                if [[ -n "$char" ]]; then
                    buffer="${buffer}${char}"
                fi
                ;;
        esac
    done
}
# }}}
