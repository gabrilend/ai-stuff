# Issue 051b: AI-Assisted Roadmap Generation

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High
**Created**: 2026-02-12
**Parent**: Issue 051 (Git Repository Documentation Generator)
**Dependencies**: Issue 051a (Initial Commit Analysis)

---

## Current Behavior

No automated method exists to generate a development roadmap from git history. Developers must manually:

1. Read through all commits chronologically
2. Identify logical phase boundaries
3. Group commits into meaningful milestones
4. Write roadmap documentation by hand

This is especially difficult for unfamiliar codebases or projects with hundreds of commits.

---

## Intended Behavior

Create an AI-assisted module that:

1. **Analyzes commit history** to identify natural phase boundaries
2. **Groups commits** into logical development phases
3. **Generates roadmap** with phase names, descriptions, and commit mappings
4. **Uses LLM tool-calls** as a programmatic API for intelligent analysis
5. **Falls back to heuristics** when LLM is unavailable

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Roadmap Generation Pipeline                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────┐                                           │
│  │ Input: kernel.json +        │                                           │
│  │        goal.json +          │                                           │
│  │        git log              │                                           │
│  └────────────┬────────────────┘                                           │
│               │                                                             │
│  ┌────────────▼────────────────┐                                           │
│  │ Commit Stream Preparation   │                                           │
│  │ - Parse all commits         │                                           │
│  │ - Extract: hash, msg, date  │                                           │
│  │ - Detect file changes       │                                           │
│  └────────────┬────────────────┘                                           │
│               │                                                             │
│  ┌────────────▼────────────────┐                                           │
│  │ Boundary Detection          │                                           │
│  │ ┌──────────────────────┐    │                                           │
│  │ │ Heuristic Signals:   │    │                                           │
│  │ │ - Large commits      │    │                                           │
│  │ │ - Time gaps          │    │                                           │
│  │ │ - Version changes    │    │                                           │
│  │ │ - README updates     │    │                                           │
│  │ │ - Directory changes  │    │                                           │
│  │ └──────────────────────┘    │                                           │
│  └────────────┬────────────────┘                                           │
│               │                                                             │
│  ┌────────────▼────────────────────────────────────────┐                   │
│  │ LLM Phase Analysis (Tool-Call API)                  │                   │
│  │                                                      │                   │
│  │  Prompt: "Given these commits and boundaries,        │                   │
│  │           identify N logical phases..."              │                   │
│  │                                                      │                   │
│  │  Response: JSON with phase assignments               │                   │
│  │                                                      │                   │
│  │  ┌────────────────────────────────────────┐         │                   │
│  │  │ Triple-Check Consensus:                │         │                   │
│  │  │ - Query 3 times                        │         │                   │
│  │  │ - Compare phase counts                 │         │                   │
│  │  │ - Merge assignments                    │         │                   │
│  │  └────────────────────────────────────────┘         │                   │
│  └────────────┬────────────────────────────────────────┘                   │
│               │                                                             │
│  ┌────────────▼────────────────┐                                           │
│  │ Roadmap Assembly            │                                           │
│  │ - Name each phase           │                                           │
│  │ - Write descriptions        │                                           │
│  │ - List key accomplishments  │                                           │
│  │ - Map commits to phases     │                                           │
│  └────────────┬────────────────┘                                           │
│               │                                                             │
│  ┌────────────▼────────────────┐                                           │
│  │ Output: roadmap.json +      │                                           │
│  │         docs/roadmap.md     │                                           │
│  └─────────────────────────────┘                                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Suggested Implementation Steps

### 1. Commit Stream Preparation

```bash
# -- {{{ prepare_commit_stream
# Extracts all commits with metadata for analysis
# Output: JSON array of commit objects
prepare_commit_stream() {
    local project_dir="$1"
    local limit="${2:-500}"  # Max commits to analyze

    cd "$project_dir" || return 1

    echo "["
    local first=true
    local count=0

    while IFS= read -r line; do
        [[ "$first" == true ]] || echo ","
        first=false
        ((count++))
        [[ $count -gt $limit ]] && break

        local hash msg date author files_changed insertions deletions
        hash=$(echo "$line" | cut -d'|' -f1)
        msg=$(echo "$line" | cut -d'|' -f2 | sed 's/"/\\"/g')
        date=$(echo "$line" | cut -d'|' -f3)
        author=$(echo "$line" | cut -d'|' -f4)

        # Get diff stats
        local stats
        stats=$(git show --stat --format="" "$hash" | tail -1)
        files_changed=$(echo "$stats" | grep -oE '[0-9]+ file' | cut -d' ' -f1 || echo "0")
        insertions=$(echo "$stats" | grep -oE '[0-9]+ insertion' | cut -d' ' -f1 || echo "0")
        deletions=$(echo "$stats" | grep -oE '[0-9]+ deletion' | cut -d' ' -f1 || echo "0")

        # Get changed file paths
        local changed_files
        changed_files=$(git show --name-only --format="" "$hash" | head -10 | paste -sd,)

        printf '  {
    "hash": "%s",
    "message": "%s",
    "date": "%s",
    "author": "%s",
    "files_changed": %d,
    "insertions": %d,
    "deletions": %d,
    "changed_paths": "%s"
  }' "$hash" "$msg" "$date" "$author" \
       "${files_changed:-0}" "${insertions:-0}" "${deletions:-0}" "$changed_files"

    done < <(git log --reverse --pretty=format:'%H|%s|%ci|%an')

    echo ""
    echo "]"
}
# }}}
```

### 2. Heuristic Boundary Detection

```bash
# -- {{{ detect_phase_boundaries
# Uses heuristics to identify potential phase boundaries
# Returns: JSON array of boundary indicators
detect_phase_boundaries() {
    local commit_stream="$1"
    local project_dir="$2"

    cd "$project_dir" || return 1

    local boundaries=()
    local prev_date=""
    local commit_index=0

    echo "["
    local first=true

    while IFS= read -r commit_json; do
        [[ -z "$commit_json" || "$commit_json" == "[" || "$commit_json" == "]" ]] && continue

        local hash msg date files_changed
        hash=$(echo "$commit_json" | jq -r '.hash')
        msg=$(echo "$commit_json" | jq -r '.message')
        date=$(echo "$commit_json" | jq -r '.date')
        files_changed=$(echo "$commit_json" | jq -r '.files_changed')

        local signals=()

        # Signal 1: Large commit (>20 files changed)
        [[ "$files_changed" -gt 20 ]] && signals+=("large_commit")

        # Signal 2: Version bump in message
        [[ "$msg" =~ [vV]?[0-9]+\.[0-9]+ ]] && signals+=("version_change")

        # Signal 3: Keywords indicating phase end/start
        [[ "$msg" =~ [Rr]elease|[Mm]erge|[Cc]omplete|[Ff]inish|[Pp]hase ]] && signals+=("milestone_keyword")

        # Signal 4: README update
        local changed_paths
        changed_paths=$(echo "$commit_json" | jq -r '.changed_paths')
        [[ "$changed_paths" =~ README ]] && signals+=("readme_update")

        # Signal 5: Time gap (>7 days from previous)
        if [[ -n "$prev_date" ]]; then
            local gap
            gap=$(( $(date -d "$date" +%s) - $(date -d "$prev_date" +%s) ))
            [[ $gap -gt 604800 ]] && signals+=("time_gap")
        fi

        # Signal 6: Directory structure change (new top-level dir)
        [[ "$changed_paths" =~ ^[a-z]+/ ]] && signals+=("new_directory")

        # If we have signals, record this as a boundary candidate
        if [[ ${#signals[@]} -gt 0 ]]; then
            [[ "$first" == true ]] || echo ","
            first=false

            printf '  {
    "commit_index": %d,
    "hash": "%s",
    "message": "%s",
    "signals": ["%s"],
    "signal_count": %d
  }' "$commit_index" "$hash" "$msg" "$(IFS=','; echo "${signals[*]}")" "${#signals[@]}"
        fi

        prev_date="$date"
        ((commit_index++))

    done < <(echo "$commit_stream" | jq -c '.[]')

    echo ""
    echo "]"
}
# }}}
```

### 3. LLM Phase Analysis

```bash
# -- {{{ llm_analyze_phases
# Uses LLM to analyze commits and assign phases
# Returns: JSON with phase assignments
llm_analyze_phases() {
    local commit_stream="$1"
    local boundaries="$2"
    local kernel="$3"
    local goal="$4"
    local target_phases="${5:-auto}"

    if [[ "$LLM_ENABLED" != true ]]; then
        # Fallback to heuristic-only phasing
        heuristic_phase_assignment "$commit_stream" "$boundaries"
        return
    fi

    local commit_summary
    commit_summary=$(echo "$commit_stream" | jq -r '
        .[] | "\(.hash[0:7]) - \(.message[0:60])"
    ' | head -100)

    local boundary_summary
    boundary_summary=$(echo "$boundaries" | jq -r '
        .[] | "Index \(.commit_index): \(.message[0:40]) [signals: \(.signals | join(", "))]"
    ')

    local prompt
    prompt="You are analyzing a git repository to create a development roadmap.

PROJECT KERNEL (original vision):
$kernel

PROJECT GOAL (current state):
$goal

COMMIT HISTORY (chronological, first 100):
$commit_summary

DETECTED BOUNDARY CANDIDATES:
$boundary_summary

TASK: Divide this commit history into logical development phases.
$([ "$target_phases" != "auto" ] && echo "Target: $target_phases phases")

For each phase, provide:
1. Phase number (1, 2, 3, ...)
2. Phase name (e.g., 'Foundation', 'Core Features', 'Polish')
3. Description (1-2 sentences)
4. Start commit index (0-based)
5. End commit index (0-based)
6. Key accomplishments (3-5 bullet points)

OUTPUT FORMAT (JSON only, no markdown):
{
  \"phases\": [
    {
      \"number\": 1,
      \"name\": \"Foundation\",
      \"description\": \"Initial project setup and core infrastructure\",
      \"start_index\": 0,
      \"end_index\": 15,
      \"accomplishments\": [\"Created project structure\", \"Added base configuration\"]
    }
  ]
}

Respond with ONLY the JSON, no explanations."

    query_local_llm "$prompt"
}
# }}}
```

### 4. Triple-Check Consensus

```bash
# -- {{{ roadmap_with_consensus
# Gets multiple LLM responses and finds consensus
roadmap_with_consensus() {
    local commit_stream="$1"
    local boundaries="$2"
    local kernel="$3"
    local goal="$4"

    local -a responses
    local i

    # Get 3 independent responses
    for i in 1 2 3; do
        log "LLM roadmap query $i/3..."
        responses+=("$(llm_analyze_phases "$commit_stream" "$boundaries" "$kernel" "$goal")")
        record_llm_result "success"  # Track for stats
    done

    # Find consensus on phase count
    local -a phase_counts
    for response in "${responses[@]}"; do
        local count
        count=$(echo "$response" | jq -r '.phases | length' 2>/dev/null || echo "0")
        phase_counts+=("$count")
    done

    # Get most common phase count
    local consensus_count
    consensus_count=$(printf '%s\n' "${phase_counts[@]}" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')

    log "Phase count consensus: $consensus_count phases"

    # Merge phase assignments
    # Use the response with the consensus phase count, preferring first match
    for response in "${responses[@]}"; do
        local count
        count=$(echo "$response" | jq -r '.phases | length' 2>/dev/null || echo "0")
        if [[ "$count" == "$consensus_count" ]]; then
            echo "$response"
            return 0
        fi
    done

    # Fallback: return first response
    echo "${responses[0]}"
}
# }}}
```

### 5. Heuristic Fallback

```bash
# -- {{{ heuristic_phase_assignment
# Assigns phases using only heuristic boundaries (no LLM)
heuristic_phase_assignment() {
    local commit_stream="$1"
    local boundaries="$2"

    local total_commits
    total_commits=$(echo "$commit_stream" | jq -r 'length')

    # Get top boundary candidates (sorted by signal count)
    local top_boundaries
    top_boundaries=$(echo "$boundaries" | jq -r '
        sort_by(.signal_count) | reverse | .[0:5] | .[].commit_index
    ')

    # If no strong boundaries, divide evenly into 3-4 phases
    if [[ -z "$top_boundaries" ]]; then
        local phase_size=$((total_commits / 3))
        echo "{
  \"phases\": [
    {\"number\": 1, \"name\": \"Foundation\", \"start_index\": 0, \"end_index\": $((phase_size - 1))},
    {\"number\": 2, \"name\": \"Development\", \"start_index\": $phase_size, \"end_index\": $((phase_size * 2 - 1))},
    {\"number\": 3, \"name\": \"Completion\", \"start_index\": $((phase_size * 2)), \"end_index\": $((total_commits - 1))}
  ]
}"
        return
    fi

    # Use boundaries to create phases
    local phases="["
    local prev_end=-1
    local phase_num=1
    local first=true

    for boundary_idx in $top_boundaries; do
        [[ "$first" == true ]] || phases+=","
        first=false

        local name="Phase $phase_num"
        case $phase_num in
            1) name="Foundation" ;;
            2) name="Core Development" ;;
            3) name="Enhancement" ;;
            4) name="Polish" ;;
        esac

        phases+="{\"number\": $phase_num, \"name\": \"$name\", \"start_index\": $((prev_end + 1)), \"end_index\": $boundary_idx}"
        prev_end=$boundary_idx
        ((phase_num++))
    done

    # Final phase to end
    phases+=",{\"number\": $phase_num, \"name\": \"Completion\", \"start_index\": $((prev_end + 1)), \"end_index\": $((total_commits - 1))}"
    phases+="]"

    echo "{\"phases\": $phases}"
}
# }}}
```

### 6. Roadmap Document Generation

```bash
# -- {{{ generate_roadmap_document
# Creates docs/roadmap.md from phase analysis
generate_roadmap_document() {
    local phases_json="$1"
    local commit_stream="$2"
    local project_name="$3"
    local output_file="$4"

    mkdir -p "$(dirname "$output_file")"

    cat << EOF > "$output_file"
# $project_name Development Roadmap

This roadmap was auto-generated from git commit history analysis.

---

EOF

    # Generate each phase section
    echo "$phases_json" | jq -r '.phases[] | @base64' | while read -r phase_b64; do
        local phase
        phase=$(echo "$phase_b64" | base64 -d)

        local num name desc start end
        num=$(echo "$phase" | jq -r '.number')
        name=$(echo "$phase" | jq -r '.name')
        desc=$(echo "$phase" | jq -r '.description // "No description"')
        start=$(echo "$phase" | jq -r '.start_index')
        end=$(echo "$phase" | jq -r '.end_index')

        cat << EOF >> "$output_file"
## Phase $num: $name

$desc

### Commits

EOF

        # List commits in this phase
        echo "$commit_stream" | jq -r --argjson start "$start" --argjson end "$end" '
            .[$start:$end+1][] |
            "- `\(.hash[0:7])` \(.message[0:60])"
        ' >> "$output_file"

        # Add accomplishments if present
        local accomplishments
        accomplishments=$(echo "$phase" | jq -r '.accomplishments // [] | .[]')
        if [[ -n "$accomplishments" ]]; then
            echo "" >> "$output_file"
            echo "### Key Accomplishments" >> "$output_file"
            echo "" >> "$output_file"
            echo "$accomplishments" | while read -r acc; do
                echo "- $acc" >> "$output_file"
            done
        fi

        echo "" >> "$output_file"
        echo "---" >> "$output_file"
        echo "" >> "$output_file"
    done

    cat << EOF >> "$output_file"
---
*Generated: $(date -Iseconds)*
*Tool: generate-docs-from-history.sh (Issue 051)*
EOF

    log "Generated: $output_file"
}
# }}}
```

---

## Output Format

### roadmap.json

```json
{
  "phases": [
    {
      "number": 1,
      "name": "Foundation",
      "description": "Initial project setup and core infrastructure",
      "start_index": 0,
      "end_index": 15,
      "start_hash": "abc1234",
      "end_hash": "def5678",
      "accomplishments": [
        "Created project structure",
        "Added base configuration",
        "Implemented logging"
      ],
      "commit_count": 16
    },
    {
      "number": 2,
      "name": "Core Features",
      "description": "Implementation of main functionality",
      "start_index": 16,
      "end_index": 45,
      "start_hash": "ghi9012",
      "end_hash": "jkl3456",
      "accomplishments": [
        "Built parser module",
        "Added caching layer",
        "Implemented API endpoints"
      ],
      "commit_count": 30
    }
  ],
  "total_commits": 100,
  "total_phases": 4,
  "generation_method": "llm_consensus",
  "generated_at": "2026-02-12T10:30:00Z"
}
```

---

## Acceptance Criteria

- [ ] Extracts full commit stream with metadata (hash, message, date, files)
- [ ] Detects potential phase boundaries using heuristics
- [ ] Uses LLM tool-calls to analyze and assign phases
- [ ] Implements triple-check consensus for phase boundaries
- [ ] Falls back to heuristics when LLM unavailable
- [ ] Generates roadmap.json with structured phase data
- [ ] Generates docs/roadmap.md with human-readable format
- [ ] Handles large repositories (500+ commits)
- [ ] Supports configurable phase count (auto or fixed)

---

## Technical Notes

### LLM Prompt Engineering

- Keep prompts focused on JSON output only
- Include concrete examples in prompt
- Use low temperature (0.3) for consistent output
- Validate JSON response before processing

### Performance

- Limit commit analysis to 500 commits by default
- Use git log formatting for efficient extraction
- Cache commit stream in tmp/
- Parallelize LLM queries when possible

---

## Metadata

- **Priority**: High
- **Complexity**: High
- **Dependencies**: Issue 051a
- **Blocks**: 051c, 051d, 051e
