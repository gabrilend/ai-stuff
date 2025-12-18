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
SKIP_FILE_ASSOCIATION=true  # 035d is slow, skip by default for now

# LLM Integration (035f) - optional, disabled by default
LLM_ENABLED="${LLM_ENABLED:-false}"
LLM_MODEL="${LLM_MODEL:-llama3}"
LLM_VERIFY_COUNT="${LLM_VERIFY_COUNT:-3}"
LLM_STATS_FILE="${LLM_STATS_FILE:-$HOME/.config/reconstruct-history/llm-stats.txt}"
OLLAMA_ENDPOINT="${OLLAMA_ENDPOINT:-http://192.168.0.115:10265}"
SHOW_LLM_STATS=false
RESET_LLM_STATS=false

# Post-Blob Commit Preservation (035e)
PRESERVE_POST_BLOB="${PRESERVE_POST_BLOB:-true}"
REPLACE_ORIGINAL="${REPLACE_ORIGINAL:-false}"
POST_BLOB_COMMIT_FILE=""      # Temp file for commit list (set at runtime)
ORIGINAL_BRANCH=""            # Store original branch name for restoration
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
# Local LLM Integration (035f)
# =============================================================================

# -- {{{ init_llm_stats
init_llm_stats() {
    # Ensure stats directory and file exist
    mkdir -p "$(dirname "$LLM_STATS_FILE")"

    if [[ ! -f "$LLM_STATS_FILE" ]]; then
        echo "0" > "$LLM_STATS_FILE"
        echo "0" >> "$LLM_STATS_FILE"
        echo "0/0" >> "$LLM_STATS_FILE"
    fi
}
# }}}

# -- {{{ record_llm_result
record_llm_result() {
    local result="$1"  # "success" or "failure"

    init_llm_stats

    # Read current counts
    local success_count failure_count
    success_count=$(sed -n '1p' "$LLM_STATS_FILE")
    failure_count=$(sed -n '2p' "$LLM_STATS_FILE")

    # Increment appropriate counter
    if [[ "$result" == "success" ]]; then
        ((success_count++))
    else
        ((failure_count++))
    fi

    # Write updated stats atomically
    {
        echo "$success_count"
        echo "$failure_count"
        echo "${success_count}/${failure_count}"
    } > "$LLM_STATS_FILE"

    log "LLM stats: ${success_count}/${failure_count} (success/failure)"
}
# }}}

# -- {{{ show_llm_stats
show_llm_stats() {
    if [[ ! -f "$LLM_STATS_FILE" ]]; then
        echo "No LLM stats recorded yet"
        echo "  Stats file: $LLM_STATS_FILE"
        return 0
    fi

    local success_count failure_count ratio
    success_count=$(sed -n '1p' "$LLM_STATS_FILE")
    failure_count=$(sed -n '2p' "$LLM_STATS_FILE")
    ratio=$(sed -n '3p' "$LLM_STATS_FILE")

    local total=$((success_count + failure_count))
    local pct=0
    [[ $total -gt 0 ]] && pct=$((success_count * 100 / total))

    echo "LLM Statistics:"
    echo "  Model:     $LLM_MODEL"
    echo "  Successes: $success_count"
    echo "  Failures:  $failure_count"
    echo "  Ratio:     $ratio ($pct% success rate)"
    echo "  Stats file: $LLM_STATS_FILE"
}
# }}}

# -- {{{ reset_llm_stats
reset_llm_stats() {
    mkdir -p "$(dirname "$LLM_STATS_FILE")"
    {
        echo "0"
        echo "0"
        echo "0/0"
    } > "$LLM_STATS_FILE"
    echo "LLM stats reset to 0/0"
}
# }}}

# -- {{{ check_llm_available
check_llm_available() {
    # Check if ollama API endpoint is reachable
    if ! curl -s --max-time 5 "${OLLAMA_ENDPOINT}/api/tags" &>/dev/null; then
        log "Ollama endpoint not responding: ${OLLAMA_ENDPOINT}"
        return 1
    fi

    # Check if model is available
    local models
    models=$(curl -s "${OLLAMA_ENDPOINT}/api/tags" 2>/dev/null)
    if ! echo "$models" | grep -q "\"name\":\"${LLM_MODEL}"; then
        log "Model '$LLM_MODEL' not found at ${OLLAMA_ENDPOINT}. Run: ollama pull $LLM_MODEL"
        return 1
    fi

    log "LLM available: ${LLM_MODEL} at ${OLLAMA_ENDPOINT}"
    return 0
}
# }}}

# -- {{{ query_local_llm
query_local_llm() {
    local prompt="$1"

    if [[ "$LLM_ENABLED" != true ]]; then
        return 1
    fi

    # Create temp files for request/response
    local request_file="/tmp/llm_request_$$.json"
    local response_file="/tmp/llm_response_$$.json"

    # Build JSON request (escape special chars in prompt)
    local escaped_prompt
    escaped_prompt=$(echo "$prompt" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' ' ')

    cat > "$request_file" << JSONEOF
{"model": "${LLM_MODEL}", "messages": [{"role": "user", "content": "${escaped_prompt}"}], "stream": false}
JSONEOF

    # Query using curl
    curl -s -X POST "${OLLAMA_ENDPOINT}/api/chat" \
        -H "Content-Type: application/json" \
        -d @"$request_file" > "$response_file" 2>/dev/null

    # Extract response content
    local response
    response=$(grep -o '"content":"[^"]*"' "$response_file" | sed 's/"content":"//;s/"$//' | head -1)

    # Cleanup
    rm -f "$request_file" "$response_file"

    if [[ -z "$response" ]]; then
        log "LLM returned empty response"
        return 1
    fi

    # Return response (unescape basic chars)
    echo "$response" | sed 's/\\n/\n/g; s/\\t/\t/g'
}
# }}}

# -- {{{ llm_triple_check
llm_triple_check() {
    local question="$1"

    if [[ "$LLM_ENABLED" != true ]]; then
        return 1
    fi

    local -a responses=()
    local i

    log "LLM triple-check: Querying $LLM_VERIFY_COUNT times..."

    # Get N responses (default 3)
    for ((i = 1; i <= LLM_VERIFY_COUNT; i++)); do
        local response
        response=$(query_local_llm "$question")
        responses+=("$response")
        log "  Response $i: $response"
    done

    # Output as newline-separated for easy parsing
    printf '%s\n' "${responses[@]}"
}
# }}}

# -- {{{ llm_get_consensus
llm_get_consensus() {
    # Read responses from stdin (newline-separated)
    local -a responses=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && responses+=("$line")
    done

    if [[ ${#responses[@]} -lt 2 ]]; then
        log "Not enough responses for consensus"
        record_llm_result "failure"
        return 1
    fi

    # Count occurrences of each response
    local -A counts
    for r in "${responses[@]}"; do
        ((counts["$r"]++)) || counts["$r"]=1
    done

    # Find response with majority (2/3 or more)
    local threshold=$(( (${#responses[@]} + 1) / 2 ))  # Ceiling of half

    for r in "${!counts[@]}"; do
        if [[ ${counts[$r]} -ge $threshold ]]; then
            log "LLM consensus reached: '$r' (${counts[$r]}/${#responses[@]} agree)"
            record_llm_result "success"
            echo "$r"
            return 0
        fi
    done

    # No consensus
    log "LLM no consensus: responses were ${responses[*]}"
    record_llm_result "failure"
    return 1
}
# }}}

# -- {{{ generate_commit_message_llm
generate_commit_message_llm() {
    # Generate a descriptive commit message body from issue file content
    local issue_file="$1"
    local title="$2"

    if [[ "$LLM_ENABLED" != true ]]; then
        return 1
    fi

    # Read issue content (first 1500 chars to avoid token limits)
    local issue_content
    issue_content=$(head -c 1500 "$issue_file" 2>/dev/null)

    if [[ -z "$issue_content" ]]; then
        return 1
    fi

    # Build prompt with few-shot example - direct instruction to avoid preamble
    local prompt
    prompt="You are a git commit message generator. Output ONLY the summary, no preamble, no 'Here is', no explanations. 2-3 sentences, past tense, start with a verb.

Example input: Issue #012: Create Lane System
Example output: Implemented lane system with 5 parallel sub-paths per main lane. Each sub-path connects spawn points with configurable spacing and collision boundaries.

Your turn. Output only the summary:
${title}

${issue_content}"

    local response
    response=$(query_local_llm "$prompt")

    if [[ -n "$response" ]]; then
        # Minimal cleanup - just trim whitespace
        echo "$response" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
    else
        return 1
    fi
}
# }}}

# -- {{{ resolve_ambiguous_ordering
resolve_ambiguous_ordering() {
    local issue1_file="$1"
    local issue2_file="$2"

    if [[ "$LLM_ENABLED" != true ]]; then
        echo "numerical"
        return
    fi

    local issue1_name issue2_name
    issue1_name=$(basename "$issue1_file" .md)
    issue2_name=$(basename "$issue2_file" .md)

    local issue1_title issue2_title
    issue1_title=$(extract_issue_title "$issue1_file")
    issue2_title=$(extract_issue_title "$issue2_file")

    local prompt="Given these two software development issues, which one should logically come FIRST in the development timeline?

Issue A: $issue1_name
Title: $issue1_title

Issue B: $issue2_name
Title: $issue2_title

Answer with ONLY the letter A or B, nothing else."

    local consensus
    if consensus=$(llm_triple_check "$prompt" | llm_get_consensus); then
        case "$consensus" in
            A|a) echo "$issue1_name" ;;
            B|b) echo "$issue2_name" ;;
            *) echo "numerical" ;;
        esac
    else
        echo "numerical"
    fi
}
# }}}

# -- {{{ resolve_ambiguous_file_association
resolve_ambiguous_file_association() {
    local file="$1"
    local issue1_file="$2"
    local issue2_file="$3"

    if [[ "$LLM_ENABLED" != true ]]; then
        echo "first"
        return
    fi

    local file_name issue1_name issue2_name
    file_name=$(basename "$file")
    issue1_name=$(basename "$issue1_file" .md)
    issue2_name=$(basename "$issue2_file" .md)

    local issue1_title issue2_title
    issue1_title=$(extract_issue_title "$issue1_file")
    issue2_title=$(extract_issue_title "$issue2_file")

    local prompt="A source file named '$file_name' could belong to either of these issues. Which issue most likely created or modified this file?

Issue A: $issue1_name - $issue1_title
Issue B: $issue2_name - $issue2_title

Answer with ONLY the letter A or B, nothing else."

    local consensus
    if consensus=$(llm_triple_check "$prompt" | llm_get_consensus); then
        case "$consensus" in
            A|a) echo "$issue1_name" ;;
            B|b) echo "$issue2_name" ;;
            *) echo "first" ;;
        esac
    else
        echo "first"
    fi
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

# -- {{{ save_post_blob_commits
save_post_blob_commits() {
    local project_dir="$1"
    local blob_commit="$2"
    local output_file="$3"

    cd "$project_dir" || return 1

    # Save commit hashes with metadata for cherry-pick
    # Format: HASH|ISO_DATE|AUTHOR_NAME|AUTHOR_EMAIL|SUBJECT
    git log --reverse --format='%H|%aI|%an|%ae|%s' \
        "${blob_commit}..HEAD" > "$output_file" 2>/dev/null

    local count
    count=$(wc -l < "$output_file" 2>/dev/null || echo "0")

    if [[ "$count" -gt 0 ]]; then
        log "Found $count post-blob commits to preserve"
        return 0
    else
        log "No post-blob commits found"
        return 1
    fi
}
# }}}

# -- {{{ apply_post_blob_commits
apply_post_blob_commits() {
    local project_dir="$1"
    local commits_file="$2"

    cd "$project_dir" || return 1

    local applied=0
    local failed=0
    local skipped=0

    echo "  Applying post-blob commits..."

    while IFS='|' read -r hash date author email message; do
        # Skip empty lines
        [[ -z "$hash" ]] && continue

        log "  Applying: $message"

        # Attempt cherry-pick with original author and date
        if GIT_AUTHOR_DATE="$date" \
           GIT_AUTHOR_NAME="$author" \
           GIT_AUTHOR_EMAIL="$email" \
           git cherry-pick --no-commit "$hash" 2>/dev/null; then

            # Check if there's anything to commit (cherry-pick might be empty after reconstruction)
            if ! git diff --cached --quiet 2>/dev/null; then
                # Commit with preserved metadata
                GIT_AUTHOR_DATE="$date" \
                GIT_AUTHOR_NAME="$author" \
                GIT_AUTHOR_EMAIL="$email" \
                GIT_COMMITTER_DATE="$date" \
                git commit -m "$message" 2>/dev/null

                echo "      + Applied: $message"
                ((applied++))
            else
                # No changes to commit (already included in reconstruction)
                log "      - Skipped (no changes): $message"
                ((skipped++))
            fi
        else
            # Cherry-pick failed - likely conflict
            echo "      ! FAILED: $message (${hash:0:7})"
            echo "        Aborting cherry-pick and continuing..."
            git cherry-pick --abort 2>/dev/null
            git reset --hard HEAD 2>/dev/null
            ((failed++))
        fi
    done < "$commits_file"

    echo ""
    echo "  Post-blob commit results:"
    echo "    Applied: $applied"
    echo "    Skipped: $skipped (already in reconstruction)"
    echo "    Failed:  $failed"

    [[ "$failed" -gt 0 ]] && return 1
    return 0
}
# }}}

# -- {{{ get_current_branch
get_current_branch() {
    local project_dir="$1"
    git -C "$project_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD"
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

    # Check if there are any actual dependencies (not just "id:" lines with empty deps)
    local has_deps=false
    while IFS=':' read -r id deps; do
        if [[ -n "$deps" && "$deps" =~ [0-9] ]]; then
            has_deps=true
            break
        fi
    done <<< "$graph_output"

    if [[ "$has_deps" == false ]]; then
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

# =============================================================================
# Date Estimation and Interpolation (035c)
# =============================================================================

# -- {{{ extract_explicit_date
extract_explicit_date() {
    local issue_file="$1"

    # Try to find explicit completion date in various formats
    local date_patterns=(
        'Completed:\s*[0-9]{4}-[0-9]{2}-[0-9]{2}'
        'Status:\s*Completed\s*[0-9]{4}-[0-9]{2}-[0-9]{2}'
        'Date:\s*[0-9]{4}-[0-9]{2}-[0-9]{2}'
        '\*\*Completed\*\*:\s*[0-9]{4}-[0-9]{2}-[0-9]{2}'
        '\*\*Completed:\*\*\s*[0-9]{4}-[0-9]{2}-[0-9]{2}'
    )

    for pattern in "${date_patterns[@]}"; do
        local match
        match=$(grep -oE "$pattern" "$issue_file" 2>/dev/null | head -1)
        if [[ -n "$match" ]]; then
            # Extract just the date part
            local date_str
            date_str=$(echo "$match" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
            if [[ -n "$date_str" ]]; then
                # Validate date and convert to epoch
                local epoch
                epoch=$(date -d "$date_str" +%s 2>/dev/null)
                if [[ -n "$epoch" ]]; then
                    echo "$epoch"
                    return 0
                fi
            fi
        fi
    done

    return 1
}
# }}}

# -- {{{ get_file_mtime
get_file_mtime() {
    local file_path="$1"
    stat -c %Y "$file_path" 2>/dev/null || echo "0"
}
# }}}

# -- {{{ estimate_issue_date
estimate_issue_date() {
    local issue_file="$1"

    # Try explicit date first
    local explicit_date
    explicit_date=$(extract_explicit_date "$issue_file")
    if [[ -n "$explicit_date" && "$explicit_date" != "0" ]]; then
        log "  Date for $(basename "$issue_file"): explicit ($explicit_date)"
        echo "$explicit_date"
        return 0
    fi

    # Fall back to file modification time
    local mtime
    mtime=$(get_file_mtime "$issue_file")
    if [[ "$mtime" != "0" ]]; then
        log "  Date for $(basename "$issue_file"): mtime ($mtime)"
        echo "$mtime"
        return 0
    fi

    # Last resort: current time
    date +%s
}
# }}}

# -- {{{ interpolate_dates
interpolate_dates() {
    # Input: file paths on stdin
    # Output: "filepath:epoch" lines
    #
    # Fills in gaps between known dates for smoother progression

    local -a files=()
    local -A file_dates=()  # file -> epoch
    local -A date_source=() # file -> "explicit" or "mtime" or "interpolated"

    # Read all files and get initial dates
    local count=0
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        files+=("$file")
        ((count++)) || true  # Prevent set -e from exiting when count was 0

        # Try explicit date first, then mtime - avoids double grep
        local explicit_date
        explicit_date=$(extract_explicit_date "$file" 2>/dev/null) || true  # May return 1 if no explicit date
        if [[ -n "$explicit_date" && "$explicit_date" != "0" ]]; then
            file_dates["$file"]="$explicit_date"
            date_source["$file"]="explicit"
        else
            file_dates["$file"]=$(get_file_mtime "$file")
            date_source["$file"]="mtime"
        fi
    done
    log "interpolate_dates: read $count files"

    if [[ ${#files[@]} -eq 0 ]]; then
        return 0
    fi

    # Interpolate missing/suspicious dates
    # A date is suspicious if it's significantly out of sequence
    local prev_date=""
    local prev_idx=-1

    for ((i=0; i<${#files[@]}; i++)); do
        local file="${files[$i]}"
        local curr_date="${file_dates[$file]}"

        if [[ -n "$prev_date" ]]; then
            # Check if current date is before previous (out of order)
            if [[ "$curr_date" -lt "$prev_date" ]]; then
                log "  WARNING: $(basename "$file") date ($curr_date) before previous ($prev_date), interpolating"

                # Interpolate: add 1 hour from previous
                local new_date=$((prev_date + 3600))
                file_dates["$file"]="$new_date"
                date_source["$file"]="interpolated"
            fi
        fi

        prev_date="${file_dates[$file]}"
    done

    # Apply sanity checks
    local now
    now=$(date +%s)

    for file in "${files[@]}"; do
        local date="${file_dates[$file]}"

        # No future dates
        if [[ "$date" -gt "$now" ]]; then
            log "  WARNING: $(basename "$file") has future date, using now"
            file_dates["$file"]="$now"
            date_source["$file"]="clamped"
        fi

        # No dates before 2020 (likely mtime corruption)
        local min_date
        min_date=$(date -d "2020-01-01" +%s)
        if [[ "$date" -lt "$min_date" ]]; then
            log "  WARNING: $(basename "$file") has ancient date, using min"
            file_dates["$file"]="$min_date"
            date_source["$file"]="clamped"
        fi
    done

    # Output results
    for file in "${files[@]}"; do
        echo "${file}:${file_dates[$file]}:${date_source[$file]}"
    done
}
# }}}

# -- {{{ format_epoch_for_git
format_epoch_for_git() {
    local epoch="$1"
    date -d "@$epoch" '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S %z'
}
# }}}

# =============================================================================
# File-to-Issue Association Heuristics (035d)
# =============================================================================

# -- {{{ File Association Configuration
ASSOC_MTIME_THRESHOLD="${ASSOC_MTIME_THRESHOLD:-3600}"   # 1 hour proximity threshold
ASSOC_MIN_SIMILARITY="${ASSOC_MIN_SIMILARITY:-50}"       # Minimum name similarity (0-100)
ASSOC_VERBOSE="${ASSOC_VERBOSE:-false}"                  # Show association reasoning
# }}}

# -- {{{ extract_mentioned_paths
extract_mentioned_paths() {
    local issue_file="$1"

    # Extract file paths from backticks: `src/foo.lua`
    local backtick_paths
    backtick_paths=$(grep -oE '\`[^`]*\.(lua|sh|py|js|ts|c|h|rs|go|json|yaml|yml|toml|conf|cfg)\`' "$issue_file" 2>/dev/null | \
                     tr -d '`' | sort -u)

    # Extract paths from "Files Changed" or "Files Modified" sections
    local section_paths
    section_paths=$(sed -n '/^##.*[Ff]iles/,/^##/p' "$issue_file" 2>/dev/null | \
                    grep -oE '[a-zA-Z0-9_/./-]+\.[a-z]+' | sort -u)

    # Also look for paths in bullet points: - `path/to/file.lua`
    local bullet_paths
    bullet_paths=$(grep -oE '^\s*[-*]\s*\`[^`]+\`' "$issue_file" 2>/dev/null | \
                   grep -oE '[a-zA-Z0-9_/./-]+\.[a-z]+' | sort -u)

    # Combine and deduplicate
    echo -e "${backtick_paths}\n${section_paths}\n${bullet_paths}" | sort -u | grep -v '^$'
}
# }}}

# -- {{{ extract_mentioned_directories
extract_mentioned_directories() {
    local issue_file="$1"

    # Extract directory paths from backticks: `src/parsers/`
    local backtick_dirs
    backtick_dirs=$(grep -oE '\`[^`]+/\`' "$issue_file" 2>/dev/null | tr -d '`')

    # Extract from prose: "in the src/parsers directory" or "src/parsers/ folder"
    local prose_dirs
    prose_dirs=$(grep -oE '[a-zA-Z0-9_-]+(/[a-zA-Z0-9_-]+)*/' "$issue_file" 2>/dev/null | \
                 grep -v '^//' | sort -u)

    echo -e "${backtick_dirs}\n${prose_dirs}" | sort -u | grep -v '^$'
}
# }}}

# -- {{{ calculate_name_similarity
calculate_name_similarity() {
    local issue_name="$1"   # e.g., "002-build-parser-module"
    local file_name="$2"    # e.g., "parser-module.lua"

    # Extract keywords from issue name (remove number prefix)
    local issue_clean
    issue_clean=$(echo "$issue_name" | sed 's/^[0-9]*[a-z]*-//')

    # Extract keywords from file name (remove extension)
    local file_clean
    file_clean=$(echo "$file_name" | sed 's/\.[^.]*$//')

    # Split into keywords
    local -a issue_keywords
    IFS='-_' read -ra issue_keywords <<< "$issue_clean"

    local -a file_keywords
    IFS='-_' read -ra file_keywords <<< "$file_clean"

    # Count matching keywords
    local matches=0
    local total=${#issue_keywords[@]}

    for issue_kw in "${issue_keywords[@]}"; do
        [[ -z "$issue_kw" ]] && continue
        for file_kw in "${file_keywords[@]}"; do
            # Case-insensitive comparison
            if [[ "${issue_kw,,}" == "${file_kw,,}" ]]; then
                ((matches++))
                break
            fi
        done
    done

    # Return similarity as percentage (0-100)
    if [[ $total -gt 0 ]]; then
        echo $((matches * 100 / total))
    else
        echo "0"
    fi
}
# }}}

# -- {{{ check_mtime_proximity
check_mtime_proximity() {
    local file_path="$1"
    local issue_mtime="$2"
    local threshold="${ASSOC_MTIME_THRESHOLD}"

    local file_mtime
    file_mtime=$(stat -c %Y "$file_path" 2>/dev/null || echo "0")

    local delta=$((file_mtime - issue_mtime))
    [[ $delta -lt 0 ]] && delta=$((-delta))

    # Return true (0) if within threshold
    [[ $delta -le $threshold ]]
}
# }}}

# -- {{{ associate_files_with_issues
associate_files_with_issues() {
    local project_dir="$1"
    local issues_dir="${project_dir}/issues/completed"

    # Get all project files (excluding .git, issues, and common non-code files)
    local -a all_files
    mapfile -t all_files < <(find "$project_dir" -type f \
        ! -path "*/.git/*" \
        ! -path "*/issues/*" \
        ! -path "*/node_modules/*" \
        ! -name "*.md" \
        ! -name ".gitignore" \
        ! -name "LICENSE" \
        ! -name "README*" \
        2>/dev/null | sort)

    if [[ ${#all_files[@]} -eq 0 ]]; then
        return 0
    fi

    # Track associations
    local -A file_to_issue   # file -> issue_id
    local -A issue_to_files  # issue_id -> "file1 file2 file3"

    # Get ordered issues with their dates
    local -a issues
    mapfile -t issues < <(discover_completed_issues "$project_dir")

    if [[ ${#issues[@]} -eq 0 ]]; then
        return 0
    fi

    # Get estimated dates for all issues
    local -A issue_dates
    while IFS=':' read -r file epoch source; do
        [[ -z "$file" ]] && continue
        issue_dates["$file"]="$epoch"
    done < <(printf '%s\n' "${issues[@]}" | interpolate_dates 2>/dev/null)

    # Process each issue to find associated files
    for issue_file in "${issues[@]}"; do
        local issue_id
        issue_id=$(extract_issue_id "$issue_file")
        [[ -z "$issue_id" ]] && continue

        issue_to_files["$issue_id"]=""

        # Get issue metadata
        local issue_mtime="${issue_dates[$issue_file]:-$(date +%s)}"
        local issue_name
        issue_name=$(basename "$issue_file" .md)

        # Extract mentioned paths and directories from issue content
        local -a mentioned_paths=()
        local -a mentioned_dirs=()

        while IFS= read -r path; do
            [[ -n "$path" ]] && mentioned_paths+=("$path")
        done < <(extract_mentioned_paths "$issue_file")

        while IFS= read -r dir; do
            [[ -n "$dir" ]] && mentioned_dirs+=("$dir")
        done < <(extract_mentioned_directories "$issue_file")

        # Process each project file
        for file in "${all_files[@]}"; do
            # Skip if already associated with a previous issue
            [[ -n "${file_to_issue[$file]:-}" ]] && continue

            local file_basename file_relative
            file_basename=$(basename "$file")
            file_relative="${file#$project_dir/}"

            local matched=false
            local match_reason=""

            # Heuristic 1: Explicit path match
            for path in "${mentioned_paths[@]}"; do
                if [[ "$file_relative" == "$path" ]] || \
                   [[ "$file_relative" == *"/$path" ]] || \
                   [[ "$file_relative" == *"$path" ]]; then
                    matched=true
                    match_reason="explicit_path"
                    break
                fi
            done

            # Heuristic 2: Filename mention (basename match)
            if [[ "$matched" == false ]]; then
                for path in "${mentioned_paths[@]}"; do
                    local mentioned_basename
                    mentioned_basename=$(basename "$path")
                    if [[ "$file_basename" == "$mentioned_basename" ]]; then
                        matched=true
                        match_reason="filename_mention"
                        break
                    fi
                done
            fi

            # Heuristic 3: Directory mention
            if [[ "$matched" == false ]]; then
                for dir in "${mentioned_dirs[@]}"; do
                    # Normalize directory (ensure trailing slash removed for comparison)
                    local dir_clean="${dir%/}"
                    if [[ "$file_relative" == "$dir_clean"/* ]] || \
                       [[ "$file_relative" == *"/$dir_clean"/* ]]; then
                        matched=true
                        match_reason="directory_mention"
                        break
                    fi
                done
            fi

            # Heuristic 4: Naming convention similarity
            if [[ "$matched" == false ]]; then
                local similarity
                similarity=$(calculate_name_similarity "$issue_name" "$file_basename")
                if [[ "$similarity" -ge "$ASSOC_MIN_SIMILARITY" ]]; then
                    matched=true
                    match_reason="naming_convention(${similarity}%)"
                fi
            fi

            # Heuristic 5: Mtime proximity (lowest priority, disabled by default)
            # Uncomment to enable mtime-based association
            # if [[ "$matched" == false ]]; then
            #     if check_mtime_proximity "$file" "$issue_mtime"; then
            #         matched=true
            #         match_reason="mtime_proximity"
            #     fi
            # fi

            # Record association
            if [[ "$matched" == true ]]; then
                file_to_issue["$file"]="$issue_id"
                issue_to_files["$issue_id"]+="$file_relative "

                if [[ "$ASSOC_VERBOSE" == true ]] || [[ "$VERBOSE" == true ]]; then
                    log "    Association: $file_relative → $issue_id ($match_reason)"
                fi
            fi
        done
    done

    # Output associations as "issue_id:file1 file2 file3"
    for issue_id in "${!issue_to_files[@]}"; do
        local files="${issue_to_files[$issue_id]}"
        # Trim trailing space
        files="${files% }"
        [[ -n "$files" ]] && echo "$issue_id:$files"
    done
}
# }}}

# -- {{{ get_vision_date
get_vision_date() {
    local project_dir="$1"
    local vision_file="$2"

    # Vision date should be the earliest known date
    # Try to get date from vision file itself, or use its mtime

    local vision_path="${project_dir}/${vision_file}"

    # Check for date in vision file
    local explicit_date
    explicit_date=$(extract_explicit_date "$vision_path" 2>/dev/null)
    if [[ -n "$explicit_date" && "$explicit_date" != "0" ]]; then
        echo "$explicit_date"
        return 0
    fi

    # Use file mtime
    local mtime
    mtime=$(get_file_mtime "$vision_path")
    if [[ "$mtime" != "0" ]]; then
        echo "$mtime"
        return 0
    fi

    # No good date found, return empty (will use current time)
    echo ""
}
# }}}

# -- {{{ create_vision_commit
create_vision_commit() {
    local vision_file="$1"
    local project_name="$2"
    local commit_date="${3:-}"  # Optional: epoch timestamp

    log "Creating vision commit for: $vision_file"

    git add "$vision_file"

    # Check if there's anything to commit
    if ! git diff --cached --quiet; then
        # Set commit date if provided
        local date_args=()
        if [[ -n "$commit_date" ]]; then
            local git_date
            git_date=$(format_epoch_for_git "$commit_date")
            date_args=(--date="$git_date")
            export GIT_AUTHOR_DATE="$git_date"
            export GIT_COMMITTER_DATE="$git_date"
            log "  Using date: $git_date"
        fi

        git commit "${date_args[@]}" -m "$(cat <<EOF
Initial vision: ${project_name} project purpose and goals

Establishes the foundational vision for this project.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: reconstruct-history.sh <noreply@delta-version>
EOF
)"
        # Unset date environment
        unset GIT_AUTHOR_DATE GIT_COMMITTER_DATE
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
    local commit_date="${2:-}"      # Optional: epoch timestamp
    local associated_files="${3:-}" # Optional: space-separated list of associated files
    local issue_name
    local title

    issue_name=$(basename "$issue_file" .md)
    title=$(extract_issue_title "$issue_file")

    log "Creating issue commit for: $issue_name"

    # Add issue file
    git add "$issue_file"

    # Add associated source files (035d)
    local file_count=0
    if [[ -n "$associated_files" ]]; then
        for file in $associated_files; do
            if [[ -f "$file" ]]; then
                git add "$file"
                ((file_count++))
                log "  + $file (associated)"
            fi
        done
    fi

    # Check if there's anything to commit
    if ! git diff --cached --quiet; then
        # Set commit date if provided
        local date_args=()
        if [[ -n "$commit_date" ]]; then
            local git_date
            git_date=$(format_epoch_for_git "$commit_date")
            date_args=(--date="$git_date")
            export GIT_AUTHOR_DATE="$git_date"
            export GIT_COMMITTER_DATE="$git_date"
            log "  Using date: $git_date"
        fi

        # Build commit message with file count if files were associated
        local file_summary=""
        [[ $file_count -gt 0 ]] && file_summary=" (+${file_count} files)"

        # Try to generate descriptive message body with LLM
        local message_body=""
        if [[ "$LLM_ENABLED" == true ]]; then
            log "  Generating commit message with LLM..."
            message_body=$(generate_commit_message_llm "$issue_file" "$title") || true
        fi

        # Fallback to generic message if LLM not available or failed
        if [[ -z "$message_body" ]]; then
            message_body="Completed issue ${issue_name}$([ $file_count -gt 0 ] && echo " with associated implementation files")."
        fi

        git commit "${date_args[@]}" -m "$(cat <<EOF
${title}${file_summary}

${message_body}

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: reconstruct-history.sh <noreply@delta-version>
EOF
)"
        # Unset date environment
        unset GIT_AUTHOR_DATE GIT_COMMITTER_DATE
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
    local vision_file vision_date
    if vision_file=$(find_vision_file "$project_dir"); then
        # Estimate vision date
        vision_date=$(get_vision_date "$project_dir" "$vision_file")
        local date_display=""
        if [[ -n "$vision_date" ]]; then
            date_display=" ($(date -d "@$vision_date" '+%Y-%m-%d'))"
        fi

        echo "  [1] Vision: $vision_file$date_display"
        if create_vision_commit "$vision_file" "$project_name" "$vision_date"; then
            ((commit_count++)) || true
        fi
    else
        echo "  [!] No vision file found, skipping vision commit"
    fi

    # Step 2: Issue commits (ordered by dependencies via topological sort)
    local -a completed_issues
    mapfile -t completed_issues < <(order_issues_by_dependencies "$project_dir")

    if [[ ${#completed_issues[@]} -gt 0 ]]; then
        echo "  [2] Processing ${#completed_issues[@]} completed issue(s) (dependency-ordered)..."

        # Estimate dates for all issues and interpolate
        local -A issue_dates
        while IFS=':' read -r file epoch source; do
            [[ -z "$file" ]] && continue
            issue_dates["$file"]="$epoch"
            log "  Date source for $(basename "$file"): $source"
        done < <(printf '%s\n' "${completed_issues[@]}" | interpolate_dates)

        # Build file-to-issue associations (035d) - skip if flag set
        local -A issue_file_map
        if [[ "$SKIP_FILE_ASSOCIATION" != true ]]; then
            echo "      Building file associations..."
            while IFS=':' read -r issue_id files; do
                [[ -z "$issue_id" ]] && continue
                issue_file_map["$issue_id"]="$files"
                log "    $issue_id -> $files"
            done < <(associate_files_with_issues "$project_dir")
        fi

        for issue_file in "${completed_issues[@]}"; do
            local issue_name issue_date date_display issue_id associated_files
            issue_name=$(basename "$issue_file" .md)
            issue_date="${issue_dates[$issue_file]:-}"
            issue_id=$(extract_issue_id "$issue_file")
            associated_files="${issue_file_map[$issue_id]:-}"

            date_display=""
            if [[ -n "$issue_date" ]]; then
                date_display=" ($(date -d "@$issue_date" '+%Y-%m-%d'))"
            fi

            local file_count=0
            [[ -n "$associated_files" ]] && file_count=$(echo "$associated_files" | wc -w)
            local file_info=""
            [[ $file_count -gt 0 ]] && file_info=" [+${file_count} files]"

            echo "      - $issue_name$date_display$file_info"
            if create_issue_commit "$issue_file" "$issue_date" "$associated_files"; then
                ((commit_count++)) || true
            fi
        done
    else
        echo "  [2] No completed issues found"
    fi

    # Step 3: Bulk commit for remaining files
    echo "  [3] Importing remaining project files..."
    if create_bulk_commit "$project_name"; then
        ((commit_count++)) || true
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

# -- {{{ reconstruct_history_with_rebase
reconstruct_history_with_rebase() {
    # Reconstructs history for a project that has existing git history,
    # preserving any commits made after the initial blob import.
    #
    # Workflow:
    # 1. Identify blob boundary (where the bulk import ends)
    # 2. Save post-blob commits to temp file
    # 3. Create orphan branch with reconstructed history
    # 4. Cherry-pick post-blob commits onto new history
    # 5. Optionally replace original branch

    local project_dir="$1"
    local project_name
    project_name=$(basename "$project_dir")

    # Validate project directory
    if [[ ! -d "$project_dir" ]]; then
        error "Project directory not found: $project_dir"
        return 1
    fi

    if [[ ! -d "${project_dir}/.git" ]]; then
        error "No git repository found at: $project_dir"
        error "Use regular reconstruct_history for projects without git"
        return 1
    fi

    cd "$project_dir" || return 1

    echo "=== History Reconstruction with Rebase ==="
    echo "Project: $project_name"
    echo ""

    # Step 1: Identify blob boundary
    echo "[1/5] Identifying blob boundary..."
    local blob_boundary
    blob_boundary=$(get_blob_boundary "$project_dir")

    if [[ -z "$blob_boundary" ]]; then
        error "Could not identify blob boundary"
        return 1
    fi
    echo "      Blob commit: ${blob_boundary:0:7}"

    # Step 2: Save post-blob commits
    echo "[2/5] Saving post-blob commits..."
    POST_BLOB_COMMIT_FILE=$(mktemp)
    local has_post_blob=false

    if save_post_blob_commits "$project_dir" "$blob_boundary" "$POST_BLOB_COMMIT_FILE"; then
        has_post_blob=true
        local post_count
        post_count=$(wc -l < "$POST_BLOB_COMMIT_FILE")
        echo "      Found $post_count commits to preserve"
    else
        echo "      No post-blob commits found"
    fi

    # Step 3: Store original branch name and create backup
    ORIGINAL_BRANCH=$(get_current_branch "$project_dir")
    echo "      Original branch: $ORIGINAL_BRANCH"

    # Create backup branch
    local backup_branch="backup-${ORIGINAL_BRANCH}-$(date +%Y%m%d-%H%M%S)"
    git branch "$backup_branch" 2>/dev/null
    echo "      Backup created: $backup_branch"
    echo ""

    # Step 4: Create orphan branch with reconstructed history
    echo "[3/5] Creating reconstructed history on orphan branch..."
    local orphan_branch="reconstructed-history-$(date +%Y%m%d-%H%M%S)"

    # Create orphan branch
    git checkout --orphan "$orphan_branch" 2>/dev/null
    git rm -rf --cached . 2>/dev/null || true

    local commit_count=0

    # 4a: Vision commit
    local vision_file vision_date
    if vision_file=$(find_vision_file "$project_dir"); then
        vision_date=$(get_vision_date "$project_dir" "$vision_file")
        local date_display=""
        if [[ -n "$vision_date" ]]; then
            date_display=" ($(date -d "@$vision_date" '+%Y-%m-%d'))"
        fi

        echo "      [1] Vision: $vision_file$date_display"
        if create_vision_commit "$vision_file" "$project_name" "$vision_date"; then
            ((commit_count++)) || true
        fi
    else
        echo "      [!] No vision file found, skipping vision commit"
    fi

    # 4b: Issue commits
    local -a completed_issues
    mapfile -t completed_issues < <(order_issues_by_dependencies "$project_dir")

    if [[ ${#completed_issues[@]} -gt 0 ]]; then
        echo "      [2] Processing ${#completed_issues[@]} completed issue(s)..."

        # Estimate dates
        local -A issue_dates
        while IFS=':' read -r file epoch source; do
            [[ -z "$file" ]] && continue
            issue_dates["$file"]="$epoch"
        done < <(printf '%s\n' "${completed_issues[@]}" | interpolate_dates)

        # Build file associations if enabled
        local -A issue_file_map
        if [[ "$SKIP_FILE_ASSOCIATION" != true ]]; then
            while IFS=':' read -r issue_id files; do
                [[ -z "$issue_id" ]] && continue
                issue_file_map["$issue_id"]="$files"
            done < <(associate_files_with_issues "$project_dir")
        fi

        for issue_file in "${completed_issues[@]}"; do
            local issue_name issue_date issue_id associated_files
            issue_name=$(basename "$issue_file" .md)
            issue_date="${issue_dates[$issue_file]:-}"
            issue_id=$(extract_issue_id "$issue_file")
            associated_files="${issue_file_map[$issue_id]:-}"

            echo "          - $issue_name"
            if create_issue_commit "$issue_file" "$issue_date" "$associated_files"; then
                ((commit_count++)) || true
            fi
        done
    else
        echo "      [2] No completed issues found"
    fi

    # 4c: Bulk commit
    echo "      [3] Importing remaining project files..."
    if create_bulk_commit "$project_name"; then
        ((commit_count++)) || true
    fi

    echo ""
    echo "      Reconstructed commits: $commit_count"

    # Step 5: Apply post-blob commits
    echo ""
    echo "[4/5] Applying post-blob commits..."
    if [[ "$has_post_blob" == true ]] && [[ "$PRESERVE_POST_BLOB" == true ]]; then
        apply_post_blob_commits "$project_dir" "$POST_BLOB_COMMIT_FILE"
    else
        echo "      No post-blob commits to apply"
    fi

    # Cleanup temp file
    rm -f "$POST_BLOB_COMMIT_FILE"

    # Step 6: Handle branch replacement
    echo ""
    echo "[5/5] Finalizing branches..."
    if [[ "$REPLACE_ORIGINAL" == true ]]; then
        echo "      Replacing original branch '$ORIGINAL_BRANCH' with reconstructed history"
        git branch -D "$ORIGINAL_BRANCH" 2>/dev/null || true
        git branch -m "$orphan_branch" "$ORIGINAL_BRANCH"
        echo "      Done. Backup preserved as: $backup_branch"
    else
        echo "      Reconstructed history is on branch: $orphan_branch"
        echo "      Original branch preserved as: $ORIGINAL_BRANCH"
        echo "      Backup preserved as: $backup_branch"
        echo ""
        echo "  To replace original branch, run:"
        echo "    git branch -D $ORIGINAL_BRANCH"
        echo "    git branch -m $orphan_branch $ORIGINAL_BRANCH"
        echo ""
        echo "  To restore from backup:"
        echo "    git checkout $backup_branch"
    fi

    echo ""
    echo "=== History Reconstruction Complete ==="
    echo ""
    echo "Recent commits on $orphan_branch:"
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
                echo "Found $post_blob_count commits after initial blob"
                echo "Blob boundary: $blob_boundary"
                echo ""

                if [[ "$FORCE" == true ]] && [[ "$PRESERVE_POST_BLOB" != true ]]; then
                    echo "WARNING: --force specified without --preserve-post-blob"
                    echo "         This will remove ALL history including post-blob commits"
                    echo ""
                    rm -rf "$project_dir/.git"
                    reconstruct_history "$project_dir"
                else
                    echo "Using rebase workflow to preserve post-blob commits..."
                    reconstruct_history_with_rebase "$project_dir"
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
            echo "    Blob boundary:     ${blob_boundary:0:7}"
            echo "    Post-blob commits: $post_blob_count"
            if [[ "$post_blob_count" -gt 0 ]]; then
                echo ""
                if [[ "$PRESERVE_POST_BLOB" == true ]]; then
                    echo "  Post-blob commits (will be PRESERVED via cherry-pick):"
                else
                    echo "  Post-blob commits (will be LOST - use --preserve-post-blob to keep):"
                fi
                git -C "$project_dir" log --oneline "${blob_boundary}..HEAD" 2>/dev/null | head -5 | sed 's/^/    /'
                local remaining=$((post_blob_count - 5))
                [[ $remaining -gt 0 ]] && echo "    ... and $remaining more"
                echo ""
                if [[ "$REPLACE_ORIGINAL" == true ]]; then
                    echo "  Branch handling: Original branch will be REPLACED"
                else
                    echo "  Branch handling: Reconstructed history on new branch (original preserved)"
                fi
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
    local vision_file vision_date
    if vision_file=$(find_vision_file "$project_dir" 2>/dev/null); then
        vision_date=$(get_vision_date "$project_dir" "$vision_file" 2>/dev/null)
        local date_str=""
        if [[ -n "$vision_date" ]]; then
            date_str=" @ $(date -d "@$vision_date" '+%Y-%m-%d')"
        fi
        echo "    + $vision_file$date_str"
    else
        echo "    (no vision file found, would skip)"
    fi

    # Completed issues (dependency-ordered with estimated dates)
    echo ""
    echo "  Commits 2..N - Completed Issues (dependency-ordered with dates):"
    local -a completed_issues
    mapfile -t completed_issues < <(order_issues_by_dependencies "$project_dir")
    log "Found ${#completed_issues[@]} issues after dependency ordering"

    if [[ ${#completed_issues[@]} -gt 0 ]]; then
        # Get interpolated dates for all issues
        local -A issue_dates issue_sources
        while IFS=':' read -r file epoch source; do
            [[ -z "$file" ]] && continue
            issue_dates["$file"]="$epoch"
            issue_sources["$file"]="$source"
        done < <(printf '%s\n' "${completed_issues[@]}" | interpolate_dates)
        log "Interpolated dates for ${#issue_dates[@]} issues"

        # Build file-to-issue associations (035d) - skip if flag set
        local -A issue_file_map
        if [[ "$SKIP_FILE_ASSOCIATION" != true ]]; then
            while IFS=':' read -r issue_id files; do
                [[ -z "$issue_id" ]] && continue
                issue_file_map["$issue_id"]="$files"
            done < <(associate_files_with_issues "$project_dir" 2>/dev/null)
        fi

        # Count total associated files for summary
        local total_associated=0

        local i=2
        for issue_file in "${completed_issues[@]}"; do
            local issue_name title issue_id deps_info date_info
            issue_name=$(basename "$issue_file" .md)
            title=$(extract_issue_title "$issue_file")
            issue_id=$(extract_issue_id "$issue_file")

            # Show dependencies if any
            local deps
            deps=$(parse_issue_dependencies "$issue_file" 2>/dev/null) || true
            deps_info=""
            [[ -n "$deps" ]] && deps_info=" (depends on: $deps)"

            # Show estimated date
            date_info=""
            if [[ -n "${issue_dates[$issue_file]:-}" ]]; then
                local date_str source_str
                date_str=$(date -d "@${issue_dates[$issue_file]}" '+%Y-%m-%d')
                source_str="${issue_sources[$issue_file]:-unknown}"
                date_info=" @ $date_str [$source_str]"
            fi

            # Show associated files (035d)
            local associated="${issue_file_map[$issue_id]:-}"
            local file_count=0
            [[ -n "$associated" ]] && file_count=$(echo "$associated" | wc -w)
            local file_info=""
            [[ $file_count -gt 0 ]] && file_info=" [+${file_count} files]"
            ((total_associated += file_count)) || true  # May be 0

            echo "    [$i] $issue_name$deps_info$date_info$file_info"
            echo "        \"$title\""

            # Show associated files if verbose or if there are files
            if [[ $file_count -gt 0 ]] && [[ "$VERBOSE" == true ]]; then
                for assoc_file in $associated; do
                    echo "          + $assoc_file"
                done
            fi
            ((i++))
        done

        # Show association summary
        if [[ $total_associated -gt 0 ]]; then
            echo ""
            echo "  File Associations: $total_associated files will be associated with issues"
            echo "    (use --verbose to see details)"
        fi
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

LLM Options (requires ollama):
    --llm                Enable LLM integration for ambiguous decisions
    --llm-model NAME     Specify model (default: llama3)
    --llm-stats          Show LLM success/failure statistics
    --llm-reset-stats    Reset LLM statistics counters

Advanced Options:
    --with-file-association  Enable file-to-issue association (slower)

Post-Blob Commit Options:
    --preserve-post-blob     Preserve commits after blob (default: true)
    --no-preserve-post-blob  Skip post-blob commit preservation
    --replace-original       Replace original branch with reconstructed (DANGEROUS)

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
    - Initial blob commits are expanded into issue-based history
    - Post-blob commits are preserved via cherry-pick onto new history
    - Original branch is backed up, reconstructed history on new branch
    - Use --replace-original to swap the original branch

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

    # Enable LLM for ambiguous decisions
    reconstruct-history.sh --llm /path/to/project

    # Use a different model
    reconstruct-history.sh --llm --llm-model mistral /path/to/project

    # Check LLM success/failure statistics
    reconstruct-history.sh --llm-stats

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
            --llm)
                LLM_ENABLED=true
                shift
                ;;
            --llm-model)
                LLM_MODEL="$2"
                shift 2
                ;;
            --llm-stats)
                SHOW_LLM_STATS=true
                shift
                ;;
            --llm-reset-stats)
                RESET_LLM_STATS=true
                shift
                ;;
            --with-file-association)
                SKIP_FILE_ASSOCIATION=false
                shift
                ;;
            --preserve-post-blob)
                PRESERVE_POST_BLOB=true
                shift
                ;;
            --no-preserve-post-blob)
                PRESERVE_POST_BLOB=false
                shift
                ;;
            --replace-original)
                REPLACE_ORIGINAL=true
                shift
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

    # Handle LLM stats commands first (don't need project)
    if [[ "$SHOW_LLM_STATS" == true ]]; then
        show_llm_stats
        exit 0
    fi

    if [[ "$RESET_LLM_STATS" == true ]]; then
        reset_llm_stats
        exit 0
    fi

    # Check LLM availability if enabled
    if [[ "$LLM_ENABLED" == true ]]; then
        if check_llm_available; then
            echo "LLM enabled: $LLM_MODEL"
        else
            echo "WARNING: LLM requested but ollama not available, disabling"
            LLM_ENABLED=false
        fi
    fi

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
