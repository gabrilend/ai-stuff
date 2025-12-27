# Issue 001: Resume Previous Analysis Context

**Phase:** 0 - Tooling/Infrastructure
**Type:** Enhancement
**Priority:** ~~Medium~~ N/A
**Dependencies:** None
**Status:** CANCELLED
**Superseded By:** 012-remove-context-continuation.md

---

## Cancellation Notice

*Added 2025-12-27*

**This issue has been cancelled.** The underlying assumption that Claude CLI sessions could be isolated per-issue was incorrect.

### Discovery

Claude CLI's `--continue` flag shares context across ALL active Claude sessions system-wide, not per-project or per-script-invocation. This means:

- User's interactive Claude Code sessions contaminate automated issue-splitter sessions
- Implementation context from unrelated work bleeds into issue file generation
- Cross-project contamination occurs between completely separate workstreams

### Impact

The proposed "session ID per issue" approach cannot work because:
1. There is no mechanism to create isolated/named sessions
2. `--continue` always continues the user's most recent global session
3. Session state is shared across all Claude CLI invocations system-wide

### Resolution

Issue 012 ("Remove Context Continuation") documents the correct approach: **remove all uses of `--continue`** and accept the higher token costs of stateless invocations.

If Claude CLI adds isolated/named session support in the future, this issue could be revisited.

---

## Original Issue Content (Preserved for Reference)

---

## Current Behavior

When "skip analyzed" is de-selected (meaning: re-analyze issues that already have analysis), the script starts a fresh Claude context and sends the full issue file (which includes previous analyses appended to it). Claude sees the prior analysis as text content, but has no conversational memory of producing it.

Session mode (`-S`) shares context across *different* issues within a single script run, but does not resume context from *previous runs* of the script on the same issue.

---

## Intended Behavior

When "skip analyzed" is de-selected, the script should attempt to resume the Claude context from the last time that specific issue was analyzed. The prompt should be conversational:

> "Remember your analysis from last time alongside the ticket? Do you think we should break it up into further issue files, or can you add any details that might be useful when executing the recommendations (to split or not to split)?"

This creates a multi-turn refinement loop for individual issues, rather than starting fresh each time.

---

## Suggested Implementation Steps

1. **Investigate Claude CLI session persistence** - Determine how `claude --continue` works and whether session IDs can be stored/resumed across script invocations. Check if there's a session file or ID that can be saved per-issue.

2. **Store session metadata** - When analyzing an issue, save a session identifier (if available) to a metadata file, e.g., `issues/analysis/.session-103.json` containing `{"issue": "103-foo.md", "session_id": "...", "last_analyzed": "2025-12-25T10:30:00"}`.

3. **Modify `call_claude()` or `process_issue()`** - When re-analyzing (skip analyzed is de-selected), check for existing session metadata. If found, attempt to resume that session with `--continue` or equivalent mechanism.

4. **Build refinement prompt** - Instead of `build_prompt()`, use a new `build_refinement_prompt()` that asks Claude to reflect on and refine its previous analysis rather than starting from scratch.

5. **Fallback behavior** - If session resumption fails (session expired, not found, etc.), fall back to current behavior with a log message indicating fresh context was used.

6. **Update TUI description** - Clarify the session mode description to explain the tradeoff: cross-issue awareness vs per-issue multi-turn depth.

---

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh` (main script)
- Claude CLI documentation (session/continue behavior)

---

## Acceptance Criteria

- [ ] Re-analyzing an issue resumes conversational context from the previous analysis
- [ ] Refinement prompt asks Claude to build on prior analysis, not restart
- [ ] Session metadata is persisted per-issue between script runs
- [ ] Graceful fallback when session cannot be resumed
- [ ] TUI description updated for session mode clarity

---

## Notes

*The cumulative nature of analysis (each run sees prior analyses in the issue file) already provides some continuity. This enhancement adds conversational memory on top of textual history, enabling Claude to refine its thinking rather than re-derive conclusions from scratch.*

*Key question to investigate: Does Claude CLI support named/persistent sessions that survive across invocations? If not, alternative approaches may be needed (e.g., conversation export/import).*
