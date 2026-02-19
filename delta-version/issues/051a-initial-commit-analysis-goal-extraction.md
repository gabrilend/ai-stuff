# Issue 051a: Initial Commit Analysis and Goal Extraction

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High
**Created**: 2026-02-12
**Parent**: Issue 051 (Git Repository Documentation Generator)

---

## Current Behavior

No automated method exists to extract the "kernel" (original vision) from a git repository's initial commits, nor to define the "success mark" (current goals achieved) from the current state.

Developers manually read through early commits and infer project intent, which is:
- Time-consuming
- Subjective
- Inconsistent across analysts

---

## Intended Behavior

Create an analysis module that:

1. **Extracts the Kernel**: Analyze initial commits to determine original project intent
2. **Defines the Goal**: Analyze current state to determine what has been achieved
3. **Outputs structured data** for use by subsequent pipeline stages

### Kernel Extraction Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                     Kernel Extraction                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐                                           │
│  │ Git Repository  │                                           │
│  └────────┬────────┘                                           │
│           │                                                     │
│  ┌────────▼────────────────────┐                               │
│  │ Find Initial Commit(s)     │                               │
│  │ git rev-list --max-parents=0│                               │
│  └────────┬────────────────────┘                               │
│           │                                                     │
│  ┌────────▼────────────────────┐                               │
│  │ Extract Key Files:          │                               │
│  │ - README (if exists)        │                               │
│  │ - package.json/Cargo.toml   │                               │
│  │ - Main entry point          │                               │
│  │ - Early documentation       │                               │
│  └────────┬────────────────────┘                               │
│           │                                                     │
│  ┌────────▼────────────────────┐                               │
│  │ Analyze Commit Messages:    │                               │
│  │ - First 5-10 commits        │                               │
│  │ - Extract intent patterns   │                               │
│  │ - Identify project name     │                               │
│  └────────┬────────────────────┘                               │
│           │                                                     │
│  ┌────────▼────────────────────┐                               │
│  │ Optional: LLM Summarization │                               │
│  │ "Summarize this project's   │                               │
│  │  original intent..."        │                               │
│  └────────┬────────────────────┘                               │
│           │                                                     │
│  ┌────────▼────────────────────┐                               │
│  │ Output: kernel.json         │                               │
│  │ {                           │                               │
│  │   "name": "project-name",   │                               │
│  │   "intent": "...",          │                               │
│  │   "initial_files": [...],   │                               │
│  │   "initial_commits": [...]  │                               │
│  │ }                           │                               │
│  └─────────────────────────────┘                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Goal/Success Mark Extraction

```
┌─────────────────────────────────────────────────────────────────┐
│                    Goal Extraction                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────┐                            │
│  │ Analyze Current State (HEAD)   │                            │
│  └────────┬───────────────────────┘                            │
│           │                                                     │
│  ┌────────▼────────────────────┐                               │
│  │ Directory Structure:        │                               │
│  │ - Count src/ files          │                               │
│  │ - Count test/ files         │                               │
│  │ - Identify modules/features │                               │
│  └────────┬────────────────────┘                               │
│           │                                                     │
│  ┌────────▼────────────────────┐                               │
│  │ Current Documentation:      │                               │
│  │ - README (latest version)   │                               │
│  │ - CHANGELOG (if exists)     │                               │
│  │ - API docs                  │                               │
│  └────────┬────────────────────┘                               │
│           │                                                     │
│  ┌────────▼────────────────────┐                               │
│  │ Feature Detection:          │                               │
│  │ - Public APIs/exports       │                               │
│  │ - Entry points              │                               │
│  │ - CLI commands              │                               │
│  └────────┬────────────────────┘                               │
│           │                                                     │
│  ┌────────▼────────────────────┐                               │
│  │ Output: goal.json           │                               │
│  │ {                           │                               │
│  │   "features": [...],        │                               │
│  │   "modules": [...],         │                               │
│  │   "capabilities": [...],    │                               │
│  │   "file_count": N,          │                               │
│  │   "loc_estimate": N         │                               │
│  │ }                           │                               │
│  └─────────────────────────────┘                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Suggested Implementation Steps

### 1. Extract Initial Commits

```bash
# -- {{{ get_initial_commits
# Gets the first N commits from the repository
# Returns: newline-separated commit hashes
get_initial_commits() {
    local project_dir="$1"
    local count="${2:-5}"

    cd "$project_dir" || return 1

    # Get root commit(s) - repos can have multiple roots
    local roots
    roots=$(git rev-list --max-parents=0 HEAD)

    # Get first N commits after each root
    for root in $roots; do
        git rev-list --reverse "$root"..HEAD | head -n "$count"
        echo "$root"  # Include root itself
    done | sort -u
}
# }}}
```

### 2. Extract Files from Initial State

```bash
# -- {{{ extract_initial_files
# Gets the files present in the initial commit
# Returns: JSON array of file info
extract_initial_files() {
    local project_dir="$1"
    local commit="${2:-$(git rev-list --max-parents=0 HEAD | head -1)}"

    cd "$project_dir" || return 1

    echo "["
    local first=true
    while IFS= read -r file; do
        [[ "$first" == true ]] || echo ","
        first=false

        # Get file content size
        local size
        size=$(git cat-file -s "$commit:$file" 2>/dev/null || echo "0")

        # Get file type
        local ftype="unknown"
        case "$file" in
            *.lua) ftype="lua" ;;
            *.sh)  ftype="bash" ;;
            *.py)  ftype="python" ;;
            *.js)  ftype="javascript" ;;
            *.md)  ftype="markdown" ;;
            *.json) ftype="json" ;;
            *.toml) ftype="toml" ;;
            README*) ftype="readme" ;;
        esac

        printf '  {"path": "%s", "size": %d, "type": "%s"}' "$file" "$size" "$ftype"
    done < <(git ls-tree -r --name-only "$commit")
    echo ""
    echo "]"
}
# }}}
```

### 3. Analyze Commit Messages

```bash
# -- {{{ analyze_initial_commits
# Extracts patterns from initial commit messages
# Returns: JSON with analysis results
analyze_initial_commits() {
    local project_dir="$1"
    local count="${2:-10}"

    cd "$project_dir" || return 1

    local commits messages
    commits=$(git rev-list --reverse HEAD | head -n "$count")

    echo "{"
    echo '  "commits": ['
    local first=true
    for commit in $commits; do
        [[ "$first" == true ]] || echo ","
        first=false

        local msg date author
        msg=$(git log -1 --pretty=format:"%s" "$commit" | sed 's/"/\\"/g')
        date=$(git log -1 --pretty=format:"%ci" "$commit")
        author=$(git log -1 --pretty=format:"%an" "$commit")

        printf '    {"hash": "%s", "message": "%s", "date": "%s", "author": "%s"}' \
            "${commit:0:7}" "$msg" "$date" "$author"
    done
    echo ""
    echo "  ],"

    # Extract common patterns
    echo '  "patterns": {'

    # Project name detection (from first commit or directory name)
    local project_name
    project_name=$(basename "$project_dir")
    echo "    \"project_name\": \"$project_name\","

    # Intent keywords
    local init_keywords
    init_keywords=$(git log --reverse --pretty=format:"%s" | head -10 | \
        grep -oiE 'initial|setup|create|add|implement|start|begin|first' | \
        sort | uniq -c | sort -rn | head -3 | awk '{print $2}' | paste -sd,)
    echo "    \"intent_keywords\": \"$init_keywords\""

    echo "  }"
    echo "}"
}
# }}}
```

### 4. Kernel Synthesis (LLM-assisted)

```bash
# -- {{{ synthesize_kernel
# Uses LLM to synthesize project kernel from initial data
# Returns: Markdown vision document content
synthesize_kernel() {
    local initial_files="$1"
    local commit_analysis="$2"
    local readme_content="$3"

    if [[ "$LLM_ENABLED" != true ]]; then
        # Fallback to template-based synthesis
        synthesize_kernel_heuristic "$initial_files" "$commit_analysis"
        return
    fi

    local prompt
    prompt="Based on the following information about a project's initial state, write a vision document that captures the original intent and goals.

Initial Files:
$initial_files

Initial Commits Analysis:
$commit_analysis

$([ -n "$readme_content" ] && echo "Original README:
$readme_content")

Write a vision document in markdown format with these sections:
1. Project Name and Purpose (one paragraph)
2. Core Goals (3-5 bullet points)
3. Target Users/Use Cases
4. Key Design Principles

Output only the markdown content, no explanations."

    query_local_llm "$prompt"
}
# }}}

# -- {{{ synthesize_kernel_heuristic
# Fallback kernel synthesis without LLM
synthesize_kernel_heuristic() {
    local initial_files="$1"
    local commit_analysis="$2"

    local project_name
    project_name=$(echo "$commit_analysis" | jq -r '.patterns.project_name')

    local file_types
    file_types=$(echo "$initial_files" | jq -r '.[].type' | sort | uniq -c | sort -rn | head -3)

    cat << EOF
# $project_name Vision

## Purpose

This project was created to [PURPOSE TO BE FILLED].

## Initial Goals

Based on initial commit analysis:
$(echo "$commit_analysis" | jq -r '.commits[0:3] | .[] | "- " + .message')

## Technical Foundation

Primary languages/formats detected:
$file_types

## Design Principles

[TO BE FILLED based on code analysis]

---
*This vision document was auto-generated from git history analysis.*
*Please review and refine as needed.*
EOF
}
# }}}
```

### 5. Goal Extraction

```bash
# -- {{{ extract_current_goal
# Analyzes current state to determine achieved goals
# Returns: JSON with goal analysis
extract_current_goal() {
    local project_dir="$1"

    cd "$project_dir" || return 1

    echo "{"

    # File statistics
    local file_count loc_estimate
    file_count=$(git ls-files | wc -l)
    loc_estimate=$(git ls-files | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
    echo "  \"file_count\": $file_count,"
    echo "  \"loc_estimate\": $loc_estimate,"

    # Directory structure (modules)
    echo '  "directories": ['
    local first=true
    for dir in $(git ls-files | xargs -n1 dirname | sort -u | grep -v '^\.$'); do
        [[ "$first" == true ]] || echo ","
        first=false
        local count
        count=$(git ls-files "$dir"/* 2>/dev/null | wc -l)
        printf '    {"path": "%s", "file_count": %d}' "$dir" "$count"
    done
    echo ""
    echo "  ],"

    # Entry points detection
    echo '  "entry_points": ['
    local first=true
    for entry in main.lua init.lua index.js main.py src/main.* run.sh; do
        if git ls-files "$entry" &>/dev/null && [[ -n "$(git ls-files "$entry")" ]]; then
            [[ "$first" == true ]] || echo ","
            first=false
            printf '    "%s"' "$entry"
        fi
    done
    echo ""
    echo "  ],"

    # Feature detection from exports/CLI
    echo '  "features": ['
    # Parse for function exports, CLI commands, etc.
    local first=true
    # Lua: look for return statements at module end
    while IFS= read -r func; do
        [[ "$first" == true ]] || echo ","
        first=false
        printf '    "%s"' "$func"
    done < <(git grep -h "^function\|^local function" -- "*.lua" 2>/dev/null | \
        sed 's/function //' | cut -d'(' -f1 | head -20)
    echo ""
    echo "  ]"

    echo "}"
}
# }}}
```

### 6. Output Generation

```bash
# -- {{{ generate_analysis_output
# Combines kernel and goal into structured output
generate_analysis_output() {
    local project_dir="$1"
    local output_dir="${2:-$project_dir}"

    mkdir -p "$output_dir/tmp"

    # Extract initial data
    local initial_files initial_commits
    initial_files=$(extract_initial_files "$project_dir")
    initial_commits=$(analyze_initial_commits "$project_dir")

    # Get README if exists
    local readme_content=""
    local root_commit
    root_commit=$(git -C "$project_dir" rev-list --max-parents=0 HEAD | head -1)
    readme_content=$(git -C "$project_dir" show "$root_commit:README.md" 2>/dev/null || \
                     git -C "$project_dir" show "$root_commit:README" 2>/dev/null || echo "")

    # Synthesize kernel
    local kernel_md
    kernel_md=$(synthesize_kernel "$initial_files" "$initial_commits" "$readme_content")

    # Extract current goal
    local goal_json
    goal_json=$(extract_current_goal "$project_dir")

    # Write outputs
    echo "$initial_files" > "$output_dir/tmp/initial-files.json"
    echo "$initial_commits" > "$output_dir/tmp/initial-commits.json"
    echo "$goal_json" > "$output_dir/tmp/current-goal.json"

    # Generate vision.md if it doesn't exist
    if [[ ! -f "$output_dir/notes/vision.md" ]]; then
        mkdir -p "$output_dir/notes"
        echo "$kernel_md" > "$output_dir/notes/vision.md"
        log "Generated: notes/vision.md"
    fi

    # Create analysis summary
    cat << EOF > "$output_dir/tmp/analysis-summary.json"
{
  "kernel": {
    "source": "initial-commits.json",
    "vision_file": "notes/vision.md"
  },
  "goal": {
    "source": "current-goal.json",
    "file_count": $(echo "$goal_json" | jq '.file_count'),
    "loc_estimate": $(echo "$goal_json" | jq '.loc_estimate')
  },
  "analysis_date": "$(date -Iseconds)"
}
EOF

    log "Analysis complete. Outputs in $output_dir/tmp/"
}
# }}}
```

---

## Output Format

### kernel.json

```json
{
  "name": "delta-version",
  "intent": "Meta-project for git repository management and infrastructure tooling",
  "initial_files": [
    {"path": "README.md", "size": 1234, "type": "readme"},
    {"path": "scripts/setup.sh", "size": 567, "type": "bash"}
  ],
  "initial_commits": [
    {"hash": "abc1234", "message": "Initial commit", "date": "2024-01-01"}
  ],
  "extracted_vision": "notes/vision.md"
}
```

### goal.json

```json
{
  "file_count": 150,
  "loc_estimate": 25000,
  "directories": [
    {"path": "scripts", "file_count": 25},
    {"path": "issues", "file_count": 50}
  ],
  "entry_points": ["scripts/main.sh", "run.sh"],
  "features": [
    "reconstruct_history",
    "generate_roadmap",
    "manage_issues"
  ],
  "capabilities": [
    "Git history reconstruction",
    "Issue file management",
    "Phase demo generation"
  ]
}
```

---

## Acceptance Criteria

- [ ] Extracts initial commit(s) from any valid git repository
- [ ] Identifies key files in initial state (README, config, entry points)
- [ ] Analyzes first N commit messages for intent patterns
- [ ] Generates vision.md from kernel analysis (LLM or heuristic)
- [ ] Extracts current state statistics (file count, LOC, directories)
- [ ] Identifies entry points and public APIs
- [ ] Outputs structured JSON for pipeline consumption
- [ ] Works without LLM (heuristic fallback)
- [ ] Handles edge cases: empty commits, binary-only repos, single-file projects

---

## Technical Notes

### Edge Cases

1. **Empty initial commit**: Use second commit for analysis
2. **Binary-only files**: Note in output, skip content analysis
3. **Renamed initial files**: Track via `git log --follow`
4. **Multiple root commits**: Analyze all roots, merge results
5. **No README**: Generate from commit messages only

### Performance

- Use `git cat-file --batch` for bulk file extraction
- Cache analysis results in tmp/
- Skip large binary files (>1MB)

---

## Metadata

- **Priority**: High (blocks all subsequent stages)
- **Complexity**: Medium
- **Dependencies**: None
- **Blocks**: 051b, 051c, 051d, 051e, 051f, 051g
