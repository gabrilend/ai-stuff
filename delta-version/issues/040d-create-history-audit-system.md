# Issue 040d: Create History and Audit Trail System

## Status
- **Parent Issue**: 040 (Dynamic CLAUDE.md Revision System)
- **Priority**: High (Foundation)
- **Type**: Implementation
- **Dependencies**: 040a (Event Taxonomy)
- **Blocks**: 040c (Revision Engine), 040e (Validation System)

## Current Behavior
There is no record of how CLAUDE.md has evolved over time. Changes are made directly to the file with no trace of:
- What was changed
- When it was changed
- Why it was changed
- Who/what initiated the change

## Intended Behavior
Create an immutable audit trail system that tracks:
1. Every revision to CLAUDE.md (insertions, updates, deprecations)
2. Every event that triggered a proposal (corrections, discoveries, etc.)
3. The complete decision chain (event → proposal → review → revision)
4. Full rollback capability to any historical state

## Core Principle: Append-Only History

Following the project's principle that tickets "may be added to, but never deleted," the history system is strictly append-only. Even rollbacks create new history entries rather than erasing existing ones.

## Data Structures

### Event Record

```lua
-- Events are triggers that may lead to proposals
local Event = {
    id = "evt_20251229_143052_a7f3",  -- Timestamp + random suffix
    timestamp = 1735480252,
    type = "correction",  -- correction|repetition|discovery|preference|script|conflict|deprecation

    -- Source context
    session_id = "sess_abc123",
    project = "delta-version",
    source = "user",  -- user|script|system

    -- Content
    raw_input = "No, always use tabs not spaces",
    extracted_guideline = "Use tabs for indentation",
    confidence = 0.85,

    -- Detection metadata
    signals = {"correction_phrase", "emphasis_always"},

    -- Outcome
    outcome = "proposal_created",  -- proposal_created|merged|ignored|insufficient_confidence
    proposal_id = "prop_20251229_143100_b2e1"  -- If proposal was created
}
```

### Proposal Record

```lua
-- Proposals are pending changes awaiting review
local Proposal = {
    id = "prop_20251229_143100_b2e1",
    created = 1735480260,

    -- Content
    content = "Use tabs for indentation in all files",
    category = "coding_conventions",
    confidence = "suggested",  -- suggested|experimental|established

    -- Source chain
    source_events = {"evt_20251229_143052_a7f3"},
    source_type = "correction",
    source_attribution = "user",
    reasoning = "User explicitly corrected spacing preference",

    -- Review state
    status = "pending",  -- pending|approved|rejected|superseded|expired
    reviewed_at = nil,
    reviewed_by = nil,
    review_notes = nil,

    -- If approved, links to revision
    revision_id = nil
}
```

### Revision Record

```lua
-- Revisions are applied changes to CLAUDE.md
local Revision = {
    id = "rev_20251229_143200_c9d4",
    timestamp = 1735480320,

    -- Operation details
    type = "insert",  -- insert|update|deprecate|rollback

    -- Content (before/after for updates)
    content = "- Use tabs for indentation in all files",
    old_content = nil,  -- For updates

    -- Location
    section = "coding_conventions",
    line_number = 15,
    guideline_id = "g048",

    -- Source chain
    proposal_id = "prop_20251229_143100_b2e1",
    approved_by = "user",

    -- Backup reference
    backup_file = "CLAUDE.md.20251229_143159",
    checksum_before = "a7f3b2e1...",
    checksum_after = "c9d4e5f6..."
}
```

### Rollback Record

```lua
-- Rollbacks are special revisions that restore previous state
local Rollback = {
    id = "rev_20251229_150000_roll",
    timestamp = 1735482000,
    type = "rollback",

    -- Rollback specifics
    target_revision = "rev_20251228_120000_x1y2",  -- State restored to
    rolled_back_revisions = {  -- Revisions undone
        "rev_20251229_143200_c9d4",
        "rev_20251229_140000_a1b2"
    },

    -- Reason
    reason = "New indentation rule caused parser failures",
    initiated_by = "user",

    backup_file = "CLAUDE.md.20251229_145959"
}
```

## Storage Architecture

```
~/.claude/
├── CLAUDE.md                    # Live document
│
├── history/
│   ├── events.log              # Append-only event log (JSON-lines)
│   ├── proposals.log           # Append-only proposal log
│   ├── revisions.log           # Append-only revision log
│   ├── index.sqlite            # Optional: indexed queries
│   └── checkpoints/
│       ├── checkpoint_001.json # Periodic state snapshots
│       └── checkpoint_002.json
│
├── backups/
│   ├── CLAUDE.md.20251229_143159
│   ├── CLAUDE.md.20251229_140000
│   └── ...
│
└── proposals/
    └── pending/                # Active proposals awaiting review
        ├── prop_001.json
        └── prop_002.json
```

## Log File Formats

### events.log (JSON-lines)

```
{"id":"evt_001","timestamp":1735480000,"type":"correction","raw_input":"Use tabs","extracted_guideline":"Use tabs for indentation","source":"user","outcome":"proposal_created","proposal_id":"prop_001"}
{"id":"evt_002","timestamp":1735480060,"type":"discovery","raw_input":null,"extracted_guideline":"Files use 2-space indent","source":"scan","confidence":0.82,"outcome":"insufficient_confidence"}
```

### revisions.log (JSON-lines)

```
{"id":"rev_001","timestamp":1735480320,"type":"insert","content":"- Use tabs for indentation","section":"coding_conventions","line_number":15,"proposal_id":"prop_001","backup_file":"CLAUDE.md.20251229_143159"}
{"id":"rev_002","timestamp":1735482000,"type":"rollback","target_revision":"rev_001","rolled_back_revisions":[],"reason":"Testing rollback","backup_file":"CLAUDE.md.20251229_150000"}
```

## Query Interface

```lua
-- {{{ history module
local history = {}

-- {{{ function history.get_events
-- Get events with optional filtering
function history.get_events(opts)
    opts = opts or {}
    local events = read_log("events.log")

    -- Apply filters
    if opts.type then
        events = filter(events, function(e) return e.type == opts.type end)
    end
    if opts.since then
        events = filter(events, function(e) return e.timestamp >= opts.since end)
    end
    if opts.source then
        events = filter(events, function(e) return e.source == opts.source end)
    end

    return events
end
-- }}}

-- {{{ function history.get_revisions
-- Get revisions with optional filtering
function history.get_revisions(opts)
    opts = opts or {}
    local revisions = read_log("revisions.log")

    if opts.guideline_id then
        revisions = filter(revisions, function(r)
            return r.guideline_id == opts.guideline_id
        end)
    end
    if opts.type then
        revisions = filter(revisions, function(r) return r.type == opts.type end)
    end

    return revisions
end
-- }}}

-- {{{ function history.get_guideline_history
-- Get complete history for a specific guideline
function history.get_guideline_history(guideline_id)
    local revisions = history.get_revisions({guideline_id = guideline_id})
    local result = {}

    for _, rev in ipairs(revisions) do
        -- Get associated proposal
        local proposal = history.get_proposal(rev.proposal_id)
        -- Get associated events
        local events = {}
        if proposal then
            for _, evt_id in ipairs(proposal.source_events or {}) do
                table.insert(events, history.get_event(evt_id))
            end
        end

        table.insert(result, {
            revision = rev,
            proposal = proposal,
            events = events
        })
    end

    return result
end
-- }}}

-- {{{ function history.find_state_at
-- Reconstruct CLAUDE.md state at a given point
function history.find_state_at(timestamp_or_revision)
    local target_rev
    if type(timestamp_or_revision) == "number" then
        -- Find last revision before timestamp
        local revisions = history.get_revisions()
        for i = #revisions, 1, -1 do
            if revisions[i].timestamp <= timestamp_or_revision then
                target_rev = revisions[i]
                break
            end
        end
    else
        target_rev = history.get_revision(timestamp_or_revision)
    end

    if target_rev and target_rev.backup_file then
        return read_backup(target_rev.backup_file)
    end

    return nil, "No state found for target"
end
-- }}}

return history
-- }}}
```

## Audit Reports

### Guideline Provenance Report

```lua
-- Generate report showing how a guideline came to exist
function generate_provenance_report(guideline_id)
    local history = get_guideline_history(guideline_id)

    local report = {
        guideline_id = guideline_id,
        current_content = get_current_content(guideline_id),

        origin = history[1],  -- First revision
        modifications = #history - 1,

        source_events = {},
        timeline = {}
    }

    for _, entry in ipairs(history) do
        table.insert(report.timeline, {
            date = os.date("%Y-%m-%d %H:%M", entry.revision.timestamp),
            action = entry.revision.type,
            triggered_by = entry.events[1] and entry.events[1].type or "direct",
            content = entry.revision.content
        })
    end

    return report
end
```

### Activity Summary Report

```lua
-- Generate summary of system activity over time period
function generate_activity_report(since, until_)
    return {
        period = {from = since, to = until_},

        events = {
            total = count_events(since, until_),
            by_type = count_events_by_type(since, until_),
            by_source = count_events_by_source(since, until_)
        },

        proposals = {
            created = count_proposals_created(since, until_),
            approved = count_proposals_approved(since, until_),
            rejected = count_proposals_rejected(since, until_),
            pending = count_proposals_pending()
        },

        revisions = {
            total = count_revisions(since, until_),
            inserts = count_revisions_by_type("insert", since, until_),
            updates = count_revisions_by_type("update", since, until_),
            rollbacks = count_revisions_by_type("rollback", since, until_)
        }
    }
end
```

## Suggested Implementation Steps

1. **Define schema files** (`src/schema/`)
   - `event.lua` - Event record structure and validation
   - `proposal.lua` - Proposal record structure
   - `revision.lua` - Revision record structure

2. **Implement log writers** (`src/logs/`)
   - `append_event()` - Write to events.log
   - `append_proposal()` - Write to proposals.log
   - `append_revision()` - Write to revisions.log

3. **Build log readers** (`src/logs/`)
   - `read_log()` - Parse JSON-lines files
   - `filter_log()` - Apply query filters
   - `paginate_log()` - Handle large logs

4. **Create query interface** (`src/history.lua`)
   - Event queries with filtering
   - Revision queries with filtering
   - Guideline history reconstruction

5. **Implement state reconstruction** (`src/state.lua`)
   - Find state at timestamp
   - Apply revision sequence
   - Validate state integrity

6. **Build report generators** (`src/reports/`)
   - Provenance reports
   - Activity summaries
   - Conflict analysis

7. **Add backup rotation** (`src/backups.lua`)
   - Create backup on each revision
   - Rotate old backups (keep last 100)
   - Checkpoint creation for fast restoration

## Integrity Checks

1. **Log integrity**: Verify JSON-lines are parseable
2. **Chain integrity**: Every revision links to valid proposal
3. **Backup integrity**: Checksums match recorded values
4. **Timeline integrity**: Timestamps are monotonically increasing
5. **State integrity**: Reconstructed state matches backup

## Related Documents
- [Issue 040](./040-dynamic-claudemd-revision-system.md) - Parent issue
- [Issue 040a](./040a-design-event-taxonomy.md) - Event types logged here
- [Issue 035](./035-project-history-reconstruction.md) - Similar history philosophy

## Notes
- JSON-lines format allows append-only writes with easy parsing
- Checkpoints reduce reconstruction time for old states
- Consider compression for old logs (gzip JSON-lines)
- Backup rotation prevents unbounded storage growth
