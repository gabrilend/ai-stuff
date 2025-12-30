# Issue 040a: Design Event Taxonomy and Pattern Detection

## Status
- **Parent Issue**: 040 (Dynamic CLAUDE.md Revision System)
- **Priority**: High (Foundation)
- **Type**: Design + Implementation
- **Dependencies**: None
- **Blocks**: 040b, 040c, 040d

## Current Behavior
There is no formal classification of events that could trigger CLAUDE.md revisions. The concept of "natural events" is undefined, making it impossible to systematically detect patterns that should become guidelines.

## Intended Behavior
Define a comprehensive taxonomy of events that can trigger guideline proposals, along with detection mechanisms for each event type.

## Event Taxonomy

### 1. Correction Events
**Definition**: User explicitly corrects AI behavior or output.

**Detection Signals**:
- Phrases: "No, actually...", "That's wrong", "Don't do that", "Instead, you should..."
- Immediate re-instruction after AI action
- User edits AI-generated content and explains why

**Example**:
```
User: "No, don't use snake_case - this project uses camelCase for all variables"
→ Potential guideline: "Use camelCase for variable names in this project"
```

**Confidence Threshold**: Single instance = low, 2 instances = medium, 3+ = high

### 2. Repetition Events
**Definition**: User repeats the same instruction across multiple sessions or contexts.

**Detection Signals**:
- Same conceptual instruction given N times (configurable, default N=3)
- Instruction appears in multiple projects
- User adds emphasis ("Remember to...", "Always...", "Every time...")

**Example**:
```
Session 1: "Add vimfolds to this function"
Session 2: "This function needs vimfolds"
Session 3: "You forgot the vimfolds again"
→ Proposal: "All functions should use vimfolds"
```

**Confidence Threshold**: 3 repetitions = auto-propose

### 3. Discovery Events
**Definition**: Pattern discovered through codebase analysis.

**Detection Signals**:
- Consistent pattern across 70%+ of files analyzed
- Pattern not yet documented in CLAUDE.md
- Pattern appears intentional (not accidental duplication)

**Example**:
```
Scanning src/: Found 47/50 Lua files use 2-space indentation
Current CLAUDE.md: No indentation guideline
→ Proposal: "Use 2-space indentation in Lua files"
```

**Confidence Threshold**: 70% = suggested, 85% = experimental, 95% = established

### 4. Preference Events
**Definition**: User explicitly states a preference.

**Detection Signals**:
- "I prefer...", "I like...", "I want...", "I'd rather..."
- Comparative statements: "X over Y", "X instead of Y"
- Emphatic preferences: "Always X, never Y"

**Example**:
```
User: "I prefer error messages over silent fallbacks"
→ Direct proposal: "Prefer error messages over fallbacks"
```

**Confidence Threshold**: Explicit = high (single instance sufficient)

### 5. Script Call Events
**Definition**: Programmatic registration via API.

**Detection Signals**:
- Valid API call to `/claudemd.sock`
- Script provides reasoning and source attribution

**Example**:
```lua
claudemd.propose({
    content = "Database connections must be pooled",
    source = "performance-audit.lua",
    reasoning = "Connection overhead causing 40ms latency"
})
```

**Confidence Threshold**: Based on script-provided confidence level

### 6. Conflict Events
**Definition**: New instruction contradicts existing guideline.

**Detection Signals**:
- Semantic analysis detects opposition
- Keywords: "but", "however", "except when", "unless"
- User overrides existing documented behavior

**Example**:
```
CLAUDE.md: "Use tabs for indentation"
User: "Use 2 spaces in this file"
→ Conflict logged, user asked to clarify scope
```

**Confidence Threshold**: Requires human resolution

### 7. Deprecation Events
**Definition**: Guideline becomes obsolete or harmful.

**Detection Signals**:
- User consistently ignores or overrides guideline
- Guideline causes repeated errors
- User explicitly says "forget that rule"

**Example**:
```
Guideline: "All files must have header comments"
User ignores for 10 consecutive files
→ Proposal: Deprecate header comment requirement
```

**Confidence Threshold**: 10 consecutive violations = propose deprecation

## Pattern Detection System

### Data Model

```lua
-- Event record structure
local Event = {
    id = "evt_20251229_001",
    type = "correction|repetition|discovery|preference|script|conflict|deprecation",
    timestamp = os.time(),
    session_id = "sess_abc123",
    project = "delta-version",

    -- Content
    raw_input = "No, use camelCase here",
    extracted_guideline = "Use camelCase for variables",
    category = "coding-style",

    -- Detection metadata
    confidence = 0.85,
    signals = {"correction_phrase", "immediate_re-instruction"},
    related_events = {"evt_20251228_047", "evt_20251227_012"},

    -- State
    status = "pending|proposed|approved|rejected|superseded"
}
```

### Detection Pipeline

```
User Input / Script Call / Codebase Scan
              │
              ▼
┌─────────────────────────────┐
│    Signal Extractor         │
│  (Regex, keyword, semantic) │
└─────────────┬───────────────┘
              │
              ▼
┌─────────────────────────────┐
│    Event Classifier         │
│  (Map signals → event type) │
└─────────────┬───────────────┘
              │
              ▼
┌─────────────────────────────┐
│    Pattern Aggregator       │
│  (Group related events)     │
└─────────────┬───────────────┘
              │
              ▼
┌─────────────────────────────┐
│    Confidence Calculator    │
│  (Thresholds → proposals)   │
└─────────────┬───────────────┘
              │
              ▼
        Event Log + Proposals
```

## Suggested Implementation Steps

1. **Create event schema** (`~/.claude/schema/event.lua`)
   - Define Event record structure
   - Add validation functions
   - Create serialization/deserialization

2. **Implement signal extractors** (`src/signals/`)
   - `correction_signals.lua` - Detect correction phrases
   - `repetition_signals.lua` - Track instruction frequency
   - `discovery_signals.lua` - Codebase pattern scanner
   - `preference_signals.lua` - Preference phrase detection

3. **Build event classifier** (`src/classifier.lua`)
   - Map extracted signals to event types
   - Handle ambiguous cases (multiple possible types)
   - Log classification reasoning

4. **Create pattern aggregator** (`src/aggregator.lua`)
   - Group events by semantic similarity
   - Track event chains across sessions
   - Maintain frequency counts

5. **Implement confidence calculator** (`src/confidence.lua`)
   - Apply thresholds per event type
   - Generate proposals when thresholds met
   - Handle edge cases (conflicts, deprecations)

## Storage Format

Events stored in append-only log:
```
~/.claude/history/events.log

# Format: JSON-lines
{"id":"evt_001","type":"correction","timestamp":1735432800,"content":"Use camelCase",...}
{"id":"evt_002","type":"preference","timestamp":1735432860,"content":"Prefer errors",...}
```

## Test Cases

1. **Correction detection**: Input "No, that's wrong - use X" → classified as correction
2. **Repetition threshold**: Same instruction 3x → triggers proposal
3. **Discovery scan**: 80% files use pattern → extracted as suggestion
4. **Conflict detection**: New vs existing guideline → flagged for review
5. **Multi-signal**: Input matches correction AND preference → both logged

## Related Documents
- [Issue 040](./040-dynamic-claudemd-revision-system.md) - Parent issue
- [CLAUDE.md](~/.claude/CLAUDE.md) - Target document structure

## Notes
- Start with simple regex-based signal detection; upgrade to semantic analysis later
- Event IDs should be globally unique across all sessions
- Consider privacy: some events may contain sensitive project data
