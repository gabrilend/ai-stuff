# Per-Issue Transcript Generation Design

## Document Purpose

This document describes the design considerations for generating and organizing LLM conversation transcripts on a per-completed-issue basis, with multiple levels of detail cached for user browsing. It addresses the complexities of multi-issue, multi-worker development environments.

**Status**: Design Document (awaiting implementation)
**Related Issues**: 035g (transcript provenance), 040g (transcript analysis memory)
**Created**: 2026-01-04

---

## 1. Overview

### Current State

The existing transcript infrastructure provides:
- **Raw storage**: `~/.claude/projects/{path-encoded}/` (JSONL format)
- **Exported summaries**: `{project}/llm-transcripts/` (Markdown format)
- **Provenance linking**: Correlates sessions to commits via scoring algorithm
- **Export tools**: `backup-conversations`, `claude-conversation-exporter.sh`

### Proposed Enhancement

Create a per-issue transcript organization system where:
1. Each completed issue has its own transcript directory
2. Multiple detail levels are pre-generated and cached
3. Users can browse transcripts at their preferred verbosity
4. The development narrative for each issue is isolated and self-contained

### Target Directory Structure

```
issues/completed/035g-transcript-to-commit-provenance/
├── 035g-transcript-to-commit-provenance.md    # The issue file itself
└── transcripts/
    ├── level-0-minimal.md         # Code and decisions only
    ├── level-1-compact.md         # Skip sentiments, keep substance
    ├── level-2-standard.md        # Full conversation flow
    ├── level-3-verbose.md         # Include context files read
    ├── level-4-complete.md        # Add tool execution details
    ├── level-5-raw.md             # All intermediate steps
    ├── sessions.json              # Metadata about matched sessions
    └── generation-log.txt         # When/how transcripts were generated
```

---

## 2. Detail Level Specification

### Level 0: Minimal (Code Focus)
- **Purpose**: Quick reference for "what was built"
- **Includes**:
  - Code blocks written or modified
  - File paths mentioned
  - Final decisions and outcomes
- **Excludes**:
  - Deliberation, reasoning, alternatives considered
  - User questions and clarifications
  - Tool outputs (search results, file reads)
- **Typical size**: 5-10% of raw transcript

### Level 1: Compact (Decision Focus)
- **Purpose**: Understanding what was decided and why
- **Includes**:
  - Key user requests
  - Final assistant responses
  - Code changes with brief context
- **Excludes**:
  - Emotional/social exchanges ("Great!", "Thanks!")
  - Intermediate exploration that led nowhere
  - Verbose tool outputs
- **Typical size**: 15-25% of raw transcript

### Level 2: Standard (Conversation Focus)
- **Purpose**: Reading the development conversation naturally
- **Includes**:
  - Complete user-assistant dialogue
  - Summarized tool results
  - Error messages and fixes
- **Excludes**:
  - Raw file contents (summarize as "Read file X")
  - Full search results (summarize as "Found 15 matches")
  - System messages and metadata
- **Typical size**: 40-60% of raw transcript

### Level 3: Verbose (Context Focus)
- **Purpose**: Understanding what information was available
- **Includes**:
  - Everything in Level 2
  - Files that were read (first N lines or summary)
  - Search results that influenced decisions
  - Referenced documentation
- **Excludes**:
  - Raw tool execution metadata
  - Timing information
  - Internal Claude processing
- **Typical size**: 70-85% of raw transcript

### Level 4: Complete (Execution Focus)
- **Purpose**: Debugging and understanding tool behavior
- **Includes**:
  - Everything in Level 3
  - Full tool invocation details
  - Command outputs and return codes
  - File diffs and patches
- **Excludes**:
  - Only internal Claude metadata
- **Typical size**: 90-95% of raw transcript

### Level 5: Raw (Archive Focus)
- **Purpose**: Complete preservation, forensic analysis
- **Includes**:
  - Everything from the JSONL source
  - Parsed and formatted for readability
  - All metadata, timestamps, message IDs
- **Typical size**: 100% of raw transcript

---

## 3. Critical Design Considerations

### 3.1 The Multi-Issue Problem

**Challenge**: Development sessions often span multiple issues.

A single Claude conversation might:
- Start on Issue 035g (transcript provenance)
- Discover a bug related to Issue 035d (file association)
- Create a new Issue 035h while working
- Return to complete Issue 035g

**Current Correlation Approach** (from 035g):
```
Score = issue_mention(40) + same_day(35) + same_week(20) + same_month(10) + file_overlap(5*n)
```

**Limitations**:
- A session mentioning multiple issues gets attributed to all of them
- No way to identify which *portions* of a session relate to which issue
- Cross-contamination of unrelated development context

**Proposed Solutions**:

1. **Segment-Level Attribution** (High Complexity)
   - Parse transcript into logical segments (user request → resolution)
   - Score each segment independently against issues
   - Include only segments above threshold for each issue
   - Risk: Breaks context continuity

2. **Overlap Acknowledgment** (Medium Complexity)
   - Include full sessions but add metadata header
   - Mark sections: `<!-- LIKELY RELATES TO: 035d -->`
   - Let user understand the multi-issue nature
   - Preserves context, adds cognitive load

3. **Primary Issue Heuristic** (Low Complexity)
   - Each session assigned to ONE primary issue (highest score)
   - Other issues get a reference: "See also: session-abc in Issue 035d"
   - Simple but loses multi-issue session content

**Recommendation**: Start with Option 3 (Primary Issue Heuristic) for v1, with metadata noting secondary issues. Upgrade to Option 2 if users request richer cross-referencing.

---

### 3.2 The Multi-Worker Problem

**Challenge**: Multiple LLM instances (or humans) may work simultaneously on the same issue or related issues.

Scenarios:
- Two Claude Code sessions open in different terminals
- One session for implementation, one for documentation
- User manually coding while Claude works on tests
- Parallel agents spawned by Task tool

**Identification Markers**:
```
Session Types:
- Primary: {uuid}_summary.md           # Main conversation
- Agent:   agent-{short-id}_summary.md  # Spawned subagent
- Human:   (no transcript)              # Manual work
```

**Problems**:
- Parallel sessions have overlapping timestamps
- Cannot determine sequencing from dates alone
- Agent sessions may lack full context of why they were spawned
- Human work has no transcript at all

**Proposed Solutions**:

1. **Session Clustering by Parent**
   - Agents include `parent_session_id` in metadata (if available)
   - Cluster agent sessions under their spawning session
   - Display as tree structure in transcript

2. **Timestamp Windowing with Gaps**
   - Identify "development windows" by activity clusters
   - Gap of >30 minutes suggests separate work sessions
   - Within window, assume related even if parallel

3. **Explicit Session Linking** (Requires infrastructure change)
   - Add `--issue 035g` flag to Claude Code
   - Sessions self-declare their target issue
   - Perfect attribution but requires workflow change

4. **Post-Hoc Human Annotation**
   - Generate best-guess transcript bundles
   - User reviews and corrects attribution
   - Store corrections for future learning

**Recommendation**: Implement (1) and (2) for automatic handling. Add (4) as a `--review` mode for important issues. Consider (3) as future enhancement proposal.

---

### 3.3 The Timestamp Correlation Accuracy Problem

**Challenge**: Date-based matching is fundamentally imprecise.

**Why Dates Are Unreliable**:

1. **Issue completion date != development date**
   - Issue might be marked complete days after last code change
   - Partial work might span multiple weeks
   - Issue file `mtime` reflects last edit, not completion

2. **Session timestamps are session-level, not message-level**
   - A 4-hour session has one start time
   - Work on different issues happens throughout
   - Cannot pinpoint when specific issue work occurred

3. **Clock skew and timezone issues**
   - Different machines may have different times
   - Transcripts may use UTC, issues may use local time
   - Daylight saving transitions create 1-hour windows

4. **Retroactive issue creation**
   - Issue files often created after implementation
   - No session explicitly mentions the issue ID
   - Must rely on file/content matching only

**Quantifying the Problem**:

```
Correlation Confidence Levels:

HIGH (0.75+):
  - Issue ID explicitly mentioned in transcript
  - Same files edited in both session and issue
  - Timestamps within same day

MEDIUM (0.5-0.74):
  - Files mentioned match issue scope
  - Timestamps within same week
  - No explicit issue reference

LOW (0.3-0.49):
  - Some file overlap
  - Timestamps within same month
  - Indirect content similarity

UNRELIABLE (<0.3):
  - Only timestamp proximity
  - No content overlap
  - Risk of false positive
```

**Proposed Mitigations**:

1. **Confidence Display**
   - Always show correlation confidence in transcript header
   - Color-code: Green (high), Yellow (medium), Red (low)
   - Let user decide if transcript is relevant

2. **Multiple Evidence Requirement**
   - Require 2+ correlation factors for inclusion
   - Timestamp alone never sufficient
   - At least one of: issue mention, file overlap, commit message match

3. **Negative Matching**
   - Explicitly exclude sessions that mention OTHER issues without this one
   - If session says "Working on Issue 040" and never mentions 035g, exclude from 035g

4. **User Override Mechanism**
   ```bash
   # Manual inclusion
   echo "session-id-1" >> issues/completed/035g/transcripts/.include

   # Manual exclusion
   echo "session-id-2" >> issues/completed/035g/transcripts/.exclude
   ```

**Recommendation**: Implement (1), (2), and (4). Accept that some mis-attribution will occur and provide tools for correction rather than perfect automation.

---

## 4. The "Perfect Storm" Scenario

Consider this realistic development situation:

```
Day 1, 10:00 - Developer opens Claude Code, starts Issue 035g
Day 1, 10:30 - Spawns agent to research Claude project paths
Day 1, 11:00 - Realizes Issue 035d has a bug, fixes it
Day 1, 11:30 - Returns to 035g, spawns another agent for testing
Day 1, 12:00 - Opens second terminal, starts Issue 040g design doc
Day 1, 12:30 - First terminal still working on 035g
Day 1, 13:00 - Takes lunch, comes back to find agents completed
Day 1, 14:00 - Completes 035g, marks done
Day 1, 14:15 - Completes 040g documentation, marks done
Day 1, 14:30 - Creates new Issue 035h based on discoveries
```

**Sessions created**:
1. `uuid-main-1` - Primary session (10:00-14:00, covers 035g, 035d, 035h)
2. `agent-abc` - First agent (10:30-10:45, 035g research)
3. `agent-def` - Second agent (11:30-12:00, 035g testing)
4. `uuid-main-2` - Second terminal (12:00-14:15, 040g only)

**Attribution challenges**:
- Session 1 touches 3 issues but spans the full window
- Session 2 is clearly 040g only
- Agent sessions should cluster under Session 1
- 035d fix has no dedicated session

**Desired outcome**:
```
issues/completed/035g/transcripts/
├── sessions.json
│   {
│     "primary": "uuid-main-1",
│     "agents": ["agent-abc", "agent-def"],
│     "confidence": 0.85,
│     "notes": "Session also touched 035d (bug fix), 035h (created)"
│   }
└── level-2-standard.md
    # Transcript for Issue 035g

    **Note**: This session also addressed Issue 035d (bug fix) and
    created Issue 035h. Sections marked with <!-- OTHER ISSUE -->
    may not be directly relevant to 035g.

    [Filtered and ordered content follows...]
```

---

## 5. Implementation Architecture

### 5.1 Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    Per-Issue Transcript System                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐      ┌──────────────────┐                 │
│  │ Session Matcher  │──────│ Issue Analyzer   │                 │
│  │                  │      │                  │                 │
│  │ - find_sessions  │      │ - extract_files  │                 │
│  │ - score_session  │      │ - get_completion │                 │
│  │ - cluster_agents │      │ - parse_deps     │                 │
│  └────────┬─────────┘      └────────┬─────────┘                 │
│           │                         │                            │
│           └───────────┬─────────────┘                            │
│                       ▼                                          │
│           ┌──────────────────┐                                   │
│           │ Transcript       │                                   │
│           │ Generator        │                                   │
│           │                  │                                   │
│           │ - parse_jsonl    │                                   │
│           │ - filter_level   │                                   │
│           │ - format_md      │                                   │
│           │ - annotate_other │                                   │
│           └────────┬─────────┘                                   │
│                    │                                             │
│                    ▼                                             │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Cache Manager                                            │    │
│  │                                                          │    │
│  │ issues/completed/{issue}/transcripts/                    │    │
│  │ ├── level-{0-5}-{name}.md                               │    │
│  │ ├── sessions.json                                        │    │
│  │ └── generation-log.txt                                   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Processing Pipeline

```
1. ISSUE COMPLETION TRIGGER
   └─> Issue file moved to completed/

2. SESSION DISCOVERY
   ├─> Scan llm-transcripts/ for date range
   ├─> Scan ~/.claude/projects/ for raw JSONL
   └─> Apply correlation scoring (issue ID, files, dates)

3. SESSION CLUSTERING
   ├─> Identify agent sessions
   ├─> Link agents to parent sessions
   └─> Build session tree

4. MULTI-ISSUE DETECTION
   ├─> Scan matched sessions for other issue references
   ├─> Tag sections with likely issue attribution
   └─> Generate cross-reference notes

5. LEVEL GENERATION (for each level 0-5)
   ├─> Parse raw JSONL content
   ├─> Apply level-specific filters
   ├─> Insert annotations for other-issue sections
   ├─> Format as Markdown
   └─> Write to cache directory

6. METADATA GENERATION
   ├─> Create sessions.json with attribution data
   ├─> Log generation details
   └─> Update issue file with transcript link
```

### 5.3 CLI Interface (Proposed)

```bash
# Generate transcripts for a completed issue
./scripts/generate-issue-transcripts.sh 035g

# Regenerate with specific options
./scripts/generate-issue-transcripts.sh 035g \
    --levels 0,2,5 \
    --min-confidence 0.5 \
    --exclude-agents

# Interactive review mode
./scripts/generate-issue-transcripts.sh 035g --review

# Batch generation for all completed issues
./scripts/generate-issue-transcripts.sh --all

# View transcript at specific level
./scripts/view-issue-transcript.sh 035g --level 2

# Compare what changed between levels
./scripts/view-issue-transcript.sh 035g --diff 1 2
```

---

## 6. Data Formats

### 6.1 sessions.json

```json
{
  "issue_id": "035g",
  "generated_at": "2026-01-04T14:30:00Z",
  "generator_version": "1.0.0",
  "correlation_threshold": 0.3,

  "primary_sessions": [
    {
      "id": "uuid-main-1",
      "source": "llm-transcripts/uuid-main-1_summary.md",
      "correlation_score": 0.92,
      "correlation_reasons": ["issue-mentioned", "same-day", "file-overlap:5"],
      "start_time": "2026-01-04T10:00:00Z",
      "end_time": "2026-01-04T14:00:00Z",
      "other_issues_mentioned": ["035d", "035h"],
      "agent_children": ["agent-abc", "agent-def"]
    }
  ],

  "agent_sessions": [
    {
      "id": "agent-abc",
      "parent": "uuid-main-1",
      "source": "llm-transcripts/agent-abc_summary.md",
      "purpose": "Research Claude project paths",
      "duration_minutes": 15
    }
  ],

  "excluded_sessions": [
    {
      "id": "uuid-main-2",
      "reason": "Explicitly references Issue 040g only",
      "correlation_score": 0.15
    }
  ],

  "user_overrides": {
    "include": [],
    "exclude": []
  },

  "statistics": {
    "total_sessions_scanned": 45,
    "sessions_matched": 3,
    "sessions_excluded": 1,
    "avg_confidence": 0.78,
    "total_message_count": 247,
    "level_sizes_kb": {
      "0": 12,
      "1": 28,
      "2": 67,
      "3": 145,
      "4": 198,
      "5": 234
    }
  }
}
```

### 6.2 Transcript Header Format

```markdown
# Issue 035g: Transcript (Level 2 - Standard)

## Metadata
| Property | Value |
|----------|-------|
| Issue | 035g-transcript-to-commit-provenance |
| Generated | 2026-01-04 14:30:00 |
| Sessions | 3 (1 primary, 2 agents) |
| Confidence | 0.78 (Medium-High) |
| Detail Level | 2 - Standard (conversation focus) |

## Session Attribution
- **Primary**: uuid-main-1 (4 hours, 10:00-14:00)
- **Agent**: agent-abc (15 min, Claude path research)
- **Agent**: agent-def (30 min, test execution)

## Cross-References
This session also addressed:
- Issue 035d (bug fix, sections marked `<!-- 035d -->`)
- Issue 035h (created during session)

---

## Conversation

[Content follows...]
```

---

## 7. Edge Cases and Handling

### 7.1 No Transcripts Available

**Scenario**: Issue completed before transcript backup was implemented.

**Handling**:
```
issues/completed/old-issue/transcripts/
└── sessions.json
    {
      "issue_id": "old-issue",
      "primary_sessions": [],
      "note": "No transcripts available. Issue predates backup system.",
      "estimated_completion": "2024-06-15"
    }
```

### 7.2 Transcript Without Issue Reference

**Scenario**: Session clearly worked on the issue but never mentioned its ID.

**Handling**:
- Rely on file overlap and timestamp correlation
- Mark confidence as "inferred" rather than "explicit"
- Include in results but flag for potential review

### 7.3 Issue Completed Retroactively

**Scenario**: Work done, then issue file created later to document it.

**Handling**:
- Use issue file creation date as anchor
- Expand search window backwards
- Accept lower confidence thresholds for pre-issue sessions

### 7.4 Very Long Sessions

**Scenario**: 8-hour session covering many issues.

**Handling**:
- Attempt segment-level analysis
- Generate section markers for different issue work
- Consider splitting into virtual sub-sessions
- Always include full session in Level 5

### 7.5 Contradictory Transcripts

**Scenario**: Two sessions give conflicting approaches for same issue.

**Handling**:
- Include both with chronological ordering
- Add note: "Earlier approach superseded by later session"
- Let user understand the evolution

---

## 8. Future Considerations

### 8.1 Semantic Segmentation

Using embedding similarity to identify issue-specific segments within sessions:
```
Session content → Embed each paragraph
Issue description → Embed
Cosine similarity → Identify relevant segments
```

**Pros**: Much finer-grained attribution
**Cons**: Requires embedding infrastructure, computational cost

### 8.2 Interactive Transcript Explorer

TUI interface for browsing transcripts:
```
┌─────────────────────────────────────────────────────┐
│ Issue 035g Transcript Explorer                      │
├─────────────────────────────────────────────────────┤
│ Level: [0] [1] [2•] [3] [4] [5]    Sessions: 3     │
├─────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────┐ │
│ │ 10:15 - User: I need to implement the          │ │
│ │ provenance linking feature...                   │ │
│ │                                                 │ │
│ │ 10:16 - Claude: I'll start by reading the      │ │
│ │ reconstruct-history.sh script...               │ │
│ │                                  [MORE ▼]      │ │
│ └─────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│ [j/k] Navigate  [Tab] Change level  [/] Search     │
│ [g] Go to segment  [q] Quit                        │
└─────────────────────────────────────────────────────┘
```

### 8.3 Explicit Issue Tagging

Modify Claude Code workflow to declare issue context:
```bash
# Start session with explicit issue
claude --issue 035g

# Switch issue mid-session
/issue 040g

# End issue context
/issue --end
```

**Benefit**: Perfect attribution with zero inference
**Cost**: Workflow change, discipline required

### 8.4 Human Work Integration

Track non-LLM development:
```bash
# Log manual work start
./scripts/log-work.sh 035g --start "Researching API docs"

# Log manual work end
./scripts/log-work.sh 035g --end "Found solution in docs"
```

Creates stub entries in transcript timeline:
```markdown
### 11:30 - Manual Work Session
*Researching API docs*
Duration: 45 minutes
(No transcript - human work)
```

---

## 9. Implementation Priority

### Phase 1: Core Infrastructure (Recommended First)
1. Create directory structure on issue completion
2. Implement session matching with existing correlation
3. Generate Level 2 (Standard) transcripts only
4. Basic sessions.json metadata

### Phase 2: Multi-Level Generation
1. Implement all 6 detail levels
2. Add filtering logic for each level
3. Generate all levels in batch
4. Size/diff comparison tooling

### Phase 3: Multi-Issue Handling
1. Segment-level other-issue detection
2. Cross-reference annotations
3. Primary issue assignment heuristic
4. User override mechanism

### Phase 4: Polish and Tooling
1. Interactive review mode
2. TUI transcript explorer
3. Batch regeneration for existing issues
4. Integration with git hooks

---

## 10. Open Questions

1. **Should completed issue directories contain the issue file?**
   - Currently: `issues/completed/035g.md`
   - Proposed: `issues/completed/035g/035g.md` + `transcripts/`
   - Trade-off: Cleaner organization vs. breaking existing paths

2. **How to handle transcript updates when source JSONL changes?**
   - Regenerate all levels? Only changed sessions?
   - Version the transcripts?

3. **Should Level 5 (raw) be optional?**
   - It's large and rarely needed
   - Could generate on-demand instead of caching

4. **Integration with git commits?**
   - Should transcript generation trigger on commit?
   - Or only on issue completion?

5. **Privacy considerations?**
   - Transcripts may contain sensitive information
   - Should there be a redaction pass?

---

## References

- [Issue 035g: Transcript-to-Commit Provenance](../issues/completed/035g-transcript-to-commit-provenance.md)
- [Issue 040g: Transcript Analysis Memory](../issues/040g-transcript-analysis-memory.md)
- [backup-conversations Script](../../../scripts/backup-conversations)
- [claude-conversation-exporter.sh](../../../scripts/claude-conversation-exporter.sh)
- [History Tools Guide](history-tools-guide.md)

---

*Document version: 1.0*
*Last updated: 2026-01-04*
