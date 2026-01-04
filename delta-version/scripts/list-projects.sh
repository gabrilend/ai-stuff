#!/bin/bash
# Project listing utility for Delta-Version repository management
# Provides standardized discovery and listing of project directories with flexible output formats

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"

# -- {{{ define_non_project_directories
function define_non_project_directories() {
    excluded_patterns=(
        "issues" "scripts" "docs" ".git" ".claude" "llm-transcripts"
        "build" "target" "dist" "out" "bin"
        "libs" "node_modules" "vendor" "external"
        "tools" "utils" "backup" "backups" "old" "archive" "tmp" "temp"
        "delta-version" ".operations" ".canaries"
    )
}
# }}}

# -- {{{ is_excluded_directory
function is_excluded_directory() {
    local dir_path="$1"
    local dir_name
    dir_name=$(basename "$dir_path")
    
    define_non_project_directories
    
    for pattern in "${excluded_patterns[@]}"; do
        [[ "$dir_name" == $pattern ]] && return 0
        [[ "$dir_name" == .storage_* ]] && return 0
        [[ "$dir_name" == .*_operations* ]] && return 0
    done
    
    return 1
}
# }}}

# -- {{{ detect_project_characteristics
function detect_project_characteristics() {
    local dir_path="$1"
    local score=0
    
    [[ -d "$dir_path/src" ]] && score=$((score + 50))
    [[ -d "$dir_path/issues" ]] && score=$((score + 40))
    [[ -f "$dir_path/Cargo.toml" ]] && score=$((score + 30))
    [[ -f "$dir_path/package.json" ]] && score=$((score + 30))
    [[ -f "$dir_path/Makefile" ]] && score=$((score + 25))
    [[ -f "$dir_path/.gitignore" ]] && score=$((score + 20))
    [[ -f "$dir_path/README.md" ]] && score=$((score + 15))
    [[ -d "$dir_path/docs" ]] && score=$((score + 10))
    
    [[ $score -ge 50 ]] && return 0 || return 1
}
# }}}

# -- {{{ is_project_directory
function is_project_directory() {
    local dir_path="$1"
    
    [[ ! -d "$dir_path" ]] && return 1
    
    detect_project_characteristics "$dir_path"
}
# }}}

# -- {{{ output_project_names
function output_project_names() {
    local projects=("$@")
    for project in "${projects[@]}"; do
        basename "$project"
    done
}
# }}}

# -- {{{ output_absolute_paths
function output_absolute_paths() {
    local projects=("$@")
    for project in "${projects[@]}"; do
        realpath "$project"
    done
}
# }}}

# -- {{{ output_relative_paths
function output_relative_paths() {
    local projects=("$@")
    local base_dir="$DIR"
    for project in "${projects[@]}"; do
        realpath --relative-to="$base_dir" "$project"
    done
}
# }}}

# -- {{{ output_json_format
function output_json_format() {
    local projects=("$@")
    echo "{"
    echo "  \"projects\": ["
    local first=true
    for project in "${projects[@]}"; do
        [[ "$first" == "false" ]] && echo ","
        echo -n "    {\"name\": \"$(basename "$project")\", \"path\": \"$(realpath "$project")\"}"
        first=false
    done
    echo ""
    echo "  ]"
    echo "}"
}
# }}}

# -- {{{ output_csv_format
function output_csv_format() {
    local projects=("$@")
    echo "name,path"
    for project in "${projects[@]}"; do
        echo "$(basename "$project"),$(realpath "$project")"
    done
}
# }}}

# -- {{{ format_project_output
function format_project_output() {
    local format="$1"
    shift
    local projects=("$@")
    
    case "$format" in
        "names") output_project_names "${projects[@]}" ;;
        "abs-paths") output_absolute_paths "${projects[@]}" ;;
        "rel-paths") output_relative_paths "${projects[@]}" ;;
        "json") output_json_format "${projects[@]}" ;;
        "csv") output_csv_format "${projects[@]}" ;;
        "lines") output_project_names "${projects[@]}" ;;
        *) output_project_names "${projects[@]}" ;;
    esac
}
# }}}

# -- {{{ get_project_list_for_integration
function get_project_list_for_integration() {
    local format="${1:-names}"
    local base_dir="${2:-$DIR}"
    
    local discovered_projects=()
    while IFS= read -r -d '' dir; do
        if [[ -d "$dir" ]] && ! is_excluded_directory "$dir" && is_project_directory "$dir"; then
            discovered_projects+=("$dir")
        fi
    done < <(find "$base_dir" -maxdepth 1 -type d -print0)
    
    format_project_output "$format" "${discovered_projects[@]}"
}
# }}}

# -- {{{ get_non_project_directories
function get_non_project_directories() {
    local format="${1:-names}"
    local base_dir="${2:-$DIR}"
    
    local non_projects=()
    while IFS= read -r -d '' dir; do
        if [[ -d "$dir" ]] && (is_excluded_directory "$dir" || ! is_project_directory "$dir"); then
            non_projects+=("$dir")
        fi
    done < <(find "$base_dir" -maxdepth 1 -type d -print0)
    
    format_project_output "$format" "${non_projects[@]}"
}
# }}}

# -- {{{ validate_project_detection
function validate_project_detection() {
    echo "=== Project Detection Validation ==="
    echo
    echo "Projects detected:"
    get_project_list_for_integration "names" "$DIR"
    echo
    echo "Non-project directories:"
    get_non_project_directories "names" "$DIR"
    echo
    echo "Manual verification recommended for edge cases."
}
# }}}

# ============================================================================
# External Directory Configuration Functions
# Added as part of Issue 024: External Project Directory Configuration
# These functions enable discovery and management of projects in directories
# outside the main repository structure.
# ============================================================================

# -- {{{ get_config_file_path
function get_config_file_path() {
    # Returns the path to the external projects configuration file
    # Uses DELTA_CONFIG_DIR if set, otherwise defaults to delta-version/config/
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local config_dir="${DELTA_CONFIG_DIR:-$(dirname "$script_dir")/config}"
    echo "$config_dir/external-projects.conf"
}
# }}}

# -- {{{ get_config_setting
function get_config_setting() {
    # Retrieves a setting value from the configuration file
    # Arguments: section_name, key_name, default_value
    local section="$1"
    local key="$2"
    local default="${3:-}"
    local config_file
    config_file="$(get_config_file_path)"

    if [[ ! -f "$config_file" ]]; then
        echo "$default"
        return
    fi

    # Parse INI-style config: find section, then find key within it
    local in_section=false
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Check for section headers
        if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$section" ]]; then
                in_section=true
            else
                in_section=false
            fi
            continue
        fi

        # Parse key=value pairs within the target section
        if [[ "$in_section" == true ]] && [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local parsed_key="${BASH_REMATCH[1]}"
            local parsed_value="${BASH_REMATCH[2]}"
            # Trim whitespace from key
            parsed_key="${parsed_key#"${parsed_key%%[![:space:]]*}"}"
            parsed_key="${parsed_key%"${parsed_key##*[![:space:]]}"}"
            if [[ "$parsed_key" == "$key" ]]; then
                echo "$parsed_value"
                return
            fi
        fi
    done < "$config_file"

    echo "$default"
}
# }}}

# -- {{{ load_external_directories
function load_external_directories() {
    # Loads and validates external directories from configuration
    # Outputs valid directory paths, one per line
    # Prints warnings to stderr for invalid directories if configured
    local config_file
    config_file="$(get_config_file_path)"

    if [[ ! -f "$config_file" ]]; then
        return
    fi

    local validate_paths
    local warn_missing
    validate_paths="$(get_config_setting "path_validation" "check_read_permissions" "true")"
    warn_missing="$(get_config_setting "path_validation" "warn_on_missing_directories" "true")"

    # Parse external_directories section
    local in_section=false
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Check for section headers
        if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "external_directories" ]]; then
                in_section=true
            else
                in_section=false
            fi
            continue
        fi

        # Parse name=path entries within external_directories section
        if [[ "$in_section" == true ]] && [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local path="${BASH_REMATCH[2]}"
            # Trim whitespace
            name="${name#"${name%%[![:space:]]*}"}"
            name="${name%"${name##*[![:space:]]}"}"
            path="${path#"${path%%[![:space:]]*}"}"
            path="${path%"${path##*[![:space:]]}"}"

            # Skip empty paths
            [[ -z "$path" ]] && continue

            # Validate directory exists and is accessible
            if [[ -d "$path" ]]; then
                if [[ "$validate_paths" == "true" ]] && [[ ! -r "$path" ]]; then
                    echo "Warning: External directory '$name' ($path) is not readable" >&2
                    continue
                fi
                echo "$path"
            else
                if [[ "$warn_missing" == "true" ]]; then
                    echo "Warning: External directory '$name' ($path) does not exist" >&2
                fi
            fi
        fi
    done < "$config_file"
}
# }}}

# -- {{{ get_all_project_directories
function get_all_project_directories() {
    # Discovers projects in both main and external directories
    # Arguments: output_format, include_external (true/false)
    local format="${1:-names}"
    local include_external="${2:-true}"

    local all_projects=()

    # Get main repository projects
    while IFS= read -r project; do
        [[ -n "$project" ]] && all_projects+=("$project")
    done < <(get_project_list_for_integration "abs-paths" "$DIR")

    # Get external projects if enabled
    if [[ "$include_external" == "true" ]]; then
        while IFS= read -r external_dir; do
            [[ -z "$external_dir" ]] && continue
            while IFS= read -r project; do
                [[ -n "$project" ]] && all_projects+=("$project")
            done < <(get_project_list_for_integration "abs-paths" "$external_dir")
        done < <(load_external_directories)
    fi

    # Output in requested format
    format_project_output "$format" "${all_projects[@]}"
}
# }}}

# -- {{{ get_external_projects_only
function get_external_projects_only() {
    # Discovers projects only in external directories (excludes main repository)
    # Arguments: output_format
    local format="${1:-names}"

    local external_projects=()

    while IFS= read -r external_dir; do
        [[ -z "$external_dir" ]] && continue
        while IFS= read -r project; do
            [[ -n "$project" ]] && external_projects+=("$project")
        done < <(get_project_list_for_integration "abs-paths" "$external_dir")
    done < <(load_external_directories)

    format_project_output "$format" "${external_projects[@]}"
}
# }}}

# -- {{{ list_external_directories
function list_external_directories() {
    # Lists all configured external directories with their status
    local config_file
    config_file="$(get_config_file_path)"

    echo "=== EXTERNAL PROJECT DIRECTORIES ==="
    echo "Config file: $config_file"
    echo

    if [[ ! -f "$config_file" ]]; then
        echo "  No configuration file found."
        echo "  Create one at: $config_file"
        return
    fi

    local found_any=false
    local in_section=false

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Check for section headers
        if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "external_directories" ]]; then
                in_section=true
            else
                in_section=false
            fi
            continue
        fi

        # Parse name=path entries
        if [[ "$in_section" == true ]] && [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local path="${BASH_REMATCH[2]}"
            # Trim whitespace
            name="${name#"${name%%[![:space:]]*}"}"
            name="${name%"${name##*[![:space:]]}"}"
            path="${path#"${path%%[![:space:]]*}"}"
            path="${path%"${path##*[![:space:]]}"}"

            [[ -z "$path" ]] && continue
            found_any=true

            if [[ -d "$path" ]]; then
                if [[ -r "$path" ]]; then
                    local project_count
                    project_count=$(get_project_list_for_integration "names" "$path" 2>/dev/null | wc -l)
                    echo "  [OK] $name"
                    echo "       Path: $path"
                    echo "       Projects: $project_count"
                else
                    echo "  [!!] $name"
                    echo "       Path: $path"
                    echo "       Status: Not readable"
                fi
            else
                echo "  [XX] $name"
                echo "       Path: $path"
                echo "       Status: Directory does not exist"
            fi
            echo
        fi
    done < "$config_file"

    if [[ "$found_any" == "false" ]]; then
        echo "  No external directories configured."
        echo "  Add entries to the [external_directories] section of:"
        echo "  $config_file"
    fi
}
# }}}

# -- {{{ add_external_directory
function add_external_directory() {
    # Adds a new external directory to the configuration
    # Arguments: name, path
    local name="$1"
    local path="$2"
    local config_file
    config_file="$(get_config_file_path)"

    # Validate arguments
    if [[ -z "$name" ]] || [[ -z "$path" ]]; then
        echo "Error: Both name and path are required" >&2
        echo "Usage: add_external_directory <name> <path>" >&2
        return 1
    fi

    # Validate path is absolute
    if [[ ! "$path" = /* ]]; then
        echo "Error: Path must be absolute (start with /)" >&2
        return 1
    fi

    # Validate directory exists
    if [[ ! -d "$path" ]]; then
        echo "Error: Directory '$path' does not exist" >&2
        return 1
    fi

    # Ensure config file exists
    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file not found at: $config_file" >&2
        echo "Please create the configuration file first." >&2
        return 1
    fi

    # Check if name already exists
    if grep -q "^$name=" "$config_file"; then
        echo "Error: External directory '$name' already exists" >&2
        echo "Use remove_external_directory first, or edit the config file directly." >&2
        return 1
    fi

    # Find the [external_directories] section and add the entry
    # We'll append after the section header or existing entries
    local temp_file
    temp_file=$(mktemp)
    local in_section=false
    local added=false

    while IFS= read -r line; do
        echo "$line" >> "$temp_file"

        if [[ "$line" =~ ^\[external_directories\]$ ]]; then
            in_section=true
        elif [[ "$in_section" == true ]] && [[ "$line" =~ ^\[.*\]$ ]]; then
            # We've reached a new section without adding, insert before it
            if [[ "$added" == false ]]; then
                # Remove the line we just added and insert our entry first
                head -n -1 "$temp_file" > "${temp_file}.new"
                echo "$name=$path" >> "${temp_file}.new"
                echo "$line" >> "${temp_file}.new"
                mv "${temp_file}.new" "$temp_file"
                added=true
            fi
            in_section=false
        fi
    done < "$config_file"

    # If we're still in the section at EOF, append the entry
    if [[ "$in_section" == true ]] && [[ "$added" == false ]]; then
        echo "$name=$path" >> "$temp_file"
        added=true
    fi

    if [[ "$added" == true ]]; then
        mv "$temp_file" "$config_file"
        echo "Added external directory: $name -> $path"
    else
        rm "$temp_file"
        echo "Error: Could not find [external_directories] section in config file" >&2
        return 1
    fi
}
# }}}

# -- {{{ remove_external_directory
function remove_external_directory() {
    # Removes an external directory from the configuration
    # Arguments: name
    local name="$1"
    local config_file
    config_file="$(get_config_file_path)"

    if [[ -z "$name" ]]; then
        echo "Error: Name is required" >&2
        echo "Usage: remove_external_directory <name>" >&2
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file not found" >&2
        return 1
    fi

    # Check if the entry exists
    if ! grep -q "^$name=" "$config_file"; then
        echo "Error: External directory '$name' not found in configuration" >&2
        return 1
    fi

    # Remove the entry (using sed with backup)
    sed -i.bak "/^$name=/d" "$config_file"
    echo "Removed external directory: $name"
    echo "Backup saved to: ${config_file}.bak"
}
# }}}

# -- {{{ validate_external_directories
function validate_external_directories() {
    # Validates all configured external directories
    echo "=== External Directory Validation ==="
    echo

    local config_file
    config_file="$(get_config_file_path)"

    if [[ ! -f "$config_file" ]]; then
        echo "No configuration file found at: $config_file"
        return 1
    fi

    local total=0
    local valid=0
    local invalid=0

    local in_section=false
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
            [[ "${BASH_REMATCH[1]}" == "external_directories" ]] && in_section=true || in_section=false
            continue
        fi

        if [[ "$in_section" == true ]] && [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local path="${BASH_REMATCH[2]}"
            name="${name#"${name%%[![:space:]]*}"}"
            name="${name%"${name##*[![:space:]]}"}"
            path="${path#"${path%%[![:space:]]*}"}"
            path="${path%"${path##*[![:space:]]}"}"

            [[ -z "$path" ]] && continue
            total=$((total + 1))

            echo "Checking: $name ($path)"

            if [[ ! -d "$path" ]]; then
                echo "  [FAIL] Directory does not exist"
                invalid=$((invalid + 1))
            elif [[ ! -r "$path" ]]; then
                echo "  [FAIL] Directory is not readable"
                invalid=$((invalid + 1))
            else
                local project_count
                project_count=$(get_project_list_for_integration "names" "$path" 2>/dev/null | wc -l)
                echo "  [PASS] Valid, contains $project_count projects"
                valid=$((valid + 1))
            fi
        fi
    done < "$config_file"

    echo
    echo "=== Summary ==="
    echo "Total directories: $total"
    echo "Valid: $valid"
    echo "Invalid: $invalid"

    [[ $invalid -eq 0 ]] && return 0 || return 1
}
# }}}

# -- {{{ run_external_management_mode
function run_external_management_mode() {
    # Interactive management interface for external directories
    echo "=== External Project Directory Management ==="
    echo
    echo "1. List configured external directories"
    echo "2. Add external directory"
    echo "3. Remove external directory"
    echo "4. Validate external directories"
    echo "5. Test external project discovery"
    echo "6. Show configuration file path"
    echo
    read -p "Select option [1-6]: " choice

    case $choice in
        1) list_external_directories ;;
        2)
            read -p "Enter directory name (symbolic): " name
            read -p "Enter directory path (absolute): " path
            add_external_directory "$name" "$path"
            ;;
        3)
            list_external_directories
            echo
            read -p "Enter directory name to remove: " name
            remove_external_directory "$name"
            ;;
        4) validate_external_directories ;;
        5)
            echo "External projects discovered:"
            echo
            get_external_projects_only "abs-paths"
            ;;
        6)
            echo "Configuration file: $(get_config_file_path)"
            ;;
        *) echo "Invalid selection" ;;
    esac
}
# }}}

# -- {{{ configure_exclusions_interactive
function configure_exclusions_interactive() {
    echo "=== Exclusion Configuration ==="
    echo "Current exclusion patterns:"
    define_non_project_directories
    for pattern in "${excluded_patterns[@]}"; do
        echo "  - $pattern"
    done
    echo
    echo "To modify exclusions, edit the define_non_project_directories function"
    echo "in $0"
}
# }}}

# -- {{{ run_interactive_mode
function run_interactive_mode() {
    echo "=== Project Listing Utility ==="
    echo "1. List project names"
    echo "2. List project absolute paths"
    echo "3. List non-project directories"
    echo "4. Export project list (JSON)"
    echo "5. Validate project detection"
    echo "6. Configure exclusions"
    
    read -p "Select option [1-6]: " choice
    
    case $choice in
        1) get_project_list_for_integration "names" "$DIR" ;;
        2) get_project_list_for_integration "abs-paths" "$DIR" ;;
        3) get_non_project_directories "names" "$DIR" ;;
        4) get_project_list_for_integration "json" "$DIR" ;;
        5) validate_project_detection ;;
        6) configure_exclusions_interactive ;;
        *) echo "Invalid selection" ;;
    esac
}
# }}}

# -- {{{ show_help
function show_help() {
    echo "Usage: list-projects.sh [OPTIONS] [DIRECTORY]"
    echo
    echo "Project Listing Utility for Delta-Version repository management."
    echo "Discovers and lists project directories with flexible output formats."
    echo
    echo "Output Format Options:"
    echo "  --names          Return project names only (default)"
    echo "  --abs-paths      Return absolute paths"
    echo "  --rel-paths      Return relative paths"
    echo "  --format FORMAT  Output format: names|abs-paths|rel-paths|json|csv|lines"
    echo
    echo "Filtering Options:"
    echo "  --inverse        Return non-project directories instead"
    echo "  --include-libs   Include library directories (normally excluded)"
    echo
    echo "External Directory Options:"
    echo "  --include-external   Include external project directories (default)"
    echo "  --exclude-external   Only search main repository directory"
    echo "  --external-only      Only search external directories"
    echo "  --list-external      List configured external directories"
    echo "  --manage-external    Interactive external directory management"
    echo "  --validate-external  Validate all external directory configurations"
    echo
    echo "General Options:"
    echo "  -I, --interactive    Interactive mode for project listing"
    echo "  --help               Show this help message"
    echo
    echo "Configuration:"
    echo "  External directories are configured in:"
    echo "    \$DELTA_CONFIG_DIR/external-projects.conf"
    echo "  or by default in:"
    echo "    <script-dir>/../config/external-projects.conf"
    echo
    echo "Examples:"
    echo "  list-projects.sh --names"
    echo "  list-projects.sh --format json /path/to/repo"
    echo "  list-projects.sh --inverse --abs-paths"
    echo "  list-projects.sh --external-only --abs-paths"
    echo "  list-projects.sh --exclude-external --names"
    echo "  list-projects.sh --manage-external"
}
# }}}

# -- {{{ main
function main() {
    local output_format="names"
    local base_directory="$DIR"
    local inverse_mode=false
    local include_libs=false
    # External directory options - check config for default include behavior
    local include_external
    include_external="$(get_config_setting "settings" "include_in_default_listings" "true")"
    local external_only=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --names)
                output_format="names"
                shift
                ;;
            --abs-paths)
                output_format="abs-paths"
                shift
                ;;
            --rel-paths)
                output_format="rel-paths"
                shift
                ;;
            --format)
                output_format="$2"
                shift 2
                ;;
            --inverse)
                inverse_mode=true
                shift
                ;;
            --include-libs)
                include_libs=true
                shift
                ;;
            # External directory options (Issue 024)
            --include-external)
                include_external=true
                shift
                ;;
            --exclude-external)
                include_external=false
                shift
                ;;
            --external-only)
                external_only=true
                include_external=true
                shift
                ;;
            --list-external)
                list_external_directories
                exit 0
                ;;
            --manage-external)
                run_external_management_mode
                exit 0
                ;;
            --validate-external)
                validate_external_directories
                exit $?
                ;;
            -I|--interactive)
                run_interactive_mode
                exit 0
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                if [[ -d "$1" ]]; then
                    base_directory="$1"
                else
                    echo "Error: Directory '$1' does not exist" >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Handle different listing modes
    if [[ "$external_only" == "true" ]]; then
        # Only list projects from external directories
        get_external_projects_only "$output_format"
    elif [[ "$inverse_mode" == "true" ]]; then
        # List non-project directories (external support not applicable here)
        get_non_project_directories "$output_format" "$base_directory"
    elif [[ "$include_external" == "true" ]]; then
        # List all projects including external directories
        get_all_project_directories "$output_format" "true"
    else
        # List only main repository projects
        get_project_list_for_integration "$output_format" "$base_directory"
    fi
}
# }}}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi