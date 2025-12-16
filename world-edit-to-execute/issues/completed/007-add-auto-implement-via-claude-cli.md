# Issue 007: Add Auto-Implement via Claude CLI

**Phase:** 0 - Tooling/Infrastructure
**Type:** Feature
**Priority:** High
**Affects:** src/cli/issue-splitter.sh
**Dependencies:** None

---

## Current Behavior

The issue-splitter can:
- Analyze issues for sub-issue splitting
- Execute recommendations to create sub-issue files
- Review existing structures

But it cannot actually *implement* the steps described in an issue file.

---

## Intended Behavior

Add a new mode that:
1. Reads an issue file
2. Extracts the implementation steps
3. Invokes `claude` CLI with a prompt to implement those steps
4. Lets Claude Code autonomously complete the task

### New Flag

```
-A, --auto-implement    Auto-implement issue steps using Claude CLI
```

### Usage Examples

```bash
# Implement a single issue
./issue-splitter.sh -A issues/102d-implement-file-extraction.md

# Interactive mode with auto-implement option
./issue-splitter.sh -I  # Select "Implement" mode

# Implement all pending issues in a phase
./issue-splitter.sh -A --pattern "1*.md"
```

---

## Suggested Implementation Steps

### 1. Add Auto-Implement Flag

```bash
# In configuration section
AUTO_IMPLEMENT=false

# In argument parsing
-A|--auto-implement)
    AUTO_IMPLEMENT=true
    ;;
```

### 2. Create Build Implementation Prompt Function

```bash
# {{{ build_implementation_prompt
build_implementation_prompt() {
    local issue_path="$1"
    local issue_content
    issue_content=$(cat "$issue_path")

    cat <<EOF
Please implement the following issue. Read the file carefully, understand
the current behavior, intended behavior, and suggested implementation steps.
Then write the code to complete each step.

After implementation:
1. Test that the changes work
2. Update the issue file with implementation notes
3. Report what was done

Issue file: $issue_path

---

$issue_content
EOF
}
# }}}
```

### 3. Create Auto-Implement Function

```bash
# {{{ auto_implement_issue
auto_implement_issue() {
    local issue_path="$1"
    local basename
    basename=$(basename "$issue_path")

    log "Auto-implementing: $basename"

    # Build the prompt
    local prompt
    prompt=$(build_implementation_prompt "$issue_path")

    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY RUN] Would invoke claude with implementation prompt"
        echo "--- Prompt Preview ---"
        echo "$prompt" | head -20
        echo "..."
        return 0
    fi

    # Invoke claude CLI
    # The -p flag sends a prompt, --dangerously-skip-permissions allows file writes
    echo "$prompt" | claude --dangerously-skip-permissions

    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log "  Implementation completed successfully"
    else
        log "  Implementation failed with exit code $exit_code"
    fi

    return $exit_code
}
# }}}
```

### 4. Add Implementation Phase

```bash
# {{{ run_implement_phase
run_implement_phase() {
    echo
    echo "════════════════════════════════════════════════════════════════"
    log "PHASE: Auto-implementing issues via Claude CLI"
    echo "════════════════════════════════════════════════════════════════"
    echo

    for issue in "${SELECTED_ISSUES[@]}"; do
        auto_implement_issue "$issue"
    done
}
# }}}
```

### 5. Update Main Logic

```bash
# In main execution flow
if [[ "$AUTO_IMPLEMENT" == true ]]; then
    run_implement_phase
fi
```

### 6. Update Help Text

```
Auto-Implementation:
  -A, --auto-implement   Invoke Claude CLI to implement issue steps
                         Reads issue file, extracts steps, runs claude
```

---

## Safety Considerations

1. **Confirmation prompt** - Ask before running claude (unless --execute-all)
2. **Dry-run support** - Show what would be sent to claude
3. **Issue selection** - Only implement explicitly selected issues
4. **Progress tracking** - Log what's being implemented

---

## Related Documents

- issues/003-execute-analysis-recommendations.md (similar pattern)
- src/cli/issue-splitter.sh
- Claude Code CLI documentation

---

## Acceptance Criteria

- [ ] `-A` / `--auto-implement` flag exists
- [ ] `build_implementation_prompt()` constructs appropriate prompt
- [ ] `auto_implement_issue()` invokes claude CLI
- [ ] Dry-run shows prompt preview
- [ ] Confirmation required unless --execute-all
- [ ] Works in interactive mode as "Implement" option
- [ ] Help text documents the feature

---

## Implementation Log

**Date:** 2024-12-16

### Changes Made

1. **Added AUTO_IMPLEMENT flag** (line 58)
   - New configuration variable for tracking mode

2. **Added -A/--auto-implement argument** (line 126-129)
   - Parses command line flag

3. **Added build_implementation_prompt()** (line 971-993)
   - Constructs prompt with issue content and instructions
   - Tells Claude to implement, test, and update issue file

4. **Added auto_implement_issue()** (line 996-1048)
   - Checks for claude CLI availability
   - Shows prompt preview in dry-run mode
   - Confirms before running (unless --execute-all)
   - Invokes `claude --dangerously-skip-permissions`

5. **Added run_implement_phase()** (line 1051-1072)
   - Iterates through selected issues
   - Calls auto_implement_issue for each

6. **Updated main execution** (line 1170-1173)
   - Runs implement phase after execute phase when -A flag set

7. **Updated TUI interactive mode** (line 389, 429-430)
   - Added "Implement" option to Mode section
   - Extracts implement mode selection

8. **Updated help text** (line 26)
   - Documents -A/--auto-implement flag

### Usage

```bash
# Dry run - preview what would be sent to Claude
./issue-splitter.sh -A -n issues/007-*.md

# Implement single issue with confirmation
./issue-splitter.sh -A issues/007-add-auto-implement-via-claude-cli.md

# Implement all issues without confirmation
./issue-splitter.sh -A -X --pattern "1*.md"

# Interactive mode - select Implement
./issue-splitter.sh -I
```

### Acceptance Criteria Resolution

- [x] `-A` / `--auto-implement` flag exists
- [x] `build_implementation_prompt()` constructs appropriate prompt
- [x] `auto_implement_issue()` invokes claude CLI
- [x] Dry-run shows prompt preview
- [x] Confirmation required unless --execute-all
- [x] Works in interactive mode as "Implement" option
- [x] Help text documents the feature
