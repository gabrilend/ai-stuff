# Issue 035g: Transcript-to-Commit Provenance Linking

## Parent Issue
- **Issue 035**: Project History Reconstruction from Issue Files

## Current Behavior

The `reconstruct-history.sh` script creates git commits from issue files with estimated dates and associated files. However, there is **no linkage between commits and the LLM conversation sessions** that produced them.

### Current Limitations
- Git commits show *what* changed but not *how the decisions were made*
- LLM transcripts exist in `{project}/llm-transcripts/` and `~/.claude/projects/`
- No mechanism to correlate transcript sessions with specific commits
- Users cannot trace a commit back to the reasoning that produced it
- The development narrative is incomplete without the collaborative context

### What Exists
| Component | Location | Status |
|-----------|----------|--------|
| Transcript storage | `{project}/llm-transcripts/` | Active |
| Session backups | `~/.claude/projects/{path-encoded}/` | Active |
| Export tools | `/scripts/backup-conversations`, `/scripts/claude-conversation-exporter.sh` | Working |
| Transcript analysis | Issue 040g (reasoning memory) | Planned |
| Git history reconstruction | Issues 035a-f | Mostly complete |

## Intended Behavior

Link each reconstructed git commit to the specific LLM transcript session(s) that contributed to that commit's changes.

### Target Output
```
$ git log --show-notes

commit abc1234
Author: User <user@example.com>
Date:   2024-12-15 14:30:00

    Issue 022: Implement embedding pipeline

    Notes (transcript-provenance):
        Sessions: agent-1b2c3d4_summary.md, 4f8a9b1c-..._summary.md
        Lines: 142-287, 12-89
        Confidence: high (timestamp overlap + content match)
```

### User Experience
1. **Reading a commit** → See which sessions contributed
2. **Debugging a decision** → Jump directly to the relevant conversation
3. **Understanding evolution** → Trace how an approach developed over multiple sessions
4. **Auditing changes** → Full provenance chain from commit to human-AI dialogue

### Workflow
```
┌─────────────────────────────────────────────────────────────────┐
│              Transcript-to-Commit Provenance Linking            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. PARSE TRANSCRIPT SESSIONS                                   │
│     ┌────────────────────────────────────────┐                  │
│     │ ~/.claude/projects/{path-encoded}/     │                  │
│     │ {project}/llm-transcripts/             │                  │
│     │                                        │                  │
│     │ Extract:                               │                  │
│     │   - Session ID (UUID or agent-ID)      │                  │
│     │   - Start/end timestamps               │                  │
│     │   - Files mentioned or modified        │                  │
│     │   - Issue references (grep for IDs)    │                  │
│     └────────────────────────────────────────┘                  │
│                                                                 │
│  2. CORRELATE SESSIONS TO ISSUES                                │
│     ┌────────────────────────────────────────┐                  │
│     │ For each completed issue:              │                  │
│     │   - Get completion timestamp           │                  │
│     │   - Find sessions overlapping window   │                  │
│     │   - Score by:                          │                  │
│     │     • Timestamp proximity              │                  │
│     │     • Issue ID mentions in session     │                  │
│     │     • File overlap                     │                  │
│     │     • Semantic similarity (optional)   │                  │
│     └────────────────────────────────────────┘                  │
│                                                                 │
│  3. ATTACH PROVENANCE TO COMMITS                                │
│     ┌────────────────────────────────────────┐                  │
│     │ Option A: Git Notes                    │                  │
│     │   git notes --ref=transcript-provenance│                  │
│     │   add -m "Sessions: ..." <commit>      │                  │
│     │                                        │                  │
│     │ Option B: Extended Commit Message      │                  │
│     │   Append provenance block to message   │                  │
│     │                                        │                  │
│     │ Option C: Sidecar JSON                 │                  │
│     │   .git/provenance/{commit-hash}.json   │                  │
│     └────────────────────────────────────────┘                  │
│                                                                 │
│  4. INTEGRATE WITH RECONSTRUCTION PIPELINE                      │
│     ┌────────────────────────────────────────┐                  │
│     │ During reconstruct_history():          │                  │
│     │   - After creating issue commit        │                  │
│     │   - Query session correlation          │                  │
│     │   - Attach provenance metadata         │                  │
│     └────────────────────────────────────────┘                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Suggested Implementation Steps

### 1. Add Configuration Variables
```bash
# -- {{{ Transcript Provenance Configuration (035g)
ENABLE_TRANSCRIPT_PROVENANCE="${ENABLE_TRANSCRIPT_PROVENANCE:-true}"
TRANSCRIPT_DIRS=(
    "${PROJECT_DIR}/llm-transcripts"
    "$HOME/.claude/projects"
)
PROVENANCE_METHOD="${PROVENANCE_METHOD:-git-notes}"  # git-notes | commit-message | sidecar
PROVENANCE_MIN_CONFIDENCE="${PROVENANCE_MIN_CONFIDENCE:-0.5}"
# }}}
```

### 2. Parse Claude Project Directory
```bash
# -- {{{ get_claude_project_path
# Claude encodes project paths by replacing / with %2F
get_claude_project_path() {
    local project_dir="$1"
    local abs_path
    abs_path=$(cd "$project_dir" && pwd)

    # Encode path for Claude's directory naming
    local encoded
    encoded=$(echo "$abs_path" | sed 's|/|%2F|g')

    local claude_dir="$HOME/.claude/projects/${encoded}"

    if [[ -d "$claude_dir" ]]; then
        echo "$claude_dir"
        return 0
    fi

    return 1
}
# }}}
```

### 3. Extract Session Metadata
```bash
# -- {{{ parse_session_metadata
parse_session_metadata() {
    local session_file="$1"

    # Extract session ID from filename
    local session_id
    session_id=$(basename "$session_file" | sed 's/_summary\.md$//' | sed 's/\.jsonl$//')

    # For JSONL files (raw Claude format)
    if [[ "$session_file" == *.jsonl ]]; then
        # First message timestamp
        local start_ts
        start_ts=$(head -1 "$session_file" | jq -r '.timestamp // empty' 2>/dev/null)

        # Last message timestamp
        local end_ts
        end_ts=$(tail -1 "$session_file" | jq -r '.timestamp // empty' 2>/dev/null)

        # Files mentioned (look for file paths in content)
        local files_mentioned
        files_mentioned=$(grep -oE '[a-zA-Z0-9_/-]+\.(lua|sh|md|py|js|ts)' "$session_file" | sort -u | tr '\n' ',' | sed 's/,$//')

        printf '{"id":"%s","start":"%s","end":"%s","files":"%s"}\n' \
            "$session_id" "$start_ts" "$end_ts" "$files_mentioned"
        return 0
    fi

    # For markdown summary files
    if [[ "$session_file" == *.md ]]; then
        # Extract "Generated on:" date
        local generated_date
        generated_date=$(grep -i "Generated on:" "$session_file" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)

        # Use file mtime as fallback
        if [[ -z "$generated_date" ]]; then
            generated_date=$(stat -c %Y "$session_file")
        else
            generated_date=$(date -d "$generated_date" +%s 2>/dev/null || stat -c %Y "$session_file")
        fi

        # Look for issue references (e.g., "Issue 022", "035a")
        local issue_refs
        issue_refs=$(grep -oE '(Issue |issue |#)[0-9]{3}[a-z]?' "$session_file" | grep -oE '[0-9]{3}[a-z]?' | sort -u | tr '\n' ',' | sed 's/,$//')

        # Files mentioned
        local files_mentioned
        files_mentioned=$(grep -oE '[a-zA-Z0-9_/-]+\.(lua|sh|md|py|js|ts)' "$session_file" | sort -u | tr '\n' ',' | sed 's/,$//')

        printf '{"id":"%s","date":%s,"issues":"%s","files":"%s"}\n' \
            "$session_id" "$generated_date" "$issue_refs" "$files_mentioned"
        return 0
    fi

    return 1
}
# }}}
```

### 4. Correlate Sessions to Issues
```bash
# -- {{{ correlate_session_to_issue
correlate_session_to_issue() {
    local issue_file="$1"
    local session_metadata="$2"  # JSON from parse_session_metadata

    local issue_id
    issue_id=$(basename "$issue_file" .md | grep -oE '^[0-9]{3}[a-z]?')

    local issue_date
    issue_date=$(estimate_issue_date "$issue_file")

    local session_date
    session_date=$(echo "$session_metadata" | jq -r '.date // .start' 2>/dev/null)

    local session_issues
    session_issues=$(echo "$session_metadata" | jq -r '.issues // ""' 2>/dev/null)

    local session_files
    session_files=$(echo "$session_metadata" | jq -r '.files // ""' 2>/dev/null)

    # Scoring algorithm
    local score=0
    local reasons=""

    # Score 1: Issue ID mentioned in session
    if echo "$session_issues" | grep -q "$issue_id"; then
        ((score += 40))
        reasons="${reasons}issue-mentioned,"
    fi

    # Score 2: Timestamp proximity (within 7 days = high, 30 days = medium)
    if [[ -n "$session_date" ]] && [[ -n "$issue_date" ]]; then
        local delta=$(( session_date - issue_date ))
        [[ $delta -lt 0 ]] && delta=$(( -delta ))

        if [[ $delta -lt 86400 ]]; then  # Same day
            ((score += 35))
            reasons="${reasons}same-day,"
        elif [[ $delta -lt 604800 ]]; then  # Within week
            ((score += 25))
            reasons="${reasons}same-week,"
        elif [[ $delta -lt 2592000 ]]; then  # Within month
            ((score += 10))
            reasons="${reasons}same-month,"
        fi
    fi

    # Score 3: File overlap
    local issue_files
    issue_files=$(grep -oE '[a-zA-Z0-9_/-]+\.(lua|sh|md|py|js|ts)' "$issue_file" 2>/dev/null | sort -u | tr '\n' ',')

    # Simple overlap check (could be improved with set intersection)
    local overlap_count=0
    for f in $(echo "$session_files" | tr ',' ' '); do
        if echo "$issue_files" | grep -q "$f"; then
            ((overlap_count++))
        fi
    done

    if [[ $overlap_count -gt 0 ]]; then
        ((score += overlap_count * 5))
        reasons="${reasons}file-overlap:${overlap_count},"
    fi

    # Normalize score to 0.0-1.0
    local normalized
    normalized=$(echo "scale=2; $score / 100" | bc 2>/dev/null || echo "0")
    [[ $(echo "$normalized > 1" | bc 2>/dev/null) == 1 ]] && normalized="1.0"

    printf '{"issue":"%s","score":%s,"reasons":"%s"}\n' \
        "$issue_id" "$normalized" "${reasons%,}"
}
# }}}

# -- {{{ find_sessions_for_issue
find_sessions_for_issue() {
    local project_dir="$1"
    local issue_file="$2"
    local min_confidence="${3:-$PROVENANCE_MIN_CONFIDENCE}"

    local -a matching_sessions=()

    # Collect all transcript sources
    local -a transcript_files=()

    # Project-local transcripts
    if [[ -d "$project_dir/llm-transcripts" ]]; then
        while IFS= read -r -d '' f; do
            transcript_files+=("$f")
        done < <(find "$project_dir/llm-transcripts" -name "*.md" -o -name "*.jsonl" -print0 2>/dev/null)
    fi

    # Claude project directory
    local claude_dir
    if claude_dir=$(get_claude_project_path "$project_dir"); then
        while IFS= read -r -d '' f; do
            transcript_files+=("$f")
        done < <(find "$claude_dir" -name "*.jsonl" -print0 2>/dev/null)
    fi

    # Score each session
    for session_file in "${transcript_files[@]}"; do
        local metadata
        metadata=$(parse_session_metadata "$session_file")
        [[ -z "$metadata" ]] && continue

        local correlation
        correlation=$(correlate_session_to_issue "$issue_file" "$metadata")

        local score
        score=$(echo "$correlation" | jq -r '.score' 2>/dev/null)

        # Check if above threshold
        if [[ $(echo "$score >= $min_confidence" | bc 2>/dev/null) == 1 ]]; then
            local session_id
            session_id=$(echo "$metadata" | jq -r '.id')
            matching_sessions+=("$session_id:$score")
        fi
    done

    # Output matching sessions sorted by score
    printf '%s\n' "${matching_sessions[@]}" | sort -t: -k2 -rn
}
# }}}
```

### 5. Attach Provenance to Commits
```bash
# -- {{{ attach_provenance_git_notes
attach_provenance_git_notes() {
    local commit_hash="$1"
    local sessions="$2"      # Comma-separated session IDs
    local confidence="$3"    # Overall confidence level
    local reasons="$4"       # Correlation reasons

    local note_content
    note_content=$(cat <<EOF
Transcript Provenance:
  Sessions: ${sessions}
  Confidence: ${confidence}
  Correlation: ${reasons}
  Generated: $(date -Iseconds)
EOF
)

    git notes --ref=transcript-provenance add -f -m "$note_content" "$commit_hash" 2>/dev/null
}
# }}}

# -- {{{ attach_provenance_commit_message
attach_provenance_commit_message() {
    local message="$1"
    local sessions="$2"
    local confidence="$3"

    # Append provenance block to commit message
    cat <<EOF
${message}

---
Transcript-Provenance:
  Sessions: ${sessions}
  Confidence: ${confidence}
EOF
}
# }}}

# -- {{{ attach_provenance_sidecar
attach_provenance_sidecar() {
    local project_dir="$1"
    local commit_hash="$2"
    local sessions="$3"
    local confidence="$4"
    local reasons="$5"

    local sidecar_dir="$project_dir/.git/provenance"
    mkdir -p "$sidecar_dir"

    local sidecar_file="$sidecar_dir/${commit_hash}.json"

    cat > "$sidecar_file" <<EOF
{
    "commit": "${commit_hash}",
    "sessions": [$(echo "$sessions" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')],
    "confidence": ${confidence},
    "reasons": "${reasons}",
    "generated": "$(date -Iseconds)"
}
EOF
}
# }}}
```

### 6. Integrate with Reconstruction Pipeline
```bash
# -- {{{ attach_transcript_provenance
# Call this after creating each issue commit
attach_transcript_provenance() {
    local project_dir="$1"
    local issue_file="$2"
    local commit_hash="$3"

    [[ "$ENABLE_TRANSCRIPT_PROVENANCE" != true ]] && return 0

    log "Finding transcript sessions for $(basename "$issue_file")..."

    local sessions_raw
    sessions_raw=$(find_sessions_for_issue "$project_dir" "$issue_file")

    if [[ -z "$sessions_raw" ]]; then
        log "  No matching sessions found"
        return 0
    fi

    # Parse sessions
    local -a session_ids=()
    local -a scores=()
    local total_score=0
    local count=0

    while IFS=: read -r session_id score; do
        [[ -z "$session_id" ]] && continue
        session_ids+=("$session_id")
        scores+=("$score")
        total_score=$(echo "$total_score + $score" | bc)
        ((count++))
    done <<< "$sessions_raw"

    # Calculate average confidence
    local avg_confidence
    avg_confidence=$(echo "scale=2; $total_score / $count" | bc 2>/dev/null || echo "0")

    local sessions_csv
    sessions_csv=$(IFS=,; echo "${session_ids[*]}")

    log "  Found $count sessions (avg confidence: $avg_confidence)"

    # Attach based on configured method
    case "$PROVENANCE_METHOD" in
        git-notes)
            attach_provenance_git_notes "$commit_hash" "$sessions_csv" "$avg_confidence" "auto-correlated"
            ;;
        commit-message)
            # This would need to amend the commit, which is complex
            # For now, just use git notes
            attach_provenance_git_notes "$commit_hash" "$sessions_csv" "$avg_confidence" "auto-correlated"
            warn "commit-message method not fully implemented, using git-notes"
            ;;
        sidecar)
            attach_provenance_sidecar "$project_dir" "$commit_hash" "$sessions_csv" "$avg_confidence" "auto-correlated"
            ;;
    esac
}
# }}}
```

### 7. Add Provenance Query Commands
```bash
# -- {{{ show_commit_provenance
show_commit_provenance() {
    local commit="${1:-HEAD}"

    echo "=== Transcript Provenance for $commit ==="
    echo ""

    # Try git notes first
    local notes
    notes=$(git notes --ref=transcript-provenance show "$commit" 2>/dev/null)

    if [[ -n "$notes" ]]; then
        echo "$notes"
        return 0
    fi

    # Try sidecar file
    local commit_hash
    commit_hash=$(git rev-parse "$commit" 2>/dev/null)
    local sidecar_file=".git/provenance/${commit_hash}.json"

    if [[ -f "$sidecar_file" ]]; then
        jq '.' "$sidecar_file"
        return 0
    fi

    echo "No provenance data found for this commit."
    return 1
}
# }}}

# -- {{{ list_provenance_commits
list_provenance_commits() {
    echo "=== Commits with Transcript Provenance ==="
    echo ""

    # List commits that have provenance notes
    git notes --ref=transcript-provenance list 2>/dev/null | while read -r note_hash commit_hash; do
        local subject
        subject=$(git log -1 --format='%s' "$commit_hash" 2>/dev/null)
        local date
        date=$(git log -1 --format='%ai' "$commit_hash" 2>/dev/null)

        echo "[${commit_hash:0:7}] $date - $subject"
    done
}
# }}}
```

### 8. Add CLI Flags
```bash
--enable-provenance       Enable transcript-to-commit linking (default: true)
--disable-provenance      Disable transcript provenance
--provenance-method       Method: git-notes | commit-message | sidecar (default: git-notes)
--provenance-min-score    Minimum correlation score 0.0-1.0 (default: 0.5)
--show-provenance <ref>   Show provenance for a commit
--list-provenance         List all commits with provenance data
```

### 9. Add Help Text
```
Transcript Provenance Linking:
  Each reconstructed commit can be linked to the LLM conversation sessions
  that contributed to its creation. This enables full traceability from
  code changes back to the human-AI dialogue that produced them.

  Correlation is based on:
    - Issue ID mentions in transcript content
    - Timestamp proximity (session date vs issue completion)
    - File overlap (files mentioned in both)

  Provenance is stored using one of three methods:
    - git-notes: Uses git notes (separate ref, queryable)
    - commit-message: Appends to commit message (visible in log)
    - sidecar: JSON files in .git/provenance/ (full metadata)

  Use --show-provenance <commit> to view provenance for a specific commit.
  Use --list-provenance to see all commits with provenance data.
```

## Files to Modify

- `delta-version/scripts/reconstruct-history.sh`:
  - Add transcript provenance configuration variables
  - Add `get_claude_project_path()`
  - Add `parse_session_metadata()`
  - Add `correlate_session_to_issue()`
  - Add `find_sessions_for_issue()`
  - Add `attach_provenance_git_notes()`
  - Add `attach_provenance_sidecar()`
  - Add `attach_transcript_provenance()`
  - Add `show_commit_provenance()`
  - Add `list_provenance_commits()`
  - Update `create_issue_commit()` to call `attach_transcript_provenance()`
  - Update `parse_args()` with new flags
  - Update `show_help()` with provenance documentation

## Edge Cases

### No Transcripts Available
```
Project imported before transcript tooling was in place.
```
Strategy: Log warning, continue without provenance. Mark with confidence=0.

### Multiple Sessions Per Issue
```
Issue worked on across 3+ sessions over several days.
```
Strategy: Include all matching sessions, show individual scores, report average confidence.

### Session Covers Multiple Issues
```
Single session worked on issues 022, 023, and 024.
```
Strategy: Link session to all relevant issues. Let correlation scoring handle relevance.

### Corrupted/Incomplete Transcripts
```
JSONL file truncated or malformed.
```
Strategy: Skip file with warning, continue with other sources.

### Path Encoding Variations
```
Claude may use different encoding schemes across versions.
```
Strategy: Try multiple encodings (URL-encoded, base64, etc.) when looking up project dir.

## Testing Strategy

### Test 1: Session Discovery
```bash
# Verify session files are found
./reconstruct-history.sh --dry-run --enable-provenance /path/to/project
# Should show: "Found N transcript sessions"
```

### Test 2: Correlation Scoring
```bash
# Create test scenario with known issue-session relationship
# Verify high score when issue ID is mentioned in session
```

### Test 3: Git Notes Attachment
```bash
./reconstruct-history.sh --enable-provenance /path/to/project
git notes --ref=transcript-provenance show HEAD
# Should display session IDs and confidence
```

### Test 4: Provenance Query
```bash
./reconstruct-history.sh --show-provenance HEAD
./reconstruct-history.sh --list-provenance
```

## Dependencies
- **Issue 035a**: Project detection (for finding project paths) ✅
- **Issue 035c**: Date estimation (for timestamp comparison) ✅
- **Issue 035e**: History rewriting (integration point) ✅
- **Scripts**: `backup-conversations`, `claude-conversation-exporter.sh`

## Blocks
- **Issue 040g**: Could consume provenance data for reasoning memory

## Related Documents
- **Issue 035**: Parent issue for project history reconstruction
- **Issue 040g**: Transcript Analysis and Reasoning Memory
- **Issue 009** (scripts): Batch Transcript Backup with TUI
- `/scripts/backup-conversations`: Transcript extraction tool
- `/scripts/claude-conversation-exporter.sh`: Export formatting tool

## Metadata
- **Priority**: Medium (valuable but not blocking other work)
- **Complexity**: Medium
- **Dependencies**: 035a, 035c, 035e
- **Blocks**: 040g (enhanced reasoning memory)
- **Status**: Pending

## Success Criteria

- [ ] `get_claude_project_path()` correctly resolves Claude's encoded paths
- [ ] `parse_session_metadata()` extracts timestamps and content from JSONL and MD
- [ ] `correlate_session_to_issue()` produces sensible correlation scores
- [ ] `find_sessions_for_issue()` returns sessions sorted by relevance
- [ ] `attach_provenance_git_notes()` creates queryable git notes
- [ ] `attach_provenance_sidecar()` creates valid JSON files
- [ ] Integration with reconstruction pipeline works without errors
- [ ] `--show-provenance` displays provenance for any commit
- [ ] `--list-provenance` shows all commits with provenance data
- [ ] Dry-run shows provenance preview
- [ ] No transcripts gracefully handled (warning, continue)
- [ ] Multiple sessions per issue correctly aggregated
- [ ] Help text documents provenance functionality
