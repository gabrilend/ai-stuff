# Issue 050: Earliest Version Extraction for History Reconstruction

**Phase**: 0 - Tooling
**Status**: Complete
**Priority**: High
**Created**: 2026-02-11
**Completed**: 2026-02-12
**Related**: Issue 035 (Project History Reconstruction)

---

## Current Behavior

The `reconstruct-history.sh` script (Issue 035) handles three project states:

1. **no_git**: Creates fresh history from current files
2. **flat_blob**: Rewrites single "import all" commit into issue-based history
3. **good_history**: Skips (already has meaningful history)

However, when a project has **existing git history** with multiple commits, the script:
- Uses the **current working tree state** (latest versions) for all commits
- Does not extract earlier file versions from the git log
- Cannot reconstruct a project that was developed with git but later "squashed" or imported

This means the reconstructed history shows files appearing in their **final form** rather than evolving through commits as they actually did.

### Problem Scenario

```
Original History (lost during import):
  commit 1: parser.lua (v1 - 50 lines)
  commit 2: parser.lua (v2 - 100 lines, added error handling)
  commit 3: parser.lua (v3 - 150 lines, added caching)

Current State After Flat Import:
  commit 1: "Import all files" - parser.lua (v3 - 150 lines)

Reconstructed (current behavior):
  commit 1: Issue 001 - parser.lua (v3 - 150 lines)  ← WRONG!
  commit 2: Issue 002 - parser.lua (v3 - 150 lines)  ← Should be v2
  commit 3: Issue 003 - parser.lua (v3 - 150 lines)  ← Already correct
```

---

## Intended Behavior

Enhance `reconstruct-history.sh` to:

1. **Analyze existing git history** to find the earliest version of each file
2. **Extract file versions** at different points in the repository's history
3. **Associate file versions with issues** based on when issues were completed
4. **Stage appropriate file versions** for each commit during reconstruction

### Enhanced Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Enhanced reconstruct-history.sh                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────────────────────────┐                              │
│  │ Has existing git history with           │                              │
│  │ multiple commits?                        │                              │
│  └─────────────────┬────────────────────────┘                              │
│                    │                                                        │
│              ┌─────┴─────┐                                                 │
│              │           │                                                 │
│             YES          NO                                                │
│              │           │                                                 │
│    ┌─────────▼─────────┐ │                                                 │
│    │ Extract file      │ └──▶ [Existing behavior: use working tree]       │
│    │ version history   │                                                   │
│    └─────────┬─────────┘                                                   │
│              │                                                              │
│    ┌─────────▼─────────────────────┐                                       │
│    │ Build file timeline:          │                                       │
│    │   file → [(commit, date, blob)]│                                       │
│    └─────────┬─────────────────────┘                                       │
│              │                                                              │
│    ┌─────────▼─────────────────────┐                                       │
│    │ Match issue dates to file     │                                       │
│    │ versions by timestamp         │                                       │
│    └─────────┬─────────────────────┘                                       │
│              │                                                              │
│    ┌─────────▼─────────────────────┐                                       │
│    │ For each issue commit:        │                                       │
│    │   Stage file at version       │                                       │
│    │   closest to issue date       │                                       │
│    └─────────┬─────────────────────┘                                       │
│              │                                                              │
│              └──▶ [Continue with existing commit creation]                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Target Result

```
Reconstructed (enhanced behavior):
  commit 1: Issue 001 - parser.lua (v1 - earliest version)
  commit 2: Issue 002 - parser.lua (v2 - version at issue 002 date)
  commit 3: Issue 003 - parser.lua (v3 - version at issue 003 date)
```

---

## Suggested Implementation Steps

### 1. Extract File Version History

```bash
# -- {{{ extract_file_history
# Builds a timeline of all versions of all files in the repository
#
# Output format (one line per file version):
#   filepath|commit_hash|commit_date_epoch|blob_hash
#
# Example:
#   src/parser.lua|abc123|1702684800|def456
#   src/parser.lua|ghi789|1702771200|jkl012
extract_file_history() {
    local project_dir="$1"
    local output_file="$2"

    cd "$project_dir" || return 1

    # Get all commits in chronological order (oldest first)
    local commits
    commits=$(git rev-list --reverse HEAD)

    # For each commit, list files and their blob hashes
    while IFS= read -r commit; do
        local commit_date
        commit_date=$(git show -s --format='%ct' "$commit")

        # List all files in this commit with their blob hashes
        git ls-tree -r "$commit" | while read -r mode type blob filepath; do
            echo "${filepath}|${commit}|${commit_date}|${blob}"
        done
    done <<< "$commits" > "$output_file"

    log "Extracted $(wc -l < "$output_file") file versions from git history"
}
# }}}
```

### 2. Find Earliest Version of Each File

```bash
# -- {{{ get_earliest_file_versions
# Returns the earliest (first appearing) version of each file
#
# Input: file history from extract_file_history
# Output: filepath|commit|date|blob (earliest version only)
get_earliest_file_versions() {
    local history_file="$1"

    # Sort by filepath, then by date, take first occurrence of each file
    sort -t'|' -k1,1 -k3,3n "$history_file" | \
        awk -F'|' '!seen[$1]++ {print}'
}
# }}}
```

### 3. Find File Version at Specific Date

```bash
# -- {{{ get_file_version_at_date
# Returns the file version that existed at or before a given date
#
# Args:
#   $1 - filepath
#   $2 - target date (epoch)
#   $3 - history file
#
# Returns: commit|blob for the version, or empty if file didn't exist yet
get_file_version_at_date() {
    local filepath="$1"
    local target_date="$2"
    local history_file="$3"

    # Find all versions of this file with date <= target_date
    # Take the latest one (closest to target date without exceeding)
    grep "^${filepath}|" "$history_file" | \
        awk -F'|' -v target="$target_date" '$3 <= target {print}' | \
        sort -t'|' -k3,3rn | \
        head -1 | \
        cut -d'|' -f2,4
}
# }}}
```

### 4. Extract File Content from Blob

```bash
# -- {{{ extract_blob_to_file
# Extracts a specific blob (file version) to the working directory
#
# Args:
#   $1 - blob hash
#   $2 - target filepath (relative to repo root)
extract_blob_to_file() {
    local blob_hash="$1"
    local target_path="$2"

    # Ensure parent directory exists
    mkdir -p "$(dirname "$target_path")"

    # Extract blob content to file
    git cat-file blob "$blob_hash" > "$target_path"
}
# }}}
```

### 5. Enhanced Issue Commit Creation

```bash
# -- {{{ create_issue_commit_with_versioned_files
# Creates a commit for an issue using file versions appropriate to that date
#
# Args:
#   $1 - issue file path
#   $2 - issue date (epoch)
#   $3 - history file
#   $4 - associated files (space-separated)
create_issue_commit_with_versioned_files() {
    local issue_file="$1"
    local issue_date="$2"
    local history_file="$3"
    local associated_files="$4"

    local title
    title=$(extract_issue_title "$issue_file")

    # For each associated file, get the version at issue date
    for filepath in $associated_files; do
        local version_info
        version_info=$(get_file_version_at_date "$filepath" "$issue_date" "$history_file")

        if [[ -n "$version_info" ]]; then
            local commit_hash blob_hash
            commit_hash=$(echo "$version_info" | cut -d'|' -f1)
            blob_hash=$(echo "$version_info" | cut -d'|' -f2)

            # Extract this version of the file
            extract_blob_to_file "$blob_hash" "$filepath"
            git add "$filepath"

            log "  $filepath: using version from commit ${commit_hash:0:7}"
        else
            log "  $filepath: did not exist at issue date, skipping"
        fi
    done

    # Add the issue file itself
    git add "$issue_file"

    # Create dated commit
    create_dated_commit "$title" "$issue_date"
}
# }}}
```

### 6. Integration with Main Workflow

```bash
# -- {{{ has_meaningful_history
# Checks if the project has git history worth extracting versions from
#
# Returns true if:
#   - Git repository exists
#   - Has more than 2 commits
#   - Same files appear in multiple commits with different content
has_meaningful_history() {
    local project_dir="$1"

    [[ ! -d "$project_dir/.git" ]] && return 1

    local commit_count
    commit_count=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null || echo "0")

    # Need at least 3 commits for meaningful version history
    [[ "$commit_count" -ge 3 ]] || return 1

    # Check if any file has multiple versions
    local multi_version_files
    multi_version_files=$(git -C "$project_dir" log --all --pretty=format: --name-only | \
        sort | uniq -c | awk '$1 > 1 {count++} END {print count+0}')

    [[ "$multi_version_files" -gt 0 ]]
}
# }}}

# -- {{{ main modification
# In reconstruct_history(), add:
#
# if has_meaningful_history "$project_dir"; then
#     log "Project has meaningful git history, extracting file versions..."
#     HISTORY_FILE=$(mktemp)
#     extract_file_history "$project_dir" "$HISTORY_FILE"
#     USE_VERSION_EXTRACTION=true
# else
#     USE_VERSION_EXTRACTION=false
# fi
#
# Then in the commit loop:
# if [[ "$USE_VERSION_EXTRACTION" == true ]]; then
#     create_issue_commit_with_versioned_files "$issue" "$date" "$HISTORY_FILE" "$files"
# else
#     create_issue_commit "$issue" "$date" "$files"
# fi
# }}}
```

---

## CLI Interface

```bash
# New flags for reconstruct-history.sh

# Enable version extraction (auto-detected by default)
    --with-version-extraction    Force version extraction even for sparse history
    --no-version-extraction      Disable version extraction, use latest files only

# Preview version timeline
    --show-file-history FILE     Show version history for a specific file
    --show-version-plan          Show which file versions would be used per commit

# Debug options
    --dump-history FILE          Export full file history to file for analysis
```

### Example Usage

```bash
# Preview what versions would be used
reconstruct-history.sh --dry-run --show-version-plan /path/to/project

# Output:
# Issue 001 (2024-01-05):
#   src/parser.lua: commit abc123 (2024-01-03)
#   src/config.lua: commit abc123 (2024-01-03)
#
# Issue 002 (2024-01-12):
#   src/parser.lua: commit def456 (2024-01-10)
#   src/config.lua: commit abc123 (2024-01-03)  ← unchanged
#   src/cache.lua: NEW (first appears)

# Show history for a specific file
reconstruct-history.sh --show-file-history src/parser.lua /path/to/project

# Output:
# src/parser.lua version history:
#   2024-01-03 abc123: Initial implementation (50 lines)
#   2024-01-10 def456: Added error handling (100 lines)
#   2024-01-15 ghi789: Added caching (150 lines)
```

---

## File Locations

- **Modified Script**: `delta-version/scripts/reconstruct-history.sh`
- **New Library** (optional): `delta-version/scripts/libs/git-version-extractor.lua`
- **Test**: `delta-version/tmp/test-version-extraction.sh`

---

## Acceptance Criteria

- [x] Detects projects with meaningful git history (>2 commits, files with multiple versions)
- [x] Extracts complete file version timeline from git history
- [x] Associates file versions with issue dates using closest-before-date matching
- [x] Reconstructed commits use appropriate file versions, not just latest
- [x] Files that didn't exist at issue date are not included in that commit
- [x] New `--show-version-plan` flag shows preview of version assignments
- [x] New `--show-file-history` flag shows individual file evolution
- [x] Backward compatible: projects without history still work as before
- [x] Performance: handles large histories (1000+ commits) efficiently

---

## Technical Notes

### Git Internals Used

- `git rev-list --reverse HEAD`: Get all commits in chronological order
- `git ls-tree -r <commit>`: List all files in a commit with blob hashes
- `git cat-file blob <hash>`: Extract file content from blob
- `git show -s --format='%ct' <commit>`: Get commit timestamp (epoch)

### Performance Considerations

For large repositories:
- Cache the history file rather than regenerating
- Use `git log --follow` for renamed files
- Consider using `git log --diff-filter=A` to find file creation dates directly
- Batch blob extractions to reduce git process spawning

### Edge Cases

1. **Renamed files**: Use `git log --follow` to track across renames
2. **Deleted then recreated files**: Track deletion events, handle gaps
3. **Binary files**: Same approach works, blob extraction is format-agnostic
4. **Submodules**: Exclude or handle specially (submodule commits are separate)
5. **Merge commits**: Use first-parent for linear history reconstruction

### Date Matching Strategy

When matching issue dates to file versions:

```
Issue date: 2024-01-12

File versions:
  2024-01-03 (v1)
  2024-01-10 (v2)  ← Use this (closest without exceeding)
  2024-01-15 (v3)

Result: Use v2 from 2024-01-10
```

If no version exists before issue date, the file is considered "not yet created" for that commit.

---

## Related

- Issue 035: Original history reconstruction implementation
- Issue 035d: File-to-issue association heuristics (dates inform version selection)
- Issue 035c: Date estimation (provides issue dates for version matching)

---

## Implementation Notes

### Functions Added to reconstruct-history.sh

1. **`has_meaningful_history()`** - Detects if project has extractable version history (≥3 commits, files with multiple versions)

2. **`extract_file_history()`** - Builds timeline of all file versions using `git ls-tree -r` and `git show -s --format='%ct'`

3. **`get_file_version_at_date()`** - Returns commit|blob for file version at or before target date

4. **`get_earliest_file_version()`** - Returns first-ever version of a file from history

5. **`extract_blob_to_file()`** - Extracts blob content to working directory via `git cat-file blob`

6. **`show_file_history()`** - Displays version history for specific file with line counts

7. **`show_version_plan()`** - Shows which file versions would be used per issue commit

8. **`stage_versioned_files()`** - Stages files at their historical versions for commit creation

### Configuration Variables Added

```bash
ENABLE_VERSION_EXTRACTION="${ENABLE_VERSION_EXTRACTION:-auto}"  # auto | true | false
VERSION_HISTORY_FILE=""       # Temp file populated at runtime
SHOW_VERSION_PLAN=false       # --show-version-plan flag
SHOW_FILE_HISTORY=""          # --show-file-history FILE flag
MIN_COMMITS_FOR_EXTRACTION=3  # Threshold for "meaningful" history
```

### CLI Flags Added

- `--with-version-extraction` - Force version extraction even for sparse history
- `--no-version-extraction` - Disable version extraction, use latest files only
- `--show-version-plan` - Preview which versions would be used per commit
- `--show-file-history FILE` - Show version history for specific file

### Bug Fixed

**`((count++))` causing early exit with `set -e`**: Arithmetic expressions evaluating to 0 are falsy in bash, triggering exit with `set -e`. Fixed by adding `|| true` to prevent exit on zero-value increments.

### Testing

Verified `--show-file-history Makefile` on symbeline-realms project, showing 14 versions evolving from 173 to 432 lines across development history.

---

## Metadata

- **Priority**: High
- **Complexity**: Medium-High
- **Dependencies**: Issue 035 (complete)
- **Blocks**: Full history reconstruction for projects with existing git history
