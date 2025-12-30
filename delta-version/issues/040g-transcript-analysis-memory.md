# Issue 040g: Transcript Analysis and Reasoning Memory

## Status
- **Parent Issue**: 040 (Dynamic CLAUDE.md Revision System)
- **Priority**: High (Core Capability)
- **Type**: Implementation
- **Dependencies**: 040a (Event Taxonomy), 040d (History System)
- **Blocks**: None (enhances all other sub-issues)

## Current Behavior
When a guideline exists in CLAUDE.md, there is no way to answer:
- "Why was this decision made?"
- "What was the context that led to this?"
- "Was there a counter-argument that was considered?"

The reasoning that produced guidelines is lost in ephemeral conversation sessions.

## Intended Behavior
Create a system with:
1. **Read-only access** to project transcription logs (llm-transcripts/)
2. **Write-only access** to its own analysis logs (analysis/)
3. **Reasoning reconstruction** capability for any guideline

The system becomes a "tough questions" oracle - given enough thought (transcript analysis), it can reconstruct the reasoning chain behind any decision.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRANSCRIPT SOURCES                           │
│  (Read-Only Access)                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   project-1/llm-transcripts/          project-2/llm-transcripts/│
│   ├── session_2025-12-28_001.md       ├── session_...          │
│   ├── session_2025-12-29_001.md       └── ...                  │
│   └── ...                                                       │
│                                                                 │
│   ~/.claude/transcripts/              (global sessions)         │
│   └── ...                                                       │
│                                                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │ READ ONLY
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ANALYSIS ENGINE                              │
│  (Processing Layer)                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐       │
│   │  Transcript  │   │   Decision   │   │  Reasoning   │       │
│   │   Scanner    │──▶│  Extractor   │──▶│  Synthesizer │       │
│   └──────────────┘   └──────────────┘   └──────────────┘       │
│                                                                 │
│   • Find decision moments    • Extract context      • Build    │
│   • Identify corrections     • Capture arguments      chains   │
│   • Track preferences        • Note alternatives    • Answer   │
│                                                        "why?"   │
└───────────────────────────┬─────────────────────────────────────┘
                            │ WRITE ONLY
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ANALYSIS STORAGE                             │
│  (Write-Only Access)                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ~/.claude/analysis/                                           │
│   ├── decisions/                                                │
│   │   ├── dec_g001_script_portability.md                       │
│   │   ├── dec_g002_vimfold_convention.md                       │
│   │   └── ...                                                   │
│   ├── reasoning_chains/                                         │
│   │   ├── chain_040_claudemd_system.md                         │
│   │   └── ...                                                   │
│   └── index.json                                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Access Control Model

### Read-Only Sources (Immutable from this system's perspective)

```lua
local READ_SOURCES = {
    -- Per-project transcript directories
    project_transcripts = "{project_root}/llm-transcripts/",

    -- Global Claude session logs
    global_transcripts = "~/.claude/transcripts/",

    -- Existing CLAUDE.md (to correlate guidelines)
    guidelines = "~/.claude/CLAUDE.md",

    -- Issue files (for context)
    issues = "{project_root}/issues/"
}

-- This system NEVER writes to these locations
-- It only observes what happened
```

### Write-Only Destinations (Append-only analysis)

```lua
local WRITE_DESTINATIONS = {
    -- Decision analysis files
    decisions = "~/.claude/analysis/decisions/",

    -- Reasoning chain reconstructions
    chains = "~/.claude/analysis/reasoning_chains/",

    -- Reconciliations (when contradictions are resolved)
    reconciliations = "~/.claude/analysis/reconciliations/",

    -- Signposts (appended to existing files, never overwriting)
    -- Note: signposts are appended to files in decisions/ and chains/
    -- They point to reconciliations/ when truth is found

    -- Cross-reference index
    index = "~/.claude/analysis/index.json",

    -- Query cache (for repeated questions)
    cache = "~/.claude/analysis/cache/"
}

-- This system only APPENDS to these locations
-- Never modifies or deletes existing analysis
-- Signposts are the ONLY append operation to existing files
```

## Decision Record Format

When the system identifies a decision moment in transcripts:

```markdown
# Decision Record: dec_g002_vimfold_convention

## Guideline
"all functions should use vimfolds to collapse functionality"

## Decision Moment
- **Session**: project-delta/llm-transcripts/session_2024-11-15_002.md
- **Line Range**: 142-178
- **Timestamp**: 2024-11-15 14:32:00

## Context Leading to Decision
User was working on a large Lua file with 40+ functions. Complained about
difficulty navigating. Assistant suggested folding. User refined to specify
vimfold syntax specifically.

## Key Exchanges

### User Statement (line 145):
> "This file is impossible to navigate, I can't find anything"

### Assistant Suggestion (line 148):
> "Consider using code folding markers to collapse functions"

### User Refinement (line 156):
> "Use vimfolds specifically, with the function name in the fold marker"

### Final Agreement (line 172):
> "Yes, that's exactly what I want for all functions going forward"

## Alternatives Considered
- Generic folding markers (rejected: not vim-specific)
- IDE-based folding (rejected: user prefers terminal)
- No folding with smaller files (rejected: user prefers larger organized files)

## Reasoning Chain
1. Problem: Large file navigation difficulty
2. General solution: Code folding
3. Specific solution: Vimfolds (user's editor)
4. Refinement: Include function name in marker
5. Scope: Apply to all functions

## Confidence
- Decision clarity: HIGH (explicit user statement)
- Context completeness: HIGH (full conversation available)
- Alternative coverage: MEDIUM (some alternatives implicit)

## Related Decisions
- dec_g001 (script portability) - same session, establishes file conventions
- dec_g015 (comment style) - related to code documentation

## Last Updated
2025-12-29 15:00:00 (initial analysis)
```

## Reasoning Chain Format

For complex decisions spanning multiple sessions:

```markdown
# Reasoning Chain: chain_error_over_fallback

## Final Guideline
"prefer error messages and breaking functionality over fallbacks"

## Chain Summary
Decision emerged over 3 sessions across 2 weeks, triggered by debugging
difficulty when fallbacks masked root causes.

## Session Timeline

### Session 1: 2024-11-20 (delta-version)
- **Trigger**: Silent failure in script, user spent 2 hours debugging
- **Initial reaction**: "Why didn't this tell me something was wrong?"
- **Outcome**: Local preference noted, not yet generalized

### Session 2: 2024-11-28 (world-edit project)
- **Trigger**: Another silent fallback caused confusion
- **User statement**: "I'd rather have it crash than silently do the wrong thing"
- **Outcome**: Pattern recognized across projects

### Session 3: 2024-12-01 (general session)
- **Trigger**: User explicitly requested this be added to CLAUDE.md
- **Statement**: "I prefer error messages over fallbacks, always"
- **Outcome**: Guideline formalized

## Evolution of Understanding

```
Session 1                    Session 2                    Session 3
    │                           │                           │
    ▼                           ▼                           ▼
"This specific             "This happens              "This is a
 failure should             in multiple                general
 have errored"              projects"                  principle"
    │                           │                           │
    └───────────────────────────┴───────────────────────────┘
                                │
                                ▼
                    GUIDELINE CRYSTALLIZED
```

## Counter-Arguments Encountered
1. "Fallbacks provide graceful degradation" → User response: "I'd rather know immediately"
2. "Users might see scary errors" → Context: Developer tooling, not end-user software

## Why This Decision Matters
User's workflow depends on immediate feedback. Silent failures compound into
larger debugging sessions. The cost of a crash is lower than the cost of
hidden incorrect behavior.
```

## Signpost Protocol

When the system discovers contradictory reasoning in its own analysis (e.g., "rejected X because Y" followed later by "accepted X because Z"), it does NOT:
- Flag as error (too passive - leaves the contradiction unresolved)
- Supersede silently (rewrites history, loses the learning)

Instead, it **re-evaluates to find truth, then leaves a signpost**:

### The Signpost Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│  ORIGINAL ANALYSIS (untouched, preserved)                       │
│  ~/.claude/analysis/decisions/dec_g007_fallback_rejection.md   │
├─────────────────────────────────────────────────────────────────┤
│  "Rejected: allow fallbacks for non-critical operations"        │
│  Reason: User stated "I'd rather have it crash"                 │
│  Date: 2024-11-28                                               │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ ⚠ SIGNPOST (appended 2025-12-29)                         │  │
│  │                                                           │  │
│  │ This reasoning was later re-examined.                     │  │
│  │ See: analysis/reconciliations/rec_001_fallback_truth.md  │  │
│  │                                                           │  │
│  │ The re-evaluation found: [brief summary]                  │  │
│  │ The truth of the matter: [conclusion]                     │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ points to
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  RECONCILIATION (new file, the re-evaluation)                   │
│  ~/.claude/analysis/reconciliations/rec_001_fallback_truth.md  │
├─────────────────────────────────────────────────────────────────┤
│  ## Contradiction Discovered                                    │
│  Prior analysis: dec_g007 rejected fallbacks (2024-11-28)       │
│  Later analysis: dec_g048 accepted scoped fallbacks (2025-01)   │
│                                                                 │
│  ## Re-Evaluation Process                                       │
│  Examined original transcripts: [session refs]                  │
│  Examined later transcripts: [session refs]                     │
│                                                                 │
│  ## The Truth of the Matter                                     │
│  The user's position evolved:                                   │
│  - Initially: absolute rejection of fallbacks                   │
│  - Later: nuanced view - errors for dev tools, fallbacks for    │
│    user-facing features where crash is worse than degradation   │
│                                                                 │
│  ## Reconciled Understanding                                    │
│  "Prefer errors in developer tooling; allow graceful            │
│   degradation in end-user features where crash impact > error"  │
│                                                                 │
│  ## Evidence Chain                                              │
│  1. [transcript link] - original strong statement               │
│  2. [transcript link] - context was debugging session           │
│  3. [transcript link] - later, discussing user-facing app       │
│  4. [transcript link] - refined position emerges                │
└─────────────────────────────────────────────────────────────────┘
```

### Why Signposts, Not Overwrites

1. **Preserves the journey**: Future readers see HOW understanding evolved, not just the final answer
2. **Respects the past self**: The earlier reasoning wasn't "wrong" - it was incomplete given available evidence
3. **Creates learning artifacts**: The reconciliation process itself is valuable - it shows the WORK of finding truth
4. **Guides adventurers**: Like a signpost warning of danger ahead, it says "if you're following this old path, know that it leads somewhere different now"

### Signpost Record Format

```lua
local Signpost = {
    id = "signpost_20251229_001",
    created = 1735490000,

    -- Location being marked
    target_file = "analysis/decisions/dec_g007_fallback_rejection.md",
    target_type = "decision",

    -- The contradiction that triggered re-evaluation
    contradiction = {
        prior_analysis = "dec_g007",
        later_analysis = "dec_g048",
        nature = "opposite_conclusions_same_subject"
    },

    -- Where the truth-seeking led
    reconciliation_file = "analysis/reconciliations/rec_001_fallback_truth.md",

    -- Brief summary (shown in signpost)
    summary = "Position evolved: errors for dev tools, fallbacks for user-facing",

    -- The found truth
    truth = "Context-dependent: developer tooling vs end-user features"
}
```

### Implementation: Contradiction Detection and Resolution

```lua
-- {{{ function detect_contradictions
function detect_contradictions()
    local all_decisions = load_all_decisions()
    local contradictions = {}

    for i, dec1 in ipairs(all_decisions) do
        for j, dec2 in ipairs(all_decisions) do
            if i < j then  -- Avoid duplicate pairs
                -- Same subject, opposite conclusions
                if same_subject(dec1, dec2) and opposite_conclusions(dec1, dec2) then
                    table.insert(contradictions, {
                        earlier = dec1.timestamp < dec2.timestamp and dec1 or dec2,
                        later = dec1.timestamp < dec2.timestamp and dec2 or dec1,
                        subject = extract_shared_subject(dec1, dec2)
                    })
                end
            end
        end
    end

    return contradictions
end
-- }}}

-- {{{ function reconcile_contradiction
function reconcile_contradiction(contradiction)
    -- 1. Gather all evidence
    local earlier_transcripts = get_source_transcripts(contradiction.earlier)
    local later_transcripts = get_source_transcripts(contradiction.later)

    -- 2. Re-evaluate: what is the truth?
    local truth = seek_truth({
        subject = contradiction.subject,
        earlier_position = contradiction.earlier.conclusion,
        later_position = contradiction.later.conclusion,
        earlier_evidence = earlier_transcripts,
        later_evidence = later_transcripts
    })

    -- 3. Write reconciliation file
    local rec_file = write_reconciliation({
        contradiction = contradiction,
        truth = truth,
        evidence_chain = truth.evidence
    })

    -- 4. Append signpost to earlier analysis (not overwrite!)
    append_signpost(contradiction.earlier.file, {
        reconciliation = rec_file,
        summary = truth.summary,
        truth = truth.conclusion
    })

    -- 5. Optionally append signpost to later analysis too
    if truth.also_incomplete then
        append_signpost(contradiction.later.file, {
            reconciliation = rec_file,
            summary = truth.summary,
            note = "This analysis was also partial; see reconciliation"
        })
    end

    return rec_file
end
-- }}}
```

## Query Interface

```lua
-- {{{ reasoning_memory module
local reasoning_memory = {}

-- {{{ function reasoning_memory.why
-- Answer "why does this guideline exist?"
function reasoning_memory.why(guideline_id_or_content)
    -- 1. Find matching guideline
    local guideline = find_guideline(guideline_id_or_content)

    -- 2. Look up decision record
    local decision = load_decision_record(guideline.id)

    if decision then
        return {
            answer = decision.reasoning_chain,
            confidence = decision.confidence,
            sources = decision.session_references,
            alternatives = decision.alternatives_considered
        }
    end

    -- 3. If no cached analysis, trigger analysis
    return analyze_guideline_origin(guideline)
end
-- }}}

-- {{{ function reasoning_memory.what_if
-- Answer "what if we changed this?"
function reasoning_memory.what_if(guideline_id, proposed_change)
    local decision = load_decision_record(guideline_id)

    -- Find original counter-arguments
    local original_alternatives = decision.alternatives_considered

    -- Check if proposed change matches a rejected alternative
    for _, alt in ipairs(original_alternatives) do
        if semantic_match(proposed_change, alt.description) then
            return {
                warning = "This was previously considered and rejected",
                original_reasoning = alt.rejection_reason,
                context = alt.session_reference
            }
        end
    end

    return {
        status = "novel_proposal",
        suggestion = "No prior consideration found - may be worth discussing"
    }
end
-- }}}

-- {{{ function reasoning_memory.trace
-- Full provenance trace for a guideline
function reasoning_memory.trace(guideline_id)
    return {
        guideline = load_guideline(guideline_id),
        decision_record = load_decision_record(guideline_id),
        reasoning_chain = load_reasoning_chain(guideline_id),
        related_decisions = find_related_decisions(guideline_id),
        transcript_references = collect_transcript_refs(guideline_id)
    }
end
-- }}}

return reasoning_memory
-- }}}
```

## Transcript Scanner Implementation

```lua
-- {{{ transcript_scanner module
-- Scans transcripts for decision moments (READ-ONLY)

local scanner = {}

-- Decision moment indicators
local DECISION_SIGNALS = {
    -- Explicit preferences
    preferences = {
        "I prefer", "I want", "I'd rather", "always use",
        "never use", "from now on", "going forward"
    },

    -- Corrections
    corrections = {
        "no, actually", "that's wrong", "don't do that",
        "instead,", "not like that"
    },

    -- Agreements
    agreements = {
        "yes, that's", "exactly", "perfect", "that's what I want",
        "add that to", "remember that"
    },

    -- Rejections
    rejections = {
        "no,", "I don't want", "that won't work", "not that",
        "I tried that"
    }
}

-- {{{ function scanner.find_decision_moments
function scanner.find_decision_moments(transcript_path)
    local content = read_file(transcript_path)  -- READ-ONLY
    local lines = split_lines(content)
    local moments = {}

    for i, line in ipairs(lines) do
        local signals_found = detect_signals(line, DECISION_SIGNALS)

        if #signals_found > 0 then
            -- Extract context window (10 lines before, 10 after)
            local context = extract_context(lines, i, 10, 10)

            table.insert(moments, {
                line_number = i,
                line_content = line,
                signals = signals_found,
                context = context,
                transcript = transcript_path
            })
        end
    end

    return moments
end
-- }}}

-- {{{ function scanner.correlate_with_guidelines
function scanner.correlate_with_guidelines(moments, guidelines)
    local correlations = {}

    for _, moment in ipairs(moments) do
        for _, guideline in ipairs(guidelines) do
            local similarity = calculate_semantic_similarity(
                moment.context,
                guideline.content
            )

            if similarity > 0.6 then
                table.insert(correlations, {
                    moment = moment,
                    guideline = guideline,
                    similarity = similarity
                })
            end
        end
    end

    return correlations
end
-- }}}

return scanner
-- }}}
```

## Analysis Writer Implementation

```lua
-- {{{ analysis_writer module
-- Writes analysis to dedicated directory (WRITE-ONLY, APPEND-ONLY)

local writer = {}
local ANALYSIS_DIR = os.getenv("HOME") .. "/.claude/analysis/"

-- {{{ function writer.write_decision
function writer.write_decision(decision_record)
    local filename = string.format("dec_%s_%s.md",
        decision_record.guideline_id,
        slugify(decision_record.summary)
    )

    local filepath = ANALYSIS_DIR .. "decisions/" .. filename

    -- APPEND-ONLY: If file exists, append update section
    if file_exists(filepath) then
        local update = format_update_section(decision_record)
        append_file(filepath, update)  -- Never overwrite
    else
        local content = format_decision_record(decision_record)
        write_file(filepath, content)
    end

    -- Update index (append entry)
    update_index("decisions", decision_record.guideline_id, filename)

    return filepath
end
-- }}}

-- {{{ function writer.write_reasoning_chain
function writer.write_reasoning_chain(chain)
    local filename = string.format("chain_%s.md", slugify(chain.name))
    local filepath = ANALYSIS_DIR .. "reasoning_chains/" .. filename

    -- Same append-only logic
    if file_exists(filepath) then
        append_file(filepath, format_chain_update(chain))
    else
        write_file(filepath, format_reasoning_chain(chain))
    end

    return filepath
end
-- }}}

return writer
-- }}}
```

## Suggested Implementation Steps

1. **Define access boundaries** (`src/access_control.lua`)
   - Enumerate read-only sources
   - Enumerate write-only destinations
   - Enforce at module level

2. **Build transcript scanner** (`src/transcript_scanner.lua`)
   - Decision signal detection
   - Context window extraction
   - Guideline correlation

3. **Create decision extractor** (`src/decision_extractor.lua`)
   - Parse decision moments
   - Identify key exchanges
   - Extract alternatives considered

4. **Implement reasoning synthesizer** (`src/reasoning_synthesizer.lua`)
   - Build reasoning chains from multiple sessions
   - Track decision evolution
   - Generate "why" explanations

5. **Build analysis writer** (`src/analysis_writer.lua`)
   - Decision record formatting
   - Append-only file operations
   - Index maintenance

6. **Create query interface** (`src/reasoning_memory.lua`)
   - `why()` - guideline provenance
   - `what_if()` - change impact analysis
   - `trace()` - full history

7. **Integrate with TUI** (update 040f)
   - Add "Why?" button to guideline detail view
   - Show reasoning chain visualization

## Use Cases

### "Why does this guideline exist?"
```
> claudemd why "prefer error messages over fallbacks"

REASONING TRACE:
This guideline emerged from 3 debugging incidents where silent fallbacks
masked root causes, costing hours of investigation time.

KEY MOMENT (2024-11-20, delta-version session):
  User: "Why didn't this tell me something was wrong?"

EVOLUTION:
  Specific complaint → Pattern recognition → General principle

ALTERNATIVES REJECTED:
  • Graceful degradation: "I'd rather know immediately"

CONFIDENCE: HIGH (explicit user statement, multiple reinforcing sessions)
```

### "What if we allowed fallbacks sometimes?"
```
> claudemd what-if g007 "allow fallbacks for non-critical operations"

WARNING: This was previously considered.

ORIGINAL REJECTION (2024-11-28):
  "I'd rather have it crash than silently do the wrong thing"

CONTEXT: User's workflow depends on immediate feedback. Even "non-critical"
failures can compound into larger debugging sessions.

RECOMMENDATION: If you want to revisit this, consider discussing the specific
use case rather than the general principle.
```

## Related Documents
- [Issue 040](./040-dynamic-claudemd-revision-system.md) - Parent issue
- [Issue 040a](./040a-design-event-taxonomy.md) - Events this system analyzes
- [Issue 040d](./040d-create-history-audit-system.md) - Complements the history system

## Notes
- Read-only access is CRITICAL - this system observes, never modifies transcripts
- Write-only access ensures analysis can't be retroactively altered
- "Tough questions" capability depends on transcript completeness
- Consider: Should analysis trigger automatically, or only on query?
- Privacy: Some transcripts may contain sensitive content - add filtering option
