#!/usr/bin/env bash
# visualize-deps.sh - Dependency visualization and branch topology analysis tool
#
# Generates ASCII tree diagrams, DOT graphs for Graphviz, and provides impact
# analysis queries for issue dependencies. Reuses dependency parsing logic from
# reconstruct-history.sh (Issue 035b).

set -euo pipefail

# -- {{{ Configuration
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Runtime options
PROJECT_DIR=""
OUTPUT_FORMAT="ascii"      # ascii, dot, json
QUERY_MODE=""              # blocks, depends, parallel, roots
QUERY_TARGET=""
INCLUDE_PENDING=true       # Include non-completed issues by default
INCLUDE_COMPLETED=true     # Include completed issues
INTERACTIVE=false
VERBOSE=false
# }}}

# -- {{{ log
log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[INFO] $*" >&2
    fi
}
# }}}

# -- {{{ error
error() {
    echo "[ERROR] $*" >&2
}
# }}}

# =============================================================================
# Dependency Parsing Functions (adapted from reconstruct-history.sh Issue 035b)
# =============================================================================

# -- {{{ extract_issue_id
extract_issue_id() {
    local issue_file="$1"
    local basename
    basename=$(basename "$issue_file" .md)

    # Extract issue ID pattern: 001, 023a, 035b, etc.
    # Also handle PRIORITY.md, progress.md, CLAUDE.md etc. (no match)
    if [[ "$basename" =~ ^([0-9]{3}[a-z]?) ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}
# }}}

# -- {{{ extract_issue_title
extract_issue_title() {
    local issue_file="$1"
    local title=""

    # Try to extract title from first heading
    # Format: # Issue 001: Title Here
    title=$(grep -m1 '^# ' "$issue_file" 2>/dev/null | sed 's/^# Issue [0-9]*[a-z]*: //' | cut -c1-40)

    # If no title found, use basename
    if [[ -z "$title" ]]; then
        title=$(basename "$issue_file" .md)
    fi

    echo "$title"
}
# }}}

# -- {{{ parse_issue_dependencies
parse_issue_dependencies() {
    local issue_file="$1"
    local -a all_refs=()

    # Extract Dependencies field (e.g., "Dependencies: 001, 002, 003")
    local deps
    deps=$(grep -iE '^[-*]?\s*\*?\*?Dependencies\*?\*?\s*:' "$issue_file" 2>/dev/null | \
           sed 's/.*:\s*//' | tr ',' ' ') || true

    # Extract Blocked By field
    local blocked_by
    blocked_by=$(grep -iE '^[-*]?\s*\*?\*?Blocked\s*By\*?\*?\s*:' "$issue_file" 2>/dev/null | \
                 sed 's/.*:\s*//' | tr ',' ' ') || true

    # Combine and extract issue numbers (003, 023a, etc.)
    local combined="$deps $blocked_by"

    # Match issue numbers: 001, 023, 035a, Issue 001, #001, etc.
    while read -r ref; do
        [[ -n "$ref" ]] && all_refs+=("$ref")
    done < <(echo "$combined" | grep -oE '([0-9]{3}[a-z]?)' | sort -u)

    # Output space-separated list
    echo "${all_refs[*]}"
}
# }}}

# -- {{{ parse_issue_blocks
parse_issue_blocks() {
    local issue_file="$1"
    local -a all_refs=()

    # Extract Blocks field (issues that THIS issue blocks)
    local blocks
    blocks=$(grep -iE '^[-*]?\s*\*?\*?Blocks\*?\*?\s*:' "$issue_file" 2>/dev/null | \
             sed 's/.*:\s*//' | tr ',' ' ') || true

    # Match issue numbers
    while read -r ref; do
        [[ -n "$ref" ]] && all_refs+=("$ref")
    done < <(echo "$blocks" | grep -oE '([0-9]{3}[a-z]?)' | sort -u)

    echo "${all_refs[*]}"
}
# }}}

# -- {{{ get_issue_status
get_issue_status() {
    local issue_file="$1"

    # Check if file is in completed directory
    if [[ "$issue_file" == *"/completed/"* ]]; then
        echo "completed"
        return
    fi

    # Check status field in file
    local status
    status=$(grep -iE '^\*?\*?Status\*?\*?\s*:' "$issue_file" 2>/dev/null | head -1 | sed 's/.*:\s*//' | tr '[:upper:]' '[:lower:]') || true

    if [[ "$status" == *"complete"* ]] || [[ "$status" == *"done"* ]]; then
        echo "completed"
    elif [[ "$status" == *"progress"* ]] || [[ "$status" == *"active"* ]]; then
        echo "in_progress"
    else
        echo "pending"
    fi
}
# }}}

# =============================================================================
# Graph Building
# =============================================================================

# -- {{{ collect_issue_files
collect_issue_files() {
    local project_dir="$1"
    local issues_dir="$project_dir/issues"

    if [[ ! -d "$issues_dir" ]]; then
        error "Issues directory not found: $issues_dir"
        return 1
    fi

    # Collect pending issues
    if [[ "$INCLUDE_PENDING" == true ]]; then
        find "$issues_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null || true
    fi

    # Collect completed issues
    if [[ "$INCLUDE_COMPLETED" == true ]] && [[ -d "$issues_dir/completed" ]]; then
        find "$issues_dir/completed" -maxdepth 1 -name "*.md" -type f 2>/dev/null || true
    fi
}
# }}}

# -- {{{ build_dependency_graph
build_dependency_graph() {
    local project_dir="$1"

    declare -A graph       # issue_id -> space-separated dependencies
    declare -A all_issues  # issue_id -> file_path
    declare -A titles      # issue_id -> title
    declare -A statuses    # issue_id -> status

    # Collect all issue files
    while IFS= read -r issue_file; do
        [[ -z "$issue_file" ]] && continue
        [[ ! -f "$issue_file" ]] && continue

        local issue_id
        issue_id=$(extract_issue_id "$issue_file")
        [[ -z "$issue_id" ]] && continue

        all_issues["$issue_id"]="$issue_file"
        titles["$issue_id"]=$(extract_issue_title "$issue_file")
        statuses["$issue_id"]=$(get_issue_status "$issue_file")

        # Get dependencies
        local deps
        deps=$(parse_issue_dependencies "$issue_file")
        graph["$issue_id"]="$deps"

        log "  $issue_id depends on: ${deps:-none}"
    done < <(collect_issue_files "$project_dir")

    # Process "Blocks" relationships (reverse direction)
    for issue_id in "${!all_issues[@]}"; do
        local issue_file="${all_issues[$issue_id]}"
        local blocks
        blocks=$(parse_issue_blocks "$issue_file")

        for blocked_id in $blocks; do
            # Add this issue as a dependency of the blocked issue
            if [[ -n "${graph[$blocked_id]:-}" ]]; then
                if ! echo " ${graph[$blocked_id]} " | grep -q " $issue_id "; then
                    graph["$blocked_id"]="${graph[$blocked_id]} $issue_id"
                fi
            else
                graph["$blocked_id"]="$issue_id"
            fi
            log "  $blocked_id depends on $issue_id (via Blocks field)"
        done
    done

    # Output graph as lines: "issue_id:deps:title:status"
    for issue_id in "${!all_issues[@]}"; do
        echo "$issue_id:${graph[$issue_id]:-}:${titles[$issue_id]}:${statuses[$issue_id]}"
    done | sort -t: -k1 -V
}
# }}}

# =============================================================================
# ASCII Tree Visualization
# =============================================================================

# Global arrays for tree rendering (bash nested functions need global scope)
declare -A _tree_deps_map
declare -A _tree_title_map
declare -A _tree_status_map
declare -A _tree_children_map
declare -A _tree_printed

# -- {{{ _print_tree_node
_print_tree_node() {
    local node="$1"
    local prefix="$2"
    local is_last="$3"

    # Skip if already printed (handles diamond dependencies)
    if [[ -n "${_tree_printed[$node]:-}" ]]; then
        local connector="├──"
        [[ "$is_last" == true ]] && connector="└──"
        printf "%s%s %s (see above)\n" "$prefix" "$connector" "$node"
        return
    fi
    _tree_printed["$node"]=1

    # Status indicator
    local status_char="○"
    case "${_tree_status_map[$node]:-pending}" in
        completed) status_char="✓" ;;
        in_progress) status_char="▶" ;;
    esac

    # Connector character
    local connector="├──"
    [[ "$is_last" == true ]] && connector="└──"

    # Print node
    local title="${_tree_title_map[$node]:-}"
    [[ ${#title} -gt 35 ]] && title="${title:0:32}..."

    printf "%s%s %s %s" "$prefix" "$connector" "$status_char" "$node"
    [[ -n "$title" ]] && printf " (%s)" "$title"
    echo ""

    # Get and sort children
    local -a children=()
    for child in ${_tree_children_map[$node]:-}; do
        children+=("$child")
    done

    # Handle empty children array for sort
    if [[ ${#children[@]} -gt 0 ]]; then
        mapfile -t children < <(printf '%s\n' "${children[@]}" | sort -V)
    fi

    # Calculate child prefix
    local child_prefix="$prefix"
    [[ "$is_last" == true ]] && child_prefix+="    " || child_prefix+="│   "

    # Print children
    local i=0
    local child_count=${#children[@]}
    for child in "${children[@]}"; do
        i=$((i + 1))
        local child_is_last=false
        [[ $i -eq $child_count ]] && child_is_last=true
        _print_tree_node "$child" "$child_prefix" "$child_is_last"
    done
}
# }}}

# -- {{{ generate_ascii_tree
generate_ascii_tree() {
    local project_dir="$1"

    # Clear global arrays
    _tree_deps_map=()
    _tree_title_map=()
    _tree_status_map=()
    _tree_children_map=()
    _tree_printed=()

    local -a all_ids=()
    local -a root_ids=()

    # Parse graph output
    while IFS=':' read -r id deps title status; do
        [[ -z "$id" ]] && continue
        all_ids+=("$id")
        _tree_deps_map["$id"]="$deps"
        _tree_title_map["$id"]="$title"
        _tree_status_map["$id"]="$status"
        _tree_children_map["$id"]=""
    done < <(build_dependency_graph "$project_dir")

    # Build children map (reverse relationships)
    for id in "${all_ids[@]}"; do
        for dep in ${_tree_deps_map[$id]}; do
            # dep is a parent of id (id depends on dep)
            if [[ -n "${_tree_children_map[$dep]:-}" ]]; then
                _tree_children_map["$dep"]="${_tree_children_map[$dep]} $id"
            else
                _tree_children_map["$dep"]="$id"
            fi
        done
    done

    # Find roots (issues with no dependencies)
    for id in "${all_ids[@]}"; do
        if [[ -z "${_tree_deps_map[$id]}" ]]; then
            root_ids+=("$id")
        fi
    done

    # Sort roots (handle empty array)
    if [[ ${#root_ids[@]} -gt 0 ]]; then
        mapfile -t root_ids < <(printf '%s\n' "${root_ids[@]}" | sort -V)
    fi

    echo "Project Dependency Tree: $(basename "$project_dir")"
    echo "========================================"
    echo ""
    echo "Legend: ✓ completed, ▶ in_progress, ○ pending"
    echo ""

    # Print from each root
    local i=0
    local root_count=${#root_ids[@]}
    for root in "${root_ids[@]}"; do
        i=$((i + 1))
        local is_last=false
        [[ $i -eq $root_count ]] && is_last=true
        _print_tree_node "$root" "" "$is_last"
    done

    echo ""
    echo "Total: ${#all_ids[@]} issues (${#root_ids[@]} roots)"
}
# }}}

# =============================================================================
# DOT Format Export
# =============================================================================

# -- {{{ generate_dot_graph
generate_dot_graph() {
    local project_dir="$1"

    echo "digraph dependencies {"
    echo "  rankdir=TB;"
    echo "  node [shape=box, style=rounded, fontname=\"Helvetica\"];"
    echo "  edge [arrowhead=vee];"
    echo ""

    # Status colors
    echo "  // Status-based styling"
    echo "  node [fillstyle=filled];"
    echo ""

    declare -A deps_map
    declare -A title_map
    declare -A status_map
    declare -a all_ids=()

    # Parse graph
    while IFS=':' read -r id deps title status; do
        [[ -z "$id" ]] && continue
        all_ids+=("$id")
        deps_map["$id"]="$deps"
        title_map["$id"]="$title"
        status_map["$id"]="$status"
    done < <(build_dependency_graph "$project_dir")

    # Output nodes with styling
    for id in "${all_ids[@]}"; do
        local title="${title_map[$id]:-}"
        [[ ${#title} -gt 25 ]] && title="${title:0:22}..."

        local color="white"
        local style="filled"
        case "${status_map[$id]:-pending}" in
            completed) color="\"#90EE90\"" ;;      # light green
            in_progress) color="\"#FFE4B5\"" ;;    # moccasin/orange
            pending) color="\"#E0E0E0\"" ;;        # light gray
        esac

        # Escape quotes in title
        title="${title//\"/\\\"}"

        echo "  \"$id\" [label=\"$id\\n$title\", fillcolor=$color, style=$style];"
    done

    echo ""
    echo "  // Dependencies (edges)"

    # Output edges
    for id in "${all_ids[@]}"; do
        for dep in ${deps_map[$id]:-}; do
            echo "  \"$dep\" -> \"$id\";"
        done
    done

    echo "}"
}
# }}}

# =============================================================================
# JSON Format Export
# =============================================================================

# -- {{{ generate_json_graph
generate_json_graph() {
    local project_dir="$1"

    declare -A deps_map
    declare -A title_map
    declare -A status_map
    declare -a all_ids=()

    while IFS=':' read -r id deps title status; do
        [[ -z "$id" ]] && continue
        all_ids+=("$id")
        deps_map["$id"]="$deps"
        title_map["$id"]="$title"
        status_map["$id"]="$status"
    done < <(build_dependency_graph "$project_dir")

    echo "{"
    echo "  \"project\": \"$(basename "$project_dir")\","
    echo "  \"issues\": ["

    local i=0
    local count=${#all_ids[@]}
    for id in "${all_ids[@]}"; do
        i=$((i + 1))
        local title="${title_map[$id]:-}"
        title="${title//\"/\\\"}"
        local deps="${deps_map[$id]:-}"
        local status="${status_map[$id]:-pending}"

        # Format dependencies as JSON array
        local deps_json="[]"
        if [[ -n "$deps" ]]; then
            deps_json="[$(echo "$deps" | sed 's/[[:space:]]\+/, /g' | sed 's/\([0-9a-z]\+\)/"\1"/g')]"
        fi

        local comma=","
        [[ $i -eq $count ]] && comma=""

        echo "    {"
        echo "      \"id\": \"$id\","
        echo "      \"title\": \"$title\","
        echo "      \"status\": \"$status\","
        echo "      \"dependencies\": $deps_json"
        echo "    }$comma"
    done

    echo "  ]"
    echo "}"
}
# }}}

# =============================================================================
# Impact Analysis Queries
# =============================================================================

# -- {{{ query_blocks
query_blocks() {
    local project_dir="$1"
    local target="$2"

    declare -A deps_map
    declare -A title_map
    declare -a all_ids=()

    while IFS=':' read -r id deps title status; do
        [[ -z "$id" ]] && continue
        all_ids+=("$id")
        deps_map["$id"]="$deps"
        title_map["$id"]="$title"
    done < <(build_dependency_graph "$project_dir")

    echo "Issues blocked by $target:"
    echo ""

    # Find direct blocks (issues that depend on target)
    local -a direct=()
    for id in "${all_ids[@]}"; do
        if echo " ${deps_map[$id]:-} " | grep -q " $target "; then
            direct+=("$id")
        fi
    done

    if [[ ${#direct[@]} -eq 0 ]]; then
        echo "  (none - $target doesn't block any issues)"
        return
    fi

    echo "  Direct: ${direct[*]}"

    # Find transitive blocks (BFS)
    local -a queue=("${direct[@]}")
    local -A visited
    local -a transitive=()

    for d in "${direct[@]}"; do
        visited["$d"]=1
    done

    while [[ ${#queue[@]} -gt 0 ]]; do
        local current="${queue[0]}"
        queue=("${queue[@]:1}")

        for id in "${all_ids[@]}"; do
            if [[ -z "${visited[$id]:-}" ]] && echo " ${deps_map[$id]:-} " | grep -q " $current "; then
                visited["$id"]=1
                queue+=("$id")
                transitive+=("$id")
            fi
        done
    done

    if [[ ${#transitive[@]} -gt 0 ]]; then
        echo "  Transitive: ${transitive[*]}"
    fi

    echo ""
    echo "  Total impact: $((${#direct[@]} + ${#transitive[@]})) issues"
}
# }}}

# -- {{{ query_depends
query_depends() {
    local project_dir="$1"
    local target="$2"

    declare -A deps_map
    declare -A title_map

    while IFS=':' read -r id deps title status; do
        [[ -z "$id" ]] && continue
        deps_map["$id"]="$deps"
        title_map["$id"]="$title"
    done < <(build_dependency_graph "$project_dir")

    if [[ -z "${deps_map[$target]+isset}" ]]; then
        echo "Issue $target not found"
        return 1
    fi

    echo "Dependency chain for $target:"
    echo ""

    # Build chain recursively (DFS)
    local -a chain=()
    local -A visited

    build_chain() {
        local node="$1"
        [[ -n "${visited[$node]:-}" ]] && return
        visited["$node"]=1

        for dep in ${deps_map[$node]:-}; do
            build_chain "$dep"
        done
        chain+=("$node")
    }

    build_chain "$target"

    # Print chain
    local IFS=" → "
    echo "  ${chain[*]}"
    echo ""
    echo "  Depth: ${#chain[@]} issues in chain"
}
# }}}

# -- {{{ query_parallel
query_parallel() {
    local project_dir="$1"

    declare -A deps_map
    declare -A title_map
    declare -A status_map
    declare -a all_ids=()

    while IFS=':' read -r id deps title status; do
        [[ -z "$id" ]] && continue
        all_ids+=("$id")
        deps_map["$id"]="$deps"
        title_map["$id"]="$title"
        status_map["$id"]="$status"
    done < <(build_dependency_graph "$project_dir")

    echo "Parallel Work Opportunities"
    echo "==========================="
    echo ""

    # Calculate depths using BFS from roots
    declare -A depths
    local -a queue=()

    # Find roots and set depth 0
    for id in "${all_ids[@]}"; do
        if [[ -z "${deps_map[$id]}" ]]; then
            depths["$id"]=0
            queue+=("$id")
        fi
    done

    # BFS to calculate depths
    while [[ ${#queue[@]} -gt 0 ]]; do
        local current="${queue[0]}"
        queue=("${queue[@]:1}")
        local current_depth="${depths[$current]}"

        for id in "${all_ids[@]}"; do
            if echo " ${deps_map[$id]:-} " | grep -q " $current "; then
                local new_depth=$((current_depth + 1))
                if [[ -z "${depths[$id]:-}" ]] || [[ $new_depth -gt ${depths[$id]} ]]; then
                    depths["$id"]=$new_depth
                    queue+=("$id")
                fi
            fi
        done
    done

    # Group by depth and filter out completed
    declare -A by_depth
    local max_depth=0

    for id in "${all_ids[@]}"; do
        local depth="${depths[$id]:-0}"
        local status="${status_map[$id]:-pending}"

        # Skip completed issues for parallel work analysis
        [[ "$status" == "completed" ]] && continue

        by_depth["$depth"]="${by_depth[$depth]:-} $id"
        [[ $depth -gt $max_depth ]] && max_depth=$depth
    done

    # Print by depth
    for ((d=0; d<=max_depth; d++)); do
        local ids="${by_depth[$d]:-}"
        [[ -z "$ids" ]] && continue

        local label="Depth $d"
        [[ $d -eq 0 ]] && label="No dependencies (can start now)"

        echo "$label:"
        for id in $ids; do
            local title="${title_map[$id]:-}"
            [[ ${#title} -gt 40 ]] && title="${title:0:37}..."
            printf "  • %s: %s\n" "$id" "$title"
        done
        echo ""
    done
}
# }}}

# -- {{{ query_roots
query_roots() {
    local project_dir="$1"

    declare -A deps_map
    declare -A title_map
    declare -A status_map
    declare -a all_ids=()

    while IFS=':' read -r id deps title status; do
        [[ -z "$id" ]] && continue
        all_ids+=("$id")
        deps_map["$id"]="$deps"
        title_map["$id"]="$title"
        status_map["$id"]="$status"
    done < <(build_dependency_graph "$project_dir")

    echo "Root Issues (no dependencies):"
    echo "=============================="
    echo ""

    local count=0
    for id in "${all_ids[@]}"; do
        if [[ -z "${deps_map[$id]}" ]]; then
            local title="${title_map[$id]:-}"
            local status="${status_map[$id]:-pending}"
            local status_char="○"
            case "$status" in
                completed) status_char="✓" ;;
                in_progress) status_char="▶" ;;
            esac

            printf "  %s %s: %s\n" "$status_char" "$id" "$title"
            count=$((count + 1))
        fi
    done

    echo ""
    echo "Total: $count root issues"
}
# }}}

# =============================================================================
# CLI Interface
# =============================================================================

# -- {{{ show_help
show_help() {
    cat << 'EOF'
Usage: visualize-deps.sh [OPTIONS] [project-directory]

Visualize and analyze issue dependencies for a project.

Output Formats:
    --ascii          ASCII tree diagram (default)
    --dot            DOT format for Graphviz
    --json           JSON format for programmatic use

Queries:
    --blocks ID      Show what issue ID blocks (direct + transitive)
    --depends ID     Show dependency chain for issue ID
    --parallel       Show issues that can be worked on in parallel
    --roots          Show issues with no dependencies

Options:
    -p, --project DIR    Project directory (default: current or delta-version)
    --pending-only       Only show pending issues
    --completed-only     Only show completed issues
    -v, --verbose        Verbose output
    -I, --interactive    Interactive mode
    -h, --help           Show this help

Examples:
    # Show dependency tree for delta-version
    visualize-deps.sh /mnt/mtwo/programming/ai-stuff/delta-version

    # Export to PNG via Graphviz
    visualize-deps.sh --dot /path/to/project | dot -Tpng -o deps.png

    # What does issue 001 block?
    visualize-deps.sh --blocks 001 /path/to/project

    # Full dependency chain for issue 035
    visualize-deps.sh --depends 035 /path/to/project

    # Find parallel work opportunities
    visualize-deps.sh --parallel /path/to/project
EOF
}
# }}}

# -- {{{ parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--project)
                PROJECT_DIR="$2"
                shift 2
                ;;
            --ascii)
                OUTPUT_FORMAT="ascii"
                shift
                ;;
            --dot)
                OUTPUT_FORMAT="dot"
                shift
                ;;
            --json)
                OUTPUT_FORMAT="json"
                shift
                ;;
            --blocks)
                QUERY_MODE="blocks"
                QUERY_TARGET="$2"
                shift 2
                ;;
            --depends)
                QUERY_MODE="depends"
                QUERY_TARGET="$2"
                shift 2
                ;;
            --parallel)
                QUERY_MODE="parallel"
                shift
                ;;
            --roots)
                QUERY_MODE="roots"
                shift
                ;;
            --pending-only)
                INCLUDE_PENDING=true
                INCLUDE_COMPLETED=false
                shift
                ;;
            --completed-only)
                INCLUDE_PENDING=false
                INCLUDE_COMPLETED=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -I|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                PROJECT_DIR="$1"
                shift
                ;;
        esac
    done
}
# }}}

# -- {{{ run_interactive
run_interactive() {
    local project_dir="$1"

    echo "=== Dependency Visualization Tool ==="
    echo ""
    echo "Project: $(basename "$project_dir")"
    echo ""
    echo "1. Show ASCII tree"
    echo "2. Export DOT format"
    echo "3. Export JSON format"
    echo "4. Query: What does an issue block?"
    echo "5. Query: What does an issue depend on?"
    echo "6. Query: Parallel work opportunities"
    echo "7. Query: Show root issues"
    echo "8. Exit"
    echo ""

    read -rp "Select option [1-8]: " choice

    case "$choice" in
        1) generate_ascii_tree "$project_dir" ;;
        2) generate_dot_graph "$project_dir" ;;
        3) generate_json_graph "$project_dir" ;;
        4)
            read -rp "Enter issue ID: " target
            query_blocks "$project_dir" "$target"
            ;;
        5)
            read -rp "Enter issue ID: " target
            query_depends "$project_dir" "$target"
            ;;
        6) query_parallel "$project_dir" ;;
        7) query_roots "$project_dir" ;;
        8) exit 0 ;;
        *) error "Invalid selection" ;;
    esac
}
# }}}

# -- {{{ main
main() {
    parse_args "$@"

    # Default project directory
    if [[ -z "$PROJECT_DIR" ]]; then
        # Try current directory, then delta-version
        if [[ -d "./issues" ]]; then
            PROJECT_DIR="$(pwd)"
        else
            PROJECT_DIR="$DIR/delta-version"
        fi
    fi

    # Validate project directory
    if [[ ! -d "$PROJECT_DIR/issues" ]]; then
        error "No issues directory found in: $PROJECT_DIR"
        exit 1
    fi

    log "Project directory: $PROJECT_DIR"

    # Interactive mode
    if [[ "$INTERACTIVE" == true ]]; then
        run_interactive "$PROJECT_DIR"
        exit 0
    fi

    # Query mode
    if [[ -n "$QUERY_MODE" ]]; then
        case "$QUERY_MODE" in
            blocks) query_blocks "$PROJECT_DIR" "$QUERY_TARGET" ;;
            depends) query_depends "$PROJECT_DIR" "$QUERY_TARGET" ;;
            parallel) query_parallel "$PROJECT_DIR" ;;
            roots) query_roots "$PROJECT_DIR" ;;
        esac
        exit 0
    fi

    # Output format
    case "$OUTPUT_FORMAT" in
        ascii) generate_ascii_tree "$PROJECT_DIR" ;;
        dot) generate_dot_graph "$PROJECT_DIR" ;;
        json) generate_json_graph "$PROJECT_DIR" ;;
    esac
}
# }}}

main "$@"
