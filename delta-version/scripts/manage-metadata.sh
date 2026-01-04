#!/bin/bash
# Project Metadata Management Utility
# Discovers, aggregates, validates, and queries project.meta.json files across the monorepo.
# Projects must explicitly declare metadata - no automatic detection or fallback.

# Default base directory - can be overridden with positional argument
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_FILE="${SCRIPT_DIR}/../assets/metadata-cache.json"

# -- {{{ show_help
show_help() {
    cat << 'EOF'
Usage: manage-metadata.sh [COMMAND] [OPTIONS]

Commands:
  list              List all projects with metadata (default)
  validate          Validate metadata files
  show PROJECT      Show metadata for a specific project
  stats             Show aggregate statistics
  init PROJECT      Create a minimal project.meta.json template

Options:
  --status=STATUS   Filter by status (active, maintenance, experimental, archived)
  --language=LANG   Filter by language
  --tag=TAG         Filter by tag
  --format=FORMAT   Output format: names (default), table, json, paths
  --all             Apply to all projects (for validate)
  --refresh         Rebuild metadata cache
  --help            Show this help message

Examples:
  manage-metadata.sh list
  manage-metadata.sh list --status=active --format=table
  manage-metadata.sh list --language=lua
  manage-metadata.sh validate --all
  manage-metadata.sh show delta-version
  manage-metadata.sh stats
  manage-metadata.sh init my-new-project
EOF
}
# }}}

# -- {{{ discover_metadata_files
# Finds all project.meta.json files in the monorepo
discover_metadata_files() {
    local base_dir="$1"
    find "$base_dir" -maxdepth 2 -name "project.meta.json" -type f 2>/dev/null | sort
}
# }}}

# -- {{{ validate_single_metadata
# Validates a single project.meta.json file
# Returns 0 if valid, 1 if invalid
validate_single_metadata() {
    local meta_file="$1"
    local project_dir
    project_dir=$(dirname "$meta_file")
    local project_name
    project_name=$(basename "$project_dir")
    local errors=()

    # Check JSON syntax
    if ! jq empty "$meta_file" 2>/dev/null; then
        errors+=("Invalid JSON syntax")
    else
        # Check required fields
        local name status
        name=$(jq -r '.name // empty' "$meta_file")
        status=$(jq -r '.status // empty' "$meta_file")

        if [[ -z "$name" ]]; then
            errors+=("Missing required field: name")
        fi

        if [[ -z "$status" ]]; then
            errors+=("Missing required field: status")
        elif [[ ! "$status" =~ ^(active|maintenance|experimental|archived)$ ]]; then
            errors+=("Invalid status value: $status (must be active, maintenance, experimental, or archived)")
        fi
    fi

    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "INVALID: $project_name"
        for err in "${errors[@]}"; do
            echo "  - $err"
        done
        return 1
    else
        echo "VALID: $project_name"
        return 0
    fi
}
# }}}

# -- {{{ build_cache
# Builds aggregated metadata cache
build_cache() {
    local base_dir="$1"
    local output_file="$2"

    echo "Building metadata cache..."

    local projects_json="[]"
    local count=0

    while IFS= read -r meta_file; do
        if jq empty "$meta_file" 2>/dev/null; then
            local project_dir
            project_dir=$(dirname "$meta_file")
            local path
            path=$(realpath "$project_dir")

            # Add path to the metadata object
            local entry
            entry=$(jq --arg path "$path" '. + {path: $path}' "$meta_file")
            projects_json=$(echo "$projects_json" | jq --argjson entry "$entry" '. + [$entry]')
            ((count++))
        fi
    done < <(discover_metadata_files "$base_dir")

    # Write cache
    mkdir -p "$(dirname "$output_file")"
    echo "$projects_json" | jq '{
        generated: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
        count: (. | length),
        projects: .
    }' > "$output_file"

    echo "Cached $count projects to $output_file"
}
# }}}

# -- {{{ load_or_build_cache
# Loads cache if fresh, otherwise rebuilds
load_or_build_cache() {
    local base_dir="$1"
    local force_refresh="$2"

    if [[ "$force_refresh" == "true" ]] || [[ ! -f "$CACHE_FILE" ]]; then
        build_cache "$base_dir" "$CACHE_FILE" >&2
    fi

    cat "$CACHE_FILE"
}
# }}}

# -- {{{ filter_projects
# Applies filters to project list
filter_projects() {
    local json="$1"
    local status_filter="$2"
    local language_filter="$3"
    local tag_filter="$4"

    local result
    result=$(echo "$json" | jq '.projects')

    if [[ -n "$status_filter" ]]; then
        result=$(echo "$result" | jq --arg s "$status_filter" '[.[] | select(.status == $s)]')
    fi

    if [[ -n "$language_filter" ]]; then
        result=$(echo "$result" | jq --arg l "$language_filter" '[.[] | select(
            (.language == $l) or
            ((.language | type) == "array" and (.language | contains([$l])))
        )]')
    fi

    if [[ -n "$tag_filter" ]]; then
        result=$(echo "$result" | jq --arg t "$tag_filter" '[.[] | select(
            (.tags | type) == "array" and (.tags | contains([$t]))
        )]')
    fi

    echo "$result"
}
# }}}

# -- {{{ format_output_names
format_output_names() {
    local json="$1"
    echo "$json" | jq -r '.[].name'
}
# }}}

# -- {{{ format_output_paths
format_output_paths() {
    local json="$1"
    echo "$json" | jq -r '.[].path'
}
# }}}

# -- {{{ format_output_table
format_output_table() {
    local json="$1"

    # Print header
    printf "%-25s %-15s %-15s %s\n" "NAME" "STATUS" "LANGUAGE" "TAGS"
    printf "%-25s %-15s %-15s %s\n" "----" "------" "--------" "----"

    # Print rows
    echo "$json" | jq -r '.[] | [
        .name,
        .status,
        (if (.language | type) == "array" then (.language | join(",")) else (.language // "-") end),
        (if (.tags | type) == "array" then (.tags | join(",")) else "-" end)
    ] | @tsv' | while IFS=$'\t' read -r name status lang tags; do
        printf "%-25s %-15s %-15s %s\n" "$name" "$status" "$lang" "$tags"
    done
}
# }}}

# -- {{{ format_output_json
format_output_json() {
    local json="$1"
    echo "$json" | jq '.'
}
# }}}

# -- {{{ cmd_list
cmd_list() {
    local base_dir="$1"
    local status_filter="$2"
    local language_filter="$3"
    local tag_filter="$4"
    local format="$5"
    local refresh="$6"

    local cache
    cache=$(load_or_build_cache "$base_dir" "$refresh")

    local filtered
    filtered=$(filter_projects "$cache" "$status_filter" "$language_filter" "$tag_filter")

    case "$format" in
        names)
            format_output_names "$filtered"
            ;;
        paths)
            format_output_paths "$filtered"
            ;;
        table)
            format_output_table "$filtered"
            ;;
        json)
            format_output_json "$filtered"
            ;;
        *)
            format_output_names "$filtered"
            ;;
    esac
}
# }}}

# -- {{{ cmd_validate
cmd_validate() {
    local base_dir="$1"
    local target="$2"
    local all_mode="$3"

    local valid_count=0
    local invalid_count=0

    if [[ "$all_mode" == "true" ]]; then
        echo "=== Validating All Metadata Files ==="
        echo

        while IFS= read -r meta_file; do
            if validate_single_metadata "$meta_file"; then
                ((valid_count++))
            else
                ((invalid_count++))
            fi
        done < <(discover_metadata_files "$base_dir")

        echo
        echo "=== Summary ==="
        echo "Valid: $valid_count"
        echo "Invalid: $invalid_count"

        [[ $invalid_count -eq 0 ]] && return 0 || return 1
    elif [[ -n "$target" ]]; then
        local meta_file
        if [[ -f "$target/project.meta.json" ]]; then
            meta_file="$target/project.meta.json"
        elif [[ -f "$base_dir/$target/project.meta.json" ]]; then
            meta_file="$base_dir/$target/project.meta.json"
        else
            echo "ERROR: No project.meta.json found for '$target'"
            return 1
        fi
        validate_single_metadata "$meta_file"
    else
        echo "ERROR: Specify a project or use --all"
        return 1
    fi
}
# }}}

# -- {{{ cmd_show
cmd_show() {
    local base_dir="$1"
    local project="$2"

    local meta_file
    if [[ -f "$project/project.meta.json" ]]; then
        meta_file="$project/project.meta.json"
    elif [[ -f "$base_dir/$project/project.meta.json" ]]; then
        meta_file="$base_dir/$project/project.meta.json"
    else
        echo "ERROR: No project.meta.json found for '$project'"
        return 1
    fi

    echo "=== $project ==="
    jq '.' "$meta_file"
}
# }}}

# -- {{{ cmd_stats
cmd_stats() {
    local base_dir="$1"
    local refresh="$2"

    local cache
    cache=$(load_or_build_cache "$base_dir" "$refresh")

    echo "=== Metadata Statistics ==="
    echo

    local total
    total=$(echo "$cache" | jq '.count')
    echo "Total projects with metadata: $total"
    echo

    echo "By Status:"
    echo "$cache" | jq -r '.projects | group_by(.status) | .[] | "  \(.[0].status): \(length)"'
    echo

    echo "By Language:"
    echo "$cache" | jq -r '
        [.projects[].language] |
        flatten |
        map(select(. != null)) |
        group_by(.) |
        .[] |
        "  \(.[0]): \(length)"
    '
    echo

    echo "By Tag (top 10):"
    echo "$cache" | jq -r '
        [.projects[].tags] |
        flatten |
        map(select(. != null)) |
        group_by(.) |
        sort_by(-length) |
        .[:10] |
        .[] |
        "  \(.[0]): \(length)"
    '
}
# }}}

# -- {{{ cmd_init
cmd_init() {
    local base_dir="$1"
    local project="$2"

    local project_dir
    if [[ -d "$project" ]]; then
        project_dir="$project"
    elif [[ -d "$base_dir/$project" ]]; then
        project_dir="$base_dir/$project"
    else
        echo "ERROR: Project directory not found: $project"
        return 1
    fi

    local meta_file="$project_dir/project.meta.json"
    local project_name
    project_name=$(basename "$project_dir")

    if [[ -f "$meta_file" ]]; then
        echo "ERROR: $meta_file already exists"
        return 1
    fi

    cat > "$meta_file" << EOF
{
  "name": "$project_name",
  "status": "active"
}
EOF

    echo "Created: $meta_file"
    echo "Edit to add optional fields (description, language, tags, etc.)"
}
# }}}

# -- {{{ main
main() {
    local command=""
    local base_dir="$DIR"
    local status_filter=""
    local language_filter=""
    local tag_filter=""
    local format="names"
    local all_mode="false"
    local refresh="false"
    local target=""

    # Parse first positional argument as directory override if it exists
    if [[ -d "$1" ]]; then
        base_dir="$1"
        shift
    fi

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            list|validate|show|stats|init)
                command="$1"
                shift
                ;;
            --status=*)
                status_filter="${1#*=}"
                shift
                ;;
            --language=*)
                language_filter="${1#*=}"
                shift
                ;;
            --tag=*)
                tag_filter="${1#*=}"
                shift
                ;;
            --format=*)
                format="${1#*=}"
                shift
                ;;
            --all)
                all_mode="true"
                shift
                ;;
            --refresh)
                refresh="true"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                # Remaining positional args
                if [[ -z "$target" ]]; then
                    target="$1"
                fi
                shift
                ;;
        esac
    done

    # Default command
    [[ -z "$command" ]] && command="list"

    # Execute command
    case "$command" in
        list)
            cmd_list "$base_dir" "$status_filter" "$language_filter" "$tag_filter" "$format" "$refresh"
            ;;
        validate)
            cmd_validate "$base_dir" "$target" "$all_mode"
            ;;
        show)
            if [[ -z "$target" ]]; then
                echo "ERROR: show requires a project name"
                exit 1
            fi
            cmd_show "$base_dir" "$target"
            ;;
        stats)
            cmd_stats "$base_dir" "$refresh"
            ;;
        init)
            if [[ -z "$target" ]]; then
                echo "ERROR: init requires a project name"
                exit 1
            fi
            cmd_init "$base_dir" "$target"
            ;;
        *)
            echo "ERROR: Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}
# }}}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
