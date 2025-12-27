# Issue 012: Remove Context Continuation

**Phase:** 0 - Tooling/Infrastructure
**Type:** Bug Fix / Design Correction
**Priority:** Critical
**Dependencies:** None
**Supersedes:** 001-resume-previous-analysis-context

---

## Current Behavior

The `issue-splitter.sh` script uses Claude CLI's `--continue` flag to preserve context across multiple Claude invocations within a single run. This was intended to:

1. Allow Claude to remember analysis context when generating complete issue files
2. Accumulate understanding across sibling sub-issue generation
3. Enable refinement prompts that build on previous analysis

### The Problem

**Claude CLI's `--continue` flag shares context across ALL active Claude sessions system-wide, not per-project or per-invocation-chain.**

This means:
- User's other Claude Code sessions contaminate the automated issue-splitter sessions
- Implementation context from unrelated work bleeds into issue file generation
- Claude may attempt to implement code when it should only be creating documentation
- Cross-project contamination can occur between completely separate workstreams

### Observed Symptoms

When `--continue` is used during "Generate Complete Issues":
- Claude outputs messages like "It seems my Bash command needs approval"
- Claude summarizes implementation progress from OTHER sessions
- Claude attempts to write source code instead of markdown issue files
- Generated issue files contain code implementations instead of specifications

---

## Intended Behavior

**Remove all uses of `--continue` flag from issue-splitter.sh.**

Each Claude invocation should start with a fresh context, isolated from:
- Other issue-splitter invocations
- User's interactive Claude Code sessions
- Other projects entirely

### Tradeoff Acknowledged

This means:
- Higher token costs (Claude must re-read project context each time)
- No accumulated understanding across sub-issue generation
- No conversational refinement of previous analyses

**These costs are acceptable.** Correctness and isolation are more important than context efficiency. A tool that produces wrong output efficiently is worse than one that produces correct output slowly.

---

## Suggested Implementation Steps

### Step 1: Remove `--continue` from `generate_complete_issues()`

```bash
# Before:
if claude --continue --allowedTools Write -p "$prompt"; then

# After:
if claude --allowedTools Write -p "$prompt"; then
```

### Step 2: Remove session mode dependency logic

The "Generate Complete Issues" option previously auto-enabled Session Mode because it depended on `--continue`. This dependency should be removed since session mode no longer provides benefit for generation.

- Remove `menu_add_prerequisite "generate_complete" "session"` if present
- Update TUI description to not mention session mode

### Step 3: Update any analysis functions using `--continue`

Search for all uses of `--continue` in the script:

```bash
grep -n "\-\-continue" issue-splitter.sh
```

For each occurrence:
- Remove the flag
- Consider whether the prompt needs to be self-contained (include all necessary context)

### Step 4: Update prompts to be self-contained

Since Claude won't have prior context, prompts must include all information needed:

```bash
# build_generation_prompt() should include:
# - Summary of the parent issue
# - List of ALL sub-issues being generated (not just current one)
# - Any relevant project context that was previously accumulated

cat <<EOF
## Parent Issue Summary
$(cat "$parent_path")

## Sub-Issues to Generate
EOF
```

### Step 5: Remove Session Mode option entirely (optional)

Consider whether Session Mode (`-S` / `--session`) still serves any purpose. If all uses of `--continue` are removed, session mode becomes meaningless for this script.

Options:
a. Remove the option entirely
b. Rename to something else if it controls other behavior
c. Keep as no-op for backward compatibility, with deprecation warning

### Step 6: Update documentation

- Update any --help text that mentions session mode benefits
- Update TUI item descriptions

### Step 7: Test isolation

Verify that issue generation is now isolated:
1. Start an interactive Claude Code session and work on unrelated code
2. Run issue-splitter with Generate Complete Issues
3. Verify Claude doesn't reference the other session's work
4. Verify generated files contain only documentation, no code

---

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh` - Main script
- 001-resume-previous-analysis-context.md - **CANCELLED** (superseded by this issue)
- 002-generate-complete-issue-files.md - Parent issue for generation feature
- 002b-script-integration.md - Documents current --continue usage

---

## Acceptance Criteria

- [ ] No uses of `--continue` flag in issue-splitter.sh
- [ ] Each Claude invocation starts with fresh context
- [ ] Prompts are self-contained (include all necessary information)
- [ ] Generate Complete Issues works correctly in isolation
- [ ] Session Mode option removed or marked deprecated
- [ ] No cross-contamination between script runs and user sessions
- [ ] Updated help text and TUI descriptions

---

## Notes

### Root Cause

The assumption was that `--continue` would continue a *specific* session started by issue-splitter. In reality, `--continue` continues the user's *most recent* Claude session globally, which could be:
- An interactive coding session in another project
- A completely unrelated conversation
- Work that includes file modifications and implementation tasks

This is a design limitation of Claude CLI's session management, not a bug in issue-splitter. However, issue-splitter must work around it.

### Future Consideration

If Claude CLI adds support for named/isolated sessions, this issue could be revisited. The ideal behavior would be:

```bash
# Hypothetical future syntax
claude --session "issue-splitter-$(date +%s)" ...
```

Until then, stateless invocations are the only safe approach.

### Cost Mitigation

To reduce token costs from re-reading context:
1. Use smaller, focused prompts where possible
2. Include only the essential parent issue content, not full files
3. Consider batching: generate all sub-issues in a single Claude call rather than one per issue

### Lesson Learned

**Document in project conventions:** When using external tools that support "session" or "continue" features, always verify the scope of session sharing. System-wide session sharing is dangerous for automation.

---

## Historical Context

This issue was created after observing Claude implementing code during what should have been documentation-only generation. The `--continue` flag was causing Claude to pick up context from the user's active Claude Code sessions, leading to:

1. Implementation bleed - Claude continued implementation work from other sessions
2. Tool confusion - Claude tried to use Bash instead of Write
3. Cross-project contamination - Context from unrelated projects appeared

The immediate workaround of adding a "SCOPE RESTRICTION" prompt was insufficient - the underlying context contamination made the model behavior unpredictable.

---

## Impact on Other Issues

### Issue 001: Resume Previous Analysis Context - **CANCELLED**

Issue 001 proposed persisting session IDs per-issue to enable multi-turn refinement. This is now impossible without isolated session support from Claude CLI. The issue should be marked as cancelled with this issue as the reason.

### Issue 002/002b: Generate Complete Issue Files

The implementation documented in 002b uses `--continue`. This implementation must be updated per this issue. The acceptance criteria item "Session awareness: Uses --continue flag when session mode is active" should be removed.
