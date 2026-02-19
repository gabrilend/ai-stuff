# Issue 049a: Detail Level Filtering

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High (blocks 049b, 049c)
**Created**: 2026-02-11
**Parent**: Issue 049 (LLM Transcript Abstraction Viewer)
**Dependencies**: Issue 049d (Ollama Processing Pipeline)

---

## Current Behavior

LLM transcripts contain all conversation content at full detail, including:
- Verbose debugging sessions with repeated trial-and-error
- Tangential discussions that don't contribute to outcomes
- Tool output dumps (file listings, git status, etc.)
- Conversational pleasantries and confirmations
- Repeated explanations when the user didn't understand

There is no mechanism to identify which sections are essential vs. noise, nor to selectively remove content based on importance thresholds.

---

## Intended Behavior

A filtering system that uses Ollama to classify transcript sections by importance, then removes sections below a configurable threshold.

### Classification Categories

| Category | Weight | Description | Example |
|----------|--------|-------------|---------|
| **ESSENTIAL** | 100 | Major decisions, architectural choices, final outcomes | "We'll use a dispatch table pattern for the command routing" |
| **IMPORTANT** | 75 | Key discussions, rationale, implementation milestones | "The parser now correctly handles nested brackets" |
| **USEFUL** | 50 | Supporting context, helpful explanations | "This approach works because Lua tables are hash-based" |
| **VERBOSE** | 25 | Debugging attempts, repeated tries, extended explanations | "Let me try a different approach... still not working..." |
| **NOISE** | 0 | Greetings, confirmations, tool dumps, tangential chat | "Yes, that's correct", "Here's the git status output:" |

### Detail Level Thresholds

| Level | Threshold | Retains | Typical Reduction |
|-------|-----------|---------|-------------------|
| **1** (Minimal) | >= 100 | ESSENTIAL only | ~90% removed |
| **2** (Summary) | >= 75 | ESSENTIAL + IMPORTANT | ~75% removed |
| **3** (Standard) | >= 50 | Above + USEFUL | ~50% removed |
| **4** (Detailed) | >= 25 | Above + VERBOSE | ~25% removed |
| **5** (Full) | >= 0 | Everything (no filtering) | 0% removed |

### Processing Flow

```
[Transcript] --> [Section Splitter] --> [LLM Classifier] --> [Threshold Filter] --> [Filtered Output]
                        |                      |                      |
                        v                      v                      v
              Split into semantic     Ollama assigns          Remove sections
              chunks (exchanges,      importance scores       below threshold
              discussions, tasks)     to each chunk
```

---

## Suggested Implementation Steps

### 1. Section Splitter

```lua
-- {{{ split_transcript_sections
-- Splits a transcript into semantic sections for classification
--
-- Sections are identified by:
-- 1. User Request / Assistant Response boundaries
-- 2. Topic transitions (detected by keywords or separator lines)
-- 3. Maximum token limits (prevent oversized chunks)
local function split_transcript_sections(content)
    local sections = {}
    local current_section = {
        type = nil,        -- "user_request", "assistant_response", "tool_output"
        content = "",
        line_start = 0,
        line_end = 0,
    }

    -- Pattern matching for section markers
    local patterns = {
        user_request = "^### User Request",
        assistant_response = "^### Assistant Response",
        separator = "^%-%-%-%-%-%-",  -- 80 dashes
        tool_output = "^```",         -- Code blocks often contain tool output
    }

    local line_num = 0
    for line in content:gmatch("[^\n]+") do
        line_num = line_num + 1
        -- Section detection logic...
    end

    return sections
end
-- }}}
```

### 2. LLM Classification Prompt

```lua
-- {{{ classify_section
-- Uses Ollama to classify a section's importance
local function classify_section(ollama_client, section)
    local prompt = string.format([[
Classify this transcript section by importance for documentation purposes.

Categories (respond with ONLY the category name):
- ESSENTIAL: Major architectural decisions, final implementations, key outcomes
- IMPORTANT: Significant discussions, milestone completions, design rationale
- USEFUL: Supporting context, explanations that aid understanding
- VERBOSE: Debugging attempts, trial-and-error, extended explanations
- NOISE: Greetings, confirmations, raw tool output, tangential discussion

Section type: %s
Content:
---
%s
---

Classification:]], section.type, section.content)

    local response = ollama_client:generate(prompt)
    local category = response:match("^%s*(%w+)")

    return category_weights[category] or 50  -- Default to USEFUL if unclear
end
-- }}}
```

### 3. Triple-Check Validation

Per CLAUDE.md and Issue 035f patterns, use triple-check for LLM consistency:

```lua
-- {{{ classify_with_consensus
-- Queries LLM 3 times and requires 2/3 consensus
local function classify_with_consensus(ollama_client, section)
    local votes = {}

    for i = 1, 3 do
        local category = classify_section(ollama_client, section)
        votes[category] = (votes[category] or 0) + 1
    end

    -- Find majority (2/3 consensus)
    for category, count in pairs(votes) do
        if count >= 2 then
            return category_weights[category]
        end
    end

    -- No consensus: default to middle ground (USEFUL)
    return 50
end
-- }}}
```

### 4. Threshold Filtering

```lua
-- {{{ filter_by_detail_level
-- Removes sections below the detail level threshold
local function filter_by_detail_level(sections, detail_level)
    local thresholds = {
        [1] = 100,  -- Minimal: ESSENTIAL only
        [2] = 75,   -- Summary: ESSENTIAL + IMPORTANT
        [3] = 50,   -- Standard: + USEFUL
        [4] = 25,   -- Detailed: + VERBOSE
        [5] = 0,    -- Full: everything
    }

    local threshold = thresholds[detail_level] or 50
    local filtered = {}

    for _, section in ipairs(sections) do
        if section.importance >= threshold then
            table.insert(filtered, section)
        end
    end

    return filtered
end
-- }}}
```

### 5. Output Reconstruction

```lua
-- {{{ reconstruct_filtered_transcript
-- Rebuilds a transcript from filtered sections with transition markers
local function reconstruct_filtered_transcript(sections, detail_level)
    local output = {}
    local prev_section = nil

    for _, section in ipairs(sections) do
        -- Add transition marker if there's a gap
        if prev_section and section.line_start > prev_section.line_end + 5 then
            table.insert(output, "\n[... content filtered at detail level " .. detail_level .. " ...]\n")
        end

        table.insert(output, section.content)
        prev_section = section
    end

    return table.concat(output, "\n")
end
-- }}}
```

---

## CLI Interface

```bash
# Filter to detail level 2 (summary)
./scripts/detail-filter.lua --level=2 llm-transcripts/38621f31.md

# Preview classifications without filtering
./scripts/detail-filter.lua --classify-only llm-transcripts/

# Output classification report
./scripts/detail-filter.lua --report llm-transcripts/ > classification-report.md
```

---

## File Locations

- **Script**: `delta-version/scripts/libs/detail-filter.lua`
- **Test**: `delta-version/tmp/test-detail-filter.lua`
- **Output**: Passed to 049b for abstraction transformation

---

## Acceptance Criteria

- [ ] Correctly splits transcripts into semantic sections
- [ ] LLM classification assigns appropriate importance weights
- [ ] Triple-check consensus prevents hallucination-based misclassification
- [ ] Detail levels 1-5 produce progressively more complete outputs
- [ ] Filtered output maintains readability with transition markers
- [ ] Classification report shows section counts by category
- [ ] Works with both individual files and FULL-TRANSCRIPT-EXPORT.md
- [ ] Processing time is reasonable (< 30s per transcript file)

---

## Technical Notes

### Token Efficiency

The classification prompt is designed to be minimal to reduce Ollama processing time. Instead of asking for explanations, we only request the category name.

### Section Boundaries

The splitter should respect semantic boundaries:
- Never split mid-sentence
- Keep code blocks intact
- Group related exchanges (question + answer)
- Respect maximum chunk size for LLM context limits

### Caching

Consider caching classifications to avoid re-processing unchanged transcripts:
```lua
-- Cache key: SHA256(section_content) -> classification
local cache_path = DIR .. "/tmp/classification-cache.json"
```

---

## Indexed Chunk System with Tool-Call Removal

### Overview

Rather than having the LLM output classifications directly, we provide it with a tool-call interface for chunk removal. This enables:

1. **Indexed Array**: Transcript split into chunks with numeric indices
2. **Tool-Call Interface**: LLM calls `remove_chunk(index, text_excerpt)` to mark sections
3. **Dual Validation**: Both index AND text similarity must agree before removal
4. **Safety Net**: Prevents accidental removal due to LLM hallucination

### Processing Flow

```
[Transcript] --> [Chunk Splitter] --> [Indexed Array] --> [LLM with Tool]
                                            |                    |
                                            v                    v
                                    chunks[1] = "..."    remove_chunk(3, "Let me try...")
                                    chunks[2] = "..."            |
                                    chunks[3] = "..."            v
                                    ...                  [Dual Validator]
                                                               / \
                                                              /   \
                                                   [Index Match] [Text Similarity]
                                                              \   /
                                                               \ /
                                                          [Agreement?]
                                                            /     \
                                                          YES      NO
                                                           |       |
                                                      [Remove]  [Keep + Warn]
```

### Implementation: Chunk Splitter Script

**File**: `delta-version/scripts/libs/chunk-splitter.lua`

```lua
#!/usr/bin/env luajit
-- chunk-splitter.lua - Split transcripts into indexed chunks for LLM tool-call removal
--
-- Splits transcript files into logically defined chunks that can be referenced
-- by numeric index. Chunk granularity adapts to target detail level.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
if arg[1] and arg[1]:match("^%-%-dir=") then
    DIR = arg[1]:match("^%-%-dir=(.+)$")
    table.remove(arg, 1)
end
-- }}}

local M = {}

-- {{{ Chunk granularity by detail level
-- Lower detail = larger chunks (more aggressive removal)
-- Higher detail = smaller chunks (finer control)
local CHUNK_GRANULARITY = {
    [1] = "conversation",   -- Entire user-assistant exchanges (largest)
    [2] = "exchange",       -- Single request-response pair
    [3] = "message",        -- Individual user or assistant message
    [4] = "paragraph",      -- Paragraph-level within messages
    [5] = "sentence",       -- Sentence-level (finest, but level 5 keeps everything anyway)
}
-- }}}

-- {{{ split_into_chunks
-- Splits transcript content into indexed chunks based on detail level
--
-- @param content string: Raw transcript content
-- @param detail_level number: Target detail level (1-5)
-- @return table: Array of chunk objects {index, content, line_start, line_end, type}
function M.split_into_chunks(content, detail_level)
    local granularity = CHUNK_GRANULARITY[detail_level] or "message"
    local chunks = {}

    if granularity == "conversation" then
        chunks = split_by_conversation(content)
    elseif granularity == "exchange" then
        chunks = split_by_exchange(content)
    elseif granularity == "message" then
        chunks = split_by_message(content)
    elseif granularity == "paragraph" then
        chunks = split_by_paragraph(content)
    else
        chunks = split_by_sentence(content)
    end

    -- Assign indices
    for i, chunk in ipairs(chunks) do
        chunk.index = i
    end

    return chunks
end
-- }}}

-- {{{ split_by_exchange
-- Splits into user request + assistant response pairs
local function split_by_exchange(content)
    local chunks = {}
    local current_chunk = nil
    local line_num = 0
    local in_exchange = false

    for line in content:gmatch("([^\n]*)\n?") do
        line_num = line_num + 1

        -- Detect exchange boundaries
        if line:match("^### User Request") then
            -- Save previous chunk
            if current_chunk and #current_chunk.content > 0 then
                current_chunk.line_end = line_num - 1
                table.insert(chunks, current_chunk)
            end
            -- Start new chunk
            current_chunk = {
                content = line .. "\n",
                line_start = line_num,
                line_end = line_num,
                type = "exchange",
            }
            in_exchange = true
        elseif line:match("^%-%-%-%-%-%-%-%-") and in_exchange then
            -- Separator after assistant response = end of exchange
            if current_chunk then
                current_chunk.content = current_chunk.content .. line .. "\n"
                -- Check if we just finished an assistant response
                if current_chunk.content:match("### Assistant Response") then
                    current_chunk.line_end = line_num
                    table.insert(chunks, current_chunk)
                    current_chunk = nil
                    in_exchange = false
                end
            end
        elseif current_chunk then
            current_chunk.content = current_chunk.content .. line .. "\n"
        end
    end

    -- Save final chunk
    if current_chunk and #current_chunk.content > 0 then
        current_chunk.line_end = line_num
        table.insert(chunks, current_chunk)
    end

    return chunks
end
-- }}}

-- {{{ split_by_message
-- Splits into individual user or assistant messages
local function split_by_message(content)
    local chunks = {}
    local current_chunk = nil
    local line_num = 0

    for line in content:gmatch("([^\n]*)\n?") do
        line_num = line_num + 1

        if line:match("^### User Request") or line:match("^### Assistant Response") then
            -- Save previous chunk
            if current_chunk and #current_chunk.content > 0 then
                current_chunk.line_end = line_num - 1
                table.insert(chunks, current_chunk)
            end
            -- Start new chunk
            local msg_type = line:match("User Request") and "user" or "assistant"
            current_chunk = {
                content = line .. "\n",
                line_start = line_num,
                line_end = line_num,
                type = msg_type,
            }
        elseif current_chunk then
            -- Skip separator lines between messages but include content
            if not line:match("^%-%-%-%-%-%-%-%-") then
                current_chunk.content = current_chunk.content .. line .. "\n"
            end
        end
    end

    -- Save final chunk
    if current_chunk and #current_chunk.content > 0 then
        current_chunk.line_end = line_num
        table.insert(chunks, current_chunk)
    end

    return chunks
end
-- }}}

-- {{{ split_by_paragraph
-- Splits messages into paragraphs (double newline boundaries)
local function split_by_paragraph(content)
    local chunks = {}
    local paragraphs = {}

    -- First split by messages to preserve context
    local messages = split_by_message(content)

    for _, msg in ipairs(messages) do
        -- Split message content by double newlines
        local para_start = msg.line_start
        for para in msg.content:gmatch("([^\n]+\n?)(\n?)") do
            if #para:gsub("%s+", "") > 0 then  -- Non-empty paragraph
                table.insert(chunks, {
                    content = para,
                    line_start = para_start,
                    line_end = para_start,  -- Approximate
                    type = msg.type .. "_paragraph",
                    parent_type = msg.type,
                })
            end
            para_start = para_start + select(2, para:gsub("\n", "")) + 1
        end
    end

    return chunks
end
-- }}}

-- {{{ format_chunks_for_llm
-- Formats chunks array for LLM consumption with indices
--
-- @param chunks table: Array of chunk objects
-- @return string: Formatted text showing [INDEX]: content for each chunk
function M.format_chunks_for_llm(chunks)
    local output = {}

    table.insert(output, "# Transcript Chunks\n")
    table.insert(output, string.format("Total chunks: %d\n\n", #chunks))

    for _, chunk in ipairs(chunks) do
        table.insert(output, string.format("[%d] (lines %d-%d, type: %s)\n",
            chunk.index, chunk.line_start, chunk.line_end, chunk.type))
        table.insert(output, "---\n")
        -- Truncate very long chunks for display
        local display_content = chunk.content
        if #display_content > 500 then
            display_content = display_content:sub(1, 500) .. "\n... [truncated, " .. #chunk.content .. " chars total]\n"
        end
        table.insert(output, display_content)
        table.insert(output, "\n---\n\n")
    end

    return table.concat(output)
end
-- }}}

-- {{{ get_chunk_by_index
-- Retrieves a chunk by its index
function M.get_chunk_by_index(chunks, index)
    if index < 1 or index > #chunks then
        return nil, "Index out of range"
    end
    return chunks[index]
end
-- }}}

return M
```

### Implementation: Tool-Call Removal Interface

**File**: `delta-version/scripts/libs/chunk-removal-tool.lua`

```lua
#!/usr/bin/env luajit
-- chunk-removal-tool.lua - Tool-call interface for LLM chunk removal
--
-- Provides a tool that the LLM can call to mark chunks for removal.
-- Uses dual validation: both index AND text similarity must agree.

local M = {}

-- {{{ calculate_word_similarity
-- Calculates word-level similarity between two strings
-- Returns a score from 0.0 (no match) to 1.0 (identical words)
local function calculate_word_similarity(text1, text2)
    -- Tokenize into words (lowercase, alphanumeric only)
    local function tokenize(text)
        local words = {}
        for word in text:lower():gmatch("%w+") do
            words[word] = (words[word] or 0) + 1
        end
        return words
    end

    local words1 = tokenize(text1)
    local words2 = tokenize(text2)

    -- Calculate Jaccard-like similarity with frequency weighting
    local intersection = 0
    local union = 0

    -- Count intersection
    for word, count1 in pairs(words1) do
        local count2 = words2[word] or 0
        intersection = intersection + math.min(count1, count2)
        union = union + math.max(count1, count2)
    end

    -- Add words only in text2 to union
    for word, count2 in pairs(words2) do
        if not words1[word] then
            union = union + count2
        end
    end

    if union == 0 then return 0 end
    return intersection / union
end
-- }}}

-- {{{ find_most_similar_chunk
-- Finds the chunk with highest text similarity to the provided excerpt
--
-- @param chunks table: Array of chunk objects
-- @param text_excerpt string: Text the LLM claims to be removing
-- @return number, number: best_index, similarity_score
local function find_most_similar_chunk(chunks, text_excerpt)
    local best_index = nil
    local best_score = 0

    for _, chunk in ipairs(chunks) do
        local score = calculate_word_similarity(chunk.content, text_excerpt)
        if score > best_score then
            best_score = score
            best_index = chunk.index
        end
    end

    return best_index, best_score
end
-- }}}

-- {{{ Module state
local state = {
    chunks = nil,
    removal_queue = {},       -- Validated removals
    rejected_removals = {},   -- Failed validation
    similarity_threshold = 0.3,  -- Minimum similarity to consider a match
}
-- }}}

-- {{{ init
-- Initialize the tool with a chunks array
function M.init(chunks, options)
    options = options or {}
    state.chunks = chunks
    state.removal_queue = {}
    state.rejected_removals = {}
    state.similarity_threshold = options.similarity_threshold or 0.3
end
-- }}}

-- {{{ remove_chunk (Tool Call)
-- The tool function that the LLM calls to mark a chunk for removal
--
-- @param index number: The chunk index to remove
-- @param text_excerpt string: The text content being removed (for validation)
-- @return table: Result with success status and message
function M.remove_chunk(index, text_excerpt)
    if not state.chunks then
        return {
            success = false,
            message = "Tool not initialized. Call init() with chunks first.",
        }
    end

    -- Validate index is in range
    if index < 1 or index > #state.chunks then
        return {
            success = false,
            message = string.format("Index %d out of range (1-%d)", index, #state.chunks),
        }
    end

    -- Get chunk at specified index
    local chunk_at_index = state.chunks[index]

    -- Find most similar chunk by text
    local similar_index, similarity = find_most_similar_chunk(state.chunks, text_excerpt)

    -- Dual validation: index and similarity must agree
    if index == similar_index then
        -- Agreement! Mark for removal
        table.insert(state.removal_queue, {
            index = index,
            chunk = chunk_at_index,
            text_excerpt = text_excerpt,
            similarity = similarity,
            validation = "AGREED",
        })
        return {
            success = true,
            message = string.format(
                "Chunk %d marked for removal (similarity: %.2f, validation: AGREED)",
                index, similarity
            ),
        }
    else
        -- Disagreement! Reject removal
        table.insert(state.rejected_removals, {
            requested_index = index,
            similar_index = similar_index,
            similarity = similarity,
            text_excerpt = text_excerpt,
            reason = "Index and text similarity point to different chunks",
        })
        return {
            success = false,
            message = string.format(
                "Removal rejected: Index %d requested, but text most similar to chunk %d (similarity: %.2f). " ..
                "Both must agree for safety.",
                index, similar_index or -1, similarity
            ),
        }
    end
end
-- }}}

-- {{{ get_tool_definition
-- Returns the tool definition for the LLM (JSON schema format)
function M.get_tool_definition()
    return {
        name = "remove_chunk",
        description = "Mark a transcript chunk for removal based on detail level filtering. " ..
                      "You must provide BOTH the chunk index AND the text you're removing. " ..
                      "The system will validate that both point to the same chunk.",
        parameters = {
            type = "object",
            properties = {
                index = {
                    type = "integer",
                    description = "The numeric index of the chunk to remove (from the chunk list)",
                },
                text_excerpt = {
                    type = "string",
                    description = "A portion of the text content being removed (for validation). " ..
                                  "Include enough text to uniquely identify the chunk.",
                },
            },
            required = {"index", "text_excerpt"},
        },
    }
end
-- }}}

-- {{{ get_removal_queue
-- Returns the list of validated removals
function M.get_removal_queue()
    return state.removal_queue
end
-- }}}

-- {{{ get_rejected_removals
-- Returns the list of rejected removal attempts
function M.get_rejected_removals()
    return state.rejected_removals
end
-- }}}

-- {{{ apply_removals
-- Applies all validated removals and returns filtered chunks
--
-- @return table: Array of chunks with removals applied
function M.apply_removals()
    if not state.chunks then return {} end

    -- Build set of indices to remove
    local remove_set = {}
    for _, removal in ipairs(state.removal_queue) do
        remove_set[removal.index] = true
    end

    -- Filter chunks
    local filtered = {}
    for _, chunk in ipairs(state.chunks) do
        if not remove_set[chunk.index] then
            table.insert(filtered, chunk)
        end
    end

    return filtered
end
-- }}}

-- {{{ generate_removal_report
-- Generates a report of all removal attempts
function M.generate_removal_report()
    local report = {}

    table.insert(report, "# Chunk Removal Report\n\n")

    table.insert(report, "## Validated Removals (" .. #state.removal_queue .. ")\n\n")
    for _, removal in ipairs(state.removal_queue) do
        table.insert(report, string.format("- **Chunk %d** (similarity: %.2f)\n", removal.index, removal.similarity))
        table.insert(report, string.format("  - Lines: %d-%d\n", removal.chunk.line_start, removal.chunk.line_end))
        table.insert(report, string.format("  - Type: %s\n", removal.chunk.type))
    end

    table.insert(report, "\n## Rejected Removals (" .. #state.rejected_removals .. ")\n\n")
    for _, rejection in ipairs(state.rejected_removals) do
        table.insert(report, string.format("- **Requested index %d**, matched chunk %d (similarity: %.2f)\n",
            rejection.requested_index, rejection.similar_index or -1, rejection.similarity))
        table.insert(report, string.format("  - Reason: %s\n", rejection.reason))
    end

    return table.concat(report)
end
-- }}}

return M
```

### LLM Prompt Template for Tool-Call Removal

```lua
-- {{{ get_removal_prompt
-- Generates the prompt for the LLM to use tool-calls for removal
local function get_removal_prompt(formatted_chunks, detail_level, categories_to_remove)
    return string.format([[
You are analyzing a transcript to identify chunks that should be removed for a detail level %d summary.

## Detail Level %d Criteria
At this detail level, you should REMOVE chunks that are:
%s

## Available Tool
You have access to the `remove_chunk` tool. For each chunk you want to remove:
1. Call remove_chunk with the chunk INDEX
2. Also provide TEXT_EXCERPT - a portion of the chunk's content (50-100 words)

The system validates that your index and text point to the same chunk. If they disagree, the removal is rejected.

## Transcript Chunks
%s

## Instructions
1. Review each chunk
2. For chunks matching the removal criteria, call remove_chunk(index, text_excerpt)
3. Be conservative - when in doubt, keep the chunk
4. Provide enough text in text_excerpt to uniquely identify the chunk

Begin analysis:
]], detail_level, detail_level, categories_to_remove, formatted_chunks)
end
-- }}}
```

### CLI Usage

```bash
# Split transcript into chunks at detail level 2
./scripts/chunk-splitter.lua --level=2 llm-transcripts/38621f31.md

# Run LLM removal with tool-calls
./scripts/detail-filter.lua --tool-mode --level=2 llm-transcripts/38621f31.md

# Generate removal report
./scripts/detail-filter.lua --tool-mode --report llm-transcripts/38621f31.md
```

### Updated Acceptance Criteria

- [ ] Chunk splitter produces indexed arrays at all granularity levels
- [ ] Tool-call interface correctly validates index + text similarity
- [ ] Disagreement between index and similarity rejects removal (safety)
- [ ] Removal report shows both validated and rejected attempts
- [ ] Word similarity calculation handles edge cases (empty strings, very short text)
- [ ] LLM prompt template guides proper tool usage
- [ ] Works with Ollama tool-calling (if supported) or structured output

---

## Related

- Issue 049d: Provides the Ollama client used for classification
- Issue 049b: Receives filtered output for abstraction transformation
- Issue 035f: Established triple-check pattern for LLM consistency
