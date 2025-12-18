#!/usr/bin/env bash
# lua-menu.sh - Bash wrapper for Lua TUI menu
# Provides API-compatible functions with menu.sh but uses Lua backend.
# Source this file to replace the bash TUI with Lua rendering.

LIBS_DIR="${LIBS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# {{{ State variables
declare -a MENU_SECTIONS=()
declare -A MENU_SECTION_TITLES=()
declare -A MENU_SECTION_TYPES=()
declare -A MENU_SECTION_ITEMS=()
declare -A MENU_ITEM_LABELS=()
declare -A MENU_ITEM_TYPES=()
declare -A MENU_VALUES=()
declare -A MENU_ITEM_DESCRIPTIONS=()
declare -A MENU_ITEM_CONFIGS=()
declare -A MENU_ITEM_DISABLED=()
declare -A MENU_ITEM_SHORTCUTS=()
declare -A MENU_ITEM_FLAGS=()

MENU_TITLE=""
MENU_SUBTITLE=""
MENU_RESULT_ACTION=""

# Command preview configuration
MENU_COMMAND_BASE=""
MENU_COMMAND_PREVIEW_ITEM=""
MENU_COMMAND_FILE_SECTION=""
# }}}

# {{{ menu_init
# Initialize menu state
menu_init() {
    MENU_SECTIONS=()
    MENU_SECTION_TITLES=()
    MENU_SECTION_TYPES=()
    MENU_SECTION_ITEMS=()
    MENU_ITEM_LABELS=()
    MENU_ITEM_TYPES=()
    MENU_VALUES=()
    MENU_ITEM_DESCRIPTIONS=()
    MENU_ITEM_CONFIGS=()
    MENU_ITEM_DISABLED=()
    MENU_ITEM_SHORTCUTS=()
    MENU_ITEM_FLAGS=()
    MENU_TITLE=""
    MENU_SUBTITLE=""
    MENU_RESULT_ACTION=""
    MENU_COMMAND_BASE=""
    MENU_COMMAND_PREVIEW_ITEM=""
    MENU_COMMAND_FILE_SECTION=""
}
# }}}

# {{{ menu_set_title
# Set menu title and optional subtitle
menu_set_title() {
    MENU_TITLE="$1"
    MENU_SUBTITLE="${2:-}"
}
# }}}

# {{{ menu_add_section
# Add a section: id, type (single|multi|list), title
menu_add_section() {
    local id="$1"
    local type="$2"
    local title="$3"

    MENU_SECTIONS+=("$id")
    MENU_SECTION_TITLES["$id"]="$title"
    # Map 'list' to 'multi' for Lua (both behave same way)
    [[ "$type" == "list" ]] && type="multi"
    MENU_SECTION_TYPES["$id"]="$type"
    MENU_SECTION_ITEMS["$id"]=""
}
# }}}

# {{{ menu_add_item
# Add item: section_id, item_id, label, type, value, description, shortcut, cli_flag
# For flag type: value format is "value:width" (e.g., "3:2")
# shortcut: optional single character for quick access (e.g., "r" for reset)
# cli_flag: optional CLI flag for command preview (e.g., "--verbose")
menu_add_item() {
    local section_id="$1"
    local item_id="$2"
    local label="$3"
    local type="${4:-checkbox}"
    local value="${5:-0}"
    local description="${6:-}"
    local shortcut="${7:-}"
    local cli_flag="${8:-}"

    # === Developer validation checks ===
    # Check for duplicate item_id
    if [[ -n "${MENU_ITEM_LABELS[$item_id]+isset}" ]]; then
        printf >&2 "ERROR: Duplicate item_id '%s' (label: '%s')\n" "$item_id" "$label"
        printf >&2 "       Previously defined with label: '%s'\n" "${MENU_ITEM_LABELS[$item_id]}"
        return 1
    fi

    # Check for duplicate shortcut (if provided)
    if [[ -n "$shortcut" ]]; then
        for existing_id in "${!MENU_ITEM_SHORTCUTS[@]}"; do
            if [[ "${MENU_ITEM_SHORTCUTS[$existing_id]}" == "$shortcut" ]]; then
                printf >&2 "ERROR: Duplicate shortcut '%s' for item '%s'\n" "$shortcut" "$item_id"
                printf >&2 "       Already used by item: '%s'\n" "$existing_id"
                return 1
            fi
        done
    fi

    # Check for duplicate cli_flag (if provided)
    if [[ -n "$cli_flag" ]]; then
        for existing_id in "${!MENU_ITEM_FLAGS[@]}"; do
            if [[ "${MENU_ITEM_FLAGS[$existing_id]}" == "$cli_flag" ]]; then
                printf >&2 "ERROR: Duplicate cli_flag '%s' for item '%s'\n" "$cli_flag" "$item_id"
                printf >&2 "       Already used by item: '%s'\n" "$existing_id"
                return 1
            fi
        done
    fi

    # Append to section's item list
    if [[ -n "${MENU_SECTION_ITEMS[$section_id]}" ]]; then
        MENU_SECTION_ITEMS["$section_id"]="${MENU_SECTION_ITEMS[$section_id]},$item_id"
    else
        MENU_SECTION_ITEMS["$section_id"]="$item_id"
    fi

    MENU_ITEM_LABELS["$item_id"]="$label"
    MENU_ITEM_TYPES["$item_id"]="$type"
    MENU_ITEM_DESCRIPTIONS["$item_id"]="$description"
    MENU_ITEM_DISABLED["$item_id"]=""
    MENU_ITEM_SHORTCUTS["$item_id"]="$shortcut"
    MENU_ITEM_FLAGS["$item_id"]="$cli_flag"

    # For flag type, value may be "value:width" - parse it
    if [[ "$type" == "flag" ]]; then
        local actual_value="${value%%:*}"
        local width="${value#*:}"
        [[ "$width" == "$value" ]] && width="10"  # Default width if not specified
        MENU_VALUES["$item_id"]="$actual_value"
        MENU_ITEM_CONFIGS["$item_id"]="$width"
    else
        MENU_VALUES["$item_id"]="$value"
        MENU_ITEM_CONFIGS["$item_id"]=""
    fi
}
# }}}

# {{{ menu_disable_item
menu_disable_item() {
    local item_id="$1"
    MENU_ITEM_DISABLED["$item_id"]="1"
}
# }}}

# {{{ menu_set_value
menu_set_value() {
    local item_id="$1"
    local value="$2"
    MENU_VALUES["$item_id"]="$value"
}
# }}}

# {{{ menu_get_value
menu_get_value() {
    local item_id="$1"
    echo "${MENU_VALUES[$item_id]:-}"
}
# }}}

# {{{ menu_set_command_config
# Configure command preview: base_command, preview_item_id, file_section_id
menu_set_command_config() {
    MENU_COMMAND_BASE="$1"
    MENU_COMMAND_PREVIEW_ITEM="$2"
    MENU_COMMAND_FILE_SECTION="${3:-}"
}
# }}}

# {{{ _menu_escape_json
# Escape a string for JSON
_menu_escape_json() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    # Use printf to avoid echo interpreting flags like -n, -e
    printf '%s\n' "$str"
}
# }}}

# {{{ _menu_build_json
# Build JSON config from current state
_menu_build_json() {
    local json='{"title":"'"$(_menu_escape_json "$MENU_TITLE")"'"'
    json+=',"subtitle":"'"$(_menu_escape_json "$MENU_SUBTITLE")"'"'

    # Command preview configuration
    if [[ -n "$MENU_COMMAND_BASE" ]]; then
        json+=',"command_base":"'"$(_menu_escape_json "$MENU_COMMAND_BASE")"'"'
    fi
    if [[ -n "$MENU_COMMAND_PREVIEW_ITEM" ]]; then
        json+=',"command_preview_item":"'"$MENU_COMMAND_PREVIEW_ITEM"'"'
    fi
    if [[ -n "$MENU_COMMAND_FILE_SECTION" ]]; then
        json+=',"command_file_section":"'"$MENU_COMMAND_FILE_SECTION"'"'
    fi

    json+=',"sections":['

    local first_section=1
    for section_id in "${MENU_SECTIONS[@]}"; do
        [[ $first_section -eq 0 ]] && json+=','
        first_section=0

        json+='{"id":"'"$section_id"'"'
        json+=',"title":"'"$(_menu_escape_json "${MENU_SECTION_TITLES[$section_id]}")"'"'
        json+=',"type":"'"${MENU_SECTION_TYPES[$section_id]}"'"'
        json+=',"items":['

        local items="${MENU_SECTION_ITEMS[$section_id]}"
        local first_item=1
        IFS=',' read -ra item_arr <<< "$items"
        for item_id in "${item_arr[@]}"; do
            [[ -z "$item_id" ]] && continue
            [[ $first_item -eq 0 ]] && json+=','
            first_item=0

            local label="${MENU_ITEM_LABELS[$item_id]}"
            local type="${MENU_ITEM_TYPES[$item_id]}"
            local value="${MENU_VALUES[$item_id]}"
            local desc="${MENU_ITEM_DESCRIPTIONS[$item_id]}"
            local config="${MENU_ITEM_CONFIGS[$item_id]}"
            local disabled="${MENU_ITEM_DISABLED[$item_id]}"
            local shortcut="${MENU_ITEM_SHORTCUTS[$item_id]}"
            local cli_flag="${MENU_ITEM_FLAGS[$item_id]}"

            json+='{"id":"'"$item_id"'"'
            json+=',"label":"'"$(_menu_escape_json "$label")"'"'
            json+=',"type":"'"$type"'"'
            json+=',"value":"'"$(_menu_escape_json "$value")"'"'
            json+=',"description":"'"$(_menu_escape_json "$desc")"'"'
            json+=',"config":"'"$(_menu_escape_json "$config")"'"'
            if [[ -n "$disabled" ]]; then
                json+=',"disabled":true'
            else
                json+=',"disabled":false'
            fi
            if [[ -n "$shortcut" ]]; then
                json+=',"shortcut":"'"$shortcut"'"'
            fi
            if [[ -n "$cli_flag" ]]; then
                json+=',"flag":"'"$(_menu_escape_json "$cli_flag")"'"'
            fi
            json+='}'
        done

        json+=']}'
    done

    json+=']}'
    echo "$json"
}
# }}}

# {{{ _menu_parse_result
# Parse JSON result from Lua menu
_menu_parse_result() {
    local result="$1"

    # Extract action
    MENU_RESULT_ACTION=$(echo "$result" | sed -n 's/.*"action":"\([^"]*\)".*/\1/p')

    # Extract values and update MENU_VALUES
    local values_str=$(echo "$result" | sed -n 's/.*"values":{\([^}]*\)}.*/\1/p')

    # Parse each key:value pair
    while [[ "$values_str" =~ \"([^\"]+)\":\"([^\"]*)\" ]]; do
        local key="${BASH_REMATCH[1]}"
        local val="${BASH_REMATCH[2]}"
        MENU_VALUES["$key"]="$val"
        values_str="${values_str#*\"$key\":\"$val\"}"
    done
}
# }}}

# {{{ menu_run
# Run the menu and capture results
# Returns: 0 if user selected "run", 1 if user quit
menu_run() {
    local json
    json=$(_menu_build_json)

    # Write JSON to temp file (stdin must stay connected to terminal for input)
    local config_file
    config_file=$(mktemp /tmp/lua-menu-XXXXXX.json)
    echo "$json" > "$config_file"

    local result
    # Don't capture stderr - let it go to terminal for debugging
    result=$(luajit "${LIBS_DIR}/menu-runner.lua" "$config_file")
    local exit_code=$?

    # Cleanup temp file
    rm -f "$config_file"

    if [[ $exit_code -ne 0 ]]; then
        echo "Error running Lua menu: $result" >&2
        return 1
    fi

    _menu_parse_result "$result"

    # Return 0 for "run", 1 for "quit"
    if [[ "$MENU_RESULT_ACTION" == "run" ]]; then
        return 0
    else
        return 1
    fi
}
# }}}

# {{{ menu_cleanup
# Cleanup (no-op for Lua backend - it cleans up automatically)
menu_cleanup() {
    :
}
# }}}

# {{{ Compatibility stubs for bash TUI functions
# These are no-ops since Lua handles everything internally

tui_init() {
    # Lua menu initializes when menu_run is called
    return 0
}

tui_cleanup() {
    # Lua menu cleans up automatically after menu_run
    :
}
# }}}
