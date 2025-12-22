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
declare -A MENU_ITEM_FILEPATHS=()  # Optional file path for preview
declare -a MENU_DEPENDENCIES=()    # Dependencies: "item_id|depends_on|required_values|invert|multi"

MENU_TITLE=""
MENU_SUBTITLE=""
MENU_RESULT_ACTION=""

# Command preview configuration
MENU_COMMAND_BASE=""
MENU_COMMAND_BASE_ABSOLUTE=""
MENU_COMMAND_PREVIEW_ITEM=""
MENU_COMMAND_FILE_SECTION=""

# Content sources - array of content to display in preview panel
# Each entry is: "type|label|content" where type is "text" or "file"
# Content panel shows these sources separated by dashed lines
# The last source gets remaining available space
declare -a MENU_CONTENT_SOURCES=()
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
    MENU_ITEM_FILEPATHS=()
    MENU_DEPENDENCIES=()
    MENU_TITLE=""
    MENU_SUBTITLE=""
    MENU_RESULT_ACTION=""
    MENU_COMMAND_BASE=""
    MENU_COMMAND_BASE_ABSOLUTE=""
    MENU_COMMAND_PREVIEW_ITEM=""
    MENU_COMMAND_FILE_SECTION=""
    MENU_CONTENT_SOURCES=()
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
    # Default value depends on type: "0" for checkbox, "" for others
    local value="$5"
    if [[ -z "$value" ]]; then
        if [[ "$type" == "checkbox" ]]; then
            value="0"
        else
            value=""
        fi
    fi
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
# Automatically computes the absolute path for the base command
menu_set_command_config() {
    MENU_COMMAND_BASE="$1"
    MENU_COMMAND_PREVIEW_ITEM="$2"
    MENU_COMMAND_FILE_SECTION="${3:-}"

    # Compute absolute path for the base command
    # If it starts with ./ or is a relative path, resolve it
    if [[ "$MENU_COMMAND_BASE" == ./* ]]; then
        # Relative path starting with ./
        local base_dir
        base_dir=$(dirname "$MENU_COMMAND_BASE")
        local base_name
        base_name=$(basename "$MENU_COMMAND_BASE")
        MENU_COMMAND_BASE_ABSOLUTE="$(cd "$base_dir" 2>/dev/null && pwd)/$base_name"
    elif [[ "$MENU_COMMAND_BASE" != /* && "$MENU_COMMAND_BASE" != "" ]]; then
        # Relative path not starting with ./ or /
        # Check if it's a command in PATH (like "ls") or a relative file
        if [[ -f "$MENU_COMMAND_BASE" ]]; then
            MENU_COMMAND_BASE_ABSOLUTE="$(cd "$(dirname "$MENU_COMMAND_BASE")" 2>/dev/null && pwd)/$(basename "$MENU_COMMAND_BASE")"
        else
            # Assume it's a command in PATH, keep it as-is
            MENU_COMMAND_BASE_ABSOLUTE="$MENU_COMMAND_BASE"
        fi
    else
        # Already absolute or empty
        MENU_COMMAND_BASE_ABSOLUTE="$MENU_COMMAND_BASE"
    fi
}
# }}}

# {{{ menu_set_item_filepath
# Set a file path for an item to show preview when selected
# When this item is highlighted, the file content will be shown in the preview panel
menu_set_item_filepath() {
    local item_id="$1"
    local filepath="$2"
    MENU_ITEM_FILEPATHS["$item_id"]="$filepath"
}
# }}}

# {{{ menu_add_content_source
# Add a content source to the preview panel
# Sources are shown in order, separated by dashed box-drawing lines
# The last source in the array gets all remaining available space
#
# Usage:
#   menu_add_content_source "text" "Label" "Static text content"
#   menu_add_content_source "file" "Preview" "/path/to/file"
#   menu_add_content_source "item_file" "" ""  # Uses current item's filepath
#
# Arguments:
#   type: "text" (static content), "file" (read from path), "item_file" (use selected item's filepath)
#   label: Optional label shown above the content (empty string for none)
#   content: The text content or file path (ignored for item_file type)
menu_add_content_source() {
    local type="$1"
    local label="$2"
    local content="$3"
    # Store as pipe-delimited: type|label|content
    MENU_CONTENT_SOURCES+=("${type}|${label}|${content}")
}
# }}}

# {{{ menu_add_dependency
# Add a dependency rule: item_id is enabled/disabled based on depends_on's value
#
# Arguments:
#   item_id: The item that will be enabled/disabled
#   depends_on: The item_id whose value controls the dependency
#   required_values: Comma-separated values that ENABLE item_id (e.g., "1" for checkbox)
#   invert: If "true", item is enabled when depends_on is NOT in required_values
#   reason: Optional message shown when item is disabled (e.g., "Requires Execute mode")
#   color: Optional color for reason (yellow, orange, green, red) - default yellow
#
# Examples:
#   # "session" disabled when "streaming" is selected (incompatible)
#   menu_add_dependency "session" "streaming" "1" "true" \
#       "Incompatible with Streaming mode" "orange"
#
#   # "verbose" only enabled when "analyze" mode is selected
#   menu_add_dependency "verbose" "mode" "analyze" "false" \
#       "Only available in Analyze mode"
menu_add_dependency() {
    local item_id="$1"
    local depends_on="$2"
    local required_values="${3:-1}"
    local invert="${4:-false}"
    local reason="${5:-}"
    local color="${6:-yellow}"

    MENU_DEPENDENCIES+=("${item_id}|${depends_on}|${required_values}|${invert}|single|${reason}|${color}")
}
# }}}

# {{{ menu_add_dependency_multi
# Add a dependency where item is enabled if ANY of the depends_on items match
#
# Arguments:
#   item_id: The item that will be enabled/disabled
#   depends_on_list: Space-separated list of "item:values" pairs
#   invert: If "true", item is enabled when NONE of the conditions match
#   reason: Optional message shown when item is disabled
#   color: Optional color for reason (yellow, orange, green, red) - default yellow
#
# Example:
#   # "no_confirm" enabled when either "execute" OR "implement" is selected
#   menu_add_dependency_multi "no_confirm" "execute:1 implement:1" "false" \
#       "Only available in Execute or Implement mode" "yellow"
menu_add_dependency_multi() {
    local item_id="$1"
    local depends_on_list="$2"
    local invert="${3:-false}"
    local reason="${4:-}"
    local color="${5:-yellow}"

    MENU_DEPENDENCIES+=("${item_id}|${depends_on_list}||${invert}|multi|${reason}|${color}")
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
    if [[ -n "$MENU_COMMAND_BASE_ABSOLUTE" ]]; then
        json+=',"command_base_absolute":"'"$(_menu_escape_json "$MENU_COMMAND_BASE_ABSOLUTE")"'"'
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
            local filepath="${MENU_ITEM_FILEPATHS[$item_id]:-}"

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
            if [[ -n "$filepath" ]]; then
                json+=',"filepath":"'"$(_menu_escape_json "$filepath")"'"'
            fi
            json+='}'
        done

        json+=']}'
    done

    json+=']'

    # Add content sources if any
    if [[ ${#MENU_CONTENT_SOURCES[@]} -gt 0 ]]; then
        json+=',"content_sources":['
        local first_source=1
        for source in "${MENU_CONTENT_SOURCES[@]}"; do
            [[ $first_source -eq 0 ]] && json+=','
            first_source=0

            # Parse pipe-delimited: type|label|content
            local src_type="${source%%|*}"
            local rest="${source#*|}"
            local src_label="${rest%%|*}"
            local src_content="${rest#*|}"

            json+='{"type":"'"$src_type"'"'
            json+=',"label":"'"$(_menu_escape_json "$src_label")"'"'
            json+=',"content":"'"$(_menu_escape_json "$src_content")"'"}'
        done
        json+=']'
    fi

    # Add dependencies if any
    if [[ ${#MENU_DEPENDENCIES[@]} -gt 0 ]]; then
        json+=',"dependencies":['
        local first_dep=1
        for dep in "${MENU_DEPENDENCIES[@]}"; do
            [[ $first_dep -eq 0 ]] && json+=','
            first_dep=0

            # Parse: item_id|depends_on|required_values|invert|type|reason|color
            local dep_item="${dep%%|*}"
            local rest="${dep#*|}"
            local dep_depends_on="${rest%%|*}"
            rest="${rest#*|}"
            local dep_values="${rest%%|*}"
            rest="${rest#*|}"
            local dep_invert="${rest%%|*}"
            rest="${rest#*|}"
            local dep_type="${rest%%|*}"
            rest="${rest#*|}"
            local dep_reason="${rest%%|*}"
            local dep_color="${rest#*|}"

            json+='{"item_id":"'"$dep_item"'"'

            if [[ "$dep_type" == "multi" ]]; then
                # Multi-dependency: depends_on_list is space-separated "item:values" pairs
                json+=',"multi":true,"depends_on_list":['
                local first_cond=1
                for cond in $dep_depends_on; do
                    [[ $first_cond -eq 0 ]] && json+=','
                    first_cond=0
                    local cond_item="${cond%%:*}"
                    local cond_values="${cond#*:}"
                    json+='["'"$cond_item"'",["'"$cond_values"'"]]'
                done
                json+=']'
            else
                # Single dependency
                json+=',"depends_on":"'"$dep_depends_on"'"'
                # Split comma-separated values into array
                json+=',"required_values":['
                local first_val=1
                IFS=',' read -ra vals <<< "$dep_values"
                for val in "${vals[@]}"; do
                    [[ $first_val -eq 0 ]] && json+=','
                    first_val=0
                    json+='"'"$val"'"'
                done
                json+=']'
            fi

            if [[ "$dep_invert" == "true" ]]; then
                json+=',"invert":true'
            else
                json+=',"invert":false'
            fi

            # Add reason and color if provided
            if [[ -n "$dep_reason" ]]; then
                json+=',"reason":"'"$(_menu_escape_json "$dep_reason")"'"'
            fi
            if [[ -n "$dep_color" ]]; then
                json+=',"color":"'"$dep_color"'"'
            fi
            json+='}'
        done
        json+=']'
    fi

    json+='}'
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
