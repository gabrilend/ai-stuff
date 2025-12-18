# Issue 035d: File-to-Issue Association Heuristics

## Parent Issue
- **Issue 035**: Project History Reconstruction from Issue Files

## Current Behavior

The `reconstruct-history.sh` script creates commits in this order:
1. Vision file commit
2. One commit per completed issue file (just the `.md` file)
3. Bulk commit with ALL remaining files

This means source code is never attributed to the issues that created it - everything ends up in the final bulk commit, obscuring the relationship between issues and their implementations.

### Example (Current)
```
commit 1: "Initial vision"
  └── notes/vision.md

commit 2: "Issue 001: Create config system"
  └── issues/completed/001-create-config-system.md

commit 3: "Issue 002: Build parser module"
  └── issues/completed/002-build-parser-module.md

commit 4: "Import remaining files"
  └── src/config.lua           ← Should be with issue 001!
  └── src/parser.lua           ← Should be with issue 002!
  └── src/utils.lua
  └── docs/api.md
  └── ... (everything else)
```

## Intended Behavior

Associate source files with the issues that created them, so each issue commit includes both the issue file AND its related implementation files.

### Example (Target)
```
commit 1: "Initial vision"
  └── notes/vision.md

commit 2: "Issue 001: Create config system"
  └── issues/completed/001-create-config-system.md
  └── src/config.lua           ← Associated by mention in issue

commit 3: "Issue 002: Build parser module"
  └── issues/completed/002-build-parser-module.md
  └── src/parser.lua           ← Associated by naming convention
  └── src/parser/lexer.lua     ← Associated by directory mention

commit 4: "Import remaining files"
  └── src/utils.lua            ← No association found
  └── docs/api.md
```

## File Association Heuristics

Priority order (highest to lowest):

| Priority | Heuristic | Reliability | Description |
|----------|-----------|-------------|-------------|
| 1 | **Explicit Path** | High | Full path appears in issue content (e.g., `src/config.lua`) |
| 2 | **Filename Mention** | High | Filename appears in issue (e.g., `config.lua` or `config`) |
| 3 | **Directory Mention** | Medium | Issue mentions directory, associate all files in that dir |
| 4 | **Naming Convention** | Medium | File name matches issue name pattern |
| 5 | **Mtime Proximity** | Low | File mtime within threshold of issue completion date |
| 6 | **Default** | - | Remaining files go to bulk commit |

### Heuristic Details

#### 1. Explicit Path Match
```lua
-- In issue file: "Created `src/mpq/extract.lua` to handle extraction"
-- File: src/mpq/extract.lua → matches this issue
```

#### 2. Filename Mention
```lua
-- In issue file: "The extract.lua module now supports..."
-- File: src/mpq/extract.lua → matches (basename match)
```

#### 3. Directory Mention
```lua
-- In issue file: "All parsing code lives in src/parsers/"
-- Files: src/parsers/*.lua → all match this issue
```

#### 4. Naming Convention
```lua
-- Issue: 002-build-parser-module.md
-- File: parser-module.lua → matches (name similarity)
-- File: parser.lua → matches (keyword match)
-- File: build-parser.sh → matches (multi-keyword)
```

#### 5. Mtime Proximity (Configurable Threshold)
```lua
-- Issue mtime: 2024-12-15 14:30:00
-- File mtime: 2024-12-15 14:25:00 (5 min before)
-- Threshold: 1 hour → matches
```

## Suggested Implementation Steps

### 1. Add Configuration
```bash
# -- {{{ File Association Configuration
ASSOC_MTIME_THRESHOLD=3600     # 1 hour proximity threshold
ASSOC_MIN_SIMILARITY=0.5       # Minimum name similarity score
ASSOC_EXCLUDE_PATTERNS=(       # Files that never associate
    "*.md"                     # Documentation (except issue files)
    ".gitignore"
    "LICENSE"
    "README*"
)
ASSOC_VERBOSE=false            # Show association reasoning
# }}}
```

### 2. Extract Mentioned Paths from Issue
```bash
# -- {{{ extract_mentioned_paths
extract_mentioned_paths() {
    local issue_file="$1"

    # Extract file paths from backticks: `src/foo.lua`
    local backtick_paths
    backtick_paths=$(grep -oE '\`[^`]+\.(lua|sh|py|js|ts|c|h|rs|go)\`' "$issue_file" | \
                     tr -d '`' | sort -u)

    # Extract paths from "Files Changed" or similar sections
    local section_paths
    section_paths=$(sed -n '/^## Files Changed/,/^##/p' "$issue_file" | \
                    grep -oE '[a-zA-Z0-9_/-]+\.[a-z]+' | sort -u)

    # Combine and deduplicate
    echo -e "${backtick_paths}\n${section_paths}" | sort -u | grep -v '^$'
}
# }}}
```

### 3. Extract Mentioned Directories
```bash
# -- {{{ extract_mentioned_directories
extract_mentioned_directories() {
    local issue_file="$1"

    # Extract directory paths from backticks: `src/parsers/`
    local backtick_dirs
    backtick_dirs=$(grep -oE '\`[^`]+/\`' "$issue_file" | tr -d '`')

    # Extract from prose: "in the src/parsers directory"
    local prose_dirs
    prose_dirs=$(grep -oE '[a-zA-Z0-9_-]+(/[a-zA-Z0-9_-]+)+/' "$issue_file")

    echo -e "${backtick_dirs}\n${prose_dirs}" | sort -u | grep -v '^$'
}
# }}}
```

### 4. Calculate Name Similarity
```bash
# -- {{{ calculate_name_similarity
calculate_name_similarity() {
    local issue_name="$1"   # e.g., "002-build-parser-module"
    local file_name="$2"    # e.g., "parser-module.lua"

    # Extract keywords from issue name (remove number prefix)
    local issue_keywords
    issue_keywords=$(echo "$issue_name" | sed 's/^[0-9]*[a-z]*-//' | tr '-' '\n')

    # Extract keywords from file name (remove extension)
    local file_keywords
    file_keywords=$(echo "$file_name" | sed 's/\.[^.]*$//' | tr '-_' '\n')

    # Count matching keywords
    local matches=0
    local total=0

    for keyword in $issue_keywords; do
        ((total++))
        if echo "$file_keywords" | grep -qi "^${keyword}$"; then
            ((matches++))
        fi
    done

    # Return similarity as percentage (0-100)
    if [[ $total -gt 0 ]]; then
        echo $((matches * 100 / total))
    else
        echo "0"
    fi
}
# }}}
```

### 5. Check Mtime Proximity
```bash
# -- {{{ check_mtime_proximity
check_mtime_proximity() {
    local file_path="$1"
    local issue_mtime="$2"
    local threshold="${ASSOC_MTIME_THRESHOLD:-3600}"

    local file_mtime
    file_mtime=$(stat -c %Y "$file_path" 2>/dev/null || echo "0")

    local delta=$((file_mtime - issue_mtime))
    [[ $delta -lt 0 ]] && delta=$((-delta))

    # Return true if within threshold
    [[ $delta -le $threshold ]]
}
# }}}
```

### 6. Main Association Function
```bash
# -- {{{ associate_files_with_issues
associate_files_with_issues() {
    local project_dir="$1"
    local issues_dir="$2"

    # Get all project files (excluding .git and issues)
    local -a all_files
    mapfile -t all_files < <(find "$project_dir" -type f \
        ! -path "*/.git/*" \
        ! -path "*/issues/*" \
        ! -name "*.md" \
        2>/dev/null)

    # Track which files have been associated
    local -A file_to_issue
    local -A issue_to_files

    # Get ordered issues
    local -a issues
    mapfile -t issues < <(discover_completed_issues "$project_dir")

    # Process each issue
    for issue_file in "${issues[@]}"; do
        local issue_id
        issue_id=$(extract_issue_id "$issue_file")
        issue_to_files["$issue_id"]=""

        # Get issue metadata
        local issue_mtime
        issue_mtime=$(estimate_issue_date "$issue_file")
        local issue_name
        issue_name=$(basename "$issue_file" .md)

        # Extract mentioned paths and directories
        local -a mentioned_paths
        mapfile -t mentioned_paths < <(extract_mentioned_paths "$issue_file")
        local -a mentioned_dirs
        mapfile -t mentioned_dirs < <(extract_mentioned_directories "$issue_file")

        # Process each project file
        for file in "${all_files[@]}"; do
            # Skip if already associated
            [[ -n "${file_to_issue[$file]:-}" ]] && continue

            local file_basename file_relative
            file_basename=$(basename "$file")
            file_relative="${file#$project_dir/}"

            local matched=false
            local match_reason=""

            # Heuristic 1: Explicit path match
            for path in "${mentioned_paths[@]}"; do
                if [[ "$file_relative" == "$path" ]] || \
                   [[ "$file_relative" == *"/$path" ]]; then
                    matched=true
                    match_reason="explicit_path"
                    break
                fi
            done

            # Heuristic 2: Filename mention
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
                    if [[ "$file_relative" == "$dir"* ]]; then
                        matched=true
                        match_reason="directory_mention"
                        break
                    fi
                done
            fi

            # Heuristic 4: Naming convention
            if [[ "$matched" == false ]]; then
                local similarity
                similarity=$(calculate_name_similarity "$issue_name" "$file_basename")
                if [[ "$similarity" -ge 50 ]]; then
                    matched=true
                    match_reason="naming_convention($similarity%)"
                fi
            fi

            # Heuristic 5: Mtime proximity (lowest priority)
            if [[ "$matched" == false ]]; then
                if check_mtime_proximity "$file" "$issue_mtime"; then
                    matched=true
                    match_reason="mtime_proximity"
                fi
            fi

            # Record association
            if [[ "$matched" == true ]]; then
                file_to_issue["$file"]="$issue_id"
                issue_to_files["$issue_id"]+="$file_relative "

                if [[ "$ASSOC_VERBOSE" == true ]]; then
                    log "  $file_relative → $issue_id ($match_reason)"
                fi
            fi
        done
    done

    # Output associations as "issue_id:file1 file2 file3"
    for issue_id in "${!issue_to_files[@]}"; do
        local files="${issue_to_files[$issue_id]}"
        [[ -n "$files" ]] && echo "$issue_id:${files% }"
    done
}
# }}}
```

### 7. Update create_issue_commit to Include Files
```bash
# -- {{{ create_issue_commit (updated)
create_issue_commit() {
    local issue_file="$1"
    local commit_date="${2:-}"
    local associated_files="${3:-}"  # Space-separated list

    local issue_name title
    issue_name=$(basename "$issue_file" .md)
    title=$(extract_issue_title "$issue_file")

    log "Creating issue commit for: $issue_name"

    # Add issue file
    git add "$issue_file"

    # Add associated source files
    local file_count=0
    for file in $associated_files; do
        if [[ -f "$file" ]]; then
            git add "$file"
            ((file_count++))
            log "  + $file"
        fi
    done

    # Check if there's anything to commit
    if ! git diff --cached --quiet; then
        local date_args=()
        if [[ -n "$commit_date" ]]; then
            local git_date
            git_date=$(format_epoch_for_git "$commit_date")
            date_args=(--date="$git_date")
            export GIT_AUTHOR_DATE="$git_date"
            export GIT_COMMITTER_DATE="$git_date"
        fi

        local file_summary=""
        [[ $file_count -gt 0 ]] && file_summary=" (+$file_count source files)"

        git commit "${date_args[@]}" -m "$(cat <<EOF
${title}${file_summary}

Completed issue ${issue_name} with associated implementation.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: reconstruct-history.sh <noreply@delta-version>
EOF
)"
        unset GIT_AUTHOR_DATE GIT_COMMITTER_DATE
        return 0
    else
        log "Issue file already committed or empty: $issue_name"
        return 1
    fi
}
# }}}
```

### 8. Update reconstruct_history to Use Associations
```bash
# In reconstruct_history(), after ordering issues:

# Build file-to-issue associations
local -A issue_file_map
while IFS=':' read -r issue_id files; do
    [[ -z "$issue_id" ]] && continue
    issue_file_map["$issue_id"]="$files"
done < <(associate_files_with_issues "$project_dir" "$project_dir/issues/completed")

# When creating issue commits:
for issue_file in "${completed_issues[@]}"; do
    local issue_id
    issue_id=$(extract_issue_id "$issue_file")
    local associated="${issue_file_map[$issue_id]:-}"

    create_issue_commit "$issue_file" "$issue_date" "$associated"
done
```

### 9. Update dry_run_report to Show Associations
```bash
# In dry_run_report(), when showing issue commits:

for issue_file in "${completed_issues[@]}"; do
    # ... existing code ...

    # Show associated files
    local issue_id
    issue_id=$(extract_issue_id "$issue_file")
    local associated="${issue_file_map[$issue_id]:-}"

    if [[ -n "$associated" ]]; then
        echo "        Associated files:"
        for file in $associated; do
            echo "          + $file"
        done
    fi
done
```

## Testing Strategy

### Test Case 1: Explicit Path Match
Create issue with `src/foo.lua` mentioned → verify `src/foo.lua` associates

### Test Case 2: Directory Match
Create issue mentioning `src/parsers/` → verify all files in `src/parsers/` associate

### Test Case 3: Naming Convention
Create issue `002-build-lexer.md` → verify `lexer.lua` associates

### Test Case 4: No Association
Files without any signal → should end up in bulk commit

### Test Case 5: Dry Run Display
Verify dry-run shows associations correctly

## Files to Modify

- `delta-version/scripts/reconstruct-history.sh`:
  - Add configuration section
  - Add `extract_mentioned_paths()`
  - Add `extract_mentioned_directories()`
  - Add `calculate_name_similarity()`
  - Add `check_mtime_proximity()`
  - Add `associate_files_with_issues()`
  - Update `create_issue_commit()` signature and implementation
  - Update `reconstruct_history()` to build and use associations
  - Update `dry_run_report()` to display associations

## Related Documents
- **Issue 035**: Parent issue for project history reconstruction
- **Issue 035a**: Project detection and external import (completed)
- **Issue 035b**: Dependency graph and topological sort (completed)
- **Issue 035c**: Date estimation and interpolation (completed)
- **Issue 035e**: History rewriting on orphan branch (next)

## Metadata
- **Priority**: High (part of 035)
- **Complexity**: Medium
- **Dependencies**: Issue 035a, 035b, 035c
- **Blocks**: Issue 035e
- **Status**: In Progress

## Success Criteria

- [ ] `extract_mentioned_paths()` finds file paths in issue content
- [ ] `extract_mentioned_directories()` finds directory references
- [ ] `calculate_name_similarity()` scores filename similarity correctly
- [ ] `check_mtime_proximity()` respects configurable threshold
- [ ] `associate_files_with_issues()` returns correct mappings
- [ ] Issue commits include associated source files
- [ ] Dry-run shows which files will be associated with which issues
- [ ] Files without associations go to bulk commit
- [ ] Verbose mode explains association reasoning
