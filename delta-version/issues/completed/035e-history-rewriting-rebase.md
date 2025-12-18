# Issue 035e: History Rewriting with Orphan Branch and Rebase

## Parent Issue
- **Issue 035**: Project History Reconstruction from Issue Files

## Current Behavior

The `reconstruct-history.sh` script creates a new git history on an orphan branch with:
1. Vision file commit
2. One commit per completed issue (with associated files if enabled)
3. Bulk commit with remaining files

However, the script does NOT handle projects that have **additional commits after the initial blob import**. These "post-blob" commits contain real work that must be preserved.

### Example (Current Problem)
```
Original history (master):
  commit A: "Initial import" (blob with 6000 files)     ← flat blob
  commit B: "Fix critical bug in parser"                ← real work, must preserve!
  commit C: "Add new export feature"                    ← real work, must preserve!
  commit D: "Update documentation"                      ← real work, must preserve!
```

Running `reconstruct-history.sh` currently creates:
```
reconstructed-history (orphan):
  commit 1: "Initial vision"
  commit 2: "Issue 001: ..."
  ...
  commit N: "Import remaining files"
```

The post-blob commits (B, C, D) are **lost** because they're only on the original branch.

## Intended Behavior

Preserve post-blob commits by rebasing them onto the reconstructed history.

### Example (Target)
```
Final history:
  commit 1: "Initial vision"
  commit 2: "Issue 001: ..."
  ...
  commit N: "Import remaining files"
  commit N+1: "Fix critical bug in parser"      ← preserved from B
  commit N+2: "Add new export feature"          ← preserved from C
  commit N+3: "Update documentation"            ← preserved from D
```

### Workflow
```
┌─────────────────────────────────────────────────────────────────┐
│                    Post-Blob Commit Preservation                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. IDENTIFY POST-BLOB COMMITS                                  │
│     ┌────────────────────────────────────────┐                  │
│     │ git log --oneline BLOB_COMMIT..HEAD    │                  │
│     │ → B: Fix critical bug                  │                  │
│     │ → C: Add new export feature            │                  │
│     │ → D: Update documentation              │                  │
│     └────────────────────────────────────────┘                  │
│                                                                 │
│  2. SAVE POST-BLOB COMMITS (cherry-pick list)                   │
│     ┌────────────────────────────────────────┐                  │
│     │ Store: [B_hash, C_hash, D_hash]        │                  │
│     └────────────────────────────────────────┘                  │
│                                                                 │
│  3. RECONSTRUCT HISTORY (existing functionality)                │
│     ┌────────────────────────────────────────┐                  │
│     │ git checkout --orphan reconstructed    │                  │
│     │ Create vision → issues → bulk commits  │                  │
│     └────────────────────────────────────────┘                  │
│                                                                 │
│  4. APPLY POST-BLOB COMMITS                                     │
│     ┌────────────────────────────────────────┐                  │
│     │ git cherry-pick B_hash C_hash D_hash   │                  │
│     │ (preserve original dates and authors)  │                  │
│     └────────────────────────────────────────┘                  │
│                                                                 │
│  5. OPTIONALLY REPLACE ORIGINAL BRANCH                          │
│     ┌────────────────────────────────────────┐                  │
│     │ git branch -D master                   │                  │
│     │ git branch -m reconstructed master     │                  │
│     └────────────────────────────────────────┘                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Suggested Implementation Steps

### 1. Add Configuration Variables
```bash
# -- {{{ Post-Blob Configuration (035e)
PRESERVE_POST_BLOB="${PRESERVE_POST_BLOB:-true}"
REPLACE_ORIGINAL="${REPLACE_ORIGINAL:-false}"
POST_BLOB_COMMIT_FILE=""  # Temp file for commit list
# }}}
```

### 2. Identify Blob Commit
```bash
# -- {{{ identify_blob_commit
identify_blob_commit() {
    local project_dir="$1"

    # The blob commit is typically the first commit or a commit with
    # an unusually large number of files added

    cd "$project_dir" || return 1

    # Get first commit
    local first_commit
    first_commit=$(git rev-list --max-parents=0 HEAD 2>/dev/null | head -1)

    # Check if first commit is a blob (many files added)
    local file_count
    file_count=$(git diff-tree --no-commit-id --name-only -r "$first_commit" 2>/dev/null | wc -l)

    if [[ "$file_count" -gt 50 ]]; then
        echo "$first_commit"
        return 0
    fi

    # Could be more sophisticated - look for commits with many files
    # For now, assume first commit is the blob
    echo "$first_commit"
}
# }}}
```

### 3. Identify Post-Blob Commits
```bash
# -- {{{ identify_post_blob_commits
identify_post_blob_commits() {
    local project_dir="$1"
    local blob_commit="$2"

    cd "$project_dir" || return 1

    # Get all commits after the blob commit, oldest first
    git rev-list --reverse "${blob_commit}..HEAD" 2>/dev/null
}
# }}}
```

### 4. Save Post-Blob Commits to Temp File
```bash
# -- {{{ save_post_blob_commits
save_post_blob_commits() {
    local project_dir="$1"
    local blob_commit="$2"
    local output_file="$3"

    cd "$project_dir" || return 1

    # Save commit hashes with metadata for cherry-pick
    git log --reverse --format='%H|%aI|%an|%ae|%s' \
        "${blob_commit}..HEAD" > "$output_file" 2>/dev/null

    local count
    count=$(wc -l < "$output_file")

    if [[ "$count" -gt 0 ]]; then
        log "Found $count post-blob commits to preserve"
        return 0
    else
        log "No post-blob commits found"
        return 1
    fi
}
# }}}
```

### 5. Apply Post-Blob Commits After Reconstruction
```bash
# -- {{{ apply_post_blob_commits
apply_post_blob_commits() {
    local project_dir="$1"
    local commits_file="$2"

    cd "$project_dir" || return 1

    local applied=0
    local failed=0

    while IFS='|' read -r hash date author email message; do
        [[ -z "$hash" ]] && continue

        log "Applying: $message"

        # Cherry-pick with original author and date
        if GIT_AUTHOR_DATE="$date" \
           GIT_AUTHOR_NAME="$author" \
           GIT_AUTHOR_EMAIL="$email" \
           git cherry-pick --no-commit "$hash" 2>/dev/null; then

            # Commit with preserved metadata
            GIT_AUTHOR_DATE="$date" \
            GIT_AUTHOR_NAME="$author" \
            GIT_AUTHOR_EMAIL="$email" \
            GIT_COMMITTER_DATE="$date" \
            git commit -m "$message" 2>/dev/null

            ((applied++))
        else
            warn "Failed to apply commit: $hash ($message)"
            git cherry-pick --abort 2>/dev/null
            ((failed++))
        fi
    done < "$commits_file"

    log "Applied $applied commits, $failed failed"

    [[ "$failed" -gt 0 ]] && return 1
    return 0
}
# }}}
```

### 6. Update reconstruct_history() to Handle Post-Blob
```bash
# In reconstruct_history(), before creating orphan branch:

# Identify and save post-blob commits
local blob_commit
blob_commit=$(identify_blob_commit "$project_dir")

POST_BLOB_COMMIT_FILE=$(mktemp)
local has_post_blob=false

if [[ -n "$blob_commit" ]] && save_post_blob_commits "$project_dir" "$blob_commit" "$POST_BLOB_COMMIT_FILE"; then
    has_post_blob=true
fi

# ... existing orphan branch reconstruction ...

# After reconstruction, apply post-blob commits
if [[ "$has_post_blob" == true ]] && [[ "$PRESERVE_POST_BLOB" == true ]]; then
    log "Applying post-blob commits..."
    apply_post_blob_commits "$project_dir" "$POST_BLOB_COMMIT_FILE"
fi

# Cleanup temp file
rm -f "$POST_BLOB_COMMIT_FILE"
```

### 7. Add Dry-Run Support for Post-Blob
```bash
# In dry_run_report():

echo ""
echo "== Post-Blob Commits =="
local blob_commit
blob_commit=$(identify_blob_commit "$project_dir")

if [[ -n "$blob_commit" ]]; then
    local post_commits
    post_commits=$(identify_post_blob_commits "$project_dir" "$blob_commit")

    if [[ -n "$post_commits" ]]; then
        echo "The following commits will be preserved via cherry-pick:"
        echo ""
        while read -r commit_hash; do
            local msg
            msg=$(git log -1 --format='%s' "$commit_hash" 2>/dev/null)
            local date
            date=$(git log -1 --format='%aI' "$commit_hash" 2>/dev/null)
            echo "    [${commit_hash:0:7}] $date - $msg"
        done <<< "$post_commits"
    else
        echo "No post-blob commits found."
    fi
else
    echo "Could not identify blob commit."
fi
```

### 8. Add CLI Flags
```bash
--preserve-post-blob    Preserve commits after blob import (default: true)
--no-preserve-post-blob Skip post-blob commit preservation
--replace-original      Replace original branch with reconstructed (dangerous!)
```

### 9. Add Help Text
```
Post-Blob Commit Handling:
  Projects may have commits made AFTER the initial "blob" import. These
  represent real work that must be preserved. The script will:

  1. Identify the initial blob commit (large file count)
  2. Save list of commits that came after it
  3. Reconstruct history from issue files
  4. Cherry-pick the post-blob commits onto the new history

  Use --no-preserve-post-blob to skip this behavior.
  Use --replace-original to replace the original branch (DANGEROUS).
```

## Files to Modify

- `delta-version/scripts/reconstruct-history.sh`:
  - Add post-blob configuration variables
  - Add `identify_blob_commit()`
  - Add `identify_post_blob_commits()`
  - Add `save_post_blob_commits()`
  - Add `apply_post_blob_commits()`
  - Update `reconstruct_history()` to handle post-blob flow
  - Update `dry_run_report()` to show post-blob commits
  - Update `parse_args()` with new flags
  - Update `show_help()` with post-blob documentation

## Edge Cases

### Multiple Blob Commits
Some projects may have been imported multiple times:
```
commit A: Initial import (blob 1)
commit B: Work
commit C: Re-import (blob 2)
commit D: More work
```

Strategy: Use the FIRST blob commit as the base, preserve everything after it.

### Merge Commits
Post-blob history may contain merge commits:
```
commit A: Blob
commit B: Work on feature X
commit C: Work on feature Y
commit D: Merge X and Y
```

Strategy: Use `--preserve-merges` or `--rebase-merges` behavior, or warn user and skip merges.

### Conflicts During Cherry-Pick
A cherry-pick may conflict if files were reorganized during reconstruction:
```
Original: src/old-name.lua
Reconstructed: src/new-name.lua (based on issue instructions)
Cherry-pick: Modifies src/old-name.lua → CONFLICT
```

Strategy: Warn user, skip commit, continue. User can manually resolve.

## Testing Strategy

### Test 1: No Post-Blob Commits
```bash
# Project with only blob commit
./reconstruct-history.sh --dry-run /path/to/fresh-import
# Should show: "No post-blob commits found"
```

### Test 2: With Post-Blob Commits
```bash
# Create test scenario
cd /tmp && mkdir test-project && cd test-project
git init
# Create blob commit
touch file{1..100}.lua && git add . && git commit -m "Initial import"
# Add post-blob commits
echo "fix" >> file1.lua && git commit -am "Fix bug"
echo "feature" >> file2.lua && git commit -am "Add feature"

# Run reconstruction
./reconstruct-history.sh --dry-run /tmp/test-project
# Should show: "2 post-blob commits to preserve"
```

### Test 3: Cherry-Pick Application
```bash
./reconstruct-history.sh /tmp/test-project
# Verify post-blob commits appear after reconstruction
git log --oneline
# Should see: vision → issues → bulk → "Fix bug" → "Add feature"
```

### Test 4: Conflict Handling
```bash
# Create scenario where cherry-pick will conflict
# Run reconstruction and verify graceful handling
```

## Dependencies
- **Issue 035a**: Project detection ✅
- **Issue 035b**: Dependency graph ✅
- **Issue 035c**: Date estimation ✅
- **Issue 035d**: File association ✅
- **Issue 035f**: LLM integration ✅

## Blocks
- **Issue 035**: Completion of parent issue

## Related Documents
- **Issue 035**: Parent issue for project history reconstruction
- **Issue 035a-035f**: Sibling sub-issues

## Metadata
- **Priority**: High (final sub-issue of 035)
- **Complexity**: Medium-High
- **Dependencies**: 035a, 035b, 035c, 035d (035f optional)
- **Blocks**: Issue 035 completion
- **Status**: Completed 2025-12-17

## Success Criteria

- [x] `identify_blob_commit()` finds the initial large import commit
  - Implemented as `get_blob_boundary()` using `find_blob_commits()`
- [x] `identify_post_blob_commits()` lists commits after blob
  - Implemented as `get_post_blob_commits()`
- [x] `save_post_blob_commits()` preserves commit metadata
  - Saves hash, ISO date, author name, email, subject to temp file
- [x] `apply_post_blob_commits()` cherry-picks with original dates/authors
  - Preserves GIT_AUTHOR_DATE, GIT_AUTHOR_NAME, GIT_AUTHOR_EMAIL
- [x] Dry-run shows post-blob commits that will be preserved
  - Shows preserve/lost status based on --preserve-post-blob flag
- [x] Cherry-pick failures are handled gracefully (warn, skip, continue)
  - Aborts cherry-pick on failure, continues with next commit
- [x] `--no-preserve-post-blob` flag disables post-blob handling
- [x] `--replace-original` flag replaces original branch
- [x] Help text documents post-blob behavior
- [x] Projects with no post-blob commits work correctly
  - Falls back to simple `reconstruct_history()`
- [x] Post-blob commits appear in correct order after reconstruction
  - Uses `--reverse` flag in git log

## Completion

**Status**: Completed 2025-12-17

**Implementation**:
- Added `save_post_blob_commits()` and `apply_post_blob_commits()` functions
- Added `reconstruct_history_with_rebase()` for complete workflow
- Updated `process_project()` to use rebase workflow when post-blob commits exist
- Added CLI flags: `--preserve-post-blob`, `--no-preserve-post-blob`, `--replace-original`
- Updated dry-run to show post-blob handling details
- Creates backup branch before reconstruction
- Creates reconstructed history on orphan branch
- Cherry-picks post-blob commits with preserved metadata
