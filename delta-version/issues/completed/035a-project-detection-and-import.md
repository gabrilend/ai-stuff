# Issue 035a: Project Detection and External Import

## Parent Issue
- **035**: Project History Reconstruction from Issue Files

## Current Behavior

The v1 `reconstruct-history.sh` script only handles projects that:
- Are already located somewhere accessible
- Have no existing git history

It does not:
- Detect whether a project is inside or outside the monorepo
- Import external projects into the monorepo
- Classify project state to determine appropriate action
- Preserve file timestamps during import

## Intended Behavior

Add unified project detection and import capabilities:

1. **Monorepo Detection**: Determine if project path is inside `$MONOREPO_ROOT`
2. **External Import**: Copy external projects into monorepo with timestamp preservation
3. **State Classification**: Categorize projects as `external`, `no_git`, `flat_blob`, `sparse_history`, or `good_history`
4. **Workflow Routing**: Direct each state to appropriate reconstruction path

### Project States

| State | Condition | Action |
|-------|-----------|--------|
| `external` | Path outside monorepo | Import first, then classify again |
| `no_git` | No `.git` directory | Initialize fresh history (v1 behavior) |
| `flat_blob` | ≤2 commits, >50 files | Rewrite ONLY initial blob, preserve later commits |
| `sparse_history` | Some commits but poor ratio | Rewrite ONLY initial blob, preserve later commits |
| `good_history` | Healthy commit/file ratio | Skip (unless --force) |

### Critical: Preserving Post-Blob Progress

When a project already exists in the monorepo with history, we must:

1. **Identify the blob boundary**: Find the initial commit(s) that contain bulk-imported files
2. **Scope the rewrite**: Only reconstruct history for files present in the blob commit(s)
3. **Preserve subsequent commits**: Any commits made AFTER the blob must remain intact
4. **Rebase if needed**: Replay post-blob commits on top of reconstructed history

```
BEFORE:                          AFTER:

commit A: "blob: 6000 files"     commit 1: "Vision"
    │                            commit 2: "Issue 001"
    ▼                            commit 3: "Issue 002"
commit B: "fix typo"               ...
    │                            commit N: "Remaining files"
    ▼                                │
commit C: "add feature"              ▼
    │                            commit B': "fix typo" (rebased)
    ▼                                │
commit D: "bugfix"                   ▼
                                 commit C': "add feature" (rebased)
                                     │
                                     ▼
                                 commit D': "bugfix" (rebased)
```

This ensures that real development work is never lost — only the initial "dump everything" commits are expanded into a proper narrative.

## Suggested Implementation Steps

### 1. Add Configuration Variables
```bash
# -- {{{ Configuration
MONOREPO_ROOT="${MONOREPO_ROOT:-/mnt/mtwo/programming/ai-stuff}"
IMPORT_MODE="${IMPORT_MODE:-copy}"  # copy or move
FLAT_BLOB_THRESHOLD=2       # Max commits to be considered flat
FLAT_BLOB_MIN_FILES=50      # Min files to be considered flat blob
GOOD_HISTORY_RATIO=20       # 1 commit per N files = good history
# }}}
```

### 2. Implement Detection Functions
```bash
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

    [[ ! -d "$project_dir/.git" ]] && return 1

    local commit_count file_count
    commit_count=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null || echo "0")
    file_count=$(git -C "$project_dir" ls-files 2>/dev/null | wc -l)

    [[ "$commit_count" -le "$FLAT_BLOB_THRESHOLD" && "$file_count" -gt "$FLAT_BLOB_MIN_FILES" ]]
}
# }}}

# -- {{{ has_good_history
has_good_history() {
    local project_dir="$1"

    [[ ! -d "$project_dir/.git" ]] && return 1

    local commit_count file_count min_commits
    commit_count=$(git -C "$project_dir" rev-list --count HEAD 2>/dev/null || echo "0")
    file_count=$(git -C "$project_dir" ls-files 2>/dev/null | wc -l)

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
```

### 2b. Blob Boundary Detection
```bash
# -- {{{ find_blob_commits
find_blob_commits() {
    local project_dir="$1"

    # Find commits that added a large number of files at once
    # These are likely the "blob" imports we want to expand

    git -C "$project_dir" log --oneline --numstat --reverse | awk '
        /^[0-9a-f]+ / {
            if (commit != "" && additions > 50) {
                print commit
            }
            commit = $1
            additions = 0
        }
        /^[0-9]+\t[0-9]+\t/ {
            additions++
        }
        END {
            if (commit != "" && additions > 50) {
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
        git -C "$project_dir" rev-list --max-parents=0 HEAD | head -1
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
    git -C "$project_dir" ls-tree -r --name-only "$blob_commit"
}
# }}}

# -- {{{ get_post_blob_commits
get_post_blob_commits() {
    local project_dir="$1"
    local blob_commit="$2"

    # Get all commits after the blob commit (these must be preserved)
    git -C "$project_dir" rev-list --reverse "${blob_commit}..HEAD"
}
# }}}

# -- {{{ count_post_blob_commits
count_post_blob_commits() {
    local project_dir="$1"
    local blob_commit="$2"

    git -C "$project_dir" rev-list --count "${blob_commit}..HEAD"
}
# }}}
```

### 3. Implement Import Function
```bash
# -- {{{ import_external_project
import_external_project() {
    local source_dir="$1"
    local project_name="${2:-$(basename "$source_dir")}"
    local target_dir="${MONOREPO_ROOT}/${project_name}"

    # Validate source
    if [[ ! -d "$source_dir" ]]; then
        error "Source directory not found: $source_dir"
        return 1
    fi

    # Check target
    if [[ -d "$target_dir" ]]; then
        if [[ "$FORCE" == true ]]; then
            log "Removing existing target directory (--force)"
            rm -rf "$target_dir"
        else
            error "Target already exists: $target_dir"
            error "Use --force to overwrite or --name to specify different name"
            return 1
        fi
    fi

    log "Importing project:"
    log "  From: $source_dir"
    log "  To:   $target_dir"

    # Preserve timestamps with cp -a
    if [[ "$IMPORT_MODE" == "move" ]]; then
        mv "$source_dir" "$target_dir"
    else
        cp -a "$source_dir" "$target_dir"
    fi

    # Remove existing .git if present (we'll reconstruct)
    if [[ -d "$target_dir/.git" ]]; then
        log "Removing existing .git directory"
        rm -rf "$target_dir/.git"
    fi

    echo "$target_dir"
}
# }}}
```

### 4. Update Main Workflow
```bash
# -- {{{ process_project
process_project() {
    local project_dir="$1"
    local state

    state=$(determine_project_state "$project_dir")
    log "Project state: $state"

    case "$state" in
        external)
            log "Project is external to monorepo"
            local new_dir
            new_dir=$(import_external_project "$project_dir" "$PROJECT_NAME")
            [[ $? -ne 0 ]] && return 1
            project_dir="$new_dir"
            # Re-classify after import
            state=$(determine_project_state "$project_dir")
            log "Post-import state: $state"
            ;&  # Fall through

        no_git)
            log "No git history found, creating from scratch"
            reconstruct_history "$project_dir"
            ;;

        flat_blob|sparse_history)
            log "Poor history detected, will rewrite"
            # TODO: Implement in 035e
            log "History rewriting not yet implemented"
            log "Falling back to v1 behavior (remove .git and recreate)"
            rm -rf "$project_dir/.git"
            reconstruct_history "$project_dir"
            ;;

        good_history)
            if [[ "$FORCE" == true ]]; then
                log "Good history exists but --force specified"
                rm -rf "$project_dir/.git"
                reconstruct_history "$project_dir"
            else
                log "Project already has good commit history"
                log "Use --force to reconstruct anyway"
                return 0
            fi
            ;;
    esac
}
# }}}
```

### 5. Add CLI Options
```bash
# New flags to add:
#   --name NAME      Specify project name for import (default: basename)
#   --move           Move instead of copy when importing
#   --monorepo DIR   Override monorepo root directory
```

## Implementation Details

### Timestamp Preservation
The `cp -a` flag is critical:
- `-a` = archive mode = `-dR --preserve=all`
- Preserves: mode, ownership, timestamps, context, links, xattr
- Without this, all files would have current timestamp, destroying mtime signals

### State Classification Heuristics
```
                    ┌─────────────────┐
                    │ Is in monorepo? │
                    └────────┬────────┘
                             │
                   NO ───────┼─────── YES
                   │         │         │
                   ▼         │         ▼
              [external]     │    ┌────────────┐
                             │    │ Has .git?  │
                             │    └─────┬──────┘
                             │          │
                             │   NO ────┼──── YES
                             │   │      │      │
                             │   ▼      │      ▼
                             │ [no_git] │ ┌──────────────┐
                             │          │ │ ≤2 commits & │
                             │          │ │ >50 files?   │
                             │          │ └──────┬───────┘
                             │          │        │
                             │          │  YES ──┼── NO
                             │          │  │     │    │
                             │          │  ▼     │    ▼
                             │          │ [flat] │ ┌────────────┐
                             │          │        │ │ Good ratio?│
                             │          │        │ └─────┬──────┘
                             │          │        │       │
                             │          │        │ YES ──┼── NO
                             │          │        │ │     │    │
                             │          │        │ ▼     │    ▼
                             │          │        │[good] │ [sparse]
```

## Related Documents
- `035-project-history-reconstruction.md` - Parent issue
- `031-import-project-histories.md` - Original import script (different approach)

## Metadata
- **Priority**: High
- **Complexity**: Medium
- **Dependencies**: None (first sub-issue)
- **Blocks**: 035b, 035c, 035d, 035e
- **Impact**: Enables unified workflow for all project sources

## Success Criteria
- [ ] `is_in_monorepo()` correctly identifies project location
- [ ] `import_external_project()` preserves file timestamps
- [ ] `determine_project_state()` correctly classifies all states
- [ ] External projects can be imported and reconstructed in one command
- [ ] `--name` flag allows custom project naming on import
- [ ] `--move` flag moves instead of copying
- [ ] `--monorepo` flag allows override of monorepo root
- [ ] Dry-run mode shows import plan without executing
- [ ] Good history projects are skipped unless --force
