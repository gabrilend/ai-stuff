# Issue 040i: Continual Co-operation Bridge

## Status
- **Parent Issue**: 040 (Dynamic CLAUDE.md Revision System)
- **Priority**: Medium
- **Type**: Integration
- **Dependencies**: 040g (Transcript Analysis), 040h (Worldbuilding Oracle)
- **Blocks**: None
- **Related Project**: continual-co-operation

## Current Behavior
The delta-version analysis systems (040g, 040h) produce reasoning chains and worldbuilding analysis, but this output remains siloed. The continual-co-operation project has a rolling memory system that could benefit from this analysis, but there's no bridge.

## Intended Behavior
Create a bidirectional bridge between:
- **delta-version**: Provides reasoning analysis, decision provenance, worldbuilding coherence
- **continual-co-operation**: Provides rolling memory, keyword similarity, always-writable context

## Key Block Format

Data flows between projects using embedded key blocks:

```lua
[BLOCK_NAME]
"path/to/referenced/data"
-- comments explaining the block
content here
[/BLOCK_NAME]
```

This format treats **code as data** and **source as queryable**.

## Bridge Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     delta-version                               │
│                                                                 │
│   040g: Reasoning Memory    040h: Worldbuilding Oracle         │
│   ├── decisions/            ├── elentalus/                     │
│   ├── reasoning_chains/     ├── design_philosophy.md           │
│   └── reconciliations/      └── coherence_checks/              │
│                                                                 │
│   [ANALYSIS_OUTPUT]                                             │
│   "continual-co-operation/src/rolling-memory.lua"              │
│   -- Exports: decision records, reasoning traces               │
│   [/ANALYSIS_OUTPUT]                                            │
│                                                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                    KEY BLOCK BRIDGE
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│                  continual-co-operation                         │
│                                                                 │
│   rolling-memory.lua        source-registry.lua                │
│   ├── context_window        ├── registered sources             │
│   ├── important_memories    ├── keyword index                  │
│   └── think_twice           └── similarity scoring             │
│                                                                 │
│   [DELTA_VERSION_INTEGRATION]                                   │
│   "delta-version/issues/040g-transcript-analysis-memory.md"   │
│   -- Imports: reasoning for context injection                  │
│   [/DELTA_VERSION_INTEGRATION]                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow: Delta → Continual

### Export Analysis for Rolling Memory

```lua
-- In delta-version/src/reasoning_memory.lua

[EXPORT_TO_ROLLING_MEMORY]
"continual-co-operation/src/rolling-memory.lua"
-- Formats analysis for injection into rolling memory context
[/EXPORT_TO_ROLLING_MEMORY]

-- {{{ function export_for_rolling_memory
function reasoning_memory.export_for_rolling_memory(guideline_id)
    local trace = reasoning_memory.trace(guideline_id)

    -- Format for continual-co-operation's memory schema
    return {
        text = format_reasoning_summary(trace),
        importance = trace.decision_record.confidence * 20,
        source = "[REASONING:" .. guideline_id .. "]",
        timestamp = os.time(),

        -- Key block metadata
        _block = "REASONING_EXPORT",
        _paths = {
            trace.decision_record.file,
            trace.reasoning_chain.file
        }
    }
end
-- }}}
```

### Export Worldbuilding Context

```lua
-- In delta-version/src/worldbuilding_oracle.lua

[EXPORT_TO_CONTEXT_INJECTION]
"continual-co-operation/issues/phase-1/006-keyword-similarity-context-injection.md"
-- Provides worldbuilding context as registered data source
[/EXPORT_TO_CONTEXT_INJECTION]

-- {{{ function export_elentalus_context
function worldbuilding.export_elentalus_context(query)
    local result = worldbuilding.lore(query)

    return {
        type = "worldbuilding",
        keywords = result.matched_keywords,
        content = result.lore_text,
        paths = result.source_files,

        -- Key block for tracking
        _block = "WORLDBUILDING_EXPORT",
        _query = query
    }
end
-- }}}
```

## Data Flow: Continual → Delta

### Import Memory Insights for Analysis

```lua
-- In delta-version/src/transcript_scanner.lua

[IMPORT_FROM_ROLLING_MEMORY]
"continual-co-operation/src/rolling-memory.lua"
-- Important memories may contain decision moments
[/IMPORT_FROM_ROLLING_MEMORY]

-- {{{ function import_important_memories
function scanner.import_important_memories(session_file)
    local bridge = require("data-bridge")
    local memories = bridge.read_memory_state(session_file)

    local potential_decisions = {}

    for _, memory in ipairs(memories.important_memories) do
        -- Check if this memory contains decision signals
        if contains_decision_signals(memory.text) then
            table.insert(potential_decisions, {
                text = memory.text,
                timestamp = memory.timestamp,
                importance = memory.importance,
                source = "rolling_memory",
                needs_analysis = true
            })
        end
    end

    return potential_decisions
end
-- }}}
```

## Shared Key Blocks

Both projects recognize these standard blocks:

| Block Name | Purpose | Direction |
|------------|---------|-----------|
| `[PROJECT_CONTEXT]` | Links to related issues | Both |
| `[DATA_SOURCE_REFERENCE]` | Paths for context injection | Continual → Delta |
| `[REASONING]` | Why code/data exists | Delta → Continual |
| `[WORLDBUILDING]` | Elentalus/creative refs | Delta → Continual |
| `[COPIED_FROM]` | Provenance when copied | Both |
| `[SCHEMA]` | Data structure definitions | Both |

## Synchronization Protocol

```lua
-- {{{ bridge_sync module

local sync = {}

[SYNC_CONFIG]
"continual-co-operation/config/bridge-sources.lua"
-- Sync interval and project mappings
local SYNC_INTERVAL = 3600  -- 1 hour
local PROJECTS = {
    delta = "/mnt/mtwo/programming/ai-stuff/delta-version/",
    continual = "/mnt/mtwo/programming/ai-stuff/continual-co-operation/"
}
[/SYNC_CONFIG]

-- {{{ function sync.delta_to_continual
function sync.delta_to_continual()
    -- 1. Export new analysis from delta-version
    local new_analysis = get_analysis_since_last_sync()

    -- 2. Format as key blocks
    local blocks = format_as_key_blocks(new_analysis)

    -- 3. Register as data sources in continual-co-operation
    for _, block in ipairs(blocks) do
        register_analysis_source(block)
    end

    -- 4. Update sync timestamp
    update_sync_timestamp("delta_to_continual")
end
-- }}}

-- {{{ function sync.continual_to_delta
function sync.continual_to_delta()
    -- 1. Export important memories that might be decision moments
    local memories = get_important_memories_since_last_sync()

    -- 2. Check for decision signals
    local potential_decisions = filter_decision_signals(memories)

    -- 3. Queue for analysis in delta-version
    queue_for_transcript_analysis(potential_decisions)

    -- 4. Update sync timestamp
    update_sync_timestamp("continual_to_delta")
end
-- }}}

return sync
-- }}}
```

## Suggested Implementation Steps

1. **Add bridge exports to 040g** (`src/reasoning_memory.lua`)
   - `export_for_rolling_memory()` function
   - Key block annotations

2. **Add bridge exports to 040h** (`src/worldbuilding_oracle.lua`)
   - `export_elentalus_context()` function
   - Key block annotations

3. **Add bridge imports to transcript scanner** (`src/transcript_scanner.lua`)
   - `import_important_memories()` function
   - Decision signal detection from external memories

4. **Create sync module** (`src/bridge_sync.lua`)
   - Bidirectional sync functions
   - Timestamp tracking
   - Conflict handling

5. **Update documentation**
   - Add key block reference to both projects
   - Document sync protocol

## Example: Full Bridge Flow

```
1. User asks continual-co-operation: "Why do we use vimfolds?"

2. Keyword extraction: ["vimfolds", "use", "why"]

3. Similarity check finds:
   - delta-version analysis: decisions/dec_g002_vimfold.md (0.89 match)
   - continual-co-operation memory: "vimfolds for collapsing" (0.72 match)

4. Bridge pulls delta-version analysis:
   [REASONING]
   "delta-version/analysis/decisions/dec_g002_vimfold.md"
   -- User was navigating 40+ function file
   -- Suggested folding, refined to vimfold syntax
   -- Scope: all functions
   [/REASONING]

5. Injected into context before LLM call

6. Response synthesizes both sources

7. If response contains new insight, think-twice may persist it

8. Next sync: persistent insight queued for delta-version analysis
```

## Related Documents
- [040-dynamic-claudemd-revision-system](./040-dynamic-claudemd-revision-system.md) - Parent issue
- [040g-transcript-analysis-memory](./040g-transcript-analysis-memory.md) - Reasoning source
- [040h-worldbuilding-design-oracle](./040h-worldbuilding-design-oracle.md) - Worldbuilding source
- [continual-co-operation/007](../../../continual-co-operation/issues/phase-1/007-cross-project-data-bridge.md) - Bridge partner

## Notes
- Key blocks must not break code execution (use comments or strings)
- Sync should be idempotent (re-running produces same result)
- Consider: real-time bridge via shared socket vs periodic batch sync
- The bridge embodies "code is data, source is queryable"
