# Issue 051c: Issue File Generation from Roadmap

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High
**Created**: 2026-02-12
**Parent**: Issue 051 (Git Repository Documentation Generator)
**Dependencies**: Issue 051a, Issue 051b

---

## Current Behavior

After generating a roadmap, there is no automated way to create individual issue files that correspond to the work done in each commit or commit group. Developers must manually:

1. Read through commits in each phase
2. Identify logical work units
3. Write issue files following naming conventions
4. Structure content with current/intended behavior sections

---

## Intended Behavior

Create a module that transforms roadmap phases into properly structured issue files:

1. **Groups commits** into logical issue units
2. **Generates issue files** following CLAUDE.md conventions
3. **Names issues** with proper {PHASE}{ID}-{DESCR} format
4. **Populates content** from commit messages and file changes
5. **Links issues** to specific commits

### Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                   Issue Generation Pipeline                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐                                          │
│  │ Input:           │                                          │
│  │ - roadmap.json   │                                          │
│  │ - commit_stream  │                                          │
│  └────────┬─────────┘                                          │
│           │                                                     │
│  ┌────────▼─────────────────────┐                              │
│  │ For each phase:              │                              │
│  │                              │                              │
│  │  ┌─────────────────────────┐ │                              │
│  │  │ Group commits by:       │ │                              │
│  │  │ - Semantic similarity   │ │                              │
│  │  │ - File overlap          │ │                              │
│  │  │ - Time proximity        │ │                              │
│  │  └───────────┬─────────────┘ │                              │
│  │              │               │                              │
│  │  ┌───────────▼─────────────┐ │                              │
│  │  │ For each commit group:  │ │                              │
│  │  │                         │ │                              │
│  │  │  - Generate issue ID    │ │                              │
│  │  │  - Extract title        │ │                              │
│  │  │  - Populate sections    │ │                              │
│  │  │  - Link commits         │ │                              │
│  │  │  - Write issue file     │ │                              │
│  │  └───────────┬─────────────┘ │                              │
│  │              │               │                              │
│  └──────────────┼───────────────┘                              │
│                 │                                               │
│  ┌──────────────▼─────────────┐                                │
│  │ Output:                    │                                │
│  │ - issues/{ID}-{descr}.md   │                                │
│  │ - issue-mapping.json       │                                │
│  └────────────────────────────┘                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Suggested Implementation Steps

### 1. Commit Grouping

```bash
# -- {{{ group_commits_into_issues
# Groups commits within a phase into logical issue units
# Returns: JSON array of issue groups
group_commits_into_issues() {
    local phase_json="$1"
    local commit_stream="$2"

    local start_idx end_idx
    start_idx=$(echo "$phase_json" | jq -r '.start_index')
    end_idx=$(echo "$phase_json" | jq -r '.end_index')

    # Extract commits for this phase
    local phase_commits
    phase_commits=$(echo "$commit_stream" | jq --argjson s "$start_idx" --argjson e "$end_idx" \
        '.[$s:$e+1]')

    # Group by semantic similarity (simple: group by common path prefix)
    local groups=()
    local current_group=()
    local current_prefix=""

    echo "$phase_commits" | jq -c '.[]' | while read -r commit; do
        local paths msg
        paths=$(echo "$commit" | jq -r '.changed_paths')
        msg=$(echo "$commit" | jq -r '.message')

        # Extract primary path prefix (first directory)
        local prefix
        prefix=$(echo "$paths" | cut -d',' -f1 | cut -d'/' -f1)

        # Check if this commit belongs to current group
        if [[ "$prefix" == "$current_prefix" ]] || [[ -z "$current_prefix" ]]; then
            current_group+=("$commit")
            current_prefix="$prefix"
        else
            # Start new group
            if [[ ${#current_group[@]} -gt 0 ]]; then
                echo "${current_group[@]}" | jq -s '.'
            fi
            current_group=("$commit")
            current_prefix="$prefix"
        fi
    done

    # Output final group
    if [[ ${#current_group[@]} -gt 0 ]]; then
        echo "${current_group[@]}" | jq -s '.'
    fi
}
# }}}

# -- {{{ group_commits_llm_assisted
# Uses LLM to group commits into logical issues
group_commits_llm_assisted() {
    local phase_commits="$1"
    local phase_name="$2"

    if [[ "$LLM_ENABLED" != true ]]; then
        group_commits_heuristic "$phase_commits"
        return
    fi

    local commit_list
    commit_list=$(echo "$phase_commits" | jq -r '.[] | "\(.hash[0:7]): \(.message[0:50])"')

    local prompt
    prompt="Group these commits from phase '$phase_name' into logical issue units.
Each issue should represent a coherent piece of work.

Commits:
$commit_list

Output JSON array where each element is an issue containing:
- 'title': Short descriptive title (3-6 words)
- 'commits': Array of commit hashes belonging to this issue
- 'type': One of 'feature', 'fix', 'refactor', 'docs', 'test', 'chore'

Example:
[
  {\"title\": \"Add user authentication\", \"commits\": [\"abc1234\", \"def5678\"], \"type\": \"feature\"},
  {\"title\": \"Fix login redirect\", \"commits\": [\"ghi9012\"], \"type\": \"fix\"}
]

Respond with ONLY the JSON array."

    query_local_llm "$prompt"
}
# }}}
```

### 2. Issue ID Generation

```bash
# -- {{{ generate_issue_id
# Generates proper issue ID following CLAUDE.md conventions
# Format: {PHASE}{ID}-{DESCR}
generate_issue_id() {
    local phase_num="$1"
    local issue_num="$2"
    local title="$3"

    # Format phase number (single digit)
    local phase_prefix
    phase_prefix=$(printf "%d" "$phase_num")

    # Format issue number (2-3 digits)
    local issue_id
    issue_id=$(printf "%02d" "$issue_num")

    # Convert title to slug
    local slug
    slug=$(echo "$title" | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-z0-9]/-/g' | \
        sed 's/--*/-/g' | \
        sed 's/^-//' | \
        sed 's/-$//' | \
        cut -c1-40)

    echo "${phase_prefix}${issue_id}-${slug}"
}
# }}}
```

### 3. Issue Content Generation

```bash
# -- {{{ generate_issue_content
# Generates issue file content from commit group
generate_issue_content() {
    local issue_title="$1"
    local issue_type="$2"
    local commits_json="$3"
    local phase_num="$4"
    local issue_id="$5"

    local commit_hashes
    commit_hashes=$(echo "$commits_json" | jq -r '.[].hash')

    local commit_messages
    commit_messages=$(echo "$commits_json" | jq -r '.[].message')

    local changed_files
    changed_files=$(echo "$commits_json" | jq -r '.[].changed_paths' | tr ',' '\n' | sort -u)

    cat << EOF
# Issue $issue_id: $issue_title

**Phase**: $phase_num
**Status**: Open
**Type**: $issue_type
**Created**: $(date +%Y-%m-%d)
**Generated From**: Git commit analysis

---

## Current Behavior

*This issue was auto-generated from git history analysis.*

Based on commit analysis, this work unit addresses:
$(echo "$commit_messages" | head -1)

---

## Intended Behavior

$(case "$issue_type" in
    feature) echo "Implement new functionality as described in commits." ;;
    fix) echo "Resolve the issue identified in related commits." ;;
    refactor) echo "Improve code structure without changing behavior." ;;
    docs) echo "Update documentation to reflect current state." ;;
    test) echo "Add or improve test coverage." ;;
    chore) echo "Perform maintenance tasks." ;;
    *) echo "Complete the work described in related commits." ;;
esac)

---

## Related Commits

$(echo "$commit_hashes" | while read -r hash; do
    local msg
    msg=$(echo "$commits_json" | jq -r --arg h "$hash" '.[] | select(.hash == $h) | .message')
    echo "- \`$hash\`: $msg"
done)

---

## Files Changed

$(echo "$changed_files" | head -20 | while read -r file; do
    echo "- \`$file\`"
done)
$([ $(echo "$changed_files" | wc -l) -gt 20 ] && echo "- *(and $(( $(echo "$changed_files" | wc -l) - 20 )) more files)*")

---

## Suggested Implementation Steps

1. Review related commits for context
2. Verify current state matches expected outcome
3. Document any deviations or follow-up work needed
4. Mark as completed if work is done

---

## Metadata

- **Complexity**: $(case "$issue_type" in feature) echo "Medium" ;; fix) echo "Low" ;; refactor) echo "Medium" ;; *) echo "Low" ;; esac)
- **Auto-Generated**: Yes
- **Source**: Issue 051 (Git Documentation Generator)

---

*This issue file was automatically generated from git commit history.*
*Please review and refine as needed.*
EOF
}
# }}}
```

### 4. Issue File Writer

```bash
# -- {{{ write_issue_file
# Writes an issue file to the issues directory
write_issue_file() {
    local issue_id="$1"
    local content="$2"
    local output_dir="$3"

    local file_path="$output_dir/issues/${issue_id}.md"

    # Check if file exists
    if [[ -f "$file_path" ]]; then
        log "Issue file exists, skipping: $file_path"
        return 1
    fi

    mkdir -p "$output_dir/issues"
    echo "$content" > "$file_path"
    log "Generated: $file_path"
}
# }}}
```

### 5. Main Generation Loop

```bash
# -- {{{ generate_issues_from_roadmap
# Main function to generate all issue files
generate_issues_from_roadmap() {
    local roadmap_json="$1"
    local commit_stream="$2"
    local output_dir="$3"

    local issue_mapping="{\"issues\": ["
    local first_issue=true
    local total_issues=0

    # Process each phase
    echo "$roadmap_json" | jq -c '.phases[]' | while read -r phase; do
        local phase_num phase_name
        phase_num=$(echo "$phase" | jq -r '.number')
        phase_name=$(echo "$phase" | jq -r '.name')

        log "Processing Phase $phase_num: $phase_name"

        # Get commits for this phase
        local start_idx end_idx
        start_idx=$(echo "$phase" | jq -r '.start_index')
        end_idx=$(echo "$phase" | jq -r '.end_index')

        local phase_commits
        phase_commits=$(echo "$commit_stream" | jq --argjson s "$start_idx" --argjson e "$end_idx" \
            '.[$s:$e+1]')

        # Group commits into issues
        local issue_groups
        issue_groups=$(group_commits_llm_assisted "$phase_commits" "$phase_name")

        # Generate issue for each group
        local issue_num=1
        echo "$issue_groups" | jq -c '.[]' | while read -r group; do
            local title type commits
            title=$(echo "$group" | jq -r '.title')
            type=$(echo "$group" | jq -r '.type')
            commits=$(echo "$group" | jq -r '.commits')

            # Get full commit data for these hashes
            local commit_data
            commit_data=$(echo "$phase_commits" | jq --argjson hashes "$commits" \
                '[.[] | select(.hash as $h | $hashes | index($h[0:7]))]')

            # Generate issue ID
            local issue_id
            issue_id=$(generate_issue_id "$phase_num" "$issue_num" "$title")

            # Generate content
            local content
            content=$(generate_issue_content "$title" "$type" "$commit_data" "$phase_num" "$issue_id")

            # Write file
            write_issue_file "$issue_id" "$content" "$output_dir"

            # Track mapping
            [[ "$first_issue" == true ]] || issue_mapping+=","
            first_issue=false
            issue_mapping+="{\"id\": \"$issue_id\", \"phase\": $phase_num, \"commits\": $commits}"

            ((issue_num++))
            ((total_issues++))
        done
    done

    issue_mapping+="]}"

    # Write mapping file
    echo "$issue_mapping" | jq '.' > "$output_dir/tmp/issue-mapping.json"
    log "Generated $total_issues issue files"
    log "Mapping saved to: $output_dir/tmp/issue-mapping.json"
}
# }}}
```

---

## Output Format

### Issue File Example

```markdown
# Issue 201-add-user-authentication: Add User Authentication

**Phase**: 2
**Status**: Open
**Type**: feature
**Created**: 2026-02-12
**Generated From**: Git commit analysis

---

## Current Behavior

*This issue was auto-generated from git history analysis.*

Based on commit analysis, this work unit addresses:
Add login form and session management

---

## Intended Behavior

Implement new functionality as described in commits.

---

## Related Commits

- `abc1234`: Add login form component
- `def5678`: Implement session storage
- `ghi9012`: Add logout functionality

---

## Files Changed

- `src/auth/login.lua`
- `src/auth/session.lua`
- `src/components/LoginForm.lua`

---

## Metadata

- **Complexity**: Medium
- **Auto-Generated**: Yes
- **Source**: Issue 051 (Git Documentation Generator)
```

### issue-mapping.json

```json
{
  "issues": [
    {
      "id": "101-initial-setup",
      "phase": 1,
      "commits": ["abc1234", "def5678"]
    },
    {
      "id": "102-add-configuration",
      "phase": 1,
      "commits": ["ghi9012"]
    },
    {
      "id": "201-add-user-authentication",
      "phase": 2,
      "commits": ["jkl3456", "mno7890", "pqr1234"]
    }
  ]
}
```

---

## Acceptance Criteria

- [ ] Groups commits into logical issue units (heuristic or LLM)
- [ ] Generates issue IDs following {PHASE}{ID}-{DESCR} convention
- [ ] Populates issue content from commit data
- [ ] Writes issue files to issues/ directory
- [ ] Creates issue-mapping.json linking issues to commits
- [ ] Handles various issue types (feature, fix, refactor, etc.)
- [ ] Skips existing issue files (no overwrites)
- [ ] Works without LLM (heuristic fallback)

---

## Metadata

- **Priority**: High
- **Complexity**: Medium
- **Dependencies**: Issue 051a, 051b
- **Blocks**: 051d
