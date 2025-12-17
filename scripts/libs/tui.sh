#!/usr/bin/env bash
# TUI Library - Terminal User Interface utilities for bash scripts
# Provides terminal state management, key reading, and formatting helpers
# for building interactive checkbox-style menus with vim keybindings.
#
# Usage: source this file in your script, then use the tui_* functions.
# Call tui_init() before using the TUI, and tui_cleanup() when done.

# Prevent double-sourcing
[[ -n "${_TUI_LOADED:-}" ]] && return 0
_TUI_LOADED=1

# Library directory (for sourcing related libraries)
TUI_LIB_DIR="${TUI_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# ============================================================================
# Terminal State Management
# ============================================================================

# {{{ tui_init
# Initialize TUI mode - switches to alternate screen, hides cursor, etc.
# Returns 1 if terminal is not suitable for TUI
tui_init() {
    # Check if we're in a terminal
    if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
        return 1
    fi

    # Check for dumb terminal
    if [[ "${TERM:-dumb}" == "dumb" ]]; then
        return 1
    fi

    # Save terminal settings
    TUI_STTY_SAVED=$(stty -g 2>/dev/null) || true

    # Switch to alternate screen buffer
    tput smcup 2>/dev/null || true

    # Hide cursor
    tput civis 2>/dev/null || true

    # Disable echo and canonical mode (line buffering)
    stty -echo -icanon min 1 time 0 2>/dev/null || true

    # Set up cleanup on exit
    trap 'tui_cleanup' EXIT
    trap 'tui_cleanup; exit 130' INT
    trap 'tui_cleanup; exit 143' TERM

    # Get initial dimensions
    tui_update_dimensions

    # Set up resize handler
    trap 'tui_update_dimensions; TUI_RESIZE_PENDING=1' WINCH

    TUI_INITIALIZED=1
    TUI_RESIZE_PENDING=0

    return 0
}
# }}}

# {{{ tui_cleanup
# Restore terminal state - call this when done with TUI
tui_cleanup() {
    [[ -z "${TUI_INITIALIZED:-}" ]] && return 0

    # Show cursor
    tput cnorm 2>/dev/null || true

    # Restore main screen buffer
    tput rmcup 2>/dev/null || true

    # Restore terminal settings
    if [[ -n "${TUI_STTY_SAVED:-}" ]]; then
        stty "$TUI_STTY_SAVED" 2>/dev/null || true
    else
        stty echo icanon 2>/dev/null || true
    fi

    # Remove traps
    trap - EXIT INT TERM WINCH

    TUI_INITIALIZED=""
}
# }}}

# {{{ tui_is_initialized
# Check if TUI is currently initialized
tui_is_initialized() {
    [[ -n "${TUI_INITIALIZED:-}" ]]
}
# }}}

# ============================================================================
# Terminal Dimensions
# ============================================================================

# Current terminal dimensions
TUI_COLS=80
TUI_ROWS=24

# {{{ tui_update_dimensions
# Update terminal dimension variables
tui_update_dimensions() {
    TUI_COLS=$(tput cols 2>/dev/null) || TUI_COLS=80
    TUI_ROWS=$(tput lines 2>/dev/null) || TUI_ROWS=24

    # Ensure minimum usable size
    [[ $TUI_COLS -lt 40 ]] && TUI_COLS=40
    [[ $TUI_ROWS -lt 10 ]] && TUI_ROWS=10
}
# }}}

# {{{ tui_get_dimensions
# Get terminal dimensions as "cols rows"
tui_get_dimensions() {
    echo "$TUI_COLS $TUI_ROWS"
}
# }}}

# {{{ tui_check_resize
# Check if resize occurred and clear flag
# Returns 0 if resize pending, 1 otherwise
tui_check_resize() {
    if [[ "${TUI_RESIZE_PENDING:-0}" == "1" ]]; then
        TUI_RESIZE_PENDING=0
        return 0
    fi
    return 1
}
# }}}

# ============================================================================
# Color and Formatting
# ============================================================================

# Color/formatting codes (set by tui_setup_colors)
TUI_BOLD=""
TUI_DIM=""
TUI_INVERSE=""
TUI_UNDERLINE=""
TUI_BLINK=""
TUI_RESET=""

TUI_BLACK=""
TUI_RED=""
TUI_GREEN=""
TUI_YELLOW=""
TUI_BLUE=""
TUI_MAGENTA=""
TUI_CYAN=""
TUI_WHITE=""

TUI_BG_BLACK=""
TUI_BG_RED=""
TUI_BG_GREEN=""
TUI_BG_YELLOW=""
TUI_BG_BLUE=""
TUI_BG_MAGENTA=""
TUI_BG_CYAN=""
TUI_BG_WHITE=""

TUI_COLORS_SUPPORTED=0

# {{{ tui_setup_colors
# Detect terminal color support and set color codes
tui_setup_colors() {
    # Check if terminal supports colors
    if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
        local colors
        colors=$(tput colors 2>/dev/null) || colors=0

        if [[ $colors -ge 8 ]]; then
            # Formatting
            TUI_BOLD=$(tput bold 2>/dev/null) || TUI_BOLD=""
            TUI_DIM=$(tput dim 2>/dev/null) || TUI_DIM=""
            TUI_INVERSE=$(tput rev 2>/dev/null) || TUI_INVERSE=""
            TUI_UNDERLINE=$(tput smul 2>/dev/null) || TUI_UNDERLINE=""
            TUI_BLINK=$(tput blink 2>/dev/null) || TUI_BLINK=""
            TUI_RESET=$(tput sgr0 2>/dev/null) || TUI_RESET=""

            # Foreground colors
            TUI_BLACK=$(tput setaf 0 2>/dev/null) || TUI_BLACK=""
            TUI_RED=$(tput setaf 1 2>/dev/null) || TUI_RED=""
            TUI_GREEN=$(tput setaf 2 2>/dev/null) || TUI_GREEN=""
            TUI_YELLOW=$(tput setaf 3 2>/dev/null) || TUI_YELLOW=""
            TUI_BLUE=$(tput setaf 4 2>/dev/null) || TUI_BLUE=""
            TUI_MAGENTA=$(tput setaf 5 2>/dev/null) || TUI_MAGENTA=""
            TUI_CYAN=$(tput setaf 6 2>/dev/null) || TUI_CYAN=""
            TUI_WHITE=$(tput setaf 7 2>/dev/null) || TUI_WHITE=""

            # Background colors
            TUI_BG_BLACK=$(tput setab 0 2>/dev/null) || TUI_BG_BLACK=""
            TUI_BG_RED=$(tput setab 1 2>/dev/null) || TUI_BG_RED=""
            TUI_BG_GREEN=$(tput setab 2 2>/dev/null) || TUI_BG_GREEN=""
            TUI_BG_YELLOW=$(tput setab 3 2>/dev/null) || TUI_BG_YELLOW=""
            TUI_BG_BLUE=$(tput setab 4 2>/dev/null) || TUI_BG_BLUE=""
            TUI_BG_MAGENTA=$(tput setab 5 2>/dev/null) || TUI_BG_MAGENTA=""
            TUI_BG_CYAN=$(tput setab 6 2>/dev/null) || TUI_BG_CYAN=""
            TUI_BG_WHITE=$(tput setab 7 2>/dev/null) || TUI_BG_WHITE=""

            TUI_COLORS_SUPPORTED=1
            return 0
        fi
    fi

    # No color support - all codes remain empty
    TUI_COLORS_SUPPORTED=0
    return 0  # Not an error, just no colors
}
# }}}

# {{{ tui_bold
# Output text in bold
tui_bold() {
    echo -n "${TUI_BOLD}${*}${TUI_RESET}"
}
# }}}

# {{{ tui_dim
# Output text in dim/faint style
tui_dim() {
    echo -n "${TUI_DIM}${*}${TUI_RESET}"
}
# }}}

# {{{ tui_highlight
# Output text with inverse/highlight
tui_highlight() {
    echo -n "${TUI_INVERSE}${*}${TUI_RESET}"
}
# }}}

# {{{ tui_underline
# Output text with underline
tui_underline() {
    echo -n "${TUI_UNDERLINE}${*}${TUI_RESET}"
}
# }}}

# {{{ tui_color
# Output text in specified color
# Usage: tui_color red "error message"
tui_color() {
    local color="$1"
    shift
    local color_code=""

    case "$color" in
        black)   color_code="$TUI_BLACK" ;;
        red)     color_code="$TUI_RED" ;;
        green)   color_code="$TUI_GREEN" ;;
        yellow)  color_code="$TUI_YELLOW" ;;
        blue)    color_code="$TUI_BLUE" ;;
        magenta) color_code="$TUI_MAGENTA" ;;
        cyan)    color_code="$TUI_CYAN" ;;
        white)   color_code="$TUI_WHITE" ;;
        *)       color_code="" ;;
    esac

    echo -n "${color_code}${*}${TUI_RESET}"
}
# }}}

# ============================================================================
# Cursor Positioning and Screen Control
# ============================================================================

# {{{ tui_goto
# Move cursor to specified row and column (0-indexed)
tui_goto() {
    local row="$1"
    local col="${2:-0}"
    # Use printf to stdout - must match where content goes
    printf '\033[%d;%dH' "$((row + 1))" "$((col + 1))"
}
# }}}

# {{{ tui_clear
# Clear the entire screen
tui_clear() {
    tput clear 2>/dev/null || echo -en "\e[2J\e[H"
}
# }}}

# {{{ tui_clear_line
# Clear from cursor to end of line
tui_clear_line() {
    printf '\033[K'
}
# }}}

# {{{ tui_clear_line_full
# Clear the entire current line
tui_clear_line_full() {
    tput el2 2>/dev/null || echo -en "\e[2K"
    tput el 2>/dev/null || true
}
# }}}

# {{{ tui_save_cursor
# Save cursor position
tui_save_cursor() {
    tput sc 2>/dev/null || echo -en "\e7"
}
# }}}

# {{{ tui_restore_cursor
# Restore cursor position
tui_restore_cursor() {
    tput rc 2>/dev/null || echo -en "\e8"
}
# }}}

# {{{ tui_hide_cursor
# Hide the cursor
tui_hide_cursor() {
    tput civis 2>/dev/null || echo -en "\e[?25l"
}
# }}}

# {{{ tui_show_cursor
# Show the cursor
tui_show_cursor() {
    tput cnorm 2>/dev/null || echo -en "\e[?25h"
}
# }}}

# ============================================================================
# Key Reading
# ============================================================================

# {{{ tui_read_key
# Read a single keypress and return a normalized key name
# Returns: UP, DOWN, LEFT, RIGHT, HOME, END, PGUP, PGDN,
#          SELECT (Enter/i/A), TOGGLE (Space), ESCAPE,
#          ALL (a), NONE (n), RUN (r), QUIT (q), HELP (?),
#          TOP (g), BOTTOM (G), BACKSPACE,
#          INDEX:N (for digits 0-9), CHAR:X (for other chars)
tui_read_key() {
    local key char

    # Read first character
    IFS= read -rsn1 key

    # Handle escape sequences
    if [[ "$key" == $'\x1b' ]]; then
        # Check if more characters are available (escape sequence)
        IFS= read -rsn1 -t 0.05 char || char=""

        if [[ -z "$char" ]]; then
            # Just escape key pressed
            echo "ESCAPE"
            return
        fi

        if [[ "$char" == "[" ]]; then
            # CSI sequence - read the rest
            IFS= read -rsn1 -t 0.05 char || char=""

            case "$char" in
                'A') echo "UP" ;;
                'B') echo "DOWN" ;;
                'C') echo "RIGHT" ;;
                'D') echo "LEFT" ;;
                'H') echo "HOME" ;;
                'F') echo "END" ;;
                '5')
                    # Page up - consume the ~
                    read -rsn1 -t 0.05 _ || true
                    echo "PGUP"
                    ;;
                '6')
                    # Page down - consume the ~
                    read -rsn1 -t 0.05 _ || true
                    echo "PGDN"
                    ;;
                '1'|'7')
                    # Could be Home (1~, 7~) - consume remaining chars
                    read -rsn1 -t 0.05 _ || true
                    echo "HOME"
                    ;;
                '4'|'8')
                    # Could be End (4~, 8~) - consume remaining chars
                    read -rsn1 -t 0.05 _ || true
                    echo "END"
                    ;;
                '3')
                    # Delete key (3~) - consume the ~
                    read -rsn1 -t 0.05 _ || true
                    echo "DELETE"
                    ;;
                *)
                    # Unknown CSI sequence - consume remaining if any
                    while IFS= read -rsn1 -t 0.01 _; do :; done
                    echo "UNKNOWN"
                    ;;
            esac
        elif [[ "$char" == "O" ]]; then
            # SS3 sequence (some terminals use these for arrows/function keys)
            IFS= read -rsn1 -t 0.05 char || char=""
            case "$char" in
                'A') echo "UP" ;;
                'B') echo "DOWN" ;;
                'C') echo "RIGHT" ;;
                'D') echo "LEFT" ;;
                'H') echo "HOME" ;;
                'F') echo "END" ;;
                *)   echo "UNKNOWN" ;;
            esac
        else
            # Alt+key combination
            echo "ALT:$char"
        fi
        return
    fi

    # Handle regular keys
    case "$key" in
        # Vim navigation
        'k') echo "UP" ;;
        'j') echo "DOWN" ;;
        'h') echo "LEFT" ;;
        'l') echo "RIGHT" ;;
        'g') echo "TOP" ;;
        'G') echo "BOTTOM" ;;

        # Selection keys
        'i') echo "SELECT" ;;
        'A') echo "SELECT" ;;     # Shift+A
        '')  echo "SELECT" ;;     # Enter (carriage return)
        ' ') echo "TOGGLE" ;;

        # Action keys
        'a') echo "ALL" ;;
        'n') echo "NONE" ;;
        'r') echo "RUN" ;;
        'q') echo "QUIT" ;;
        '?') echo "HELP" ;;

        # Numbers for index jumping
        [0-9]) echo "INDEX:$key" ;;

        # Backspace (various terminals send different codes)
        $'\x7f') echo "BACKSPACE" ;;
        $'\x08') echo "BACKSPACE" ;;

        # Tab
        $'\t') echo "TAB" ;;

        # Any other printable character
        *)
            if [[ -n "$key" ]]; then
                echo "CHAR:$key"
            else
                echo "UNKNOWN"
            fi
            ;;
    esac
}
# }}}

# {{{ tui_read_key_timeout
# Read a keypress with timeout
# Args: timeout_seconds (default 1)
# Returns: key name or "TIMEOUT" if no input
tui_read_key_timeout() {
    local timeout="${1:-1}"
    local key

    # Use read timeout
    IFS= read -rsn1 -t "$timeout" key || {
        echo "TIMEOUT"
        return 1
    }

    # If we got a key, put it back and use regular read_key
    # This is a bit hacky but handles escape sequences properly
    if [[ "$key" == $'\x1b' ]]; then
        # Check for escape sequence
        local char
        IFS= read -rsn1 -t 0.05 char || char=""

        if [[ -z "$char" ]]; then
            echo "ESCAPE"
            return 0
        fi

        # There's more - handle as escape sequence
        if [[ "$char" == "[" ]]; then
            IFS= read -rsn1 -t 0.05 char || char=""
            case "$char" in
                'A') echo "UP" ;;
                'B') echo "DOWN" ;;
                'C') echo "RIGHT" ;;
                'D') echo "LEFT" ;;
                *)   echo "UNKNOWN" ;;
            esac
        else
            echo "ALT:$char"
        fi
    else
        # Regular key handling (simplified)
        case "$key" in
            'k') echo "UP" ;;
            'j') echo "DOWN" ;;
            'h') echo "LEFT" ;;
            'l') echo "RIGHT" ;;
            'q') echo "QUIT" ;;
            '') echo "SELECT" ;;
            ' ') echo "TOGGLE" ;;
            [0-9]) echo "INDEX:$key" ;;
            *) echo "CHAR:$key" ;;
        esac
    fi
}
# }}}

# {{{ tui_wait_key
# Wait for any keypress
tui_wait_key() {
    local msg="${1:-Press any key to continue...}"
    echo -n "$msg"
    tui_read_key > /dev/null
    echo
}
# }}}

# ============================================================================
# Drawing Helpers
# ============================================================================

# {{{ tui_hline
# Draw a horizontal line of specified character
# Args: length [char] [col] [row]
tui_hline() {
    local length="$1"
    local char="${2:-─}"
    local col="${3:-}"
    local row="${4:-}"

    if [[ -n "$row" ]]; then
        tui_goto "$row" "${col:-0}"
    fi

    # Build string by repeating char (tr doesn't work with multi-byte UTF-8)
    local line=""
    for ((i = 0; i < length; i++)); do
        line+="$char"
    done
    echo -n "$line"
}
# }}}

# {{{ tui_box_top
# Draw top of a box
# Args: width [style] - style: single, double, heavy
tui_box_top() {
    local width="$1"
    local style="${2:-single}"

    local tl tr h
    case "$style" in
        double) tl="╔"; tr="╗"; h="═" ;;
        heavy)  tl="┏"; tr="┓"; h="━" ;;
        *)      tl="┌"; tr="┐"; h="─" ;;
    esac

    echo -n "$tl"
    tui_hline "$((width - 2))" "$h"
    echo "$tr"
}
# }}}

# {{{ tui_box_bottom
# Draw bottom of a box
tui_box_bottom() {
    local width="$1"
    local style="${2:-single}"

    local bl br h
    case "$style" in
        double) bl="╚"; br="╝"; h="═" ;;
        heavy)  bl="┗"; br="┛"; h="━" ;;
        *)      bl="└"; br="┘"; h="─" ;;
    esac

    echo -n "$bl"
    tui_hline "$((width - 2))" "$h"
    echo "$br"
}
# }}}

# {{{ tui_box_separator
# Draw box separator line
tui_box_separator() {
    local width="$1"
    local style="${2:-single}"

    local l r h
    case "$style" in
        double) l="╠"; r="╣"; h="═" ;;
        heavy)  l="┣"; r="┫"; h="━" ;;
        *)      l="├"; r="┤"; h="─" ;;
    esac

    echo -n "$l"
    tui_hline "$((width - 2))" "$h"
    echo "$r"
}
# }}}

# {{{ tui_box_line
# Draw a line of content within a box
# Args: width content [align] - align: left, center, right
tui_box_line() {
    local width="$1"
    local content="$2"
    local align="${3:-left}"
    local style="${4:-single}"

    local v
    case "$style" in
        double) v="║" ;;
        heavy)  v="┃" ;;
        *)      v="│" ;;
    esac

    # Calculate content width (strip ANSI codes for length calculation)
    local plain_content
    plain_content=$(echo -n "$content" | sed 's/\x1b\[[0-9;]*m//g')
    local content_len=${#plain_content}
    local inner_width=$((width - 2))

    echo -n "$v"

    case "$align" in
        center)
            local pad_left=$(( (inner_width - content_len) / 2 ))
            local pad_right=$((inner_width - content_len - pad_left))
            printf '%*s' "$pad_left" ''
            echo -n "$content"
            printf '%*s' "$pad_right" ''
            ;;
        right)
            printf '%*s' "$((inner_width - content_len))" ''
            echo -n "$content"
            ;;
        *)  # left
            echo -n "$content"
            printf '%*s' "$((inner_width - content_len))" ''
            ;;
    esac

    echo "$v"
}
# }}}

# ============================================================================
# Progress/Status Indicators
# ============================================================================

# {{{ tui_spinner
# Show a spinner at current position
# Args: frame_number
# Returns: spinner character for that frame
tui_spinner() {
    local frame="${1:-0}"
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local idx=$((frame % ${#chars}))
    echo -n "${chars:$idx:1}"
}
# }}}

# {{{ tui_progress_bar
# Draw a progress bar
# Args: current max width [filled_char] [empty_char]
tui_progress_bar() {
    local current="$1"
    local max="$2"
    local width="${3:-20}"
    local filled="${4:-█}"
    local empty="${5:-░}"

    local percent=$((current * 100 / max))
    local filled_count=$((current * width / max))
    local empty_count=$((width - filled_count))

    echo -n "["
    printf "%${filled_count}s" '' | tr ' ' "$filled"
    printf "%${empty_count}s" '' | tr ' ' "$empty"
    echo -n "] ${percent}%"
}
# }}}

# ============================================================================
# Initialization
# ============================================================================

# Auto-initialize colors when library is sourced
tui_setup_colors
