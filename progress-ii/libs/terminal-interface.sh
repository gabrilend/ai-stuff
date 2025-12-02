#!/bin/bash

# Terminal Interface Library for Progress-II
# Provides reusable UI components and display functions
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# {{{ clear_screen
clear_screen() {
    clear
    echo
}
# }}}

# {{{ display_header
display_header() {
    echo "============================================================================="
    echo "                              PROGRESS-II"
    echo "        Terminal Adventure Game with AI Commands & Time Manipulation"
    echo "============================================================================="
    echo
}
# }}}

# {{{ display_separator
display_separator() {
    local char="${1:-=}"
    local length="${2:-77}"
    
    printf "%*s\n" "$length" | tr ' ' "$char"
}
# }}}

# {{{ display_menu
display_menu() {
    local title="$1"
    shift
    local options=("$@")
    
    echo "$title:"
    display_separator "=" ${#title}
    echo
    
    local i=1
    for option in "${options[@]}"; do
        echo "$i) $option"
        ((i++))
    done
    echo
}
# }}}

# {{{ get_user_input
get_user_input() {
    local prompt="${1:-Please select an option: }"
    local input_var="${2:-user_input}"
    
    echo -n "$prompt"
    read -r "$input_var"
}
# }}}

# {{{ display_info_box
display_info_box() {
    local title="$1"
    shift
    local lines=("$@")
    
    echo "$title:"
    display_separator "=" ${#title}
    echo
    
    for line in "${lines[@]}"; do
        echo "$line"
    done
    echo
}
# }}}

# {{{ wait_for_user
wait_for_user() {
    local message="${1:-Press Enter to continue...}"
    
    echo
    echo -n "$message"
    read -r
}
# }}}

# {{{ display_status
display_status() {
    local status_type="$1"  # OK, FAIL, INFO, WARN
    local message="$2"
    
    case "$status_type" in
        "OK"|"SUCCESS")
            echo "[OK] $message"
            ;;
        "FAIL"|"ERROR")
            echo "[FAIL] $message"
            ;;
        "INFO")
            echo "[INFO] $message"
            ;;
        "WARN"|"WARNING")
            echo "[WARN] $message"
            ;;
        *)
            echo "[$status_type] $message"
            ;;
    esac
}
# }}}

# {{{ display_character_status
display_character_status() {
    local player_name="$1"
    local level="${2:-1}"
    local experience="${3:-0}"
    local max_exp="${4:-5}"
    local location="${5:-Unknown}"
    
    display_info_box "Character Status" \
        "Name: $player_name" \
        "Level: $level" \
        "Experience: $experience/$max_exp" \
        "Location: $location"
}
# }}}

# {{{ display_game_features
display_game_features() {
    display_info_box "Progress-II Features" \
        "🤖 AI-Generated Commands:" \
        "   Dynamic bash one-liners for problem solving" \
        "" \
        "⏰ Git-Based Time Travel:" \
        "   Rewind time and explore different paths" \
        "" \
        "📁 Filesystem Integration:" \
        "   Your world exists as real files and directories" \
        "" \
        "🎭 Character Progression:" \
        "   Level up Maxine and her companions" \
        "" \
        "🌍 Dynamic World:" \
        "   Environmental variables create ever-changing experiences"
}
# }}}

# {{{ handle_invalid_input
handle_invalid_input() {
    local invalid_input="$1"
    local valid_options="$2"
    
    echo
    display_status "FAIL" "Invalid option: '$invalid_input'"
    echo "Valid options: $valid_options"
    wait_for_user
}
# }}}

# {{{ confirm_action
confirm_action() {
    local prompt="$1"
    local default="${2:-n}"
    
    echo -n "$prompt [y/N]: "
    read -r response
    
    case "$response" in
        [Yy]|[Yy][Ee][Ss])
            return 0
            ;;
        [Nn]|[Nn][Oo]|"")
            return 1
            ;;
        *)
            echo "Please answer yes or no."
            confirm_action "$prompt" "$default"
            ;;
    esac
}
# }}}

# Export functions for use by other scripts
export -f clear_screen
export -f display_header
export -f display_separator
export -f display_menu
export -f get_user_input
export -f display_info_box
export -f wait_for_user
export -f display_status
export -f display_character_status
export -f display_game_features
export -f handle_invalid_input
export -f confirm_action