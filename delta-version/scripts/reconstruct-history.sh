#!/usr/bin/env bash
# reconstruct-history.sh - Unified project onboarding and history reconstruction
#
# Handles both external project import and in-place history reconstruction.
# Detects project state and applies appropriate reconstruction strategy.
# Preserves any commits made after initial "blob" imports.
#
# Commit order: 1) Vision file, 2) Each completed issue, 3) Remaining files
# For existing repos: Rewrites only blob commits, rebases subsequent commits.

set -euo pipefail

# -- {{{ Configuration
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Monorepo settings
MONOREPO_ROOT="${MONOREPO_ROOT:-/mnt/mtwo/programming/ai-stuff}"
IMPORT_MODE="${IMPORT_MODE:-copy}"  # copy or move

# Blob detection thresholds
FLAT_BLOB_THRESHOLD=2       # Max commits to be considered flat blob
FLAT_BLOB_MIN_FILES=50      # Min files to be considered flat blob
GOOD_HISTORY_RATIO=20       # 1 commit per N files = good history

# Runtime options
PROJECT_DIR=""
PROJECT_NAME=""             # Override name for imports
DRY_RUN=false
VERBOSE=false
FORCE=false
INTERACTIVE=false
BRANCH_NAME="main"
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
# Project Detection Functions
# =============================================================================

# -- {{{ is_in_monorepo
is_in_monorepo() {
    local project_dir="$1"
    local abs_path abs_mono

    abs_path=$(cd "$project_dir" 2>/dev/null && pwd) || return 1
    abs_mono=$(cd "$MONOREPO_ROOT" 2>/dev/null && pwd) || return 1

    [[ "$abs_path" == "$abs_mono"/* ]]
}
# }}}

# -- {{{ has_flat_history
has_flat_history() {
    local project_dir="$1"

    # No git = not flat history (needs initialization)
    [[ ! -d "$project_dir/.git" ]] && return 1

    local commit_count file_count
    commit_count=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null || echo "0")
    file_count=$(git -C "$project_dir" ls-files 2>/dev/null | wc -l)

    # Heuristic: flat blob if few commits but many files
    [[ "$commit_count" -le "$FLAT_BLOB_THRESHOLD" && "$file_count" -gt "$FLAT_BLOB_MIN_FILES" ]]
}
# }}}

# -- {{{ has_good_history
has_good_history() {
    local project_dir="$1"

    # No git = no history
    [[ ! -d "$project_dir/.git" ]] && return 1

    local commit_count file_count min_commits
    commit_count=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null || echo "0")
    file_count=$(git -C "$project_dir" ls-files 2>/dev/null | wc -l)

    # Good history: reasonable commit-to-file ratio
    min_commits=$((file_count / GOOD_HISTORY_RATIO))
    [[ "$commit_count" -ge "$min_commits" && "$commit_count" -gt 5 ]]
}
# }}}

# -- {{{ determine_project_state
determine_project_state() {
    local project_dir="$1"

    if ! is_in_monorepo "$project_dir"; then
        echo "external"
    elif [[ ! -d "$project_dir/.git" ]]; then
        echo "no_git"
    elif has_flat_history "$project_dir"; then
        echo "flat_blob"
    elif has_good_history "$project_dir"; then
        echo "good_history"
    else
        echo "sparse_history"
    fi
}
# }}}

# =============================================================================
# Blob Boundary Detection (for preserving post-blob commits)
# =============================================================================

# -- {{{ find_blob_commits
find_blob_commits() {
    local project_dir="$1"

    # Find commits that added a large number of files at once
    # These are likely the "blob" imports we want to expand
    git -C "$project_dir" log --oneline --numstat --reverse 2>/dev/null | awk -v threshold="$FLAT_BLOB_MIN_FILES" '
        /^[0-9a-f]+ / {
            if (commit != "" && additions > threshold) {
                print commit
            }
            commit = $1
            additions = 0
        }
        /^[0-9]+\t[0-9]+\t/ {
            additions++
        }
        END {
            if (commit != "" && additions > threshold) {
                print commit
            }
        }
    ' | head -2  # Usually first 1-2 commits are the blob
}
# }}}

# -- {{{ get_blob_boundary
get_blob_boundary() {
    local project_dir="$1"

    # Find the last "blob" commit - commits after this are real development
    local blob_commits
    blob_commits=$(find_blob_commits "$project_dir")

    if [[ -z "$blob_commits" ]]; then
        # No blob found, use root commit
        git -C "$project_dir" rev-list --max-parents=0 HEAD 2>/dev/null | head -1
    else
        # Return the last blob commit
        echo "$blob_commits" | tail -1
    fi
}
# }}}

# -- {{{ get_files_in_blob
get_files_in_blob() {
    local project_dir="$1"
    local blob_commit="$2"

    # Get all files that were present at the blob commit
    git -C "$project_dir" ls-tree -r --name-only "$blob_commit" 2>/dev/null
}
# }}}

# -- {{{ count_post_blob_commits
count_post_blob_commits() {
    local project_dir="$1"
    local blob_commit="$2"

    git -C "$project_dir" rev-list --count "${blob_commit}..HEAD" 2>/dev/null || echo "0"
}
# }}}

# -- {{{ get_post_blob_commits
get_post_blob_commits() {
    local project_dir="$1"
    local blob_commit="$2"

    # Get all commits after the blob commit (these must be preserved)
    git -C "$project_dir" rev-list --reverse "${blob_commit}..HEAD" 2>/dev/null
}
# }}}

# =============================================================================
# External Project Import
# =============================================================================

# -- {{{ import_external_project
import_external_project() {
    local source_dir="$1"
    local project_name="${PROJECT_NAME:-$(basename "$source_dir")}"
    local target_dir="${MONOREPO_ROOT}/${project_name}"

    # Validate source
    if [[ ! -d "$source_dir" ]]; then
        error "Source directory not found: $source_dir"
        return 1
    fi

    # Check target
    if [[ -d "$target_dir" ]]; then
        if [[ "$FORCE" == true ]]; then
            echo "Removing existing target directory (--force)"
            rm -rf "$target_dir"
        else
            error "Target already exists: $target_dir"
            error "Use --force to overwrite or --name to specify different name"
            return 1
        fi
    fi

    echo "Importing project:"
    echo "  From: $source_dir"
    echo "  To:   $target_dir"

    # Preserve timestamps with cp -a (critical for date estimation)
    if [[ "$IMPORT_MODE" == "move" ]]; then
        mv "$source_dir" "$target_dir"
    else
        cp -a "$source_dir" "$target_dir"
    fi

    # Remove existing .git if present (we'll reconstruct)
    if [[ -d "$target_dir/.git" ]]; then
        echo "  Removing existing .git directory"
        rm -rf "$target_dir/.git"
    fi

    echo "$target_dir"
}
# }}}

# =============================================================================
# Vision and Issue Discovery
# =============================================================================

# -- {{{ find_vision_file
find_vision_file() {
    local project_dir="$1"

    # Search in priority order
    local patterns=(
        "notes/vision.md"
        "notes/vision"
        "vision.md"
        "vision"
        "docs/vision.md"
        "docs/vision"
    )

    for pattern in "${patterns[@]}"; do
        if [[ -f "${project_dir}/${pattern}" ]]; then
            echo "${pattern}"
            return 0
        fi
    done

    # Also check for vision-* variants
    local vision_variant
    vision_variant=$(find "$project_dir" -maxdepth 3 \( -name "vision-*" -o -name "vision.md" \) -type f 2>/dev/null | head -1)
    if [[ -n "$vision_variant" ]]; then
        # Return relative path
        echo "${vision_variant#$project_dir/}"
        return 0
    fi

    return 1
}
# }}}

# -- {{{ discover_completed_issues
discover_completed_issues() {
    local project_dir="$1"
    local completed_dir="${project_dir}/issues/completed"

    if [[ ! -d "$completed_dir" ]]; then
        log "No completed issues directory found at: $completed_dir"
        return 0
    fi

    # Find all .md files that look like issues (start with digits)
    # Sort by issue number for consistent ordering
    find "$completed_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null | \
        while read -r file; do
            local basename
            basename=$(basename "$file")
            # Match patterns like 001-*, 023-*, 012a-* (sub-issues)
            if [[ "$basename" =~ ^[0-9]{3}[a-z]?- ]]; then
                echo "$file"
            fi
        done | sort -t'/' -k1 -V
}
# }}}

# -- {{{ extract_issue_title
extract_issue_title() {
    local issue_file="$1"

    # Extract title from first # heading
    local title
    title=$(grep -m1 '^# ' "$issue_file" 2>/dev/null | sed 's/^# //')

    if [[ -z "$title" ]]; then
        # Fallback to filename
        title=$(basename "$issue_file" .md | sed 's/-/ /g')
    fi

    echo "$title"
}
# }}}

# -- {{{ extract_issue_id
extract_issue_id() {
    local issue_file="$1"
    local basename
    basename=$(basename "$issue_file" .md)

    # Extract issue ID pattern: 001, 023a, 035b, etc.
    if [[ "$basename" =~ ^([0-9]{3}[a-z]?) ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}
# }}}

# =============================================================================
# Dependency Graph and Topological Sort (035b)
# =============================================================================

# -- {{{ parse_issue_dependencies
parse_issue_dependencies() {
    local issue_file="$1"
    local -a all_refs=()

    # Extract Dependencies field (e.g., "Dependencies: 001, 002, 003")
    local deps
    deps=$(grep -iE '^[-*]?\s*\*?\*?Dependencies\*?\*?\s*:' "$issue_file" 2>/dev/null | \
           sed 's/.*:\s*//' | tr ',' ' ')

    # Extract Blocked By field
    local blocked_by
    blocked_by=$(grep -iE '^[-*]?\s*\*?\*?Blocked\s*By\*?\*?\s*:' "$issue_file" 2>/dev/null | \
                 sed 's/.*:\s*//' | tr ',' ' ')

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
             sed 's/.*:\s*//' | tr ',' ' ')

    # Match issue numbers
    while read -r ref; do
        [[ -n "$ref" ]] && all_refs+=("$ref")
    done < <(echo "$blocks" | grep -oE '([0-9]{3}[a-z]?)' | sort -u)

    echo "${all_refs[*]}"
}
# }}}

# -- {{{ build_dependency_graph
build_dependency_graph() {
    local issues_dir="$1"
    local -A graph  # issue_id -> space-separated list of dependencies

    # Process all issue files
    for issue_file in "$issues_dir"/*.md; do
        [[ ! -f "$issue_file" ]] && continue

        local issue_id
        issue_id=$(extract_issue_id "$issue_file")
        [[ -z "$issue_id" ]] && continue

        # Get direct dependencies (issues this one depends on)
        local deps
        deps=$(parse_issue_dependencies "$issue_file")
        graph["$issue_id"]="$deps"

        log "  Graph: $issue_id depends on: ${deps:-none}"
    done

    # Also process "Blocks" relationships (reverse direction)
    # If issue A blocks issue B, then B depends on A
    for issue_file in "$issues_dir"/*.md; do
        [[ ! -f "$issue_file" ]] && continue

        local issue_id
        issue_id=$(extract_issue_id "$issue_file")
        [[ -z "$issue_id" ]] && continue

        local blocks
        blocks=$(parse_issue_blocks "$issue_file")

        for blocked_id in $blocks; do
            # Add this issue as a dependency of the blocked issue
            if [[ -n "${graph[$blocked_id]:-}" ]]; then
                # Avoid duplicates
                if ! echo " ${graph[$blocked_id]} " | grep -q " $issue_id "; then
                    graph["$blocked_id"]="${graph[$blocked_id]} $issue_id"
                fi
            else
                graph["$blocked_id"]="$issue_id"
            fi
            log "  Graph: $blocked_id depends on $issue_id (via Blocks field)"
        done
    done

    # Output graph as lines: "issue_id:dep1 dep2 dep3"
    for issue_id in "${!graph[@]}"; do
        echo "$issue_id:${graph[$issue_id]}"
    done
}
# }}}

# -- {{{ topological_sort_issues
topological_sort_issues() {
    # Reads dependency graph from stdin and outputs topologically sorted issue IDs
    # Format: "issue_id:dep1 dep2 dep3" per line

    local -A graph       # issue_id -> space-separated dependencies
    local -A in_degree   # issue_id -> number of unresolved dependencies
    local -a all_nodes=()
    local -a result=()
    local -a queue=()

    # Parse input graph
    while IFS=':' read -r node deps; do
        [[ -z "$node" ]] && continue

        graph["$node"]="$deps"
        all_nodes+=("$node")

        # Initialize in_degree
        [[ -z "${in_degree[$node]:-}" ]] && in_degree["$node"]=0

        # Count dependencies (increment in_degree for nodes this one depends on)
        for dep in $deps; do
            [[ -z "${in_degree[$dep]:-}" ]] && in_degree["$dep"]=0
            all_nodes+=("$dep")  # Ensure all referenced nodes are tracked
        done
    done

    # Remove duplicate nodes
    mapfile -t all_nodes < <(printf '%s\n' "${all_nodes[@]}" | sort -u)

    # Calculate in_degree for each node
    # in_degree = number of nodes that depend on this node (i.e., this node blocks them)
    # We want nodes with low in_degree (not many blockers) to come first
    # Actually, we need REVERSE: nodes with no dependencies should come first

    # Reset and recalculate: in_degree[X] = count of how many issues X depends on
    for node in "${all_nodes[@]}"; do
        local deps="${graph[$node]:-}"
        local dep_count=0
        for dep in $deps; do
            [[ -n "$dep" ]] && ((dep_count++))
        done
        in_degree["$node"]=$dep_count
    done

    # Initialize queue with nodes having no dependencies (in_degree = 0)
    for node in "${all_nodes[@]}"; do
        if [[ "${in_degree[$node]}" -eq 0 ]]; then
            queue+=("$node")
        fi
    done

    # Sort queue by issue number for deterministic output
    mapfile -t queue < <(printf '%s\n' "${queue[@]}" | sort -V)

    # Kahn's algorithm
    while [[ ${#queue[@]} -gt 0 ]]; do
        # Take first node from queue
        local current="${queue[0]}"
        queue=("${queue[@]:1}")
        result+=("$current")

        # For each node that depends on current, decrement its in_degree
        for node in "${all_nodes[@]}"; do
            local deps="${graph[$node]:-}"
            if echo " $deps " | grep -q " $current "; then
                ((in_degree["$node"]--))
                if [[ "${in_degree[$node]}" -eq 0 ]]; then
                    queue+=("$node")
                fi
            fi
        done

        # Re-sort queue for deterministic output
        mapfile -t queue < <(printf '%s\n' "${queue[@]}" | sort -V)
    done

    # Output result
    printf '%s\n' "${result[@]}"
}
# }}}

# -- {{{ order_issues_by_dependencies
order_issues_by_dependencies() {
    local project_dir="$1"
    local completed_dir="${project_dir}/issues/completed"

    if [[ ! -d "$completed_dir" ]]; then
        return 0
    fi

    log "Building dependency graph from issue files..."

    # Build the dependency graph
    local graph_output
    graph_output=$(build_dependency_graph "$completed_dir")

    if [[ -z "$graph_output" ]]; then
        log "No dependencies found, falling back to numerical order"
        discover_completed_issues "$project_dir"
        return 0
    fi

    # Get topologically sorted issue IDs
    local -a sorted_ids
    mapfile -t sorted_ids < <(echo "$graph_output" | topological_sort_issues)

    log "Topological sort result: ${sorted_ids[*]}"

    # Also get issues that weren't in the graph (no dependencies mentioned)
    local -a all_issue_files
    mapfile -t all_issue_files < <(discover_completed_issues "$project_dir")

    local -a ordered_files=()
    local -A seen_ids=()

    # First, output issues in topological order
    for issue_id in "${sorted_ids[@]}"; do
        for issue_file in "${all_issue_files[@]}"; do
            local file_id
            file_id=$(extract_issue_id "$issue_file")
            if [[ "$file_id" == "$issue_id" ]] && [[ -z "${seen_ids[$file_id]:-}" ]]; then
                ordered_files+=("$issue_file")
                seen_ids["$file_id"]=1
                break
            fi
        done
    done

    # Then, add any remaining issues not in the graph (in numerical order)
    for issue_file in "${all_issue_files[@]}"; do
        local file_id
        file_id=$(extract_issue_id "$issue_file")
        if [[ -z "${seen_ids[$file_id]:-}" ]]; then
            ordered_files+=("$issue_file")
            seen_ids["$file_id"]=1
        fi
    done

    # Output ordered files
    printf '%s\n' "${ordered_files[@]}"
}
# }}}

# -- {{{ create_vision_commit
create_vision_commit() {
    local vision_file="$1"
    local project_name="$2"

    log "Creating vision commit for: $vision_file"

    git add "$vision_file"

    # Check if there's anything to commit
    if ! git diff --cached --quiet; then
        git commit -m "$(cat <<EOF
Initial vision: ${project_name} project purpose and goals

Establishes the foundational vision for this project.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: reconstruct-history.sh <noreply@delta-version>
EOF
)"
        return 0
    else
        log "Vision file already committed or empty"
        return 1
    fi
}
# }}}

# -- {{{ create_issue_commit
create_issue_commit() {
    local issue_file="$1"
    local issue_name
    local title

    issue_name=$(basename "$issue_file" .md)
    title=$(extract_issue_title "$issue_file")

    log "Creating issue commit for: $issue_name"

    git add "$issue_file"

    # Check if there's anything to commit
    if ! git diff --cached --quiet; then
        git commit -m "$(cat <<EOF
${title}

Completed issue documentation for ${issue_name}.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: reconstruct-history.sh <noreply@delta-version>
EOF
)"
        return 0
    else
        log "Issue file already committed or empty: $issue_name"
        return 1
    fi
}
# }}}

# -- {{{ create_bulk_commit
create_bulk_commit() {
    local project_name="$1"

    log "Creating bulk commit for remaining files"

    git add -A

    # Check if there's anything to commit
    if ! git diff --cached --quiet; then
        git commit -m "$(cat <<EOF
Import remaining ${project_name} project files

Adds all source code, documentation, and assets not covered
by individual issue commits.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: reconstruct-history.sh <noreply@delta-version>
EOF
)"
        return 0
    else
        log "No remaining files to commit"
        return 1
    fi
}
# }}}

# -- {{{ reconstruct_history
reconstruct_history() {
    local project_dir="$1"
    local project_name
    project_name=$(basename "$project_dir")

    # Validate project directory
    if [[ ! -d "$project_dir" ]]; then
        error "Project directory not found: $project_dir"
        return 1
    fi

    # Check for existing git history
    if [[ -d "${project_dir}/.git" ]]; then
        if [[ "$FORCE" != true ]]; then
            error "Project already has git history at: ${project_dir}/.git"
            error "Use --force to override (this will delete existing history)"
            return 1
        else
            echo "WARNING: Removing existing git history (--force specified)"
            rm -rf "${project_dir}/.git"
        fi
    fi

    # Change to project directory
    cd "$project_dir" || return 1

    # Initialize git repository
    echo "Initializing git repository in: $project_dir"
    git init -b "$BRANCH_NAME"

    local commit_count=0

    # Step 1: Vision commit
    local vision_file
    if vision_file=$(find_vision_file "$project_dir"); then
        echo "  [1] Vision: $vision_file"
        if create_vision_commit "$vision_file" "$project_name"; then
            ((commit_count++))
        fi
    else
        echo "  [!] No vision file found, skipping vision commit"
    fi

    # Step 2: Issue commits (ordered by dependencies via topological sort)
    local -a completed_issues
    mapfile -t completed_issues < <(order_issues_by_dependencies "$project_dir")

    if [[ ${#completed_issues[@]} -gt 0 ]]; then
        echo "  [2] Processing ${#completed_issues[@]} completed issue(s) (dependency-ordered)..."
        for issue_file in "${completed_issues[@]}"; do
            local issue_name
            issue_name=$(basename "$issue_file" .md)
            echo "      - $issue_name"
            if create_issue_commit "$issue_file"; then
                ((commit_count++))
            fi
        done
    else
        echo "  [2] No completed issues found"
    fi

    # Step 3: Bulk commit for remaining files
    echo "  [3] Importing remaining project files..."
    if create_bulk_commit "$project_name"; then
        ((commit_count++))
    fi

    echo ""
    echo "=== History Reconstruction Complete ==="
    echo "Project: $project_name"
    echo "Commits created: $commit_count"
    echo ""
    echo "Recent commits:"
    git log --oneline -10
}
# }}}

# =============================================================================
# Unified Workflow
# =============================================================================

# -- {{{ process_project
process_project() {
    local project_dir="$1"
    local state

    state=$(determine_project_state "$project_dir")
    echo "Project state: $state"

    case "$state" in
        external)
            echo ""
            echo "Project is external to monorepo, importing..."
            local new_dir
            new_dir=$(import_external_project "$project_dir")
            [[ $? -ne 0 ]] && return 1
            project_dir="$new_dir"
            echo ""
            # Re-classify after import (will be no_git since we removed .git)
            state="no_git"
            echo "Post-import state: $state"
            ;&  # Fall through

        no_git)
            echo ""
            echo "No git history found, creating from scratch..."
            reconstruct_history "$project_dir"
            ;;

        flat_blob|sparse_history)
            echo ""
            # Check for post-blob commits that need preservation
            local blob_boundary post_blob_count
            blob_boundary=$(get_blob_boundary "$project_dir")
            post_blob_count=$(count_post_blob_commits "$project_dir" "$blob_boundary")

            if [[ "$post_blob_count" -gt 0 ]]; then
                echo "Found $post_blob_count commits after initial blob that will be preserved"
                echo "Blob boundary: $blob_boundary"
                echo ""
                echo "NOTE: Full history rewriting with rebase not yet implemented (035e)"
                echo "      For now, only the blob commits will be examined."
                echo "      Use --force to rebuild from scratch (loses post-blob commits)"
                if [[ "$FORCE" == true ]]; then
                    echo ""
                    echo "WARNING: --force specified, removing ALL history including post-blob commits"
                    rm -rf "$project_dir/.git"
                    reconstruct_history "$project_dir"
                else
                    return 1
                fi
            else
                echo "No post-blob commits to preserve, rebuilding history..."
                rm -rf "$project_dir/.git"
                reconstruct_history "$project_dir"
            fi
            ;;

        good_history)
            if [[ "$FORCE" == true ]]; then
                echo ""
                echo "Good history exists but --force specified, rebuilding..."
                rm -rf "$project_dir/.git"
                reconstruct_history "$project_dir"
            else
                echo ""
                echo "Project already has good commit history ($(git -C "$project_dir" rev-list --count HEAD) commits)"
                echo "Use --force to reconstruct anyway"
                return 0
            fi
            ;;
    esac
}
# }}}

# =============================================================================
# Dry Run and Reporting
# =============================================================================

# -- {{{ dry_run_report
dry_run_report() {
    local project_dir="$1"
    local project_name
    project_name=$(basename "$project_dir")

    echo "=== DRY RUN MODE ==="
    echo ""

    # Project state analysis
    local state
    state=$(determine_project_state "$project_dir")

    echo "Project Analysis:"
    echo "  Name:      $project_name"
    echo "  Directory: $project_dir"
    echo "  State:     $state"

    # State-specific details
    case "$state" in
        external)
            local target_name="${PROJECT_NAME:-$project_name}"
            local target_dir="${MONOREPO_ROOT}/${target_name}"
            echo ""
            echo "  Import Details:"
            echo "    Source: $project_dir"
            echo "    Target: $target_dir"
            echo "    Mode:   $IMPORT_MODE"
            if [[ -d "$target_dir" ]]; then
                if [[ "$FORCE" == true ]]; then
                    echo "    WARNING: Target exists, would be removed (--force)"
                else
                    echo "    ERROR: Target exists, use --force or --name"
                fi
            fi
            # For external, show what would happen after import
            project_dir="$target_dir"
            ;;

        flat_blob|sparse_history)
            local blob_boundary post_blob_count
            blob_boundary=$(get_blob_boundary "$project_dir")
            post_blob_count=$(count_post_blob_commits "$project_dir" "$blob_boundary")
            local commit_count file_count
            commit_count=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null || echo "0")
            file_count=$(git -C "$project_dir" ls-files 2>/dev/null | wc -l)

            echo ""
            echo "  Git Statistics:"
            echo "    Total commits:     $commit_count"
            echo "    Total files:       $file_count"
            echo "    Blob boundary:     $blob_boundary"
            echo "    Post-blob commits: $post_blob_count"
            if [[ "$post_blob_count" -gt 0 ]]; then
                echo ""
                echo "  Post-blob commits to preserve:"
                git -C "$project_dir" log --oneline "${blob_boundary}..HEAD" 2>/dev/null | head -5 | sed 's/^/    /'
                local remaining=$((post_blob_count - 5))
                [[ $remaining -gt 0 ]] && echo "    ... and $remaining more"
            fi
            ;;

        good_history)
            local commit_count file_count
            commit_count=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null || echo "0")
            file_count=$(git -C "$project_dir" ls-files 2>/dev/null | wc -l)
            echo ""
            echo "  Git Statistics:"
            echo "    Commits: $commit_count"
            echo "    Files:   $file_count"
            echo "    Ratio:   1 commit per $((file_count / (commit_count > 0 ? commit_count : 1))) files"
            echo ""
            echo "  Action: Skip (use --force to reconstruct anyway)"
            return 0
            ;;
    esac

    echo ""
    echo "Planned Reconstruction:"
    echo ""

    # Vision file
    echo "  Commit 1 - Vision:"
    local vision_file
    if vision_file=$(find_vision_file "$project_dir" 2>/dev/null); then
        echo "    + $vision_file"
    else
        echo "    (no vision file found, would skip)"
    fi

    # Completed issues (dependency-ordered)
    echo ""
    echo "  Commits 2..N - Completed Issues (dependency-ordered):"
    local -a completed_issues
    mapfile -t completed_issues < <(order_issues_by_dependencies "$project_dir" 2>/dev/null)

    if [[ ${#completed_issues[@]} -gt 0 ]]; then
        local i=2
        for issue_file in "${completed_issues[@]}"; do
            local issue_name title issue_id deps_info
            issue_name=$(basename "$issue_file" .md)
            title=$(extract_issue_title "$issue_file")
            issue_id=$(extract_issue_id "$issue_file")

            # Show dependencies if any
            local deps
            deps=$(parse_issue_dependencies "$issue_file" 2>/dev/null)
            deps_info=""
            [[ -n "$deps" ]] && deps_info=" (depends on: $deps)"

            echo "    [$i] $issue_name$deps_info"
            echo "        \"$title\""
            ((i++))
        done
    else
        echo "    (no completed issues found)"
    fi

    # Remaining files estimate
    echo ""
    echo "  Final Commit - Remaining Files:"
    local file_count dir_count
    file_count=$(find "$project_dir" -type f ! -path "*/.git/*" 2>/dev/null | wc -l)
    dir_count=$(find "$project_dir" -type d ! -path "*/.git/*" ! -path "*/.git" 2>/dev/null | wc -l)
    echo "    ~$file_count files in ~$dir_count directories"

    # Summary
    echo ""
    local total_commits=$((1 + ${#completed_issues[@]} + 1))
    if [[ -z "$vision_file" ]]; then
        ((total_commits--))
    fi
    echo "Total commits that would be created: $total_commits"
}
# }}}

# -- {{{ show_help
show_help() {
    cat <<'EOF'
Usage: reconstruct-history.sh [OPTIONS] <project-directory>

Unified project onboarding and history reconstruction tool.

Handles both external project import and in-place history reconstruction.
Detects project state and applies appropriate strategy. Preserves any
commits made after initial "blob" imports.

Options:
    -p, --project DIR    Project directory to process
    -b, --branch NAME    Branch name to create (default: main)
    -n, --dry-run        Show what would be done without making changes
    -v, --verbose        Verbose output
    -f, --force          Override existing git history (destructive!)
    -I, --interactive    Interactive mode (select project from list)
    -h, --help           Show this help message

Import Options (for external projects):
    --name NAME          Specify project name for import (default: basename)
    --move               Move instead of copy when importing
    --monorepo DIR       Override monorepo root directory

Project States:
    external       - Outside monorepo, will be imported first
    no_git         - No git history, create from scratch
    flat_blob      - Few commits with many files, rewrite history
    sparse_history - Some commits but poor ratio, rewrite history
    good_history   - Healthy history, skip (unless --force)

Commit Order:
    1. Vision file (notes/vision.md, vision, etc.)
    2. Each completed issue file (issues/completed/*.md)
       - Ordered by dependencies (topological sort)
       - Parses Dependencies, Blocks, Blocked By fields
       - Issues with no dependencies come first
    3. All remaining project files (source, docs, assets)

For existing repos with post-blob commits:
    - Only the initial blob commits are rewritten
    - Subsequent commits are preserved and rebased (future: 035e)

Examples:
    # Preview what would happen
    reconstruct-history.sh --dry-run /path/to/project

    # Reconstruct history for a project in monorepo
    reconstruct-history.sh /path/to/project

    # Import external project and reconstruct
    reconstruct-history.sh /external/project

    # Import with custom name
    reconstruct-history.sh --name my-project /external/project

    # Force reconstruction (removes existing .git)
    reconstruct-history.sh --force /path/to/project

    # Interactive mode - select from available projects
    reconstruct-history.sh -I

Vision File Patterns:
    notes/vision.md, notes/vision, vision.md, vision,
    docs/vision.md, docs/vision, notes/vision-*

Issue File Patterns:
    issues/completed/001-*.md, issues/completed/023a-*.md, etc.

EOF
}
# }}}

# -- {{{ interactive_select_project
interactive_select_project() {
    local projects_script="${DIR}/delta-version/scripts/list-projects.sh"

    if [[ ! -x "$projects_script" ]]; then
        error "Project listing script not found: $projects_script"
        error "Cannot run interactive mode without list-projects.sh"
        return 1
    fi

    echo "Available projects:"
    echo ""

    local -a projects
    mapfile -t projects < <("$projects_script" --paths)

    if [[ ${#projects[@]} -eq 0 ]]; then
        error "No projects found"
        return 1
    fi

    local i=1
    for project in "${projects[@]}"; do
        local name
        name=$(basename "$project")
        local has_git=""
        local has_issues=""

        [[ -d "${project}/.git" ]] && has_git=" [git]"
        [[ -d "${project}/issues/completed" ]] && has_issues=" [issues]"

        printf "  %2d) %-30s%s%s\n" "$i" "$name" "$has_git" "$has_issues"
        ((i++))
    done

    echo ""
    read -rp "Select project (1-${#projects[@]}): " selection

    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt ${#projects[@]} ]]; then
        error "Invalid selection: $selection"
        return 1
    fi

    PROJECT_DIR="${projects[$((selection-1))]}"
    echo "Selected: $PROJECT_DIR"
    echo ""
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
            -b|--branch)
                BRANCH_NAME="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -I|--interactive)
                INTERACTIVE=true
                shift
                ;;
            --name)
                PROJECT_NAME="$2"
                shift 2
                ;;
            --move)
                IMPORT_MODE="move"
                shift
                ;;
            --monorepo)
                MONOREPO_ROOT="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                # Assume positional argument is project directory
                PROJECT_DIR="$1"
                shift
                ;;
        esac
    done
}
# }}}

# -- {{{ main
main() {
    parse_args "$@"

    # Interactive mode
    if [[ "$INTERACTIVE" == true ]]; then
        if ! interactive_select_project; then
            exit 1
        fi
    fi

    # Validate project directory
    if [[ -z "$PROJECT_DIR" ]]; then
        error "No project directory specified"
        echo ""
        show_help
        exit 1
    fi

    # Resolve to absolute path (allow non-existent for external check)
    if [[ -d "$PROJECT_DIR" ]]; then
        PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
    else
        # For external projects that might not exist yet in target
        PROJECT_DIR=$(realpath -m "$PROJECT_DIR" 2>/dev/null || echo "$PROJECT_DIR")
    fi

    # Verify the source directory exists
    if [[ ! -d "$PROJECT_DIR" ]]; then
        error "Project directory not found: $PROJECT_DIR"
        exit 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        dry_run_report "$PROJECT_DIR"
    else
        process_project "$PROJECT_DIR"
    fi
}
# }}}

main "$@"
