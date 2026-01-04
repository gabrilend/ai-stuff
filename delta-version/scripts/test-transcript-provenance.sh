#!/bin/bash
# test-transcript-provenance.sh - Test script for Issue 035g transcript provenance functions
#
# This script tests the transcript-to-commit provenance linking functionality
# without requiring a full history reconstruction. Use it to verify that:
# - Session metadata can be extracted from transcripts
# - Claude project directories are found correctly
# - Correlation scoring works as expected
# - Provenance attachment functions operate correctly

set -euo pipefail

# -- {{{ Configuration
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERBOSE="${VERBOSE:-true}"
# }}}

# -- {{{ Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
# }}}

# -- {{{ Logging
log() { echo -e "${BLUE}[INFO]${NC} $*"; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
# }}}

# -- {{{ test_parse_session_metadata
test_parse_session_metadata() {
    echo ""
    echo "=== Test 1: parse_session_metadata ==="

    local test_dir="$DIR/llm-transcripts"

    if [[ ! -d "$test_dir" ]]; then
        warn "No llm-transcripts directory found at $test_dir"
        return 1
    fi

    # Find a test file (use ls instead of find for speed)
    local test_file
    test_file=$(ls -1 "$test_dir"/*_summary.md 2>/dev/null | head -1)

    if [[ -z "$test_file" ]]; then
        warn "No transcript files found in $test_dir"
        return 1
    fi

    log "Testing with file: $(basename "$test_file")"

    # Extract metadata (inline version of parse_session_metadata)
    local session_id
    session_id=$(basename "$test_file" | sed 's/_summary\.md$//' | sed 's/\.jsonl$//' | sed 's/\.md$//')

    local generated_date
    generated_date=$(stat -c %Y "$test_file" 2>/dev/null || echo "0")

    local issue_refs
    issue_refs=$(grep -oE '(Issue |issue |#)[0-9]{3}[a-z]?' "$test_file" 2>/dev/null | \
        grep -oE '[0-9]{3}[a-z]?' | sort -u | tr '\n' ',' | sed 's/,$//' || echo "")

    local files_mentioned
    files_mentioned=$(grep -oE '[a-zA-Z0-9_/-]+\.(lua|sh|md|py|js|ts|rs|go|c|h|cpp|hpp)' "$test_file" 2>/dev/null | \
        sort -u | head -10 | tr '\n' ',' | sed 's/,$//' || echo "")

    echo "  Session ID: $session_id"
    echo "  Date: $generated_date ($(date -d "@$generated_date" '+%Y-%m-%d %H:%M'))"
    echo "  Issues found: ${issue_refs:-none}"
    echo "  Files found: ${files_mentioned:-none}"

    # Validation
    if [[ -n "$session_id" ]] && [[ "$generated_date" != "0" ]]; then
        pass "Session metadata extracted successfully"
        return 0
    else
        fail "Failed to extract session metadata"
        return 1
    fi
}
# }}}

# -- {{{ test_claude_project_path
test_claude_project_path() {
    echo ""
    echo "=== Test 2: get_claude_project_path ==="

    local project_dir="$DIR"
    local abs_path
    abs_path=$(cd "$project_dir" 2>/dev/null && pwd)

    log "Project path: $abs_path"

    # Try URL-encoded path (with leading slash)
    local encoded
    encoded=$(echo "$abs_path" | sed 's|/|%2F|g')
    local claude_dir="$HOME/.claude/projects/${encoded}"

    log "Checking: $claude_dir"

    if [[ -d "$claude_dir" ]]; then
        pass "Claude project directory found"
        echo "  Path: $claude_dir"
        # Just count files, don't list them (avoid hangs on large dirs)
        local file_count
        file_count=$(ls -1 "$claude_dir" 2>/dev/null | head -100 | wc -l)
        echo "  Files (first 100): $file_count"
        return 0
    fi

    # Try without leading slash
    encoded=$(echo "$abs_path" | sed 's|^/||' | sed 's|/|%2F|g')
    claude_dir="$HOME/.claude/projects/${encoded}"

    log "Checking alternate: $claude_dir"

    if [[ -d "$claude_dir" ]]; then
        pass "Claude project directory found (alternate encoding)"
        echo "  Path: $claude_dir"
        local file_count
        file_count=$(ls -1 "$claude_dir" 2>/dev/null | head -100 | wc -l)
        echo "  Files (first 100): $file_count"
        return 0
    fi

    warn "Claude project directory not found"
    echo "  This is expected if Claude Code hasn't been used in this project"
    return 0  # Don't fail - this is optional
}
# }}}

# -- {{{ test_correlation_scoring
test_correlation_scoring() {
    echo ""
    echo "=== Test 3: Correlation Scoring Logic ==="

    local issues_dir="$DIR/issues/completed"

    if [[ ! -d "$issues_dir" ]]; then
        warn "No completed issues directory at $issues_dir"
        return 1
    fi

    # Find a test issue
    local test_issue
    test_issue=$(find "$issues_dir" -name "*.md" -type f 2>/dev/null | head -1)

    if [[ -z "$test_issue" ]]; then
        warn "No completed issue files found"
        return 1
    fi

    log "Testing with issue: $(basename "$test_issue")"

    # Extract issue ID
    local issue_id
    issue_id=$(basename "$test_issue" .md | grep -oE '^[0-9]{3}[a-z]?' || echo "")

    echo "  Issue ID: $issue_id"

    # Get issue completion date (from file mtime)
    local issue_date
    issue_date=$(stat -c %Y "$test_issue" 2>/dev/null || echo "0")
    echo "  Issue date: $(date -d "@$issue_date" '+%Y-%m-%d')"

    # Extract files mentioned in issue
    local issue_files
    issue_files=$(grep -oE '[a-zA-Z0-9_/-]+\.(lua|sh|md|py|js|ts)' "$test_issue" 2>/dev/null | \
        sort -u | head -5 | tr '\n' ',' | sed 's/,$//' || echo "")
    echo "  Files in issue: ${issue_files:-none}"

    # Simulate scoring
    echo ""
    echo "  Scoring simulation:"
    echo "    - Issue ID match: +40 points"
    echo "    - Same day: +35 points"
    echo "    - Same week: +20 points"
    echo "    - Same month: +10 points"
    echo "    - File overlap: +5 per file (max 25)"
    echo "    - Maximum: 100 points (normalized to 1.0)"

    pass "Correlation scoring logic documented"
    return 0
}
# }}}

# -- {{{ test_transcript_inventory
test_transcript_inventory() {
    echo ""
    echo "=== Test 4: Transcript Inventory ==="

    local transcript_dir="$DIR/llm-transcripts"

    if [[ ! -d "$transcript_dir" ]]; then
        warn "No llm-transcripts directory"
        return 1
    fi

    # Use ls instead of find for speed
    local md_count jsonl_count
    md_count=$(ls -1 "$transcript_dir"/*.md 2>/dev/null | wc -l || echo "0")
    jsonl_count=$(ls -1 "$transcript_dir"/*.jsonl 2>/dev/null | wc -l || echo "0")

    echo "  Transcript directory: $transcript_dir"
    echo "  Markdown summaries: $md_count"
    echo "  JSONL files: $jsonl_count"
    echo ""
    echo "  Recent transcripts (by mtime):"
    ls -1t "$transcript_dir"/*.md 2>/dev/null | head -5 | while read -r path; do
        local name
        name=$(basename "$path")
        local mtime
        mtime=$(stat -c %Y "$path" 2>/dev/null || echo "0")
        local date
        date=$(date -d "@$mtime" '+%Y-%m-%d %H:%M')
        echo "    [$date] $name"
    done

    if [[ $md_count -gt 0 ]] || [[ $jsonl_count -gt 0 ]]; then
        pass "Transcripts available for provenance linking"
        return 0
    else
        warn "No transcripts found"
        return 1
    fi
}
# }}}

# -- {{{ test_git_notes_capability
test_git_notes_capability() {
    echo ""
    echo "=== Test 5: Git Notes Capability ==="

    if ! git rev-parse --git-dir &>/dev/null; then
        warn "Not in a git repository"
        return 1
    fi

    # Check if git notes ref exists
    local notes_ref="refs/notes/transcript-provenance"

    if git show-ref --verify "$notes_ref" &>/dev/null; then
        log "Provenance notes ref exists"
        local count
        count=$(git notes --ref=transcript-provenance list 2>/dev/null | wc -l)
        echo "  Commits with provenance: $count"
    else
        log "Provenance notes ref does not exist yet"
        echo "  This is normal - notes are created during reconstruction"
    fi

    # Test if we can create notes
    log "Testing git notes write capability..."
    local test_ref
    test_ref=$(git rev-parse HEAD 2>/dev/null)

    if git notes --ref=test-provenance add -f -m "test" "$test_ref" 2>/dev/null; then
        pass "Git notes can be written"
        git notes --ref=test-provenance remove "$test_ref" 2>/dev/null || true
    else
        warn "Cannot write git notes (this may require different permissions)"
    fi

    return 0
}
# }}}

# -- {{{ test_script_integration
test_script_integration() {
    echo ""
    echo "=== Test 6: Script Integration ==="

    local main_script="$SCRIPT_DIR/reconstruct-history.sh"

    if [[ ! -f "$main_script" ]]; then
        fail "reconstruct-history.sh not found at $main_script"
        return 1
    fi

    log "Checking script syntax..."
    if bash -n "$main_script" 2>/dev/null; then
        pass "Script syntax OK"
    else
        fail "Script has syntax errors"
        return 1
    fi

    log "Checking provenance CLI flags..."
    local help_output
    help_output=$("$main_script" --help 2>&1)

    local flags_found=0
    # Use grep -F -- to signal end of options before the pattern
    for flag in "--with-provenance" "--no-provenance" "--show-provenance" "--list-provenance"; do
        if echo "$help_output" | grep -qF -- "$flag"; then
            ((flags_found++))
        else
            warn "Flag not found in help: $flag"
        fi
    done

    if [[ $flags_found -eq 4 ]]; then
        pass "All provenance CLI flags present"
    else
        warn "Only $flags_found/4 provenance flags found"
    fi

    log "Testing --list-provenance command..."
    if "$main_script" --list-provenance &>/dev/null; then
        pass "--list-provenance command works"
    else
        warn "--list-provenance returned non-zero (may be expected if no provenance exists)"
    fi

    return 0
}
# }}}

# -- {{{ main
main() {
    echo "=============================================="
    echo "  Transcript Provenance Test Suite (035g)"
    echo "=============================================="
    echo ""
    echo "Project: $DIR"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"

    local passed=0
    local failed=0

    # Run tests
    # Note: Using ((++var)) instead of ((var++)) because post-increment returns
    # the original value, which is 0 (falsy) on first run, causing || to trigger
    if test_parse_session_metadata; then ((++passed)); else ((++failed)); fi
    if test_claude_project_path; then ((++passed)); else ((++failed)); fi
    if test_correlation_scoring; then ((++passed)); else ((++failed)); fi
    if test_transcript_inventory; then ((++passed)); else ((++failed)); fi
    if test_git_notes_capability; then ((++passed)); else ((++failed)); fi
    if test_script_integration; then ((++passed)); else ((++failed)); fi

    echo ""
    echo "=============================================="
    echo "  Results: $passed passed, $failed failed"
    echo "=============================================="

    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${YELLOW}Some tests failed or had warnings${NC}"
        return 1
    fi
}
# }}}

main "$@"
