# Issue 006: Keyword Similarity Context Injection

## Status
- **Phase**: 1
- **Priority**: High
- **Type**: Feature
- **Dependencies**: 002 (rolling-context-window), 005 (memory-persistence)
- **Blocks**: LLM integration with custom data sources

## Current Behavior
The rolling memory system manages a context window with importance scoring, but:
- Context sources are limited to conversation history
- No mechanism to inject external data sources programmatically
- No keyword similarity matching to find relevant context automatically
- Cannot dynamically build context from reference materials

## Intended Behavior
Create a system that:

1. **Registers data sources** - projects, files, directories that can provide context
2. **Extracts keywords** from current conversation/prompt
3. **Scores relevance** using keyword similarity against registered sources
4. **Injects relevant context** automatically before LLM calls
5. **Always writable** - new sources can be added at any time

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     DATA SOURCE REGISTRY                        │
│  (Always writable - add sources at runtime)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   sources = {                                                   │
│     { path = "~/.claude/CLAUDE.md",                            │
│       type = "guidelines",                                      │
│       keywords = {"script", "function", "vimfold", ...}        │
│     },                                                          │
│     { path = "/home/ritz/.dominions6/mods/elentalus-0.96/",   │
│       type = "game_design",                                     │
│       keywords = {"elemental", "altar", "supermage", ...}      │
│     },                                                          │
│     { path = "{project}/issues/",                              │
│       type = "issues",                                          │
│       keywords = extracted_from_content                         │
│     }                                                           │
│   }                                                             │
│                                                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SIMILARITY ENGINE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   on_prompt(text):                                              │
│     1. Extract keywords from text                               │
│     2. For each registered source:                              │
│        - Calculate Jaccard similarity                           │
│        - Score = |keywords ∩ source_keywords| /                │
│                  |keywords ∪ source_keywords|                   │
│     3. Rank sources by similarity score                         │
│     4. Inject top-N sources into context                        │
│                                                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    AUTO-BUILT CONTEXT                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   context = {                                                   │
│     system_prompt,                                              │
│     important_memories,         # From think-twice              │
│     relevant_sources[],         # NEW: Similarity-matched       │
│     conversation_history        # Rolling window                │
│   }                                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Source Registration API

```lua
-- {{{ source_registry module
local source_registry = {}

local sources = {}
local index_cache = {}

-- {{{ function source_registry.register
-- Register a new data source (always writable)
function source_registry.register(source)
    local entry = {
        id = source.id or generate_id(),
        path = source.path,
        type = source.type or "generic",
        keywords = source.keywords or {},
        weight = source.weight or 1.0,
        extract_fn = source.extract_fn,  -- Optional: custom extraction
        last_indexed = nil
    }

    -- If no keywords provided, extract them
    if #entry.keywords == 0 and file_exists(entry.path) then
        entry.keywords = extract_keywords_from_path(entry.path)
    end

    table.insert(sources, entry)
    return entry.id
end
-- }}}

-- {{{ function source_registry.add_project
-- Convenience: register a project directory
function source_registry.add_project(project_path)
    -- Register issues
    source_registry.register({
        path = project_path .. "/issues/",
        type = "issues",
        weight = 1.5  -- Issues are highly relevant
    })

    -- Register notes
    source_registry.register({
        path = project_path .. "/notes/",
        type = "notes",
        weight = 1.2
    })

    -- Register docs
    source_registry.register({
        path = project_path .. "/docs/",
        type = "documentation",
        weight = 1.0
    })
end
-- }}}

-- {{{ function source_registry.add_elentalus
-- Convenience: register Elentalus mod
function source_registry.add_elentalus()
    source_registry.register({
        id = "elentalus-mod",
        path = "/home/ritz/.dominions6/mods/elentalus-0.96/",
        type = "game_design",
        keywords = {
            "elemental", "altar", "supermage", "urn", "dominions",
            "fire", "water", "earth", "air", "astral", "nature",
            "cavalry", "infantry", "sacred", "adventurer", "refugee"
        },
        weight = 1.5
    })

    source_registry.register({
        id = "elentalus-lore",
        path = "/home/ritz/.dominions6/mods/elentalus-0.96/elentalus/lore/",
        type = "lore",
        weight = 2.0  -- Lore is extra relevant for worldbuilding questions
    })
end
-- }}}

return source_registry
-- }}}
```

## Keyword Extraction

```lua
-- {{{ keyword_extractor module
local extractor = {}

-- Stopwords to ignore
local STOPWORDS = {
    "the", "a", "an", "is", "are", "was", "were", "be", "been",
    "being", "have", "has", "had", "do", "does", "did", "will",
    "would", "could", "should", "may", "might", "must", "shall",
    "can", "need", "dare", "ought", "used", "to", "of", "in",
    "for", "on", "with", "at", "by", "from", "as", "into", "through"
}

-- {{{ function extractor.from_text
function extractor.from_text(text)
    local keywords = {}
    local stopwords_set = {}
    for _, w in ipairs(STOPWORDS) do stopwords_set[w] = true end

    -- Tokenize and filter
    for word in text:lower():gmatch("%w+") do
        if #word > 3 and not stopwords_set[word] then
            keywords[word] = (keywords[word] or 0) + 1
        end
    end

    -- Sort by frequency
    local sorted = {}
    for word, count in pairs(keywords) do
        table.insert(sorted, {word = word, count = count})
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    -- Return top keywords
    local result = {}
    for i = 1, math.min(20, #sorted) do
        table.insert(result, sorted[i].word)
    end

    return result
end
-- }}}

-- {{{ function extractor.from_file
function extractor.from_file(filepath)
    local file = io.open(filepath, "r")
    if not file then return {} end

    local content = file:read("*all")
    file:close()

    return extractor.from_text(content)
end
-- }}}

-- {{{ function extractor.from_directory
function extractor.from_directory(dirpath)
    local keywords = {}

    -- Use find to get all text files
    local handle = io.popen("find " .. dirpath .. " -type f -name '*.md' -o -name '*.txt' -o -name '*.lua' 2>/dev/null")
    if handle then
        for filepath in handle:lines() do
            local file_keywords = extractor.from_file(filepath)
            for _, kw in ipairs(file_keywords) do
                keywords[kw] = (keywords[kw] or 0) + 1
            end
        end
        handle:close()
    end

    -- Convert to list
    local result = {}
    for word, _ in pairs(keywords) do
        table.insert(result, word)
    end

    return result
end
-- }}}

return extractor
-- }}}
```

## Similarity Scoring

```lua
-- {{{ similarity module
local similarity = {}

-- {{{ function similarity.jaccard
-- Jaccard similarity coefficient
function similarity.jaccard(set1, set2)
    local s1 = {}
    local s2 = {}

    for _, v in ipairs(set1) do s1[v] = true end
    for _, v in ipairs(set2) do s2[v] = true end

    local intersection = 0
    local union = {}

    for k, _ in pairs(s1) do
        union[k] = true
        if s2[k] then intersection = intersection + 1 end
    end

    for k, _ in pairs(s2) do
        union[k] = true
    end

    local union_size = 0
    for _, _ in pairs(union) do union_size = union_size + 1 end

    if union_size == 0 then return 0 end
    return intersection / union_size
end
-- }}}

-- {{{ function similarity.rank_sources
function similarity.rank_sources(prompt_keywords, sources)
    local ranked = {}

    for _, source in ipairs(sources) do
        local score = similarity.jaccard(prompt_keywords, source.keywords)
        score = score * (source.weight or 1.0)

        if score > 0.05 then  -- Threshold
            table.insert(ranked, {
                source = source,
                score = score
            })
        end
    end

    table.sort(ranked, function(a, b) return a.score > b.score end)

    return ranked
end
-- }}}

return similarity
-- }}}
```

## Integration with Rolling Memory

```lua
-- Extend rolling-memory.lua ask() function:

ask = function(self, prompt)
    add_to_context(self.memory_state, prompt, "user")

    local messages = {}

    -- 1. Build important memories context
    if #self.memory_state.important_memories > 0 then
        local important_context = "Important memories:\n"
        for i = math.max(1, #self.memory_state.important_memories - 5), #self.memory_state.important_memories do
            local memory = self.memory_state.important_memories[i]
            important_context = important_context .. "- " .. memory.text .. "\n"
        end

        table.insert(messages, {
            role = "system",
            content = important_context
        })
    end

    -- 2. NEW: Find and inject relevant data sources
    local prompt_keywords = keyword_extractor.from_text(prompt)
    local ranked_sources = similarity.rank_sources(prompt_keywords, source_registry.get_all())

    for i = 1, math.min(3, #ranked_sources) do  -- Top 3 sources
        local source = ranked_sources[i].source
        local content = source_registry.get_content(source, 500)  -- Max 500 chars

        table.insert(messages, {
            role = "system",
            content = string.format("[Reference: %s]\n%s", source.type, content)
        })
    end

    -- 3. Add conversation history
    for _, entry in ipairs(self.memory_state.context_window) do
        table.insert(messages, {
            role = entry.role,
            content = entry.content
        })
    end

    -- Call LLM
    local response = call_ollama(messages)
    -- ... rest unchanged
end
```

## CLI for Source Management

```bash
#!/bin/bash
# continual-sources - manage data sources for context injection

DIR="${1:-/mnt/mtwo/programming/ai-stuff/continual-co-operation}"

case "$2" in
    add)
        # Add a source
        lua "$DIR/src/source-cli.lua" add "$3" "$4"
        ;;
    list)
        # List registered sources
        lua "$DIR/src/source-cli.lua" list
        ;;
    index)
        # Re-index keywords for a source
        lua "$DIR/src/source-cli.lua" index "$3"
        ;;
    test)
        # Test similarity against a prompt
        lua "$DIR/src/source-cli.lua" test "$3"
        ;;
    *)
        echo "Usage: continual-sources [DIR] {add|list|index|test} [args]"
        ;;
esac
```

## Suggested Implementation Steps

1. **Create keyword extractor** (`src/keyword-extractor.lua`)
   - Stopword filtering
   - Frequency-based ranking
   - File and directory scanning

2. **Implement similarity module** (`src/similarity.lua`)
   - Jaccard coefficient
   - Source ranking with weights

3. **Build source registry** (`src/source-registry.lua`)
   - Source registration (always writable)
   - Keyword indexing and caching
   - Content extraction

4. **Integrate with rolling-memory** (modify `src/rolling-memory.lua`)
   - Inject similarity-matched sources before LLM call
   - Respect context size limits

5. **Create CLI wrapper** (`scripts/continual-sources`)
   - add, list, index, test commands

6. **Add default sources**
   - CLAUDE.md
   - Project directories
   - Elentalus mod

## Example Usage

```lua
-- At startup
source_registry.register({
    path = "/home/ritz/.claude/CLAUDE.md",
    type = "guidelines"
})

source_registry.add_project("/mnt/mtwo/programming/ai-stuff/delta-version")
source_registry.add_elentalus()

-- Later, during conversation
session:ask("How should the altar system work?")
-- → Automatically injects elentalus-lore (high similarity to "altar")
-- → Also injects game-design-document (contains altar mechanics)
```

## Related Documents
- [002-rolling-context-window](./002-rolling-context-window) - Core memory system
- [005-memory-persistence-mechanism](./005-memory-persistence-mechanism) - State persistence
- [Delta-Version 040h](../../delta-version/issues/040h-worldbuilding-design-oracle.md) - Worldbuilding integration

## Notes
- Keyword extraction should be cached per source (re-index on file change)
- Consider TF-IDF for more sophisticated similarity scoring later
- Source weights allow prioritizing certain types (lore > docs)
- The "always writable" requirement means sources can be added mid-session
