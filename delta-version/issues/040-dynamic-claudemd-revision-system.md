# Issue 040: Dynamic CLAUDE.md Revision System

## Status
- **Phase**: 4 (Meta-Infrastructure)
- **Priority**: High
- **Type**: Feature - Living Documentation System
- **Dependencies**: Issue 023 (Project Listing Utility)
- **Blocks**: Future multi-agent coordination systems

## Current Behavior
The CLAUDE.md file (`~/.claude/CLAUDE.md`) is a static document that must be manually edited by the user. When patterns emerge during development sessions - recurring corrections, discovered conventions, or evolved preferences - these insights are either:
1. Lost when the session ends
2. Manually transcribed by the user after the fact
3. Captured in conversation but never formalized

There is no mechanism for the system to learn from repeated events and propose amendments to its own instruction set.

## Intended Behavior
Create a dynamic revision system that:

1. **Observes Natural Events**: Tracks patterns in development sessions (corrections, repeated instructions, discovered conventions)

2. **Proposes Amendments**: Suggests new guidelines or modifications based on observed patterns

3. **Provides API Access**: Allows projects/scripts to programmatically register conventions or request guideline additions

4. **Maintains Audit Trail**: Every revision is logged with reasoning, source event, and timestamp

5. **Requires Consent**: All changes require explicit user approval before being applied

## Architecture Overview

```
                    ┌─────────────────────┐
                    │   CLAUDE.md File    │
                    │  (Living Document)  │
                    └──────────▲──────────┘
                               │
                    ┌──────────┴──────────┐
                    │   Revision Engine   │
                    │ (Apply/Rollback)    │
                    └──────────▲──────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
┌─────────┴─────────┐ ┌────────┴────────┐ ┌────────┴────────┐
│  Event Collector  │ │   API Server    │ │  User Interface │
│ (Pattern Detect)  │ │ (Script Access) │ │ (Review/Approve)│
└─────────┬─────────┘ └────────┬────────┘ └────────┬────────┘
          │                    │                    │
          ▼                    ▼                    ▼
    Natural Events        Script Calls        Manual Edits
```

## Access Control Model

The system enforces strict separation between observation and mutation:

```
┌─────────────────────────────────────────────────────────────────┐
│                     READ-ONLY SOURCES                           │
│  (System observes but NEVER modifies)                          │
├─────────────────────────────────────────────────────────────────┤
│  • {project}/llm-transcripts/     Session logs per project     │
│  • ~/.claude/transcripts/         Global session logs          │
│  • {project}/issues/              Issue context                │
│  • {project}/notes/               Project notes                │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼ READ
                    ┌─────────────────────┐
                    │  Analysis Engine    │
                    │  "Tough Questions"  │
                    │       Oracle        │
                    └─────────────────────┘
                               │
                               ▼ WRITE (append-only)
┌─────────────────────────────────────────────────────────────────┐
│                    WRITE-ONLY DESTINATIONS                      │
│  (System appends analysis, NEVER reads own analysis)           │
├─────────────────────────────────────────────────────────────────┤
│  • ~/.claude/analysis/decisions/       Decision records        │
│  • ~/.claude/analysis/reasoning_chains/ Multi-session traces   │
│  • ~/.claude/analysis/index.json       Cross-reference index   │
└─────────────────────────────────────────────────────────────────┘
```

**Why this separation matters**: Given enough thought (transcript analysis), the system can reconstruct the reasoning behind any decision. The read-only constraint ensures it can't alter history; the write-only constraint ensures analysis is additive and auditable.

## Key Design Principles

1. **Immutable History**: Like issue tickets, revisions can be added but never deleted from the log
2. **Source Attribution**: Every guideline traces back to the event/script/user that proposed it
3. **Semantic Sections**: Guidelines are organized by concern (coding style, workflow, philosophy, etc.)
4. **Conflict Resolution**: When new guidelines contradict existing ones, the system surfaces the conflict for human decision
5. **Graduated Confidence**: New guidelines may start as "experimental" before being promoted to "established"

## Sub-Issues

- **040a**: Design Event Taxonomy and Pattern Detection
- **040b**: Build API Layer for Project/Script Integration
- **040c**: Implement Revision Engine with Rollback Support
- **040d**: Create History and Audit Trail System
- **040e**: Build Validation and Conflict Detection System
- **040f**: Create Interactive Review Interface
- **040g**: Transcript Analysis and Reasoning Memory (the "tough questions" oracle)
- **040h**: Worldbuilding and Game Design Oracle (creative project reasoning)
- **040i**: Continual Co-operation Bridge (cross-project data sharing via key blocks)

## Suggested Implementation Steps

### Phase 1: Foundation (040a, 040d)
1. Define what constitutes a "natural event" (correction, repetition, discovery, etc.)
2. Design the history storage format
3. Implement event logging infrastructure

### Phase 2: Core Engine (040c, 040e)
4. Build the revision engine that can parse and modify CLAUDE.md
5. Implement section-aware insertion (not just appending)
6. Add conflict detection for contradictory guidelines
7. Create rollback capability

### Phase 3: Integration (040b)
8. Design the API contract for script access
9. Implement the socket/file-based API server
10. Create client library for Lua/Bash integration

### Phase 4: User Experience (040f)
11. Build TUI for reviewing pending proposals
12. Add approval/rejection workflow
13. Implement batch operations for multiple proposals

## Event Types to Track

| Event Type | Description | Example Trigger |
|------------|-------------|-----------------|
| `correction` | User corrects AI behavior | "No, always use tabs not spaces" |
| `repetition` | Same instruction given 3+ times | "Remember to add vimfolds" (3rd time) |
| `discovery` | New pattern found in codebase | "I see you use dispatch tables here" |
| `preference` | Explicit preference statement | "I prefer error messages over fallbacks" |
| `script_call` | Programmatic registration | API call from project script |
| `conflict` | Contradictory instruction | "Use 2 spaces" vs existing "use tabs" |

## API Contract (Draft)

```lua
-- Register a new guideline proposal
claudemd.propose({
    content = "all database queries should use prepared statements",
    source = "security-audit-script",
    category = "security",
    confidence = "suggested",  -- suggested | experimental | established
    reasoning = "Found 3 SQL injection vulnerabilities in codebase scan"
})

-- Query existing guidelines
local guidelines = claudemd.query({
    category = "coding-style",
    contains = "vimfold"
})

-- Check for conflicts before proposing
local conflicts = claudemd.check_conflicts({
    content = "use 4 spaces for indentation"
})
```

## Storage Locations

- **Active Guidelines**: `~/.claude/CLAUDE.md`
- **Pending Proposals**: `~/.claude/proposals/pending/`
- **Revision History**: `~/.claude/history/revisions.log`
- **Event Log**: `~/.claude/history/events.log`
- **API Socket**: `~/.claude/claudemd.sock` or `/tmp/claudemd-{uid}.sock`

## Success Metrics

1. Guidelines can be proposed from both natural events and API calls
2. All revisions maintain full audit trail
3. User can review, approve, reject, or modify proposals
4. Rollback works for any revision within history
5. No guideline is ever lost - only deprecated or superseded

## Related Documents
- [CLAUDE.md](~/.claude/CLAUDE.md) - The target living document
- [Issue 035 - History Reconstruction](./035-project-history-reconstruction.md) - Similar immutable history philosophy
- [Issue 030 - Issue Management](./completed/030-issue-management-utility.md) - Workflow patterns

## Notes
- This system embodies the principle: "the system learns from doing, not just from being told"
- Consider integration with Claude's native memory features if available
- The "graduated confidence" concept prevents unstable churn in guidelines
