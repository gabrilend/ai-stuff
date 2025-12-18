# Issue 035: Project History Reconstruction from Issue Files

## Current Behavior

Projects in the delta-version repository often exist as flat "initial commit" blobs — all files added at once with no development narrative. This obscures the project's evolution and makes git log/blame useless for understanding how the project grew.

### Current Issues
- Projects imported as single commits lose their development story
- Completed issue files contain timeline information not reflected in version control
- No tooling exists to rewrite history based on documentation
- File modification dates are lost or normalized during import
- The relationship between issue completion and code changes is invisible
- Reading through a project's history should feel like reading a story, not a data dump

### Current Implementation Status (v1)
A basic `reconstruct-history.sh` script exists at `/scripts/reconstruct-history.sh` that handles the simpler case:
- Creates new git history from projects WITHOUT existing git
- Commits: vision → issues → bulk files
- Does NOT rewrite existing history
- Does NOT estimate dates
- Does NOT analyze dependencies

## Intended Behavior

Create a **unified project onboarding and history reconstruction engine** that:
1. Detects whether the project is inside or outside the monorepo
2. Imports external projects if needed
3. Transforms flat blob commits into story-like progressions

### Unified Workflow
```
┌─────────────────────────────────────────────────────────────────┐
│                    reconstruct-history.sh                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐                                          │
│  │ Is project in    │                                          │
│  │ monorepo?        │                                          │
│  └────────┬─────────┘                                          │
│           │                                                     │
│     ┌─────┴─────┐                                              │
│     │           │                                              │
│    YES          NO                                             │
│     │           │                                              │
│     │     ┌─────▼─────────────┐                                │
│     │     │ Import project    │                                │
│     │     │ into monorepo     │                                │
│     │     │ (copy/move files) │                                │
│     │     └─────┬─────────────┘                                │
│     │           │                                              │
│     └─────┬─────┘                                              │
│           │                                                     │
│     ┌─────▼─────────────┐                                      │
│     │ Has flat blob     │                                      │
│     │ commit history?   │                                      │
│     └─────┬─────────────┘                                      │
│           │                                                     │
│     ┌─────┴─────┐                                              │
│     │           │                                              │
│    YES          NO (no git or already good history)            │
│     │           │                                              │
│     │     ┌─────▼─────────────┐                                │
│     │     │ Initialize git    │                                │
│     │     │ (v1 behavior)     │                                │
│     │     └─────┬─────────────┘                                │
│     │           │                                              │
│     └─────┬─────┘                                              │
│           │                                                     │
│     ┌─────▼─────────────────────┐                              │
│     │ Reconstruct history       │                              │
│     │ - Analyze dependencies    │                              │
│     │ - Estimate dates          │                              │
│     │ - Associate files→issues  │                              │
│     │ - Create orphan branch    │                              │
│     │ - Build commit sequence   │                              │
│     └─────┬─────────────────────┘                              │
│           │                                                     │
│     ┌─────▼─────────────────────┐                              │
│     │ Output: Project with      │                              │
│     │ story-like git history    │                              │
│     └───────────────────────────┘                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Detection Logic
```bash
# Is project inside monorepo?
is_in_monorepo() {
    local project_dir="$1"
    local monorepo_root="${MONOREPO_ROOT:-/mnt/mtwo/programming/ai-stuff}"

    # Check if project_dir is under monorepo_root
    [[ "$project_dir" == "$monorepo_root"/* ]]
}

# Has flat blob history? (single commit with all files)
has_flat_history() {
    local project_dir="$1"

    # Check if git exists
    [[ ! -d "$project_dir/.git" ]] && return 1

    # Count commits
    local commit_count=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null)

    # If only 1-2 commits and large file count, likely flat blob
    [[ "$commit_count" -le 2 ]]
}
```

### Phase 1: Basic Reconstruction ✅ (v1 Complete)
1. **Vision-First Commit**: First commit establishes project intent
2. **Issue-Based Commits**: One commit per completed issue
3. **Final Bulk Commit**: Remaining source code and assets

### Phase 2: History Rewriting (v2 - This Enhancement)
1. **Detect Project Location**: Inside or outside monorepo
2. **Import if External**: Copy/move project into monorepo structure
3. **Analyze Existing Repository**: Parse the flat blob commit(s)
4. **Extract Ordering Signals**: Gather evidence for chronological ordering
5. **Estimate Commit Dates**: Assign plausible timestamps
6. **Rewrite History**: Transform single commit into ordered sequence
7. **Associate Files with Issues**: Map source files to the issues that created them

### Ordering Signal Sources (Priority Order)
| Signal | Source | Reliability |
|--------|--------|-------------|
| Issue Dependencies | `Dependencies:` field in issue files | High |
| Issue Blocking | `Blocks:` / `Blocked By:` fields | High |
| Issue Number | Filename prefix (001, 002, ...) | Medium |
| Phase Number | Phase prefix in filename | Medium |
| File Modification Time | `stat -c %Y` / `mtime` | Medium |
| Directory Structure | When directories were created | Low |
| Issue Content Dates | Dates mentioned in issue text | Low |
| Local LLM Analysis | Ambiguity resolution | Variable |

### Commit Date Estimation Strategy
```
1. Parse issue files for explicit dates:
   - "Completed: 2024-12-15"
   - "Status: Completed 2024-12-15"
   - Date patterns in issue content

2. Use file modification times as fallback:
   - Issue file mtime = completion date
   - Source file mtime = creation date

3. Interpolate missing dates:
   - If issue 003 is between 001 and 005 with known dates
   - Estimate 003's date as interpolation

4. Apply sanity checks:
   - Commits must be chronologically ordered
   - No future dates
   - Reasonable gaps between commits
```

## Suggested Implementation Steps

### Phase 2 Implementation

### 0. Project Detection and Import Module
```bash
# -- {{{ Configuration
MONOREPO_ROOT="${MONOREPO_ROOT:-/mnt/mtwo/programming/ai-stuff}"
IMPORT_MODE="${IMPORT_MODE:-copy}"  # copy or move
# }}}

# -- {{{ is_in_monorepo
is_in_monorepo() {
    local project_dir="$1"

    # Resolve to absolute path
    local abs_path=$(cd "$project_dir" 2>/dev/null && pwd)
    local abs_mono=$(cd "$MONOREPO_ROOT" 2>/dev/null && pwd)

    # Check if project_dir is under monorepo_root
    [[ "$abs_path" == "$abs_mono"/* ]]
}
# }}}

# -- {{{ has_flat_history
has_flat_history() {
    local project_dir="$1"

    # No git = not flat history (needs initialization)
    [[ ! -d "$project_dir/.git" ]] && return 1

    # Count commits on current branch
    local commit_count=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null || echo "0")

    # Count total files in repo
    local file_count=$(git -C "$project_dir" ls-files | wc -l)

    # Heuristic: flat blob if few commits but many files
    # 1-2 commits with >50 files = likely flat import
    [[ "$commit_count" -le 2 && "$file_count" -gt 50 ]]
}
# }}}

# -- {{{ has_good_history
has_good_history() {
    local project_dir="$1"

    # No git = no history
    [[ ! -d "$project_dir/.git" ]] && return 1

    # Check commit count vs file count ratio
    local commit_count=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null || echo "0")
    local file_count=$(git -C "$project_dir" ls-files | wc -l)

    # Good history: reasonable commit-to-file ratio
    # At least 1 commit per 20 files (rough heuristic)
    local min_commits=$((file_count / 20))
    [[ "$commit_count" -ge "$min_commits" && "$commit_count" -gt 5 ]]
}
# }}}

# -- {{{ import_external_project
import_external_project() {
    local source_dir="$1"
    local project_name="${2:-$(basename "$source_dir")}"
    local target_dir="${MONOREPO_ROOT}/${project_name}"

    # Validate source exists
    if [[ ! -d "$source_dir" ]]; then
        error "Source directory not found: $source_dir"
        return 1
    fi

    # Check target doesn't exist
    if [[ -d "$target_dir" ]]; then
        error "Target already exists: $target_dir"
        error "Use --force to overwrite or choose different name"
        return 1
    fi

    log "Importing project from: $source_dir"
    log "                    to: $target_dir"

    # Preserve file timestamps during copy
    if [[ "$IMPORT_MODE" == "move" ]]; then
        mv "$source_dir" "$target_dir"
    else
        # Use cp -a to preserve timestamps, permissions, etc.
        cp -a "$source_dir" "$target_dir"
    fi

    # Remove any existing .git from imported project
    # (we'll create fresh history)
    if [[ -d "$target_dir/.git" ]]; then
        log "Removing existing .git directory (will reconstruct history)"
        rm -rf "$target_dir/.git"
    fi

    echo "$target_dir"
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
        echo "sparse_history"  # Has git but questionable quality
    fi
}
# }}}

# -- {{{ main_workflow
main_workflow() {
    local project_dir="$1"
    local state=$(determine_project_state "$project_dir")

    case "$state" in
        external)
            log "Project is external to monorepo, importing..."
            project_dir=$(import_external_project "$project_dir")
            [[ $? -ne 0 ]] && return 1
            # Fall through to reconstruction
            ;&

        no_git|flat_blob|sparse_history)
            log "Project state: $state"
            log "Proceeding with history reconstruction..."
            reconstruct_history "$project_dir"
            ;;

        good_history)
            log "Project already has good commit history"
            log "Use --force to reconstruct anyway"
            return 0
            ;;
    esac
}
# }}}
```

### 1. Create Analysis Module
```bash
# -- {{{ analyze_existing_history
analyze_existing_history() {
    local project_dir="$1"

    # Find the initial "blob" commit
    local first_commit=$(git -C "$project_dir" rev-list --max-parents=0 HEAD)

    # Get list of all files from that commit
    git -C "$project_dir" ls-tree -r --name-only "$first_commit"
}
# }}}

# -- {{{ extract_file_metadata
extract_file_metadata() {
    local file_path="$1"
    local project_dir="$2"

    # Get modification time
    local mtime=$(stat -c %Y "$project_dir/$file_path" 2>/dev/null || echo "0")

    # Get file size
    local size=$(stat -c %s "$project_dir/$file_path" 2>/dev/null || echo "0")

    # Output as JSON-like structure
    printf '{"path":"%s","mtime":%s,"size":%s}\n' "$file_path" "$mtime" "$size"
}
# }}}
```

### 2. Build Dependency Graph
```bash
# -- {{{ parse_issue_dependencies
parse_issue_dependencies() {
    local issue_file="$1"

    # Extract Dependencies field
    local deps=$(grep -i "Dependencies:" "$issue_file" | sed 's/.*Dependencies:\s*//')

    # Extract Blocks field
    local blocks=$(grep -i "Blocks:" "$issue_file" | sed 's/.*Blocks:\s*//')

    # Extract Blocked By field
    local blocked_by=$(grep -i "Blocked By:" "$issue_file" | sed 's/.*Blocked By:\s*//')

    # Parse issue numbers from these fields
    echo "$deps $blocks $blocked_by" | grep -oE '[0-9]{3}[a-z]?' | sort -u
}
# }}}

# -- {{{ build_dependency_graph
build_dependency_graph() {
    local issues_dir="$1"
    local -A graph

    for issue_file in "$issues_dir"/*.md; do
        local issue_id=$(basename "$issue_file" .md | grep -oE '^[0-9]{3}[a-z]?')
        [[ -z "$issue_id" ]] && continue

        local deps=$(parse_issue_dependencies "$issue_file")
        graph["$issue_id"]="$deps"
    done

    # Output graph for topological sort
    for issue in "${!graph[@]}"; do
        echo "$issue: ${graph[$issue]}"
    done
}
# }}}
```

### 3. Implement Topological Sort
```bash
# -- {{{ topological_sort_issues
topological_sort_issues() {
    local -A graph
    local -A in_degree
    local -a result
    local -a queue

    # Read dependency graph from stdin
    while IFS=': ' read -r node deps; do
        graph["$node"]="$deps"
        [[ -z "${in_degree[$node]}" ]] && in_degree["$node"]=0

        for dep in $deps; do
            ((in_degree["$dep"]++)) || in_degree["$dep"]=1
        done
    done

    # Initialize queue with nodes having in_degree 0
    for node in "${!graph[@]}"; do
        [[ "${in_degree[$node]}" -eq 0 ]] && queue+=("$node")
    done

    # Process queue
    while [[ ${#queue[@]} -gt 0 ]]; do
        local current="${queue[0]}"
        queue=("${queue[@]:1}")
        result+=("$current")

        for neighbor in ${graph[$current]}; do
            ((in_degree[$neighbor]--))
            [[ "${in_degree[$neighbor]}" -eq 0 ]] && queue+=("$neighbor")
        done
    done

    printf '%s\n' "${result[@]}"
}
# }}}
```

### 4. Estimate Commit Dates
```bash
# -- {{{ estimate_issue_date
estimate_issue_date() {
    local issue_file="$1"

    # Try to find explicit completion date
    local explicit_date=$(grep -iE '(completed|status).*[0-9]{4}-[0-9]{2}-[0-9]{2}' "$issue_file" | \
        grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)

    if [[ -n "$explicit_date" ]]; then
        date -d "$explicit_date" +%s
        return 0
    fi

    # Fall back to file modification time
    stat -c %Y "$issue_file"
}
# }}}

# -- {{{ interpolate_dates
interpolate_dates() {
    local -a issues=("$@")
    local -A known_dates
    local -A estimated_dates

    # First pass: collect known dates
    for issue in "${issues[@]}"; do
        local date=$(estimate_issue_date "$issue")
        if [[ "$date" != "0" ]]; then
            known_dates["$issue"]="$date"
        fi
    done

    # Second pass: interpolate missing dates
    local prev_date=""
    local prev_issue=""

    for issue in "${issues[@]}"; do
        if [[ -n "${known_dates[$issue]}" ]]; then
            estimated_dates["$issue"]="${known_dates[$issue]}"
            prev_date="${known_dates[$issue]}"
            prev_issue="$issue"
        elif [[ -n "$prev_date" ]]; then
            # Simple interpolation: add 1 day from previous
            estimated_dates["$issue"]=$((prev_date + 86400))
            prev_date="${estimated_dates[$issue]}"
        fi
    done

    # Output dates
    for issue in "${issues[@]}"; do
        echo "$issue:${estimated_dates[$issue]}"
    done
}
# }}}
```

### 5. Rewrite Git History
```bash
# -- {{{ create_dated_commit
create_dated_commit() {
    local message="$1"
    local timestamp="$2"
    local files="$3"

    # Format date for git
    local git_date=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S')

    # Add files
    for file in $files; do
        git add "$file" 2>/dev/null || true
    done

    # Create commit with specific date
    GIT_AUTHOR_DATE="$git_date" \
    GIT_COMMITTER_DATE="$git_date" \
    git commit -m "$message" --allow-empty-message 2>/dev/null || true
}
# }}}

# -- {{{ rewrite_history
rewrite_history() {
    local project_dir="$1"
    local -a ordered_issues
    local -A issue_dates
    local -A issue_files  # Maps issues to associated source files

    cd "$project_dir" || return 1

    # Create orphan branch for new history
    git checkout --orphan reconstructed-history

    # Clear the index
    git rm -rf --cached . 2>/dev/null || true

    # Build ordered list of issues with dates
    mapfile -t ordered_issues < <(get_ordered_issues "$project_dir")

    # Create commits in order
    for issue in "${ordered_issues[@]}"; do
        local date="${issue_dates[$issue]}"
        local files="${issue_files[$issue]}"
        local title=$(extract_issue_title "$issue")

        create_dated_commit "$title" "$date" "$files"
    done

    # Final commit with remaining files
    git add -A
    GIT_AUTHOR_DATE="$(date '+%Y-%m-%d %H:%M:%S')" \
    GIT_COMMITTER_DATE="$(date '+%Y-%m-%d %H:%M:%S')" \
    git commit -m "Import remaining project files"
}
# }}}
```

### 6. Associate Files with Issues (Heuristic)
```bash
# -- {{{ associate_files_with_issues
associate_files_with_issues() {
    local project_dir="$1"
    local issues_dir="$2"

    # Heuristics for file-to-issue mapping:
    # 1. Files mentioned in issue content (paths, filenames)
    # 2. Files with similar mtime to issue completion
    # 3. Files in directories mentioned in issues
    # 4. Default: associate with closest preceding issue by mtime

    local -A file_to_issue

    for file in $(find "$project_dir" -type f ! -path "*/.git/*" ! -path "*/issues/*"); do
        local file_mtime=$(stat -c %Y "$file")
        local best_issue=""
        local best_delta=999999999

        for issue_file in "$issues_dir"/*.md; do
            # Check if file is mentioned in issue
            if grep -q "$(basename "$file")" "$issue_file" 2>/dev/null; then
                best_issue="$issue_file"
                break
            fi

            # Otherwise, find closest issue by mtime
            local issue_mtime=$(stat -c %Y "$issue_file")
            local delta=$((file_mtime - issue_mtime))
            [[ $delta -lt 0 ]] && delta=$((-delta))

            if [[ $delta -lt $best_delta ]]; then
                best_delta=$delta
                best_issue="$issue_file"
            fi
        done

        file_to_issue["$file"]="$best_issue"
    done

    # Output mapping
    for file in "${!file_to_issue[@]}"; do
        echo "$file:${file_to_issue[$file]}"
    done
}
# }}}
```

### 7. Local LLM Integration (Optional)
```bash
# -- {{{ Configuration for LLM
LLM_ENABLED="${LLM_ENABLED:-false}"
LLM_MODEL="${LLM_MODEL:-llama3}"  # or mistral, codellama, etc.
LLM_VERIFY_COUNT=3  # Number of times to verify each decision
# }}}

# -- {{{ query_local_llm
query_local_llm() {
    local prompt="$1"
    local context="$2"

    if [[ "$LLM_ENABLED" != true ]]; then
        return 1
    fi

    # Query using ollama (or similar local LLM runner)
    local response=$(echo "$prompt" | ollama run "$LLM_MODEL" 2>/dev/null)

    echo "$response"
}
# }}}

# -- {{{ llm_triple_check
llm_triple_check() {
    local question="$1"
    local context="$2"

    local -a responses
    local i

    # Get 3 responses
    for i in 1 2 3; do
        responses+=("$(query_local_llm "$question" "$context")")
    done

    # Check if responses are consistent
    # Output JSON for comparison
    printf '{"responses":["%s","%s","%s"]}' \
        "${responses[0]}" "${responses[1]}" "${responses[2]}"
}
# }}}

# -- {{{ llm_verify_equivalence
llm_verify_equivalence() {
    local value1="$1"
    local value2="$2"

    local prompt="Are these two values the same or similar enough to be equivalent? Answer only YES or NO.
Value 1: $value1
Value 2: $value2"

    local response=$(query_local_llm "$prompt")

    [[ "$response" =~ ^[Yy][Ee]?[Ss]? ]]
}
# }}}

# -- {{{ resolve_ambiguous_ordering
resolve_ambiguous_ordering() {
    local issue1="$1"
    local issue2="$2"
    local context="$3"

    if [[ "$LLM_ENABLED" != true ]]; then
        # Fall back to numerical order
        echo "numerical"
        return
    fi

    local prompt="Given these two issues, which one should come first in the development timeline?
Output ONLY the issue number that should come first, nothing else.

Issue 1: $(cat "$issue1")

Issue 2: $(cat "$issue2")

Context: $context"

    local result=$(llm_triple_check "$prompt" "$context")

    # Parse JSON and check consistency
    local r1=$(echo "$result" | jq -r '.responses[0]')
    local r2=$(echo "$result" | jq -r '.responses[1]')
    local r3=$(echo "$result" | jq -r '.responses[2]')

    # If 2+ agree, use that answer
    if [[ "$r1" == "$r2" ]] || [[ "$r1" == "$r3" ]]; then
        echo "$r1"
    elif [[ "$r2" == "$r3" ]]; then
        echo "$r2"
    else
        # No consensus, fall back to numerical
        echo "numerical"
    fi
}
# }}}
```

## Implementation Details

### History Rewriting Strategy
```
Original State:
  commit abc123 "Initial import: 6000 files"
    └── all files added at once

Target State:
  commit 001 "Initial vision" (dated: 2024-01-01)
    └── notes/vision.md

  commit 002 "Issue 001: Setup" (dated: 2024-01-05)
    └── issues/completed/001-setup.md
    └── src/config.lua (associated by mtime)

  commit 003 "Issue 002: Core module" (dated: 2024-01-12)
    └── issues/completed/002-core-module.md
    └── src/core/*.lua (mentioned in issue)

  ... (N commits)

  commit N+1 "Import remaining files" (dated: today)
    └── everything else
```

### File Association Heuristics
1. **Explicit Mention**: File path appears in issue content
2. **Directory Match**: Issue mentions directory, all files in that dir associate
3. **Mtime Proximity**: Files modified near issue completion time
4. **Naming Convention**: Files named similarly to issue (e.g., `core-module.lua` ↔ `002-core-module.md`)
5. **Default**: Remaining files go to final bulk commit

### Date Sanity Checks
- No commit dated before the vision file
- No commit dated in the future
- Minimum 1 hour gap between commits (configurable)
- Maximum 6 month gap between sequential commits (flag for review)

## Related Documents
- `031-import-project-histories.md` - Existing history import
- `001-prepare-repository-structure.md` - Repository structure conventions
- `/scripts/sync-visions.sh` - Vision file discovery patterns

## Tools Required
- Bash 4.3+ (mapfile, associative arrays)
- Git with filter-repo support (optional, for complex rewrites)
- `jq` for JSON parsing (LLM integration)
- Local LLM runner (ollama, llama.cpp) - optional
- Standard POSIX utilities

## Metadata
- **Priority**: High
- **Complexity**: High (v2), Medium (v1 complete)
- **Dependencies**: None
- **Blocks**: Issue 008 (Validation and Documentation), future project imports
- **Impact**: Enables meaningful history reconstruction for all legacy projects

## Success Criteria

### Phase 1 (v1) ✅
- [x] Script discovers vision files using common patterns
- [x] Script finds and orders completed issue files
- [x] Vision file is always the first commit
- [x] Each completed issue gets exactly one commit
- [x] Remaining files are added in a final bulk commit
- [x] Dry-run mode shows planned commits without executing
- [x] Both headless and interactive modes function

### Phase 2 (v2)

#### Project Detection & Import
- [ ] Detect if project is inside or outside monorepo
- [ ] Import external projects with timestamp preservation (`cp -a`)
- [ ] Detect project state: no_git, flat_blob, sparse_history, good_history
- [ ] Skip projects with good history (unless --force)

#### History Analysis
- [ ] Script can analyze existing repository with flat blob commits
- [ ] Dependency graph built from issue file metadata
- [ ] Topological sort respects blocking/dependency relationships
- [ ] File modification times used as ordering signal

#### Date & File Management
- [ ] Commit dates estimated and applied correctly
- [ ] Files associated with issues using heuristics
- [ ] History rewritten on orphan branch (preserves original)

#### Optional LLM Integration
- [ ] Local LLM integration for ambiguous decisions
- [ ] Triple-check pattern for LLM consistency
- [ ] JSON output for LLM responses (easy parsing/comparison)

## Risk Assessment
- **Data Loss**: History rewriting is destructive
  - Mitigation: Always work on orphan branch, never force-push to main
- **Incorrect Ordering**: Dependencies might be miscalculated
  - Mitigation: Dry-run mode, manual review before applying
- **Date Estimation Errors**: Mtimes might be wrong (from copy operations)
  - Mitigation: Multiple signal sources, sanity checks, manual override
- **LLM Hallucination**: Local LLM might give wrong answers
  - Mitigation: Triple-check pattern, require 2/3 consensus, JSON validation
- **External Import**: Source project could be modified/deleted during copy
  - Mitigation: Use atomic copy operations, verify checksums

## Sub-Issues

| ID | Title | Status | Description |
|----|-------|--------|-------------|
| **035a** | Project detection and external import | ✅ Complete | Detect monorepo membership, import external projects, classify project state |
| **035b** | Dependency graph and topological sort | ✅ Complete | Parse Dependencies/Blocks fields, build graph, sort issues correctly |
| **035c** | Date estimation and interpolation | Pending | Extract dates from issue content/mtimes, interpolate gaps, apply sanity checks |
| **035d** | File-to-issue association heuristics | Pending | Map source files to issues via mentions, mtime proximity, naming conventions |
| **035e** | History rewriting on orphan branch | Pending | Create dated commits on orphan branch, preserve original history |
| **035f** | Local LLM integration (optional) | Pending | Triple-check ambiguous decisions, JSON output, consensus validation |

### Implementation Order
```
035a (detection/import)
  │
  └──▶ 035b (dependency graph) ──▶ 035c (date estimation)
                                        │
                                        └──▶ 035d (file association)
                                                    │
                                                    └──▶ 035e (history rewrite)
                                                                │
                                                                └──▶ 035f (LLM - optional)
```
