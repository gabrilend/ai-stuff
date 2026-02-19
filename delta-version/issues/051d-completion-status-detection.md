# Issue 051d: Completion Status Detection

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High
**Created**: 2026-02-12
**Parent**: Issue 051 (Git Repository Documentation Generator)
**Dependencies**: Issue 051c

---

## Current Behavior

Generated issue files are created with "Open" status, even though the work they describe has already been completed (since they're derived from existing commits). There is no automated way to:

1. Determine which issues represent completed work
2. Move completed issues to the `issues/completed/` directory
3. Update the progress tracking file

---

## Intended Behavior

Create a module that:

1. **Analyzes commit evidence** to determine if issue work is complete
2. **Marks issues as completed** with appropriate metadata
3. **Moves completed issues** to `issues/completed/`
4. **Updates progress.md** with completion status

### Completion Detection Logic

```
┌─────────────────────────────────────────────────────────────────┐
│                  Completion Detection                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  For each generated issue:                                      │
│                                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Check 1: All commits exist in history?   │                  │
│  │          (they do, by definition)        │──▶ ✓             │
│  └──────────────────────────────────────────┘                  │
│                                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Check 2: Files from commits exist        │                  │
│  │          in current working tree?        │──▶ Partial match │
│  └──────────────────────────────────────────┘        OK        │
│                                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Check 3: No revert commits found         │                  │
│  │          for these changes?              │──▶ If reverted,  │
│  └──────────────────────────────────────────┘    mark REVERTED │
│                                                                 │
│  ┌──────────────────────────────────────────┐                  │
│  │ Check 4: Later commits don't "fix"       │                  │
│  │          or "revert" this work?          │──▶ Check for     │
│  └──────────────────────────────────────────┘    follow-ups    │
│                                                                 │
│  Result:                                                        │
│  - COMPLETED: All checks pass                                   │
│  - REVERTED: Work was undone                                    │
│  - SUPERSEDED: Work was replaced                                │
│  - PARTIAL: Some work remains incomplete                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Suggested Implementation Steps

### 1. Check Commit Presence

```bash
# -- {{{ verify_commits_exist
# Verifies all commits for an issue exist in current history
verify_commits_exist() {
    local commits_json="$1"
    local project_dir="$2"

    cd "$project_dir" || return 1

    local all_exist=true
    echo "$commits_json" | jq -r '.[]' | while read -r hash; do
        if ! git cat-file -t "$hash" &>/dev/null; then
            log "Warning: Commit $hash not found in history"
            all_exist=false
        fi
    done

    [[ "$all_exist" == true ]]
}
# }}}
```

### 2. Check for Reverts

```bash
# -- {{{ check_for_reverts
# Checks if any commits were later reverted
# Returns: JSON with revert information
check_for_reverts() {
    local commits_json="$1"
    local project_dir="$2"

    cd "$project_dir" || return 1

    local reverts=()

    echo "$commits_json" | jq -r '.[]' | while read -r hash; do
        # Look for "Revert" commits that reference this hash
        local revert_commit
        revert_commit=$(git log --grep="Revert.*$hash" --grep="revert.*${hash:0:7}" \
            --pretty=format:"%H" | head -1)

        if [[ -n "$revert_commit" ]]; then
            echo "{\"original\": \"$hash\", \"revert\": \"$revert_commit\"}"
        fi
    done | jq -s '.'
}
# }}}
```

### 3. Check File Existence

```bash
# -- {{{ check_files_exist
# Checks if files from commits still exist
# Returns: JSON with existence status
check_files_exist() {
    local commits_json="$1"
    local project_dir="$2"

    cd "$project_dir" || return 1

    local results=()

    # Get all unique files from commits
    local files
    files=$(echo "$commits_json" | jq -r '.[].changed_paths' | tr ',' '\n' | sort -u)

    local exists=0
    local missing=0

    for file in $files; do
        if [[ -f "$file" ]]; then
            ((exists++))
        else
            ((missing++))
        fi
    done

    local total=$((exists + missing))
    local ratio=100
    [[ $total -gt 0 ]] && ratio=$((exists * 100 / total))

    echo "{\"exists\": $exists, \"missing\": $missing, \"ratio\": $ratio}"
}
# }}}
```

### 4. Determine Completion Status

```bash
# -- {{{ determine_completion_status
# Determines overall completion status for an issue
# Returns: status string and reason
determine_completion_status() {
    local issue_id="$1"
    local commits_json="$2"
    local project_dir="$3"

    # Check for reverts
    local reverts
    reverts=$(check_for_reverts "$commits_json" "$project_dir")

    local revert_count
    revert_count=$(echo "$reverts" | jq 'length')

    if [[ "$revert_count" -gt 0 ]]; then
        echo "REVERTED|Work was reverted in later commits"
        return
    fi

    # Check file existence
    local file_status
    file_status=$(check_files_exist "$commits_json" "$project_dir")

    local ratio
    ratio=$(echo "$file_status" | jq -r '.ratio')

    if [[ "$ratio" -lt 50 ]]; then
        echo "SUPERSEDED|Most files no longer exist (refactored or removed)"
        return
    fi

    # Default: if commits exist and weren't reverted, work is complete
    # (Since we're generating from existing history, the work is done)
    echo "COMPLETED|Work verified in git history"
}
# }}}
```

### 5. Update Issue File

```bash
# -- {{{ mark_issue_completed
# Updates issue file with completion status
mark_issue_completed() {
    local issue_file="$1"
    local status="$2"
    local reason="$3"
    local completion_date="$4"

    # Read current content
    local content
    content=$(cat "$issue_file")

    # Update status line
    content=$(echo "$content" | sed "s/^\*\*Status\*\*:.*/\*\*Status\*\*: $status/")

    # Add completion metadata
    local completion_section="
---

## Completion Details

- **Status**: $status
- **Completed**: $completion_date
- **Verification**: $reason
- **Auto-Detected**: Yes (Issue 051d)
"

    # Append completion section before final metadata
    echo "$content" | sed "/^## Metadata/i\\$completion_section" > "$issue_file"
}
# }}}
```

### 6. Move to Completed

```bash
# -- {{{ move_to_completed
# Moves completed issue to issues/completed/
move_to_completed() {
    local issue_file="$1"
    local output_dir="$2"

    local filename
    filename=$(basename "$issue_file")

    local completed_dir="$output_dir/issues/completed"
    mkdir -p "$completed_dir"

    mv "$issue_file" "$completed_dir/$filename"
    log "Moved to completed: $filename"
}
# }}}
```

### 7. Update Progress File

```bash
# -- {{{ update_progress_file
# Updates or creates progress.md with completion status
update_progress_file() {
    local output_dir="$1"
    local roadmap_json="$2"
    local issue_mapping="$3"

    local progress_file="$output_dir/issues/progress.md"

    cat << EOF > "$progress_file"
# Project Progress

*Auto-generated from git history analysis*
*Last updated: $(date -Iseconds)*

---

EOF

    # Process each phase
    echo "$roadmap_json" | jq -c '.phases[]' | while read -r phase; do
        local phase_num phase_name
        phase_num=$(echo "$phase" | jq -r '.number')
        phase_name=$(echo "$phase" | jq -r '.name')

        # Count issues for this phase
        local total completed
        total=$(echo "$issue_mapping" | jq --argjson p "$phase_num" \
            '[.issues[] | select(.phase == $p)] | length')

        # Count completed (files in completed/ directory)
        completed=$(ls "$output_dir/issues/completed/${phase_num}"*.md 2>/dev/null | wc -l)

        cat << EOF >> "$progress_file"
## Phase $phase_num: $phase_name

**Status**: $completed/$total issues completed

| Issue | Title | Status |
|-------|-------|--------|
EOF

        # List issues for this phase
        echo "$issue_mapping" | jq -r --argjson p "$phase_num" \
            '.issues[] | select(.phase == $p) | "\(.id)"' | while read -r issue_id; do

            local title status
            if [[ -f "$output_dir/issues/completed/${issue_id}.md" ]]; then
                status="✅ Complete"
                title=$(grep "^# Issue" "$output_dir/issues/completed/${issue_id}.md" | \
                    sed 's/^# Issue [^:]*: //')
            elif [[ -f "$output_dir/issues/${issue_id}.md" ]]; then
                status="📝 Open"
                title=$(grep "^# Issue" "$output_dir/issues/${issue_id}.md" | \
                    sed 's/^# Issue [^:]*: //')
            else
                status="❓ Missing"
                title="Unknown"
            fi

            echo "| $issue_id | $title | $status |" >> "$progress_file"
        done

        echo "" >> "$progress_file"
    done

    log "Updated: $progress_file"
}
# }}}
```

### 8. Main Detection Loop

```bash
# -- {{{ detect_and_mark_completions
# Main function to detect and mark all completions
detect_and_mark_completions() {
    local issue_mapping="$1"
    local commit_stream="$2"
    local output_dir="$3"

    local completed_count=0

    echo "$issue_mapping" | jq -c '.issues[]' | while read -r issue; do
        local issue_id commits
        issue_id=$(echo "$issue" | jq -r '.id')
        commits=$(echo "$issue" | jq -r '.commits')

        local issue_file="$output_dir/issues/${issue_id}.md"

        if [[ ! -f "$issue_file" ]]; then
            log "Issue file not found: $issue_file"
            continue
        fi

        # Get full commit data
        local commit_data
        commit_data=$(echo "$commit_stream" | jq --argjson hashes "$commits" \
            '[.[] | select(.hash[0:7] as $h | $hashes | index($h))]')

        # Determine status
        local status_result
        status_result=$(determine_completion_status "$issue_id" "$commit_data" "$output_dir")

        local status reason
        status=$(echo "$status_result" | cut -d'|' -f1)
        reason=$(echo "$status_result" | cut -d'|' -f2)

        # Get completion date from last commit
        local completion_date
        completion_date=$(echo "$commit_data" | jq -r '.[-1].date' | cut -d' ' -f1)

        log "Issue $issue_id: $status"

        if [[ "$status" == "COMPLETED" ]]; then
            mark_issue_completed "$issue_file" "Completed" "$reason" "$completion_date"
            move_to_completed "$issue_file" "$output_dir"
            ((completed_count++))
        elif [[ "$status" == "REVERTED" ]]; then
            mark_issue_completed "$issue_file" "Reverted" "$reason" "$completion_date"
        elif [[ "$status" == "SUPERSEDED" ]]; then
            mark_issue_completed "$issue_file" "Superseded" "$reason" "$completion_date"
            move_to_completed "$issue_file" "$output_dir"
            ((completed_count++))
        fi
    done

    log "Marked $completed_count issues as completed"
}
# }}}
```

---

## Output

### Updated Issue File (in completed/)

```markdown
# Issue 201-add-user-authentication: Add User Authentication

**Phase**: 2
**Status**: Completed

...

---

## Completion Details

- **Status**: COMPLETED
- **Completed**: 2024-06-15
- **Verification**: Work verified in git history
- **Auto-Detected**: Yes (Issue 051d)

---

## Metadata
...
```

### progress.md

```markdown
# Project Progress

*Auto-generated from git history analysis*
*Last updated: 2026-02-12T10:30:00Z*

---

## Phase 1: Foundation

**Status**: 5/5 issues completed

| Issue | Title | Status |
|-------|-------|--------|
| 101-initial-setup | Initial Setup | ✅ Complete |
| 102-add-configuration | Add Configuration | ✅ Complete |
| 103-implement-logging | Implement Logging | ✅ Complete |
| 104-create-cli | Create CLI | ✅ Complete |
| 105-add-tests | Add Tests | ✅ Complete |

## Phase 2: Core Features

**Status**: 3/3 issues completed

| Issue | Title | Status |
|-------|-------|--------|
| 201-add-user-authentication | Add User Authentication | ✅ Complete |
| 202-implement-api | Implement API | ✅ Complete |
| 203-add-caching | Add Caching | ✅ Complete |
```

---

## Acceptance Criteria

- [ ] Detects completed issues based on commit presence
- [ ] Identifies reverted work
- [ ] Identifies superseded work (files removed/refactored)
- [ ] Updates issue files with completion metadata
- [ ] Moves completed issues to issues/completed/
- [ ] Generates/updates progress.md
- [ ] Handles edge cases (missing commits, empty issues)

---

## Metadata

- **Priority**: High
- **Complexity**: Medium
- **Dependencies**: Issue 051c
- **Blocks**: 051e (demos need to know which phases are complete)
