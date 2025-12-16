#!/usr/bin/env bash
# Multi-State Toggle Component - Cycle through multiple option values
# Provides toggles that cycle through 3+ states with h/l (left/right) keys.
#
# Usage: source this file after tui.sh, then use multistate_* functions.
# Example: ◀ [JSON] ▶ where h/l cycles through text, json, yaml

# Prevent double-sourcing
[[ -n "${_MULTISTATE_LOADED:-}" ]] && return 0
_MULTISTATE_LOADED=1

# Library directory
MULTISTATE_LIB_DIR="${MULTISTATE_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Ensure TUI library is loaded
if [[ -z "${_TUI_LOADED:-}" ]]; then
    source "${MULTISTATE_LIB_DIR}/tui.sh"
fi

# ============================================================================
# Multi-State Configuration
# ============================================================================

# Option definitions: name -> "state1,state2,state3,..."
declare -A MULTISTATE_OPTIONS

# Current values: name -> current_state
declare -A MULTISTATE_VALUES

# Display labels: name -> "Display Label"
declare -A MULTISTATE_LABELS

# Descriptions for states: name:state -> "description"
declare -A MULTISTATE_STATE_DESCRIPTIONS

# ============================================================================
# Initialization
# ============================================================================

# {{{ multistate_init
# Initialize/reset all multistate options
multistate_init() {
    MULTISTATE_OPTIONS=()
    MULTISTATE_VALUES=()
    MULTISTATE_LABELS=()
    MULTISTATE_STATE_DESCRIPTIONS=()
}
# }}}

# {{{ multistate_add
# Add a multi-state option
# Args: name options [default] [label]
# options: comma-separated list of states (e.g., "text,json,yaml")
multistate_add() {
    local name="$1"
    local options="$2"
    local default="${3:-}"
    local label="${4:-$name}"

    MULTISTATE_OPTIONS[$name]="$options"
    MULTISTATE_LABELS[$name]="$label"

    # Set default value
    if [[ -n "$default" ]]; then
        MULTISTATE_VALUES[$name]="$default"
    else
        # Default to first option
        MULTISTATE_VALUES[$name]="${options%%,*}"
    fi
}
# }}}

# {{{ multistate_add_description
# Add description for a specific state
# Args: name state description
multistate_add_description() {
    local name="$1"
    local state="$2"
    local desc="$3"
    MULTISTATE_STATE_DESCRIPTIONS["${name}:${state}"]="$desc"
}
# }}}

# ============================================================================
# Value Access
# ============================================================================

# {{{ multistate_get
# Get current value of an option
multistate_get() {
    local name="$1"
    echo "${MULTISTATE_VALUES[$name]:-}"
}
# }}}

# {{{ multistate_set
# Set value of an option (validates against allowed states)
# Returns: 0 if successful, 1 if invalid value
multistate_set() {
    local name="$1"
    local value="$2"

    local options="${MULTISTATE_OPTIONS[$name]:-}"
    if [[ -z "$options" ]]; then
        return 1  # Option doesn't exist
    fi

    # Check if value is valid
    if [[ ",$options," == *",$value,"* ]]; then
        MULTISTATE_VALUES[$name]="$value"
        return 0
    fi

    return 1  # Invalid value
}
# }}}

# {{{ multistate_get_options
# Get array of available options for a name
multistate_get_options() {
    local name="$1"
    local options="${MULTISTATE_OPTIONS[$name]:-}"

    IFS=',' read -ra opts <<< "$options"
    printf '%s\n' "${opts[@]}"
}
# }}}

# {{{ multistate_get_index
# Get 0-based index of current value
multistate_get_index() {
    local name="$1"
    local current="${MULTISTATE_VALUES[$name]:-}"
    local options="${MULTISTATE_OPTIONS[$name]:-}"

    IFS=',' read -ra opts <<< "$options"
    for ((i = 0; i < ${#opts[@]}; i++)); do
        if [[ "${opts[$i]}" == "$current" ]]; then
            echo "$i"
            return
        fi
    done
    echo "0"
}
# }}}

# {{{ multistate_get_count
# Get number of states for an option
multistate_get_count() {
    local name="$1"
    local options="${MULTISTATE_OPTIONS[$name]:-}"

    IFS=',' read -ra opts <<< "$options"
    echo "${#opts[@]}"
}
# }}}

# ============================================================================
# Cycling
# ============================================================================

# {{{ multistate_cycle
# Cycle to next/previous state
# Args: name direction
# direction: "right" or "1" for forward, "left" or "-1" for backward
multistate_cycle() {
    local name="$1"
    local direction="$2"

    local options="${MULTISTATE_OPTIONS[$name]:-}"
    local current="${MULTISTATE_VALUES[$name]:-}"

    if [[ -z "$options" ]]; then
        return 1
    fi

    # Split options into array
    IFS=',' read -ra opts <<< "$options"
    local count=${#opts[@]}

    # Find current index
    local idx=0
    for ((i = 0; i < count; i++)); do
        if [[ "${opts[$i]}" == "$current" ]]; then
            idx=$i
            break
        fi
    done

    # Calculate new index with wraparound
    if [[ "$direction" == "right" ]] || [[ "$direction" == "1" ]]; then
        idx=$(( (idx + 1) % count ))
    else
        idx=$(( (idx - 1 + count) % count ))
    fi

    MULTISTATE_VALUES[$name]="${opts[$idx]}"
}
# }}}

# {{{ multistate_cycle_left
# Convenience function to cycle left
multistate_cycle_left() {
    multistate_cycle "$1" "left"
}
# }}}

# {{{ multistate_cycle_right
# Convenience function to cycle right
multistate_cycle_right() {
    multistate_cycle "$1" "right"
}
# }}}

# {{{ multistate_set_first
# Set to first state
multistate_set_first() {
    local name="$1"
    local options="${MULTISTATE_OPTIONS[$name]:-}"
    MULTISTATE_VALUES[$name]="${options%%,*}"
}
# }}}

# {{{ multistate_set_last
# Set to last state
multistate_set_last() {
    local name="$1"
    local options="${MULTISTATE_OPTIONS[$name]:-}"
    MULTISTATE_VALUES[$name]="${options##*,}"
}
# }}}

# ============================================================================
# Type Checking
# ============================================================================

# {{{ multistate_exists
# Check if an option exists
multistate_exists() {
    local name="$1"
    [[ -n "${MULTISTATE_OPTIONS[$name]:-}" ]]
}
# }}}

# {{{ multistate_is_multistate
# Check if a name is a multistate option (for integration with other components)
multistate_is_multistate() {
    multistate_exists "$1"
}
# }}}

# ============================================================================
# Rendering
# ============================================================================

# {{{ multistate_render
# Render a multistate toggle
# Args: name [label_width] [highlight]
# Returns: rendered string (no newline)
multistate_render() {
    local name="$1"
    local label_width="${2:-20}"
    local highlight="${3:-0}"

    local label="${MULTISTATE_LABELS[$name]:-$name}"
    local current="${MULTISTATE_VALUES[$name]:-}"
    local current_upper="${current^^}"

    # Pad label to width
    local padded_label
    printf -v padded_label "%-${label_width}s" "$label"

    # Build display
    if [[ "$highlight" == "1" ]]; then
        echo -n "${TUI_BOLD}▸ ${padded_label}${TUI_RESET}"
        echo -n " ${TUI_CYAN}◀${TUI_RESET}"
        echo -n " ${TUI_INVERSE}[${current_upper}]${TUI_RESET}"
        echo -n " ${TUI_CYAN}▶${TUI_RESET}"
    else
        echo -n "  ${padded_label}"
        echo -n " ${TUI_DIM}◀${TUI_RESET}"
        echo -n " [${current_upper}]"
        echo -n " ${TUI_DIM}▶${TUI_RESET}"
    fi
}
# }}}

# {{{ multistate_render_inline
# Render a compact inline version (just the value with arrows)
multistate_render_inline() {
    local name="$1"
    local current="${MULTISTATE_VALUES[$name]:-}"
    echo -n "◀${current^^}▶"
}
# }}}

# {{{ multistate_render_value
# Render just the value (for embedding in other displays)
multistate_render_value() {
    local name="$1"
    local current="${MULTISTATE_VALUES[$name]:-}"
    echo -n "[${current^^}]"
}
# }}}

# {{{ multistate_render_with_description
# Render with state description
# Args: name [label_width] [highlight]
multistate_render_with_description() {
    local name="$1"
    local label_width="${2:-20}"
    local highlight="${3:-0}"

    multistate_render "$name" "$label_width" "$highlight"

    # Add description if exists
    local current="${MULTISTATE_VALUES[$name]:-}"
    local desc="${MULTISTATE_STATE_DESCRIPTIONS["${name}:${current}"]:-}"

    if [[ -n "$desc" ]]; then
        echo -n "  ${TUI_DIM}${desc}${TUI_RESET}"
    fi
}
# }}}

# {{{ multistate_render_all_states
# Render showing all possible states with current highlighted
# Args: name [separator]
multistate_render_all_states() {
    local name="$1"
    local sep="${2:- | }"

    local options="${MULTISTATE_OPTIONS[$name]:-}"
    local current="${MULTISTATE_VALUES[$name]:-}"

    IFS=',' read -ra opts <<< "$options"

    local first=1
    for opt in "${opts[@]}"; do
        if [[ $first -eq 0 ]]; then
            echo -n "${TUI_DIM}${sep}${TUI_RESET}"
        fi
        first=0

        if [[ "$opt" == "$current" ]]; then
            echo -n "${TUI_INVERSE}${opt^^}${TUI_RESET}"
        else
            echo -n "${TUI_DIM}${opt}${TUI_RESET}"
        fi
    done
}
# }}}

# ============================================================================
# Key Handling
# ============================================================================

# {{{ multistate_handle_key
# Handle a key event for a multistate option
# Args: name key
# Returns: 0 if handled, 1 if not
multistate_handle_key() {
    local name="$1"
    local key="$2"

    if ! multistate_exists "$name"; then
        return 1
    fi

    case "$key" in
        LEFT)
            multistate_cycle_left "$name"
            return 0
            ;;
        RIGHT)
            multistate_cycle_right "$name"
            return 0
            ;;
        HOME|TOP)
            multistate_set_first "$name"
            return 0
            ;;
        END|BOTTOM)
            multistate_set_last "$name"
            return 0
            ;;
    esac

    return 1
}
# }}}

# ============================================================================
# Presets
# ============================================================================

# {{{ multistate_add_preset
# Add common preset configurations
# Available presets: output_format, verbosity, compression, boolean
multistate_add_preset() {
    local preset="$1"
    local name="${2:-$preset}"

    case "$preset" in
        output_format)
            multistate_add "$name" "text,json,yaml" "text" "Output Format"
            multistate_add_description "$name" "text" "Plain text output"
            multistate_add_description "$name" "json" "JSON formatted output"
            multistate_add_description "$name" "yaml" "YAML formatted output"
            ;;
        verbosity)
            multistate_add "$name" "quiet,normal,verbose,debug" "normal" "Verbosity"
            multistate_add_description "$name" "quiet" "Minimal output"
            multistate_add_description "$name" "normal" "Standard output"
            multistate_add_description "$name" "verbose" "Detailed output"
            multistate_add_description "$name" "debug" "Debug-level output"
            ;;
        compression)
            multistate_add "$name" "none,fast,balanced,max" "balanced" "Compression"
            multistate_add_description "$name" "none" "No compression"
            multistate_add_description "$name" "fast" "Fast, lower ratio"
            multistate_add_description "$name" "balanced" "Balanced speed/ratio"
            multistate_add_description "$name" "max" "Maximum compression"
            ;;
        boolean|yesno)
            multistate_add "$name" "no,yes" "no" "$name"
            ;;
        onoff)
            multistate_add "$name" "off,on" "off" "$name"
            ;;
    esac
}
# }}}
