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
    echo "Options:"
    echo "  --names          Return project names only (default)"
    echo "  --abs-paths      Return absolute paths"
    echo "  --rel-paths      Return relative paths"
    echo "  --format FORMAT  Output format: names|abs-paths|rel-paths|json|csv|lines"
    echo "  --inverse        Return non-project directories instead"
    echo "  --include-libs   Include library directories (normally excluded)"
    echo "  -I, --interactive Interactive mode"
    echo "  --help           Show this help message"
    echo
    echo "Examples:"
    echo "  list-projects.sh --names"
    echo "  list-projects.sh --format json /path/to/repo"
    echo "  list-projects.sh --inverse --abs-paths"
}
# }}}

# -- {{{ main
function main() {
    local output_format="names"
    local base_directory="$DIR"
    local inverse_mode=false
    local include_libs=false
    
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
    
    if [[ "$inverse_mode" == "true" ]]; then
        get_non_project_directories "$output_format" "$base_directory"
    else
        get_project_list_for_integration "$output_format" "$base_directory"
    fi
}
# }}}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi