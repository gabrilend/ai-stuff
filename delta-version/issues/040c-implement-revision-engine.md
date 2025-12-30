# Issue 040c: Implement Revision Engine with Rollback Support

## Status
- **Parent Issue**: 040 (Dynamic CLAUDE.md Revision System)
- **Priority**: High
- **Type**: Implementation
- **Dependencies**: 040a (Event Taxonomy), 040d (History System)
- **Blocks**: 040f (Interactive Interface)

## Current Behavior
CLAUDE.md modifications require direct text editing. There is no structured way to:
- Insert guidelines into appropriate sections
- Update existing guidelines while preserving context
- Roll back changes that cause problems
- Track the relationship between guidelines

## Intended Behavior
Create a revision engine that:
1. Parses CLAUDE.md into structured sections
2. Inserts new guidelines in semantically appropriate locations
3. Updates or deprecates existing guidelines
4. Maintains full rollback capability
5. Preserves formatting and readability

## CLAUDE.md Structure Model

### Section Detection

The engine parses CLAUDE.md into logical sections based on content patterns:

```lua
-- Detected section structure
local sections = {
    {
        id = "coding_conventions",
        type = "list",
        keywords = {"script", "function", "variable", "syntax"},
        line_start = 1,
        line_end = 17,
        guidelines = {
            {id = "g001", line = 1, content = "all scripts should be written..."},
            {id = "g002", line = 2, content = "all functions should use vimfolds..."},
            -- ...
        }
    },
    {
        id = "project_structure",
        type = "list",
        keywords = {"project", "mkdir", "directory", "issues"},
        line_start = 18,
        line_end = 25,
        guidelines = {...}
    },
    {
        id = "philosophy",
        type = "prose",
        keywords = {"think", "design", "interest", "principle"},
        line_start = 45,
        line_end = 56,
        guidelines = {...}
    }
}
```

### Section Categories

| Category | Keywords | Insertion Style |
|----------|----------|-----------------|
| `coding_conventions` | script, function, syntax, variable | List item (- prefix) |
| `project_structure` | project, directory, mkdir, issues | List item |
| `workflow` | commit, issue, phase, complete | List item |
| `philosophy` | think, design, interest, principle | Prose (paragraph) |
| `tools` | library, libs, script, utility | List item |
| `formatting` | comment, indent, space, style | List item |
| `uncategorized` | (fallback) | Append to end |

## Revision Operations

### 1. INSERT - Add new guideline

```lua
-- Insert a new guideline
revision_engine.insert({
    content = "prefer dispatch tables over switch statements",
    category = "coding_conventions",
    after = "g042",  -- Optional: specific position
    source = "user",
    proposal_id = "prop_001"
})
```

**Algorithm**:
1. Parse CLAUDE.md into sections
2. Determine target section from category or content analysis
3. Find insertion point (end of section, or after specific guideline)
4. Insert with appropriate formatting (list item vs prose)
5. Update line numbers for subsequent sections
6. Write to backup, then to live file
7. Log revision to history

### 2. UPDATE - Modify existing guideline

```lua
-- Update an existing guideline
revision_engine.update({
    target = "g015",  -- Guideline ID
    content = "use 2-space indentation for Lua files",  -- New content
    preserve_original = true,  -- Keep as comment
    source = "discovery_event",
    proposal_id = "prop_002"
})
```

**Algorithm**:
1. Find target guideline by ID
2. If `preserve_original`: convert old to comment
3. Insert new content at same position
4. Log both old and new in revision history

### 3. DEPRECATE - Mark guideline as obsolete

```lua
-- Deprecate a guideline
revision_engine.deprecate({
    target = "g007",
    reason = "No longer applicable after project restructure",
    source = "user",
    replacement = "g045"  -- Optional: successor guideline
})
```

**Algorithm**:
1. Find target guideline
2. Add deprecation marker: `[DEPRECATED: <reason>]`
3. Optionally add reference to replacement
4. Log deprecation in history

### 4. ROLLBACK - Revert to previous state

```lua
-- Rollback to specific revision
revision_engine.rollback({
    to_revision = "rev_20251229_001",
    -- OR
    steps = 3  -- Go back 3 revisions
})
```

**Algorithm**:
1. Load revision history
2. Find target revision state
3. Create backup of current state
4. Restore from target revision
5. Log rollback as new revision (preserves forward history)

## Storage Format

### Backup System

```
~/.claude/
├── CLAUDE.md                    # Live file
├── backups/
│   ├── CLAUDE.md.20251229_120000  # Timestamped backups
│   ├── CLAUDE.md.20251229_113000
│   └── ...
└── history/
    └── revisions.log            # Revision history
```

### Revision Log Format

```json
{"id":"rev_001","timestamp":1735432800,"type":"insert","target":null,"content":"new guideline...","section":"coding_conventions","source":"user","proposal_id":"prop_001","backup_file":"CLAUDE.md.20251229_120000"}
{"id":"rev_002","timestamp":1735432860,"type":"update","target":"g015","old_content":"use tabs","content":"use 2 spaces","section":"coding_conventions","source":"discovery","proposal_id":"prop_002","backup_file":"CLAUDE.md.20251229_120100"}
```

## Parser Implementation

### Guideline Extraction

```lua
-- {{{ function parse_claudemd
function parse_claudemd(filepath)
    local content = read_file(filepath)
    local lines = split_lines(content)
    local sections = {}
    local current_section = nil
    local guideline_id = 0

    for i, line in ipairs(lines) do
        -- Detect section boundaries
        local section_type = detect_section_type(line, lines, i)

        if section_type then
            if current_section then
                current_section.line_end = i - 1
                table.insert(sections, current_section)
            end
            current_section = {
                type = section_type,
                line_start = i,
                guidelines = {}
            }
        end

        -- Extract guidelines
        if is_guideline_line(line) then
            guideline_id = guideline_id + 1
            table.insert(current_section.guidelines, {
                id = "g" .. string.format("%03d", guideline_id),
                line = i,
                content = extract_guideline_content(line)
            })
        end
    end

    -- Close final section
    if current_section then
        current_section.line_end = #lines
        table.insert(sections, current_section)
    end

    return sections
end
-- }}}
```

### Guideline Detection

```lua
-- {{{ function is_guideline_line
function is_guideline_line(line)
    -- List items
    if line:match("^%s*%- ") then return true end

    -- Standalone statements (not comments, not blank)
    if line:match("^[^#\n]") and #line > 20 then
        -- Contains imperative verb
        if line:match("should") or line:match("must") or
           line:match("prefer") or line:match("always") or
           line:match("never") or line:match("ensure") then
            return true
        end
    end

    return false
end
-- }}}
```

## Section-Aware Insertion

```lua
-- {{{ function insert_guideline
function insert_guideline(sections, new_guideline, category)
    -- Find target section
    local target_section = nil
    for _, section in ipairs(sections) do
        if section.category == category then
            target_section = section
            break
        end
    end

    -- Fallback to uncategorized (append to end)
    if not target_section then
        target_section = sections[#sections]
    end

    -- Determine formatting based on section type
    local formatted_content
    if target_section.type == "list" then
        formatted_content = "- " .. new_guideline.content
    else
        formatted_content = new_guideline.content
    end

    -- Insert at end of section
    local insert_line = target_section.line_end

    return {
        line = insert_line,
        content = formatted_content,
        section = target_section.id
    }
end
-- }}}
```

## Suggested Implementation Steps

1. **Build CLAUDE.md parser** (`src/parser.lua`)
   - Line-by-line parsing
   - Section boundary detection
   - Guideline extraction with IDs

2. **Implement section categorizer** (`src/categorizer.lua`)
   - Keyword-based section identification
   - Content analysis for new guidelines

3. **Create revision operations** (`src/revisions.lua`)
   - INSERT operation with section awareness
   - UPDATE operation with preservation option
   - DEPRECATE operation with markers
   - ROLLBACK operation with history traversal

4. **Build backup manager** (`src/backups.lua`)
   - Timestamped backup creation
   - Backup rotation (keep last N)
   - Backup restoration

5. **Implement revision logger** (`src/history.lua`)
   - JSON-lines append-only log
   - Query interface for history
   - Revision chain tracking

6. **Integration tests**
   - Parse → modify → write round-trip
   - Rollback to arbitrary point
   - Concurrent modification handling

## Edge Cases

1. **Empty sections**: Insert creates section header
2. **Conflicting insertions**: Queue and process sequentially
3. **Malformed CLAUDE.md**: Preserve original, report error
4. **Large files**: Stream processing for memory efficiency
5. **Unicode content**: UTF-8 aware line handling

## Related Documents
- [Issue 040](./040-dynamic-claudemd-revision-system.md) - Parent issue
- [Issue 040d](./040d-create-history-audit-system.md) - History storage this uses

## Notes
- Always create backup before any modification
- Preserve original formatting where possible
- Guideline IDs are stable across revisions (don't renumber)
- Consider future: section headers, nested structure
