# Issue 007: Cross-Project Data Bridge with Key Blocks

## Status
- **Phase**: 1
- **Priority**: High
- **Type**: Feature (Integration)
- **Dependencies**: 006 (keyword-similarity-context-injection)
- **Blocks**: Integration with delta-version/040 series
- **Related Projects**: delta-version, elentalus

## Current Behavior
Data exists in silos:
- `continual-co-operation` has rolling memory and source registry
- `delta-version/040` has reasoning analysis and worldbuilding oracle
- No mechanism to copy data between them with embedded metadata

## Intended Behavior
Create a data format and parser that:

1. Uses **key blocks** `[like this]` as section/data markers
2. Embeds **comment-strings** `"path/to/data"` as location references
3. Allows **intermittent mixing** of code, comments, and data
4. Treats **source as data** - parseable and queryable
5. Enables **cross-project copying** with metadata preservation

## The Key Block Format

### Syntax

```
[BLOCK_NAME]
"optional/path/reference"
-- comment explaining the block
actual data or code here
which can span multiple lines
[/BLOCK_NAME]
```

### Example: Source File with Embedded Data

```lua
-- rolling-memory.lua
-- "continual-co-operation/src/rolling-memory.lua"

[PROJECT_CONTEXT]
"delta-version/issues/040-dynamic-claudemd-revision-system.md"
-- This module connects to the dynamic CLAUDE.md revision system
-- for guideline-aware context building
[/PROJECT_CONTEXT]

local M = {}

[IMPORTANT_MEMORY_SCHEMA]
-- Schema for memories that survive the think-twice mechanism
-- "continual-co-operation/schemas/memory.json"
local memory_schema = {
    text = "string",           -- The remembered content
    timestamp = "number",      -- When it was remembered
    importance = "number",     -- Calculated importance score
    remember_count = "number", -- How many times thought about
    source = "string|nil"      -- Optional: where it came from
}
[/IMPORTANT_MEMORY_SCHEMA]

[DATA_SOURCE_REFERENCE]
"~/.claude/CLAUDE.md"
"delta-version/issues/040g-transcript-analysis-memory.md"
"/home/ritz/.dominions6/mods/elentalus-0.96/elentalus/lore/"
-- These paths are queryable data sources for context injection
[/DATA_SOURCE_REFERENCE]

-- {{{ function M.create_session
function M.create_session(memory_file)
    [SESSION_CONFIG]
    -- Default configuration copied from delta-version conventions
    "delta-version/issues/CLAUDE.md"
    local defaults = {
        max_context_size = 4000,
        importance_threshold = 15,
        think_twice_count = 2
    }
    [/SESSION_CONFIG]

    -- ... rest of function
end
-- }}}
```

## Parser Implementation

```lua
-- {{{ key_block_parser module
-- Parses source files for [KEY_BLOCKS] and "path/references"
-- Treats code as data, source as queryable

local parser = {}

[BLOCK_PATTERN]
-- Regex patterns for block detection
local BLOCK_START = "%[([%w_]+)%]"
local BLOCK_END = "%[/([%w_]+)%]"
local PATH_REF = '"([^"]+)"'
local COMMENT = "%-%-(.+)"
[/BLOCK_PATTERN]

-- {{{ function parser.extract_blocks
function parser.extract_blocks(filepath)
    local file = io.open(filepath, "r")
    if not file then return nil, "Cannot open file" end

    local content = file:read("*all")
    file:close()

    local blocks = {}
    local current_block = nil
    local line_num = 0

    for line in content:gmatch("[^\n]+") do
        line_num = line_num + 1

        -- Check for block start
        local block_name = line:match(BLOCK_START)
        if block_name and not line:match(BLOCK_END) then
            current_block = {
                name = block_name,
                start_line = line_num,
                paths = {},
                comments = {},
                content = {},
                raw = {}
            }

        -- Check for block end
        elseif current_block and line:match("%[/" .. current_block.name .. "%]") then
            current_block.end_line = line_num
            blocks[current_block.name] = current_block
            current_block = nil

        -- Inside a block
        elseif current_block then
            table.insert(current_block.raw, line)

            -- Extract path references
            local path = line:match(PATH_REF)
            if path then
                table.insert(current_block.paths, path)
            end

            -- Extract comments
            local comment = line:match(COMMENT)
            if comment then
                table.insert(current_block.comments, comment:gsub("^%s+", ""))
            end

            -- Non-comment, non-path content
            if not path and not comment then
                table.insert(current_block.content, line)
            end
        end
    end

    return blocks
end
-- }}}

-- {{{ function parser.extract_all_paths
-- Get all path references from a file
function parser.extract_all_paths(filepath)
    local blocks = parser.extract_blocks(filepath)
    local paths = {}

    for block_name, block in pairs(blocks) do
        for _, path in ipairs(block.paths) do
            table.insert(paths, {
                path = path,
                block = block_name,
                source_file = filepath
            })
        end
    end

    return paths
end
-- }}}

-- {{{ function parser.find_blocks_by_name
-- Search across multiple files for blocks with a given name
function parser.find_blocks_by_name(block_name, search_paths)
    local results = {}

    for _, search_path in ipairs(search_paths) do
        local files = find_lua_files(search_path)
        for _, filepath in ipairs(files) do
            local blocks = parser.extract_blocks(filepath)
            if blocks[block_name] then
                table.insert(results, {
                    file = filepath,
                    block = blocks[block_name]
                })
            end
        end
    end

    return results
end
-- }}}

return parser
-- }}}
```

## Cross-Project Data Copier

```lua
-- {{{ data_bridge module
-- Copies data between projects using key blocks as markers

local bridge = {}
local parser = require("key-block-parser")

[BRIDGE_CONFIG]
"continual-co-operation/config/bridge-sources.lua"
-- Projects that can share data
local CONNECTED_PROJECTS = {
    ["continual-co-operation"] = "/mnt/mtwo/programming/ai-stuff/continual-co-operation/",
    ["delta-version"] = "/mnt/mtwo/programming/ai-stuff/delta-version/",
    ["elentalus"] = "/home/ritz/.dominions6/mods/elentalus-0.96/"
}
[/BRIDGE_CONFIG]

-- {{{ function bridge.copy_block
-- Copy a block from one project to another
function bridge.copy_block(block_name, source_project, dest_project, dest_file)
    -- Find the block in source project
    local source_path = CONNECTED_PROJECTS[source_project]
    if not source_path then
        return nil, "Unknown source project: " .. source_project
    end

    local blocks = parser.find_blocks_by_name(block_name, {source_path})
    if #blocks == 0 then
        return nil, "Block not found: " .. block_name
    end

    local source_block = blocks[1]

    -- Format for destination
    local formatted = format_block_for_insert(source_block.block, {
        source_file = source_block.file,
        copy_timestamp = os.time()
    })

    -- Insert into destination (or return for manual insertion)
    return formatted, source_block
end
-- }}}

-- {{{ function bridge.sync_paths
-- Sync path references between projects
function bridge.sync_paths(source_project, dest_project)
    local source_path = CONNECTED_PROJECTS[source_project]
    local dest_path = CONNECTED_PROJECTS[dest_project]

    -- Find all DATA_SOURCE_REFERENCE blocks in source
    local refs = parser.find_blocks_by_name("DATA_SOURCE_REFERENCE", {source_path})

    -- Extract unique paths
    local all_paths = {}
    for _, ref in ipairs(refs) do
        for _, path in ipairs(ref.block.paths) do
            all_paths[path] = true
        end
    end

    return all_paths
end
-- }}}

-- {{{ function bridge.build_shared_context
-- Build context from all connected projects for a query
function bridge.build_shared_context(query_keywords)
    local context = {}

    for project_name, project_path in pairs(CONNECTED_PROJECTS) do
        -- Find relevant blocks based on keywords
        local all_blocks = scan_all_blocks(project_path)

        for block_name, block in pairs(all_blocks) do
            local relevance = calculate_keyword_relevance(
                query_keywords,
                block.comments,
                block.content
            )

            if relevance > 0.3 then
                table.insert(context, {
                    project = project_name,
                    block = block_name,
                    relevance = relevance,
                    paths = block.paths,
                    content = table.concat(block.content, "\n")
                })
            end
        end
    end

    -- Sort by relevance
    table.sort(context, function(a, b) return a.relevance > b.relevance end)

    return context
end
-- }}}

return bridge
-- }}}
```

## Standard Key Block Types

```
[PROJECT_CONTEXT]
-- Links this file to related projects/issues
"path/to/related/issue.md"
[/PROJECT_CONTEXT]

[DATA_SOURCE_REFERENCE]
-- Paths that can be queried for context
"~/.claude/CLAUDE.md"
"/path/to/data/source"
[/DATA_SOURCE_REFERENCE]

[SCHEMA]
-- Data structure definitions
field = "type"
[/SCHEMA]

[CONFIG]
-- Configuration values that can be synced
setting = value
[/CONFIG]

[COPIED_FROM]
-- Marks content copied from another project
"source/project/file.lua"
-- Original block: BLOCK_NAME
-- Copy timestamp: 2025-12-29 15:30:00
[/COPIED_FROM]

[REASONING]
-- Why this code/data exists
"delta-version/issues/040g-transcript-analysis-memory.md"
-- Decision was made because...
[/REASONING]

[WORLDBUILDING]
-- Elentalus and creative project references
"elentalus/lore/game-design-document"
-- Related to: altar system, elemental progression
[/WORLDBUILDING]
```

## Integration Example

### In continual-co-operation:

```lua
-- src/source-registry.lua

[DELTA_VERSION_INTEGRATION]
"delta-version/issues/040-dynamic-claudemd-revision-system.md"
"delta-version/issues/040g-transcript-analysis-memory.md"
"delta-version/issues/040h-worldbuilding-design-oracle.md"
-- These analysis systems provide:
-- - Guideline provenance (why does a rule exist)
-- - Transcript-based reasoning reconstruction
-- - Worldbuilding coherence checking for Elentalus
[/DELTA_VERSION_INTEGRATION]

function source_registry.import_delta_version_analysis()
    local bridge = require("data-bridge")

    -- Sync analysis paths from delta-version
    local analysis_paths = bridge.sync_paths("delta-version", "continual-co-operation")

    for path, _ in pairs(analysis_paths) do
        source_registry.register({
            path = path,
            type = "analysis",
            weight = 1.8  -- High relevance for reasoning questions
        })
    end
end
```

### In delta-version:

```lua
-- src/reasoning_memory.lua

[CONTINUAL_COOPERATION_BRIDGE]
"continual-co-operation/src/rolling-memory.lua"
"continual-co-operation/issues/phase-1/006-keyword-similarity-context-injection.md"
-- Memory system provides:
-- - Think-twice persistence for important insights
-- - Keyword similarity for finding relevant analysis
-- - Always-writable context injection
[/CONTINUAL_COOPERATION_BRIDGE]

function reasoning_memory.export_to_rolling_memory(insight)
    -- Format insight for continual-co-operation's memory system
    return {
        text = insight.summary,
        importance = insight.confidence * 20,
        source = "[REASONING:" .. insight.guideline_id .. "]",
        paths = insight.transcript_refs
    }
end
```

## CLI for Bridge Operations

```bash
#!/bin/bash
# data-bridge - cross-project data operations

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/continual-co-operation}"

case "$1" in
    copy)
        # Copy a block from one project to another
        # data-bridge copy BLOCK_NAME source_project dest_project
        lua "$DIR/src/data-bridge-cli.lua" copy "$2" "$3" "$4"
        ;;
    sync)
        # Sync path references between projects
        lua "$DIR/src/data-bridge-cli.lua" sync "$2" "$3"
        ;;
    find)
        # Find all blocks with a given name across projects
        lua "$DIR/src/data-bridge-cli.lua" find "$2"
        ;;
    paths)
        # List all path references in a project
        lua "$DIR/src/data-bridge-cli.lua" paths "$2"
        ;;
    context)
        # Build shared context for a query
        lua "$DIR/src/data-bridge-cli.lua" context "$2"
        ;;
    *)
        echo "Usage: data-bridge {copy|sync|find|paths|context} [args]"
        echo ""
        echo "Examples:"
        echo "  data-bridge find DATA_SOURCE_REFERENCE"
        echo "  data-bridge copy SCHEMA delta-version continual-co-operation"
        echo "  data-bridge context 'altar elemental progression'"
        ;;
esac
```

## Suggested Implementation Steps

1. **Create key block parser** (`src/key-block-parser.lua`)
   - Block start/end detection
   - Path reference extraction
   - Comment extraction
   - Content separation

2. **Implement data bridge** (`src/data-bridge.lua`)
   - Project registry
   - Block copying with metadata
   - Path synchronization

3. **Build shared context builder** (extend `src/similarity.lua`)
   - Cross-project block scanning
   - Keyword relevance scoring
   - Context assembly

4. **Create CLI wrapper** (`scripts/data-bridge`)
   - copy, sync, find, paths, context commands

5. **Add standard blocks to existing files**
   - rolling-memory.lua: PROJECT_CONTEXT, DATA_SOURCE_REFERENCE
   - delta-version files: CONTINUAL_COOPERATION_BRIDGE

6. **Integration tests**
   - Copy block from delta-version to continual-co-operation
   - Build context using blocks from both projects

## Philosophy

```
[DESIGN_PHILOSOPHY]
-- Code is data. Source is queryable.
-- Comments carry meaning beyond documentation.
-- Paths embedded in source become live references.
-- Key blocks are semantic markers in the code stream.
-- Cross-project copying preserves provenance.
-- The bridge treats all projects as one unified knowledge base.
[/DESIGN_PHILOSOPHY]
```

## Related Documents
- [006-keyword-similarity-context-injection](./006-keyword-similarity-context-injection.md) - Similarity engine
- [delta-version/040](../../delta-version/issues/040-dynamic-claudemd-revision-system.md) - Target integration
- [delta-version/040g](../../delta-version/issues/040g-transcript-analysis-memory.md) - Reasoning system
- [delta-version/040h](../../delta-version/issues/040h-worldbuilding-design-oracle.md) - Worldbuilding oracle

## Notes
- Key blocks should not interfere with code execution (inside comments or strings)
- Path references can be relative to project root or absolute
- The [COPIED_FROM] block preserves provenance when data moves between projects
- Consider: version tracking for blocks that evolve over time
